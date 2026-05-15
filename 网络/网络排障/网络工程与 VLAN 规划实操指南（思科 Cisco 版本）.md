# 网络工程与 VLAN 规划实操指南（思科 Cisco 版本）

以下是三个核心任务的完整实验手册，建议在**Cisco Packet Tracer**或**GNS3/EVE-NG**模拟器中操作。

------

## 📋 实验环境准备

### 软件安装

| 软件                | 版本 | 下载地址      | 用途         |
| ------------------- | ---- | ------------- | ------------ |
| **Packet Tracer**   | 8.2+ | Cisco NetAcad | 基础网络模拟 |
| **GNS3**            | 2.2+ | gns3.com      | 高级网络模拟 |
| **EVE-NG**          | 最新 | eve-ng.net    | 企业级模拟   |
| **Wireshark**       | 最新 | wireshark.org | 抓包分析     |
| **SecureCRT/Putty** | 最新 | -             | 终端连接     |

### 实验拓扑设计

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                      总部大楼                            │
                    │                                                         │
                    │   ┌─────────┐         ┌─────────┐         ┌─────────┐   │
                    │   │  PC1    │         │  PC2    │         │  PC3    │   │
                    │   │ VLAN10  │         │ VLAN20  │         │ VLAN30  │   │
                    │   │ 研发部  │         │ 财务部  │         │ 访客区  │   │
                    │   └────┬────┘         └────┬────┘         └────┬────┘   │
                    │        │                   │                   │         │
                    │        └───────────────────┼───────────────────┘         │
                    │                            │                             │
                    │                    ┌───────▼───────┐                     │
                    │                    │  核心交换机   │                     │
                    │                    │  Cisco 3560   │                     │
                    │                    │  (三层)       │                     │
                    │                    └───────┬───────┘                     │
                    │                            │                             │
                    │                    ┌───────▼───────┐                     │
                    │                    │   路由器      │                     │
                    │                    │  Cisco 2901   │                     │
                    │                    └───────┬───────┘                     │
                    │                            │                             │
                    └────────────────────────────┼─────────────────────────────┘
                                                 │
                    ┌────────────────────────────┼─────────────────────────────┐
                    │                    互联网  │                             │
                    └────────────────────────────┼─────────────────────────────┘
                                                 │
                    ┌────────────────────────────▼─────────────────────────────┐
                    │                      分部大楼                            │
                    │                                                         │
                    │   ┌─────────┐         ┌─────────┐                       │
                    │   │  PC4    │         │ Server  │                       │
                    │   │ VLAN40  │         │ VLAN50  │                       │
                    │   │ 办公区  │         │ 服务器区 │                       │
                    │   └────┬────┘         └────┬────┘                       │
                    │        │                   │                             │
                    │        └───────────────────┼───────────────────┘         │
                    │                            │                             │
                    │                    ┌───────▼───────┐                     │
                    │                    │  分部交换机   │                     │
                    │                    │  Cisco 2960   │                     │
                    │                    └───────┬───────┘                     │
                    │                            │                             │
                    │                    ┌───────▼───────┐                     │
                    │                    │   路由器      │                     │
                    │                    │  Cisco 1941   │                     │
                    │                    └───────────────┘                     │
                    └─────────────────────────────────────────────────────────┘
```

------

## 🔴 任务 A：子网与 VLAN 规划计算

### 场景需求

| 部门/区域 | 人数/设备数 | 业务类型 | 安全要求        |
| --------- | ----------- | -------- | --------------- |
| 研发部    | 500 人      | 内部开发 | 高，禁止外网    |
| 财务部    | 50 人       | 财务系统 | 最高，独立 VLAN |
| 访客区    | 100 人      | 无线访客 | 低，仅外网      |
| 服务器区  | 20 台       | 业务服务 | 高，需公网访问  |
| 分部办公  | 50 人       | 日常办公 | 中，需访问总部  |

### 步骤 1：VLAN 规划表

```
┌──────────┬──────────┬───────────────┬──────────────┬──────────────┬─────────────┐
│  VLAN ID │  部门    │   网段        │   子网掩码   │   网关       │   备注      │
├──────────┼──────────┼───────────────┼──────────────┼──────────────┼─────────────┤
│   10     │  研发部  │ 192.168.10.0  │ 255.255.254.0│ 192.168.10.1 │ /23, 510IP  │
│   20     │  财务部  │ 192.168.20.0  │ 255.255.255.0│ 192.168.20.1 │ /24, 254IP  │
│   30     │  访客区  │ 192.168.30.0  │ 255.255.255.0│ 192.168.30.1 │ /24, 254IP  │
│   40     │  分部办公│ 192.168.40.0  │ 255.255.255.0│ 192.168.40.1 │ /24, 254IP  │
│   50     │  服务器区│ 192.168.50.0  │ 255.255.255.0│ 192.168.50.1 │ /24, 254IP  │
│   100    │  管理 VLAN│10.0.0.0      │ 255.255.255.0│ 10.0.0.1     │ 设备管理    │
│   999    │  互联 VLAN│172.16.0.0    │ 255.255.255.252│ -          │ 路由器互联  │
└──────────┴──────────┴───────────────┴──────────────┴──────────────┴─────────────┘
```

### 步骤 2：子网划分计算（面试必考）

```
【计算原理】
IP 地址总数 = 2^(32 - 子网掩码位数)
可用 IP 数 = 2^(32 - 子网掩码位数) - 2（减去网络地址和广播地址）

