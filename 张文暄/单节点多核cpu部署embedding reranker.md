很多刚入行的同学会有一个误区：觉得只有 K8s 集群、分布式训练才叫“技术”。但实际上，**“单节点多核 CPU 部署 Embedding 和 Reranker” 是整个 RAG（检索增强生成）架构的心脏**。在绝大多数 ToB 私有化交付场景中，这就是算法工程的**最终交付形态**。

接下来，我们将结合手册，把你从一名“命令执行者”拉升为“架构掌控者”。

------

### 一、 宏观架构：请求是如何在这个单节点上流淌的？

在动手之前，你必须先在脑海中建立这张**数据流转图**。这决定了你未来怎么排错。

```
graph TD
    A[企业大脑主服务] -->|1. HTTP POST 请求| B(Xinference 容器:18345)
    B -->|2. 加载模型权重| C[(宿主机模型目录 ./bge_model)]
    B -->|3. 调用 Embedding| D[CPU 核心 0,1,2...]
    D -->|4. 返回向量| B
    B -->|5. 返回 JSON 结果| A
```

**硬核洞察**：

看似只是一个 `docker-compose up -d`，背后其实是**宿主机内核调度多核 CPU 进行高密度矩阵运算**，并通过 Unix Socket 将容器内外的文件系统进行映射（Volume）的过程。

------

### 二、 阶段一：单节点资源盘点（不打无准备之仗）

翻开手册，第一步永远是查看机器资源。这不是走流程，而是**防止 OOM（内存溢出）和 指令集不兼容**的生死线。

手册命令回顾：

```
cpu: lscpu
内存: free -h
磁盘: df -h
检查服务器是否支持指令集: lscpu | grep avx
```

**深度刨析：**

1. **为什么查 `avx`指令集？**

   Embedding 模型（如 BCE）在进行向量运算时，极度依赖 CPU 的矢量扩展指令集。`avx2`或 `avx512`的存在与否，直接决定了你推理速度的快慢。如果没有，框架会降级到更基础的指令集，性能可能大打折扣。

   Embedding、Reranker 属于大批量向量浮点计算，AVX2 是 x86 CPU 的SIMD 向量并行指令集（单指令多数据），能单指令同时处理多组数据，配合  乘加融合指令大幅提速；而 Xinference 底层依赖 PyTorch 等框架，其 CPU 推理算子编译时强制依赖 AVX2，不支持会直接报错或性能暴跌，因此是 x86 环境部署的必备指令集。

2. **`free -h`看什么？**

   Embedding 模型虽然不像 LLM 那样吃显存，但加载 BCE （BCE 是有道双语向量模型，含 Embedding 与 Reranker，用于 RAG 知识库检索和精排，轻量化适配私有化部署）这类模型时，会将权重全部读入内存。如果你的 `/bge_model`目录下放了多个维度的模型，很容易吃掉几 GB 到十几 GB 的内存。如果 swap 分区没开，内存一旦耗尽，Docker 容器就会瞬间被 Linux OOM Killer 杀掉。

3. **`df -h`的潜台词：**

   手册强调“建议目录 1T 以上”。因为除了 Embedding，同目录可能还存放着 LLM 的权重（几十 GB）。如果 inode 用完或者磁盘满了，Docker 写入日志时会直接报 `No space left on device`，导致服务假死。

------

### 三、 阶段二：模型包的预处理（离线交付的艺术）

在公有云，我们习惯 `git clone`或 `huggingface-cli download`。但在私有化交付中，客户机器往往是**物理隔离、无法连接外网**的。因此，手册采用了“离线包”的形式。

手册步骤回顾：

```
tar -zxvf bce-embedding-base_v1.tar.gz
tar -zxvf bce-reranker-base_v1.tar.gz
```

**深度刨析：**

1. **目录结构的约定优于配置**：

   手册要求按照特定目录存放。这是因为 Xinference 在启动时会去固定的环境变量路径下（`/root/.cache/custom/models`）扫描模型文件。如果你解压放错了地方，容器启动时就会报 `ModelNotFound`错误。

2. **文件属主问题（经典排坑点）**：

   在 Linux 中，如果你是用 `root`解压的 tar 包，那么这些文件的属主就是 `root`。当 Docker 容器（内部可能用非 root 用户运行）去挂载并读取这些文件时，极易出现 **Permission Denied**。

   *（高阶操作：解压后执行 `chown -R 1000:1000 ./bge_model`，或者保证 Docker 以 privileged 模式运行）*。

