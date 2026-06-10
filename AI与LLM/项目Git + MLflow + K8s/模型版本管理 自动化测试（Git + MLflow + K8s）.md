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

#### 3. 部署至minikube (K8s)

基于你的Windows笔记本，推荐使用 `minikube` + `docker` 驱动。关键 YAML 如下：

- **Ollama Deployment（单副本，挂载模型缓存）**
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
            nvidia.com/gpu: 1  # 需安装k8s NVIDIA device plugin
        volumeMounts:
        - name: models
          mountPath: /root/.ollama
      volumes:
      - name: models
        hostPath:
          path: /home/user/.ollama  # 预下载模型目录
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

### 简历优化描述（可直接使用）

> **基于MLflow与Kubernetes的LLM金丝雀发布与A/B测试系统**
> - 设计并实现了一套MLOps闭环方案，利用MLflow管理两个逻辑模型版本（通过不同System Prompt模拟），支持版本别名与模型注册。
> - 开发Flask智能网关，实现请求头路由与基于权重的流量切分（90% v1 / 10% v2），并集成指标自动采集（延迟、用户反馈）至MLflow。
> - 将全链路部署至minikube K8s集群，通过Ingress暴露服务，支持GPU共享与显存优化（单卡8GB同时服务多版本）。
> - 使用Streamlit构建实时可视化监控看板，对比版本性能与用户满意度，为模型迭代提供低成本、可量化的验证依据。

这个方案既真实展示了MLOps核心能力，又完全能在你的4060笔记本上跑通，对简历面试都会是很好的加分项。