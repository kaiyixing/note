---
title: 存储 PV/PVC 完全打通（供需撮合视角）
tags:
  - 容器/k8s
  - 存储
  - 核心模型
---

# 存储 PV/PVC 完全打通（供需撮合视角）

> 🔰 前置：[[容器与编排/Kubernetes/基础知识/控制面与数据面]]（地基概念）
> 主线：[[容器与编排/Kubernetes/Kubernetes 知识聚合索引]]
> 原方向清单：[[容器与编排/Kubernetes/存储卷/__学习方向]]

---

## 一、破题：就是"找存储管理员要盘"

你一定干过这事。整个流程搬到 K8s 里，一个字都不差：

| 现实流程 | K8s 对应 |
|---------|---------|
| 你填的申请单（100G、给某台机器、读写） | **PVC**（PersistentVolumeClaim） |
| 管理员划好的盘 | **PV**（PersistentVolume） |
| 撮合的办事员 | **PV Controller** |
| 自动划盘的仓库 | **StorageClass + provisioner** |

---

## 二、三件套拆解

| | 存储体系 |
|---|---|
| **它在调谐什么** | 「存储需求」和「存储供给」之间的配对 |
| **期望端** | `PVC.spec`（要多大的盘、什么访问模式、哪个 StorageClass） |
| **现实端** | 真实存在的 PV 对象 / 底层那块实际的盘 |
| **控制器** | PV Controller（撮合绑定）+ external-provisioner（动态造盘） |

### ⭐ 它跟其他循环最大的不同

**PV Controller 自己造不出盘。**

- Deployment 控制器：算出缺 1 个 → **自己就能造 Pod** → 闭环
- Service：算出名单 → **自己就能写规则** → 闭环
- **存储**：算出需求 → **它只能撮合现成的 PV，或者喊 provisioner 去造** → 撮不上就**双方干等**

所以这是 K8s 里**唯一一个需求方和供给方是两个独立循环、会互相等待**的模块。表现就是 PVC 长期 `Pending`。

> 一句话：**别的循环是"我算完我干"，存储是"我算完我撮合"。**

---

## 三、为什么非要分 PVC 和 PV 两层

直接写一个对象不行吗？不行，因为这是**职责分离**：

| 角色 | 只关心 | 不关心 |
|------|--------|--------|
| **开发者** | 写 PVC：我要 10G、能读写 | 底层是 Ceph 还是阿里云盘、怎么供给 |
| **运维** | 管 PV / StorageClass：底层用什么、供给策略、回收策略 | 哪个应用要用 |

类比：**你申请服务器只写"8 核 16G"，不用管是 Dell 还是 HP、放在哪个机柜。**

这就是面向接口编程——PVC 是接口，PV 是实现，StorageClass 是实现的模板。

---

## 四、⭐ 数据面在哪？这是存储最反直觉的一点

用刚建立的控制面/数据面尺子量一下，会得到意外结论：

| | Service | 存储 |
|---|---------|------|
| 控制面 | 控制器 + kube-proxy（写规则） | PV Controller + provisioner（撮合、造盘） |
| 数据面 | 内核 netfilter 转发 | **Pod 内核直连 Ceph / NFS 后端** |
| **数据面归谁管** | **在 K8s 手里** | **不在 K8s 手里** |

**核心结论：K8s 只决定"把盘挂到哪"，IO 一个字节都不碰。**

推论（排障时极重要）：
- **存储慢、存储报错，根因往往在后端 Ceph/NFS，不在 K8s。**
- K8s 侧能看到的失败只有"挂载不上"，看不到"为什么慢"。
- 所以存储排障必须**两头看**：K8s 侧看挂载状态，后端看存储集群。

---

## 五、三种供给方式

| 方式 | 谁造 PV | 什么时候用 |
|------|---------|-----------|
| **静态供给 Static** | 运维手工 `kubectl apply` 建 PV | 已有现成存储（NFS 共享目录、已有 Ceph image） |
| **动态供给 Dynamic** | StorageClass + provisioner 自动造 | **生产主流**，绝大多数场景 |
| **撮不上** | 没人造 | PVC 一直 Pending |

### StorageClass 的两个关键参数

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-rbd
provisioner: rbd.csi.ceph.com        # 谁来造盘（CSI 驱动）
parameters:
  pool: kubernetes
