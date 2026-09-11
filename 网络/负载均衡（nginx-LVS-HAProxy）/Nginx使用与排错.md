# Nginx 使用与排错

> 关联：[[网络/负载均衡（nginx-LVS-HAProxy）/__学习方向|负载均衡学习方向]] · [[LVS]] · [[HAProxy]]

## 一、先建立心智模型

把 Nginx 想象成一个**餐厅的前台/传菜台**：

- **客户端**（用户浏览器）把"点单"（HTTP 请求）交给前台。
- Nginx 是**前台 + 传菜台**：
  - 它自己**能直接上的菜**（静态文件 `root`/`index`）——直接端走。
  - 它**自己不会做的菜**（动态接口 `/api`）——把单子传给**后厨**（`proxy_pass` 到后端服务，比如 Java/Go 应用），再把菜端回来。
- **upstream** = 后厨里的一群厨师（多个后端节点），前台按策略（轮询/权重）决定这次叫哪个厨师做。

关键结论：Nginx 既是**静态服务器**，也是**反向代理 / 负载均衡器**。排错时先分清"这个请求是 Nginx 自己处理的，还是转发给后端的"——**静态问题 99% 出在 Nginx 配置，动态问题 99% 出在后端或转发参数。**

### 配置分层（看懂 `nginx.conf` 结构）
```
main（worker 数等）
 └─ events（连接模型）
 └─ http（全局 HTTP 设置）
     └─ upstream（定义一组后端）
     └─ server（一个虚拟主机 / 一个站点）
         └─ location（一个路径块，决定怎么处理某类请求）
```
排错时，**先定位到是哪个 `location` 块**，再查该块指令。

## 二、最核心、最易错的点：`proxy_pass` 末尾的 `/`

这是 Nginx 新手第一号坑。规则：

- `proxy_pass http://backend/;`（带 URI `/`）→ **前缀会被替换掉**。`location /api/` 收到 `/api/user`，转发给后端的是 `/user`（把 `/api` 吃掉了）。
- `proxy_pass http://backend;`（不带 URI）→ **原样转发**。`/api/user` 还是 `/api/user` 发给后端。

> 记忆点：**带 `/` 就"吃前缀"，不带就"原样搬"。** 后端 404 时优先怀疑这里写错。

### 三个必透传的请求头
后端常依赖这些头拿到真实信息，反向代理后不手动设置会"失真"：
```nginx
proxy_set_header Host $host;                      # 后端拿到的是原域名，不是 IP
proxy_set_header X-Real-IP $remote_addr;           # 客户端真实 IP
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;  # 经过的代理链
```

## 三、Location 匹配优先级（排 404/403 的关键）

请求进来，Nginx 按**固定顺序**选 location：
1. `= /exact` 精确匹配（命中即停，最高）
2. 前缀匹配里**最长**的那个（普通 `location /a/b`）
3. `~` / `~*` 正则匹配（按书写顺序第一个命中）
4. 普通前缀、最后兜底 `/`

> 坑点：正则优先级高于普通前缀。你以为命中 `/api`，实际被某个正则 `~ \.php$` 抢先匹配走了。

## 四、诊断与运维命令（及为什么用它）

```bash
nginx -t              # 语法校验。改配置后【必须】先跑，报错说明配置本身有问题
nginx -s reload       # 平滑重载：老连接处理完再切新配置，不断流（比 restart 好）
systemctl status nginx # 服务是否活着
ss -lntp | grep ':80'  # 确认 80 端口确实被 nginx 监听（端口被别的占了也会异常）
curl -I http://127.0.0.1  # 本地探活，绕开外网问题
tail -f /var/log/nginx/error.log   # 错误日志（配错/后端连不上都在这）
journalctl -u nginx -n 50 --no-pager  # systemd 视角的日志
```

### 日志分析（access.log 常用）
access.log 默认各列：`$1`=IP、`$7`=请求URI、`$9`=状态码。
```bash
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -nr   # 各状态码出现次数（看 5xx 占比）
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr   # 哪些 IP 访问最多（排查攻击/爬虫）
awk '$7 ~ /api\/v1/' /var/log/nginx/access.log                            # 只看某类 URI 的请求
```

## 五、典型故障：现象 → 原因 → 处理

| 现象 | 根因 | 处理 |
|------|------|------|
| 改配置不生效 | `nginx -t` 报错被忽略 / 没 reload / include 路径不对 | `nginx -t` 通过 → `nginx -s reload`，确认 include 指向 |
| 后端 404 | `proxy_pass` 末尾 `/` 写错，前缀被吃了或没吃 | 按第二节规则核对带不带 `/` |
| **502 Bad Gateway** | 后端挂了 / 端口没监听 / upstream 地址写错 | `curl` 直接探后端、`systemctl status` 后端、改 upstream |
| **504 Gateway Timeout** | 后端响应慢，超过 `proxy_read_timeout`（默认 60s） | 调大超时（治标）或优化后端（治本）；区分"连不上"与"连上后读慢" |
| **503** | `limit_req`/`limit_conn` 限流触发，或 upstream 全不可用 | 看限流配置与后端健康 |
| **413** | 上传体积超 `client_max_body_size`（默认仅 1m） | `client_max_body_size 100m;` |
| **403** | 目录无读权限 / `index` 缺 / **SELinux 阻止** | `ls -Z` 看上下文、`restorecon -Rv`；检查目录权限 |
| **404** | root 路径错 / location 没匹配到（被正则抢先） | 核对 `root`、按第三节优先级排查 |
| CPU 高 / worker 卡 | `worker_connections` 太小 / keepalive 不合理 / 正则回溯 | 调 `worker_connections`、`limit_conn`，简化正则 |

> 排错顺序口诀：**先看是不是静态（root/index/权限）还是动态（502/504 看后端）→ 再看 4xx 多半是 location/权限 → 最后 5xx 一定查后端或转发参数。**

## 六、进阶要点（含一句话原理）

- **SSL 终止**：证书放在 Nginx 层做 HTTPS 加解密，后端只跑明文 HTTP，省后端性能。配合 HSTS `Strict-Transport-Security` 强制走 HTTPS。
- **动静分离**：静态文件 `try_files` + `expires 30d`（浏览器缓存），动态走 `proxy_pass`，互不拖累。
- **限流**：`limit_req_zone` 先定义"每 key 每秒多少请求"，`limit_req` 再应用；按 IP 或会话做 key，防突发打挂后端。
- **健康检查**：Nginx 原生只有**被动**健康检查（`max_fails`/`fail_timeout`——失败了才摘除），要**主动**探活需用 `nginx_upstream_check` 模块，或干脆换 HAProxy / K8s Ingress。
- **蓝灰发布**：调 upstream 里各后端**权重**，灰度流量按比例切到新版本，出问题秒回滚。

## 七、最小可用配置模板（带注释）

```nginx
http {
  upstream backend {                # 定义一组后端（"后厨厨师"）
    server 127.0.0.1:8080 weight=3;  # 权重3：4个请求里3个给它（灰度主力）
    server 127.0.0.1:8081;            # 默认权重1
  }
  server {
    listen 80;                        # 监听 80
    location /api/ {
      proxy_pass http://backend/;     # 末尾/：吃掉 /api 前缀，后端收到 /user
      proxy_set_header Host $host;    # 透传真实信息
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_read_timeout 60s;         # 读后端超时
    }
    location / {                      # 兜底：静态文件
      root /var/www/html;
      index index.html;
    }
  }
}
```

---
*更新时间：2026-09-11*
