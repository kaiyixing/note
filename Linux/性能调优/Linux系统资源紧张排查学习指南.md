# Linux 系统资源紧张排查学习指南

> 面向初学者，系统讲解 CPU、内存、磁盘 I/O、网络四大核心资源的排查思路与实战命令。

---

## 目录

1. [排查总览：建立系统思维](#1-排查总览建立系统思维)
2. [CPU 资源紧张排查](#2-cpu-资源紧张排查)
3. [内存资源紧张排查](#3-内存资源紧张排查)
4. [磁盘 I/O 紧张排查](#4-磁盘-io-紧张排查)
5. [网络资源紧张排查](#5-网络资源紧张排查)
6. [综合排查流程与实战案例](#6-综合排查流程与实战案例)
7. [进阶工具与学习路线](#7-进阶工具与学习路线)

---

## 1. 排查总览：建立系统思维

### 1.1 什么是"系统资源紧张"？

当服务器出现以下现象时，通常意味着某种资源紧张：

| 现象 | 可能的原因 |
|------|-----------|
| 服务响应变慢、超时 | CPU、内存、磁盘 I/O、网络任一瓶颈 |
| 系统负载飙高 | CPU 计算压力大或大量进程等待 I/O |
| 应用报错 OOM Killed | 内存不足，系统强制杀进程 |
| 磁盘读写卡顿 | I/O 瓶颈或磁盘故障 |
| 网络连接失败/丢包 | 带宽打满、连接数耗尽、防火墙限制 |

### 1.2 排查的黄金法则

```
先观察，再定位，最后处理
```

**第一步：快速感知** → 用 `top` / `df -h` / `free -m` 等命令快速看一眼全局状态。

**第二步：定位瓶颈** → 根据症状缩小范围，确定是 CPU / 内存 / 磁盘 / 网络中的哪一个。

**第三步：深入分析** → 用针对性工具找到具体是哪个进程、哪个指标出了问题。

**第四步：处理与验证** → 采取行动后，持续观察确认问题是否解决。

### 1.3 四大资源速查表

| 资源类型 | 快速查看命令 | 关键指标 |
|---------|------------|---------|
| CPU | `top`、`uptime` | load average、%CPU、%wa |
| 内存 | `free -h`、`top` | available、used、buff/cache、swap |
| 磁盘 | `df -h`、`iostat -x 1` | 使用率、%util、await |
| 网络 | `sar -n DEV 1`、`netstat` | 流量、丢包、连接数 |

---

## 2. CPU 资源紧张排查

### 2.1 理解 CPU 的关键概念

- **用户态（user）**：应用程序自身消耗的 CPU
- **内核态（system/sys）**：系统调用、内核操作消耗的 CPU
- **I/O 等待（iowait/wa）**：CPU 等待磁盘 I/O 完成的比例
- **负载均衡（load average）**：单位时间内处于可运行状态和不可中断状态的平均进程数
- **上下文切换（cs）**：CPU 在不同进程间切换的次数，过高说明调度压力大

### 2.2 排查步骤

#### 第一步：看整体负载

```bash
# 查看系统负载（1分钟、5分钟、15分钟平均值）
uptime
# 输出示例: 14:30:01 up 30 days, load average: 8.52, 5.10, 3.20

# 判断标准：load average 不应持续超过 CPU 核心数
# 查看核心数
nproc
# 或
grep 'model name' /proc/cpuinfo | wc -l
```

> **经验值**：load average 持续 > CPU 核心数 × 0.7 就需要关注，持续 > 核心数说明已经过载。

#### 第二步：看 CPU 使用率分布

```bash
# 实时查看 CPU 各项指标（每1秒刷新）
vmstat 1
# 关注列：
#   us - 用户态CPU使用率
#   sy - 内核态CPU使用率
#   id - 空闲率（越低说明越忙）
#   wa - I/O等待率（>20%说明I/O可能是瓶颈）
#   cs - 上下文切换次数
```

```bash
# 查看每个 CPU 核心的使用情况
mpstat -P ALL 1
```

#### 第三步：定位消耗 CPU 最高的进程

```bash
# 方法一：top 命令（最常用）
top
# 按 CPU 排序：按 Shift+P
# 常用快捷键：
#   Shift+P - 按CPU排序
#   Shift+M - 按内存排序
#   c       - 显示完整命令
#   1       - 显示所有CPU核心

# 方法二：htop（更直观，需安装）
htop
# F5 - 树形视图，方便看父子进程关系
# F6 - 选择排序字段
# F9 - 杀进程

# 方法三：精确查找
# 查看指定进程的 CPU 使用
pidstat -u 1
# 查看指定进程的线程级 CPU 使用
pidstat -t -p <PID> 1
```

### 2.3 常见 CPU 问题及处理

| 现象 | 可能原因 | 处理方法 |
|------|---------|---------|
| us 持续很高 | 业务程序计算量大 | 优化代码、扩容、限流 |
| sy 持续很高 | 大量系统调用或线程切换 | 减少线程数、检查锁竞争 |
| wa 持续很高 | 磁盘 I/O 慢，CPU 在等 | 转到磁盘排查章节 |
| cs（上下文切换）极高 | 进程/线程数过多 | 减少线程数、使用连接池 |
| load 高但 CPU 空闲 | 大量进程处于 D 状态（等待I/O） | 转到磁盘排查章节 |

### 2.4 实战技巧

```bash
# 找出 CPU 占用 Top 10 的进程
ps aux --sort=-%cpu | head -11

# 找出某个用户的所有进程 CPU 占用
top -u username

# 持续记录 CPU 状态（便于事后分析）
sar -u 1 10 > cpu_report.log
```

---

## 3. 内存资源紧张排查

### 3.1 理解 Linux 内存管理

Linux 的内存管理与 Windows 有很大不同，理解以下概念至关重要：

```
┌─────────────────────────────────────────┐
│              物理内存总量                │
├──────────┬──────────┬───────────────────┤
│  已使用   │  Buff/   │     可用          │
│  (used)  │  Cache   │   (available)     │
│          │          │                   │
│ 应用程序  │ 系统缓存  │ 可被应用使用的     │
│ 正在使用  │ 加速读写  │  内存（含可回收    │
│ 的内存    │          │  的缓存）          │
└──────────┴──────────┴───────────────────┘
```

> **关键理解**：`free` 命令中的 `buff/cache` 是可以被回收的，真正要看的是 **available**（可用内存），而不是 `free`。

### 3.2 排查步骤

#### 第一步：看内存整体状态

```bash
# 查看内存使用概况（推荐）
free -h
# 输出示例：
#               total    used    free   shared  buff/cache  available
# Mem:           7.8G    5.2G    256M    128M       2.3G       2.1G
# Swap:          2.0G    1.8G     0B

# 关键指标：
#   available - 真正可用的内存（最重要！）
#   used      - 应用实际使用的内存
#   buff/cache- 系统缓存（可回收）
#   Swap used - 交换分区使用量（用了就说明内存紧张）
```

```bash
# 更详细的内存信息
cat /proc/meminfo
# 关注：
#   MemAvailable - 可用内存
#   MemTotal     - 总内存
#   SwapTotal / SwapFree - 交换分区
#   Hugepages_*  - 大页内存（数据库常用）
```

#### 第二步：定位占用内存最多的进程

```bash
# 方法一：top 按内存排序
top
# 按 Shift+M 按内存使用排序

# 方法二：精确查看
ps aux --sort=-%mem | head -11

# 方法三：pidstat 查看进程内存详情
pidstat -r 1
# 输出列说明：
#   minflt/s - 次缺页中断（正常）
#   majflt/s - 主缺页中断（高说明需要从磁盘读数据，内存紧张）
#   RSS      - 实际物理内存占用
#   %MEM     - 内存使用百分比
```

#### 第三步：检查 Swap 使用情况

```bash
# 查看 Swap 使用详情
swapon --show

# 查看哪些进程在使用 Swap
for file in /proc/*/status; do
    awk '/VmSwap|Name/{printf $2 " " $3}END{print ""}' "$file" 2>/dev/null
done | grep -v "^$ 0 kB" | sort -k2 -n -r | head -10

# 或者用这个更简洁的方式
grep -H VmSwap /proc/*/status 2>/dev/null | sort -t: -k2 -n -r | head -10
```

### 3.3 常见内存问题及处理

| 现象 | 可能原因 | 处理方法 |
|------|---------|---------|
| available 持续很低 | 内存泄漏、应用内存需求大 | 排查泄漏、扩容、优化配置 |
| Swap 使用量持续增长 | 物理内存不足 | 扩容、优化应用内存使用 |
| OOM Killer 触发 | 内存耗尽，内核杀进程 | 查看日志、调整 oom_score、扩容 |
| majflt/s 很高 | 内存不足导致频繁换页 | 增加内存、减少内存使用 |
| buff/cache 占用过大 | 系统缓存过多 | 可手动清理（通常不需要） |

### 3.4 OOM（Out of Memory）排查

```bash
# 查看 OOM 事件记录
dmesg | grep -i "oom\|killed process"
# 或
journalctl -k | grep -i "oom"

# 查看当前 OOM 打分（分数越高越容易被杀）
cat /proc/<PID>/oom_score

# 查看系统 OOM 配置
cat /proc/sys/vm/overcommit_memory
# 0 - 默认，启发式判断
# 1 - 允许分配所有物理内存+swap
# 2 - 严格模式，不超过 swap + overcommit_ratio * RAM

# 保护重要进程不被 OOM Kill
echo -1000 > /proc/<PID>/oom_score_adj
```

### 3.5 实战技巧

```bash
# 查看所有进程的内存汇总（按用户）
ps aux | awk '{arr[$1]+=$6} END {for (i in arr) print i, arr[i]/1024 "MB"}' | sort -k2 -n -r

# 清理系统缓存（谨慎使用，通常不需要）
echo 1 > /proc/sys/vm/drop_caches  # 清除页面缓存
echo 2 > /proc/sys/vm/drop_caches  # 清除目录项和inode缓存
echo 3 > /proc/sys/vm/drop_caches  # 清除所有缓存

# 持续监控内存
sar -r 1 10 > mem_report.log
```

---

## 4. 磁盘 I/O 紧张排查

### 4.1 理解磁盘 I/O 关键概念

- **IOPS**：每秒 I/O 操作次数（随机读写的关键指标）
- **吞吐量（Throughput）**：每秒读写的数据量（顺序读写的关键指标）
- **延迟（Latency/await）**：I/O 请求从发出到完成的等待时间
- **队列长度（avgqu-sz）**：等待处理的 I/O 请求数量
- **利用率（%util）**：磁盘忙于处理 I/O 的时间百分比

### 4.2 排查步骤

#### 第一步：看磁盘空间

```bash
# 查看各分区使用率
df -h
# 关注 Use% 列，> 85% 就需要关注

# 查看指定目录的磁盘占用
du -sh /var/log/*
du -sh /tmp/*

# 查找大文件（>100MB）
find / -type f -size +100M 2>/dev/null | xargs ls -lhS

# 查找被删除但仍占用空间的文件（常见问题！）
lsof +L1 2>/dev/null
# 或
lsof | grep deleted
```

> **常见坑**：文件被 `rm` 删除后，如果还有进程持有文件句柄，磁盘空间不会释放。解决方法是重启对应进程或 `kill` 掉占用句柄的进程。

#### 第二步：看磁盘 I/O 性能

```bash
# 查看 I/O 性能（需安装 sysstat）
iostat -x 1
# 关键列说明：
#   %util   - 磁盘利用率（>80% 说明磁盘可能成为瓶颈）
#   await   - I/O 平均等待时间（ms），一般应 < 10ms（SSD）或 < 20ms（HDD）
#   avgqu-sz- 平均队列长度（>2 说明有排队）
#   r/s w/s - 每秒读/写次数
#   rkB/s wkB/s - 每秒读/写的数据量
#   r_await w_await - 读/写平均等待时间

# 只看特定磁盘
iostat -x /dev/sda 1
```

```bash
# 实时查看哪些进程在进行 I/O（需安装 iotop）
iotop
# 常用快捷键：
#   o - 只显示有 I/O 活动的进程
#   p - 只显示进程（不显示线程）
#   a - 显示累计 I/O（而非速率）
```

#### 第三步：综合判断

```bash
# vmstat 查看 I/O 整体情况
vmstat 1
# 关注列：
#   bi - 每秒从块设备读入的块数
#   bo - 每秒写入块设备的块数
#   wa - CPU I/O 等待时间占比

# 查看系统 I/O 调度器（影响 I/O 性能）
cat /sys/block/sda/queue/scheduler
# 常见调度器：
#   noop      - 适合SSD
#   deadline  - 适合通用场景
#   cfq       - 适合桌面（已逐渐被bfq替代）
#   mq-deadline - 现代内核默认
```

### 4.3 常见磁盘问题及处理

| 现象 | 可能原因 | 处理方法 |
|------|---------|---------|
| %util 持续 > 80% | 磁盘 I/O 饱和 | 升级 SSD、优化读写、使用缓存 |
| await 持续很高 | 磁盘响应慢 | 检查磁盘健康、更换磁盘 |
| 磁盘空间满 | 日志/临时文件堆积 | 清理、配置日志轮转 |
| 删除文件空间不释放 | 进程持有文件句柄 | 重启进程或清理句柄 |
| I/O 队列长 | 大量并发读写 | 优化应用 I/O 模式、使用队列 |

### 4.4 实战技巧

```bash
# 查看 inode 使用情况（有时空间没满但 inode 满了）
df -i

# 查看磁盘健康状态（需安装 smartmontools）
smartctl -a /dev/sda

# 持续监控 I/O
sar -d 1 10 > io_report.log
sar -b 1 10 > io_summary.log

# 快速判断：系统是否因 I/O 变慢
# 如果 vmstat 中 wa 持续 > 20%，且 iostat 中 %util > 80%
# 基本可以确定是 I/O 瓶颈
```

---

## 5. 网络资源紧张排查

### 5.1 理解网络关键概念

- **带宽（Bandwidth）**：网络接口的最大传输速率（如 1Gbps）
- **吞吐量（Throughput）**：实际的数据传输速率
- **延迟（Latency）**：数据包从发送到接收的时间
- **丢包率（Packet Loss）**：发送的数据包中丢失的比例
- **连接数（Connections）**：当前网络连接的数量
- **TCP 状态**：ESTABLISHED、TIME_WAIT、CLOSE_WAIT 等

### 5.2 排查步骤

#### 第一步：看网络接口状态

```bash
# 查看所有网络接口的实时流量
sar -n DEV 1
# 关键列：
#   rxkB/s - 每秒接收的数据量（KB）
#   txkB/s - 每秒发送的数据量（KB）
#   rxerr/s - 每秒接收错误包数
#   txerr/s - 每秒发送错误包数

# 简单查看（无需安装 sysstat）
cat /proc/net/dev
# 或
ip -s link

# 查看网络接口错误和丢包
netstat -i
# 关注：
#   RX-ERR / TX-ERR - 错误包数
#   RX-DRP / TX-DRP - 丢弃包数
#   RX-OVR / TX-OVR - 溢出包数
```

#### 第二步：看连接状态

```bash
# 查看所有 TCP 连接状态统计
ss -s
# 输出示例：
#   TCP:   1250 (estab 800, closed 200, orphaned 0, timewait 150)

# 查看各状态的连接数
ss -ant | awk '{print $1}' | sort | uniq -c | sort -rn

# 查看 TIME_WAIT 连接过多的原因
ss -ant state time-wait | wc -l
# TIME_WAIT 过多通常是因为短连接频繁创建/关闭

# 查看 CLOSE_WAIT 连接（应用未正确关闭连接）
ss -ant state close-wait | wc -l
# CLOSE_WAIT 过多说明应用程序没有正确关闭 socket

# 查看连接数最多的 IP
ss -ant | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -10

# 查看某个端口的连接情况
ss -ant sport = :80 | head -20
```

#### 第三步：测试网络连通性和延迟

```bash
# 测试连通性
ping -c 10 target_host

# 测试路由路径
traceroute target_host
# 或
tracepath target_host

# 测试带宽（需安装 iperf3）
# 服务端：
iperf3 -s
# 客户端：
iperf3 -c server_ip

# 测试 DNS 解析
dig example.com
# 或
nslookup example.com
```

### 5.3 常见网络问题及处理

| 现象 | 可能原因 | 处理方法 |
|------|---------|---------|
| 网络延迟高 | 带宽打满、网络拥塞 | 限流、升级带宽、优化传输 |
| 丢包率高 | 网络设备故障、缓冲区溢出 | 检查物理链路、调整缓冲区 |
| TIME_WAIT 过多 | 短连接频繁 | 启用长连接、调整 tcp_tw_reuse |
| CLOSE_WAIT 过多 | 应用未关闭连接 | 修复应用代码 |
| 连接数耗尽 | 连接泄漏或攻击 | 检查应用、配置防火墙 |
| RX-ERR/TX-ERR 增长 | 网线/网卡/交换机故障 | 检查物理链路 |

### 5.4 内核网络参数调优参考

```bash
# 查看当前网络参数
sysctl -a | grep net.core
sysctl -a | grep net.ipv4

# 常用调优参数（写入 /etc/sysctl.conf 永久生效）
# 增加连接队列大小
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000

# TIME_WAIT 优化
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# 增加文件描述符限制
fs.file-max = 1000000

# TCP 缓冲区优化
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 应用参数（不重启生效）
sysctl -p
```

### 5.5 实战技巧

```bash
# 实时监控网络连接变化
watch -n 1 'ss -s'

# 抓包分析（需安装 tcpdump）
tcpdump -i eth0 port 80 -c 100
# -i 指定网卡
# -c 抓包数量
# -w 保存到文件，用 Wireshark 分析

# 查看进程的网络连接
lsof -i :80
lsof -i @192.168.1.100

# 查看某个进程的所有网络活动
strace -p <PID> -e trace=network
```

---

## 6. 综合排查流程与实战案例

### 6.1 标准排查流程

```
收到告警 / 用户反馈系统慢
        │
        ▼
┌───────────────────┐
│  第一步：快速感知   │  top / uptime / free -h / df -h
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│  第二步：判断瓶颈   │  CPU? 内存? 磁盘I/O? 网络?
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│  第三步：定位进程   │  找到消耗资源最多的进程
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│  第四步：分析原因   │  代码bug? 配置不当? 容量不足?
└───────┬───────────┘
        │
        ▼
┌───────────────────┐
│  第五步：处理验证   │  采取措施 → 持续观察 → 确认恢复
└───────────────────┘
```

### 6.2 实战案例一：Web 服务响应变慢

**现象**：用户反馈网站打开很慢，有时超时。

```bash
# 第一步：快速感知
uptime          # load average: 12.5, 10.2, 8.1 （4核机器，严重过载）
free -h         # available: 500M / 8G （内存还行）
top             # %wa: 35% （I/O 等待很高！）

# 第二步：定位磁盘 I/O
iostat -x 1
# /dev/sda  %util: 95%, await: 45ms （磁盘严重饱和）

# 第三步：找 I/O 热点进程
iotop
# 发现 mysqld 进程读写量最大

# 第四步：分析 MySQL
# 查看慢查询日志
tail -100 /var/log/mysql/slow.log
# 发现大量全表扫描查询

# 第五步：处理
# 1. 为相关表添加索引
# 2. 优化慢查询
# 3. 观察 iostat，await 降到 5ms 以下，恢复正常
```

### 6.3 实战案例二：应用频繁重启

**现象**：Java 应用每隔一段时间就自动重启。

```bash
# 第一步：查看系统日志
dmesg | grep -i "oom\|killed"
# 发现：Out of memory: Killed process 12345 (java)

# 第二步：分析内存使用
free -h
# total: 4G, available: 200M （内存严重不足）

ps aux --sort=-%mem | head -10
# 发现 java 进程 RSS 达到 3.5G

# 第三步：分析 Java 应用
# 查看堆内存配置
ps aux | grep java
# 发现 -Xmx4g（比物理内存还大！）

# 第四步：处理
# 1. 调整 JVM 堆内存：-Xmx2g -Xms2g
# 2. 增加物理内存到 8G
# 3. 配置 swap 作为兜底
```

### 6.4 实战案例三：网络连接数耗尽

**现象**：Nginx 报错 "too many open files"。

```bash
# 第一步：查看连接数
ss -s
# TCP: 65000 (estab 50000, timewait 10000)

# 第二步：查看文件描述符限制
ulimit -n
# 1024 （太小了！）

# 第三步：查看系统级限制
cat /proc/sys/fs.file-max
# 100000

# 第四步：处理
# 1. 临时修改（立即生效）
ulimit -n 65535

# 2. 永久修改（写入配置文件）
# /etc/security/limits.conf
# * soft nofile 65535
# * hard nofile 65535

# 3. 优化 TIME_WAIT
sysctl -w net.ipv4.tcp_tw_reuse=1
```

---

## 7. 进阶工具与学习路线

### 7.1 工具箱总览

| 类别 | 基础工具 | 进阶工具 |
|------|---------|---------|
| CPU | top, vmstat, mpstat | perf,火焰图 |
| 内存 | free, top, pidstat | pmap, smem, Valgrind |
| 磁盘 | df, du, iostat, iotop | blktrace, fio |
| 网络 | netstat/ss, tcpdump | nethogs, iftop, Wireshark |
| 综合 | top, vmstat, sar | dstat/glances, eBPF/BCC |
| 日志 | dmesg, journalctl | ELK Stack, Prometheus+Grafana |

### 7.2 性能分析神器：perf + 火焰图

```bash
# 安装
apt install linux-tools-common linux-tools-$(uname -r)

# 采样 CPU 性能数据（60秒）
perf record -g -p <PID> -- sleep 60

# 生成火焰图
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg

# 火焰图可以直观地看到 CPU 时间花在了哪些函数上
```

### 7.3 现代可观测性工具

```bash
# glances - 一个命令看所有资源（推荐！）
pip install glances
glances

# dstat - vmstat + iostat + netstat 的结合
dstat -cdngy 1

# bcc/eBPF - 内核级追踪（高级）
# 需要较新的内核（4.1+）
# 示例：查看哪些进程在做磁盘写入
biosnoop
# 示例：查看延迟分布
biolatency
```

### 7.4 推荐学习路线

```
入门阶段（当前）
├── 掌握 top/free/df/iostat/ss 等基础命令
├── 理解 CPU/内存/磁盘/网络的基本概念
└── 能独立完成常见资源问题的排查

进阶阶段
├── 学习 perf、火焰图等性能分析工具
├── 理解 Linux 内核调度、内存管理、I/O 栈
├── 掌握 tcpdump 抓包和网络协议分析
└── 学习 eBPF/BCC 进行内核级追踪

高级阶段
├── 搭建 Prometheus + Grafana 监控体系
├── 掌握容量规划和性能建模
├── 学习内核参数调优
└── 掌握分布式系统的性能排查
```

### 7.5 推荐学习资源

- **书籍**：《性能之巅》（Systems Performance）- Brendan Gregg
- **书籍**：《Linux 性能优化实战》- 倪朋飞
- **网站**：[Brendan Gregg 的性能分析博客](http://www.brendangregg.com/)
- **网站**：[Linux 性能观测工具速查](https://www.brendangregg.com/linuxperf.html)
- **实战**：在生产环境多练习，积累经验是最好的学习方式

---

## 附录：常用命令速查卡

```bash
# === CPU ===
top                          # 实时进程监控
htop                         # 增强版进程监控
vmstat 1                     # CPU/内存/I/O 综合监控
mpstat -P ALL 1              # 每核 CPU 使用率
pidstat -u 1                 # 进程级 CPU 使用率
uptime                       # 系统负载

# === 内存 ===
free -h                      # 内存使用概况
cat /proc/meminfo            # 详细内存信息
pidstat -r 1                 # 进程级内存使用
pmap -x <PID>                # 进程内存映射

# === 磁盘 ===
df -h                        # 磁盘空间使用率
du -sh <dir>                 # 目录占用大小
iostat -x 1                  # 磁盘 I/O 性能
iotop                        # 进程级 I/O 监控
lsof +L1                     # 查找已删除但仍占用空间的文件

# === 网络 ===
ss -s                        # 连接状态统计
ss -ant                      # 所有 TCP 连接
sar -n DEV 1                 # 网卡流量监控
netstat -i                   # 网卡错误统计
tcpdump -i eth0 port 80      # 抓包
lsof -i :80                  # 查看端口占用

# === 系统 ===
dmesg                        # 内核日志
journalctl -f                # 实时系统日志
sar -u 1 10                  # 记录 CPU 历史
sar -r 1 10                  # 记录内存历史
sar -d 1 10                  # 记录 I/O 历史
```

---

> **最后提醒**：排查资源问题最重要的是 **建立排查思路**，而不是死记命令。遇到问题时，先问自己三个问题：
> 1. **什么资源出了问题？**（CPU / 内存 / 磁盘 / 网络）
> 2. **哪个进程在消耗资源？**
> 3. **为什么会消耗这么多资源？**
>
> 带着这三个问题去使用工具，排查效率会大大提升。
