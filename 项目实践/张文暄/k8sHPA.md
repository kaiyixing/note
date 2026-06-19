# Kubernetes HPA 自动扩容全流程详解

## 一、今日操作流程概览

流程如下：
1. **环境准备**：部署 Metrics Server
2. **应用部署**：创建 Deployment 和 Service
3. **HPA 配置**：创建 HorizontalPodAutoscaler
4. **负载测试**：创建负载生成器触发扩容
5. **阈值调整**：修改 HPA 阈值观察扩容
6. **监控验证**：观察扩容全过程

## 二、详细步骤与代码实现

### 1. 环境准备：Metrics Server 部署
**底层原理**：
- Metrics Server 是 Kubernetes 集群的资源指标聚合器
- 从每个节点的 kubelet 收集资源使用数据
- 通过 Kubernetes Metrics API 暴露数据供 HPA 使用

**部署命令**：
```bash
# 下载 Metrics Server 配置文件
wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 修改配置（如果需要）
# 在 containers 下的 args 中添加：--kubelet-insecure-tls

# 部署 Metrics Server
kubectl apply -f components.yaml

# 验证部署
kubectl get pods -n kube-system -l k8s-app=metrics-server
```

### 2. 应用部署：创建测试应用
**YAML 文件**：`hpa-test-app.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hpa-test-app
  namespace: practice
  labels:
    app: hpa-test
spec:
  replicas: 2  # 初始副本数
  selector:
    matchLabels:
      app: hpa-test
  template:
    metadata:
      labels:
        app: hpa-test
    spec:
      containers:
      - name: hpa-test-container
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m  # 关键：必须设置资源请求，HPA 基于此计算百分比
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: hpa-test-service
  namespace: practice
spec:
  selector:
    app: hpa-test
  ports:
  - port: 80
    targetPort: 80
```

**部署命令**：

```bash
kubectl apply -f hpa-test-deployment.yaml
```

### 3. HPA 配置：创建自动扩缩容器
**YAML 文件**：`hpa-test-hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-test-hpa
  namespace: practice
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hpa-test-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # 初始阈值：CPU 使用率超过 50% 时扩容
```

**部署命令**：

```bash
kubectl apply -f hpa-test-hpa.yaml
```

### 4. 负载测试：创建负载生成器

**负载生成器 Deployment**：`hpa-test-load.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load-generator
  namespace: practice
spec:
  replicas: 3
  selector:
    matchLabels:
      app: load-generator
  template:
    metadata:
      labels:
        app: load-generator
    spec:
      containers:
      - name: load-generator
        image: busybox
        command: ["/bin/sh"]
        args: ["-c", "while true; do wget -q -O- http://hpa-test-service; sleep 0.5; done"]
```

**部署命令**：
```bash
kubectl apply -f load-generator.yaml
```

### 5. 阈值调整：动态修改 HPA 配置
**修改阈值命令**：

```bash
# 将 CPU 阈值从 50% 修改为 15%
kubectl patch hpa hpa-test-hpa -n practice --type='json' -p='[{"op": "replace", "path": "/spec/metrics/0/resource/target/averageUtilization", "value": 15}]'
```

**验证修改**：
```bash
kubectl describe hpa hpa-test-hpa -n practice | grep -A5 "Metrics:"
```

###应用 Deployment（hpa-test-app）、自动扩缩容器（hpa-test-hpa） 和负载生成器（load-generator）三者协同工作流程，
**压力注入 -> 自动感知 -> 决策扩容 -> 执行伸缩 -> 压力解除 -> 自动缩容**

它们之间的协同工作流程，可以清晰地分为以下几个阶段，其数据流和决策链如所示：
#### 阶段一：初始与施压

1. **负载生成器** 开始向 **应用 Deployment** 的服务（`hpa-test-service`）发送持续请求
		- 具体的请求内容
			`while true; do wget -q -O- http://hpa-test-service; sleep 0.5; done`
		- 具体的含义：