【研发部 500 人计算】
需求：500 个可用 IP
计算：2^n - 2 >= 500
      2^9 - 2 = 510 >= 500 ✓
      所以主机位需要 9 位
      子网掩码 = 32 - 9 = 23 位
      网段：192.168.10.0/23
      掩码：255.255.254.0
      范围：192.168.10.1 - 192.168.11.254

【财务部 50 人计算】
需求：50 个可用 IP
计算：2^n - 2 >= 50
      2^6 - 2 = 62 >= 50 ✓
      所以主机位需要 6 位
      子网掩码 = 32 - 6 = 26 位（但为了扩展，通常用/24）
      网段：192.168.20.0/24
      掩码：255.255.255.0
      范围：192.168.20.1 - 192.168.20.254

【服务器区 20 台计算】
需求：20 个可用 IP，但需要考虑扩展
计算：2^n - 2 >= 20
      2^5 - 2 = 30 >= 20 ✓
      但为了未来扩展，建议使用/24
      网段：192.168.50.0/24
      掩码：255.255.255.0
      范围：192.168.50.1 - 192.168.50.254

【路由器互联链路计算】
需求：2 个 IP（两端各一个）
计算：2^n - 2 >= 2
      2^2 - 2 = 2 >= 2 ✓
      所以主机位需要 2 位
      子网掩码 = 32 - 2 = 30 位
      网段：172.16.0.0/30
      掩码：255.255.255.252
      范围：172.16.0.1 - 172.16.0.2
```

### 步骤 3：IP 地址分配表

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         总部核心交换机 (Cisco 3560)                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│  VLAN 10    : 192.168.10.1/23    (研发部网关)                                    │
│  VLAN 20    : 192.168.20.1/24    (财务部网关)                                    │
│  VLAN 30    : 192.168.30.1/24    (访客区网关)                                    │
│  VLAN 50    : 192.168.50.1/24    (服务器区网关)                                  │
│  VLAN 100   : 10.0.0.1/24        (管理 VLAN)                                     │
│  Gi0/1      : 172.16.0.1/30      (连接总部路由器)                                │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                         总部路由器 (Cisco 2901)                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│  Gi0/0      : 172.16.0.2/30      (连接核心交换机)                               │
│  Gi0/1      : 172.16.1.1/30      (连接分部路由器)                               │
│  Gi0/2      : 203.0.113.1/24     (连接互联网，模拟)                             │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                         分部交换机 (Cisco 2960)                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│  VLAN 40    : 192.168.40.1/24    (分部办公网关)                                  │
│  VLAN 50    : 192.168.50.2/24    (服务器区备用网关)                              │
│  Gi0/1      : 172.16.1.2/30      (连接分部路由器)                               │
└─────────────────────────────────────────────────────────────────────────────────┘
```

------

## 🔴 任务 B：思科模拟器配置

### 步骤 1：创建拓扑

```
1. 打开 Packet Tracer 或 GNS3，新建拓扑
2. 拖拽设备：
   - 路由器：Cisco 2901 × 2（总部、分部）
   - 交换机：Cisco 3560 × 1（核心三层），Cisco 2960 × 1（分部接入）
   - 终端：PC × 5，Server × 1
3. 连接线缆：
   - 交换机之间：GigabitEthernet（千兆）
   - 交换机-路由器：GigabitEthernet
   - 交换机-PC：Copper Straight-Through（直通线）
4. 启动所有设备
```

### 步骤 2：总部核心交换机配置（Cisco 3560）

