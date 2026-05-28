

#  Nginx + FastAPI 前后端交互 —— **（含完整配置 & 逐行代码）**


- **架构拓扑**
```
  [ 浏览器 ]
       |
       | HTTP 请求 (80端口)
       v
  [ Nginx ]  <-- 守门员
       |
       | 反向代理 (转发给8000端口)
       v
  [ FastAPI (uvicorn) ] <-- 指挥官
       |
       | 系统调用 (fork/exec)
       v
  [ top / free / df ] <-- 侦察兵
       |
       | 写入设备文件
       v
  [ /dev/pts/0 ] <-- 服务器终端屏幕
```



## 一、Nginx：从安装到完整配置（逐行拆解）

###安装 Nginx

```bash
apt update
apt install -y nginx
systemctl enable nginx
systemctl start nginx
```

### 核心配置文件（服务器的真实路径）

```
/etc/nginx/nginx.conf
/etc/nginx/sites-enabled/default
```

- 在`/etc/nginx/sites-avaliable/`下修改
- `sites-enabled/default`并不是 Nginx 运行的唯一配置文件，但它是最**安全**、最**标准**的操作入口。
 一、Nginx 的配置文件结构
  Nginx 启动时会加载一个 **主配置文件**，它位于：
  `/etc/nginx/nginx.conf`
  **最底部看到这样一行代码（这是关键）**：`include /etc/nginx/sites-enabled/*`;        意思是：“老板（nginx.conf）说：具体业务我不看，你们把各分公司的方案都拿进来吧。”
  nginx变成下面这样	

```
	/etc/nginx/
	├── nginx.conf              # 主配置文件（宪法）
	├── sites-available/        # 可用的站点配置（草稿箱）
	│   └── default            # 默认站点配置
	└── sites-enabled/          # 启用的站点配置（正式生效的）
	    └── default -> ../sites-available/default  (软链接)
```

   二、为什么不直接改 `nginx.conf`？
   1. 职责分离（Separation of Concerns）
	| 文件                    | 职责                                       | 类比               |
	| ----------------------- | ------------------------------------------ | ------------------ |
	| `nginx.conf`            | 全局设置（worker进程数、日志路径、连接数） | **公司章程**       |
	| `sites-enabled/default` | 具体的网站业务（端口、域名、反向代理）     | **分公司运营手册** |
	
	如果你把网站的端口、反向代理规则写进 `nginx.conf`，一旦网站配置写错，可能导致 **整个 Nginx 服务崩溃**，连其他网站也打不开。
	
   2. 支持多站点（Virtual Hosting）
	假设服务器上有两个项目：
    1. 一个 FastAPI 监控工具（monitor.example.com）
	2. 一个博客（blog.example.com）
	一般这样做：
```bash
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/monitor
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/blog
```
   然后在 `sites-enabled`里启用它们。
   **Nginx 会根据浏览器请求的域名，自动选择对应的配置文件。**
	
   三、`sites-available`和 `sites-enabled`的区别（核心）
   1. `sites-available`（可用）
	- **含义**：这里存放着所有的配置“草稿”。
	- **作用**：你可以把配置写在这里，但不一定要启用。
	
   2. `sites-enabled`（启用）
	- **含义**：这里存放着当前正在生效的配置。
	- **真相**：这里通常不放真实文件，而是放 **软链接（Shortcut）**。
	
   3. 为什么要这样设计？
      **场景：你要下线维护一个网站。**
      **错误做法**：直接删除配置文件（万一恢复不了怎么办？）
      **正确做法**：
```bash
rm /etc/nginx/sites-enabled/default
systemctl reload nginx
```
   -  配置还在 `sites-available`里（没丢）。
   - 但 Nginx 不再加载它（下线了）。

   四、为什么偏偏是 `default`文件？
   `default`文件是 Nginx 安装后自带的示例文件。
```bash
server_name _;
```
   这里的 `_`是一个通配符，意思是：
   > “不管你用 IP 还是域名访问，只要没有匹配到其他配置，就用我这个。”
   对于你的 FastAPI 项目，它充当了 **“默认入口”**。

   五、底层原理：Nginx 启动时做了什么？
   当执行：
```bash
systemctl reload nginx
```
Nginx 内部流程如下：
1. **读取主配置**：打开 `/etc/nginx/nginx.conf`。
2. **执行 Include**：扫描 `/etc/nginx/sites-enabled/*`。
3. **语法解析**：检查 `default`文件里的语法是否正确。
4. **加载 Server 块**：将 `listen 80`绑定到网卡。
5. **平滑切换**：老进程继续服务旧连接，新进程处理新连接（零宕机）。

   六、给你的实操建议（初学者必看）
   1. 修改前先备份

```bash
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak
```
   2. 修改哪里？
      **永远只改：**
```bash
/etc/nginx/sites-available/default
```
   **然后确保它被链接到：**
```bash
/etc/nginx/sites-enabled/default
```
   3. 测试语法
      每次修改后，务必执行：
