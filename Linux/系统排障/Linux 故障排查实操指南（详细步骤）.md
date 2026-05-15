# Linux 故障排查实操指南（详细步骤）

以下是三个核心任务的完整实验手册，建议在**虚拟机环境**中操作（避免影响主机）。

------

## 📋 实验前准备

| 项目     | 要求                                    |
| -------- | --------------------------------------- |
| **系统** | RedHat（CentOS） 7/8 或 Ubuntu 20.04+   |
| **权限** | root 或 sudo 权限                       |
| **软件** | Nginx、net-tools、tcpdump、htop、iostat |
| **快照** | 实验前对虚拟机打快照，方便恢复          |

### 安装必要工具

```bash
# CentOS
sudo yum install -y nginx net-tools tcpdump sysstat htop

# Ubuntu
sudo apt update
sudo apt install -y nginx net-tools tcpdump sysstat htop

# 启动 Nginx 并设置开机自启
sudo systemctl start nginx
sudo systemctl enable nginx
```

------

## 🔴 任务 A：模拟服务宕机与系统负载分析

### 目标

学会识别系统资源瓶颈（CPU/内存/磁盘IO），并定位异常进程。

### 步骤 1：制造故障场景

```bash
# 1.1 查看当前 Nginx 进程
ps -ef | grep nginx
# 记录 PID，例如：1234

# 1.2 故意杀掉 Nginx 主进程（模拟宕机）
sudo kill -9 1234  杀不掉，用systenctl stop 停止

# 1.3 验证服务已挂
curl http://localhost
# 预期：Connection refused
```

### 步骤 2：制造资源压力（可选进阶）

```bash
# 2.1 CPU 压力测试（安装 stress 工具）
sudo yum install -y stress  # CentOS
sudo apt install -y stress  # Ubuntu

# 启动 4 个 CPU 满载进程，持续 60 秒
stress --cpu 4 --timeout 60s &

# 2.2 内存压力测试
# 消耗 500MB 内存
stress --vm 1 --vm-bytes 500M --timeout 60s &

# 2.3 磁盘 IO 压力测试
# 持续写入大文件
dd if=/dev/zero of=/tmp/bigfile bs=1M count=2000 &
```

### 步骤 3：系统负载分析命令

| 命令            | 用途         | 关键指标                                |
| --------------- | ------------ | --------------------------------------- |
| `top`           | 实时进程监控 | `%CPU`, `%MEM`, `load average`          |
| `htop`          | 增强版 top   | 彩色显示，可交互杀进程                  |
| `free -m`       | 内存使用     | `available`, `buff/cache`               |
| `df -h`         | 磁盘空间     | `Use%` 超过 90% 需警惕                  |
| `iostat -x 2 5` | 磁盘 IO      | `%util` 超过 80% 表示 IO 瓶颈           |
| `vmstat 2 5`    | 综合系统状态 | `si/so` (swap 交换), `bi/bo` (磁盘读写) |

```bash
# 3.1 查看系统负载（重点看 load average）
top
# 解读：load average: 2.5, 1.8, 1.2
# 含义：1分钟/5分钟/15分钟平均负载
# 判断：如果数值 > CPU核心数，说明系统过载

# 3.2 查看内存（重点看 available）
free -m
#              total        used        free      shared  buff/cache   available
# Mem:           7982        4521         234          89        3227        3172
# 关键：available 才是真正可用内存，不是 free！

# 3.3 查看磁盘空间
df -h
# 关注 / 和 /var 分区，Use% > 90% 需要清理

# 3.4 查看磁盘 IO 性能
iostat -x 2 5
# 关注 %util 列，接近 100% 表示磁盘饱和
# 关注 await 列，数值越大 IO 延迟越高

# 3.5 查看占用最高的进程
ps aux --sort=-%cpu | head -10   # CPU 占用前10
ps aux --sort=-%mem | head -10   # 内存占用前10
```

### 步骤 4：恢复服务并记录

```bash
# 4.1 重启 Nginx
sudo systemctl start nginx

# 4.2 验证恢复
curl -I http://localhost
# 预期：HTTP/1.1 200 OK

# 4.3 清理压力测试进程
pkill stress          kill按id。pkill按名字
rm -f /tmp/bigfile
```

### 📝 排查报告模板（面试可用）

````
【故障现象】
- 服务无法访问，curl 返回 Connection refused
- 系统响应缓慢，SSH 登录有延迟

