---
title: k8s滚动更新
tags:
  - "#容器/k8s/部署"
---

在 Kubernetes 中，**滚动更新（Rolling Update）主要通过 [[容器与编排/Kubernetes/基础知识/Kubernetes组件详细解析|Deployment]] 资源实现**，核心管理命令集中在 `kubectl rollout` 系列。以下是关键命令及实用技巧（以 Deployment 为例），相关概念可参考 [[容器与编排/Kubernetes/基础知识/Kubernetes知识梳理|Kubernetes知识梳理]]。滚动更新是 [[容器与编排/Kubernetes/CI-CD与集成/CI-CD集成详解|CI/CD]] 流水线中的关键部署环节，与 [[容器与编排/Kubernetes/容器运行时/Kubernetes 使用 containerd 作为容器运行时（详细步骤）|容器运行时]] 配合完成应用更新。

------

### **🔑 核心命令速查**

表格



| 场景          | 命令示例                                                     |
| :------------ | :----------------------------------------------------------- |
| **触发更新**  | `kubectl set image deployment/nginx-deploy nginx=nginx:1.25` `kubectl patch deployment nginx-deploy -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.25"}]}}}}'` `kubectl rollout restart deployment/nginx-deploy` *(重启触发，v1.15+)* |
| **监控进度**  | `kubectl rollout status deployment/nginx-deploy` `kubectl get pods -w -l app=nginx` *(实时观察 Pod 变化)* |
| **暂停/恢复** | `kubectl rollout pause deployment/nginx-deploy` `kubectl rollout resume deployment/nginx-deploy` |
| **回滚操作**  | `kubectl rollout undo deployment/nginx-deploy` *(回退至上一版)* `kubectl rollout undo deployment/nginx-deploy --to-revision=2` |
| **查看历史**  | `kubectl rollout history deployment/nginx-deploy` `kubectl rollout history deployment/nginx-deploy --revision=3` |

## 1. 发起滚动更新

### 更新镜像（最常用）



```bash
# 直接更新 Deployment 的镜像
kubectl set image deployment/<deployment-name> <container-name>=<new-image>:<tag>

# 示例：将 nginx 更新到新版本
kubectl set image deployment/nginx-deployment nginx=nginx:1.25.2
```

### 通过编辑配置更新



```bash
# 交互式编辑 Deployment 配置
kubectl edit deployment/<deployment-name>

# 修改 .spec.template.spec.containers[0].image 字段触发更新
```

### 应用 YAML 配置



```bash
# 应用更新后的 YAML 文件
kubectl apply -f deployment.yaml

# 或
kubectl replace -f deployment.yaml
```

### 使用 Patch 局部更新



```bash
kubectl patch deployment <deployment-name> -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.25.2"}]}}}}'
```

## 2. 查看更新状态



```bash
# 实时监控滚动更新进度（查看 ReplicaSet 替换过程）
kubectl rollout status deployment/<deployment-name>

# 查看 Deployment 历史版本
kubectl rollout history deployment/<deployment-name>

# 查看特定版本的详细信息
kubectl rollout history deployment/<deployment-name> --revision=2

# 查看 Pod 替换情况
kubectl get pods -l app=<label> -w
```

## 3. 暂停与恢复更新



```bash
# 暂停滚动更新（用于调试或批量修改配置）
kubectl rollout pause deployment/<deployment-name>

# 恢复更新
kubectl rollout resume deployment/<deployment-name>
```

## 4. 回滚操作



```bash
# 回滚到上一个版本
kubectl rollout undo deployment/<deployment-name>

# 回滚到指定版本
kubectl rollout undo deployment/<deployment-name> --to-revision=2
```

> 💡 **集成建议**：滚动更新是 CI/CD 流水线的关键环节。结合 [[../../Helm与包管理/Helm包管理详解|Helm]] 可以实现版本化部署管理，配合 [[../../CI-CD与集成/CI-CD集成详解|CI/CD 工具]] 可完全自动化更新流程。详细的 Kubernetes 知识体系参考 [[../../基础知识/Kubernetes知识梳理|Kubernetes 知识梳理]]。

## 相关笔记

- [[../../基础知识/Kubernetes知识梳理|Kubernetes 知识梳理]] — 集群知识体系
- [[../../基础知识/Kubernetes组件详细解析|Kubernetes 组件详细解析]] — Deployment 控制器与滚动更新原理
- [[../../CI-CD与集成/CI-CD集成详解|CI/CD 集成详解]] — 自动化部署流水线
- [[../../Helm与包管理/Helm包管理详解|Helm 包管理详解]] — 版本化部署管理
- [[../../Ingress与网络策略/网络插件详解（Calico-Flannel）|网络插件详解]] — 网络插件与更新期间网络通信
- [[../../权限与安全/RBAC权限管理详解|RBAC 权限管理详解]] — 部署相关的 RBAC 权限配置
- [[../../容器运行时/Kubernetes 使用 containerd 作为容器运行时（详细步骤）|containerd 容器运行时]] — 容器运行时与滚动更新配合
- [[../../Docker/Compose进阶/Docker vs Docker Compose|Docker vs Docker Compose]] — 容器基础技术
- [[../../../监控与可观测性/Prometheus/Kubernetes监控部署指南|Kubernetes 监控部署指南]] — 部署监控与告警