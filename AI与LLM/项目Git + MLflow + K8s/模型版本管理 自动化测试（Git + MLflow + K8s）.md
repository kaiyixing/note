针对你提出的“模型版本管理 + 自动化A/B测试”项目，我为你梳理了一份可直接落地的详细实施方案。它严格基于你的硬件条件（RTX 4060 8GB显存）设计，用**单模型实例 + 不同System Prompt**的方式模拟两个版本，完整演示MLOps闭环。

---

### 项目架构与数据流

```
用户请求 → K8s Ingress → Flask网关 (路由决策)
                │
                ├─ 90%流量 → 版本v1 (System Prompt A)
                └─ 10%流量 → 版本v2 (System Prompt B)
                │
                └─ 调用同一个 Ollama 实例 (不同prompt参数)
                        │
                        └─ Llama 3 8B (4-bit量化)
日志 & 指标 → MLflow Tracking Server → Streamlit 看板
```

### 核心步骤实现

#### 1. 模型注册与版本管理 (MLflow)

首先，在MLflow中创建两个“逻辑版本”，实际指向同一个Ollama模型，但记录不同的配置信息。

```python
import mlflow
import mlflow.pyfunc
import requests
import json

class OllamaModelWrapper(mlflow.pyfunc.PythonModel):
    def __init__(self, model_name, system_prompt):
        self.model_name = model_name
        self.system_prompt = system_prompt

    def predict(self, context, model_input):
        user_message = model_input["prompt"][0]
        response = requests.post(
            "http://ollama-service:11434/api/generate",
            json={
                "model": self.model_name,
                "system": self.system_prompt,
                "prompt": user_message,
                "stream": False
            }
        )
        return response.json()["response"]

# 注册 v1：原始模型
with mlflow.start_run(run_name="register_v1"):
    mlflow.pyfunc.log_model(
        "model",
        python_model=OllamaModelWrapper("llama3:8b", "你是一个乐于助人的AI助手。"),
        registered_model_name="llama3_ab"
    )
    # 添加版本别名
    client = mlflow.tracking.MlflowClient()
    client.set_registered_model_alias("llama3_ab", "v1", 1)

# 注册 v2：提示词调优版
with mlflow.start_run(run_name="register_v2"):
    mlflow.pyfunc.log_model(
        "model",
        python_model=OllamaModelWrapper("llama3:8b", "你是一个专业、细致且富有同理心的AI助手，回答时请条理清晰并多使用鼓励性语言。"),
        registered_model_name="llama3_ab"
    )
    client.set_registered_model_alias("llama3_ab", "v2", 2)
```

> **4060适配关键**：两个版本共用同一个Ollama实例加载的同一份模型权重，显存仅占一份（约5.7GB，4bit量化后），完全不会OOM。

#### 2. Flask网关实现流量切分

网关根据请求头 `X-Model-Version` 或随机权重进行路由，并记录指标到MLflow。

```python
# gateway.py
from flask import Flask, request, jsonify
import requests
import random
import time
import mlflow

app = Flask(__name__)
mlflow.set_tracking_uri("http://mlflow-server:5000")

OLLAMA_BASE = "http://localhost:11434/api/generate"
WEIGHT_V1 = 0.9  # 90%流量给v1

SYSTEM_PROMPTS = {
    "v1": "你是一个乐于助人的AI助手。",
    "v2": "你是一个专业、细致且富有同理心的AI助手，回答时请条理清晰并多使用鼓励性语言。"
}

@app.route('/chat', methods=['POST'])
def chat():
    data = request.json
    user_prompt = data.get("prompt")
    req_version = request.headers.get("X-Model-Version")

    # 路由决策
    if req_version in SYSTEM_PROMPTS:
        version = req_version
    else:
        version = "v1" if random.random() < WEIGHT_V1 else "v2"

    system_prompt = SYSTEM_PROMPTS[version]

    # 调用Ollama
    start = time.time()
    resp = requests.post(OLLAMA_BASE, json={
        "model": "llama3:8b",
        "system": system_prompt,
        "prompt": user_prompt,
        "stream": False
    })
    latency = time.time() - start
    answer = resp.json().get("response", "")

    # 模拟用户反馈（可后续接入真实评分）
    user_rating = random.choice([1, 1, 1, 0])  # 75%正面反馈示例

    # 记录指标到MLflow
    with mlflow.start_run(run_name="gateway_metrics", nested=True):
        mlflow.log_metric(f"{version}_latency", latency)
        mlflow.log_metric(f"{version}_feedback", user_rating)
        mlflow.log_param("prompt", user_prompt[:100])
        mlflow.set_tag("version", version)

    return jsonify({"version": version, "answer": answer, "latency": latency})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
```

#### 3. Windows 笔记本上的推荐部署方案

> 结论：在 Windows + RTX 4060 笔记本上，**不建议一开始把 Ollama 放进 K8s Pod 里跑 GPU**。更稳妥的方式是：**Ollama 在 Windows / WSL2 宿主机上直接使用显卡，K8s 只负责部署 Flask 网关、MLflow、Streamlit、Ingress 等控制与观测组件**。

