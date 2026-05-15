# Kubernetes 网络插件详解：Calico 与 Flannel

基于项目描述中的"配置网络插件（如 Calico 或 Flannel）以实现 Pod 网络"，以下是网络插件的详细知识：

## 一、Kubernetes 网络模型

### 1.1 网络要求
1. **Pod 间通信**：所有 Pod 可以不经过 NAT 直接通信
2. **节点间通信**：节点上的 Pod 可以与所有节点上的 Pod 通信
3. **Pod 与 Service**：Pod 可以不经过 NAT 与 Service 通信
4. **外部访问**：外部客户端可以不经过 NAT 访问 Service

### 1.2 CNI 标准
- **容器网络接口**：标准化容器网络配置
- **插件架构**：可插拔的网络解决方案
- **配置格式**：JSON 格式的网络配置

## 二、Flannel 网络插件

### 2.1 架构概述
- **简单 overlay 网络**：使用 VXLAN 或 host-gw
- **中央 etcd 存储**：存储网络配置
- **每个节点代理**：flanneld 守护进程

### 2.2 网络模式

#### 2.2.1 VXLAN 模式（默认）
```json
{
  "Network": "10.244.0.0/16",
  "SubnetLen": 24,
  "SubnetMin": "10.244.1.0",
  "SubnetMax": "10.244.255.0",
  "Backend": {
    "Type": "vxlan",
    "Port": 8472
  }
}
```
**特点**：
- 封装 Pod 流量在 UDP 包中
- 支持跨子网通信
- 性能开销较大

#### 2.2.2 host-gw 模式
```json
{
  "Network": "10.244.0.0/16",
  "Backend": {
    "Type": "host-gw"
  }
}
```
**特点**：
- 直接路由，无封装
- 高性能
- 要求节点在同一二层网络

#### 2.2.3 UDP 模式（已弃用）
- 最早的实现
- 性能最差
- 仅用于测试

### 2.3 部署配置
```yaml
# kube-flannel.yml
apiVersion: v1
kind: Namespace
metadata:
  name: kube-flannel
  labels:
    pod-security.kubernetes.io/enforce: privileged
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flannel
  namespace: kube-flannel
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: flannel
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list", "watch"]
- apiGroups: [""]
  resources: ["nodes/status"]
  verbs: ["patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flannel
subjects:
- kind: ServiceAccount
  name: flannel
  namespace: kube-flannel
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds
  namespace: kube-flannel
  labels:
    tier: node
    app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/os
                operator: In
                values:
                - linux
      hostNetwork: true
      priorityClassName: system-node-critical
      tolerations:
      - operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni
        image: flannelcni/flannel:v0.22.0
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: flannelcni/flannel:v0.22.0
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
            add: ["NET_ADMIN", "NET_RAW"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: run
          mountPath: /run/flannel
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
        - name: xtables-lock
          mountPath: /run/xtables.lock
      volumes:
      - name: run
        hostPath:
          path: /run/flannel
      - name: cni
        hostPath:
          path: /etc/cni/net.d
      - name: flannel-cfg
        configMap:
          name: kube-flannel-cfg
      - name: xtables-lock
        hostPath:
          path: /run/xtables.lock
          type: FileOrCreate
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-flannel-cfg
  namespace: kube-flannel
  labels:
    tier: node
    app: flannel
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan"
      }
    }
```

### 2.4 优缺点
**优点**：
- 部署简单
- 社区支持好
- 稳定可靠

**缺点**：
- 缺少网络策略
- 性能一般
- 功能相对简单

## 三、Calico 网络插件

### 3.1 架构概述
- **BGP 路由**：使用 BGP 协议传播路由
- **网络策略**：强大的网络策略引擎
- **eBPF 加速**：可选 eBPF 数据平面

### 3.2 组件构成

#### 3.2.1 Felix
- 运行在每个节点上
- 配置路由和 ACL 规则
- 报告节点状态

#### 3.2.2 BIRD
- BGP 客户端
- 交换路由信息
- 支持 BGP 路由反射器

#### 3.2.3 calicoctl
- 命令行管理工具
- 配置和管理 Calico

#### 3.2.4 Typha
- 数据存储代理
- 减少 etcd 连接数
- 提高扩展性

### 3.3 部署模式

#### 3.3.1 Overlay 模式（IP-in-IP）
```yaml
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: default-ipv4-ippool
spec:
  cidr: 192.168.0.0/16
  ipipMode: Always
  natOutgoing: true
```

#### 3.3.2 BGP 模式（纯路由）
```yaml
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: default-ipv4-ippool
spec:
  cidr: 192.168.0.0/16
  ipipMode: Never
  natOutgoing: false
```

### 3.4 部署配置
```bash
# 使用 operator 部署
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/custom-resources.yaml
```

```yaml
# custom-resources.yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
```

### 3.5 网络策略

#### 3.5.1 基本策略
```yaml
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: allow-tcp-6379
  namespace: production
spec:
  selector: app == 'redis'
  types:
  - Ingress
  - Egress
  ingress:
  - action: Allow
    protocol: TCP
    source:
      selector: app == 'app'
    destination:
      ports:
      - 6379
  egress:
  - action: Allow
```

#### 3.5.2 全局网络策略
```yaml
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: default-deny
spec:
  selector: all()
  types:
  - Ingress
  - Egress
  ingress:
  - action: Deny
  egress:
  - action: Deny
```

### 3.6 优缺点
**优点**：
- 高性能（BGP 模式）
- 强大的网络策略
- 生产环境验证
- 支持 eBPF 加速

