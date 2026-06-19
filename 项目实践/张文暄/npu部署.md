# 昇腾（Ascend）NPU 物理机部署全流程实战笔记

> **适用场景**：Kubernetes 异构算力节点、AI 训练/推理集群
>
> **硬件环境**：Atlas 系列服务器（如 Atlas 800 9000）
>
> **操作系统**：Ubuntu 20.04 / 22.04 LTS
>
> **目标**：完成从物理硬件上架到 `npu-smi info`验证成功的全过程。

------

## 一、 部署架构与核心概念

在开始之前，必须先理清两个最容易混淆的包：

| 包名                | 类型                | 作用                                                       | 类比                 |
| ------------------- | ------------------- | ---------------------------------------------------------- | -------------------- |
| **Ascend-driver**   | **驱动 (Driver)**   | 运行在 Host OS 中，负责与 Linux 内核交互，为上层提供 API。 | 电脑的 **显卡驱动**  |
| **Ascend-firmware** | **固件 (Firmware)** | 刷写在 NPU 芯片内部，控制芯片最底层的启动和电源管理。      | 主板的 **BIOS/UEFI** |

⚠️ **黄金法则**：**Driver 和 Firmware 版本必须严格配套！** 版本不匹配会导致 NPU 掉卡或算力异常。

------

## 二、 环境准备（物理机）

### 1. 硬件检查

确保 NPU 卡已正确插入 PCIe 插槽，且供电正常。

```
# 在物理机上执行，必须能看到设备
lspci | grep -i ascend
# 预期输出示例：1a1c:2080 (Huawei Technologies Co., Ltd. Device 2080)
```

### 2. 系统与内核检查

```
# 查看系统版本
cat /etc/os-release

# 查看内核版本（建议 5.x 版本，且与驱动兼容）
uname -r
```

### 3. 安装依赖工具

```
apt-get update
apt-get install -y gcc g++ make dkms linux-headers-$(uname -r) net-tools
```

------

## 三、 软件包获取与规划

从 [昇腾社区](https://www.hiascend.com/)下载以下包（以 25.5.1 为例）：

1. 

   `Ascend-firmware_25.5.1_linux.run`

2. 

   `Ascend-driver_25.5.1_linux.run`

3. 

   `Ascend-cann-toolkit_25.5.1_linux.run`(后续 AI 框架依赖)

**目录规划**：

```
mkdir -p /opt/ascend/install
mv *.run /opt/ascend/install/
cd /opt/ascend/install/
```

------

## 四、 部署实施步骤

### Step 1：安装固件 (Firmware)

固件是底层基础，必须先装。

```
# 赋予执行权限
chmod +x Ascend-firmware_25.5.1_linux.run

# 安装固件
./Ascend-firmware_25.5.1_linux.run --full
```

**验证**：固件安装通常无输出，只要不报错即为成功。

### Step 2：安装驱动 (Driver)

驱动安装会自动编译内核模块（DKMS）。

```
# 赋予执行权限
chmod +x Ascend-driver_25.5.1_linux.run

# 安装驱动（--full 表示完整安装，包含 Driver 和 Management 工具）
./Ascend-driver_25.5.1_linux.run --full
```

**安装过程监控**：

安装过程中会刷屏编译内核模块，此时可以通过另一个终端查看：

```
top
# 看到 cc1 和 make 进程占用高 CPU，说明正在编译，切勿中断！
```

### Step 3：加载内核模块

虽然安装脚本通常会自动加载，但手动确认一次更稳妥。

```
# 加载核心模块
modprobe ascend

# 检查模块是否加载成功
lsmod | grep ascend
# 预期输出：大量 ascend 开头的模块
```

### Step 4：配置环境变量

为了方便使用 `npu-smi`等工具，配置全局变量。

```
vim /etc/profile
```

在文件末尾添加：

```
export ASCEND_HOME=/usr/local/Ascend
export PATH=$ASCEND_HOME/driver/tools:$PATH
export LD_LIBRARY_PATH=$ASCEND_HOME/driver/lib64:$LD_LIBRARY_PATH
```

使其生效：

```
source /etc/profile
```

------

## 五、 验证与验收

### 1. 基础状态验证

```
# 查看 NPU 概要信息（这是最重要的命令）
npu-smi info
```

**预期成功画面**：

- 

  显示芯片型号（如 Ascend910B）

- 

  显示健康状态（Health Status: OK）

- 

  显示温度、功率、内存使用情况

### 2. 详细拓扑验证

```
# 查看芯片间互联拓扑（适用于多卡服务器）
npu-smi topology -m
```

### 3. 健康检查

```
# 运行 NPU 自检
npu-smi health -c 0
```

------

## 六、 常见问题排障 (Troubleshooting)

| 故障现象                          | 可能原因                      | 解决方案                                                     |
| --------------------------------- | ----------------------------- | ------------------------------------------------------------ |
| `npu-smi: command not found`      | 环境变量未配置                | `source /etc/profile`或检查 `/usr/local/Ascend`是否存在。    |
| `dcmi module initialize failed`   | 驱动未加载 / 固件不匹配       | 1. 检查 `lsmod \| grep ascend`。 2. 确认 Firmware 和 Driver 版本一致。 3. 执行 `reboot`。 |
| 安装驱动时编译报错                | 缺少内核头文件                | `apt-get install linux-headers-$(uname -r)`。                |
| 卡在 `Waiting for device startup` | BIOS 未开启 Above 4G Decoding | 重启进入物理机 BIOS，开启 `Above 4G Decoding`和 `SR-IOV`（如有）。 |
| `lspci`找不到卡                   | 硬件松动或 PCIe 槽位禁用      | 重新拔插 NPU 卡，检查服务器 BMC 日志。                       |

------

## 七、 交付物清单（给 Mentor 看）

完成部署后，向导师或上级交付以下内容：

1. 

   **硬件信息截图**：`lspci | grep ascend`

2. 

   **驱动状态截图**：`npu-smi info`

3. 

   **版本记录**：

   - 

     OS: Ubuntu 22.04 LTS

   - 

     Kernel: 5.15.0-78-generic

   - 

     Firmware: 25.5.1

   - 

     Driver: 25.5.1

4. 

   **部署文档**：本文档链接或本地 Markdown 文件。

------

## 八、 后续步骤（K8s 集成）

驱动部署只是第一步，接下来你需要：

1. 

   安装 **CANN Toolkit**（提供算子库）。

2. 

   安装 **NVIDIA Container Toolkit** 或 **Ascend Docker Runtime**（让容器能调用 NPU）。

3. 

   在 K8s 中部署 **Ascend Device Plugin**，使 Kubelet 能感知 NPU 资源。

4. 

   提交测试 Job，验证 `resources: limits: huawei.com/Ascend910: 1`调度成功。

🎉 **至此，NPU 物理机部署全流程结束！**