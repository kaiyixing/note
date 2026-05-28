# 企业大脑 RAG 核心：Embedding 与 Reranker 模型部署笔记

## 1. 核心概念与职责分工

在企业大脑的 **RAG（检索增强生成）** 架构中，Embedding 和 Reranker 是两道核心关卡，负责从海量数据中精准找到“原材料”，为大模型（LLM）提供上下文。

| 维度         | Embedding (嵌入模型)                                         | Reranker (重排序模型)                                        |
| ------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| **别名**     | 向量化模型、双塔模型                                         | 精排模型、交叉编码器                                         |
| **核心职责** | **“粗筛” (Recall)** 将文本转为数学向量，快速计算相似度，召回一批候选文档。 | **“精筛” (Precision)** 对候选文档进行深度相关性打分，把最相关的排在前面。 |
| **类比**     | 图书馆的**分类员** （把书按类别上架，方便快速查找）。        | 图书馆的**资深研究员** （从一堆书中仔细甄别，找出最准的答案）。 |
| **计算特点** | 计算快，资源消耗低。                                         | 计算慢，资源消耗中等。                                       |
| **硬件要求** | **CPU 优先** （手册提及资源占用较小）。                      | **CPU 或 低端 GPU** （视并发量而定）。                       |

------

## 2. 工作流程（RAG Pipeline）

结合你手中的《企业大脑部署手册》，一次完整的问答流程如下：

```
graph LR
    A[用户提问] --> B(Embedding 模型)
    B -->|生成问题向量| C[向量数据库 Milvus]
    C -->|返回 Top-K 候选文档| D(Reranker 模型)
    D -->|重新打分排序| E[筛选后的 Top-N 文档]
    E --> F(LLM 大模型<br>Qwen/DeepSeek)
    F --> G[最终答案]
```

1. **向量化**：用户问“如何部署 Flannel？”，**Embedding 模型**将其转为向量 `[0.0123, 0.9876, ...]`。

2. **检索**：Milvus 数据库比对向量，找出语义相似的文档片段（如 20 个）。Top-N

3. **重排**：**Reranker 模型**计算“如何部署 Flannel？”与这 20 个片段的真实相关性，选出最相关的 3 个。Top-K

4. **生成**：**LLM** 阅读这 3 个片段，生成最终的操作步骤。

5. 总结
	- LLM (Qwen/DeepSeek)：“大脑”。负责理解和生成，算力消耗最大（70B 需要 4 卡）。
	
	- Embedding (BCE)：“图书管理员”。负责把文字变成坐标（向量），方便快速查找。算力消耗小（CPU 即可）。

	- Reranker (BCE)：“审核员”。负责把图书管理员找来的 10 本书，精挑细选出最相关的 3 本。算力消耗中等。

------

## 3. 部署实战（基于企业大脑手册）

### 3.1 镜像与资源

手册明确指出这两个模型是**必须部署**的基础组件，且资源占用相对较小。

- **Embedding**: `bce-embedding-base_v1.tar.gz`

- **Reranker**: `bce-reranker-base_v1.tar.gz`

### 3.2 启动与配置（Xinference 平台）

在 Xinference 中注册模型时，需注意接口路径的差异。

**Embedding 注册：**

```
curl --location --request POST 'http://ip:port/v1/embeddings' \
--header 'Content-Type: application/json' \
--data-raw '{
"model": "bce-embedding-base",
"input": "你好"
}'
```

**Reranker 注册：**

```
curl --location --request POST 'http://ip:port/v1/rerank' \
--header 'Content-Type: application/json' \
--data-raw '{
"model": "bce-reranker-base_v1",
"query": "如何部署 Flannel?",
"documents": ["Flannel 是 CNI 插件", "K8s 需要网络", "Docker 是容器"]
}'
```

### 3.3 Docker Compose 配置要点

在 `agent_local`的 `docker-compose.yaml`中，必须正确配置这两个模型的地址，供 Agent 组件调用：

```
environment:
  # 大模型地址
  - LOCAL_LLM_URL=http://ip:port/v1
  # Embedding 地址 (注意接口最后是 /embeddings)
  - LOCAL_EMB_URL=http://ip:port/v1/embeddings
  - LOCAL_EMB_UID=bce-embedding-base
  # Reranker 地址 (注意接口最后是 /rerank)
  - LOCAL_RERANK_URL=http://ip:port/v1/rerank
  - LOCAL_RERANK_UID=bce-reranker-base_v1
```

