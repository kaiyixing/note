# Web端调用Bash脚本实现分级Ping测试 项目实战笔记

## 一、项目简介

本次独立开发**Web\+Bash分级Ping测试项目**，全程与原有服务器监控旧项目完全隔离、无端口冲突、无配置覆盖。实现核心功能：前端批量输入多个IP地址，后端自动按顺序分配Ping次数，第一个IP Ping1次、第二个IP Ping2次、第三个IP Ping3次，多余IP默认Ping1次，通过Bash脚本执行网络测试并返回结果。

**项目核心架构**：前端HTML表单 \+ FastAPI后端服务 \+ Bash脚本 \+ Nginx反向代理

**环境系统**：Ubuntu

## 二、新旧项目隔离方案（核心重点）

本次严格遵循Ubuntu Nginx标准架构，实现双项目完全隔离，互不干扰、互不覆盖。

|项目类型|Nginx对外端口|后端服务端口|Nginx配置文件路径|项目目录|访问方式|
|---|---|---|---|---|---|
|旧监控项目|80（默认端口）|8000|/etc/nginx/sites\-available/default|系统默认目录|http://服务器IP|
|新项目（Ping测试）|81（自定义端口）|8001|/etc/nginx/sites\-available/web\-bash|/web\-bash|http://服务器IP:81|

**隔离原理**：Ubuntu Nginx采用 `sites\-available`（配置仓库）\+ `sites\-enabled`（软链接生效）架构，两个项目独立配置文件、独立端口、独立目录，彻底杜绝冲突。

## 三、项目完整文件结构

项目根目录：`/web\-bash`

包含3个核心业务文件，无冗余代码：

- `index\.html`：前端展示页面、数据提交表单

- `main\.py`：FastAPI后端核心逻辑，分配Ping次数、调用脚本

- `test\.sh`：Bash脚本，执行Ping网络测试

## 四、全文件代码逐行解析

### 1\. 前端文件：index\.html（解决中文乱码）

**功能作用**：提供可视化IP输入表单，接收用户输入，以POST方式提交数据到后端接口，声明UTF\-8编码彻底解决中文乱码问题。

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head&gt;
    <!-- 核心：指定编码格式，解决页面中文乱码 -->
    <meta charset="UTF-8">
    <title>Web调用Bash脚本</title>
</head>
<body>
    <h2>Web调用Bash脚本</h2&gt;
    <!-- 表单核心：提交地址为后端接口，提交方式POST -->
    <form action="/exec_bash" method="post">
        输入多个IP（一行一个）：&lt;br&gt;
        <!-- 多行文本框，支持批量输入多个IP -->
        <textarea name="ip_list" rows="5" cols="40" placeholder="192.168.1.1
8.8.8.8"></textarea>
        <br><br>
        <button type="submit">提交执行</button>
    </form>
</body>
</html>
```

### 2\. 后端文件：main\.py（核心业务逻辑）

**功能作用**：接收前端表单数据，清洗IP数据，按IP排序分级分配Ping次数，调用Bash脚本执行命令，返回执行结果。

```python
# 导入FastAPI核心组件、表单接收模块、系统进程调用模块
from fastapi import FastAPI, Form
import subprocess

# 初始化FastAPI服务实例
app = FastAPI(title="Web+Bash独立项目")

# 定义POST接口：接收前端提交的IP列表表单数据
@app.post("/exec_bash")
def exec_bash(ip_list: str = Form(...)):
    # 数据清洗：按换行切割IP，过滤空行、空格
    ips = [ip.strip() for ip in ip_list.splitlines() if ip.strip()]
    # 定义空字符串，存储所有脚本执行输出结果
    output = ""

    # 遍历IP列表，按顺序分级分配Ping次数
    for index, ip in enumerate(ips):
        # 第1个IP ping1次
        if index == 0:
            count = 1
        # 第2个IP ping2次
        elif index == 1:
            count = 2
        # 第3个IP ping3次
        elif index == 2:
            count = 3
        # 超过3个的IP，默认ping1次
        else:
            count = 1

        # 调用本地bash脚本，传入IP地址和ping次数参数
        res = subprocess.run(
            ["./test.sh", ip, str(count)],
            stdout=subprocess.PIPE,  # 接收脚本标准输出
            stderr=subprocess.PIPE,  # 接收脚本错误输出
            text=True  # 以文本格式返回结果，默认字节流
        )
        # 拼接每次ping的执行结果
        output += res.stdout + res.stderr

    # 以网页预格式化格式返回结果，保留换行排版
    return f"<pre>{output}</pre>"

