# Kubernetes 组件详细解析

基于项目描述中提到的组件，以下是各核心组件的详细知识：

## 一、控制平面组件（Master Node）

### 1.1 kube-apiserver
**功能**：集群的统一入口，处理所有 REST 请求
**关键特性**：

- 认证（Authentication）：验证用户身份
- 授权（Authorization）：检查用户权限
- 准入控制（Admission Control）：资源验证和修改
- API 版本管理：支持多版本 API

**配置要点**：
```yaml
# 典型配置
--etcd-servers=https://127.0.0.1:2379
--bind-address=0.0.0.0
--secure-port=6443
--tls-cert-file=/etc/kubernetes/pki/apiserver.crt
--tls-private-key-file=/etc/kubernetes/pki/apiserver.key
--client-ca-file=/etc/kubernetes/pki/ca.crt
--authorization-mode=Node,RBAC
```

### 1.2 kube-scheduler
**功能**：为 Pod 选择运行节点
**调度策略**：
- 预选（Predicates）：过滤不满足条件的节点
- 优选（Priorities）：为节点打分
- 绑定（Binding）：将 Pod 绑定到节点

**调度考虑因素**：
- 资源需求（CPU、内存）
- 节点亲和性/反亲和性
- Pod 亲和性/反亲和性
- 污点和容忍度
- 节点压力

### 1.3 kube-controller-manager
**功能**：运行各种控制器，确保集群状态符合期望

**核心控制器**：

1. **Node Controller**：监控节点状态、处理节点异常与 Pod 驱逐
2. **Replication Controller**：维护 Pod 固定副本数量（旧版）
3. **ReplicaSet Controller**：基于标签维护 Pod 副本，支持Deployment
4. **Deployment Controller**：管理应用滚动更新、扩缩容与回滚
5. **DaemonSet Controller**：保证每个节点运行一个常驻 Pod
6. **StatefulSet Controller**：管理有状态应用，保证有序启动与稳定标识
7. **Endpoint/EndpointSlice Controller**：维护 Service 和后端 Pod 的地址关联
8. **Service Controller**：管理 Service 生命周期与负载均衡
9. **Namespace Controller**：管理命名空间创建、删除与资源回收
10. **ResourceQuota Controller**：限制命名空间资源最大使用量
11. **LimitRange Controller**：给 Pod、容器设置默认资源上下限
12. **ServiceAccount & Token Controllers**：自动创建账号、分发 API 访问令牌
13. **PV & PVC Controller**：绑定、回收、管理持久化存储
14. **StorageClass Provisioner Controller**：动态自动创建存储卷
15. **Job & CronJob Controller**：管理一次性任务和定时任务
16. **HPA Controller**：根据指标自动伸缩 Pod 副本数
17. **CSR Certificate Controller**：审批、签发集群内部 TLS 证书

### 1.4 etcd
**功能**：分布式键值存储，保存集群所有状态
**关键特性**：
- 强一致性：Raft 共识算法
- 高可用：多节点集群
- 数据持久化：WAL 日志和快照
- 租约机制：键值对过期

**备份恢复**：
```bash
# 备份
ETCDCTL_API=3 etcdctl snapshot save snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 恢复
ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --data-dir /var/lib/etcd-backup
```

## 二、工作节点组件（Worker Node）

### 2.1 kubelet
**功能**：节点代理，管理 Pod 生命周期

**主要职责**：
1. **Pod 管理**：接收、创建、监控 Pod
2. **容器运行时接口**：通过 CRI 与容器运行时通信
3. **容器网络接口**：通过 CNI 配置网络
4. **容器存储接口**：通过 CSI 管理存储
5. **节点状态上报**：向 API Server 报告节点状态

**关键配置**：
```yaml
--pod-manifest-path=/etc/kubernetes/manifests
--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock
--network-plugin=cni
--cni-conf-dir=/etc/cni/net.d
--cni-bin-dir=/opt/cni/bin
--node-ip=<node-ip>
--hostname-override=<node-name>
```

### 2.2 kube-proxy
**功能**：网络代理，实现 Service 的负载均衡

**工作模式**：

1. **userspace 模式**：用户空间代理（已弃用）
2. **iptables 模式**：默认模式，使用 iptables 规则
3. **IPVS 模式**：高性能模式，使用 IPVS 内核模块

**Service 类型支持**：
- **ClusterIP**：集群内部 IP
- **NodePort**：节点端口暴露
- **LoadBalancer**：云提供商负载均衡器
- **ExternalName**：外部服务别名

### 2.3 容器运行时
**支持类型**：
- **Docker**：传统选择（已弃用，通过 cri-dockerd）
- **containerd**：推荐选择，CNCF 毕业项目
- **CRI-O**：专为 Kubernetes 设计

**配置示例（containerd）**：

```toml
version = 2
[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "registry.k8s.io/pause:3.9"
[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "runc"
```

## 三、网络组件

### 3.1 CNI 插件
**功能**：实现 Pod 网络配置

**常见插件对比**：

| 插件 | 网络模型 | 特点 | 适用场景 |
|------|---------|------|---------|
| **Calico** | BGP/Overlay | 网络策略、高性能 | 生产环境、需要网络策略 |
| **Flannel** | Overlay | 简单、稳定 | 测试环境、简单网络 |
| **Cilium** | eBPF | 高性能、安全 | 高性能需求、安全敏感 |
| **Weave Net** | Overlay | 简单部署、加密 | 简单部署、安全通信 |

### 3.2 DNS 服务
**CoreDNS**：集群 DNS 解析
**配置**：
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
```

## 四、附加组件

### 4.1 Dashboard
**功能**：Web 管理界面
**部署**：
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

**访问控制**：
```yaml
# 创建管理员 ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
# 绑定 ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

### 4.2 Metrics Server
**功能**：收集资源使用指标
**部署**：
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**配置**：
```yaml
# 添加额外参数
args:
  - --kubelet-insecure-tls
  - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
```

## 五、组件交互关系

### 5.1 启动流程
1. **etcd 启动**：提供数据存储
2. **API Server 启动**：提供 REST API
3. **Controller Manager 启动**：开始控制循环
4. **Scheduler 启动**：准备调度 Pod
5. **kubelet 启动**：注册节点，启动 Pod
6. **kube-proxy 启动**：配置网络规则

### 5.2 通信机制
- **组件间通信**：TLS 加密通信
- **Pod 间通信**：CNI 插件配置
- **Service 发现**：DNS 和环境变量
- **监控数据**：Metrics API 和 cAdvisor

## 六、故障排查

### 6.1 组件状态检查
```bash
# 检查组件状态
kubectl get componentstatuses

# 检查节点状态
kubectl get nodes

# 检查 Pod 状态
kubectl get pods -n kube-system

# 查看组件日志
kubectl logs -n kube-system <pod-name>
```

### 6.2 常见问题
1. **API Server 无法连接 etcd**：检查证书和网络
2. **kubelet 无法注册**：检查节点配置和证书
3. **Pod 调度失败**：检查资源配额和节点状态
4. **Service 无法访问**：检查 kube-proxy 和网络插件

### 6.3 调试命令
```bash
# 描述资源详情
kubectl describe <resource> <name>

# 查看事件
kubectl get events --sort-by='.lastTimestamp'

# 进入容器调试
kubectl exec -it <pod-name> -- /bin/sh

# 端口转发
kubectl port-forward <pod-name> <local-port>:<pod-port>
```

---

**学习建议**：通过实际操作部署这些组件，理解它们之间的依赖关系和通信机制，掌握故障排查的基本方法。