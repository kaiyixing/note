# Kubernetes 监控系统详解：Prometheus + Grafana

基于项目描述中的"部署 Prometheus 和 Grafana 进行集群监控"，以下是监控系统的详细知识：

## 一、监控体系架构

### 1.1 监控层次
1. **基础设施层**：节点、网络、存储
2. **容器层**：Pod、容器运行时
3. **应用层**：应用性能、业务指标
4. **用户层**：用户体验、业务指标

### 1.2 监控组件
```
Prometheus (收集+存储+告警) → Grafana (可视化)
     ↑
cAdvisor (容器指标) + kube-state-metrics (K8s对象状态)
     ↑
Kubernetes 集群
```

## 二、Prometheus 详解

### 2.1 核心概念
- **指标（Metric）**：时间序列数据
- **标签（Label）**：指标的维度
- **抓取目标（Target）**：被监控的端点
- **作业（Job）**：一组相同配置的抓取目标
- **告警规则（Alerting Rule）**：触发告警的条件
- **记录规则（Recording Rule）**：预计算的指标

### 2.2 数据模型
```
metric_name{label1="value1", label2="value2"} value timestamp
示例：
container_cpu_usage_seconds_total{container="nginx", pod="web-1"} 123.45 1612345678
```

### 2.3 部署配置
```yaml
# prometheus.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    rule_files:
      - /etc/prometheus/rules/*.yml
    
    alerting:
      alertmanagers:
        - static_configs:
            - targets:
              - alertmanager:9093
    
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
          - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            action: keep
            regex: default;kubernetes;https
      
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
          - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          - target_label: __address__
            replacement: kubernetes.default.svc:443
          - source_labels: [__meta_kubernetes_node_name]
            regex: (.+)
            target_label: __metrics_path__
            replacement: /api/v1/nodes/${1}/proxy/metrics
      
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: kubernetes_pod_name
```

### 2.4 服务发现配置
```yaml
# Kubernetes 服务发现
kubernetes_sd_configs:
  - role: node      # 节点发现
  - role: pod       # Pod 发现
  - role: service   # Service 发现
  - role: endpoint  # Endpoint 发现
  - role: ingress   # Ingress 发现

# 文件服务发现
file_sd_configs:
  - files:
      - /etc/prometheus/targets/*.json
    refresh_interval: 5m

# 静态配置
static_configs:
  - targets:
      - 'localhost:9090'
      - 'localhost:9100'
```

## 三、cAdvisor 容器监控

### 3.1 功能特性
- **容器资源使用**：CPU、内存、磁盘、网络
- **容器统计信息**：进程数、文件描述符
- **历史数据**：保留一段时间的历史指标
- **集成简单**：kubelet 内置 cAdvisor

### 3.2 访问指标
```bash
# 通过 kubelet 访问
curl http://<node-ip>:10255/metrics/cadvisor

# 通过 API Server 代理
kubectl proxy --port=8080
curl http://localhost:8080/api/v1/nodes/<node-name>/proxy/metrics/cadvisor
```

### 3.3 关键指标
```promql
# CPU 使用率
rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m])

# 内存使用率
container_memory_working_set_bytes{container!="POD",container!=""}

# 网络流量
rate(container_network_receive_bytes_total[5m])
rate(container_network_transmit_bytes_total[5m])

# 磁盘 I/O
rate(container_fs_reads_bytes_total[5m])
rate(container_fs_writes_bytes_total[5m])
```

## 四、kube-state-metrics

### 4.1 功能特性
- **Kubernetes 对象状态**：Deployment、Pod、Node 等状态
- **资源配额监控**：命名空间资源使用
- **事件监控**：Kubernetes 事件
- **自定义指标**：扩展监控维度

### 4.2 部署配置
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-state-metrics
  namespace: monitoring
spec:
  replicas: 2
  selector:
    matchLabels:
      app: kube-state-metrics
  template:
    metadata:
      labels:
        app: kube-state-metrics
    spec:
      serviceAccountName: kube-state-metrics
      containers:
      - name: kube-state-metrics
        image: k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.3.0
        ports:
        - containerPort: 8080
          name: http-metrics
        - containerPort: 8081
          name: telemetry
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          timeoutSeconds: 5
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          timeoutSeconds: 5
        resources:
          limits:
            cpu: 100m
            memory: 150Mi
          requests:
            cpu: 50m
            memory: 100Mi
---
apiVersion: v1
kind: Service
metadata:
  name: kube-state-metrics
  namespace: monitoring
  labels:
    app: kube-state-metrics
