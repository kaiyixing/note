# K8s 容器资源隔离底层实现（Namespace + cgroup）

## 一、容器不是虚拟机

```
虚拟机：                容器：
┌──────────┐          ┌──────────┐
│  App     │          │  App     │
├──────────┤          ├──────────┤
│ Guest OS │          │ 依赖库    │  ← 没有完整OS！
├──────────┤          ├──────────┤
│ Hypervisor│         │ Docker   │
├──────────┤          ├──────────┤
│ Host OS  │          │ Host OS  │
└──────────┘          └──────────┘
```

**容器本质**：只是 Linux 内核里的一个**进程**，靠内核的两个机制实现隔离和资源限制：
- **Namespace**：让进程"看不到"其他进程（视野隔离）
- **cgroup**：限制进程能用多少 CPU、内存（资源限制）

---

## 二、Namespace —— 视野隔离的核心

### 什么是 Namespace？

**一句话**：Namespace 是 Linux 内核的功能，让进程拥有**独立的"视野"**，看不到其他进程、网络、文件系统等。

### 类比理解

```
想象一栋大楼：

整栋大楼 = Linux 主机（Host）
每个房间 = 一个 Namespace

房间1（PID Namespace）：只有3个员工（进程1、2、3）
房间2（PID Namespace）：只有2个员工（进程4、5）

房间1看不到房间2的员工，反之亦然
但它们都住在同一栋楼（共享主机内核）
```

### Linux 内核提供的 7 种 Namespace

| Namespace | 隔离什么 | 效果 |
|-----------|----------|------|
| **PID** | 进程 ID | 容器内 PID 从 1 开始，看不到宿主机进程 |
| **Network** | 网络栈 | 容器有自己的 IP、端口、路由表 |
| **Mount** | 文件系统挂载点 | 容器有独立的文件系统视图 |
| **UTS** | 主机名 | 容器可以有自己的 hostname |
| **IPC** | 进程间通信 | 容器间信号量、消息队列隔离 |
| **User** | 用户/组 | 容器内的 root 不是宿主机的 root |
| **Cgroup** | cgroup 根目录 | 容器看不到宿主机的 cgroup 层级 |

### PID Namespace 举例

```
宿主机视角：
PID 1 (systemd)
PID 2 (kubelet)
PID 3 (containerd)
PID 100 (容器A的进程) ← 这个进程在容器里是 PID 1
PID 200 (容器B的进程) ← 这个进程在容器里是 PID 1

容器A视角：
PID 1 (自己的进程) ← 它以为自己是第一个进程
看不到 PID 2, 3, 200...
```

### 验证 Namespace 的存在

```bash
# 查看容器进程的 Namespace
ls -la /proc/<容器进程PID>/ns/

# 查看当前进程的 PID Namespace
readlink /proc/self/ns/pid

# 查看宿主机的 PID Namespace
readlink /proc/1/ns/pid
```

---

## 三、Namespace 和 cgroup 的关系

```
┌─────────────────────────────────────────┐
│              容器 = 进程                 │
├─────────────────────────────────────────┤
│  Namespace：隔离视野（看不到别人）       │
│  - PID：看不到宿主机进程                │
│  - Network：有自己的 IP                 │
│  - Mount：有自己的文件系统              │
├─────────────────────────────────────────┤
│  cgroup：限制资源（用多少）             │
│  - CPU：最多用 0.5 核                   │
│  - Memory：最多用 256Mi                 │
└─────────────────────────────────────────┘

一句话总结：
Namespace 管"能看什么"，cgroup 管"能用什么"
```

### K8s Namespace vs Linux Namespace

**注意**：这是两个完全不同的概念！

| | Linux Namespace | Kubernetes Namespace |
|--|-----------------|---------------------|
| 层级 | Linux 内核机制 | K8s 逻辑分组 |
| 作用 | 进程隔离（视野） | 资源隔离（权限/配额） |
| 实现 | 内核系统调用 | API Server 控制 |
| 粒度 | 容器级别 | 命名空间级别 |

---

## 四、cgroup（Control Groups）—— 资源限制的核心

### 什么是 cgroup？

**一句话**：cgroup 是 Linux 内核的功能，可以把进程"关进一个资源限制的笼子里"。

```
比喻：
把容器想象成一个房间
cgroup 就是这个房间的水电表

- CPU limit = 电表上限（最多用多少电）
- 内存 limit = 房间面积（最多占多大）
- 超了怎么办？限电（CPU throttle）或 踢出去（OOM Kill）
```

### cgroup v1 vs v2

| 特性 | cgroup v1 | cgroup v2 |
|------|-----------|-----------|
| 架构 | 每种资源独立层级 | 统一层级 |
| 挂载点 | `/sys/fs/cgroup/cpu/`, `/sys/fs/cgroup/memory/` | `/sys/fs/cgroup/` |
| 管理方式 | cgroupfs 或 systemd | 统一 systemd |
| K8s 支持 | 支持 | 推荐（1.25+） |

