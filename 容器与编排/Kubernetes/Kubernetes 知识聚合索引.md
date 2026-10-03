---
title: Kubernetes 知识聚合索引
tags:
  - 容器/k8s
  - MOC
  - 导航
---

# Kubernetes 知识聚合索引

> 学习导航 + 进度追踪。**本文的核心在第 2 节——整套 K8s 的统一心智模型。**

---

## 1. 当前进度（2026-10-01 修正）

| # | 概念 | 状态 | 对应笔记 |
|---|------|------|---------|
| 1 | Node & Container Runtime | ✅ 掌握 | [[容器与编排/Kubernetes/容器运行时/Kubernetes-containerd容器运行时]] |
| 2 | Pod Deep Dive | ✅ 掌握 | [[k8s-知识总结-2026-05-25]] |
| 3 | Workload Controllers | ✅ 掌握 | [[k8s-知识总结-2026-05-26]] |
| 4 | ConfigMap & Secret | ✅ 掌握 | [[k8s-知识总结-2026-05-28]] |
| 5 | **Service** | ✅ **已打通** | [[Service完全打通-调谐循环视角]] |
| 6 | Ingress & Gateway API | ⏳ 待学习 | 依赖第 5 项，必须排在 Service 之后 |
| 7 | NetworkPolicy | ⏳ 待学习 | |
| 8 | **Storage（PV/PVC/SC）** | ✅ **已打通** | [[容器与编排/Kubernetes/存储卷/存储PV-PVC完全打通-供需撮合视角]] |
| 9 | Scheduling & Resource | ⏳ 待学习 | |
| 10 | Autoscaling（HPA/VPA） | ⏳ 待学习 | [[容器与编排/Kubernetes/HPA与弹性伸缩/__学习方向]] |
| 11 | Security（RBAC/SA） | ⏳ 待学习 | [[容器与编排/Kubernetes/权限与安全/RBAC权限管理详解]] |

> 📌 2026-05-31 的原始 Service 笔记里有两处理解偏差（iptables 线性遍历、DNAT 随机转发），已在 [[Service完全打通-调谐循环视角]] 第 0 节纠正，原文保留。

---

## 2. ⭐ 核心模型：调谐循环三件套

> 🔰 **地基概念（先读这个）**：[[容器与编排/Kubernetes/基础知识/控制面与数据面]]
> 控制面做决策、写表，低频；数据面按表执行、转发，每个包都走。区分方法：**每秒被调用几次 = 控制面，每秒几万次 = 数据面**。

**K8s 不是一堆要背的对象，是同一个循环重复了十遍。**

```
期望状态（etcd）  ──watch──▶  控制器 diff  ──执行──▶  现实状态
       ▲                                                  │
       └──────────────────  状态回流（status）◀──────────────┘
```

**拿到任何新对象，只问三个问题：**

1. 它在调谐什么？（期望与现实之间是什么关系）
2. 期望端是谁？现实端是谁？
3. 控制器有几个？中间有没有解耦对象？

答出来就算懂了。**这张表的每一行，都是同一道题。**

---

## 3. 模块总表（三件套视角）

| # | 模块 | 期望端 | 现实端 | 控制器 | 备注 |
|---|------|--------|--------|--------|------|
| **3** | **Deployment** | `replicas: 3` | 运行的 Pod 数量 | Deployment → ReplicaSet 控制器 | 两级级联，中间对象 RS |
| **5** | **Service** | `selector` + `ports` | 节点上的 iptables/IPVS 规则 | ① EndpointSlice 控制器 ② kube-proxy | **第一个双循环**，EndpointSlice 解耦 |
| **6** | **Ingress** | `rules`（host/path → svc） | Ingress Controller 进程里的配置 | **不在 K8s 本体**！第三方实现 | 本体只定义了 API，实现要自己装 |
| **7** | **NetworkPolicy** | `podSelector` + 规则 | 节点上的 iptables/ipset 或 eBPF | **CNI 插件**（Calico/Cilium） | 许了愿但不落地 → CNI 不支持 |
| **8** | **PV/PVC** | PVC 的容量与访问模式 | 真实的 PV / 底层存储卷 | PV 控制器 + external-provisioner | 唯一有"供需双方"，会 Pending 等待 |
| **9** | **调度** | Pod 的 `nodeName` 为空 | `nodeName` 被填上 | kube-scheduler | **唯一不改所有权只改字段**的控制器（bind） |
| **10** | **HPA** | 目标指标值（如 CPU 70%） | 实测指标值 | HPA 控制器 → **改 Deployment 的 replicas** | **级联到别人的循环**，自己不动手 |
| **11** | **RBAC** | — | — | — | 🚫 **全表唯一例外：不是循环，是拦截器** |

### 一句话总结

> **11 个模块 = 10 次同一个循环 + 1 个拦截器。**

### 为什么 RBAC 是例外