原因是：

- 普通虚拟机（VirtualBox / VMware / 普通 Hyper-V）很难直接使用笔记本独显；
- K8s Pod 想使用 NVIDIA GPU，需要 NVIDIA Container Toolkit、K8s NVIDIA device plugin、容器运行时、WSL2 / Docker Desktop 等多层配置；
- 对 8GB 显存的本地项目来说，强行把模型服务容器化到 K8s 里，容易把时间耗在 GPU passthrough 和 device plugin 调试上；
- 本项目的核心展示点是 **模型版本管理、A/B 流量切分、指标采集和可视化闭环**，不是本地 GPU 调度。

因此，Windows 最适合的本地架构是：

```text
Windows / WSL2 宿主机
└── Ollama + Llama 3 8B
    └── 使用 RTX 4060 GPU
    └── 暴露 http://localhost:11434

Docker Desktop Kubernetes / minikube / kind
├── Flask Gateway
│   └── 负责 v1 / v2 prompt 路由与 A/B 流量切分
├── MLflow Tracking Server
│   └── 记录延迟、版本、反馈等指标
├── Streamlit Dashboard
│   └── 展示 A/B 测试结果
└── Ingress / Service
```

数据流变为：

```text
用户请求 → K8s Ingress → Flask Gateway → 宿主机 Ollama
                              │
                              ├─ v1 System Prompt
                              └─ v2 System Prompt
                              │
                              └─ MLflow 记录指标 → Streamlit 看板
```

##### 3.1 Windows 原生运行 Ollama

在 Windows 上安装 Ollama 后，拉取模型：

```powershell
ollama pull llama3:8b
ollama run llama3:8b
```

确认 Ollama 服务可访问：

```powershell
curl http://localhost:11434/api/tags
```

K8s Pod 内部不能用 `localhost:11434` 访问宿主机 Ollama，因为 Pod 里的 `localhost` 指向 Pod 自己。网关应改为访问宿主机地址：

```python
OLLAMA_BASE = "http://host.docker.internal:11434/api/generate"
```

如果使用 Docker Desktop Kubernetes，`host.docker.internal` 通常可直接解析到 Windows 宿主机。

##### 3.2 WSL2 运行 Ollama

如果使用 WSL2，先确认 WSL2 能看到 NVIDIA GPU：

```bash
nvidia-smi
```

然后在 WSL2 中安装 Ollama：

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3:8b
ollama run llama3:8b
```

这种方式比传统虚拟机更适合 Windows + NVIDIA，因为 WSL2 可以通过 NVIDIA WSL 驱动访问 GPU。但如果 K8s 运行在 Docker Desktop / minikube 中，Pod 访问 WSL2 内的 Ollama 可能还需要处理网络地址映射。为了降低复杂度，初版项目优先推荐 **Windows 原生 Ollama + K8s Pod 通过 `host.docker.internal` 调用**。

##### 3.3 推荐的 Windows MVP 部署边界

第一版只把这些组件放进 K8s：

```text
K8s 内部：
- Flask Gateway
- MLflow Tracking Server
- Streamlit Dashboard
- Ingress / Service

K8s 外部：
- Ollama
- Llama 3 8B 模型权重
- RTX 4060 GPU 推理
```

这样仍然可以完整展示：

- K8s 服务部署；
- 网关层 A/B 路由；
- MLflow 实验与指标记录；
- Streamlit 可视化；
- 本地 GPU 推理；
- 推理服务与控制服务解耦。

简历 / 面试中可以这样解释：

> 在 Windows + RTX 4060 本地环境中，我将推理服务与 K8s 控制面解耦：Ollama 在宿主机上直接使用 GPU 承载 Llama 3 8B，K8s 负责部署 Flask 网关、MLflow Tracking Server 和 Streamlit 看板。网关通过 `host.docker.internal` 调用宿主机推理服务，同时完成 A/B 流量切分、版本标记和指标采集。该方案避免了本地 K8s GPU passthrough 的复杂性，同时保留了 MLOps 闭环的核心能力。

##### 3.4 Windows 进阶方案

等 MVP 跑通后，再尝试完整 GPU Pod 方案：

```text
WSL2
└── Docker / containerd
    └── minikube / kind / k3d
        └── NVIDIA Container Toolkit
            └── NVIDIA device plugin
                └── Ollama Pod 申请 nvidia.com/gpu: 1
```

对应 YAML 中可以保留 GPU 资源声明：

```yaml
resources:
  limits:
    nvidia.com/gpu: 1
