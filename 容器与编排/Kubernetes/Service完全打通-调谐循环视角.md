---
title: Service 完全打通（调谐循环视角）
tags:
  - 容器/k8s
  - 网络
  - 核心模型
---

# Service 完全打通（调谐循环视角）

> ⚠️ **前置必读**：[[容器与编排/Kubernetes/基础知识/控制面与数据面]] —— 这是地基概念，没搞懂的话本文的「第一次分家」部分看不明白。
>
> 前置：[[容器与编排/Kubernetes/k8s-知识总结-2026-05-31]]（原始笔记）
> 主线：[[容器与编排/Kubernetes/基础知识/Kubernetes知识梳理]]

---

## 零、先纠两处理解偏差

原始笔记里这两句看着对，实际是错的，而且错的地方正好是"领悟"的关键：

| 原笔记 | 问题 | 正解 |
|--------|------|------|
| 「iptables 模式每个包从头遍历到尾部」 | **错。** 如果真这样，稍大一点的集群早崩了 | 只有**新建连接**走规则遍历；一旦握手成功，后续包由内核 **conntrack 表**直接转发，不再碰 iptables 规则 |
| 「DNAT 随机转发」 | 不严谨 | 是 `statistic` 模块的**概率链**实现，见下面第四节，不是 random() 掐随机数 |

> **教训**：这两处都错在把 iptables 想成了"一张线性表"。K8s 用的是**分层链 + 概率分流 + conntrack 缓存**三件套。

---

## 一、用三件套拆解 Service（回到主线）

别问"Service 怎么用"，问那三个问题：

| | Service 体系 |
|---|---|
| **它在调谐什么** | 「一组动态 Pod」和「一个稳定访问入口」之间的映射 |
| **期望端是谁** | `Service.spec.selector` + `ports`，写在 etcd 里，万年不变 |
| **现实端是谁** | 每个节点网络命名空间里的 iptables/IPVS 规则 + 真实 PodIP 列表 |
| **控制器是谁** | ⚠️ **两个**，不是像 Deployment 那样只有一个 |

```
Service.spec（期望：我要 app=nginx 的所有 Pod）
        │
        │  ① EndpointSlice Controller（跑在 master 上，全局一份）
        ▼
EndpointSlice 对象（现实名单：nginx-a:10.1.1.5、nginx-b:10.1.2.9）
        │
        │  ② kube-proxy（跑在「每个节点」上，每台一份）
        ▼
节点上的 iptables / IPVS 规则 ← 数据包真正走的东西
```

**为什么 Service 比 Deployment 难就在这里**：Deployment 只有一个循环，Service 是**一个全局循环 + N 个节点本地循环**，中间用一个 EndpointSlice 对象解耦。这是你第一次遇到"控制器级联"。

---

## 二、全景链路

```
   你 kubectl apply -f svc.yaml
            │
            ▼
   ┌─────────────────┐
   │  kube-apiserver │──→ etcd（存 Service 期望状态）
   └─────────────────┘
            │ watch
            ▼
   ┌──────────────────────────┐
   │ EndpointSlice Controller │   ① 全局循环：按 selector 筛 Pod
   └──────────────────────────┘         ├─ Pod Ready → 加入名单
            │                           └─ Pod 删了 → 移出名单
            ▼
   ┌──────────────────────────┐
   │    EndpointSlice 对象    │   纯做解耦的中间件（每个 slice ≤100 endpoint）
   └──────────────────────────┘
            │ watch（每个节点一份）
            ▼
   ┌──────────────────────────┐
   │       kube-proxy         │   ② 节点本地循环：把名单翻译成转发规则
   └──────────────────────────┘
            ▼
   iptables (-j DNAT)  /  IPVS
            ▼
        真实 PodIP
```

顺带解答原始笔记里没说的：**为什么叫 EndpointSlice 而不是老版的 Endpoints？**
老版一个 Service 一个 Endpoints 对象，Service 有 5000 个 Pod 时，一个 Pod 挂了就会导致整个 5000 条目的对象全量更新，产生更新风暴。Slice 切成每片最多 100 个，只更新受影响那一片。

---

## 三、ClusterIP 的本质（最重要的一节）