```bash
while true; do
    wget -q -O- http://hpa-test-service
    sleep 0.5
done

#while true; do ... done
#作用：创建一个无限循环。while循环的条件是 true（永远为真），因此循环体（do和 done之间的命令）会一直重复执行，直到其所在的容器进程被终止。
#这确保了负载生成器能持续不断地产生请求，模拟稳定的流量来源。

#wget -q -O- http://hpa-test-service
#wget：一个在命令行中使用的、从网络下载文件的工具。
#-q (quiet 模式)：让 wget不输出进度、错误信息等，保持静默运行，使日志更简洁。
#-O-：-O参数指定输出文件。-是一个特殊值，表示将下载的内容输出到标准输出。结合 -q模式，这意味着请求会被发送，但响应内容会被直接丢弃。负载生成器不关心返回什么，只关心是否发起了请求。

#http://hpa-test-service：这是请求的目标地址。在您的 Kubernetes 集群中，hpa-test-service是一个 Service 资源，它会将流量负载均衡到后端所有标签为 app: hpa-test的 Pod（即您要测试的 Nginx 应用）。

#sleep 0.5
#作用：让当前 Shell 进程暂停 0.5 秒。
#这控制了请求的频率。每执行一次 wget请求后，程序会等待 0.5 秒，然后开始下一次循环。因此，单个负载生成器 Pod 每秒大约会发送 2 个请求。

```
总结与目的

这行代码组合起来实现的效果是：以一个固定的、较低的频率（2 QPS/每Pod），永不停止地向目标服务 hpa-test-service发送 HTTP 请求，这段代码是“制造负载”的关键。

- 目的：通过持续、稳定的请求，消耗您 hpa-test-app（Nginx） Pod 的 CPU 资源，使其使用率上升。
- 结果：当 CPU 使用率超过 HPA 设定的阈值时，触发自动扩容。

设计考量：使用 sleep控制频率是为了产生稳定、可预测的压力，而非洪水攻击。这对于清晰展示 HPA 的响应过程非常有效。

2. **应用 Deployment** 管理的 Pod 因处理这些请求，**CPU 使用率开始上升**。

#### 阶段二：监控、决策与驱动
1. **HPA** 通过 Metrics Server 定期（默认15秒）查询 **应用 Deployment** 所有 Pod 的当前平均 CPU 使用率。
2. **HPA** 将获取的指标与自身配置的阈值（例如 15%）比较。若指标**持续超过**阈值，则触发决策。
3. **HPA** 根据公式计算期望的副本数（例如，从2个副本计算出需要3个）。
4. **HPA** 执行核心操作：**通过 API Server 修改 应用 Deployment 对象的 `.spec.replicas`字段**（例如，从2改为3）。这是三者协同中最关键的一步，HPA 不创建Pod，而是驱动应用 Deployment 改变其“期望状态”。

#### 阶段三：执行与调度
1. **应用 Deployment 的控制器** 检测到自身的 `.spec.replicas`被修改，立即开始工作，以确保实际状态符合期望。
2. Kubernetes 控制平面（包括 Deployment Controller, ReplicaSet Controller, Scheduler, Kubelet）接替后续工作，最终在节点上**创建并启动新的 Pod**。您通过 `kubectl get pods`观察到了新 Pod（`hpa-test-app-xxxx`）从 `Pending`到 `Running`的过程。

#### 阶段四：减压、反向决策与闭环
1. **您删除负载生成器**，对应用 Deployment 的请求压力消失。
2. **HPA** 再次通过 Metrics Server 检测到 **应用 Deployment** 的 CPU 使用率已**大幅低于阈值**。
3. 经过缩容冷却窗口（默认5分钟）后，**HPA** 反向决策，**再次修改 应用 Deployment 的 `.spec.replicas`字段**（例如，从3改回2）。
4. **应用 Deployment 的控制器** 再次响应变更，驱动控制平面。
5. 多余的 Pod 被安全终止，系统恢复初始状态，完成一个完整的弹性伸缩闭环。

#### 协同总结
- **负载生成器** 是外部触发器，负责**改变**系统的输入（负载）。
- **应用 Deployment** 是作用点和最终执行者，其副本数的增减是协同工作的**直接结果**。
- **HPA** 是监控与决策中枢，是连接负载变化与执行动作的**智能桥梁**。它通过感知应用 Deployment 的状态变化，并反过来驱动应用 Deployment 的配置变更，实现了自动化。



### 6. 监控验证：观察扩容过程

**监控命令**：
```bash
# 实时监控 HPA 状态
kubectl get hpa hpa-test-hpa -n practice -w

# 监控 Pod 状态
kubectl get pods -n practice -w

# 查看详细事件
kubectl describe hpa hpa-test-hpa -n practice
```