------

### 四、 阶段三：Docker Compose 核心机制拆解（灵魂所在）

这是整个部署流程最核心的一环。我们结合你之前提问的 Compose 配置，进行硬核还原。

手册核心配置回顾：

```
xinference:
  image: docker.m.daocloud.io/xprobe/xinference:nightly-main-cpu-new
  container_name: xinference
  volumes:
    - ./bge_model:/root/.cache/custom/models
  environment:
    - XINFERENCE_MODEL_SRC=modelscope
  entrypoint: sh -c "/opt/nvidia/nvidia_entrypoint.sh; xinference -H 0.0.0.0 --port 9997 --log-level debug; tail -f /dev/null"
  
  # 直接使用 command 来指定启动参数，更清晰（比entrypoint可读性更强）
  #command: >
    #xinference-local 
    #-H 0.0.0.0 
    #--port 9997 
    #--log-level debug
    
    
  ports:
    - "18345:9997"
```

**深度刨析：**

1. **镜像分层与内部机制**：

   `xinference:nightly-main-cpu-new`这个镜像，底层是基于 Python 的。它打包了 `transformers`, `torch`等重型库。使用 DaoCloud 私有仓库，是为了绕过客户机房无法访问 Docker Hub 的限制。

2. **Volume 挂载的魔法**：

   `- ./bge_model:/root/.cache/custom/models`本质上是 Linux 的 **Bind Mount**(绑定挂载)。它将宿主机的目录直接映射进容器的命名空间。这意味着，即使容器崩溃重启，模型权重依然安全地躺在宿主机硬盘上，实现了**数据与运行时的分离**。

3. **环境变量注入**：

   `XINFERENCE_MODEL_SRC=modelscope`告诉框架：不要去 HuggingFace 找模型，而是去 ModelScope（阿里魔搭社区） 的本地缓存目录找。这是离线部署成功的关键密钥。

4. **Entrypoint 的命令链**：

   这是一个非常经典的 Docker 技巧。

   - `/opt/nvidia/nvidia_entrypoint.sh`：虽然是 CPU 镜像，但官方为了统一入口，保留了 NVIDIA 的初始化脚本（在 CPU 环境下相当于空跑）。
   		- 虽然用的是 CPU 镜像，但这个镜像可能保留了 NVIDIA 的基础层。
   		- 这个脚本通常用于设置 CUDA 环境和权限。
   		- 即使没有 GPU，运行它通常也不会报错，而且能保证环境初始化完成
   - `xinference -H 0.0.0.0 ...`：启动主服务进程。
   		- -H 0.0.0.0：允许外部访问（不仅仅是 localhost）。
   		- --port 9997：指定服务监听 9997 端口。
   		- --log-level debug：输出详细日志，方便排查模型加载失败的问题。
	- `tail -f /dev/null`：**保活机制**。如果 Xinference 意外崩溃，这个命令能防止容器退出，为你留出 `docker exec`进去调试的时间。
   		/dev/null 是个永远空、永远不会出新内容的文件
     	tail -f 就是死盯着等新内容
     	因为永远等不到，所以它无限卡住、不结束、不退出
     	- 使用该命令通常是因为主进程没有以前台模式运行。Xinference 本身是支持前台运行的，不需要这个补丁，可以改成重启策略`restart: unless-stopped`
   
5. **端口映射**:
   - 左边 18345：是你宿主机（服务器）的端口
   - 右边 9997：是容器内部 Xinference 监听的端口
   - 访问方式：你在浏览器输入 http://服务器IP:18345就能打开 Xinference 的 Web UI 或 API 接口
- ###补：端口映射的底层原理
   1. 核心定义
   端口映射（Port Mapping）​ 是 Docker 连接宿主机（Host）与容器（Container）网络的桥梁。其核心目的是将容器内部封闭的服务暴露给外部访问。