> **ClusterIP 不是 IP。它是一组 DNAT 规则的「名字」。**

这条事实很多人学 K8s 三年都不知道，但它能一次性解释所有诡异现象：

```bash
kubectl get svc nginx
# NAME    TYPE        CLUSTER-IP     PORT
# nginx   ClusterIP   10.96.0.10     80/TCP

ip addr | grep 10.96.0.10     # ← 什么都没有！没有任何网卡上有这个 IP
ip route | grep 10.96.0.10    # ← 也没有这条路由
```

它只活在这一行 iptables 规则里：

```bash
iptables-save -t nat | grep 10.96.0.10
# -A KUBE-SERVICES -d 10.96.0.10/32 -p tcp -m tcp --dport 80 -j KUBE-SVC-XXXXXXXX
```

数据包的处理逻辑：
1. 容器里访问 `10.96.0.10:80`，包从 veth 出来进宿主机
2. 走到 netfilter 的 **PREROUTING**（别人转发）/ **OUTPUT**（本机发起）链
3. 命中 `KUBE-SERVICES` → `KUBE-SVC-XXX` → `KUBE-SEP-XXX`
4. 最后一跳 `-j DNAT --to-destination 10.244.1.5:8080` —— **目的地址在这里被改写成真实 PodIP**
5. 之后就是普通的 CNI 路由，送达目标 Pod

**由此推出的三个必然结论：**

| 现象 | 原因 |
|------|------|
| `ping` ClusterIP 永远不通 | ① ClusterIP 上没有进程监听，不会有 ICMP 回包；② IP 不存在，压根没法 ARP；③ kube-proxy 只写了 TCP/UDP 规则，不管 ICMP |
| kube-proxy 挂了 ClusterIP 立刻失效 | 规则是它写的，没人写规则，VIP 就只是一个不存在的地址 **（注意：已建立的连接因 conntrack 缓存可能还能续命一会儿）** |
| 集群里可以同时有几百个 ClusterIP 而不冲突 | 它们不是真 IP，不存在地址冲突问题，只在各自的 DNAT 规则里生效 |

---

## 四、iptables 规则的真实长相（概率链）

这是原始笔记里缺的那块。真实规则长这样（三层链）：

```bash
# 第一层：总入口，按目标 VIP+端口 分流到具体 Service
-A KUBE-SERVICES -d 10.96.0.10/32 -p tcp -m tcp --dport 80 -j KUBE-SVC-XXXXXXXX

# 第二层：这个 Service 有 3 个后端，用概率把她拆成 1/3 + 1/3 + 1/3
-A KUBE-SVC-XXXXXXXX -m statistic --mode random --probability 0.33333 -j KUBE-SEP-AAAAAA
-A KUBE-SVC-XXXXXXXX -m statistic --mode random --probability 0.50000 -j KUBE-SEP-BBBBBB
-A KUBE-SVC-XXXXXXXX                                                   -j KUBE-SEP-CCCCCC

# 第三层：每条 SEP 做真正的 DNAT
-A KUBE-SEP-AAAAAA -p tcp -m tcp -j DNAT --to-destination 10.244.1.5:8080
-A KUBE-SEP-BBBBBB -p tcp -m tcp -j DNAT --to-destination 10.244.2.7:8080
-A KUBE-SEP-CCCCCC -p tcp -m tcp -j DNAT --to-destination 10.244.3.9:8080
```

**概率链的巧思**（面试高频）：
- 第 1 条概率 1/3 → 1/3 流量
- 第 2 条概率 1/2 → 从**剩下的 2/3** 里拿一半 = 1/3 流量
- 第 3 条无条件兜底 → 剩下的 1/3
- 好处：**无需记录任何状态**，纯数学保证均匀；后端数变化时只需重算概率

**推论**：iptables 模式是**线性匹配**，Service 越多、`KUBE-SERVICES` 链越长，新连接的首包延迟越高。**但因为有 conntrack，只有首包受影响**，稳态流量不受影响。所以几百 Service 以内完全够用。

---

## 五、kube-proxy 三种模式（修正版）