```bash
# 进入特权模式
Switch> enable
Switch# configure terminal

# 修改主机名
Switch(config)# hostname Core-SW

# 创建 VLAN
Core-SW(config)# vlan 10
Core-SW(config-vlan)# name R&D
Core-SW(config-vlan)# exit
Core-SW(config)# vlan 20
Core-SW(config-vlan)# name Finance
Core-SW(config-vlan)# exit
Core-SW(config)# vlan 30
Core-SW(config-vlan)# name Guest
Core-SW(config-vlan)# exit
Core-SW(config)# vlan 50
Core-SW(config-vlan)# name Server
Core-SW(config-vlan)# exit
Core-SW(config)# vlan 100
Core-SW(config-vlan)# name Management
Core-SW(config-vlan)# exit

# 或者批量创建（IOS 15.x 支持）
Core-SW(config)# vlan 10,20,30,50,100

# 配置连接 PC 的接口（Access 模式）
# 研发部 PC1 - 接口 Gi0/1
Core-SW(config)# interface GigabitEthernet 0/1
Core-SW(config-if)# description To-PC1-RD
Core-SW(config-if)# switchport mode access
Core-SW(config-if)# switchport access vlan 10
Core-SW(config-if)# spanning-tree portfast
Core-SW(config-if)# no shutdown
Core-SW(config-if)# exit

# 财务部 PC2 - 接口 Gi0/2
Core-SW(config)# interface GigabitEthernet 0/2
Core-SW(config-if)# description To-PC2-Finance
Core-SW(config-if)# switchport mode access
Core-SW(config-if)# switchport access vlan 20
Core-SW(config-if)# spanning-tree portfast
Core-SW(config-if)# no shutdown
Core-SW(config-if)# exit

# 访客区 PC3 - 接口 Gi0/3
Core-SW(config)# interface GigabitEthernet 0/3
Core-SW(config-if)# description To-PC3-Guest
Core-SW(config-if)# switchport mode access
Core-SW(config-if)# switchport access vlan 30
Core-SW(config-if)# spanning-tree portfast
Core-SW(config-if)# no shutdown
Core-SW(config-if)# exit

# 服务器区 Server - 接口 Gi0/4
Core-SW(config)# interface GigabitEthernet 0/4
Core-SW(config-if)# description To-Server
Core-SW(config-if)# switchport mode access
Core-SW(config-if)# switchport access vlan 50
Core-SW(config-if)# spanning-tree portfast
Core-SW(config-if)# no shutdown
Core-SW(config-if)# exit

# 配置连接路由器的接口（三层路由口）
Core-SW(config)# interface GigabitEthernet 0/24
Core-SW(config-if)# description To-Router
Core-SW(config-if)# no switchport
Core-SW(config-if)# ip address 172.16.0.1 255.255.255.252
Core-SW(config-if)# no shutdown
Core-SW(config-if)# exit

# 配置 VLAN 接口（SVI - 网关）
Core-SW(config)# interface Vlan 10
Core-SW(config-if)# description Gateway-RD
Core-SW(config-if)# ip address 192.168.10.1 255.255.254.0
Core-SW(config-if)# no shutdown
Core-SW(config-if)# exit

Core-SW(config)# interface Vlan 20
Core-SW(config-if)# description Gateway-Finance
Core-SW(config-if)# ip address 192.168.20.1 255.255.255.0
Core-SW(config-if)# no shutdown
Core-SW(config-if)# exit

Core-SW(config)# interface Vlan 30
Core-SW(config-if)# description Gateway-Guest
Core-SW(config-if)# ip address 192.168.30.1 255.255.255.0
Core-SW(config-if)# no shutdown
Core-SW(config-if)# exit

Core-SW(config)# interface Vlan 50
Core-SW(config-if)# description Gateway-Server
Core-SW(config-if)# ip address 192.168.50.1 255.255.255.0
Core-SW(config-if)# no shutdown
Core-SW(config-if)# exit

Core-SW(config)# interface Vlan 100
Core-SW(config-if)# description Management
Core-SW(config-if)# ip address 10.0.0.1 255.255.255.0
Core-SW(config-if)# no shutdown
Core-SW(config-if)# exit

# 启用 IP 路由（三层交换机必须）
Core-SW(config)# ip routing

# 配置默认路由指向路由器
Core-SW(config)# ip route 0.0.0.0 0.0.0.0 172.16.0.2

# 返回特权模式并保存
Core-SW(config)# end
Core-SW# copy running-config startup-config
Core-SW# write memory
```

### 步骤 3：总部路由器配置（Cisco 2901）