---

## 五、K8s 如何用 cgroup 限制容器资源

### 1. Pod YAML 中的资源定义

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:        # 调度依据（保证值）
        cpu: "250m"    # 0.25 核
        memory: "128Mi"
      limits:          # 硬上限（超了会被限制或杀掉）
        cpu: "500m"    # 0.5 核
        memory: "256Mi"
```

### 2. 这些配置最终变成什么？

K8s 会调用容器运行时（containerd → runc），最终在 Linux 内核创建 cgroup：

```bash
# 容器的 cgroup 目录（假设容器 ID 是 abc123）
/sys/fs/cgroup/cpu/kubepods/burstable/pod<uid>/abc123/
/sys/fs/cgroup/memory/kubepods/burstable/pod<uid>/abc123/
```

### 3. CPU 限制的底层实现

```bash
# cgroup CPU 配置文件
/sys/fs/cgroup/cpu/abc123/
├── cpu.cfs_quota_us    # CFS 调度器的配额（微秒）
├── cpu.cfs_period_us   # 调度周期（默认100ms = 100000微秒）
└── cpu.shares          # CPU 份额（相对权重）
```

**计算公式**：
```
CPU 核数 = cpu.cfs_quota_us / cpu.cfs_period_us

例如：
limits.cpu = "500m"（0.5核）
→ cpu.cfs_quota_us = 50000
→ cpu.cfs_period_us = 100000
→ 每 100ms 周期内，最多用 50ms
```

**CPU Throttle（节流）**：
```
进程想继续用 CPU → 内核说"你超配额了，等着"
等下一个周期才能继续用

表现：
- 应用响应变慢
- CPU 使用率看起来不高，但应用就是卡
- 这就是为什么 "CPU limit 设置太低会导致性能问题"
```

### 4. 内存限制的底层实现

```bash
# cgroup 内存配置文件
/sys/fs/cgroup/memory/abc123/
├── memory.limit_in_bytes    # 内存上限
├── memory.usage_in_bytes    # 当前使用量
└── memory.oom_control       # OOM 控制
```

**内存超限 → OOM Kill**：
```
内存使用超过 limit → 内核触发 OOM → 直接杀进程，没有商量余地！

类比：
CPU 超了 = 水龙头限流（还能用，只是慢）
内存超了 = 房间满了直接踢出去（直接死）
```

---

## 六、完整调用链

```
用户创建 Pod（kubectl apply）
    ↓
API Server 存储 PodSpec
    ↓
Scheduler 选择节点
    ↓
kubelet 在节点上创建容器
    ↓
kubelet → CRI 接口 → containerd → runc
    ↓
runc 调用 Linux 内核：
  1. clone() 系统调用 → 创建进程
  2. unshare() → 创建 Namespace（隔离视野）
  3. 写 cgroup 文件 → 设置资源限制
    ↓
容器进程启动，受到 cgroup 限制
```

---

## 七、其他 cgroup 限制

| 资源 | 限制方式 | 超了会怎样 |
|------|----------|-----------|
| CPU | CFS 配额 | Throttle（变慢） |
| 内存 | 硬上限 | OOM Kill（被杀） |
| 磁盘 | ephemeral-storage | Pod 被驱逐 |
| GPU | 设备插件 | 调度失败 |

---

## 八、面试高频问题

**Q1: CPU limit 设置太低会怎样？**
- 容器被 throttle，响应变慢
- 但不会被杀，只是变卡
- 建议：设 request 不设 limit，或 limit 留 20% 余量

**Q2: 内存 limit 和 OOM Kill 的关系？**
- 内存使用超过 limit → 内核触发 OOM → 直接杀进程
- 没有"缓冲"，到了就杀
- K8s 会重启容器，但数据可能丢失

**Q3: cgroup v1 和 v2 的区别？**
- v1：每种资源独立管理，配置复杂
- v2：统一管理，K8s 1.25+ 推荐
- 生产环境建议用 v2

**Q4: 为什么 CPU 使用率低但应用还是卡？**
- 可能是 CPU throttle
- 用 `cat /sys/fs/cgroup/cpu/xxx/cpu.stat` 查看
- nr_throttled 增长说明被限流了

---

## 九、相关链接

- [[容器与编排/Docker/基础知识/Docker核心概念与原理|Docker 核心概念]]
- [[容器与编排/Kubernetes/容器运行时/Kubernetes-containerd容器运行时|containerd 容器运行时]]
- [[容器与编排/Kubernetes/基础知识/Kubernetes知识梳理|Kubernetes 知识梳理]]
