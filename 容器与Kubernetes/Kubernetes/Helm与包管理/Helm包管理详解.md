# Helm 包管理详解

基于项目描述中的"集成 Helm 包管理工具，自动化部署常见的应用服务"，以下是 Helm 的详细知识：

## 一、Helm 基础概念

### 1.1 核心组件
- **Chart**：Helm 包，包含部署应用所需的所有资源定义
- **Release**：Chart 的部署实例，有唯一名称
- **Repository**：Chart 仓库，存储和分享 Chart
- **Values**：可配置参数，用于定制 Chart

### 1.2 Helm 架构
```
Helm Client → Tiller (v2) / Helm Library (v3) → Kubernetes API Server
     ↓              ↓                  ↓
 用户命令    服务端组件（v2已弃用）   直接与K8s交互（v3）
```

## 二、Helm v3 新特性

### 2.1 主要变化
- **移除 Tiller**：直接使用 kubeconfig 与集群交互
- **改进安全模型**：基于 RBAC 的权限控制
- **Library Charts**：可重用的 Chart 组件
- **JSON Schema 验证**：Values 文件验证
- **依赖管理改进**：Chart.yaml 中的 dependencies

### 2.2 安装 Helm v3
```bash
# Linux
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Windows (PowerShell)
choco install kubernetes-helm

# 验证安装
helm version
```

## 三、Chart 结构详解

### 3.1 标准 Chart 目录结构
```
mychart/
├── Chart.yaml          # Chart 元数据
├── values.yaml         # 默认配置值
├── charts/             # 依赖的子 Chart
├── templates/          # 模板文件
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── _helpers.tpl    # 辅助模板
│   └── tests/          # 测试文件
└── README.md           # 文档
```

### 3.2 Chart.yaml
```yaml
apiVersion: v2
name: myapp
description: A Helm chart for Kubernetes
type: application
version: 1.0.0
appVersion: "2.0.0"

# 依赖管理
dependencies:
  - name: mysql
    version: "8.8.0"
    repository: "https://charts.bitnami.com/bitnami"
    condition: mysql.enabled
  - name: redis
    version: "14.0.0"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled

# 维护者信息
maintainers:
  - name: John Doe
    email: john@example.com
    url: https://example.com

# 注解
annotations:
  category: Database
```

### 3.3 values.yaml
```yaml
# 全局配置
global:
  imagePullSecrets: []
  storageClass: "standard"

# 副本数配置
replicaCount: 1

# 镜像配置
image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.21.0"

# 服务配置
service:
  type: ClusterIP
  port: 80
  targetPort: 80
  nodePort: null

# 资源限制
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"

# 自动伸缩
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

# 持久化存储
persistence:
  enabled: true
  storageClass: "standard"
  accessMode: ReadWriteOnce
  size: 8Gi

# 探针配置
livenessProbe:
  enabled: true
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  enabled: true
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 1
```

## 四、模板引擎

### 4.1 Go 模板语法
```yaml
# 基本变量
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-{{ .Chart.Name }}
  labels:
    app: {{ .Values.appName | default .Chart.Name }}
    chart: {{ .Chart.Name }}-{{ .Chart.Version }}
    release: {{ .Release.Name }}

# 条件判断
{{- if .Values.service.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
{{- end }}

# 循环
{{- range .Values.extraVolumes }}
- name: {{ .name }}
  {{ .type }}:
    {{- toYaml . | nindent 4 }}
{{- end }}

# 管道和函数
{{ .Values.image.repository }}:{{ .Values.image.tag | default "latest" }}
{{ .Values.config | toYaml | indent 2 }}
```

### 4.2 内置对象
- **.Release**：Release 相关信息
- **.Chart**：Chart.yaml 内容
- **.Values**：values.yaml 和用户提供的值
- **.Files**：访问 Chart 中的文件
- **.Capabilities**：Kubernetes 集群信息
- **.Template**：当前模板信息

### 4.3 辅助函数 (_helpers.tpl)
```yaml
{{- define "mychart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "mychart.labels" -}}
helm.sh/chart: {{ include "mychart.chart" . }}
{{ include "mychart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "mychart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mychart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

## 五、Helm 命令详解

### 5.1 基本命令
```bash
# 搜索 Chart
helm search hub wordpress
helm search repo stable

# 添加仓库
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stable https://charts.helm.sh/stable
helm repo update

# 安装 Chart
helm install my-release bitnami/wordpress
helm install my-release ./mychart
helm install my-release ./mychart -f values.yaml
helm install my-release ./mychart --set replicaCount=3