## 三、底层原理深度解析

### 1. HPA 架构与组件交互

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes 控制平面                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │   HPA       │    │  Deployment  │    │ ReplicaSet   │   │
│  │ Controller  │◄──►│  Controller  │◄──►│  Controller  │   │
│  └─────────────┘    └──────────────┘    └──────────────┘   │
│         │                          │               │        │
│         ▼                          │               ▼        │
│  ┌─────────────┐                   │        ┌──────────┐   │
│  │ Metrics API │                   │        │  Pod     │   │
│  └─────────────┘                   │        │ (新创建) │   │
│         │                          │        └──────────┘   │
│         ▼                          │               │        │
│  ┌─────────────┐                   │               ▼        │
│  │   Metrics   │                   │        ┌──────────┐   │
│  │   Server    │                   │        │ kubelet  │   │
│  └─────────────┘                   │        └──────────┘   │
│         │                          │               │        │
│         ▼                          │               ▼        │
│  ┌─────────────┐                   │        ┌──────────┐   │
│  │   cAdvisor  │                   │        │  cgroups │   │
│  │ (每个节点)  │                   │        │ (资源限制)│   │
│  └─────────────┘                   │        └──────────┘   │
│         │                          │                        │
│         ▼                          ▼                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                工作节点 (Node)                       │   │
│  │  ┌──────────┐    ┌──────────┐    ┌──────────┐      │   │
│  │  │ Pod 1    │    │ Pod 2    │    │ Pod 3    │      │   │
│  │  │ (nginx)  │    │ (nginx)  │    │ (nginx)  │      │   │
│  │  └──────────┘    └──────────┘    └──────────┘      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 2. 扩容触发机制

**指标收集流程**：

1. **cAdvisor**：每个节点上的 cAdvisor 收集容器资源使用情况
2. **Metrics Server**：从所有节点的 cAdvisor 聚合数据
3. **Metrics API**：通过 Kubernetes API 服务器暴露聚合数据
4. **HPA Controller**：定期（默认 15 秒）查询 Metrics API
**计算算法**：

```
期望副本数 = ceil[当前副本数 × (当前指标值 / 期望指标值)]

示例计算：
当前副本数 = 2
当前 CPU 使用率 = 18%
目标 CPU 使用率 = 15%

期望副本数 = ceil[2 × (18 / 15)] = ceil[2 × 1.2] = ceil[2.4] = 3
```

### 3. 控制器协调过程
**HPA 控制器工作流程**：

```java
// 伪代码表示 HPA 控制器逻辑
func (hpa *HorizontalPodAutoscaler) reconcile() {
    // 1. 获取当前指标
    currentMetrics := metricsClient.GetMetrics(hpa.Spec.ScaleTargetRef)
    
    // 2. 计算期望副本数
    desiredReplicas := calculateDesiredReplicas(
        currentMetrics,
        hpa.Spec.Metrics,
        currentReplicas,
        hpa.Spec.MinReplicas,
        hpa.Spec.MaxReplicas
    )
    
    // 3. 更新目标对象（Deployment）
    if desiredReplicas != currentReplicas {
        scaleClient.UpdateScale(
            hpa.Spec.ScaleTargetRef,
            desiredReplicas
        )
    }
}
```

**Deployment 控制器响应**：
```java
// Deployment 控制器检测到副本数变化
func (dc *DeploymentController) syncDeployment() {
    // 1. 创建新的 ReplicaSet
    newRS := createNewReplicaSet(deployment, desiredReplicas)
    
    // 2. 逐步更新 Pod
    // 采用滚动更新策略，确保服务不中断
}
```

### 4. 为什么修改后 rs 会增加？
**ReplicaSet 版本控制机制**：

```
初始状态：
Deployment (v1) → ReplicaSet v1 (replicas: 2) → Pod v1 (2个)

HPA 修改副本数：
Deployment (v1) → ReplicaSet v1 (replicas: 3) → Pod v1 (3个)

修改 HPA 阈值（无模板变更）：
Deployment (v1) → ReplicaSet v1 (replicas: 3) → Pod v1 (3个)
# 注意：这里不会创建新的 ReplicaSet，因为 Deployment 模板未变

如果修改了 Deployment 模板：
Deployment (v2) → ReplicaSet v2 (replicas: 3) → Pod v2 (3个)
# 这时会创建新的 ReplicaSet
```