【排查过程】
1. 使用 top 发现 load average 达到 8.5（4核CPU），系统过载
2. 使用 ps aux --sort=-%cpu 发现 stress 进程占用 400% CPU
3. 使用 free -m 发现 available 内存仅剩 200MB
4. 使用 iostat 发现 /dev/sda %util 达到 95%，IO 饱和

【根因分析】
- 异常进程 stress 导致 CPU 和内存资源耗尽
- 磁盘大量写入导致 IO 瓶颈

【解决方案】
1. kill -9 异常进程 PID
2. 清理 /tmp 大文件
3. 重启受影响服务 nginx
4. 添加监控告警，防止再次发生

【预防措施】
- 配置系统资源限制（ulimit, cgroups）
- 部署 Prometheus + Alertmanager 监控告警





# 部署 Prometheus + Alertmanager 监控告警（零基础实操版）
我会用**最简洁、易上手的方式**带你完成部署，优先用 Docker 容器化部署（避免系统环境冲突），全程给出可直接复制的命令，新手也能搞定。

## 一、部署前准备
### 1. 环境要求
- 一台 Linux 服务器（Ubuntu/CentOS/RHEL 均可），建议 2C4G 以上；
- 已安装 Docker + Docker Compose（没有的话先执行下面的命令安装）：
  ```bash
  # 一键安装 Docker（国内源）
  curl -fsSL https://get.docker.com | bash -s docker --mirror 
  
  # 安装 Docker Compose
  curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  
  # 验证安装
  docker -v && docker compose -v
  ```

### 2. 目录规划（统一规范，避免混乱）
```bash
# 创建核心目录
mkdir -p /opt/prometheus/{config,data}
mkdir -p /opt/alertmanager/{config,data}
chmod 777 /opt/prometheus/data /opt/alertmanager/data  # ！！！！！！！！避免权限问题
```

## 二、第一步：编写配置文件
### 1. Prometheus 核心配置（/opt/prometheus/config/prometheus.yml）
```yaml
global:
  scrape_interval: 15s  # 全局采集间隔（每15秒拉取一次监控数据）
  evaluation_interval: 15s  # 规则评估间隔

# 告警规则文件（后续可新增）
rule_files:
  - "alert_rules.yml"

# 采集目标（监控哪些对象，先监控Prometheus自身）
scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]  # Prometheus自身的监控地址
  - job_name: "node-exporter"
    static_configs:
      - targets: ["node-exporter:9100"]

# 告警发送给Alertmanager
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]  # Alertmanager的容器名+端口
```

### 2. 告警规则文件（/opt/prometheus/config/alert_rules.yml）
先写一个简单的规则：Prometheus 进程挂了就告警，这个监控不到，Prometheus挂掉后，没人采集数据、计算规则、触发告警，需要引入外部监控
```yaml
groups:
- name: 基础监控告警
  rules:
  - alert: Prometheus进程宕机
    expr: up{job="prometheus"} == 0  # 核心表达式：prometheus的up指标为0（宕机）
    for: 10s  # 持续10秒触发告警（避免抖动）
    labels:
      severity: critical  # 告警级别：严重
    annotations:
      summary: "Prometheus进程异常"
      description: "Prometheus实例 {{ $labels.instance }} 已宕机，持续时间超过10秒！"
  # 2. 内存使用率过高告警
  - alert: 内存使用率过高
    expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "服务器 {{ $labels.instance }} 内存使用率过高"
      description: "当前内存使用率为 {{ $value | printf \"%.2f\" }}%，超过85%阈值！"

  # 3. 磁盘使用率过高告警
  - alert: 磁盘使用率过高
    expr: 100 - ((node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "服务器 {{ $labels.instance }} 磁盘使用率过高"
      description: "分区 {{ $labels.mountpoint }} 使用率为 {{ $value | printf \"%.2f\" }}%"
```

### 3. Alertmanager 配置（/opt/alertmanager/config/alertmanager.yml）
先配置「控制台输出」（新手先看告警效果，后续可加邮箱/钉钉/企业微信）：
```yaml
global:
  resolve_timeout: 5m  # 告警恢复后，5分钟标记为已解决

route:
  group_by: ['alertname']  # 按告警名称分组
  group_wait: 10s  # 组内等待10秒，合并同类型告警
  group_interval: 10s  # 组间间隔10秒
  repeat_interval: 1h  # 重复告警间隔（1小时重复一次）
  receiver: 'default-receiver'  # 默认接收者

receivers:
- name: 'default-receiver'
  # 控制台输出（测试用，生产环境替换为邮箱/钉钉等）
  webhook_configs:
    - url: 'http://localhost:9093/#/alerts'  # Alertmanager自身控制台

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
```

