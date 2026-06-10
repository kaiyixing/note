# Ubuntu 原生系统调用 AMD RX580 部署方案

这篇笔记补充说明：如果不用 Windows，而是在**原生 Ubuntu 系统**中使用 **AMD RX580**，如何部署“模型版本管理 + 自动化 A/B 测试”项目。

> 核心结论：RX580 可以用于本地 LLM 推理探索，但它不是当前大模型生态里最省心的 GPU。相比 NVIDIA RTX 4060，AMD RX580 在 ROCm、Ollama、K8s GPU 调度方面都会更折腾。因此推荐优先采用 **Ubuntu 宿主机运行模型推理服务，K8s 负责网关、MLflow、Streamlit** 的解耦方案，而不是一开始就把模型服务放进 K8s Pod。

---

## 1. RX580 的现实限制

RX580 是 Polaris 架构显卡，常见显存为 4GB 或 8GB。它的主要问题不是完全不能跑，而是：

- 官方 ROCm 对老架构显卡支持不如新卡稳定；
- 很多 LLM 推理框架优先优化 NVIDIA CUDA；
- Ollama 对 AMD GPU 的支持通常依赖 ROCm 环境，而 RX580 可能需要额外兼容配置；
- K8s 中调度 AMD GPU 需要 AMD device plugin，比单机直接调用更复杂；
- 如果是 4GB RX580，很多 7B / 8B 模型即使用 4bit 量化也会比较吃力；
- 如果是 8GB RX580，可以尝试较小量化模型，但速度和兼容性不能和 RTX 4060 相比。

因此，RX580 更适合做：

```text
本地低成本 MLOps / LLMOps 演示
小模型推理
量化模型推理
Prompt A/B 测试
模型服务与 K8s 控制面解耦实验
```

不适合一开始就做：

```text
生产级 GPU K8s 调度
多模型并发推理
大模型高吞吐服务
复杂 GPU Operator 集群
```

---

## 2. 推荐总体架构

在原生 Ubuntu + RX580 上，推荐架构如下：

```text
Ubuntu 宿主机
├── AMD GPU Driver / ROCm 或 llama.cpp Vulkan/HIP 后端
├── 模型推理服务
│   ├── Ollama AMD 方案，或
│   └── llama.cpp server 方案
└── http://localhost:11434 或 http://localhost:8080

K8s 集群
├── Flask Gateway
│   ├── v1 System Prompt
│   └── v2 System Prompt
├── MLflow Tracking Server
├── Streamlit Dashboard
└── Ingress / Service
```

数据流：

```text
用户请求 → K8s Ingress → Flask Gateway → Ubuntu 宿主机模型服务
                              │
                              ├─ 90% → v1 prompt
                              └─ 10% → v2 prompt
                              │
                              └─ MLflow 记录指标 → Streamlit 展示
```

这样做的好处：

- 模型服务可以直接访问 AMD GPU；
- K8s 不需要立刻处理 AMD GPU device plugin；
- Flask、MLflow、Streamlit 仍然完整部署在 K8s 中；
- 项目重点仍然是 MLOps 闭环，而不是 GPU 驱动调试。

---

## 3. 方案 A：Ubuntu 宿主机运行 Ollama，K8s 调用 Ollama

### 3.1 安装基础依赖

```bash
sudo apt update
sudo apt install -y curl git build-essential
```

### 3.2 安装 AMD 驱动 / ROCm

RX580 对 ROCm 的支持比较敏感，建议先确认显卡信息：

```bash
lspci | grep -i 'vga\|display\|amd'
```

如果系统能正常识别 RX580，再考虑安装 AMDGPU / ROCm 相关组件。

> 注意：不同 Ubuntu 版本、内核版本、ROCm 版本对 RX580 的兼容性不同。RX580 属于老架构，可能需要额外环境变量或非官方兼容方式。不要把“ROCm 完美可用”当作默认前提。

安装后可以尝试检查：

```bash
rocminfo
clinfo
```

如果这些命令无法正常识别 GPU，说明 AMD GPU 计算栈还没配好。

### 3.3 安装 Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

拉取较小模型，例如：

```bash
ollama pull llama3.2:3b
# 或者尝试其他更小的 instruct 模型
```

不建议 RX580 一开始就强行跑 8B 模型。更务实的选择：