**缺点**：
- 配置相对复杂
- 需要 BGP 知识（纯路由模式）
- 资源消耗较大

## 四、网络插件对比

### 4.1 功能对比
| 特性 | Flannel | Calico |
|------|---------|--------|
| **网络模型** | Overlay (VXLAN) | BGP/IP-in-IP/VXLAN |
| **网络策略** | 无 | 有（基于标签） |
| **性能** | 中等 | 高（BGP 模式） |
| **扩展性** | 好 | 优秀 |
| **部署复杂度** | 简单 | 中等 |
| **生产就绪** | 是 | 是 |
| **社区支持** | 好 | 优秀 |

### 4.2 选择建议
- **测试/开发环境**：Flannel（简单易用）
- **生产环境**：Calico（需要网络策略）
- **高性能需求**：Calico BGP 模式
- **云环境**：Calico（更好的云集成）
- **简单网络**：Flannel（无需复杂配置）

## 五、网络问题排查

### 5.1 通用排查命令
```bash
# 检查节点网络
ip addr show
ip route show

# 检查 CNI 配置
ls -la /etc/cni/net.d/
cat /etc/cni/net.d/*

# 检查 CNI 二进制文件
ls -la /opt/cni/bin/

# 检查 Pod 网络
kubectl exec <pod> -- ip addr
kubectl exec <pod> -- ping <target>
```

### 5.2 Flannel 特定排查
```bash
# 检查 flannel 接口
ip -d link show flannel.1

# 检查 flannel 路由
ip route show | grep flannel

# 查看 flannel 日志
kubectl logs -n kube-flannel -l app=flannel

# 检查 etcd 网络配置
etcdctl get /coreos.com/network/config
```

### 5.3 Calico 特定排查
```bash
# 检查 calico 节点状态
calicoctl get nodes
calicoctl node status

# 检查 BGP 对等体
calicoctl get bgppeers

# 检查 IP 池
calicoctl get ippools

# 检查网络策略
calicoctl get networkpolicy --all-namespaces

# 查看 felix 日志
kubectl logs -n calico-system -l k8s-app=calico-node
```

### 5.4 常见问题解决

#### 5.4.1 Pod 无法跨节点通信
```bash
# 检查网络插件状态
kubectl get pods -n kube-flannel
kubectl get pods -n calico-system

# 检查节点路由
ip route show

# 检查防火墙规则
iptables -L -n
```

#### 5.4.2 Service 无法访问
```bash
# 检查 kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy

# 检查 iptables 规则
iptables -t nat -L KUBE-SERVICES

# 检查 DNS 解析
kubectl run test --image=busybox --rm -it -- nslookup kubernetes.default
```

#### 5.4.3 网络策略不生效
```bash
# 检查网络策略
kubectl get networkpolicy --all-namespaces
calicoctl get networkpolicy --all-namespaces

# 检查策略日志
kubectl logs -n calico-system -l k8s-app=calico-node | grep -i policy

# 验证策略选择器
kubectl get pods --show-labels
```

## 六、自动化部署配置

### 6.1 Ansible 网络插件部署
```yaml
# roles/network/tasks/main.yml
- name: Determine network plugin
  set_fact:
    network_plugin: "{{ 'calico' if network_calico_enabled else 'flannel' }}"

- name: Deploy Flannel
  when: network_plugin == 'flannel'
  k8s:
    state: present
    src: "{{ role_path }}/files/flannel.yml"

- name: Deploy Calico
  when: network_plugin == 'calico'
  k8s:
    state: present
    src: "{{ role_path }}/files/calico.yml"
```

### 6.2 Helm 网络插件部署
```yaml
# values-flannel.yaml
flannel:
  enabled: true
  backend: "vxlan"
  network: "10.244.0.0/16"
  ipMasq: true

# values-calico.yaml
calico:
  enabled: true
  ipv4Pool: "10.244.0.0/16"
  ipv4PoolIpip: "Always"
  ipv4PoolBlockSize: 26
  felix:
    prometheusMetricsEnabled: true
```

### 6.3 Terraform 网络配置
```hcl
resource "helm_release" "calico" {
  name       = "calico"
  repository = "https://projectcalico.docs.tigera.io/charts"
  chart      = "tigera-operator"
  namespace  = "tigera-operator"
  
  set {
    name  = "installation.calicoNetwork.ipPools[0].cidr"
    value = "10.244.0.0/16"
  }
  
  set {
    name  = "installation.calicoNetwork.ipPools[0].encapsulation"
    value = "VXLAN"
  }
}
```

## 七、性能优化

### 7.1 Flannel 优化
```json
{
  "Network": "10.244.0.0/16",
  "Backend": {
    "Type": "vxlan",
    "Port": 8472,
    "VNI": 1,
    "GBP": true
  },
  "mtu": 1450
}
```

### 7.2 Calico 优化
```yaml
apiVersion: projectcalico.org/v3
kind: FelixConfiguration
metadata:
  name: default
spec:
  bpfEnabled: true
  bpfExternalServiceMode: "DSR"
  ipipEnabled: false
  vxlanEnabled: true
  logSeverityScreen: "Info"
  prometheusMetricsEnabled: true
```

### 7.3 通用优化
1. **调整 MTU**：根据网络环境优化
2. **启用硬件卸载**：如果网卡支持
3. **使用 eBPF**：Calico 的 eBPF 数据平面
4. **优化路由表**：减少路由条目
5. **监控网络性能**：使用 Prometheus 监控

---

**关键要点**：选择网络插件需根据实际需求，Flannel 适合简单场景，Calico 适合需要网络策略的生产环境。部署后需进行充分的测试和监控。