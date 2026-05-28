# Kubernetes 离线环境部署 Metrics Server 实战笔记

## 一、背景与环境
- **环境特点**：单 Master 节点、离线环境（无法访问外网）、使用 containerd 作为容器运行时。
- **核心痛点**：官方 `metrics-server`默认配置依赖外网镜像和严格的 TLS 证书校验，在离线单节点环境下必然部署失败。

## 二、部署流程详解

### 第一阶段：离线镜像准备（在有网络的机器上操作）

由于 K8s 无法访问 `k8s.gcr.io`，必须手动将镜像搬运到 Master 节点。
```shell
# 1. 从国内镜像源拉取指定版本（v0.6.1 兼容性最好）
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server:v0.6.1

# 2. 将镜像打包成 tar 文件
docker save registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server:v0.6.1 -o metrics-server-v0.6.1.tar

# 3. 拷贝镜像包到 Master 节点
scp metrics-server-v0.6.1.tar root@<Master_IP>:/root/
```

### 第二阶段：镜像导入 Containerd（在 Master 节点操作）
** 关键避坑点**：Kubernetes 使用的是 containerd 的 `k8s.io`命名空间，而不是 Docker 的默认命名空间。
```shell
# 1. 查看 containerd 命名空间（确认 k8s.io 存在）
ctr ns ls

# 2. 将镜像导入 k8s.io 命名空间（必须加 -n k8s.io）
ctr -n k8s.io images import metrics-server-v0.6.1.tar
#ctr -n k8s.io images import 文件名.tar   把打包的文件“安装”到系统里

# 为什么不用解压的方式呢
#手动解压 docker save生成的 .tar文件，会得到一堆分层的目录和 JSON 配置文件。但这并不是容器运行时（containerd）能够直接使用的格式。ctr import命令的作用，就是充当一个“翻译官”或“搬运工”，将磁盘上标准格式的镜像包，转换并注册到容器运行时的内部存储结构中。

#如果先解压 .tar包，再尝试让 ctr去读取解压后的文件夹，命令将会失败，因为它期待的是一个特定格式的归档文件，而不是一个文件夹。

# 3. 验证镜像是否存在于 k8s.io 中
ctr -n k8s.io images ls | grep metrics-server
```
### 第三阶段：定制化部署（核心步骤）
官方 YAML 不适合离线单节点，必须修改。
```shell
# 1. 下载官方部署文件(从有网的机器上下载，并拷贝到本地)
wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
scp...

# 2. 编辑文件
vim components.yaml
```
**修改内容如下：**
```yaml
containers:
- name: metrics-server
  # 修改点 1：替换成本地已有的镜像地址!!!!!
  image: registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server:v0.6.1
  # 修改点 2：强制禁止去外网拉取!!!!!
  imagePullPolicy: Never
  args:
    - --cert-dir=/tmp
    - --secure-port=4443
    # 修改点 3：使用 IP 访问 Kubelet（单节点 DNS 常出问题）
    - --kubelet-preferred-address-types=InternalIP
    # 修改点 4：跳过 TLS 证书校验（单节点证书通常不合法）
    - --kubelet-insecure-tls
```
### 第四阶段：应用与验证
```shell
# 1. 应用配置
kubectl apply -f components.yaml
# 2. 实时监控 Pod 状态
watch kubectl get pods -n kube-system | grep metrics-server
# 3. 验证功能（看到数据即为成功）
kubectl top nodes
kubectl top pods -A
```
## 三、核心概念解析

### 1. 为什么是 `k8s.io`命名空间？
- `kubectl get ns`看到的是 **Kubernetes 的资源隔离命名空间**（如 `default`, `kube-system`）。
- `ctr -n k8s.io`指的是 **Containerd 的命名空间**。
- Kubernetes 只认 `k8s.io`里的镜像，用 `docker load`导入的镜像 K8s 是看不见的。
  
### 2. 为什么要加那两个参数？
- `--kubelet-preferred-address-types=InternalIP`：防止 Master 节点解析自身主机名失败。
- `--kubelet-insecure-tls`：Metrics Server 需要访问 Kubelet 获取指标，单节点证书通常自签，必须跳过校验。
## 四、故障排查速查表

| 现象                | 原因                                    | 解决方案                                      |
| ------------------- | --------------------------------------- | --------------------------------------------- |
| `ImagePullBackOff`  | 镜像没导入 `k8s.io`命名空间             | `ctr -n k8s.io images import ...`             |
| `ErrImageNeverPull` | `imagePullPolicy`为 `Never`但本地无镜像 | 确认镜像名与本地完全一致                      |
| `CrashLoopBackOff`  | 缺少 TLS 或 IP 参数                     | 检查 YAML 中是否加了 `--kubelet-insecure-tls` |
| `Unknown`           | 节点 NotReady 或 Flannel 异常           | 检查节点状态和网络插件                        |

## 五、总结
本次部署成功解决了三个核心难题：
1. **镜像孤岛**：通过 `docker save/load`和 `ctr import`打通离线环境。
2. **外网阻断**：通过 `imagePullPolicy: Never`防止无效拉取。
3. **单节点适配**：通过 `--kubelet-insecure-tls`解决证书信任问题。