spec:
  ports:
  - name: http-metrics
    port: 8080
    targetPort: http-metrics
    protocol: TCP
  - name: telemetry
    port: 8081
    targetPort: telemetry
    protocol: TCP
  selector:
    app: kube-state-metrics
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-state-metrics
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-state-metrics
rules:
- apiGroups: [""]
  resources: ["nodes", "pods", "services", "resourcequotas", "replicationcontrollers", "limitranges", "persistentvolumeclaims", "persistentvolumes", "namespaces", "endpoints"]
  verbs: ["list", "watch"]
- apiGroups: ["extensions"]
  resources: ["daemonsets", "deployments", "replicasets"]
  verbs: ["list", "watch"]
- apiGroups: ["apps"]
  resources: ["statefulsets", "daemonsets", "deployments", "replicasets"]
  verbs: ["list", "watch"]
- apiGroups: ["batch"]
  resources: ["cronjobs", "jobs"]
  verbs: ["list", "watch"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["list", "watch"]
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["list", "watch"]
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests"]
  verbs: ["list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "volumeattachments"]
  verbs: ["list", "watch"]
- apiGroups: ["admissionregistration.k8s.io"]
  resources: ["mutatingwebhookconfigurations", "validatingwebhookconfigurations"]
  verbs: ["list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies", "ingresses"]
  verbs: ["list", "watch"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-state-metrics
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-state-metrics
subjects:
- kind: ServiceAccount
  name: kube-state-metrics
  namespace: monitoring
```

### 4.3 关键指标
```promql
# Pod 状态
kube_pod_status_phase{phase="Running"}
kube_pod_status_phase{phase="Pending"}
kube_pod_status_phase{phase="Failed"}

# Deployment 状态
kube_deployment_status_replicas_available
kube_deployment_status_replicas_unavailable

# Node 状态
kube_node_status_condition{condition="Ready",status="true"}
kube_node_status_condition{condition="MemoryPressure",status="true"}

# 资源请求和限制
kube_pod_container_resource_requests_cpu_cores
kube_pod_container_resource_limits_memory_bytes
```

## 五、Grafana 可视化

### 5.1 部署配置
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:8.3.3
        ports:
        - containerPort: 3000
          name: http-grafana
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-secret
              key: admin-password
        volumeMounts:
        - mountPath: /var/lib/grafana
          name: grafana-storage
        - mountPath: /etc/grafana/provisioning/datasources
          name: grafana-datasources
          readOnly: false
        - mountPath: /etc/grafana/provisioning/dashboards
          name: grafana-dashboards
          readOnly: false
        - mountPath: /etc/grafana/dashboards
          name: grafana-dashboard-definitions
          readOnly: false
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 200m
            memory: 512Mi
      volumes:
      - name: grafana-storage
        emptyDir: {}
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
      - name: grafana-dashboards
        configMap:
          name: grafana-dashboards
      - name: grafana-dashboard-definitions
        configMap:
          name: grafana-dashboard-definitions
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  prometheus.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus:9090
      access: proxy
      isDefault: true
      editable: true
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: monitoring
data:
  dashboards.yaml: |
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /etc/grafana/dashboards
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-definitions
  namespace: monitoring
data:
  kubernetes-cluster.json: |
    {
      "dashboard": {
        "title": "Kubernetes Cluster",
        "panels": [...]
      }
    }
  kubernetes-pods.json: |
    {
      "dashboard": {
        "title": "Kubernetes Pods",
        "panels": [...]
      }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: 30000
  selector:
    app: grafana
---
apiVersion: v1
kind: Secret
metadata:
  name: grafana-secret
  namespace: monitoring
type: Opaque
data:
  admin-password: YWRtaW4=  # admin
```

### 5.2 常用仪表盘
1. **Kubernetes Cluster Monitoring**：集群概览
2. **Kubernetes Pods Monitoring**：Pod 监控
3. **Kubernetes Nodes Monitoring**：节点监控
4. **Kubernetes Deployment Monitoring**：部署监控
5. **Prometheus 2.0 Overview**：Prometheus 自身监控

### 5.3 导入仪表盘
```bash
# 使用 grafana-cli
grafana-cli plugins install grafana-piechart-panel
grafana-cli plugins install grafana-worldmap-panel

# 导入 JSON 文件
# 通过 Grafana UI 导入或使用 ConfigMap
```

## 六、Alertmanager 告警

### 6.1 部署配置
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      smtp_smarthost: 'smtp.gmail.com:587'
      smtp_from: 'alertmanager@example.com'
      smtp_auth_username: 'username@gmail.com'
      smtp_auth_password: 'password'
    
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'team-X-mails'
      routes:
      - match:
          severity: critical
        receiver: 'team-X-pager'
    
    receivers:
    - name: 'team-X-mails'
      email_configs:
      - to: 'team-X+alerts@example.com'
    
    - name: 'team-X-pager'
      email_configs:
      - to: 'team-X+alerts-critical@example.com'
      pagerduty_configs:
      - service_key: <teams-service-key>
```

### 6.2 告警规则
```yaml
# rules/alerts.yml
groups:
- name: kubernetes-alerts
  rules:
  - alert: KubePodCrashLooping
    expr: rate(kube_pod_container_status_restarts_total[15m]) * 60 * 5 > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is restarting frequently"
      description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is restarting {{ $value }} times in the last 5 minutes."
  
  - alert: KubeNodeNotReady
    expr: kube_node_status_condition{condition="Ready",status="false"} == 1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Node {{ $labels.node }} is not ready"
      description: "Node {{ $labels.node }} has been in a non-ready state for more than 5 minutes."
  
  - alert: KubeCPUOvercommit
    expr: sum(namespace_cpu:kube_pod_container_resource_requests:sum) / sum(kube_node_status_allocatable_cpu_cores) > 1.5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Cluster has overcommitted CPU resources"
      description: "Cluster has {{ $value }} CPU cores requested vs {{ $value2 }} available."
  
  - alert: KubeMemoryOvercommit
    expr: sum(namespace_memory:kube_pod_container_resource_requests:sum) / sum(kube_node_status_allocatable_memory_bytes) > 1.5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Cluster has overcommitted memory resources"
      description: "Cluster has {{ $value }} memory requested vs {{ $value2 }} available."
  
  - alert: KubeDeploymentReplicasMismatch
    expr: kube_deployment_spec_replicas != kube_deployment_status_replicas_available
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} replicas mismatch"
      description: "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has {{ $value }} desired replicas but {{ $value2 }} available."
```

### 6.3 通知渠道
- **Email**：邮件通知
- **Slack**：Slack 频道
- **PagerDuty**：值班系统
- **Webhook**：自定义 Webhook
- **Pushover**：移动推送
- **VictorOps**：运维平台

## 七、监控指标详解

### 7.1 节点监控指标
```promql
# CPU 使用率
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 内存使用率
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# 磁盘使用率
(node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100

# 磁盘 I/O
rate(node_disk_read_bytes_total[5m])
rate(node_disk_written_bytes_total[5m])

# 网络流量
rate(node_network_receive_bytes_total[5m])
rate(node_network_transmit_bytes_total[5m])
```

### 7.2 Pod 监控指标
```promql
# Pod CPU 使用率
sum(rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m])) by (pod, namespace)

# Pod 内存使用率
sum(container_memory_working_set_bytes{container!="POD",container!=""}) by (pod, namespace)

# Pod 重启次数
sum(kube_pod_container_status_restarts_total) by (pod, namespace)

# Pod 就绪状态
sum(kube_pod_status_ready{condition="true"}) by (pod, namespace)
```

### 7.3 集群容量监控
```promql
# 集群 CPU 容量
sum(kube_node_status_allocatable_cpu_cores)

# 集群 CPU 使用
sum(rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m]))