```yaml
ports:
- "宿主机端口:容器端口"
# 示例："18345:9997"
```

   2. 为什么需要端口映射？
      2.1 网络隔离（Network Namespace）
   - Docker 容器运行在独立的 Network Namespace中，拥有完全隔离的网络栈（IP、网卡、端口）
   - 现象：容器内的 127.0.0.1:9997只能在容器内部访问。
   - 结果：宿主机无法直接通过 localhost:9997访问容器服务。
      2.2 解决冲突
      多个容器可以同时运行，如果都直接监听宿主机的 80 端口，会发生冲突。端口映射允许宿主机通过不同端口（如 8080, 8081）分发流量。

   3. 底层实现原理（Linux Kernel）
      Docker 端口映射并非应用层转发，而是基于 **Linux 内核**级的技术。
      3.1 核心技术栈
      - iptables (NAT)：核心执行者，在 PREROUTING 链中修改数据包的目标地址（DNAT）。
      - Network Namespace：隔离舱，确保容器拥有独立的网络环境。
      - veth pair：虚拟网线，连接容器和宿主机网桥（docker0），负责搬运数据包
      - ip_forward：内核开关，必须开启 net.ipv4.ip_forward=1，否则宿主机不会转发数据包。
      3.2 数据流图解（以访问 18345为例）
      text
      [ 外部请求 ]
      |
      v
      [ 宿主机 IP:18345 ]
      |
      v
      [ iptables 拦截 ]
      |
      v
      [ DNAT 转换: 目标地址 -> 容器IP:9997 ]
      |
      v
      [ Docker 网桥 (docker0) ]
      |
      v
      [ 容器内部: 9997 (Xinference) ]
      
   4. 端口选择的“潜规则”
      4.1 容器端口（右侧）：由应用决定
      - 定义：容器内服务实际监听的端口。
      
      - 来源：通常由 Dockerfile 的 EXPOSE指令或启动命令（如 --port 9997）指定。
      
      - 关于端口号 18345的选择逻辑
      
        18345并非固定值，其选择基于以下考量：
      
        1. 避免特权端口：Linux 规定 0-1023为特权端口，普通用户无权监听，因此通常避开。
      
        2. 避免常用端口冲突：3306(MySQL)、6379(Redis)、8080(HTTP) 等端口常被宿主机或其他容器占用。
      
        3. 高位随机性：18345属于 1024-65535的动态/私有端口范围，降低了与其他服务冲突的概率，同时增加了外部扫描的难度（安全性）
      
      - 不可随意改：除非你修改应用的启动配置，否则必须匹配应用监听的端口。
      
        4.2 宿主机端口（左侧）：由用户决定

	  - 定义：外部访问宿主机时使用的端口。
	  - 范围：1024 - 65535（非特权端口，避免与系统服务冲突）。
	  - 灵活性：可以任意指定，只要未被占用。例如将 18345改为 8888完全可行。

   5. 实战配置解析（Xinference 案例）
```yaml
xinference:
  image: xprobe/xinference:nightly-main-cpu-new
  ports:
    - "18345:9997"  # 宿主机18345 -> 容器9997
  command: >
      xinference-local 
      -H 0.0.0.0 
      --port 9997  # 必须与右侧端口一致
```
   原则：右随应用，左随心情。
   改对外端口：只需修改左边数字。

```yaml
ports: ["8080:9997"]  # 访问 http://host:8080
```

改对内端口：需同时修改应用配置和映射。

```yaml
command: xinference-local --port 8000
ports: ["18345:8000"]
```
6. 常见误区与调试
6.1 容器间通信不需要端口映射

​      如果服务 A 需要访问 Xinference（服务 B）：

​      错误：http://宿主机IP:18345（绕路，效率低）

​     正确：http://xinference:9997（直连，利用 Docker DNS）

​      6.2 防火墙阻断

​      即使 Docker 配置正确，宿主机的防火墙（Firewalld/UFW）若未放行 18345端口，外部依然无法访问。

​      6.3 查看底层规则

​      验证 Docker 是否写入了 iptables 规则：

```bash
sudo iptables -t nat -L -n | grep 18345
```
7.  总结

​     本质：Linux 内核的 DNAT 流量转发。

​     口诀：左外右内，右定左变。

​     核心价值：在不侵入容器网络的情况下，安全地打通内外网络

------

### 五、 阶段四：服务拉起与模型热加载（让骨架长出血肉）

手册步骤回顾：

```
docker-compose up -d
docker-compose ps
docker exec -it xinference bash
curl --location --request POST 'http://ip:port/v1/embeddings' 
```

**深度刨析：**

1. **`docker-compose up -d`底层发生了什么？**

   Docker 引擎会根据 YAML 文件创建一个隔离的 Network Namespace（默认桥接网络），然后将容器的 9997 端口映射到宿主机的 18345 端口。

