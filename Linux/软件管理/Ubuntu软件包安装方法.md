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

Debian/Ubuntu 的標準軟件包格式，類似 Windows 的 `.exe`。

### 1.1 `dpkg` 安裝

```bash
# 安裝
sudo dpkg -i package.deb

# 卸載
sudo dpkg -r package_name

# 查看已安裝
dpkg -l | grep package_name
```

> ⚠️ `dpkg` **不會自動解決依賴**，缺依賴時會報錯。此時執行：

```bash
sudo apt install -f
```

### 1.2 `apt` 安裝（推薦）

```bash
# 本地 .deb 也支持
sudo apt install ./package.deb

# 自動解決依賴並安裝
sudo apt install -f
```

### 1.3 Gdebi（圖形化依賴解析）

```bash
sudo apt install gdebi
sudo gdebi package.deb
```

---

## 二、AppImage

免安裝、免解壓、單文件運行，類似 macOS 的 `.app`。

### 使用方法

```bash
# 1. 下載 .AppImage 文件
wget https://example.com/app.AppImage

# 2. 賦予執行權限
chmod +x app.AppImage

# 3. 運行
./app.AppImage
```

### 整合到系統（可選）

```bash
# 移到自定義路徑
mkdir -p ~/Applications
mv app.AppImage ~/Applications/

# 或者創建桌面快捷方式
ln -s ~/Applications/app.AppImage ~/.local/share/applications/
```

> 💡 可用 **AppImageLauncher** 自動整合到系統菜單：
> ```bash
> sudo add-apt-repository ppa:appimagelauncher-team/stable
> sudo apt update && sudo apt install appimagelauncher
> ```

---

## 三、Snap（Ubuntu 默認）

Ubuntu 自帶 Snap 支持。

```bash
# 查找
snap find package_name

# 安裝
sudo snap install package_name

# 卸載
sudo snap remove package_name

# 更新
sudo snap refresh
```

---

## 四、Flatpak

跨發行版容器化方案。

```bash
# 安裝 Flatpak
sudo apt install flatpak

# 添加 Flathub 倉庫
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# 安裝
flatpak install flathub org.package.Name
```

---

## 五、對比總結

| 格式 | 依賴隔離 | 沙箱 | 跨發行版 | 特點 |
|------|---------|------|---------|------|
| `.deb` | ❌ | ❌ | ❌ | 傳統包格式，依賴管理需 apt |
| AppImage | ✅ | ❌ | ✅ | 單文件綠色運行，無需安裝 |
| Snap | ✅ | ✅ | ✅ | Ubuntu 原生，自動更新 |
| Flatpak | ✅ | ✅ | ✅ | 專注桌面應用，沙箱隔離強 |

---

## 相關筆記

- [[Linux/系统配置/Linux 系统核心组件配置文件速查表|Linux 系统核心组件配置文件速查表]]
- [[Linux/系统排障/Linux 故障排查实操指南（详细步骤）|Linux 故障排查实操指南]]
