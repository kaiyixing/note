# Windows 笔记本安装 Ubuntu 双系统（AMD+英伟达只能开混合模式，不然笔记本屏幕可能会花屏，外接显示器没问题）

记录给 Windows 笔记本加装 Ubuntu 双系统的完整流程。

---

## 环境

| 项目   | 内容                           |
| ---- | ---------------------------- |
| 原系统  | Windows 10/11                |
| 目标系统 | Ubuntu 26.04 LTS / 24.04 LTS |
| 磁盘类型 | MBR 或 GPT（建议 GPT）            |
| 引导模式 | Legacy BIOS 或 UEFI（建议 UEFI）  |

---

## 一、准备工作

### 1.1 磁盘空间预留

在 Windows 中给 Ubuntu 腾出空闲分区。

```
Win + X → 磁盘管理
```

- 如果 C 盘空间充足：右键 C 盘 → **压缩卷** → 填入大小（建议至少 80GB），先不要格式化。
- 如果已有空白分区或未分配空间：直接使用
- **不删除 Windows 引导分区（ESP/MSR）**，双系统依赖它启动

> 压缩后出现一个黑色的"未分配"区域，安装 Ubuntu 时用它。

### 1.2 制作启动 U 盘

需要一个 8GB+ 的 U 盘。

**工具推荐：**

| 工具                 | 适用场景                             |
| ------------------ | -------------------------------- |
| Rufus（Windows）good | 最稳，选 **DD 模式** 写入（iso也行，感觉iso不错） |
| balenaEtcher       | 跨平台，图形化，简单                       |
| Ventoy             | 把 ISO 丢进 U 盘即可，可同时放多个 ISO        |

**推荐用 Rufus：**

```
设备 → 选 U 盘
引导类型 → 选下载的 Ubuntu ISO
分区类型 → GPT（UEFI）/ MBR（Legacy）
目标系统 → UEFI（非 CSM）
文件系统 → FAT32
点击开始 → 选择 **写入为 ISO 模式**
```

写入完毕后 U 盘会被格式化，不要拔，下一步要用。

### 1.3 关于 Secure Boot

建议在 BIOS 中 **关闭 Secure Boot**，否则可能U盘无法启动。

- 重启 → 按 ESC（蛟龙16pro）/F2/Del/F12（各品牌不同）进入 BIOS
- 找到 **Secure Boot** → 设为 **Disabled**

### 1.4 快速开机（fastboot）关了

要把这个关了，在控制面板的电源管理的系统设置。

### 1.5 关闭 BitLocker（硬盘锁）

如果电脑开启了 BitLocker（Windows 硬盘加密），装 Ubuntu 前必须先关掉，否则后面会锁盘。

**怎么关：**

```
控制面板 → 系统和安全 → BitLocker 驱动器加密 → 关闭 BitLocker
```

或在任务栏搜索框直接搜 **"管理 BitLocker"**。

点 **关闭 BitLocker** 后会开始解密，耗时取决于硬盘大小（可能几十分钟到几小时），等它解完再装系统。

> ⚠️ 不确定有没有开 BitLocker？打开文件资源管理器 → 右键 C 盘 → 如果菜单里有"管理 BitLocker"，说明开着。没开就不用管。

---

## 二、安装 Ubuntu

### 2.1 从 U 盘启动

```
插入 U 盘 → 重启 → 开机时按 F12（选启动设备）
```

- 如果没进 U 盘：检查 BIOS 中 **Boot Order**，把 U 盘调到第一，或者关闭 **Fast Boot**
- 选择 **Try or Install Ubuntu** → 等进桌面

### 2.2 进入安装程序

进 Live 桌面后，双击桌面上的 **Install Ubuntu**。

**重要步骤：**

| 步骤       | 建议                         |
| -------- | -------------------------- |
| 键盘布局     | 选 **Chinese**              |
| 联网       | 可选（不连装更快）                  |
| 更新和其他软件  | 选 **最小安装**，勾不勾"安装第三方驱动"都可以 |
| **安装类型** | ✅ **其他选项（手动分区）**           |

### 2.3 手动分区

在"安装类型"中选择"其他选项"，找到之前留的**未分配空间**，手动建分区。

**推荐分区方案（基于 80GB~256GB 空闲空间）：**

| 分区         | 大小      | 类型   | 挂载点     | 说明                          |
| ---------- | ------- | ---- | ------- | --------------------------- |
| /boot      | 1GB     | Ext4 | `/boot` | 存放内核和启动文件。不单独分也行（放 `/` 里），但分开更稳，根分区写满也不影响开机 |
| **swap**   | 内存大小    | 交换空间 | —       | 休眠用。现在内存大（16G+）可以跳过或只分 4~8G |
| **/**（根分区） | 剩余空间的大头 | Ext4 | `/`     | 系统+程序，建议 40GB+              |
| **/home**  | 剩余空间    | Ext4 | `/home` | 个人数据，可选但推荐（重装系统不清数据）        |


### 2.4 安装引导

分区完成后，确认底部的 **安装引导启动器的设备**：

- **UEFI 模式** → 选 EFI 系统分区（不是 /dev/sda，是那个 FAT32 分区）

点 **现在安装** → 选时区（Shanghai） → 设置用户名和密码 → 等安装完成。

---

## 三、重启与引导

### 3.1 首次重启

安装完成后提示重启 → 拔掉 U 盘 → 回车。

- 如果看到 **GRUB 菜单**→ 成功
- 如果直接进了 Windows → 进 BIOS → **Boot Order** 把 `Ubuntu` 或 `GRUB` 调到第一
- 如果找不到 Ubuntu 的引导项（见常见问题）

