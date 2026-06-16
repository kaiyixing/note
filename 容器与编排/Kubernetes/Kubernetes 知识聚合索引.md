---
title: Kubernetes 知识聚合索引
tags:
  - 容器/k8s
  - MOC
  - 导航
---

# Kubernetes 知识聚合索引

> 本文档是对 K8s 学习过程中各日期笔记的导航聚合，方便快速查找和回顾，不替代原文。

---

## 学习笔记（按时间线）

| 日期 | 主题 | 覆盖进度 | 查看 |
|------|------|---------|------|
| 2026-05-25 | Pod Deep Dive | Phase/Conditions/Probe/Init容器/QoS/故障状态 | [[k8s-知识总结-2026-05-25]] |
| 2026-05-26 | Workload Controllers | Deployment/StatefulSet/DaemonSet/Job/CronJob | [[k8s-知识总结-2026-05-26]] |
| 2026-05-28 | ConfigMap & Secret | Volume挂载/envFrom/symlink更新机制/base64 | [[k8s-知识总结-2026-05-28]] |
| 2026-05-31 | Service Deep Dive | kube-proxy工作模式/Service类型/EndpointSlice | [[k8s-知识总结-2026-05-31]] |

---

## K8s 知识体系全景

按照你的学习路线规划（来自 `2026-05-25` 笔记），完整知识框架如下：

| # | 概念 | 状态 | 对应笔记 |
|---|------|------|------|
| 1 | Node & Container Runtime | ✅ 已掌握 | 基础概念 |
| 2 | Pod Deep Dive | ✅ 已掌握 | [[k8s-知识总结-2026-05-25]] |
| 3 | Workload Controllers | ✅ 已掌握 | [[k8s-知识总结-2026-05-26]] |
| 4 | ConfigMap & Secret | ✅ 已掌握 | [[k8s-知识总结-2026-05-28]] |
| 5 | Service Deep Dive | 🟡 进行中 | [[k8s-知识总结-2026-05-31]] |
| 6 | Ingress & Gateway API | ⏳ 待学习 | [[容器与编排/Kubernetes/Ingress与网络策略/网络插件详解-Calico-Flannel]] |
| 7 | NetworkPolicy | ⏳ 待学习 | |
| 8 | Storage（PV/PVC/StorageClass） | ⏳ 待学习 | [[容器与编排/Kubernetes/存储卷]] |
| 9 | Scheduling & Resource Management | ⏳ 待学习 | |
| 10 | Autoscaling（HPA/VPA） | ⏳ 待学习 | [[张文暄/k8sHPA]] |
| 11 | Security（RBAC/ServiceAccount） | ⏳ 待学习 | [[容器与编排/Kubernetes/权限与安全/RBAC权限管理详解]] |

---

## 关联笔记

### 部署与更新
- [[k8s滚动更新]] — K8s 滚动更新实操

### 运维平台与项目
- [[张文暄/03Kubernetes 集群故障复盘：Flannel 镜像缺失引发的雪崩]] — 实战故障复盘
- [[张文暄/Kubernetes离线环境部署Metrics Server实战笔记]] — Metrics Server 部署
- [[张文暄/Web端调用Bash脚本实现分级Ping测试 项目实战笔记]] — Bash 集成项目
- [[张文暄/Web与后端交互无bash]] — Web 与后端交互

### AI + K8s 集成
- [[AI与LLM/项目Git + MLflow + K8s/模型版本管理 自动化测试（Git + MLflow + K8s）]] — MLflow + K8s
- [[AI与LLM/项目Git + MLflow + K8s/Ubuntu原生系统调用AMD RX580部署方案]] — RX580 + K8s 部署方案

### CI/CD 与 Helm
- [[容器与编排/Kubernetes/CI-CD与集成/CI-CD集成详解]] — CI/CD 集成
- [[容器与编排/Kubernetes/Helm与包管理/Helm包管理详解]] — Helm 包管理

### 容器运行时
- [[容器与编排/Kubernetes/容器运行时/Kubernetes-containerd容器运行时]] — containerd 运行时