## 三、第二步：编写 Docker Compose 文件（一键启动）
找不到镜像
在/etc/docker/daemon.json里买写这个

！！！！！！！！！！
{
 "registry-mirrors": [
   "https://docker.m.daocloud.io",
   "https://hub-mirror.c.163.com"
 ]
}
！！！！！！！！！！！！！！
创建 `/opt/prometheus/docker-compose.yml`：
```yaml


services:
  prometheus:
    image: prom/prometheus:latest # 固定版本，避免兼容问题
    container_name: prometheus
    ports:
      - "9090:9090"  # 宿主机9090端口映射到容器
    volumes:
      - /opt/prometheus/config:/etc/prometheus  # 配置文件挂载
      - /opt/prometheus/data:/prometheus  # 数据持久化
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'  # 支持热加载配置（不用重启容器）
    restart: always  # 容器挂了自动重启
    networks:
      - monitor-net

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"  # Alertmanager控制台端口
    volumes:
      - /opt/alertmanager/config:/etc/alertmanager   ！！！！！！！这里一定要有目录/opt/alertmanager/config，要不就                                                                  添加 volumes块
      - /opt/alertmanager/data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    restart: always
    networks:
      - monitor-net
   
  node-exporter:
    image: docker.io/prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    # 挂载宿主机的 /proc /sys 等目录，保证采集的是服务器真实指标（不是容器内的）
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
    restart: always
    networks:
      - monitor-net     ！！！！！！这个一定要一致，再加其他插件也一定要一致
    privileged: true  # 提升权限，保证能采集所有系统指标
networks:
  monitor-net:
    driver: bridge
```

## 四、第三步：启动服务并验证
### 1. 启动容器
```bash
cd /opt/prometheus
docker-compose up -d  # 后台启动
```

### 2. 验证启动状态
```bash
# 查看容器是否运行
docker-compose ps

# 查看日志（无报错则正常）
docker-compose logs prometheus
docker-compose logs alertmanager
```

### 3. 访问控制台
- Prometheus 控制台：`http://服务器IP:9090`
  - 验证：点击「Status」→「Targets」，看到 `prometheus` 目标状态为 `UP`；
  - 测试指标：在搜索框输入 `up{job="prometheus"}`，点击「Execute」，能看到值为 `1`（正常）。
- Alertmanager 控制台：`http://服务器IP:9093`
  - 验证：点击「Alerts」，初始无告警（正常）。

## 五、第四步：测试告警功能（验证是否生效）
### 1. 手动停掉 Prometheus 触发告警
```bash
docker stop prometheus
```

### 2. 查看告警
- 等待 10 秒后，刷新 Alertmanager 控制台（`http://服务器IP:9093`），能看到「Prometheus进程宕机」的告警；
- 也可以在 Prometheus 控制台「Alerts」页面看到告警状态为 `FIRING`（触发中）。

### 3. 恢复 Prometheus
```bash
docker start prometheus
```
等待约 1 分钟，告警会自动标记为「Resolved」（已解决）。

## 六、进阶：配置实际告警渠道（替换控制台输出）
上面的「控制台输出」只是测试，生产环境需要配置邮箱/钉钉/企业微信，这里以**钉钉**为例（最常用）：

### 1. 钉钉机器人配置
- 打开钉钉群 → 群设置 → 智能群助手 → 添加机器人 → 选择「自定义机器人」；
- 复制机器人的「Webhook 地址」（比如 `https://oapi.dingtalk.com/robot/send?access_token=xxx`）；
- 关闭「加签」（新手先关，生产环境开启）。

### 2. 修改 Alertmanager 配置
修改 `/opt/alertmanager/config/alertmanager.yml`，替换 `receivers` 部分：
```yaml
receivers:
- name: 'default-receiver'
  webhook_configs:
    - url: 'https://oapi.dingtalk.com/robot/send?access_token=你的钉钉token'
      send_resolved: true  # 告警恢复后发送通知
```

### 3. 热加载配置（不用重启容器）
```bash
# 热加载Prometheus配置
curl -X POST http://服务器IP:9090/-/reload

# 热加载Alertmanager配置
curl -X POST http://服务器IP:9093/-/reload
```

