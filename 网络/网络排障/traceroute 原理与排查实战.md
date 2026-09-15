---
title: traceroute 原理与排查实战
tags:
  - 网络/排障
  - 网络/诊断工具
created: 2026-09-15
---

# traceroute 原理与排查实战

traceroute 利用 **IP TTL 分片溢出**机制逐跳探测网络路径，核心思想：发送 TTL=1、2、3... 的探测包，每跳路由器 TTL 减 1 归零即丢弃并回 **ICMP Time Exceeded**，由此暴露每一跳地址。

## 一、核心原理

- IP 头中 TTL 字段，每经过一个路由器减 1
- TTL 减到 0 时，路由器丢弃该包并回送 ICMP Time Exceeded（Type 11）
- traceroute 依次发送 TTL=1、2、3... 的探测包，每轮默认发 3 个
- 从收到的 ICMP 超时消息中提取源 IP，即为该跳地址
- 当某跳返回 ICMP Destination Unreachable 或收到目标响应，停止探测

## 二、三种实现差异

| 工具 | 默认协议 | 目标端口 | 说明 |
|------|---------|---------|------|
| `traceroute`（Linux） | UDP | 从 33434 起递增 | 靠 UDP 端口不可达报错（ICMP Type 3 Code 3）判断到达目标 |
| `tracert`（Windows） | ICMP | — | 靠 ICMP 回显判断到达目标 |
| `mtr` | UDP/ICMP | 可配置 | 持续探测，统计丢包率/延迟，支持 SLA 监测 |

关键差异：Linux traceroute 用 UDP 高编号端口而非 ICMP，因为很多路由器会过滤 ICMP 但不过滤 UDP，这样能获取目标主机的响应。

## 三、典型输出解读

```
$ traceroute example.com
traceroute to example.com (93.184.215.14), 30 hops max, 60 byte packets
 1  192.168.1.1 (192.168.1.1)  1.234 ms  1.102 ms  1.098 ms
 2  10.0.0.1 (10.0.0.1)  5.678 ms  5.543 ms  5.512 ms
 3  202.96.1.1 (202.96.1.1)  12.345 ms  *  12.201 ms
 4  203.119.1.1 (203.119.1.1)  25.678 ms  25.543 ms  25.412 ms
 5  93.184.215.14 (93.184.215.14)  30.123 ms  30.098 ms  30.087 ms
```

- 每跳 3 个值：3 个探测包的 RTT
- `*` 表示该探测包超时（路由器可能丢包或过滤 ICMP 回复）
- 同一跳显示不同 IP：**等价多路径路由（ECMP）** 导致
- `!H` 表示目标收到 UDP 包但端口不可达（traceroute 标记）
- `!N` 网络不可达，`!P` 端口不可达，`!A` 管理员禁止

## 四、常见异常场景

| 现象 | 原因 |
|------|------|
| 某跳全 `*` | 路由器禁用了 ICMP 超时回复，或 QoS 策略丢弃低优先级 ICMP |
| 某跳延迟骤增 | 到达核心骨干网或跨洋链路 |
| 中间跳延迟大于后续跳 | ICMP 回复被低优先级处理（路由器对 ICMP 做 QoS 限速） |
| 跳数突然增加 | 路由表变化或 BGP 路径切换 |
| 同一跳 IP 不同 | ECMP 等价多路径，轮询转发 |

## 五、进阶命令

```bash
traceroute -n example.com          # 不解析 DNS，更快
traceroute -I example.com          # 用 ICMP 代替 UDP（绕过 UDP 过滤）
traceroute -T -p 443 example.com   # TCP SYN 探测，绕过 UDP/ICMP 过滤
traceroute -F example.com          # 设置 DF 标记，测试 MTU / MPLS 黑盒发现
traceroute -m 10 example.com       # 最大跳数限制为 10
traceroute -q 1 example.com        # 每跳只发 1 个包（默认 3）
traceroute -w 3 example.com        # 等待超时时间 3 秒
traceroute -x 8.8.8.8             # 指定回源地址
```

**MTR 持续监测（推荐用于 SLA 监控）**
```bash
mtr -r -n -c 50 example.com        # 发 50 轮后出报告
mtr -n -c 100 10.1.1.1            # 测试内网，不解析 DNS
mtr --report-cycles 10 8.8.8.8    # 报告模式，10 轮
```

## 六、网络诊断实战

### 场景 1：定位丢包位置

```
 1  192.168.1.1     0.5ms  0.4ms  0.3ms
 2  10.0.0.1        1.2ms  1.1ms  1.0ms
 3  172.16.1.1      *      *      *          ← 疑似丢包
 4  202.96.1.1      15.3ms 15.2ms 15.1ms     ← 恢复
```

第 3 跳全 `*` 但第 4 跳正常 → 第 3 跳路由器**过滤了 ICMP 超时但正常转发数据包**，实际并未丢包。

### 场景 2：MTU 问题排查

```bash
traceroute -F destination.com
# 某跳返回 "Fragmentation Needed" → 该路由器 MTU 小于 1500
# 检查该链路 MTU 配置（隧道封装会消耗头部空间）
```

### 场景 3：非对称路由

```bash
traceroute 8.8.8.8              # 去程
traceroute -r 8.8.8.8           # 回程（若支持）
mtr --reverse 8.8.8.8           # MTR 对比去程回程
```

跨运营商时去程和回程路径不同是常见情况。

### 场景 4：云环境 / VPN 环境

云厂商或企业 VPN 中，traceroute 可能只到网关就结束：
- 中间链路被 NAPT / NAT-T 覆盖
- 可用 `traceroute -T -p 443` 指定 TCP 协议穿透
- 云环境建议用 `mtr` 配合云厂商提供的探测点

## 七、与 ping / MTR 对比

| 维度 | ping | traceroute | MTR |
|------|------|-----------|-----|
| 用途 | 测延迟/丢包 | 定位路径 | 持续监测 |
| 逐跳 | 否 | 是 | 是 |
| 输出 | 单次 | 单次 | 循环统计 |
| 协议 | ICMP | UDP/ICMP/TCP | 可配 |
| 适用 | 简单连通性 | 路径定位 | SLA 监控 |

## 八、核心结论

- traceroute 是**网络故障定位的第一手工具**，但需理解 ICMP 限速和 UDP 过滤机制
- 全 `*` 不一定代表真实丢包，可能是路由器禁用了 ICMP 超时回复
- 生产环境优先使用 `mtr` 做持续监测，traceroute 做单次快速定位
- 遇到 UDP 被过滤时，切换 `-T -p 443` 用 TCP 探测

## 相关

- [[路由与交换的核心原理及区别]]
- [[网络工程与 VLAN 规划实操指南（思科 Cisco 版本）]]
