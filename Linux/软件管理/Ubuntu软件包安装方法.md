---
title: Ubuntu 软件包安装方法（deb / AppImage / Snap / Flatpak）
tags:
  - Linux/软件管理
  - Ubuntu
  - 包管理
---

# Ubuntu 软件包安装方法（deb / AppImage / Snap / Flatpak）

> 📎 **关联笔记：** [[Linux 系统核心组件配置文件速查表]] · [[Linux 故障排查实操指南（详细步骤）]] · [[Linux命令手册_第1-6章]]

---

## 一、.deb 包

Debian/Ubuntu 的标准软件包格式，类似 Windows 的 `.exe`。

### 1.1 `dpkg` 安装

```bash
# 安装
sudo dpkg -i package.deb

# 卸载
sudo dpkg -r package_name

# 查看已安装
dpkg -l | grep package_name
```

> ⚠️ `dpkg` **不会自动解决依赖**，缺依赖时会报错。此时执行：

```bash
sudo apt install -f
```

### 1.2 `apt` 安装（推荐）

```bash
# 本地 .deb 也支持
sudo apt install ./package.deb

# 自动解决依赖并安装
sudo apt install -f
```

### 1.3 Gdebi（图形化依赖解析）

```bash
sudo apt install gdebi
sudo gdebi package.deb
```

---

## 二、AppImage

免安装、免解压、单文件运行，类似 macOS 的 `.app`。

### 使用方法

```bash
# 1. 下载 .AppImage 文件
wget https://example.com/app.AppImage

# 2. 赋予执行权限
chmod +x app.AppImage

# 3. 运行
./app.AppImage
```

### 整合到系统（可选）

```bash
# 移到自定义路径
mkdir -p ~/Applications
mv app.AppImage ~/Applications/

# 或者创建桌面快捷方式
ln -s ~/Applications/app.AppImage ~/.local/share/applications/
```

> 💡 可用 **AppImageLauncher** 自动整合到系统菜单：
> ```bash
> sudo add-apt-repository ppa:appimagelauncher-team/stable
> sudo apt update && sudo apt install appimagelauncher
> ```

---

## 三、Snap（Ubuntu 默认）

Ubuntu 自带 Snap 支持。

```bash
# 查找
snap find package_name

# 安装
sudo snap install package_name

# 卸载
sudo snap remove package_name

# 更新
sudo snap refresh
```

---

## 四、Flatpak

跨发行版容器化方案。

```bash
# 安装 Flatpak
sudo apt install flatpak

# 添加 Flathub 仓库
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# 安装
flatpak install flathub org.package.Name
```

---

## 五、对比总结

| 格式 | 依赖隔离 | 沙箱 | 跨发行版 | 特点 |
|------|---------|------|---------|------|
| `.deb` | ❌ | ❌ | ❌ | 传统包格式，依赖管理需 apt |
| AppImage | ✅ | ❌ | ✅ | 单文件绿色运行，无需安装 |
| Snap | ✅ | ✅ | ✅ | Ubuntu 原生，自动更新 |
| Flatpak | ✅ | ✅ | ✅ | 专注桌面应用，沙箱隔离强 |

---

## 相關筆記

- [[Linux/系统配置/Linux 系统核心组件配置文件速查表|Linux 系统核心组件配置文件速查表]]
- [[Linux/系统排障/Linux 故障排查实操指南（详细步骤）|Linux 故障排查实操指南]]