```bash
Router> enable
Router# configure terminal
Router(config)# hostname HQ-Router

# 配置连接核心交换机的接口
HQ-Router(config)# interface GigabitEthernet 0/0/0
HQ-Router(config-if)# description To-Core-SW
HQ-Router(config-if)# ip address 172.16.0.2 255.255.255.252
HQ-Router(config-if)# no shutdown
HQ-Router(config-if)# exit

# 配置连接分部路由器的接口
HQ-Router(config)# interface GigabitEthernet 0/0/1
HQ-Router(config-if)# description To-Branch-Router
HQ-Router(config-if)# ip address 172.16.1.1 255.255.255.252
HQ-Router(config-if)# no shutdown
HQ-Router(config-if)# exit

# 配置连接互联网的接口（模拟）
HQ-Router(config)# interface GigabitEthernet 0/0/2
HQ-Router(config-if)# description To-Internet
HQ-Router(config-if)# ip address 203.0.113.1 255.255.255.0
HQ-Router(config-if)# no shutdown
HQ-Router(config-if)# exit

# 配置静态路由
# 回总部各 VLAN 网段
HQ-Router(config)# ip route 192.168.10.0 255.255.254.0 172.16.0.1
HQ-Router(config)# ip route 192.168.20.0 255.255.255.0 172.16.0.1
HQ-Router(config)# ip route 192.168.30.0 255.255.255.0 172.16.0.1
HQ-Router(config)# ip route 192.168.50.0 255.255.255.0 172.16.0.1

# 到分部网段
HQ-Router(config)# ip route 192.168.40.0 255.255.255.0 172.16.1.2

# 默认路由到互联网
HQ-Router(config)# ip route 0.0.0.0 0.0.0.0 203.0.113.254

# 配置 NAT（让内网访问外网）
# 定义 ACL 允许内网网段
HQ-Router(config)# access-list 1 permit 192.168.0.0 0.0.255.255
HQ-Router(config)# access-list 1 permit 10.0.0.0 0.255.255.255

# 配置 NAT
HQ-Router(config)# ip nat inside source list 1 interface GigabitEthernet 0/0/2 overload

# 配置接口 NAT 方向
HQ-Router(config)# interface GigabitEthernet 0/0/0
HQ-Router(config-if)# ip nat inside
HQ-Router(config-if)# exit

HQ-Router(config)# interface GigabitEthernet 0/0/1
HQ-Router(config-if)# ip nat inside
HQ-Router(config-if)# exit

HQ-Router(config)# interface GigabitEthernet 0/0/2
HQ-Router(config-if)# ip nat outside
HQ-Router(config-if)# exit

# 保存配置
HQ-Router(config)# end
HQ-Router# copy running-config startup-config
HQ-Router# write memory
```

### 步骤 4：分部交换机配置（Cisco 2960）

```bash
Switch> enable
Switch# configure terminal
Switch(config)# hostname Branch-SW

# 创建 VLAN
Branch-SW(config)# vlan 40
Branch-SW(config-vlan)# name Branch-Office
Branch-SW(config-vlan)# exit
Branch-SW(config)# vlan 50
Branch-SW(config-vlan)# name Server
Branch-SW(config-vlan)# exit
Branch-SW(config)# vlan 100
Branch-SW(config-vlan)# name Management
Branch-SW(config-vlan)# exit

# 配置连接 PC 的接口
Branch-SW(config)# interface GigabitEthernet 0/1
Branch-SW(config-if)# description To-PC4-Branch
Branch-SW(config-if)# switchport mode access
Branch-SW(config-if)# switchport access vlan 40
Branch-SW(config-if)# spanning-tree portfast
Branch-SW(config-if)# no shutdown
Branch-SW(config-if)# exit

# 配置连接服务器的接口
Branch-SW(config)# interface GigabitEthernet 0/2
Branch-SW(config-if)# description To-Server-Branch
Branch-SW(config-if)# switchport mode access
Branch-SW(config-if)# switchport access vlan 50
Branch-SW(config-if)# spanning-tree portfast
Branch-SW(config-if)# no shutdown
Branch-SW(config-if)# exit

# 配置连接路由器的接口（三层路由口）
Branch-SW(config)# interface GigabitEthernet 0/24
Branch-SW(config-if)# description To-Branch-Router
Branch-SW(config-if)# no switchport
Branch-SW(config-if)# ip address 172.16.1.2 255.255.255.252
Branch-SW(config-if)# no shutdown
Branch-SW(config-if)# exit

# 配置 VLAN 接口（SVI - 网关）
Branch-SW(config)# interface Vlan 40
Branch-SW(config-if)# description Gateway-Branch-Office
Branch-SW(config-if)# ip address 192.168.40.1 255.255.255.0
Branch-SW(config-if)# no shutdown
Branch-SW(config-if)# exit

Branch-SW(config)# interface Vlan 50
Branch-SW(config-if)# description Gateway-Server-Backup
Branch-SW(config-if)# ip address 192.168.50.2 255.255.255.0
Branch-SW(config-if)# no shutdown
Branch-SW(config-if)# exit

Branch-SW(config)# interface Vlan 100
Branch-SW(config-if)# description Management
Branch-SW(config-if)# ip address 10.0.1.1 255.255.255.0
Branch-SW(config-if)# no shutdown
Branch-SW(config-if)# exit

# 启用 IP 路由
Branch-SW(config)# ip routing

# 配置默认路由
Branch-SW(config)# ip route 0.0.0.0 0.0.0.0 172.16.1.1

# 保存
Branch-SW(config)# end
Branch-SW# copy running-config startup-config
Branch-SW# write memory
```

### 步骤 5：分部路由器配置（Cisco 1941）