**关键点**：

- HPA 只修改 Deployment 的 `.spec.replicas`字段
- 如果 Deployment 模板不变，不会创建新的 ReplicaSet
- 看到的 "rs 增加" 可能是之前操作的结果，或者是观察到了 ReplicaSet 的 generation 变化

### 5. 冷却时间与稳定性
**默认冷却时间**：
- **扩容冷却**：3 分钟（防止快速波动）
- **缩容冷却**：5 分钟（更保守，避免频繁缩容）
**冷却时间配置**：
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # 缩容稳定窗口：300秒
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleUp:
      stabilizationWindowSeconds: 0    # 扩容稳定窗口：0秒（立即响应）
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
```

## 四、完整流程图

```

```

## 五、关键配置参数详解

### 1. HPA 核心参数

```bash
spec:
  # 目标对象
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment  # 也可以是 StatefulSet、ReplicaSet 等
    name: hpa-test-app
  
  # 副本数范围
  minReplicas: 2      # 最小副本数
  maxReplicas: 10     # 最大副本数
  
  # 指标配置
  metrics:
  - type: Resource
    resource:
      name: cpu       # 支持 cpu、memory
      target:
        type: Utilization  # 或 AverageValue
        averageUtilization: 50
  
  # 行为配置（Kubernetes 1.18+）
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
    scaleUp:
      stabilizationWindowSeconds: 0
```

### 2. Pod 资源请求配置

```yaml
resources:
  requests:
    cpu: "100m"      # 0.1 个 CPU 核心
    memory: "128Mi"  # 128 MB 内存
  limits:
    cpu: "200m"      # 0.2 个 CPU 核心
    memory: "256Mi"  # 256 MB 内存
```

**重要**：HPA 基于 `requests`计算使用率百分比，而不是 `limits`。

## 六、最佳实践与注意事项

### 1. 配置建议

- **合理设置资源请求**：避免过小或过大
- **选择合适的指标**：CPU 适合计算密集型，内存适合内存密集型
- **设置合理的 min/max**：避免过度伸缩
- **配置冷却时间**：根据业务特点调整

### 2. 监控与告警
```bash
# 监控 HPA 事件
kubectl get events --field-selector involvedObject.kind=HorizontalPodAutoscaler

# 查看 HPA 状态
kubectl describe hpa <hpa-name>

# 监控资源使用
kubectl top pods
kubectl top nodes
```

### 3. 常见问题排查
```bash
# 1. 检查 Metrics Server
kubectl get apiservices | grep metrics
kubectl logs -n kube-system -l k8s-app=metrics-server

# 2. 检查 HPA 状态
kubectl describe hpa <hpa-name>

# 3. 检查 Pod 资源请求
kubectl get pod <pod-name> -o yaml | grep -A5 resources

# 4. 检查事件
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 七、总结
Kubernetes HPA 的自动扩缩容流程：
1. **原理层面**：理解了 HPA 如何通过 Metrics Server 收集指标，计算期望副本数，并通过控制器模式协调多个组件完成扩缩容。
2. **操作层面**：掌握了创建 Deployment、Service、HPA 的完整流程，学会了如何通过负载测试触发扩容，以及如何动态调整 HPA 配置。
3. **监控层面**：学会了使用 kubectl 命令实时监控 HPA 状态、Pod 创建过程和事件流。
4. **问题排查**：理解了为什么修改 HPA 阈值后 ReplicaSet 会增加，以及整个扩缩容过程中的冷却机制。

HPA 是 Kubernetes 自动化的核心组件之一，正确配置和使用 HPA 可以显著提高应用的弹性和资源利用率，是云原生应用的重要特性。

好的，我们从底层原理的视角，深入剖析 Kubernetes Horizontal Pod Autoscaler 自动扩容的完整工作流程。这个过程是 Kubernetes **声明式 API** 与 **控制器模式** 的经典体现。

### 核心架构与组件

首先，需要理解参与此流程的核心组件及其角色：