| 模式 | 数据结构 | 复杂度 | 现状 | 排障工具 |
|------|---------|--------|------|---------|
| **userspace** | 用户态进程代理 | 极差 | 已废弃 | — |
| **iptables** | 分层规则链 + 概率 | O(n)，n=Service 数 | 默认，中小集群首选 | `iptables-save -t nat` |
| **IPVS** | 哈希表 | O(1) | 大集群（>1000 Service） | `ipvsadm -Ln` |

> ⚠️ 补充原笔记：**IPVS 模式并没有完全甩掉 iptables**。它仍然需要 iptables 配合 **ipset** 来做 SNAT、源地址标记、健康检查黑名单等脏活。IPVS 只接管了负载均衡那一跳。

查当前模式：

```bash
kubectl get cm kube-proxy -n kube-system -o yaml | grep mode
# mode: "ipvs"   ← 或 "iptables"

# 或者看日志
kubectl logs -n kube-system <kube-proxy-xxx> | grep "Using"
```

---

## 六、四种类型 + Headless

| 类型 | VIP 有没有 | 怎么用 | 谁负责 |
|------|-----------|--------|--------|
| **ClusterIP** | 有 | 集群内 `vip:port` | kube-proxy |
| **NodePort** | 有 | `任意节点IP:30000-32767` | kube-proxy（每台机器都写规则） |
| **LoadBalancer** | 有 | 云厂商 LB → NodePort → ClusterIP | 云厂商的 cloud-controller-manager |
| **ExternalName** | **没有** | 纯 DNS CNAME，返回外部域名 | CoreDNS |
| **Headless**（`clusterIP: None`） | **没有** | DNS 直接返回 PodIP 列表 | CoreDNS |

### ClusterIP 的内部关系（重要）

NodePort 和 LoadBalancer **不是替代关系，是层层套娃**：

```
外部流量 → 云 LB → NodeIP:NodePort →（kube-proxy DNAT）→ ClusterIP:Port → PodIP:TargetPort
```

所以排查 LoadBalancer 不通时，**从里往外一层层测**，先确认 ClusterIP 通不通。

### Headless Service 的使用场景

```yaml
spec:
  clusterIP: None    # ← 关键一行
```
- 没有 VIP，**没有任何 iptables 负载均衡规则**
- DNS 查询直接返回所有 Ready Pod 的 IP
- 负载均衡交给客户端自己做
- **StatefulSet 必须配它**，因为要让每个 Pod 有独立可解析的 DNS 名：`mysql-0.mysql-svc.default.svc.cluster.local`

---

## 七、CoreDNS —— 又一个循环

| | CoreDNS |
|---|---|
| 期望端 | Service/Pod 的名称定义 |
| 现实端 | 节点上 Pod `/etc/resolv.conf` 的查询结果 |
| 控制器 | coreDNS 的 kubernetes 插件 watch apiserver，实时维护内存里的 DNS 记录 |

命名规则（必须背熟）：

```
服务名.命名空间.svc.cluster.local
nginx.default.svc.cluster.local

# Pod 的 DNS 名（把 IP 的点换成横线）
10-244-1-5.default.pod.cluster.local
```