```text
优先：3B / 4B 量化模型
谨慎：7B / 8B 4bit 量化模型
不建议：13B 以上模型
```

测试：

```bash
ollama run llama3.2:3b
```

确认 HTTP API：

```bash
curl http://localhost:11434/api/tags
```

### 3.4 让 K8s Pod 访问宿主机 Ollama

如果 K8s 使用的是 Docker / containerd / minikube，需要让 Pod 能访问 Ubuntu 宿主机的 Ollama。

可以把 Ollama 绑定到所有网卡：

```bash
export OLLAMA_HOST=0.0.0.0:11434
ollama serve
```

然后查宿主机 IP：

```bash
ip addr
```

例如宿主机 IP 是：

```text
192.168.1.100
```

Flask 网关中配置：

```python
OLLAMA_BASE = "http://192.168.1.100:11434/api/generate"
```

K8s Deployment 中可以写成环境变量：

```yaml
env:
- name: OLLAMA_BASE
  value: "http://192.168.1.100:11434/api/generate"
```

更推荐的代码写法：

```python
import os

OLLAMA_BASE = os.getenv("OLLAMA_BASE", "http://localhost:11434/api/generate")
```

---

## 4. 方案 B：Ubuntu 宿主机运行 llama.cpp server

如果 Ollama + RX580 兼容性不好，可以改用 `llama.cpp`。

`llama.cpp` 的优势是：

- 对量化 GGUF 模型支持成熟；
- 可以使用 CPU、Vulkan、HIP 等多种后端；
- 对老显卡有时比 Ollama 更灵活；
- 即使 GPU 不成功，也可以退回 CPU 跑小模型，保证项目闭环可演示。

### 4.1 编译 llama.cpp

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
cmake -B build
cmake --build build --config Release -j$(nproc)
```

如果要尝试 Vulkan 后端：

```bash
sudo apt install -y vulkan-tools libvulkan-dev
vulkaninfo | less
```

然后按 llama.cpp 当前文档启用 Vulkan 编译选项。

### 4.2 下载 GGUF 量化模型

推荐选择小模型，例如：

```text
Qwen2.5-3B-Instruct GGUF
Llama-3.2-3B-Instruct GGUF
Phi-3-mini GGUF
```

优先选择：

```text
Q4_K_M
Q4_0
Q5_K_M
```

如果 RX580 是 4GB，优先 Q4；如果是 8GB，可以尝试更高量化精度。

### 4.3 启动 OpenAI-compatible Server

示例：

```bash
./build/bin/llama-server \
  -m /path/to/model.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  -c 4096
```

此时模型服务地址为：

```text
http://Ubuntu宿主机IP:8080
```

Flask 网关可以改为调用 llama.cpp server 的 OpenAI-compatible API。

示例请求：

```python
import requests

resp = requests.post(
    "http://192.168.1.100:8080/v1/chat/completions",
    json={
        "model": "local-gguf",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        "temperature": 0.7
    }
)
answer = resp.json()["choices"][0]["message"]["content"]
```

---

## 5. K8s 部署边界

RX580 环境下，第一阶段建议：

```text
K8s 内：
- Flask Gateway
- MLflow Tracking Server
- Streamlit Dashboard
- Ingress / Service

K8s 外：
- Ollama 或 llama.cpp server
- AMD RX580 推理
- 模型权重
```

Flask Gateway Deployment 示例：

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
          value: "http://192.168.1.100:11434/api/generate"
```

如果使用 llama.cpp server，则改为：

```yaml
        - name: LLM_API_BASE
          value: "http://192.168.1.100:8080/v1/chat/completions"
```

---

## 6. 是否要把 AMD GPU 放进 K8s？

可以，但不建议作为第一阶段。

完整 AMD GPU K8s 路线大致是：

```text
Ubuntu 原生系统
├── AMDGPU / ROCm
├── containerd / Docker
├── Kubernetes / minikube / k3s
├── AMD GPU device plugin
└── Ollama / llama.cpp Pod 申请 AMD GPU 资源
```

潜在问题：

- RX580 是否能被 ROCm 稳定识别；
- AMD device plugin 是否识别这张老卡；
- 容器内是否能访问 `/dev/kfd`、`/dev/dri`；
- Pod 权限、安全上下文、驱动挂载比较麻烦；
- LLM 框架是否真的调用到了 GPU，而不是悄悄退回 CPU；
- 排错成本远高于项目收益。