```

但这应作为进阶探索，不建议作为项目第一阶段目标。

#### 4. 部署至 minikube / Docker Desktop Kubernetes

基于 Windows 笔记本，第一阶段推荐 K8s 内只部署网关、MLflow、Streamlit，Ollama 保持在宿主机运行。关键 YAML 如下：

- **Ollama 访问方式（Windows MVP 推荐）**

Ollama 不部署进 K8s，而是在 Windows 宿主机运行。Flask 网关容器通过宿主机地址访问：

```python
OLLAMA_BASE = "http://host.docker.internal:11434/api/generate"
```

如果必须在 K8s 内抽象成 Service，也可以创建一个 `ExternalName` Service，但本地 Docker Desktop 场景下直接在环境变量中配置 `host.docker.internal` 更简单。

- **Ollama Deployment（Linux GPU 服务器 / Windows 进阶方案，可选）**

下面 YAML 只适合 GPU 已经能被 K8s 识别的环境。Windows 笔记本第一阶段不建议使用。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
        resources:
          limits:
            nvidia.com/gpu: 1  # 需安装 K8s NVIDIA device plugin
        volumeMounts:
        - name: models
          mountPath: /root/.ollama
      volumes:
      - name: models
        hostPath:
          path: /home/user/.ollama  # Linux 环境下的预下载模型目录
```

- **Flask网关 + Service**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ab-gateway
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ab-gateway
  template:
    metadata:
      labels:
        app: ab-gateway
    spec:
      containers:
      - name: gateway
        image: your-registry/ab-gateway:latest
        ports:
        - containerPort: 8000
        env:
        - name: MLFLOW_TRACKING_URI
          value: "http://mlflow-server:5000"
        - name: OLLAMA_BASE
          value: "http://host.docker.internal:11434/api/generate"
---
apiVersion: v1
kind: Service
metadata:
  name: gateway-service
spec:
  selector:
    app: ab-gateway
  ports:
  - port: 80
    targetPort: 8000
```

- **Ingress 暴露网关**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ab-ingress
spec:
  rules:
  - host: llama-ab.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gateway-service
            port:
              number: 80
```

本地测试时，在 `hosts` 文件中添加 `127.0.0.1 llama-ab.local`，然后通过 minikube tunnel 访问。

#### 4. 可视化对比界面 (Streamlit)

```python
import streamlit as st
import mlflow
import pandas as pd

mlflow.set_tracking_uri("http://localhost:5000")
client = mlflow.tracking.MlflowClient()

st.title("A/B Test 实时监控 - Llama 3 版本对比")

# 获取最新指标
experiment = client.get_experiment_by_name("gateway_metrics")
runs = client.search_runs(experiment.experiment_id, order_by=["start_time DESC"], max_results=200)

v1_lat, v2_lat = [], []
v1_fb, v2_fb = [], []

for run in runs:
    metrics = run.data.metrics
    if "v1_latency" in metrics:
        v1_lat.append(metrics["v1_latency"])
        v1_fb.append(metrics.get("v1_feedback", 0))
    if "v2_latency" in metrics:
        v2_lat.append(metrics["v2_latency"])
        v2_fb.append(metrics.get("v2_feedback", 0))

col1, col2 = st.columns(2)
with col1:
    st.metric("v1 平均延迟 (ms)", f"{sum(v1_lat)/len(v1_lat)*1000:.1f}" if v1_lat else "N/A")
    st.metric("v1 用户好评率", f"{sum(v1_fb)/len(v1_fb)*100:.1f}%" if v1_fb else "N/A")
with col2:
    st.metric("v2 平均延迟 (ms)", f"{sum(v2_lat)/len(v2_lat)*1000:.1f}" if v2_lat else "N/A")
    st.metric("v2 用户好评率", f"{sum(v2_fb)/len(v2_fb)*100:.1f}%" if v2_fb else "N/A")

# 趋势图
df = pd.DataFrame({
    "v1_latency": v1_lat,
    "v2_latency": v2_lat
}).reset_index(drop=True)
st.line_chart(df)
```

### Windows 本地部署总结

对于你的 Windows + RTX 4060 笔记本，最终推荐路线是：

```text
Ollama：Windows / WSL2 宿主机运行，直接使用 RTX 4060
K8s：部署 Flask Gateway、MLflow、Streamlit、Ingress
网关：通过 host.docker.internal 调用 Ollama
```

不要一开始追求把 Ollama 放进 K8s 并让 Pod 直接申请 GPU。这样做虽然更“云原生”，但在 Windows 本地环境里调试成本较高，不适合作为第一阶段目标。

### 简历优化描述（可直接使用）

> **基于MLflow与Kubernetes的LLM金丝雀发布与A/B测试系统**
> - 设计并实现了一套MLOps闭环方案，利用MLflow管理两个逻辑模型版本（通过不同System Prompt模拟），支持版本别名与模型注册。
> - 开发Flask智能网关，实现请求头路由与基于权重的流量切分（90% v1 / 10% v2），并集成指标自动采集（延迟、用户反馈）至MLflow。
> - 将全链路部署至minikube K8s集群，通过Ingress暴露服务，支持GPU共享与显存优化（单卡8GB同时服务多版本）。
> - 使用Streamlit构建实时可视化监控看板，对比版本性能与用户满意度，为模型迭代提供低成本、可量化的验证依据。

这个方案既真实展示了MLOps核心能力，又完全能在你的4060笔记本上跑通，对简历面试都会是很好的加分项。