```bash
nginx -t

### 完整 Nginx 配置
```yaml
server {
    # 监听 IPv4 80 端口
    listen 80 default_server;

    # 监听 IPv6 80 端口
    listen [::]:80 default_server;

    # 站点根目录
    root /var/www/html;

    # 默认首页文件
    index index.html index.htm;

    # 匹配所有域名（通配）
    server_name _;

    # 前端静态资源
    location / {
        # 先尝试文件，再尝试目录，都没有则返回 404
        try_files $uri $uri/ =404;
    }

    # 1. 匹配规则：所有 以 /api/ 开头的请求（如 /api/user、/api/login），都会进入这个配置块处理
	location /api/ {
        # 2. 核心：反向代理转发
        # 把匹配到的 /api/ 请求，转发到 本机 8000 端口的 FastAPI 服务
        # 127.0.0.1 代表本机，8000 是 FastAPI 默认运行端口
        proxy_pass http://127.0.0.1:8000;

        # 3. 请求头配置：传递原始请求的主机名（域名/IP）给后端 FastAPI
        # $host 是 Nginx 内置变量，代表客户端访问的原始域名/IP
        # 作用：让后端知道用户访问的是哪个域名，而不是代理的本地地址
        proxy_set_header Host $host;

        # 4. 传递【真实客户端IP】给后端 FastAPI
        # $remote_addr 是 Nginx 内置变量，代表发起请求的客户端真实 IP
        # 作用：后端可以通过请求头 X-Real-IP 获取到用户的真实 IP，而不是 Nginx 的代理 IP
        proxy_set_header X-Real-IP $remote_addr;

        # 5. 传递【完整代理链IP】（多层代理必备，比如 Nginx → 其他代理 → FastAPI）
        # $proxy_add_x_forwarded_for 会拼接所有代理层的 IP + 客户端真实 IP
        # 作用：后端能追溯请求经过的所有代理节点，日志/风控场景必备
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # 6. 关闭 Nginx 响应缓冲
        # 默认 Nginx 会缓存后端返回的数据，攒满再发给客户端
        # 关闭后：数据实时转发，无延迟，适合接口、实时通信、流式响应场景
        proxy_buffering off;
	}
}
```

### nginx配置每一行的底层含义（非常重要）

| 指令         | 作用           | 底层原理                         |
| :----------- | -------------- | :------------------------------- |
| `listen 80`  | 绑定 80 端口   | 调用 `bind(0.0.0.0:80)`          |
| `root`       | 静态文件根目录 | Nginx 拼接 `/var/www/html + URI` |
| `try_files`  | 文件查找规则   | `open()`→ `stat()`→ `sendfile()` |
| `proxy_pass` | 反向代理       | Nginx 建立新 TCP 连接            |
| `X-Real-IP`  | 透传客户端 IP  | 解决后端拿不到真实 IP 问题       |


------

### 重载配置（必须）

```bash
nginx -t        # 语法检查
systemctl reload nginx   # 重载nginx
```

------

##二、FastAPI 后端：main.py

## 创建后端目录

```bash
mkdir -p /opt/backend
cd /opt/backend
```
------

### 安装依赖

```bash
pip3 install fastapi uvicorn
```

- `fastapi`：**Python高性能Web框架**，用于编写API接口 
- `uvicorn`：**异步Web服务器**，用于启动运行FastAPI，监听8000端口 - 两者配合：搭建出Nginx反向代理的后端API服务

## main.py（最终完整代码）

```python
# 1. 导入需要的工具包
from fastapi import FastAPI  # 导入FastAPI框架，用来创建Web接口
import subprocess            # Python内置模块，用来执行Linux系统命令
import os                    # 操作系统相关模块（这里未直接使用，可忽略）
from datetime import datetime # 时间模块，用来获取当前系统时间

# 2. 创建FastAPI应用实例
# title是API的名称，方便识别
app = FastAPI(title="System Monitor API")

# 3. 工具函数1：把文字输出到服务器的终端屏幕
def write_to_terminal(text: str):
    """
    将内容写入当前服务器的终端（/dev/pts是Linux终端设备文件）
    :param text: 要输出的文字内容
    """
    # 遍历0-4号终端，找到可用的终端并写入
    for i in range(5):
        try:
            # 打开终端设备文件，以写入模式
            with open(f"/dev/pts/{i}", "w") as f:
                f.write(text)  # 把内容写入终端
            return  # 写入成功就退出，不再尝试其他终端
        except FileNotFoundError:
            # 如果这个终端不存在，就跳过，尝试下一个
            continue

# 4. 工具函数2：格式化输出内容（加标题、时间、边框，更好看）
def format_output(title: str, content: str) -> str:
    """
    给输出内容加边框、标题、时间，美化显示
    :param title: 模块标题（CPU/内存/磁盘）
    :param content: 系统命令执行结果
    :return: 格式化后的完整文本
    """
    # 获取当前时间，格式化成年-月-日 时:分:秒
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    # 生成分割线（60个等号）
    border = "=" * 60

    # 返回拼接好的格式化文本
    return f"""
{border}
📌 {title}
{border}
时间: {now}
{border}

{content}

{border}
"""

