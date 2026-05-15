# Kubernetes Prometheus 监控部署指南

## 一、环境说明

### 1.1 集群信息

| 节点 | IP | 角色 | 状态 |
|------|-----|------|------|
| k8s-master | 192.168.233.10 | control-plane | Ready |
| k8s-node1 | 192.168.233.11 | worker | Ready |
| k8s-node2 | 192.168.233.12 | worker | NotReady (未开启) |

### 1.2 软件版本

- Kubernetes: v1.28.15
- Containerd: 2.2.2
- Helm: 3.20.2

---

## 二、部署前准备

### 2.1 安装 Helm

```bash
# 使用官方脚本安装
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# 验证安装
helm version
```

### 2.2 网络检查

```bash
# 测试 GitHub 访问
curl -I https://github.com

# 测试 DNS 解析
nslookup github.com
```

> 注意：如遇到 DNS 解析错误，可临时添加 hosts 映射：
> ```
> echo "20.205.243.166 github.com" >> /etc/hosts
> ```

---

## 三、Containerd 镜像源配置

### 3.1 在所有 Worker 节点配置

在 node1 (192.168.233.11) 上执行：

```bash
# 创建镜像配置目录
mkdir -p /etc/containerd/certs.d/docker.io
mkdir -p /etc/containerd/certs.d/gcr.io
mkdir -p /etc/containerd/certs.d/quay.io
mkdir -p /etc/containerd/certs.d/k8s.gcr.io
mkdir -p /etc/containerd/certs.d/registry.k8s.io

# 配置 Docker Hub 镜像
echo '[host "https://docker.m.daocloud.io"]
  capabilities = ["pull", "resolve"]' > /etc/containerd/certs.d/docker.io/hosts.toml

# 配置 GCR 镜像
echo '[host "https://gcr.m.daocloud.io"]
  capabilities = ["pull", "resolve"]' > /etc/containerd/certs.d/gcr.io/hosts.toml

# 配置 Quay 镜像
echo '[host "https://quay.m.daocloud.io"]
  capabilities = ["pull", "resolve"]' > /etc/containerd/certs.d/quay.io/hosts.toml

# 配置 k8s.gcr.io 镜像
echo '[host "https://k8s.m.daocloud.io"]
  capabilities = ["pull", "resolve"]' > /etc/containerd/certs.d/k8s.gcr.io/hosts.toml

# 配置 registry.k8s.io 镜像
echo '[host "https://docker.m.daocloud.io"]
  capabilities = ["pull", "resolve"]' > /etc/containerd/certs.d/registry.k8s.io/hosts.toml

# 重启 containerd
systemctl restart containerd
```

### 3.2 验证配置

```bash
# 测试拉取镜像
crictl pull docker.m.daocloud.io/library/nginx:alpine
```

---

## 四、部署 kube-prometheus-stack

### 4.1 添加 Helm 仓库

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 4.2 创建 monitoring 命名空间

```bash
kubectl create namespace monitoring
```

### 4.3 创建 values.yaml 配置文件

创建 `prometheus-values.yaml`:

```yaml
prometheus:
  service:
    type: NodePort
    nodePort: 30900
  prometheusSpec:
    retention: 15d
    storageSpec: null

grafana:
  enabled: true
  service:
    type: NodePort
    nodePort: 30090
  persistence:
    enabled: false
  adminPassword: admin123

alertmanager:
  service:
    type: NodePort
    nodePort: 30901

prometheus-node-exporter:
  service:
    type: NodePort

kube-state-metrics:
  enabled: true
```

### 4.4 执行安装

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f prometheus-values.yaml
```

### 4.5 验证部署

```bash
# 查看 Pod 状态
kubectl get pods -n monitoring

# 查看服务
kubectl get svc -n monitoring

# 查看详细信息
kubectl get pods -n monitoring -o wide
```

---

## 五、部署结果

### 5.1 组件状态

| 组件 | 状态 | 节点 | 端口 |
|------|------|------|------|
| Prometheus | Running | k8s-node1 | 30900 |
| Grafana | Running | k8s-node1 | 30090 |
| Alertmanager | Running | k8s-node1 | 30901 |
| node-exporter | Running | master/node1 | 31208 |
| prometheus-operator | Running | k8s-node1 | - |

### 5.2 服务信息

```bash
NAME                                      TYPE        CLUSTER-IP       PORT(S)
prometheus-grafana                        NodePort    10.108.174.179   80:30090/TCP
prometheus-kube-prometheus-alertmanager   NodePort    10.106.161.96    9093:30901/TCP
prometheus-kube-prometheus-prometheus     NodePort    10.102.104.183   9090:30900/TCP
prometheus-kube-state-metrics             ClusterIP   10.102.169.243   8080/TCP
prometheus-prometheus-node-exporter       NodePort    10.96.65.26      9100:31208/TCP
```

### 5.3 访问地址

| 服务 | 地址 | 账号 |
|------|------|------|
| Prometheus | http://192.168.233.10:30900 | - |
| Grafana | http://192.168.233.10:30090 | admin / admin123 |
| Alertmanager | http://192.168.233.10:30901 | - |

---

## 六、常见问题

### 6.1 节点 NotReady

**问题描述**: 节点状态为 NotReady

**解决方案**:
1. 检查节点 hostname 是否与集群注册名一致
2. 在节点上执行:
   ```bash
   hostnamectl set-hostname k8s-node1
   echo "192.168.233.11 k8s-node1" >> /etc/hosts
   systemctl restart kubelet
   ```

### 6.2 镜像拉取失败

**问题描述**: Pod 状态为 ImagePullBackOff

**解决方案**:
1. 确认 containerd 镜像配置正确
2. 手动测试拉取: `crictl pull <镜像地址>`
3. 检查镜像源是否可用

### 6.3 网络问题

**问题描述**: 无法访问 GitHub/Docker Hub

**解决方案**:
1. 检查 DNS: `nslookup github.com`
2. 如 DNS 异常，添加 hosts 映射
3. 检查网络连通性: `ping github.com`
4. 确认网关/DNS 服务器配置正确

---

## 七、卸载

```bash
# 卸载 Prometheus
helm uninstall prometheus -n monitoring

# 删除命名空间
kubectl delete namespace monitoring
```

---

## 八、后续配置

1. **Grafana 配置**:
   - 登录 Grafana (http://<IP>:30090)
   - 添加 Prometheus 数据源: http://prometheus-kube-prometheus-prometheus:9090
   - 导入 Dashboard (ID: 6417 - Kubernetes cluster monitoring)

2. **告警配置**:
   - 在 Prometheus 中配置告警规则
   - 在 Alertmanager 中配置通知渠道

---

**文档版本**: v1.0  
**创建时间**: 2026-04-14  
**适用版本**: Kubernetes 1.28+ / Helm 3.x / kube-prometheus-stack 83.x