## 七、常见问题排查
1. **容器启动失败**：检查目录权限（`chmod 777` 数据目录）、配置文件格式（YAML 不允许 tab 缩进，用空格）；
2. **告警不触发**：检查 Prometheus 告警规则语法（`docker-compose logs prometheus` 看报错）、`for` 时间是否满足；
3. **Alertmanager 收不到告警**：检查 Prometheus 配置中 `alertmanagers` 的地址是否正确（容器名 `alertmanager` 要和 Compose 里的服务名一致）。

---

### 总结
1. **核心流程**：编写配置文件 → Docker Compose 启动 → 验证控制台 → 测试告警 → 配置实际告警渠道；
2. **关键文件**：
   - Prometheus：`prometheus.yml`（采集目标+告警规则关联）、`alert_rules.yml`（告警规则）；
   - Alertmanager：`alertmanager.yml`（告警接收渠道）；
3. **核心特性**：容器化部署易维护，热加载配置不用重启，先测试控制台告警再替换实际渠道。

如果需要配置监控其他服务（比如服务器CPU/内存、MySQL、Nginx），或者配置邮箱/企业微信告警，我可以再补充对应的步骤~
````

------

## 🔴 任务 B：网络连通性排查（还原面试场景）

### 目标

掌握从物理层到应用层的网络排查链路。

### 步骤 1：制造网络故障

```bash
# 1.1 查看当前防火墙状态
sudo firewall-cmd --state
# 或
sudo systemctl status firewalld

# 1.2 阻断 80 端口（模拟防火墙问题）
sudo firewall-cmd --permanent --remove-service=http
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port port="80" protocol="tcp" reject'
sudo firewall-cmd --reload

# 或者直接用 iptables（更底层）
sudo iptables -A INPUT -p tcp --dport 80 -j DROP
```

### 步骤 2：分层排查流程（面试核心！）

```
┌─────────────────────────────────────────────────────────┐
│              网络排查七层模型（面试必背）                │
├─────────────────────────────────────────────────────────┤
│  物理层  →  网线/网卡灯亮吗？ifconfig 能看到网卡吗？     │
│  数据层  →  MAC 地址正常吗？arp -n 有缓存吗？           │
│  网络层  →  IP 通吗？ping 网关/目标 IP                  │
│  传输层  →  端口通吗？telnet/nc 测试端口               │
│  应用层  →  服务响应吗？curl -v 看 HTTP 响应            │
└─────────────────────────────────────────────────────────┘
# 2.1 第一层：检查本地网络接口
ip addr show
# 或
ifconfig
# 确认：网卡有 IP 地址，状态 UP

# 2.2 第二层：检查路由
ip route show
# 或
route -n
# 确认：有默认网关（default via xxx）

# 2.3 第三层：测试 ICMP 连通性
ping -c 4 8.8.8.8        # 测试外网
ping -c 4 192.168.1.1    # 测试网关
ping -c 4 localhost      # 测试本地协议栈

# 预期现象：
# - 外网不通但网关通 → 可能是 NAT/路由问题
# - 网关都不通 → 本地网络配置问题

# 2.4 第四层：测试端口连通性（关键！）
telnet 192.168.1.100 80
# 或（推荐，更强大）
nc -zv 192.168.1.100 80
# 或
curl -v http://192.168.1.100:80

# 预期现象：
# - telnet 连接后立刻断开 → 端口被防火墙 DROP
# - telnet Connection refused → 服务没启动
# - telnet 能连接 → 网络层正常

# 2.5 第五层：查看本地监听端口
ss -ntulp | grep 80
# 或
netstat -ntulp | grep 80
# 确认：80 端口有进程监听（应该是 nginx）

# 2.6 第六层：抓包分析（终极武器）
sudo tcpdump -i any -n port 80 -vv
# 然后在另一个终端发起请求
curl http://localhost:80

# 预期现象：
# - 看到 SYN 包但没有 SYN-ACK → 防火墙丢弃
# - 看到完整三次握手 → 网络正常，问题在应用层
# - 看到 HTTP 4xx/5xx → 应用层错误

# 2.7 第七层：检查防火墙规则
sudo firewall-cmd --list-all
# 或
sudo iptables -L -n -v

# 找到 DROP/REJECT 规则
```

### 步骤 3：修复并验证

