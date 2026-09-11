# K8s PodSpec 详解

## 一、PodSpec 是什么？

**一句话**：PodSpec 就是 Pod 的"说明书"，告诉 K8s 这个 Pod 长什么样、需要什么资源、怎么运行。

### 类比理解

```
点外卖：

订单 = PodSpec
├── 菜品 = 容器（一个或多个）
├── 份数 = 副本数
├── 配送地址 = 节点选择
├── 备注 = 环境变量、挂载卷
└── 超时时间 = 重启策略

你（用户）写订单 → 餐厅（K8s）按订单做菜 → 外卖小哥（kubelet）配送
```

---

## 二、PodSpec 完整结构

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  labels:
    app: web
spec:
  # ========== 容器配置 ==========
  containers:
  - name: nginx
    image: nginx:1.20
    ports:
    - containerPort: 80
    env:
    - name: ENV
      value: "production"
    resources:
      requests:
        cpu: "250m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
    volumeMounts:
    - name: config
      mountPath: /etc/nginx/conf.d
    livenessProbe:
      httpGet:
        path: /healthz
        port: 80
      initialDelaySeconds: 10
    readinessProbe:
      httpGet:
        path: /ready
        port: 80

  # ========== 初始化容器 ==========
  initContainers:
  - name: init-db
    image: busybox
    command: ['sh', '-c', 'until nslookup mysql; do sleep 2; done']

  # ========== 存储配置 ==========
  volumes:
  - name: config
    configMap:
      name: nginx-config
  - name: data
    persistentVolumeClaim:
      claimName: my-pvc

  # ========== 调度配置 ==========
  nodeSelector:
    disk: ssd
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"

  # ========== 网络配置 ==========
  dnsPolicy: ClusterFirst
  hostNetwork: false

  # ========== 重启策略 ==========
  restartPolicy: Always

  # ========== 安全配置 ==========
  serviceAccountName: my-sa
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
```

---

## 三、PodSpec 核心字段详解

### 1. containers（必填）—— 容器配置

```yaml
containers:
- name: app              # 容器名（必填）
  image: nginx:1.20      # 镜像（必填）
  imagePullPolicy: Always # 镜像拉取策略
  command: ["nginx"]      # 覆盖镜像的 ENTRYPOINT
  args: ["-g", "daemon off;"]  # 覆盖镜像的 CMD
  workingDir: /app       # 工作目录
  ports:
  - containerPort: 80    # 容器监听端口
    protocol: TCP
```

**imagePullPolicy 三种值**：

| 值 | 行为 | 适用场景 |
|----|------|----------|
| Always | 每次都拉最新镜像 | 开发环境 |
| IfNotPresent | 本地没有才拉 | 生产环境（推荐） |
| Never | 只用本地镜像 | 测试环境 |

### 2. resources —— 资源配置

```yaml
resources:
  requests:        # 调度依据（保证值）
    cpu: "250m"    # 0.25 核
    memory: "128Mi"
  limits:          # 硬上限
    cpu: "500m"
    memory: "256Mi"
```

**requests vs limits**：
- `requests`：调度器保证给你这么多资源
- `limits`：最多只能用这么多，超了会被限制或杀掉

### 3. env —— 环境变量

```yaml
env:
# 直接写值
- name: ENV
  value: "production"

# 引用 ConfigMap
- name: DB_HOST
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: db-host

# 引用 Secret
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-secret
      key: password
```

### 4. volumeMounts + volumes —— 存储挂载

```yaml
# 容器内挂载点
volumeMounts:
- name: data
  mountPath: /data      # 挂载到容器内的路径
  readOnly: false

# 定义存储卷
volumes:
- name: data
  persistentVolumeClaim:
    claimName: my-pvc    # 引用 PVC