```bash
Router> enable
Router# configure terminal
Router(config)# hostname Branch-Router

# 配置连接分部交换机的接口
Branch-Router(config)# interface GigabitEthernet 0/0/0
Branch-Router(config-if)# description To-Branch-SW
Branch-Router(config-if)# ip address 172.16.1.1 255.255.255.252
Branch-Router(config-if)# no shutdown
Branch-Router(config-if)# exit

# 配置连接总部路由器的接口
Branch-Router(config)# interface GigabitEthernet 0/0/1
Branch-Router(config-if)# description To-HQ-Router
Branch-Router(config-if)# ip address 172.16.1.2 255.255.255.252
Branch-Router(config-if)# no shutdown
Branch-Router(config-if)# exit

# 配置静态路由
# 回分部各 VLAN 网段
Branch-Router(config)# ip route 192.168.40.0 255.255.255.0 172.16.1.1
Branch-Router(config)# ip route 192.168.50.0 255.255.255.0 172.16.1.1

# 到总部网段
Branch-Router(config)# ip route 192.168.10.0 255.255.254.0 172.16.1.1
Branch-Router(config)# ip route 192.168.20.0 255.255.255.0 172.16.1.1
Branch-Router(config)# ip route 192.168.30.0 255.255.255.0 172.16.1.1

# 默认路由到总部（通过总部上外网）
Branch-Router(config)# ip route 0.0.0.0 0.0.0.0 172.16.1.1

# 保存
Branch-Router(config)# end
Branch-Router# copy running-config startup-config
Branch-Router# write memory
```

### 步骤 6：PC 和 Server 配置

```
PC1（研发部）:
  IP Address: 192.168.10.10
  Subnet Mask: 255.255.254.0
  Default Gateway: 192.168.10.1
  DNS Server: 8.8.8.8

PC2（财务部）:
  IP Address: 192.168.20.10
  Subnet Mask: 255.255.255.0
  Default Gateway: 192.168.20.1
  DNS Server: 8.8.8.8

PC3（访客区）:
  IP Address: 192.168.30.10
  Subnet Mask: 255.255.255.0
  Default Gateway: 192.168.30.1
  DNS Server: 8.8.8.8

PC4（分部办公）:
  IP Address: 192.168.40.10
  Subnet Mask: 255.255.255.0
  Default Gateway: 192.168.40.1
  DNS Server: 8.8.8.8

Server（服务器区）:
  IP Address: 192.168.50.10
  Subnet Mask: 255.255.255.0
  Default Gateway: 192.168.50.1
  DNS Server: 8.8.8.8
```

------

## 🔴 任务 C：验证流程

### 步骤 1：连通性测试

```bash
# 在 PC1 上执行（Packet Tracer 中点击 PC → Desktop → Command Prompt）
PC> ping 192.168.10.1      # 测试网关
PC> ping 192.168.20.10     # 测试财务部 PC（跨 VLAN）
PC> ping 192.168.50.10     # 测试服务器
PC> ping 192.168.40.10     # 测试分部 PC（跨地域）
PC> ping 8.8.8.8           # 测试外网（如果配置了 NAT）

# 预期结果：
# - 同 VLAN：应该通
# - 跨 VLAN：应该通（三层交换机路由）
# - 跨地域：应该通（静态路由）
# - 外网：取决于 NAT 配置
```

### 步骤 2：查看 MAC 地址表

```bash
# 在核心交换机上
Core-SW# show mac address-table
# 输出示例：
#          Mac Address Table
# -------------------------------------------
#
# Vlan    Mac Address       Type        Ports
# ----    -----------       --------    -----
#  10     00e0.fc12.3456    DYNAMIC     Gi0/1
#  20     00e0.fc23.4567    DYNAMIC     Gi0/2
#  30     00e0.fc34.5678    DYNAMIC     Gi0/3
#  50     00e0.fc45.6789    DYNAMIC     Gi0/4

# 验证要点：
# - 每个 PC 的 MAC 应该在正确的 VLAN 中
# - 端口应该对应正确的物理接口

# 查看特定 VLAN 的 MAC 表
Core-SW# show mac address-table vlan 10
```

### 步骤 3：查看 ARP 表

```bash
# 在核心交换机上
Core-SW# show arp
# 或
Core-SW# show ip arp
# 输出示例：
# Protocol  Address          Age (min)  Hardware Addr   Type   Interface
# Internet  192.168.10.10           5    00e0.fc12.3456  ARPA   Vlan10
# Internet  192.168.10.1            -    00e0.fc00.0001  ARPA   Vlan10
# Internet  192.168.20.10          10    00e0.fc23.4567  ARPA   Vlan20

# 验证要点：
# - 每个 VLAN 的网关应该有对应的 ARP 条目
# - 年龄（Age）应该正常刷新

# 查看特定接口的 ARP
Core-SW# show ip arp vlan 10
```