# 升级 Release
helm upgrade my-release bitnami/wordpress
helm upgrade my-release ./mychart -f new-values.yaml
helm upgrade my-release ./mychart --set image.tag=v2.0

# 回滚 Release
helm rollback my-release 1
helm rollback my-release --dry-run

# 卸载 Release
helm uninstall my-release
helm uninstall my-release --keep-history

# 查看 Release
helm list
helm list --all
helm list --all-namespaces
helm status my-release
helm get all my-release
helm get values my-release
helm get manifest my-release

# 查看历史
helm history my-release
```

### 5.2 开发命令
```bash
# 创建新 Chart
helm create mychart

# 检查模板
helm lint ./mychart
helm template ./mychart
helm template ./mychart -f values.yaml
helm template ./mychart --debug

# 打包 Chart
helm package ./mychart
helm package ./mychart --destination ./dist

# 验证 Chart
helm verify ./mychart-1.0.0.tgz
helm dependency update ./mychart
helm dependency build ./mychart
```

### 5.3 高级命令
```bash
# 插件管理
helm plugin list
helm plugin install https://github.com/helm/helm-plugin-template
helm plugin update <plugin>
helm plugin uninstall <plugin>

# 仓库管理
helm repo list
helm repo remove bitnami
helm repo index ./charts

# 环境管理
helm env
```

## 六、依赖管理

### 6.1 Chart.yaml 依赖
```yaml
dependencies:
  - name: mysql
    version: "8.8.0"
    repository: "https://charts.bitnami.com/bitnami"
    condition: mysql.enabled
    tags:
      - database
    import-values:
      - child: default.data
        parent: mysql
    alias: primary-db
```

### 6.2 依赖操作
```bash
# 更新依赖
helm dependency update ./mychart

# 构建依赖
helm dependency build ./mychart

# 查看依赖
helm dependency list ./mychart
```

### 6.3 条件依赖
```yaml
# values.yaml
mysql:
  enabled: true
  auth:
    rootPassword: "secret"

# templates/mysql.yaml
{{- if .Values.mysql.enabled }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Release.Name }}-mysql
type: Opaque
data:
  root-password: {{ .Values.mysql.auth.rootPassword | b64enc }}
{{- end }}
```

## 七、测试与验证

### 7.1 Chart 测试
```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "mychart.fullname" . }}-test-connection"
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
spec:
  containers:
  - name: wget
    image: busybox
    command: ['wget']
    args: ['{{ include "mychart.fullname" . }}:{{ .Values.service.port }}']
  restartPolicy: Never
```

### 7.2 运行测试
```bash
# 安装时运行测试
helm install my-release ./mychart --atomic

# 手动运行测试
helm test my-release
helm test my-release --logs
```

### 7.3 验证 Values
```yaml
# values.schema.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Values",
  "type": "object",
  "properties": {
    "replicaCount": {
      "type": "integer",
      "minimum": 1,
      "maximum": 10
    },
    "image": {
      "type": "object",
      "properties": {
        "repository": {
          "type": "string"
        },
        "tag": {
          "type": "string",
          "pattern": "^[a-zA-Z0-9._-]+$"
        }
      },
      "required": ["repository"]
    }
  },
  "required": ["replicaCount", "image"]
}
```

## 八、高级特性

### 8.1 Hooks（钩子）
```yaml
# pre-install 钩子
apiVersion: batch/v1
kind: Job
metadata:
  name: "{{ .Release.Name }}-pre-install"
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: pre-install
        image: busybox
        command: ['sh', '-c', 'echo Pre-install hook']
      restartPolicy: Never

# post-upgrade 钩子
apiVersion: batch/v1
kind: Job
metadata:
  name: "{{ .Release.Name }}-post-upgrade"
  annotations:
    "helm.sh/hook": post-upgrade
    "helm.sh/hook-weight": "5"
spec:
  template:
    spec:
      containers:
      - name: post-upgrade
        image: busybox
        command: ['sh', '-c', 'echo Post-upgrade hook']
      restartPolicy: Never
```

### 8.2 钩子类型
- **pre-install**：安装前执行
- **post-install**：安装后执行
- **pre-upgrade**：升级前执行
- **post-upgrade**：升级后执行
- **pre-rollback**：回滚前执行
- **post-rollback**：回滚后执行
- **pre-delete**：删除前执行
- **post-delete**：删除后执行
- **test**：测试时执行

### 8.3 库 Chart（Library Chart）
```yaml
# Chart.yaml
apiVersion: v2
name: common
description: A library chart for common templates
type: library
version: 1.0.0

