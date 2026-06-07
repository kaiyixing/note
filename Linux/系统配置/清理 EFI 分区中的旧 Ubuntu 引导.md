---
title: 清理 EFI 分区中的旧 Ubuntu 引导（完整指南）
tags:
  - Linux/安装
  - Windows
  - 引导
---

# 清理 EFI 分区中的旧 Ubuntu 引导

删除双系统中的 Ubuntu 分区后，EFI 分区里的 Ubuntu 引导文件还在。不清也能装（新系统会覆盖），但清一下更干净，避免 EFI 分区里留孤儿文件。

> 📎 **相关笔记：** [[Windows 笔记本安装 Ubuntu 双系统]] · [[Linux 故障排查实操指南（详细步骤）]]

---

## 背景知识

### EFI 分区是什么

- EFI 分区（ESP, EFI System Partition）是一个 **FAT32 格式** 的小分区（通常 100MB~500MB）
- 它存放操作系统的引导加载程序（bootloader）
- Windows、Ubuntu 的引导文件都放在这里，各自一个文件夹
- 结构大概这样：

```
Z:\EFI\
├── Microsoft\       ← Windows 引导
│   ├── Boot\
│   └── Recovery\
├── ubuntu\          ← Ubuntu 引导（要删的就是这个）
│   ├── grubx64.efi
│   ├── shimx64.efi
│   └── ...
└── Boot\            ← 启动管理器
```

### 为什么只看不到 C 盘，但能看到 EFI 分区？

EFI 分区在 Windows 磁盘管理里能看到（FAT32，几百 MB），但默认**没有盘符**，所以在"此电脑"里看不到。需要用工具给它分配一个临时盘符才能访问。

---

## 方法一：mountvol（推荐，最简单）

### 完整步骤

**管理员运行 CMD（命令提示符）**，逐条执行：

```cmd
:: 第 1 步：挂载 EFI 分区到 Z 盘
mountvol Z: /s

:: 第 2 步：确认 EFI 目录结构（可选，看一眼放心）
dir Z:\EFI\

:: 第 3 步：删掉 Ubuntu 引导文件夹
rmdir /s Z:\EFI\ubuntu

:: 第 4 步：卸载 EFI 分区（Z 盘消失）
mountvol Z: /d
```

### ⚠️ 常见误区

| 误区 | 正确做法 |
|------|---------|
| 在 PowerShell 里执行 `mountvol Z: /s` | 用 **CMD（命令提示符）**，不是 PowerShell。PowerShell 可能把 `/s` 当成路径参数解析出错 |
| 没以管理员身份运行 | 右键 → **以管理员身份运行**，否则 `mountvol /s` 会拒绝访问 |
| 认为 `/s` 是某个文件路径 | `/s` 是 `mountvol` 的**参数**，意思是挂载系统分区，不是路径 |
| 在 diskpart 里执行 `rmdir` | `rmdir` 是 CMD 的命令。如果在 diskpart 里看到一堆帮助信息，说明跑错了地方，先打 `exit` 退出来 |

### 各命令做了什么

```
mountvol Z: /s
  ├── mountvol    → Windows 自带的卷管理工具
  ├── Z:          → 把 EFI 分区挂载为 Z 盘（字母可换，只要没被占用）
  └── /s          → 挂载 EFI 系统分区（ESP），不加 /s 挂不了

rmdir /s Z:\EFI\ubuntu
  ├── rmdir       → 删除目录（CMD 命令。PowerShell 里用 rm -r）
  ├── /s          → 递归删除子目录和文件，不询问（等同 Linux 的 rm -rf）
  └── Z:\EFI\ubuntu → Ubuntu 引导文件夹。只删这个，不动其他

mountvol Z: /d
  ├── /d          → 删除挂载点（unmount）
  └── 效果：Z 盘消失，EFI 分区隐藏回去
```

### 一行搞定（挂载 → 查看 → 删除 → 卸载）