### 步骤 4：查看路由表

```bash
# 在核心交换机上
Core-SW# show ip route
# 输出示例：
# Codes: C - connected, S - static, R - RIP, O - OSPF
#        D - EIGRP, EX - EIGRP external
#
# Gateway of last resort is 172.16.0.2 to network 0.0.0.0
#
# S*    0.0.0.0/0 [1/0] via 172.16.0.2
# C     192.168.10.0/23 is directly connected, Vlan10
# C     192.168.20.0/24 is directly connected, Vlan20
# C     192.168.30.0/24 is directly connected, Vlan30
# C     192.168.50.0/24 is directly connected, Vlan50
# C     172.16.0.0/30 is directly connected, GigabitEthernet0/24

# 在路由器上
HQ-Router# show ip route
# 应该看到所有内网网段的静态路由
# S     192.168.10.0/23 [1/0] via 172.16.0.1
# S     192.168.20.0/24 [1/0] via 172.16.0.1
# S     192.168.40.0/24 [1/0] via 172.16.1.2

# 验证要点：
# - 直连路由（C - connected）应该存在
# - 静态路由（S - static）应该指向正确的下一跳
# - 默认路由（S*）应该存在

# 查看特定路由
HQ-Router# show ip route 192.168.10.0
```

### 步骤 5：查看 VLAN 配置

```bash
# 在核心交换机上
Core-SW# show vlan
# 或
Core-SW# show vlan brief
# 输出示例：
# VLAN Name                             Status    Ports
# ---- -------------------------------- --------- -------------------------------
# 1    default                          active    Gi0/5, Gi0/6, Gi0/7, Gi0/8
# 10   R&D                              active    Gi0/1
# 20   Finance                          active    Gi0/2
# 30   Guest                            active    Gi0/3
# 50   Server                           active    Gi0/4
# 100  Management                       active    
# 1002 fddi-default                     act/unsup 
# 1003 token-ring-default               act/unsup 

# 查看特定 VLAN 详情
Core-SW# show vlan id 10
Core-SW# show vlan name R&D

# 验证要点：
# - 所有 VLAN 应该存在且状态为 active
# - 端口应该在正确的 VLAN 中
# - 接口类型（Access/Trunk）应该正确
```

### 步骤 6：查看接口状态

```bash
# 查看所有接口状态摘要
Core-SW# show interfaces status
# 输出示例：
# Port    Name               Status       Vlan       Duplex  Speed Type
# Gi0/1   To-PC1-RD          connected    10         a-full  a-100 10/100/1000BaseTX
# Gi0/2   To-PC2-Finance     connected    20         a-full  a-100 10/100/1000BaseTX
# Gi0/24  To-Router          connected    routed     a-full  a-1000 10/100/1000BaseTX

# 查看特定接口详情
Core-SW# show interfaces GigabitEthernet 0/1
# 输出包含：
# - 物理状态（line protocol）
# - 输入/输出数据包
# - 错误计数

# 查看接口 IP 配置
Core-SW# show ip interface brief
# 输出示例：
# Interface              IP-Address      OK? Method Status                Protocol
# Vlan10                 192.168.10.1    YES manual up                    up
# Vlan20                 192.168.20.1    YES manual up                    up
# GigabitEthernet0/24    172.16.0.1      YES manual up                    up

# 验证要点：
# - 物理状态（Status）应该是 up/connected
# - 协议状态（Protocol）应该是 up
# - 没有错误计数（input errors/output errors）
```

### 步骤 7：查看 NAT 会话

```bash
# 在总部路由器上
HQ-Router# show ip nat translations
# 输出示例：
# Pro Inside global      Inside local       Outside local      Outside global
# icmp 203.0.113.1:1     192.168.10.10:1    8.8.8.8:1          8.8.8.8:1
# tcp  203.0.113.1:1024  192.168.20.10:80   8.8.8.8:80         8.8.8.8:80

# 查看 NAT 统计
HQ-Router# show ip nat statistics

# 验证要点：
# - 应该有内网 IP 到外网 IP 的转换条目
# - 发起 ping 或 HTTP 请求后应该有对应会话
```

### 步骤 8：抓包分析（Wireshark）

```
1. 在 GNS3/EVE-NG 中右键链路 → Start Capture
2. 在 PC1 上 ping PC2
3. 在 Wireshark 中观察：
   - ARP 请求/响应（广播→单播）
   - ICMP 请求/响应
   - VLAN 标签（如果是 Trunk 链路，802.1Q）

4. 验证要点：
   - 跨 VLAN 通信应该经过网关
   - ARP 请求应该是广播（FF:FF:FF:FF:FF:FF）
   - ICMP 应该是单播
   - Trunk 链路应该有 802.1Q 标签
```

------

## 🔴 故障排查指南

### 问题 1：PC 无法 ping 通网关