| 组件                      | 角色              | 在 HPA 流程中的职责                                          |
| ------------------------- | ----------------- | ------------------------------------------------------------ |
| **Metrics Server**        | 指标聚合器        | 从各节点 Kubelet 收集 Pod 的 CPU/内存使用量，并通过 Metrics API 暴露。 |
| **API Server**            | 中央总线/状态存储 | 存储 HPA、Deployment 等资源对象的“期望状态”；作为所有组件通信的中枢。 |
| **HPA Controller**        | 自动扩缩容控制器  | 核心决策者。定期从 API Server 获取 HPA 配置和指标，计算期望副本数，并更新目标对象的 `.spec.replicas`。 |
| **Deployment Controller** | 部署控制器        | 监视其管理的 Deployment 对象。当发现 `.spec.replicas`被修改，驱动创建新的 ReplicaSet 以达到目标副本数。 |
| **ReplicaSet Controller** | 副本集控制器      | 确保由其管理的 Pod 副本数与定义的一致。发现其 `.spec.replicas`变化后，创建或删除 Pod。 |
| **Scheduler**             | 调度器            | 为新创建的、未调度的 Pod 分配合适的 Node。                   |
| **Kubelet**               | 节点代理          | 接收调度结果，调用容器运行时（如 containerd）拉取镜像、启动容器，并上报容器资源使用指标。 |

整个扩容流程，就是这些组件围绕 **API Server 中存储的资源对象状态**，通过一系列 **Watch（监听）-> Diff（比较）-> Reconcile（调和）** 的循环，驱动集群从“当前状态”向“期望状态”演进的过程。

------

### 底层原理详细流程

我们以 **CPU 使用率超过阈值** 为例，分解其底层交互链条。

#### 阶段一：指标收集与暴露（数据基础）

这是扩容决策的“感知”阶段，发生在触发条件满足之前，持续进行。

1. **节点级数据采集**：每个 Node 上的 **Kubelet** 内置 **cAdvisor**，持续收集该节点上所有容器的资源使用情况（如 CPU 使用时间）。

2. **集群级数据聚合**：**Metrics Server** 定期（默认 15-30 秒）通过 Kubelet 的 Summary API 拉取所有 Pod 的资源使用数据。

3. **API 化暴露**：Metrics Server 将聚合后的数据存储于内存，并通过 **Kubernetes Metrics API**（`apis/metrics.k8s.io`）在 API Server 上提供查询接口。至此，Pod 的实时指标成为了可通过 API Server 查询的“资源”。

**关键点**：如果没有 Metrics Server 或它工作异常，HPA Controller 将查询不到指标，扩容流程在第一步就会中断。

#### 阶段二：阈值检测与决策（大脑计算）

这是扩容流程的“决策”阶段，由 HPA Controller 主导。

1. **监听与获取**：**HPA Controller**（作为 `kube-controller-manager`的一部分）持续 **Watch** API Server，监听所有 HPA 对象的变化。同时，它以一个固定的周期（默认 **15秒**）执行以下操作：

   a. 通过 API Server 的 **Metrics API**，查询该 HPA 所监控的 Pod 的当前指标（如所有目标 Pod 的 CPU 使用率）。

   b. 从 API Server 读取该 HPA 对象自身配置，获取目标值（如 `targetAverageUtilization: 50`）、`minReplicas`、`maxReplicas`等信息。

2. **计算期望副本数**：

   a. **计算当前使用率**：`当前使用率 = (所有目标Pod的当前指标值总和) / (所有目标Pod的指标请求值总和) * 100%`
   - 这里解释了为何 Pod 必须设置 `resources.requests`：它是公式中的分母，是百分比计算的基准。

     b. **应用公式**：`期望副本数 = ceil[当前副本数 * (当前使用率 / 目标使用率)]`

   - 在您之前的实践中，当前副本数=2，当前使用率=18%，目标使用率=15%，计算为 `ceil[2 * (18/15)] = ceil[2.4] = 3`。

     c. **应用边界**：将计算结果限制在 `minReplicas`和 `maxReplicas`之间。

3. **决策**：如果计算出的 `期望副本数`与 HPA 对象 **status** 中记录的当前副本数不同，则触发更新操作。

#### 阶段三：驱动与执行（肢体动作）

这是扩容流程的“执行”阶段，Kubernetes 的控制器模式层层驱动，最终创建出 Pod。