# 集群内存容量
sum(kube_node_status_allocatable_memory_bytes)

# 集群内存使用
sum(container_memory_working_set_bytes{container!="POD",container!=""})

# 集群 Pod 容量
sum(kube_node_status_allocatable_pods)

# 集群 Pod 使用
count(kube_pod_info)
```

## 八、高级监控配置

### 8.1 长期存储
```yaml
# Thanos 配置
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: thanos-sidecar
  namespace: monitoring
spec:
  serviceName: thanos-sidecar
  replicas: 1
  selector:
    matchLabels:
      app: thanos-sidecar
  template:
    metadata:
      labels:
        app: thanos-sidecar
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.30.3
        args:
        - "--config.file=/etc/prometheus/prometheus.yml"
        - "--storage.tsdb.path=/prometheus"
        - "--web.console.templates=/etc/prometheus/consoles"
        - "--web.console.libraries=/etc/prometheus/console_libraries"
        - "--storage.tsdb.retention.time=2d"
        - "--web.enable-lifecycle"
        ports:
        - containerPort: 9090
          name: http
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus
        - name: prometheus-data
          mountPath: /prometheus
      - name: thanos-sidecar
        image: thanosio/thanos:v0.23.1
        args:
        - sidecar
        - --prometheus.url=http://localhost:9090
        - --tsdb.path=/prometheus
        - --objstore.config-file=/etc/thanos/object-store.yaml
        ports:
        - containerPort: 10902
          name: http
        - containerPort: 10901
          name: grpc
        volumeMounts:
        - name: prometheus-data
          mountPath: /prometheus
          readOnly: true
        - name: thanos-config
          mountPath: /etc/thanos