```bash
# 排查步骤
# 1. 检查 PC 配置
PC> ipconfig
# 确认 IP、掩码、网关正确

# 2. 检查交换机接口状态
Core-SW# show interfaces GigabitEthernet 0/1 status
# 确认 Status 是 connected

# 3. 检查 VLAN 配置
Core-SW# show vlan id 10
# 确认端口在 VLAN 10 中

# 4. 检查 VLAN 接口
Core-SW# show ip interface brief | include Vlan10
# 确认 Vlan10 是 up/up 状态，有 IP 地址

# 5. 检查 ARP
Core-SW# show ip arp | include 192.168.10.10
# 确认有 PC1 的 ARP 条目

# 常见原因：
# - 端口 VLAN 配置错误
# - VLAN 接口 shutdown
# - PC 网关配置错误
# - 接口 no shutdown 未执行
```

### 问题 2：跨 VLAN 不通

```bash
# 排查步骤
# 1. 检查源 VLAN 配置
Core-SW# show vlan id 10

# 2. 检查目的 VLAN 配置
Core-SW# show vlan id 20

# 3. 检查路由表
Core-SW# show ip route
# 确认两个 VLAN 网段都是直连路由（C）

# 4. 检查 IP 路由是否启用
Core-SW# show running-config | include ip routing
# 必须配置 ip routing

# 5. 检查 ACL（如果有）
Core-SW# show access-lists
# 确认没有阻断策略

# 常见原因：
# - VLAN 接口未配置 IP
# - ip routing 未启用
# - 路由表缺失
# - ACL 阻断
```

### 问题 3：总部和分部不通

```bash
# 排查步骤
# 1. 检查总部路由器路由
HQ-Router# show ip route
# 确认有到分部网段的路由

# 2. 检查分部路由器路由
Branch-Router# show ip route
# 确认有到总部网段的路由

# 3. 检查互联链路
HQ-Router# ping 172.16.1.2
# 确认路由器之间能通

# 4. 检查接口状态
HQ-Router# show ip interface brief
Branch-Router# show ip interface brief

# 常见原因：
# - 静态路由配置错误
# - 互联链路故障
# - 下一跳地址错误
# - 接口 shutdown
```

### 问题 4：无法访问外网

```bash
# 排查步骤
# 1. 检查默认路由
HQ-Router# show ip route 0.0.0.0
# 确认有默认路由指向互联网

# 2. 检查 NAT 配置
HQ-Router# show ip nat translations
HQ-Router# show running-config | include nat

# 3. 检查 ACL
HQ-Router# show access-lists
# 确认 ACL 允许内网网段

# 4. 检查 NAT 接口方向
HQ-Router# show running-config | interface GigabitEthernet 0/0/2
# 确认 ip nat outside

# 常见原因：
# - 默认路由缺失
# - NAT 未配置
# - ACL 未允许内网网段
# - NAT inside/outside 方向错误
```

------

## 🔴 思科命令速查表

### 基础配置命令

| 功能             | 命令                                                   | 说明                   |
| ---------------- | ------------------------------------------------------ | ---------------------- |
| 进入特权模式     | `enable`                                               | 从用户模式进入特权模式 |
| 进入配置模式     | `configure terminal`                                   | 从特权模式进入配置模式 |
| 修改主机名       | `hostname XXX`                                         | 设置设备名称           |
| 创建 VLAN        | `vlan 10` + `name XXX`                                 | 创建并命名 VLAN        |
| 进入接口         | `interface GigabitEthernet 0/1`                        | 进入接口配置视图       |
| 设置 Access 模式 | `switchport mode access`                               | 设置为 Access 端口     |
| 加入 VLAN        | `switchport access vlan 10`                            | Access 端口加入 VLAN   |
| 设置 Trunk 模式  | `switchport mode trunk`                                | 设置为 Trunk 端口      |
| 允许 VLAN        | `switchport trunk allowed vlan 10,20`                  | Trunk 允许 VLAN        |
| 配置 IP          | `ip address 192.168.1.1 255.255.255.0`                 | 接口 IP 地址           |
| 配置网关         | `interface Vlan 10` + `ip address`                     | SVI 网关               |
| 启用三层路由     | `ip routing`                                           | 三层交换机必须         |
| 静态路由         | `ip route 目的网段 掩码 下一跳`                        | 配置静态路由           |
| 默认路由         | `ip route 0.0.0.0 0.0.0.0 下一跳`                      | 默认路由               |
| 保存配置         | `copy running-config startup-config` 或 `write memory` | 保存当前配置           |
| 启用接口         | `no shutdown`                                          | 激活接口               |

### 查看命令