2. **为什么一定要进容器执行注册？**

   虽然模型文件已经在硬盘上，但 Xinference 作为一个模型生命周期管理平台，需要将其**元数据（UID、模型类型、路径）注册进内置的 SQLite 数据库中**。

   手册里的 `curl`命令，实际上就是向 Xinference 的 API 发送指令，触发它在后台加载模型权重到内存中。

3. **多核 CPU 的利用：**

   当你发送 Embedding 请求时，如果你没有在请求体中指定特定的 `device`（如 `cpu:0`），Xinference 默认会使用多线程。此时，你如果在宿主机上运行 `top`命令，会发现多个 CPU 核心的利用率同时飙升，这就是 PyTorch 底层在并行处理你的向量化请求。

------

### 六、 阶段五：与企业大脑的级联（交付的价值体现）

孤立的 Embedding 服务毫无意义，它必须与企业大脑的主平台对接。

手册步骤回顾：

```
勾选: embedding
模型名称: bce-embedding
URL: http://ip:port (port是xinference平台端口，默认18345)
```

**深度刨析：**

这里暴露了一个在企业级开发中极为常见的痛点：**网络连通性**。

企业大脑的主服务（可能是 Java 写的，跑在另一个 Tomcat 或 Docker 里）需要通过内网 IP 访问你刚刚部署的 Xinference。

- 如果它们在同一个 Docker Compose 网络中，可以用服务名 `xinference:9997`直连。

- 如果它们是物理隔离的两个服务，就必须用宿主机的 `18345`端口。

  这也是为什么手册里反复强调要配置 `LOCAL_EMB_URL`的原因。
  
- 如果无法访问，可能的原因？
1. 模型文件与路径的问题：核心逻辑：Xinference 收到了你的 API 请求，但它去硬盘上找模型文件时，没找到或者没权限
docker-compose中写了：
```yaml
volumes:
  - ./bge_model:/root/.cache/custom/models
```
```
在宿主机执行
ls - ./bge_model
```

必须看到：bce-embedding-base_v1这个文件夹，且里面有 pytorch_model.bin等文件。
常见错误：把模型解压到了 ./models目录，但容器挂载的是 ./bge_model。
修正：把模型文件移动到 ./bge_model，或者修改 docker-compose.yml的挂载路径。

2. Xinference 服务状态：核心逻辑：容器虽然起来了，但里面的服务可能还没完全初始化好，或者已经崩溃。

查看 Xinference 日志（最直接的证据）
```shell
docker logs xinference
```
重点看红色报错：
- PermissionError：模型文件权限不对，执行 chmod -R 755 ./bge_model。
- OSError: Can't load tokenizer：模型文件损坏或不完整，重新下载解压。
- CUDA out of memory：如果是 GPU 模式，显存不够加载模型（Embedding 模型虽小，但也需要显存）

服务是否真的在监听
```shell
netstat -tlnp | grep 18345
```

```
补：netstat和ss的区别
1. 底层实现机制（最核心的差异）
netstat(读取 /proc 伪文件)：它是一个传统的用户空间程序。当它运行时，会去读取内核暴露出来的伪文件系统 /proc/net/tcp、/proc/net/udp等文本文件，然后再由 netstat自己在用户态进行解析和格式化。

ss(直接使用 Netlink 接口)：它是 iproute2软件包的一部分（现代 Linux 发行版的标配）。它绕过了 /proc文件系统，直接通过 Netlink 套接字向 Linux 内核发起查询请求，内核直接把当前内核中的 Socket 信息返回给用户。

2. 性能表现（高并发下的天壤之别）

这是由底层机制直接导致的结果差异：netstat极慢：在一个拥有几万个并发连接的服务器上（比如你跑了一个高并发的 Xinference 或大模型推理服务），netstat需要遍历并解析成千上万个文件句柄，这会消耗大量的 CPU 和内存，甚至可能把终端卡死。

ss极快：因为它直接向内核查询，内核在做数据返回时经过了高度优化，哪怕面对几十万的并发连接，ss也能在毫秒级内瞬间给出结果，几乎不消耗系统资源。

3. 功能与输出信息的丰富度
ss信息更详尽：除了基本的端口和 IP，ss还能显示更多的内核级细节。比如，它可以显示连接的拥塞控制算法、接收/发送队列大小（对于排查网络吞吐瓶颈极其有用）、以及定时器信息。

netstat逐渐边缘化：在较新的 Linux 发行版（如 CentOS 8、Ubuntu 22.04+）中，netstat甚至不再默认安装，你需要额外安装 net-tools包才能使用它。
```