reclaimPolicy: Retain                 # 删 PVC 后盘怎么办
volumeBindingMode: WaitForFirstConsumer   # 什么时候造
```

#### `volumeBindingMode`（运维必懂）

| 值 | 行为 | 什么时候用 |
|---|------|-----------|
| `Immediate` | PVC 一创建就立刻造 PV、立刻绑定 | 默认值。存储与节点无关时（如 NFS、CephFS） |
| `WaitForFirstConsumer` | **等 Pod 调度到具体节点后**才造 PV | ⭐ **Local PV、云盘多可用区场景必需** |

> 为什么需要延迟绑定？云盘是**可用区级资源**。如果 PVC 一提交就在 A 区造了盘，而 Pod 后来被调度到 B 区，这块盘**根本挂不上**。
> 用了 `WaitForFirstConsumer`，调度器先选节点，provisioner 再在**同区**造盘，一次成功。
> **Local PV 必须配这个**，否则必踩坑。

---

## 六、访问模式 AccessModes（含最容易错的一个）

| 模式 | 含义 | 典型后端 |
|------|------|---------|
| **RWO** (ReadWriteOnce) | 单**节点**读写挂载 | 云盘、Ceph RBD、Local PV |
| **ROX** (ReadOnlyMany) | 多节点只读 | NFS、CephFS |
| **RWX** (ReadWriteMany) | 多节点读写 | NFS、CephFS、GlusterFS |
| **RWOP** (ReadWriteOncePod) | 单 **Pod** 读写（1.22+） | 特殊场景 |

### ⚠️ 最容易搞错的一条

> **RWO 不是"只能一个 Pod 用"，是"只能一个节点挂载"。**

同一个节点上的多个 Pod **可以**同时挂同一个 RWO 的 PVC。RWO 限制的是节点数，不是 Pod 数。

真要限制到单个 Pod，得用 **RWOP**。

### 选型的硬约束

- 要 RWX（多 Pod 同时写）→ **必须**用共享文件存储（NFS / CephFS）。块存储（RBD / 云盘）**做不到**。
- 数据库这类单写场景 → RWO 块存储，性能最好。
- 多 Pod 共享配置文件 → 用 ConfigMap，别用 PVC。

---

## 七、回收策略 ReclaimPolicy（数据安全相关）

| 策略 | 删 PVC 后 | 风险 |
|------|----------|------|
| **Retain** | PV 变 `Released`，**数据还在**，需人工清理 | 安全，但会留下孤儿 PV |
| **Delete** | **自动删 PV 并删掉后端存储** | ⚠️ **数据直接没了，不可恢复** |
| Recycle | 已废弃 | — |

> **生产建议：默认 Retain。**
> 用 Delete 的话，一次误删 PVC 就是一次数据事故。`Retain` 下删了 PVC 数据还在，还有救。

`Released` 状态的 PV 不能直接复用（还残留旧数据），要人工确认后删掉 `spec.claimRef` 才能回到 `Available`。

---

## 八、生命周期与状态

```
PVC:  Pending ──撮合成功──▶ Bound ──Pod 使用中──▶ 删除 PVC
                  │                                    │
                  └──一直撮不上（见第九节排障）          ▼
                                          PV: Bound → Released → (人工清理) → Available
                                                    └─(Delete 策略)─▶ 直接消失