| 功能         | 命令                                  | 说明               |
| ------------ | ------------------------------------- | ------------------ |
| 查看 VLAN    | `show vlan brief`                     | 查看所有 VLAN 摘要 |
| 查看 MAC 表  | `show mac address-table`              | 查看 MAC 地址表    |
| 查看 ARP     | `show ip arp`                         | 查看 ARP 表        |
| 查看路由表   | `show ip route`                       | 查看 IP 路由表     |
| 查看接口状态 | `show interfaces status`              | 查看接口摘要       |
| 查看接口详情 | `show interfaces GigabitEthernet 0/1` | 查看特定接口       |
| 查看 IP 接口 | `show ip interface brief`             | 查看 IP 接口摘要   |
| 查看 NAT     | `show ip nat translations`            | 查看 NAT 转换      |
| 查看 ACL     | `show access-lists`                   | 查看所有 ACL       |
| 查看运行配置 | `show running-config`                 | 查看当前配置       |
| 查看启动配置 | `show startup-config`                 | 查看保存的配置     |

### 调试命令

| 功能     | 命令              | 说明             |
| -------- | ----------------- | ---------------- |
| 开启调试 | `debug ip packet` | 调试 IP 数据包   |
| 关闭调试 | `undebug all`     | 关闭所有调试     |
| 查看日志 | `show logging`    | 查看系统日志     |
| 清除配置 | `clear config`    | 清除配置（慎用） |
| 重启设备 | `reload`          | 重启设备         |

------

## ✅ 实验完成检查清单

| 任务   | 完成标志                | 面试能说出                                                   |
| ------ | ----------------------- | ------------------------------------------------------------ |
| 任务 A | 能计算 500 人子网掩码   | "500 人需要/23，因为 2^9-2=510"                              |
| 任务 B | 能配置 Access/Trunk/SVI | "Access 用 switchport mode access，SVI 用 interface Vlan"    |
| 任务 C | 能验证并排查故障        | "我用 show mac address-table 验证 VLAN，用 show ip route 验证路由" |

------

## 💡 面试话术模板

```
【面试官】：你怎么规划 VLAN 和子网？

【回答】：
我通常按业务功能划分 VLAN，而不是按人数。比如研发、财务、
访客各自独立 VLAN，这样便于安全隔离和策略控制。

子网划分时，我会根据人数计算主机位。比如 500 人的研发部，
需要 2^n-2>=500，算出 n=9，所以用/23 掩码，提供 510 个可用 IP。

网关通常设在三层交换机的 SVI 接口上，这样 VLAN 间通信
通过三层交换机路由，效率高。

配置时我用思科命令：vlan 创建 VLAN，switchport mode access/trunk
设置接口模式，switchport access vlan 加入 VLAN，interface Vlan
配置 SVI 网关，ip routing 启用三层路由。

验证时用 show mac address-table 看 VLAN 绑定，show ip arp 看地址解析，
show ip route 看路由。遇到过跨 VLAN 不通的问题，排查发现是
ip routing 没启用，配置后解决。

总部和分部之间我配置静态路由，互联网出口配置 NAT，让内网
可以访问外网但外网不能主动访问内网。
```

------

## 📚 华为 vs 思科命令对比表

| 功能         | 华为命令                        | 思科命令                           |
| ------------ | ------------------------------- | ---------------------------------- |
| 进入配置模式 | `system-view`                   | `configure terminal`               |
| 创建 VLAN    | `vlan batch 10 20`              | `vlan 10` + `vlan 20`              |
| Access 端口  | `port link-type access`         | `switchport mode access`           |
| 加入 VLAN    | `port default vlan 10`          | `switchport access vlan 10`        |
| Trunk 端口   | `port link-type trunk`          | `switchport mode trunk`            |
| 允许 VLAN    | `port trunk allow-pass vlan 10` | `switchport trunk allowed vlan 10` |
| VLAN 接口    | `interface Vlanif 10`           | `interface Vlan 10`                |
| 查看 VLAN    | `display vlan`                  | `show vlan brief`                  |
| 查看 MAC     | `display mac-address`           | `show mac address-table`           |
| 查看 ARP     | `display arp`                   | `show ip arp`                      |
| 查看路由     | `display ip routing-table`      | `show ip route`                    |
| 查看接口     | `display interface brief`       | `show interfaces status`           |
| 保存配置     | `save`                          | `copy run start` 或 `write`        |
| 查看配置     | `display current-configuration` | `show running-config`              |

------

## 📚 扩展学习建议

1. **动态路由协议**：学习 OSPF 配置（思科：router ospf 1）
2. **VLAN 间 ACL**：学习如何限制部门间访问（思科：ip access-list）
3. **HSRP/VRRP 冗余**：学习网关冗余配置（思科：standby）
4. **DHCP 服务**：学习自动分配 IP 地址（思科：ip dhcp pool）
5. **认证考试**：思科 CCNA/CCNP 数通认证

完成这三个任务后，你的网络工程能力会有质的飞跃，面试时也能自信地说出具体的配置命令和排查思路！