如果以后要尝试，可以先从最小容器测试开始，而不是直接上 Ollama：

```bash
# 先验证容器是否能看到 AMD GPU 设备
ls /dev/kfd
ls /dev/dri
```

再验证容器内的 ROCm / OpenCL / Vulkan 能否识别 GPU。

---

## 7. Flask 网关适配建议

为了同时兼容 Windows RTX 4060、Ubuntu RX580、Ollama、llama.cpp，网关代码最好不要写死地址。

推荐：

```python
import os

LLM_BACKEND = os.getenv("LLM_BACKEND", "ollama")
OLLAMA_BASE = os.getenv("OLLAMA_BASE", "http://localhost:11434/api/generate")
OPENAI_COMPAT_BASE = os.getenv("OPENAI_COMPAT_BASE", "http://localhost:8080/v1/chat/completions")
```

调用逻辑：

```python
if LLM_BACKEND == "ollama":
    resp = requests.post(OLLAMA_BASE, json={
        "model": os.getenv("OLLAMA_MODEL", "llama3.2:3b"),
        "system": system_prompt,
        "prompt": user_prompt,
        "stream": False
    })
    answer = resp.json().get("response", "")
else:
    resp = requests.post(OPENAI_COMPAT_BASE, json={
        "model": os.getenv("OPENAI_COMPAT_MODEL", "local-gguf"),
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ]
    })
    answer = resp.json()["choices"][0]["message"]["content"]
```

这样同一个 Flask Gateway 可以适配：

```text
Windows + RTX 4060 + Ollama
Ubuntu + RX580 + Ollama
Ubuntu + RX580 + llama.cpp server
CPU fallback + llama.cpp server
```

---

## 8. 推荐实施顺序

### 阶段 1：先跑通 MLOps 闭环

```text
Ubuntu 宿主机：Ollama 或 llama.cpp server
K8s：Flask Gateway + MLflow + Streamlit
```

目标：

- `/chat` 接口可用；
- v1 / v2 prompt 可切换；
- 随机流量切分可用；
- MLflow 能记录 version、latency、feedback；
- Streamlit 能展示指标。

### 阶段 2：优化 AMD GPU 推理

尝试：

- 更小模型；
- GGUF 量化模型；
- Vulkan / HIP / ROCm 后端；
- 调整上下文长度；
- 限制并发；
- 记录真实吞吐和延迟。

### 阶段 3：再考虑 K8s GPU Pod

如果前两阶段稳定，再尝试：

- AMD device plugin；
- Pod 访问 `/dev/kfd`、`/dev/dri`；
- 容器内模型服务；
- GPU 资源调度。

---

## 9. 简历 / 面试描述

可以这样写：

> 在 Ubuntu + AMD RX580 环境中实现低成本 LLMOps A/B 测试系统。考虑到 RX580 对 ROCm 与 K8s GPU 调度支持有限，采用推理服务与控制面解耦架构：模型服务运行在 Ubuntu 宿主机，直接调用 AMD GPU 或 llama.cpp 后端；K8s 负责部署 Flask 网关、MLflow Tracking Server 与 Streamlit 看板。系统支持基于 System Prompt 的逻辑版本管理、请求头路由、加权流量切分、延迟与反馈指标采集，并通过 MLflow 与 Streamlit 实现版本效果对比。

如果面试官追问为什么不把 RX580 直接放进 K8s，可以回答：

> AMD RX580 属于较老架构，ROCm 与 K8s device plugin 的兼容性不如 NVIDIA CUDA 生态稳定。为了优先验证 MLOps 闭环，我把模型推理服务和 K8s 控制服务解耦：推理层直接在宿主机使用 GPU，K8s 负责网关、实验记录和可视化。后续可以在该基础上扩展 AMD device plugin，实现 Pod 级 GPU 调度。

---

## 10. 最终建议

如果目标是“把项目跑通并能讲清楚”，推荐：

```text
首选：Windows RTX 4060 + Ollama 宿主机推理 + K8s 控制面
备选：Ubuntu RX580 + llama.cpp / Ollama 宿主机推理 + K8s 控制面
进阶：Ubuntu + AMD device plugin + K8s GPU Pod
```

RX580 方案可以作为“低成本异构 GPU 环境适配”的补充亮点，但不要把它作为第一主线。主线仍建议用 RTX 4060 跑出稳定效果。