1. **更新目标对象**：HPA Controller **不会直接创建 Pod**。它遵循控制器模式，通过 API Server **更新** HPA 的 **scaleTargetRef** 所指向的对象（例如名为 `my-app`的 **Deployment**）的 `.spec.replicas`字段。

   - **操作**：`kubectl patch deployment my-app --subresource=scale -p '{"spec":{"replicas":3}}'`

   - **本质**：HPA 只是在修改它所关心的那个对象的“期望状态”。

2. **Deployment Controller 响应**：**Deployment Controller** 一直在 Watch 它所管理的 Deployment 对象。它发现 `my-app`的 `.spec.replicas`从 2 变为 3。

   a. 它检查当前管理 Pod 的 **ReplicaSet** 的 Pod 模板是否与 Deployment 的最新模板一致。

   b. 如果一致，则直接**更新这个 ReplicaSet 的 `.spec.replicas`为 3**。

   c. （*注：如果 Pod 模板有过变更，Deployment Controller 会创建一个全新的 ReplicaSet 并逐步扩缩，这就是您之前观察到“rs 增加”的原因，但在纯 HPA 扩容场景下，模板未变，通常复用原 RS*）。

3. **ReplicaSet Controller 响应**：**ReplicaSet Controller** 发现其管理的 ReplicaSet 的 `.spec.replicas`变为 3，但当前只有 2 个匹配的 Pod。

   a. 它通过 API Server **创建一个新的 Pod 对象**。此 Pod 的 `ownerReference`指向该 ReplicaSet，并带有必要的标签。

   b. 此时，新 Pod 的 `.spec.nodeName`为空，状态为 **Pending**。

4. **调度与绑定**：**Scheduler** 监听到存在一个 `.spec.nodeName`为空的 Pod。

   a. 执行调度算法（过滤、打分），为该 Pod 选择一个最优 Node。

   b. 通过 API Server，**将 Node 名绑定到该 Pod 的 `.spec.nodeName`字段**。

5. **节点执行**：目标 Node 上的 **Kubelet** 监听到有一个 Pod 被调度到本机（`.spec.nodeName`填上了自己的名字）。

   a. 调用容器运行时（如 containerd）拉取 Pod 所需的镜像。

   b. 创建容器网络命名空间（通常由 CNI 插件负责）。

   c. 启动容器。

   d. 执行 Pod 中定义的 postStart 钩子（如果有）。

   e. 将容器状态报告回 API Server，Pod 状态依次变为 **ContainerCreating**，最终变为 **Running**。

#### 阶段四：冷却与稳定（反馈与缓冲）

1. **冷却窗口**：一次扩/缩容事件发生后，HPA 会进入一个**冷却窗口**（扩容默认3分钟，缩容默认5分钟）。在此窗口期内，即使指标再次超标，HPA Controller 也会抑制新的扩缩容决策，这是为了防止在指标快速波动时系统频繁震荡。

2. **负载均衡**：新 Pod 变为 `Ready`后，Service 的 `kube-proxy`或 Ingress 控制器会将其加入负载均衡池，流量开始分流到新 Pod，整体指标（如 CPU 使用率）随之下降，HPA 进入稳定监控状态。

### 核心原理总结

1. **声明式与控制器模式**：您声明“CPU 使用率不超过 50%”的期望状态。HPA Controller 等组件不断检查现实与期望的差异，并驱动相关组件（DeploymentC, ReplicaSetC, Scheduler, Kubelet）进行一系列协同操作来消除差异。

2. **水平与控制反转**：HPA 通过修改上级控制器（Deployment）的期望值来间接达成目标，而非直接操作 Pod，这是一种优雅的“水平”控制。所有组件都只与 API Server 交互，彼此解耦。

3. **基于速率而非绝对值**：HPA 关注的是资源使用率（速率），而非绝对使用量，这使得应用能更好地适应不同规格的节点和资源请求。

4. **延迟不可避免**：从指标采集（~30秒）、决策周期（~15秒）到 Pod 调度启动（~数秒），整个流程存在固有的延迟，因此 HPA 适用于处理分钟级趋势性流量变化，而非秒级突发请求。

您之前的整个实践过程——从设置 `requests`、调整阈值、观察 `kubectl get hpa -w`的输出变化，到最终看到新 Pod 出现——正是这个复杂精密的底层原理机制在命令行界面上的直观反映。