```

### 8.2 自定义指标
```yaml
# Prometheus Adapter 配置
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-adapter-config
  namespace: monitoring
data:
  config.yaml: |
    rules:
      custom:
      - seriesQuery: 'http_requests_total{namespace!="",pod!=""}'
        resources:
          overrides:
            namespace: {resource: "namespace"}
            pod: {resource: "pod"}
        name:
          matches: "^(.*)_total$"
          as: "${1}_per_second"
        metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[2m])) by (<<.GroupBy>>)'
    
    resourceRules:
      cpu:
        containerQuery: sum(rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m])) by (<<.GroupBy>>)
        nodeQuery: sum(rate(container_cpu_usage_seconds_total{id="/"}[5m])) by (<<.GroupBy>>)
        resources:
          overrides:
            node:
              resource: node
            namespace:
              resource: namespace
            pod:
              resource: pod
        containerLabel: container
      
      memory:
        containerQuery: sum(container_memory_working_set_bytes{container!="POD",container!=""}) by (<<.GroupBy>>)
        nodeQuery: sum(container_memory_working_set_bytes{id="/"}) by (<<.GroupBy>>)
        resources:
          overrides:
            node:
              resource: node
            namespace:
              resource: namespace
            pod:
              resource: pod
        containerLabel: container
```

### 8.3 服务监控
```yaml
# ServiceMonitor 配置
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: example-app
  namespace: monitoring
  labels:
    team: frontend
spec:
  selector:
    matchLabels:
      app: example-app
  namespaceSelector:
    any: true
  endpoints:
  - port: web
    interval: 30s
    path: /metrics
    scheme: http
    honorLabels: true
    relabelings:
    - sourceLabels: [__meta_kubernetes_pod_node_name]
      targetLabel: node
    metricRelabelings:
    - sourceLabels: [le]
      regex: ".+"
      action: labeldrop
```

## 九、监控最佳实践

### 9.1 监控策略
1. **分层监控**：基础设施 → 容器 → 应用 → 业务
2. **黄金信号**：延迟、流量、错误、饱和度
3. **SLO/SLI**：定义服务级别目标/指标
4. **告警分级**：紧急、警告、信息
5. **告警收敛**：避免告警风暴

### 9.2 性能优化
```yaml
# Prometheus 性能配置
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: "production"

# 限制抓取目标
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      # 限制抓取数量
      - action: drop
        source_labels: [__meta_kubernetes_pod_container_port_number]
        regex: "9100"

# 记录规则优化
rule_files:
  - /etc/prometheus/rules/recording.yml

# recording.yml
groups:
- name: recording_rules
  interval: 30s
  rules:
  - record: job:http_requests:rate5m
    expr: rate(http_requests_total[5m])
```

### 9.3 安全配置
```yaml
# RBAC 配置
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - configmaps
  verbs: ["get"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
```

## 十、故障排查

### 10.1 常见问题
```bash
# Prometheus 无法启动
kubectl logs -n monitoring prometheus-0

# 指标无法抓取
curl http://prometheus:9090/api/v1/targets

# Grafana 无法连接数据源
kubectl exec -n monitoring grafana-0 -- cat /etc/grafana/provisioning/datasources/prometheus.yaml

# 告警不触发
curl http://prometheus:9090/api/v1/rules

# 内存使用过高
kubectl top pods -n monitoring
```

### 10.2 调试命令
```bash
# 检查 Prometheus 状态
kubectl get pods -n monitoring
kubectl describe pod prometheus-0 -n monitoring

# 检查服务发现
curl -s "http://prometheus:9090/api/v1/targets" | jq '.data.activeTargets[] | select(.health=="up") | .labels'

# 检查指标
curl -s "http://prometheus:9090/api/v1/query?query=up" | jq

# 检查告警规则
curl -s "http://prometheus:9090/api/v1/rules" | jq

# 检查 Alertmanager
curl -s "http://alertmanager:9093/api/v2/alerts" | jq
```

### 10.3 性能调优
1. **减少抓取间隔**：适当增加 scrape_interval
2. **优化记录规则**：预计算常用查询
3. **限制标签数量**：避免过多的标签组合
4. **使用长期存储**：Thanos 或 Cortex
5. **水平扩展**：多个 Prometheus 实例分片

---

**关键要点**：完整的监控体系需要覆盖基础设施、容器、应用和业务各个层面。Prometheus + Grafana 是 Kubernetes 监控的事实标准，配合 Alertmanager 可以实现完整的监控告警体系。