```bash
# 3.1 修复防火墙（firewalld）
sudo firewall-cmd --permanent --remove-port=80/tcp
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload

# 3.2 修复防火墙（iptables）
sudo iptables -D INPUT -p tcp --dport 80 -j DROP

# 3.3 验证修复
curl -I http://localhost
# 预期：HTTP/1.1 200 OK

nc -zv localhost 80
# 预期：succeeded!
```

### 📝 面试话术模板

```
【面试官】：客户端无法访问服务端，你怎么排查？

【回答】：
我会按照 OSI 模型从下到上逐层排查：

第一步，物理层检查。用 ifconfig 或 ip addr 确认网卡状态是 UP，
有正确的 IP 地址。

第二步，网络层检查。用 ping 测试网关和目标 IP，确认路由可达。
如果 ping 不通网关，说明本地网络配置有问题。

第三步，传输层检查。用 telnet 或 nc 测试目标端口是否开放。
如果 ping 通但端口不通，大概率是防火墙问题。

第四步，本地服务检查。用 ss -ntulp 确认本机有进程监听该端口。
如果没监听，说明服务没启动或配置错了监听地址。

第五步，防火墙检查。用 iptables -L 或 firewall-cmd --list-all 
查看是否有 DROP/REJECT 规则。

第六步，抓包分析。如果以上都正常，用 tcpdump 抓包看请求是否
到达本机，以及响应是否发出。

实际工作中，80% 的网络问题是防火墙或服务未启动导致的。
```

------

## 🔴 任务 C：日志分析与磁盘故障排查

### 目标

学会通过日志定位系统问题，处理磁盘空间不足故障。

### 步骤 1：制造磁盘满故障

```bash
# 1.1 查看当前磁盘使用
df -h

# 1.2 制造大文件占满磁盘（谨慎操作！）
# 先创建一个 1GB 的测试文件
sudo dd if=/dev/zero of=/var/log/test_bigfile bs=1M count=1024

# 如果空间还不够，继续创建
sudo dd if=/dev/zero of=/var/log/test_bigfile2 bs=1M count=1024

# 1.3 验证磁盘已满
df -h
# 预期：Use% 达到 95% 以上

# 1.4 尝试重启 Nginx（会失败）
sudo systemctl restart nginx
# 预期：Job failed，因为无法写入 pid 文件
```

### 步骤 2：日志分析命令

| 日志文件                   | 用途                    | 关键命令           |
| -------------------------- | ----------------------- | ------------------ |
| `/var/log/messages`        | 系统通用日志（CentOS）  | `tail -f`, `grep`  |
| `/var/log/syslog`          | 系统通用日志（Ubuntu）  | `tail -f`, `grep`  |
| `/var/log/secure`          | 安全/登录日志           | `grep "Failed"`    |
| `/var/log/nginx/error.log` | Nginx 错误日志          | `tail -f`          |
| `journalctl`               | 系统服务日志（systemd） | `-u 服务名`, `-xe` |

```bash
# 2.1 查看系统日志（找错误关键词）
sudo tail -100 /var/log/messages | grep -i "error"
sudo tail -100 /var/log/messages | grep -i "fail"

# 2.2 查看 Nginx 错误日志
sudo tail -50 /var/log/nginx/error.log
# 预期：可能看到 "No space left on device"

# 2.3 使用 journalctl 查询服务日志
sudo journalctl -u nginx -n 50 --no-pager
# -u: 指定服务
# -n: 显示行数
# --no-pager: 不分页

# 2.4 实时跟踪日志（调试用）
sudo journalctl -f -u nginx
# 按 Ctrl+C 退出

# 2.5 查找特定时间段的日志
sudo journalctl -u nginx --since "2024-01-01 00:00:00" --until "2024-01-01 23:59:59"

# 2.6 查看磁盘空间占用详情
sudo du -sh /var/log/* | sort -hr | head -10
# 找出占用最大的日志目录

# 2.7 查找大文件
sudo find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null
# 找出大于 100MB 的文件
```

### 步骤 3：定位并解决问题