------

## 4. 硬件选型与性能优化（面试重点）

### 4.1 选型决策树

根据并发量和响应要求，决定部署位置：

| 场景                          | Embedding 部署建议 | Reranker 部署建议 | 理由                              |
| ----------------------------- | ------------------ | ----------------- | --------------------------------- |
| **常规私有化** （几十人使用） | **CPU**            | **CPU**           | 计算量小，节省 GPU 显存给 LLM。   |
| **高并发** （几百人同时问答） | **GPU (低端卡)**   | **CPU**           | 向量计算快，Reranker 瓶颈不明显。 |
| **极致低延迟**                | **GPU**            | **GPU**           | 全流程加速，成本最高。            |

### 4.2 避坑指南

- 

  **指令集检查**：如果在 CPU 上跑 Embedding 很慢，检查服务器是否支持 **AVX/AVX2** 指令集（`lscpu | grep avx`）。

- 

  **显存隔离**：不要把 Embedding 和 LLM 挤在同一张卡上，容易导致 OOM（显存溢出）。

- 

  **模型一致性**：确保 `agent_local`配置里的 `LOCAL_EMB_UID`和 Xinference 里注册的模型名称完全一致，否则会出现“找不到模型”的错误。

------

## 5. 故障排查手册

| 故障现象           | 可能原因             | 排查思路                                                     |
| ------------------ | -------------------- | ------------------------------------------------------------ |
| **搜索结果不相关** | Reranker 未生效      | 检查 `LOCAL_RERANK_URL`是否能连通；查看 Reranker 容器日志是否有报错。 |
| **检索为空**       | Embedding 模型未加载 | 检查 Xinference 平台，确认 `bce-embedding-base`状态为 Running。 |
| **CPU 飙高**       | Embedding 并发过大   | 限制 Embedding 的请求频率；或迁移到 GPU。                    |
| **Agent 报错 500** | 接口地址配置错误     | 检查 `docker-compose.yaml`中的 URL 是否多了斜杠 `/`，或端口不对。 |

------

## 6. 面试实战话术

**面试官**：我看你部署过 RAG 系统，Embedding 和 Reranker 在硬件选型上有什么讲究？

**你的回答**：

> “根据我在企业大脑私有化部署的经验，这两者的硬件选型主要看并发量：
>
> 1. 
>
>    **常规场景**：我会把 **Embedding 和 Reranker 部署在 CPU 节点**。因为它们的计算量相比 Qwen-72B 小很多，手册里也提到它们‘占用资源相对较小’。用 CPU 可以节省宝贵的 GPU 显存给核心大模型。
>
> 2. 
>
>    **高并发场景**：如果客户有几百人同时在线问答，我会给 Embedding 分配一张 **低端 GPU**（如 T4 或 4090）。Reranker 对算力要求稍高，但如果用 BCE 这种轻量级模型，CPU 通常也能扛住。
>
> 3. 
>
>    **避坑点**：部署时要特别注意 Xinference 的配置，确保 `device`参数设置正确，否则可能会因为显存不足导致服务崩溃。”

**面试官**：如果客户反馈搜索出来的文档不相关，你觉得是哪个模型的问题？

**你的回答**：

> “我会按这个顺序排查：
>
> 1. 
>
>    **先看 Reranker**：如果搜出来的前几条完全不对，大概率是 **Reranker 没生效** 或者模型没加载对。Embedding 负责召回，Reranker 负责纠偏。
>
> 2. 
>
>    **再看 Embedding**：如果召回的候选集里就没有正确答案，那是 **Embedding 模型** 的语义理解有问题，或者向量数据库里的数据没更新。
>
> 3. 
>
>    **最后看 LLM**：如果上下文是对的，但 LLM 胡编乱造，那才是大模型的问题。”

------

## 7. 总结

Embedding 和 Reranker 是企业大脑“感知”外界知识的眼睛和大脑。虽然它们不像 LLM 那样引人注目，但它们决定了 **“Garbage In, Garbage Out”** 的上限。**CPU 优先、GPU 辅助、隔离显存**是部署这两者的黄金法则。