### 3.2 GRUB 引导菜单

启动时 GRUB 会列出：

```
Ubuntu
Advanced options for Ubuntu
Windows Boot Manager  ← 进 Windows 选这项
```

想改默认系统或等待时间：

```bash
sudo nano /etc/default/grub
```

改这两个值：

```
GRUB_DEFAULT=0          # 0=第一个，4=Windows 一般是第5个（从0开始数）
GRUB_TIMEOUT=5          # 等待秒数
```

改完更新 GRUB：

```bash
sudo update-grub
```

---

## 四、装完后的必做设置

### 4.1 更新系统

```bash
sudo apt update && sudo apt upgrade -y
```

### 4.2 安装显卡驱动（NVIDIA）

```bash
# 查看推荐驱动版本
ubuntu-drivers devices

# 自动安装推荐版本
sudo ubuntu-drivers autoinstall

# 或手动指定
sudo apt install nvidia-driver-595

# 装完重启
sudo reboot

# 验证
nvidia-smi
```

### 4.3 中文输入法

```bash
# 安装 fcitx5 + 中文输入法
sudo apt install fcitx5 fcitx5-chinese-addons fcitx5-pinyin

# 设置环境变量
echo "export GTK_IM_MODULE=fcitx5" >> ~/.bashrc
echo "export QT_IM_MODULE=fcitx5" >> ~/.bashrc
echo "export XMODIFIERS=@im=fcitx5" >> ~/.bashrc

# 重启后生效，在输入法设置里添加拼音
```

### 4.4 安装常用软件

```bash
# 基础工具
sudo apt install -y git curl wget htop net-tools openssh-server

# 开发工具（按需）
sudo apt install -y build-essential dkms

# 截图工具（Ubuntu 自带截屏可能不够用）
sudo apt install -y flameshot

# 压缩工具
sudo apt install -y p7zip-full unzip
```

### 4.5 清理 Windows 占用的时间（双系统时间差）

双系统时间会差 8 小时（本地时间 vs UTC）。让 Ubuntu 用本地时间：

```bash
timedatectl set-local-rtc 1 --adjust-system-clock
```

---

## 五、常见问题

### Q1：装完直接进 Windows，没有 GRUB

原因：BIOS 启动顺序还是 Windows Boot Manager 优先。

解决：

```
重启 → F2/Del 进 BIOS
找到 Boot Order / Boot Sequence
把 Ubuntu 或 ubuntu（引导项）移到第一
保存退出
```

如果 BIOS 引导列表里也没有 Ubuntu：

- 用 EasyUEFI（Windows 软件）手动添加引导项
- 或者进 Live USB 修复 GRUB（见 Q2）

### Q2：GRUB 损坏或丢失，手动修复

用 Ubuntu Live U 盘启动，进 Try Ubuntu，打开终端：

```bash
# 查看分区情况，确认根分区和 EFI 分区
sudo fdisk -l

# 挂载根分区（假设根分区是 /dev/nvme0n1p5，EFI 是 /dev/nvme0n1p1）
sudo mount /dev/nvme0n1p5 /mnt
sudo mount /dev/nvme0n1p1 /mnt/boot/efi

# 进入 chroot 环境
for i in /dev /dev/pts /proc /sys /run; do sudo mount --bind $i /mnt$i; done
sudo chroot /mnt

# 重装并更新 GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Ubuntu
update-grub

# 退出
exit
sudo reboot
```

### Q3：开机黑屏或卡在紫屏

常见原因：NVIDIA 显卡驱动问题或内核参数冲突。

解决办法：启动时在 GRUB 选中 Ubuntu 按 `e`，找到 `quiet splash` 一行，改成：

```
quiet splash nomodeset
```

然后按 F10 启动。如果能进系统，永久生效：

```bash
sudo nano /etc/default/grub
```

找到 `GRUB_CMDLINE_LINUX_DEFAULT`，改为：

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nomodeset"
```

保存后 `sudo update-grub`。

### Q4：触控板/无线网卡不工作

Ubuntu 对 Intel 无线网卡支持好，但一些 Realtek / Broadcom 网卡可能需要额外驱动。

```bash
# 查看无线网卡型号
lspci | grep -i network

# 如果是 Broadcom，装驱动
sudo apt install bcmwl-kernel-source

# 如果是 Realtek，搜对应芯片组驱动
```

触控板问题一般更新内核能解决，或者装 `libinput` 调试：

```bash
sudo apt install libinput-tools
```

### Q5：Windows 更新后 GRUB 被覆盖

Windows 大版本更新有时会覆盖 MBR/EFI 引导，导致直接进 Windows 看不到 GRUB。

用 EasyUEFI 加回 Ubuntu 引导项，或用 Live USB 修复 GRUB（见 Q2）。

---

## 六、附录：各品牌进 BIOS / 启动菜单快捷键

| 品牌 | BIOS 设置 | 启动菜单 |
|------|-----------|---------|
| 联想 | F2 | F12 |
| Dell | F2 | F12 |
| HP | F10 | F9 |
| 华硕 | F2 | Esc |
| 宏碁 | F2 | F12 |
| 华为 | F2 | F12 |
| 小米 | F2 | F12 |
| ThinkPad | Enter → F1 | F12 |

---

## 参考

- [Ubuntu 官方安装文档](https://ubuntu.com/tutorials/install-ubuntu-desktop)
- [Rufus - 启动盘制作工具](https://rufus.ie/)
- [AskUbuntu - 双系统常见问题](https://askubuntu.com/)