```bash
# 3.1 确认错误信息
sudo journalctl -u nginx -n 20 --no-pager
# 预期看到：
# "nginx: [emerg] open() "/run/nginx.pid" failed (28: No space left on device)"

# 3.2 定位大文件
sudo du -sh /var/log/* | sort -hr | head -10

# 3.3 安全清理日志（不要直接 rm！）
# 方法 1：清空文件内容（保留文件 inode）
sudo echo "" > /var/log/test_bigfile
sudo echo "" > /var/log/nginx/access.log
sudo echo "" > /var/log/nginx/error.log

# 方法 2：使用 logrotate 轮转
sudo logrotate -f /etc/logrotate.d/nginx

# 方法 3：压缩归档后删除
sudo gzip /var/log/test_bigfile
sudo rm /var/log/test_bigfile.gz

# 3.4 验证空间释放
df -h
# 预期：Use% 下降到合理范围

# 3.5 重启服务
sudo systemctl start nginx
sudo systemctl status nginx
# 预期：Active: active (running)

# 3.6 验证服务恢复
curl -I http://localhost
```

### 步骤 4：配置日志轮转（预防措施）

```bash
# 4.1 查看 logrotate 配置
sudo cat /etc/logrotate.d/nginx

# 4.2 编辑配置（可选）
sudo vi /etc/logrotate.d/nginx

# 典型配置：
/var/log/nginx/*.log {
    daily                   # 每天轮转
    missingok               # 日志缺失不报错
    rotate 14               # 保留 14 个备份
    compress                # 压缩旧日志
    delaycompress           # 延迟一天压缩
    notifempty              # 空日志不轮转
    create 0640 nginx adm   # 新建日志权限
    sharedscripts           # 所有日志轮转后执行一次脚本
    postrotate
        [ -f /run/nginx.pid ] && kill -USR1 `cat /run/nginx.pid`
    endscript
}

# 4.3 手动测试轮转
sudo logrotate -d /etc/logrotate.d/nginx  # 调试模式（不实际执行）
sudo logrotate -f /etc/logrotate.d/nginx  # 强制执行
```

### 📝 面试话术模板

```
【面试官】：服务启动失败，你怎么通过日志排查？

【回答】：
首先，我会用 systemctl status 查看服务状态和简要错误信息。

然后，用 journalctl -u 服务名 -n 50 查看详细日志，
重点关注 error、fail、critical 等关键词。

如果是磁盘问题，常见错误是 "No space left on device"，
这时我会用 df -h 确认磁盘使用率，用 du -sh 找出占用最大的目录。

清理日志时，我不会直接 rm 删除文件，因为进程可能还持有
文件句柄，空间不会释放。我会用 echo "" > 文件 的方式清空内容，
或者用 logrotate 进行规范的日志轮转。

解决问题后，我会配置 logrotate 防止再次发生，并添加
磁盘使用率监控告警，超过 80% 就通知运维团队。
```

------

## 📊 综合排查流程图（面试可画）

```
                    ┌─────────────────┐
                    │   服务不可用    │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │ 系统资源 │  │  网络    │  │  日志    │
        └────┬─────┘  └────┬─────┘  └────┬─────┘
             │             │             │
        ┌────▼─────┐  ┌────▼─────┐  ┌────▼─────┐
        │top/free  │  │ping/telnet│  │journalctl│
        │df/iostat │  │ss/tcpdump │  │tail/grep │
        └────┬─────┘  └────┬─────┘  └────┬─────┘
             │             │             │
             └──────────────┼──────────────┘
                            │
                    ┌───────▼───────┐
                    │   定位根因    │
                    └───────┬───────┘
                            │
                    ┌───────▼───────┐
                    │   修复验证    │
                    └───────┬───────┘
                            │
                    ┌───────▼───────┐
                    │   预防配置    │
                    │ (监控/告警)   │
                    └───────────────┘
```

------

## ✅ 实验完成检查清单

| 任务   | 完成标志                  | 面试能说出                                             |
| ------ | ------------------------- | ------------------------------------------------------ |
| 任务 A | 能独立分析 load/memory/io | "我用 top 发现 CPU 95%，用 ps 找到异常进程"            |
| 任务 B | 能分层排查网络问题        | "我按 OSI 七层从 ping 到 telnet 到 curl 逐层定位"      |
| 任务 C | 能通过日志找到根因        | "我在 journalctl 看到 No space left，用 du 找到大文件" |

------

## 💡 进阶建议

1. **搭建监控系统**：学习 Prometheus + Grafana，把上述指标可视化
2. **编写自动化脚本**：把排查命令写成 shell 脚本，一键诊断
3. **学习 Ansible**：批量管理多台服务器的故障排查
4. **考取认证**：RHCE（红帽）、CKA（K8s）都有大量实操考题

完成这三个任务后，你的 Linux 实操能力会有质的飞跃，面试时也能有底气说出具体的命令和排查思路！