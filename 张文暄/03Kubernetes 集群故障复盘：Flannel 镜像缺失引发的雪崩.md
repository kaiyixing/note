# Kubernetes 集群故障复盘：Flannel 镜像缺失引发的雪崩

# 1\. 故障现象

- **集群状态**：单节点 k8s\-master\-shizai状态异常，业务 Pod 大规模 Evicted。

- **网络状态**：CoreDNS 无法解析，Node 节点处于 NotReady状态。

- **Flannel 状态**：kubectl get pods \-n kube\-system显示 Flannel 卡在 Init:ImagePullBackOff或 PodInitializing。

- **磁盘表象**：df \-h显示磁盘使用率 63%，df \-i显示 Inode 使用率 9%，看似健康。

# 2\. 排查过程与具体命令

## 2\.1 排除磁盘空间问题

**目标**：确认底层存储是否真的满了。

```bash
# 1. 查看磁盘块使用率
df -h /data
# 输出：使用率 63%

# 2. 查看 Inode 使用率（防止小文件占满）
df -i /data
# 输出：使用率 9%

# 3. 查看 Docker 自身存储占用
docker system df
# 输出：总占用 16.38GB
```

**结论**：磁盘和 Inode 均充足，排除存储瓶颈。

## 2\.2 定位 Flannel 启动失败原因

**目标**：检查 Flannel Pod 为何无法完成初始化。

```bash
# 1. 查看 Flannel Pod 状态
kubectl get pods -n kube-system -l app=flannel
# 输出：kube-flannel-ds-lgtl7   0/1   Init:ImagePullBackOff   0   159m

# 2. 描述 Pod 详情（关键步骤）
kubectl describe pod kube-flannel-ds-lgtl7 -n kube-system
```

**关键输出**：

```text
Init Containers:
  install-cni-plugin:
    State:          Waiting
      Reason:       ImagePullBackOff
    Image:         docker.io/rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.0
Events:
  Type    Reason   Age                     From     Message
  ----    ------   ----                    ----     -------
  Normal  BackOff  2m25s (x454 over 117m)  kubelet  Back-off pulling image "docker.io/rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.0"
```

## 2\.3 验证镜像仓库

**目标**：确认 Docker 本地是否存在该镜像。

```bash
docker images | grep flannel
# 输出：仅存在 v0.19.1（主镜像），缺失 v1.1.0（Init镜像）
```
**为什么缺少v1.1.0不可以:**
- v0.19.1（主程序）：这是 Flannel 本体（也就是你有的那个镜像 rancher/mirrored-flannelcni-flannel）。它是用 Go 语言写的 Flannel 核心守护进程。

- v1.1.0（依赖插件）：这是 Flannel CNI 插件（也就是你缺的那个镜像 rancher/mirrored-flannelcni-flannel-cni-plugin）。它是 Flannel 为了和 Kubernetes 网络规范（CNI）对接而依赖的一个标准二进制工具。

- 部署前，一定要把 YAML 文件里涉及到的 所有镜像（包括主镜像、Init 镜像、sidecar镜像）全部提前 docker load进去，一个都不能少

	- sidecar（边车）镜像：辅助性质的容器镜像，为主容器提供日志收集、配置管理、网络代理、监控等附加能力，解耦思想，让主容器专注于核心业务
	- Flannel不需要边车镜像：因为它功能单一（只接通网络）、机制巧妙（靠内核和二进制文件干活），所以它完全不需要 Sidecar

在早期的 Flannel 版本中，CNI 插件是直接塞进 Flannel 主程序的镜像里的。但后来为了架构解耦，官方把 CNI 插件剥离了出来，单独形成了一个镜像

## 2\.4 检查 Kubelet 驱逐配置

**目标**：确认是否是 Kubelet 配置过于严格。

```bash
cat /var/lib/kubelet/config.yaml | grep -A 10 -B 5 eviction
# 输出：仅存在 evictionPressureTransitionPeriod: 0s，无自定义阈值
```

# 3\.  原因

## 3\.1 直接原因

Flannel 的 Init Container 镜像缺失。