# _helpers.tpl
{{- define "common.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

## 九、CI/CD 集成

### 9.1 GitHub Actions
```yaml
# .github/workflows/helm.yaml
name: Helm Chart CI/CD
on:
  push:
    branches: [ main ]
    paths:
      - 'charts/**'
  pull_request:
    branches: [ main ]

jobs:
  lint-test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Set up Helm
      uses: azure/setup-helm@v1
    - name: Run Helm Lint
      run: helm lint ./charts/mychart
    - name: Run Helm Template
      run: helm template ./charts/mychart --debug

  package-publish:
    runs-on: ubuntu-latest
    needs: lint-test
    if: github.event_name == 'push'
    steps:
    - uses: actions/checkout@v2
    - name: Set up Helm
      uses: azure/setup-helm@v1
    - name: Package Chart
      run: helm package ./charts/mychart --destination ./dist
    - name: Upload Artifact
      uses: actions/upload-artifact@v2
      with:
        name: helm-chart
        path: ./dist
```

### 9.2 GitLab CI
```yaml
# .gitlab-ci.yml
stages:
  - lint
  - test
  - package
  - deploy

helm-lint:
  stage: lint
  image: alpine/helm:3.7.0
  script:
    - helm lint ./charts/mychart

helm-template:
  stage: test
  image: alpine/helm:3.7.0
  script:
    - helm template ./charts/mychart --debug

helm-package:
  stage: package
  image: alpine/helm:3.7.0
  script:
    - helm package ./charts/mychart --destination ./dist
  artifacts:
    paths:
      - ./dist

helm-deploy:
  stage: deploy
  image: alpine/helm:3.7.0
  script:
    - helm upgrade --install my-app ./charts/mychart -n production
  only:
    - main
```

### 9.3 ArgoCD 集成
```yaml
# application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/helm-charts.git
    targetRevision: HEAD
    path: charts/mychart
    helm:
      valueFiles:
        - values-production.yaml
      parameters:
        - name: replicaCount
          value: "3"
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## 十、最佳实践

### 10.1 Chart 设计原则
1. **单一职责**：一个 Chart 只部署一个应用
2. **可配置性**：通过 Values 文件提供配置选项
3. **向后兼容**：保持 Values 的向后兼容性
4. **文档完善**：提供详细的 README 和 Values 说明
5. **测试覆盖**：包含完整的测试用例

### 10.2 安全最佳实践
```yaml
# 使用 Secret 管理敏感信息
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Release.Name }}-secret
type: Opaque
data:
  password: {{ .Values.dbPassword | b64enc }}

# 在模板中引用
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Release.Name }}-secret
      key: password
```

### 10.3 性能优化
1. **减少模板复杂度**：避免复杂的模板逻辑
2. **使用命名模板**：重用模板代码
3. **合理使用钩子**：避免过多的钩子影响部署速度
4. **优化依赖管理**：减少不必要的依赖

### 10.4 版本管理
```bash
# 语义化版本
# 主版本.次版本.修订版本
# 1.2.3

# 版本升级策略
# 修订版本：bug 修复，向后兼容
# 次版本：新功能，向后兼容
# 主版本：重大变更，可能不兼容

# 发布流程
helm package ./mychart --version 1.2.3
helm push ./mychart-1.2.3.tgz myrepo
```

## 十一、常见问题排查

### 11.1 安装失败
```bash
# 查看详细错误
helm install my-release ./mychart --debug --dry-run

# 检查模板渲染
helm template ./mychart -f values.yaml

# 检查 Kubernetes 资源
kubectl get events --sort-by='.lastTimestamp'
```

### 11.2 升级失败
```bash
# 查看历史版本
helm history my-release

# 回滚到稳定版本
helm rollback my-release 2

# 检查 Values 差异
helm get values my-release --revision 2
helm get values my-release --revision 3
```

### 11.3 依赖问题
```bash
# 更新依赖
helm dependency update ./mychart

# 清理 charts 目录
rm -rf ./mychart/charts/*.tgz

# 重新构建
helm dependency build ./mychart
```

---

**关键要点**：Helm 是 Kubernetes 的包管理标准，通过 Chart 实现应用部署的标准化和自动化。掌握 Helm 可以大大提高 Kubernetes 应用的部署效率和管理能力。