# 5. 核心API接口：访问 /api/monitor 调用监控功能
@app.get("/api/monitor")
def monitor(opt: int):
    """
    前端点击按钮后调用的接口
    :param opt: 选项参数
    opt = 1 → CPU监控
    opt = 2 → 内存监控
    opt = 3 → 磁盘监控
    opt = 4 → 退出监控
    """

    if opt == 1:
        # --------------------------
        # 选项1：执行CPU监控命令
        # --------------------------
        # 执行Linux命令：top -bn1 → 静态输出1次CPU/进程信息
        result = subprocess.run(
            ["top", "-bn1"],          # 要执行的命令
            stdout=subprocess.PIPE,    # 捕获命令执行的正常输出
            stderr=subprocess.PIPE,    # 捕获命令执行的错误信息
            text=True                  # 以文本格式返回结果（不是二进制）
        )

        # 只取前15行输出，避免终端刷屏
        lines = result.stdout.split("\n")[:15]
        content = "\n".join(lines)

        # 格式化内容 + 输出到终端
        formatted = format_output("CPU 监控", content)
        write_to_terminal(formatted)
        return "✅ CPU 信息已输出到终端"

    elif opt == 2:
        # --------------------------
        # 选项2：执行内存监控
        # --------------------------
        # 执行Linux命令：free -h → 人性化显示内存使用情况
        result = subprocess.run(
            ["free", "-h"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        formatted = format_output("内存监控", result.stdout)
        write_to_terminal(formatted)
        return "✅ 内存信息已输出到终端"

    elif opt == 3:
        # --------------------------
        # 选项3：执行磁盘监控
        # --------------------------
        # 执行Linux命令：df -h → 人性化显示磁盘分区使用情况
        result = subprocess.run(
            ["df", "-h"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        formatted = format_output("磁盘监控", result.stdout)
        write_to_terminal(formatted)
        return "✅ 磁盘信息已输出到终端"

    elif opt == 4:
        # --------------------------
        # 选项4：结束监控
        # --------------------------
        formatted = format_output("系统监控", "👋 监控已结束")
        write_to_terminal(formatted)
        return "✅ 已退出"

    else:
        # 无效参数
        return "❌ 非法选项"
```

------

## 三、main.py 函数逐行拆解（核心）

### `monitor(opt: int)`

```bash
@app.get("/api/monitor")
def monitor(opt: int):
```

**底层流程**：

```
浏览器 fetch('/api/monitor?opt=1')
↓
Nginx 转发
↓
FastAPI 路由匹配
↓
monitor(1)
```

------

## `subprocess.run()`（最关键）

```bash
subprocess.run(["top", "-bn1"], ...)
```

 **发生了什么？**

1. FastAPI 进程调用 `fork()`
2. 子进程调用 `execve("/usr/bin/top")`
3. `top`读取 `/proc/stat`、`/proc/meminfo`
4. FastAPI 通过 **pipe** 读取 stdout

**这是“Web 控制 OS”的根本**

------

###`write_to_terminal()`（终端输出原理）

```bash
with open("/dev/pts/0", "w") as f:
```

**原理**：

- `/dev/pts/0`是 SSH 终端
- `write()`→ TTY 驱动 → 显卡 → 屏幕
 **不是日志，是真终端输出**

## 四、Systemd 服务（完整版）

###服务文件

```bash
nano /etc/systemd/system/fastapi-monitor.service
[Unit]
Description=FastAPI System Monitor
After=network.target

[Service]
User=root
WorkingDirectory=/opt/backend(路径要和main.py的路径一致！！！)
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

------

### 启动服务

```bash
systemctl daemon-reload
systemctl enable fastapi-monitor
systemctl start fastapi-monitor
systemctl status fastapi-monitor
```

## 五、前端页面（完整版）

### `/var/www/html/index.html`

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>系统监控</title>
<style>
  body { background:#0b1120; color:#e5e7eb; text-align:center; padding-top:80px; }
  .box { background:rgba(255,255,255,0.05); border:1px solid rgba(255,255,255,0.1); border-radius:14px; padding:40px; width:360px; margin:auto; }
  button { width:100%; padding:12px; margin:8px 0; border:none; border-radius:8px; background:#2563eb; color:white; font-size:16px; cursor:pointer; }
</style>
</head>
<body>
<div class="box">
  <h1>🖥️ 系统监控</h1>
  <button onclick="run(1)">1️⃣ CPU</button>
  <button onclick="run(2)">2️⃣ 内存</button>
  <button onclick="run(3)">3️⃣ 磁盘</button>
  <button onclick="run(4)">4️⃣ 退出</button>
</div>

<script>
function run(opt) {
  fetch('/api/monitor?opt=' + opt)
    .then(res => res.text())
    .then(msg => alert(msg));
}
</script>
</body>
</html>
```

------

## 六、最终效果（你今天看到的）

```bash
============================================================
 CPU 监控
============================================================
时间: 2026-05-27 09:41:46
============================================================

top - 09:41:46 up 1:26, 5 users, load average: 3.04
Tasks: 335 total, 1 running, 334 sleeping
%Cpu(s): 0.0 us, 4.2 sy, 0.0 ni, 94.4 id

============================================================
```

