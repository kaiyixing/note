# Nginx 使用与排错

> 关联：[[网络/负载均衡（nginx-LVS-HAProxy）/__学习方向|负载均衡学习方向]] · [[LVS]] · [[HAProxy]]

## 核心指令速查

| 指令 | 说明 |
|------|------|
| `worker_processes` / `worker_connections` | 并发模型；epoll 模型下每 worker 可连接数 |
| `proxy_pass` | 反向代理到 `upstream`；**末尾 `/` 决定是否吃掉 location 前缀** |
| `proxy_set_header` | 透传 `Host` / `X-Real-IP` / `X-Forwarded-For` |
| `proxy_read_timeout` | 读后端超时，默认 60s |
| `limit_req` / `limit_conn` | 限流（按 key 限速率/并发） |
| `client_max_body_size` | 请求体上限，默认 1m（上传超限 → 413） |
| `gzip` / `keepalive_timeout` | 压缩 / 长连接保持 |
| `error_log ... warn;` | 日志级别 |

## 常用配置模板

```nginx
http {
  upstream backend {
    server 127.0.0.1:8080 weight=3;
    server 127.0.0.1:8081;
  }
  server {
    listen 80;
    location /api/ {
      proxy_pass http://backend/;   # 末尾/：/api/x → 后端 /x
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_read_timeout 60s;
    }
    location / {
      root /var/www/html;
      index index.html;
    }
  }
}
```

Location 匹配优先级：`=` 精确 > 前缀最长匹配 > `~`/`~*` 正则 > 普通前缀 > `/`。

## 诊断与运维命令

```bash
nginx -t                 # 语法校验（必须 reload 前跑）
nginx -s reload          # 平滑重载，不断连
systemctl status nginx
ss -lntp | grep ':80'    # 确认端口监听
curl -I http://127.0.0.1 # 本地探活
tail -f /var/log/nginx/error.log
journalctl -u nginx -n 50 --no-pager
```

日志分析：
```bash
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -nr   # 状态码分布
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr   # 高频 IP
awk '$7 ~ /api\/v1/' /var/log/nginx/access.log                            # 按 URI 过滤
```

## 典型故障排查

| 现象 | 常见原因 | 处理 |
|------|----------|------|
| 配置改了不生效 | `nginx -t` 报错被吞 / 没 reload / include 没生效 | `nginx -t` 后 `nginx -s reload`，确认 include 路径 |
| 前缀被吃掉或没吃 | `proxy_pass` 末尾 `/` 写错 | 带 URI 部分会做前缀替换，不带则原样转发 |
| **502 Bad Gateway** | 后端挂了 / 端口没监听 / upstream 地址错 | `curl` 探后端、`systemctl status`、改 upstream |
| **504 Gateway Timeout** | 后端响应 > `proxy_read_timeout`（60s） | 调大超时或优化后端；区分 connect/read 超时 |
| **503** | `limit_req`/`limit_conn` 触发、upstream 被标不可用 | 看 `limit_req_status` 变量与后端健康 |
| **413** | `client_max_body_size` 默认 1m | 调大该指令 |
| **403/404** | root/index 错、文件权限、SELinux 上下文 | `ls -Z`、`restorecon -Rv`，检查 `index`/`try_files` |
| CPU 高 / worker 卡 | `worker_connections` 过小、keepalive、正则回溯 | 调 `worker_connections`、`limit_conn`，优化 location |

## 进阶要点

- **SSL 终止**：证书放 LB 层，`proxy_ssl_server_name on`；HSTS `Strict-Transport-Security`
- **动静分离**：静态 `try_files` + `expires 30d`，动态 `proxy_pass`
- **限流**：`limit_req_zone` 定义速率 + `limit_req` 应用，按 IP/会话 key
- **健康检查**：原生仅被动（`max_fails`/`fail_timeout`），主动用 `nginx_upstream_check` 或换 HAProxy/Ingress
- **蓝灰发布**：upstream 权重调整做灰度

---
*更新时间：2026-09-11*