如果没有输出，说明容器没起来或端口没映射。
如果有输出，说明端口通了，但服务内部逻辑报错。

3. API请求格式错误： 核心逻辑：你发的请求格式不对，Xinference 无法解析
请求 Body 是否完整？
```shell
curl --location --request POST 'http://127.0.0.1:18345/v1/embeddings' \
--header 'Content-Type: application/json' \
--data-raw '{
  "model": "bce-embedding-base",
  "input": "你好"
}'
```
4. 资源限制：核心逻辑：作为算法运维开发，你需要考虑资源是否达标
内存是否爆了？(Embedding 模型虽然是 CPU 跑，但如果机器内存太小（比如小于 8G），加载模型时会瞬间 OOM 被杀掉。)
```shell
free -h
```
如果内存剩余很少，关掉其他占用内存的程序

5. CPU 指令集不支持：文档里提到要检查 lscpu | grep avx
如果客户机器是非常老的 CPU（不支持 AVX 指令集），PyTorch 会直接报错无法运行。
解决方案：换支持 AVX 的机器，或者找实在智能要一个兼容旧 CPU 的镜像

------

### 七、 总结：

单节点多核 CPU 部署流程：

1. **底层硬件感知**（指令集、内存、磁盘）
2. **操作系统原理**（进程隔离、文件权限、端口映射）
3. **大模型推理机制**（离线权重加载、CPU 矩阵运算）
4. **企业级交付规范**（网络连通性、服务保活、离线包管理）

**K8s 只是一个运行载体，它解决的是“规模化调度”的问题；而今天的这套流程，解决的是“应用到底怎么跑起来”的问题。**

### 为什么要用到docker-compose
1. Dockerfile vs Compose
	- Dockerfile 是构建阶段用的，负责把环境和代码打包成镜像；
	- 而 Docker Compose 是交付阶段用的，负责定义容器怎么跑（端口、目录挂载、网络）。

交付包里已经提供了 xinference.tar镜像，所以不需要 Dockerfile 去现场编译，只需要 Compose 把它跑起来。

2. 场景适配，为什么不用 K8s
	- K8s 是为大规模集群和高可用设计的，但这会带来巨大的资源开销和运维复杂度
	- 客户通常只有 1-3 台物理机，且缺乏专业的 K8s 运维人员
	- 使用 Docker Compose 能节省 K8s Master 节点消耗的资源，且交付简单，符合客户现状

3. 业务价值（离线交付）
	- 私有化部署通常是离线环境。
	- Docker Compose 配合离线镜像包，可以实现‘解压即运行’，不需要依赖任何外网仓库或复杂的集群配置

###docker-compose的终极版

这是为你定制的**“终极版”**配置。它融合了 **安全、稳定、可观测、易交付** 四大特性，专门针对你们公司的 **Xinference CPU 推理场景** 进行了深度优化。

#### 1. 最完美的 `docker-compose.yml`

```
version: '3.8'

services:
  xinference:
    # 1. 镜像：使用 Daocloud 私有仓库，确保离线可用
    image: docker.m.daocloud.io/xprobe/xinference:nightly-main-cpu-new
    
    # 2. 容器名：固定名称，便于运维
    container_name: xinference
    
    # 3. 用户：非 root 运行（安全红线）
    user: "1000:1000"
    
    # 4. 重启策略：除非手动停止，否则始终重启
    restart: unless-stopped
    
    # 5. 资源限制：防止吃光宿主机资源（交付必杀技）
    deploy:
      resources:
        limits:
          cpus: '8'
          memory: 16G
    
    # 6. 卷挂载：数据持久化 + 只读保护
    volumes:
      # 模型目录：只读，防止容器误删模型
      - ./bge_model:/root/.cache/custom/models:ro
      # 日志目录：可写，方便排查
      - ./logs:/root/logs
      # 时区同步：确保日志时间与宿主机一致
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    
    # 7. 环境变量：优化推理性能
    environment:
      - XINFERENCE_MODEL_SRC=modelscope
      - OMP_NUM_THREADS=8          # 控制 OpenMP 并行数
      - MKL_NUM_THREADS=8          # 控制 Intel MKL 并行数
      - PYTHONMALLOC=malloc        # 优化内存分配，防碎片
      - MALLOC_ARENA_MAX=2         # 减少内存锁竞争
    
    # 8. 启动命令：简洁、明确、无保活黑魔法
    command: >
      sh -c "/opt/nvidia/nvidia_entrypoint.sh || true && 
             xinference -H 0.0.0.0 --port 9997 --log-level debug"
    
    # 9. 端口映射：暴露服务
    ports:
      - "18345:9997"
    
    # 10. 健康检查：真实探测服务可用性
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9997/v1/models || exit 1"]
      interval: 30s      # 每 30 秒检查一次
      timeout: 10s       # 10 秒超时
      retries: 5         # 重试 5 次才判定失败
      start_period: 60s # 启动后 60 秒内不检查（留给模型加载时间）
    
    # 11. 日志管理：防止磁盘爆满
    logging:
      driver: "json-file"
      options:
        max-size: "10m"  # 单个日志最大 10MB
        max-file: "5"    # 最多保留 5 个日志文件
```

