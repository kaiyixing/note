---
title: LLM+RAG日志分析系统完整复现
tags:
  - LLM
  - RAG
  - LangChain
  - Ollama
  - Streamlit
  - ChromaDB
  - Qwen
  - 项目复现
aliases:
  - LLM日志分析系统复现
  - RAG日志分析项目复现
---

前置审查：[[AI与LLM/项目实践/LLM日志分析系统方案审查]]

> 基于 Ollama + LangChain + Qwen2 + Streamlit 构建本地 RAG 日志分析系统，实现语义级日志检索与智能问答。

---

## 项目结构

```
llm-log-analyzer/
├── app.py                    # 主程序: Streamlit UI入口
├── log_loader.py             # 日志加载器: 读取日志文件，逐条拆分
├── vector_store.py           # 向量存储: ChromaDB知识库管理
├── qa_chain.py               # QA链: LangChain + Ollama的RAG调用链
├── sample.log                # 测试日志文件
└── requirements.txt          # Python依赖清单
```

---

## 一、环境准备

```bash
# 1. 安装 Ollama
curl -fsSL https://ollama.com/install.sh | sh

# 2. 验证
ollama --version

# 3. 拉取模型
ollama pull qwen2:7b
ollama pull quentinz/bge-large-zh-v1.5    # 中文向量模型，用于RAG

# 4. 创建项目
mkdir llm-log-analyzer && cd llm-log-analyzer
python3 -m venv venv
source venv/bin/activate

# 5. 安装依赖（注意：需额外装 langchain-chroma）
pip install streamlit langchain langchain-ollama langchain-community chromadb langchain-chroma
```

> 注意：原方案 `pip install` 中缺少 `langchain-chroma`，`app.py` 中的 `from langchain_chroma import Chroma` 会报错，必须补装。

---

## 二、模块实现

### 2.1 日志加载器 (`log_loader.py`)

```python
import os

def load_logs_to_chroma(log_path: str):
    """逐行处理日志文件，为每一行添加元数据"""
    if not os.path.exists(log_path):
        return []
    lines = []
    with open(log_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            if line.strip():
                lines.append({
                    "content": line.strip(),
                    "metadata": {
                        "source": log_path,
                        "line_number": line_num
                    }
                })
    return lines
```

### 2.2 向量知识库 (`vector_store.py`)

```python
from langchain_chroma import Chroma
from langchain_ollama import OllamaEmbeddings

def build_vectorstore(chunks, persist_dir="./chroma_db"):
    embeddings = OllamaEmbeddings(model="quentinz/bge-large-zh-v1.5")
    vectorstore = Chroma.from_documents(
        chunks,
        embeddings,
        persist_directory=persist_dir
    )
    return vectorstore.as_retriever(search_kwargs={"k": 4})
```

> 注意：原方案中 `qa_chain.py` 使用了 `chromadb.PersistentClient` 的低层 API 并调用了不存在的 `.as_retriever()` 方法，应统一使用 LangChain 的 `Chroma` 封装类。

### 2.3 RAG 推理链 (`qa_chain.py`)

```python
from langchain_ollama import ChatOllama
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough

def format_docs(docs):
    return "\n\n".join(doc.page_content for doc in docs)

def create_rag_chain(retriever):
    llm = ChatOllama(model="qwen2:7b", temperature=0.1)
    prompt = ChatPromptTemplate.from_messages([
        ("system", """你是一个 SRE（站点可靠性工程师），擅长分析系统日志。
        根据提供的日志片段回答问题。如果不知道答案，就说"日志中未找到相关信息"。
        上下文: {context}"""),
        ("human", "{question}")
    ])
    rag_chain = (
        {"context": retriever | format_docs, "question": RunnablePassthrough()}
        | prompt
        | llm
        | StrOutputParser()
    )
    return rag_chain
```

> 注意：`retriever` 返回 `List[Document]`，必须通过 `format_docs` 转为字符串后传入 prompt 的 `{context}`。

### 2.4 Streamlit 入口 (`app.py`)