```cmd
mountvol Z: /s && dir Z:\EFI\ && rmdir /s Z:\EFI\ubuntu && mountvol Z: /d
```

> 每条命令用 `&&` 连接：上一条成功才执行下一条。
> 注意 `dir Z:\EFI\` 最后多了一个空格加 `&&`——不要漏。

---

## 方法二：diskpart 手动挂载（mountvol 失败时的备选）

有些机器上 `mountvol /s` 可能报错，这时用 diskpart 手动操作。

```cmd
:: 进入 diskpart
diskpart
```

进去后执行：

```diskpart
:: 列出所有磁盘
list disk

:: 选中系统盘（一般是 磁盘 0，看大小确认）
select disk 0

:: 列出分区
list partition

:: 找到类型为"系统"、大小几百 MB 的那个分区（一般是 分区 1）
select partition 1

:: 给它分配 Z 盘
assign letter=Z

:: 退出 diskpart
exit
```

回到 CMD 提示符后（不再是 `DISKPART>`），继续：

```cmd
:: 查看 EFI 目录
dir Z:\EFI\

:: 删除 Ubuntu 引导
rmdir /s Z:\EFI\ubuntu
```

然后再用 diskpart 去掉盘符：

```cmd
diskpart
select disk 0
select partition 1
remove letter=Z
exit
```

---

## 如何验证删干净了

### 方法一：命令行检查

```cmd
mountvol Z: /s
dir Z:\EFI\
```

- 有 `ubuntu` 文件夹 → 没删干净
- 没有 `ubuntu` 文件夹，只有 `Microsoft` 等 → 删干净了
- 然后卸载：

```cmd
mountvol Z: /d
```

### 方法二：图形界面

挂载后，打开 `此电脑` → Z 盘 → `EFI` 文件夹，看有没有 `ubuntu` 文件夹。

---

## 可选：也清理 BIOS 里的 Ubuntu 启动项

删掉 EFI 里的文件后，BIOS 的启动菜单里**可能还残留**一个叫 "ubuntu" 的启动项。不删不影响使用，但看着碍眼。

### 方法 A：bcdedit（推荐）

**管理员运行 CMD**：

```cmd
:: 列出所有固件启动项
bcdedit /enum firmware
```

输出里找这样的内容：

```
固件启动项
------------------
标识符                 {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}
description            ubuntu
```

记下 Ubuntu 那行的 `标识符`（花括号 + GUID），然后删：

```cmd
bcdedit /delete {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}
```

把上面那一串 GUID 替换进去，回车即可。

### 方法 B：进 BIOS 删

重启 → 按 F2/Del/F12 进 BIOS → 找 **Boot Order / Boot Priority** → 选中 "ubuntu" → 按 Delete/Remove/X 删除 → F10 保存退出。

---

## 为什么不清理也能装新 Ubuntu？

安装 Ubuntu 时，安装程序会：

1. 找到 EFI 分区
2. 在 `\EFI\` 下创建 `ubuntu` 文件夹（如果已存在就覆盖）
3. 写入新的 `.efi` 引导文件

所以旧文件会被覆盖，不影响安装。清理只是让 EFI 分区更干净，没有孤儿文件。

---

## 快速参考卡片

### 正常流程（mountvol）

```cmd
:: 管理员 CMD
mountvol Z: /s
rmdir /s Z:\EFI\ubuntu
mountvol Z: /d
```

### 备选流程（diskpart）

```cmd
:: 管理员 CMD
diskpart
  list disk
  select disk 0
  list partition
  select partition 1
  assign letter=Z
  exit
rmdir /s Z:\EFI\ubuntu
diskpart
  select disk 0
  select partition 1
  remove letter=Z
  exit
```

### 清理 BIOS 启动项

```cmd
bcdedit /enum firmware
bcdedit /delete {GUID}
```

---

## 参考

- [mountvol | Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/mountvol)
- [bcdedit | Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/bcdedit)
- [[Windows 笔记本安装 Ubuntu 双系统]]