# 服务入口：指定监听所有IP、绑定8001端口，规避旧项目8000端口冲突
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
```

### 3\. 脚本文件：test\.sh（Ping执行脚本）

**功能作用**：接收后端传递的IP和Ping次数参数，执行Ping命令，格式化输出测试结果。

```bash
#!/bin/bash
# 接收外部传参：$1=IP地址  $2=Ping次数
IP=$1
COUNT=$2

# 格式化输出头部信息
echo "====================================="
echo "处理IP：${IP}  |  ping次数：${COUNT}"
echo "====================================="
# 执行指定次数的ping测试 -c 指定次数
ping -c ${COUNT} ${IP}
# 格式化输出尾部分隔符
echo "====================================="
echo -e "\n"
```

## 五、Nginx核心配置（Ubuntu专属）

### 1\. 配置文件路径

新建专属配置文件：`/etc/nginx/sites\-available/web\-bash`

遵循Ubuntu规范：**只修改sites\-available，不直接改sites\-enabled**

### 2\. 完整Nginx配置代码

```nginx
server {
    # 新项目对外访问端口81
    listen 81;
    # 项目静态文件根目录（html所在路径）
    root /web-bash;
    # 默认首页文件
    index index.html;

    # 匹配所有静态资源请求，访问前端页面
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 接口反向代理：将前端接口请求转发到本地8001后端服务
    location /exec_bash {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 3\. Nginx配置生效命令

```bash
# 1. 创建软链接，启用站点配置
sudo ln -s /etc/nginx/sites-available/web-bash /etc/nginx/sites-enabled/

# 2. 检查配置语法是否报错
sudo nginx -t

# 3. 平滑重启Nginx生效
sudo systemctl restart nginx
```

## 六、环境依赖安装（解决DNS联网报错）

项目依赖 `python\-multipart` 解析表单数据，服务器默认DNS异常导致无法联网，需先修复DNS再安装依赖。

```bash
# 1. 修复服务器DNS解析故障
echo -e "nameserver 114.114.114.114\nnameserver 8.8.8.8" > /etc/resolv.conf

# 2. 国内镜像快速安装表单依赖
pip install python-multipart -i https://pypi.tuna.tsinghua.edu.cn/simple
```

## 七、项目启动与访问流程

### 1\. 启动后端服务

```bash
# 进入项目目录
cd /web-bash
# 启动后端服务，对外开放访问权限
uvicorn main:app --host 0.0.0.0 --port 8001
```

### 2\. 双项目访问地址

- 旧监控项目：`http://192\.168\.174\.137`（默认80端口，无需加端口）

- 新项目Ping测试：`http://192\.168\.174\.137:81`（81端口专属访问）

## 八、今日所有报错问题与解决方案（重点复盘）

### 1\. 端口占用报错 \[Errno 98\]

**报错原因**：新项目默认启动8000端口，与旧监控项目8000端口冲突

**解决方案**：新项目固定使用8001后端端口，彻底隔离冲突

### 2\. python\-multipart 依赖缺失报错

**报错原因**：FastAPI接收Form表单必须依赖该模块，系统默认未安装

**解决方案**：更换国内镜像源安装依赖

### 3\. DNS解析失败、pip联网超时

**报错原因**：服务器默认DNS配置异常，无法连接外网pip源

**解决方案**：手动覆盖resolv\.conf配置公共DNS

### 4\. 页面中文乱码

**报错原因**：HTML未声明编码格式，浏览器默认非UTF\-8解析

**解决方案**：添加 `\&lt;meta charset=\&\#34;UTF\-8\&\#34;\&gt;` 全局编码声明

### 5\. Nginx访问81端口404

**报错原因**：Nginx配置路径不匹配、未创建首页文件、配置未生效

**解决方案**：核对root路径、重建index\.html、重载Nginx配置

### 6\. 外部无法直接访问8001端口

**报错原因**：启动参数为 `127\.0\.0\.1`，仅服务器本地可访问

**解决方案**：改为 `0\.0\.0\.0` 监听所有网段，配合Nginx反向代理

## 九、项目核心总结

1. **架构规范**：严格遵循Ubuntu Nginx站点管理规范，双项目端口、配置、目录三重隔离，无任何冲突

2. **业务清晰**：前端负责数据展示与提交、后端负责逻辑分发、脚本负责命令执行，三层分工明确

3. **功能达标**：完美实现IP分级Ping测试逻辑，1/2/3次自定义次数适配需求

4. **问题闭环**：解决端口冲突、联网失败、乱码、404、依赖缺失等所有生产常见问题

5. **可扩展性强**：可批量新增IP、修改Ping规则，代码简洁易维护