因为它**不改变任何状态**。它挂在 kube-apiserver 的请求链路上（认证 → 授权 → 准入），只回答"放行 / 拒绝"，不产生 reconcile。

这是唯一一格不需要用循环模型去理解的。

---

## 4. 推荐学习顺序（按依赖关系重排，不是按大纲顺序）

原顺序是横向铺广度，容易卡死。改为**依赖优先**：

```
已完成：Pod → Workload → ConfigMap → Service ✅
                                        │
        ┌───────────────────────────────┤
        ▼                               ▼
   ⑧ 存储 PV/PVC ✅                    ⑨ 调度 Scheduling
   （撮合而非自造，               （最简单的一次性绑定，
     数据面不在 K8s 手里）            学完就明白 Pod 为何 Pending）
        │                               │
        └───────────────┬───────────────┘
                        ▼
              ⑩ HPA 弹性伸缩
              （依赖 Deployment + metrics-server，
                级联控制器的第二个例子）
                        │
                        ▼
               ⑥ Ingress
               （⚠️ 必须排在 Service 之后，
                  因为 Ingress 的后端就是 Service）
                        │
                        ▼
              ⑦ NetworkPolicy
              （依赖理解 CNI 与 Label）
                        
   ⑪ RBAC —— 唯一例外，随时可学，跟其他都不冲突
```

**关键提醒**：之前计划里把 Ingress 排在第 6 位紧跟 Service，这没错，但**前提是 Service 必须真通**。现在补完了，可以走了。

---

## 5. 学习笔记（按时间线）

| 日期 | 主题 | 覆盖内容 | 查看 |
|------|------|---------|------|
| 2026-05-25 | Pod Deep Dive | Phase/Conditions/Probe/Init 容器/QoS/故障状态 | [[k8s-知识总结-2026-05-25]] |
| 2026-05-26 | Workload Controllers | Deployment/StatefulSet/DaemonSet/Job/CronJob | [[k8s-知识总结-2026-05-26]] |
| 2026-05-28 | ConfigMap & Secret | Volume 挂载/envFrom/symlink 更新机制/base64 | [[k8s-知识总结-2026-05-28]] |
| 2026-05-31 | Service Deep Dive | kube-proxy 模式/Service 类型/EndpointSlice | [[k8s-知识总结-2026-05-31]] |
| **2026-10-01** | **Service 打通** | **调谐循环视角 + VIP 本质 + 概率链 + 排障树** | [[Service完全打通-调谐循环视角]] |
| **2026-10-03** | **存储 PV/PVC 打通** | **供需撮合模型 + 数据面归属 + Multi-Attach 排障** | [[容器与编排/Kubernetes/存储卷/存储PV-PVC完全打通-供需撮合视角]] |

---

## 6. 关联笔记

### 核心概念
- [[容器与编排/Kubernetes/基础知识/控制面与数据面]] — 🔰 地基：控制面 vs 数据面（必先读）
- [[Service完全打通-调谐循环视角]] — ⭐ 主推：Service 与统一心智模型
- [[容器与编排/Kubernetes/基础知识/Kubernetes组件详细解析]] — 组件全景
- [[容器与编排/Kubernetes/基础知识/Kubernetes知识梳理]] — 整体架构
- [[容器与编排/Kubernetes/基础知识/PodSpec详解]] — Pod 字段详解
- [[容器与编排/Kubernetes/基础知识/K8s资源隔离底层实现]] — namespace / cgroup 底层

### 部署与运维
- [[容器与编排/Kubernetes/部署与更新/k8s滚动更新]] — 滚动更新实操
- [[容器与编排/Kubernetes/部署与更新/kubectl常用命令]] — 命令速查
- [[容器与编排/Kubernetes/Helm与包管理/Helm包管理详解]] — Helm
- [[容器与编排/Kubernetes/CI-CD与集成/CI-CD集成详解]] — CI/CD

### 网络与存储
- [[容器与编排/Kubernetes/Ingress与网络策略/网络插件详解-Calico-Flannel]] — CNI 与排障
- [[容器与编排/Kubernetes/存储卷/存储PV-PVC完全打通-供需撮合视角]] — ⭐ 存储：供需撮合 + 数据面归属 + 排障
- [[容器与编排/Kubernetes/存储卷/__学习方向]] — 存储实操清单与选型
- [[容器与编排/Kubernetes/HPA与弹性伸缩/__学习方向]] — HPA 方向
- [[容器与编排/Kubernetes/Operator/__学习方向]] — Operator 进阶
- [[容器与编排/Kubernetes/权限与安全/RBAC权限管理详解]] — RBAC（唯一非循环模块）
- [[容器与编排/Kubernetes/容器运行时/Kubernetes-containerd容器运行时]] — containerd

### 实战复盘
- [[项目实践/03Kubernetes 集群故障复盘：Flannel 镜像缺失引发的雪崩]] — 集群雪崩故障复盘
- [[项目实践/Kubernetes离线环境部署Metrics Server实战笔记]] — Metrics Server 离线部署