```

**存储卷类型**：

| 类型 | 说明 | 适用场景 |
|------|------|----------|
| emptyDir | 临时目录，Pod 删除就没了 | 缓存、临时文件 |
| hostPath | 挂载宿主机目录 | 日志收集 |
| configMap | 挂载配置文件 | 应用配置 |
| secret | 挂载敏感信息 | 密码、证书 |
| persistentVolumeClaim | 持久化存储 | 数据库、文件存储 |

### 5. probes —— 探针配置

```yaml
# 存活探针：失败会重启容器
livenessProbe:
  httpGet:
    path: /healthz
    port: 80
  initialDelaySeconds: 10  # 容器启动后等10秒再探测
  periodSeconds: 5         # 每5秒探测一次
  timeoutSeconds: 3        # 超时时间
  failureThreshold: 3      # 连续失败3次判定为失败

# 就绪探针：失败会从 Service 摘除
readinessProbe:
  httpGet:
    path: /ready
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 10

# 启动探针：解决启动慢的应用
startupProbe:
  httpGet:
    path: /healthz
    port: 80
  failureThreshold: 30    # 最多等 30*10=300 秒
  periodSeconds: 10
```

**探针执行方式**：

| 方式 | 说明 |
|------|------|
| httpGet | 发 HTTP 请求，2xx/3xx 算成功 |
| tcpSocket | TCP 连接，能连上算成功 |
| exec | 执行命令，exit 0 算成功 |

### 6. initContainers —— 初始化容器

```yaml
initContainers:
# 先等数据库启动
- name: wait-db
  image: busybox
  command: ['sh', '-c', 'until nslookup mysql; do sleep 2; done']

# 再等 Redis 启动
- name: wait-redis
  image: busybox
  command: ['sh', '-c', 'until nslookup redis; do sleep 2; done']
```

**特点**：
- 按顺序执行，前一个成功后才执行下一个
- 如果失败，Pod 不会启动
- 全部成功后，主容器才会启动

### 7. scheduling 相关配置

```yaml
# 节点选择器
nodeSelector:
  disk: ssd
  zone: us-east-1a

# 污点容忍
tolerations:
- key: "dedicated"
  operator: "Equal"
  value: "gpu"
  effect: "NoSchedule"

# 节点亲和性（更灵活的调度）
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: zone
          operator: In
          values:
          - us-east-1a
          - us-east-1b
```

---

## 四、PodSpec 与 Deployment 的关系

```yaml
# Deployment（控制器）
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 3           # 3 个副本
  selector:
    matchLabels:
      app: nginx
  template:             # ← 这里面就是 PodSpec！
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.20
```

```
Deployment → 管理 Pod 副本数、滚动更新
    ↓
PodTemplate（包含 PodSpec）→ 定义 Pod 长什么样
    ↓
Pod → 实际运行的容器
```

---

## 五、面试高频问题

**Q1: PodSpec 中必填字段有哪些？**
- `containers.name`（容器名）
- `containers.image`（镜像）
- 其他都是可选的

**Q2: livenessProbe 和 readinessProbe 的区别？**
- livenessProbe：失败 → 重启容器（证明"活着"）
- readinessProbe：失败 → 从 Service 摘除（证明"准备好接收流量"）

**Q3: initContainers 的作用？**
- 做前置依赖检查（如等数据库启动）
- 按顺序执行，全部成功后主容器才启动
- 常用于数据库迁移、配置初始化

**Q4: resources.requests 和 limits 的区别？**
- requests：调度依据，保证给你这么多
- limits：硬上限，超了会被限制（CPU）或杀掉（内存）

**Q5: imagePullPolicy 三种值的区别？**
- Always：每次都拉（开发环境）
- IfNotPresent：本地没有才拉（生产推荐）
- Never：只用本地（测试环境）

---

## 六、相关链接

- [[容器与编排/Kubernetes/基础知识/K8s资源隔离底层实现|K8s 资源隔离底层实现]]
- [[容器与编排/Kubernetes/基础知识/Kubernetes知识梳理|Kubernetes 知识梳理]]
- [[容器与编排/Kubernetes/基础知识/Kubernetes组件详细解析|Kubernetes 组件详细解析]]