```

PV 的状态：`Available` → `Bound` → `Released` → `Available`（清理后）/ 删除

**绑定是一对一独占**，一个 PV 绑了某个 PVC 之后，别人抢不走。

> 补充：PVC 里写的 `storage: 10Gi` 是**最小值**，不是实际大小。撮合会找 ≥ 10Gi 的 PV，绑上之后你实际拿到的是那块 PV 的真实容量（可能是 20Gi）。

---

## 九、排障手册

### 故障 1：PVC 一直 Pending

```bash
kubectl describe pvc <name>      # 第一件事：看 Events
kubectl get sc                   # StorageClass 存在吗
kubectl get pod -n kube-system | grep csi   # CSI 驱动活着吗
```

**动态供给场景**，按概率排：
1. `storageClassName` 名字写错 / 没写且没有 default SC
2. CSI provisioner Pod 没跑起来（镜像拉不到、RBAC 没配）
3. 后端存储不可达（Ceph 集群挂了、云厂商 AK 失效）
4. 用了 `WaitForFirstConsumer` 但 Pod 还没被调度（**这个不是故障**，Pod 调度后才造）

**静态供给场景**：
1. 没有 PV 的 `capacity` ≥ PVC 请求
2. `accessModes` 不匹配
3. `storageClassName` 对不上（**两边都写 `""` 才匹配空 SC**，不写会用默认 SC，这是个坑）

> 典型坑：PV 里写 `storageClassName: ""` 表示"不属于任何 SC"，PVC 也必须是 `""` 才能撮合上。两边都不写反而会去找默认 SC。

### 故障 2：Multi-Attach 死锁（经典）

**现象**：Pod 卡在 `ContainerCreating`，describe 看到
```
Multi-Attach error for volume "pvc-xxx"
Volume is already exclusively attached to one node and can't be attached to another
```

**原因**：RWO 的盘挂在 node1 上，Pod 重建后调度到 node2，但 node1 的 attach 没释放（常见于节点宕机、驱逐超时、强制删 Pod）。

**处理**（⚠️ 有风险，先确认原 Pod 真的没了）：
```bash
kubectl get volumeattachment | grep <pvc-name>    # 看谁还占着
# 确认原 Pod 已经不存在后，才能删 attachment 触发重新挂载
kubectl delete volumeattachment <name>
```

**预防**：
- 用 `WaitForFirstConsumer` 减少跨节点漂移
- 节点 NotReady 后别急着强制驱逐，给 attach 释放留时间（默认 6 分钟）
- 关键业务考虑 RWX 共享存储

### 故障 3：删了 PVC 数据没了

根因：`reclaimPolicy: Delete`。

**预防**：生产一律 Retain。已经删了的，看后端存储有没有快照。

### 故障 4：存储慢 / IO 报错

记住第四节：**K8s 不碰 IO**。
- K8s 侧能确认的：PVC 是否 Bound、Pod 是否挂载成功
- 真正的根因要去后端查：Ceph 集群健康度、OSD 延迟、NFS server 负载、网络链路
- 别在 K8s 里瞎找

---

## 十、其他要点

### CSI 是现在的唯一选择

K8s 1.25+ 已移除所有 in-tree 存储插件（老的 `kubernetes.io/aws-ebs` 之类），现在**一律用 CSI 驱动**。每个 CSI 驱动包含两部分：
- `csi-provisioner`（控制面：造盘）
- `csi-node-plugin`（节点上：挂载）

### StatefulSet 与存储

StatefulSet 用 `volumeClaimTemplates` 自动给每个 Pod 建独立的 PVC：

```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: ["ReadWriteOnce"]
    storageClassName: ceph-rbd
    resources:
      requests:
        storage: 10Gi
```

Pod 重建后**仍然绑回原来那个 PVC**（名字是固定的 `data-mysql-0`），数据不丢。这是有状态服务能跑在 K8s 上的根本原因。

### 快照

`VolumeSnapshot` / `VolumeSnapshotClass` —— 依赖 CSI 驱动支持，做备份用。

---

## 十一、自检清单

- [ ] 说出 PV/PVC 体系的期望端、现实端分别是谁
- [ ] 解释为什么存储是"撮合"而不是"自己造"，以及为什么会导致 Pending
- [ ] 解释为什么要分 PVC 和 PV 两层（职责分离）
- [ ] 说出存储的数据面归谁管，跟 Service 有什么不同
- [ ] 说出 RWO 到底是限制节点还是限制 Pod
- [ ] 说出 `WaitForFirstConsumer` 什么时候必须用
- [ ] 说出生产环境 reclaimPolicy 该用什么，为什么
- [ ] PVC Pending 时第一刀砍在哪（describe 看 Events）
- [ ] 遇到 Multi-Attach 知道是什么原因、怎么处理

---

## 相关笔记

- [[容器与编排/Kubernetes/基础知识/控制面与数据面]] — 地基概念
- [[Service完全打通-调谐循环视角]] — 上一个模块，数据面在 K8s 手里（对比本文第四节）
- [[容器与编排/Kubernetes/存储卷/__学习方向]] — 实操清单与选型
- [[存储/Ceph/ceph详细架构]] — 后端存储（Ceph）
- [[存储/NFS/__学习方向]] — 后端存储（NFS）
