# Kubernetes RBAC 权限管理详解

基于项目描述中的"配置 Kubernetes 证书与 RBAC 权限管理"，以下是 RBAC 的详细知识：

## 一、RBAC 核心概念

### 1.1 基本组件
- **Subject**：权限的接收者（User、Group、ServiceAccount）
- **Role**：权限的集合，定义在命名空间内
- **ClusterRole**：集群范围的权限集合
- **RoleBinding**：将 Role 绑定到 Subject（命名空间内）
- **ClusterRoleBinding**：将 ClusterRole 绑定到 Subject（集群范围）

### 1.2 权限模型
```
Subject → (Cluster)RoleBinding → (Cluster)Role → API Resources
    ↑                             ↑
  用户/服务账户                   权限规则集合
```

## 二、RBAC 资源定义

### 2.1 Role 定义
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]  # 核心 API 组
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

### 2.2 ClusterRole 定义
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
- nonResourceURLs: ["*"]
  verbs: ["*"]
```

### 2.3 RoleBinding 定义
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### 2.4 ClusterRoleBinding 定义
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-secrets-global
subjects:
- kind: Group
  name: system:authenticated
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
```

## 三、权限规则详解

### 3.1 API Groups
- **""**：核心 API 组（如 Pod、Service、ConfigMap）
- **"apps"**：apps API 组（如 Deployment、StatefulSet）
- **"batch"**：batch API 组（如 Job、CronJob）
- **"extensions"**：扩展 API 组
- **"*"**：所有 API 组

### 3.2 Resources
- **pods**：Pod 资源
- **services**：Service 资源
- **deployments**：Deployment 资源
- **secrets**：Secret 资源
- **configmaps**：ConfigMap 资源
- **persistentvolumes**：PV 资源
- ***"**：所有资源

### 3.3 Verbs（操作动词）
- **get**：获取单个资源
- **list**：列出资源
- **watch**：监视资源变化
- **create**：创建资源
- **update**：更新资源
- **patch**：部分更新资源
- **delete**：删除资源
- **deletecollection**：删除资源集合
- **"*"**：所有操作

### 3.4 Resource Names
```yaml
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["my-config"]
  verbs: ["get"]
```
限制只对特定名称的资源有权限。

## 四、预定义 ClusterRoles

### 4.1 系统预定义角色
- **cluster-admin**：超级管理员，拥有所有权限
- **admin**：命名空间管理员
- **edit**：命名空间编辑者
- **view**：命名空间查看者

### 4.2 详细权限
```yaml
# cluster-admin 权限
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
- nonResourceURLs: ["*"]
  verbs: ["*"]

# admin 权限（在命名空间内）
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
# 但不能修改资源配额和命名空间本身

# edit 权限
# 可以读写大部分资源，但不能查看或修改 RBAC

# view 权限
# 只能查看资源，不能修改
```

## 五、ServiceAccount 权限管理

### 5.1 ServiceAccount 创建
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-serviceaccount
  namespace: default
```

### 5.2 Pod 使用 ServiceAccount
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  serviceAccountName: my-serviceaccount
  containers:
  - name: my-container
    image: nginx
```

### 5.3 为 ServiceAccount 授权
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-sa-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: my-serviceaccount
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

## 六、最佳实践

### 6.1 最小权限原则
- 只授予完成工作所需的最小权限
- 避免使用 cluster-admin 等宽泛权限
- 定期审计权限分配

### 6.2 角色设计模式
```yaml
# 开发人员角色
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: dev
  name: developer
rules:
- apiGroups: ["", "apps", "batch"]
  resources: ["pods", "deployments", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# 运维人员角色
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: operator
rules:
- apiGroups: [""]
  resources: ["nodes", "persistentvolumes", "storageclasses"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
```

### 6.3 命名空间隔离
```yaml
# 为每个团队创建独立命名空间
apiVersion: v1
kind: Namespace
metadata:
  name: team-a

# 团队管理员
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-a-admin
  namespace: team-a
subjects:
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
```

## 七、权限检查与调试

### 7.1 权限检查命令
```bash
# 检查用户权限
kubectl auth can-i create pods
kubectl auth can-i delete pods --as=system:serviceaccount:default:my-sa

# 检查详细权限
kubectl auth can-i --list
kubectl auth can-i --list --as=system:serviceaccount:default:my-sa

# 模拟权限检查
kubectl auth can-i create deployments --namespace=production --as=developer
```

### 7.2 查看现有绑定
```bash
# 查看所有 RoleBinding
kubectl get rolebindings --all-namespaces

# 查看所有 ClusterRoleBinding
kubectl get clusterrolebindings

# 查看绑定详情
kubectl describe rolebinding <name> -n <namespace>
kubectl describe clusterrolebinding <name>
```

### 7.3 审计日志
```yaml
# API Server 审计配置
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  users: ["system:serviceaccount:kube-system:default"]
  verbs: ["get", "list", "watch"]
- level: Request
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods"]
  verbs: ["create", "update", "patch", "delete"]
```

## 八、证书与 RBAC 集成

### 8.1 用户证书创建
```bash
# 生成私钥
openssl genrsa -out jane.key 2048

# 生成证书签名请求
openssl req -new -key jane.key -out jane.csr \
  -subj "/CN=jane/O=developers"

# 使用集群 CA 签名
openssl x509 -req -in jane.csr \
  -CA /etc/kubernetes/pki/ca.crt \
  -CAkey /etc/kubernetes/pki/ca.key \
  -CAcreateserial -out jane.crt -days 365
```

### 8.2 kubeconfig 配置
```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: <ca-cert-base64>
    server: https://kubernetes:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: jane
  name: jane-context
current-context: jane-context
users:
- name: jane
  user:
    client-certificate-data: <jane-cert-base64>
    client-key-data: <jane-key-base64>
```

### 8.3 组权限管理
```yaml
# 为组授权
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developers-binding
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: rbac.authorization.k8s.io
```

## 九、自动化部署中的 RBAC 配置

### 9.1 Ansible 模板
```yaml
# roles/kubernetes/templates/rbac.yaml.j2
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: {{ role_name }}
rules:
{% for rule in rules %}
- apiGroups: {{ rule.api_groups | to_yaml }}
  resources: {{ rule.resources | to_yaml }}
  verbs: {{ rule.verbs | to_yaml }}
{% endfor %}
```

### 9.2 Helm Chart 中的 RBAC
```yaml
# templates/rbac.yaml
{{- if .Values.rbac.create }}
apiVersion: rbac.authorization.k8s.io/v1
kind: {{ .Values.rbac.kind }}
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
rules:
{{- toYaml .Values.rbac.rules | nindent 2 }}
{{- end }}
```

### 9.3 值文件配置
```yaml
# values.yaml
rbac:
  create: true
  kind: Role
  rules:
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
```

---

**关键要点**：RBAC 是 Kubernetes 安全的核心，需要结合证书管理、命名空间隔离和最小权限原则，构建安全的集群访问控制体系。