```python
import streamlit as st
import os
from langchain_community.document_loaders import TextLoader
from langchain_text_splitters import CharacterTextSplitter
from langchain_ollama import OllamaEmbeddings, ChatOllama
from langchain_chroma import Chroma
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnablePassthrough
from langchain_core.output_parsers import StrOutputParser

def load_logs(log_path: str):
    if not os.path.exists(log_path):
        return None
    loader = TextLoader(log_path, encoding='utf-8')
    docs = loader.load()
    text_splitter = CharacterTextSplitter(chunk_size=500, chunk_overlap=50, separator="\n")
    return text_splitter.split_documents(docs)

@st.cache_resource
def init_vectorstore(chunks):
    embeddings = OllamaEmbeddings(model="quentinz/bge-large-zh-v1.5")
    vectorstore = Chroma.from_documents(chunks, embeddings)
    return vectorstore.as_retriever(search_kwargs={"k": 4})

def format_docs(docs):
    return "\n\n".join(doc.page_content for doc in docs)

def create_rag_chain(retriever):
    llm = ChatOllama(model="qwen2:7b", temperature=0.1)
    prompt = ChatPromptTemplate.from_messages([
        ("system", """你是一个 SRE（站点可靠性工程师），擅长分析系统日志。
        根据提供的日志片段回答问题。如果不知道答案，就说"日志中未找到相关信息"。
        上下文: {context}"""),
        ("human", "{question}")
    ])
    rag_chain = (
        {"context": retriever | format_docs, "question": RunnablePassthrough()}
        | prompt
        | llm
        | StrOutputParser()
    )
    return rag_chain

st.title("AI 智能日志分析系统")
st.caption("基于 Ollama + LangChain + Qwen 的本地日志分析助手")

uploaded_file = st.file_uploader("上传日志文件", type=["log", "txt"])
if uploaded_file:
    save_path = "uploaded.log"
    with open(save_path, "wb") as f:
        f.write(uploaded_file.getbuffer())
    st.success("日志文件已上传")

    with st.spinner("正在构建向量知识库..."):
        chunks = load_logs(save_path)
        if not chunks:
            st.error("文件为空或格式不支持")
            st.stop()
        retriever = init_vectorstore(chunks)
        rag_chain = create_rag_chain(retriever)

    if "messages" not in st.session_state:
        st.session_state.messages = []

    for msg in st.session_state.messages:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

    if prompt := st.chat_input("请输入你的问题，例如：日志中有哪些 ERROR？"):
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)
        with st.chat_message("assistant"):
            with st.spinner("AI 分析中..."):
                response = rag_chain.invoke(prompt)
                st.markdown(response)
        st.session_state.messages.append({"role": "assistant", "content": response})
```

---

## 三、运行与测试

```bash
# 1. 确认 Ollama 运行
ollama list || ollama serve &

# 2. 启动应用
streamlit run app.py

# 3. 测试问题
# - "最近一个小时有哪些 ERROR 级别的日志？"
# - "列出所有关于数据库连接超时的错误"
# - "分析日志，有哪些可疑的访问模式？"
```

---

## 四、RAG 工作流程

```
索引阶段：
  日志文件 → 分块(chunk_size=500, overlap=50) → 向量化(bge-large-zh) → 存入ChromaDB

检索阶段：
  用户提问 → 向量化 → ChromaDB语义检索(Top-K=4) → 返回最相关日志片段

生成阶段：
  检索结果 + 原始问题 → Prompt模板 → LLM(qwen2:7b) → 生成回答
```

---

## 五、面试要点

| 问题 | 答案 |
|------|------|
| **为什么不用 grep？** | grep 只能做关键字匹配，RAG 实现语义搜索，能匹配含义相关但不含精确关键词的日志 |
| **大日志超出模型长度限制？** | 日志分块(500字符)后存入向量库，只检索 Top-K 最相关块输入 LLM |
| **为什么选 Qwen2:7B + bge-large-zh？** | 中文理解与推理优秀，7B 对硬件要求适中；bge 是专门的中文向量模型 |
| **为什么选 ChromaDB？** | 轻量级本地数据库，无需额外服务，数据持久化到本地文件夹 |
| **RAG 整体流程？** | 索引(分块→向量化→入库) → 检索(语义搜索 Top-K) → 生成(上下文+问题→LLM) |

---

## 关联笔记

- [[AI与LLM/项目实践/LLM日志分析系统方案审查|方案审查]] — 本项目的代码问题与修复记录
- [[AI与LLM/项目实践/README|项目实践索引]] — 更多 AI 项目
- [[监控与可观测性/ELK-Loki日志/README|日志分析]] — 传统日志方案对比
- [[面试准备/项目总结/我的简历中项目知识点总结|简历项目总结]] — 简历项目补充