------

#### 2. 为什么这是“最完美”的？（深度解析）

- 安全性（Security）

| 配置                | 作用                                           |
| ------------------- | ---------------------------------------------- |
| `user: "1000:1000"` | **核心**。防止容器逃逸后获得宿主机 root 权限。 |
| `:ro`(只读挂载)     | 防止恶意进程或 Bug 删除宿主机上的模型文件。    |
| `/etc/timezone`     | 防止时区篡改，确保日志时间戳正确。             |

- 稳定性（Stability）

| 配置                      | 作用                                                         |
| ------------------------- | ------------------------------------------------------------ |
| `restart: unless-stopped` | 服务器重启后自动拉起，比 `always`更安全。                    |
| `deploy.resources.limits` | **交付神器**。限制 16G 内存，防止 Xinference 内存泄漏拖垮整台服务器。 |
| `OMP_NUM_THREADS=8`       | 控制 CPU 使用率，避免 100% 占满导致系统卡死。                |
- 可观测性（Observability）

| 配置               | 作用                                              |
| ------------------ | ------------------------------------------------- |
| `healthcheck`      | **真活**。不仅看容器是否运行，还看 API 是否响应。 |
| `logging.max-size` | **防雪崩**。防止日志写满 1T 硬盘，导致交付事故。  |
| `./logs`挂载       | 方便客户运维直接查看日志，无需 `docker logs`。    |

- 交付友好性（Delivery）

| 配置                | 作用                                     |
| ------------------- | ----------------------------------------|   
| `start_period: 60s` | 给大模型加载留出时间，避免误判为不健康。 |


------

#### 3. 配套的最佳实践（必须一起做）
- 宿主机目录权限（解决 `user: 1000`报错）

**这是 90% 交付失败的原因！** 在 `docker-compose up -d`之前，必须在宿主机执行：

```
# 创建模型目录
mkdir -p ./bge_model
# 赋予权限（让 uid 1000 的用户能读）
sudo chown -R 1000:1000 ./bge_model
sudo chmod -R 755 ./bge_model
```

- 离线镜像加载

```
# 加载镜像（手册标准流程）
docker load -i xinference.tar
# 启动
docker-compose up -d
# 检查
docker-compose ps
docker-compose logs -f xinference
```

------

#### 4. 面试话术

 Docker Compose 部署改进的地方

**回答**：

> “K8s 适合大规模集群，但我们做的是**私有化交付**。客户只有一台机器，且可能没有专业运维。
>
> 这个配置是针对**交付痛点**设计的：
>
> 1. **防资源抢占**：我加了 `mem_limit: 16G`。客户的服务器通常还跑着数据库，如果我不限制，AI 模型会把内存吃光，导致客户业务挂掉。
>
> 2. **防误操作**：模型目录我用了 `:ro`只读挂载。曾经有客户运维误删了容器里的文件，导致服务坏了。现在他删不掉。
>
> 3. **真活探测**：`healthcheck`不仅看容器，还看 API。以前容器活着但服务死了，客户投诉说‘怎么没报警’。现在不会了。
>
> 对于单节点交付，**简单、稳定、可控**比技术先进性更重要。”

------

#### 5. 总结

| 维度       | 手册原始版     | **你的完美版**       |
| ---------- | -------------- | -------------------- |
| **定位**   | 功能演示       | **生产交付**         |
| **安全性** | ❌ Root 运行    | ✅ 非 Root            |
| **稳定性** | ❌ 可能拖垮系统 | ✅ 资源隔离           |
| **排错**   | ❌ 黑盒         | ✅ 日志清晰、健康可见 |