Flannel DaemonSet 包含两个 Init 容器：

- install\-cni\-plugin：需要镜像 rancher/mirrored\-flannelcni\-flannel\-cni\-plugin:v1\.1\.0（缺失）。

- install\-cni：需要镜像 rancher/mirrored\-flannelcni\-flannel:v0\.19\.1（存在）。

由于是纯离线环境，Kubelet 无法拉取缺失的插件镜像，导致 Init Container 无限重试，Flannel 无法启动。

## 3\.2 连锁反应（雪崩效应）

Flannel 是 Kubernetes 的网络底座，它挂了会触发以下连锁反应：

1. **网络瘫痪**：节点无法跨 Pod 通信，CoreDNS 失效。

2. **Node NotReady**：Kubelet 检测到网络异常，将节点标记为 NotReady。

3. **Kubelet 自我保护**：Kubelet 认为节点不健康，触发保护机制，批量驱逐（Evicted）业务 Pod。

4. **集群崩塌**：所有非系统级 Pod 被清空。

# 4\. 解决方法与具体命令

## 4\.1 离线导入缺失镜像（核心修复）

找 Mentor 获取 flannel\-cni\-plugin的离线包。

```bash
# 1. 导入镜像
docker load -i flannel-cni-plugin-v1.1.0.tar

# 2. 验证镜像
docker images | grep flannel
# 预期输出：v1.1.0 存在
```

## 4\.2 重启 Flannel 组件

强制 DaemonSet 重新创建 Pod。

```bash
# 1. 删除旧 Pod
kubectl delete pod -n kube-system -l app=flannel

# 2. 或直接滚动重启（推荐）
kubectl rollout restart daemonset kube-flannel-ds -n kube-system
```

## 4\.3 清理战场

删除已驱逐的 Pod 尸体。

```bash
kubectl get pods -A | grep Evicted | awk '{print $1, $2}' | xargs -n2 kubectl delete pod -n
```

## 4\.4 验证恢复

```bash
# 1. 检查 Node 状态
kubectl get nodes
# 预期：STATUS Ready

# 2. 检查 CoreDNS
kubectl get pods -n kube-system | grep coredns
# 预期：STATUS Running

# 3. 检查业务 Pod 是否自愈
kubectl get pods -A
```

# 5\. 底层原理解析

## 5\.1 Init Container 机制

Flannel 不仅仅是运行一个容器，它需要向宿主机写入网络配置和二进制文件。

- install\-cni\-plugin：负责将 flannel二进制文件拷贝到宿主机的 /opt/cni/bin。这是 CNI 插件的核心，缺失则无法配置网络。

- install\-cni：负责生成 /etc/cni/net\.d/10\-flannel\.conflist配置文件。

如果 install\-cni\-plugin失败，后续所有步骤都无法进行。

## 5\.2 Kubelet 的驱逐机制（Eviction）

Kubelet 持续监控节点资源，当检测到节点不健康时，会触发保护机制：

- DiskPressure：磁盘不足（默认 nodefs\.available \&lt; 10%）。

- MemoryPressure：内存不足。

- NetworkUnavailable：网络不可用（本案例的根源）。

**注意**：当 Flannel 挂掉导致 NetworkUnavailable=True时，Kubelet 会立即驱逐非关键 Pod，以防止更多流量进入故障节点。

## 5\.3 离线环境的特殊性

在离线部署中，“镜像即软件”。Kubernetes 不会帮你下载任何东西，你必须确保所有层级（Main Container \+ Init Container \+ Sidecar）的镜像都已提前存在于节点本地。

# 6\. 经验总结

- 查 Pod 先看 describe：ImagePullBackOff和 CrashLoopBackOff是两大最常见的错误，前者通常是镜像问题，后者通常是程序配置问题。

- Init Container 是盲区：很多时候我们只关注主容器，忽略了 Init 容器也需要镜像。

- Evicted 不等于磁盘满：Node 状态异常（如 NotReady）也会触发驱逐。

- 离线包要全：部署前务必核对 DaemonSet 或 Deployment 的 YAML 文件，确认所有 image:字段对应的镜像都已导入。