**集群内的 `/etc/resolv.conf`** 长这样：
```
nameserver 10.96.0.10        # ← CoreDNS 服务的 ClusterIP
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

> `search` + `ndots:5` 意味着在 Pod 里 `curl nginx` 会被自动补全成 `nginx.default.svc.cluster.local`。**这也是为什么短域名能在 Pod 内可用、在宿主机上不可用。**

### 服务发现的两种方式

| 方式 | 机制 | 坑 |
|------|------|-----|
| **DNS**（推荐） | CoreDNS 实时解析，动态感知 | 基本没有 |
| **环境变量** | kubelet 创建 Pod 时注入 `<SVC>_SERVICE_HOST` | ⚠️ **致命顺序坑**：Service 晚于 Pod 创建时，Pod 拿不到变量，且不会自动补，必须重建 Pod |

**生产一律用 DNS。** 环境变量方式基本只在调试时用。

---

## 八、五个反直觉真相（运维必背）

1. **ClusterIP 不是 IP**，是一组 DNAT 规则的名字 → ping 不通是正常的
2. **NodePort 在每一个节点都开端口**，跟那个节点上有没有对应的 Pod 无关 → 所以随便连哪个节点 IP 都行，代价是流量多跳一次
3. **Service 的负载均衡是四层的**：同一个 TCP 连接一定打到同一个 Pod。**长连接压测看起来"流量没打散"就是这个原因**，不是故障
4. **会话保持要配出来**：默认无粘性，需要显式 `spec.sessionAffinity: ClientIP`（默认超时 10800s = 3 小时）
5. **kube-proxy 不转发数据包**：它只负责写规则。真正转发的是内核 netfilter/IPVS。所以 **kube-proxy 挂了，已有连接不会立刻断**

---

## 九、排障决策树（Service 访问不通）

**核心二分法：先 curl PodIP，绕过 Service 直接测。**

如果 `curl PodIP:端口` 也不通 → 不是 Service 的问题，去看 CNI 和 Pod 本身。

```
Service 访问不通
│
├─ 步骤0：绕过 Service curl PodIP:TargetPort
│   ├─ 不通 → 问题在 Pod / CNI，去看 [[容器与编排/Kubernetes/Ingress与网络策略/网络插件详解-Calico-Flannel|网络插件]]
│   └─ 通 ↓（说明 Service 链路有问题）
│
├─ 步骤1：DNS 解析对不对
│   kubectl run -it --rm dnsutil --image=busybox:1.28 --restart=Never -- nslookup nginx
│   （注意用 busybox:1.28，新版镜像的 nslookup 有 bug）
│
├─ 步骤2：EndpointSlice 有没有成员 ← 80% 的故障在这里
│   kubectl get endpointslice -l kubernetes.io/service-name=nginx
│   ├─ 空 → selector 没匹配上
│   │    kubectl get pod --show-labels      # 看 Pod 真实 labels
│   │    kubectl get svc nginx -o yaml | grep -A3 selector
│   │    ⚠️ 记住：Service 匹配的是 Pod 的 labels，不是 Deployment 的！
│   └─ 有 → 继续往下
│
├─ 步骤3：kube-proxy 活着吗
│   kubectl get pod -n kube-system -l k8s-app=kube-proxy
│   kubectl logs -n kube-system <kube-proxy-xxx> | tail -50
│
├─ 步骤4：节点上规则在不在
│   # iptables 模式
│   iptables-save -t nat | grep <ClusterIP>
│   # IPVS 模式
│   ipvsadm -Ln | grep -A5 <ClusterIP>
│   └─ 规则缺失 → kube-proxy 出问题了，或 conntrack 表满了
│
└─ 步骤5：端口对应关系有没有搞错
    kubectl get svc nginx -o jsonpath='{.spec.ports[0]}'
    # port(对外) → targetPort(容器真实监听端口)
    # ⚠️ targetPort 不写就默认等于 port，容器监听 8080 而 port 填 80 时就会踩坑
```

---

## 十、自检清单

能不看文档答出这 8 条，Service 就算真懂了：

- [ ] 说出 Service 体系的期望端、现实端分别是谁，为什么控制器有两个
- [ ] 解释为什么 `ip addr` 里找不到 ClusterIP
- [ ] 解释为什么 ping 不通 ClusterIP 但 curl 能通
- [ ] 画出 KUBE-SERVICES → KUBE-SVC → KUBE-SEP 的三层链
- [ ] 说出 iptables 概率链里第二个 SEP 为什么填 0.5 而不是 0.3333
- [ ] 说出 NodePort / LoadBalancer / ClusterIP 的层层套娃关系
- [ ] 说出 Headless Service 的两种典型用途
- [ ] Service 不通时，第一刀砍在哪里（curl PodIP 二分法）

---

## 相关笔记

- [[容器与编排/Kubernetes/k8s-知识总结-2026-05-31]] — 原始 Service 笔记
- [[容器与编排/Kubernetes/Ingress与网络策略/网络插件详解-Calico-Flannel]] — CNI 层排障
- [[容器与编排/Kubernetes/基础知识/Kubernetes组件详细解析]] — 组件全景
- [[容器与编排/Kubernetes/基础知识/K8s资源隔离底层实现]] — namespace / cgroup 底层
