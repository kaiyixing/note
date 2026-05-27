---
title: GitHub 仓库创建与本地关联
tags:
  - 工具/github
  - 工具/git
---

# 📦 GitHub 仓库创建与本地关联（从新建到日常提交）

---

## 场景说明

你在本地写了一个项目，或者想要开始一个新项目，需要：
1. 在 GitHub 上创建一个仓库（repository）来存代码
2. 关联到本地，后续可以随时 `add → commit → push`

有两种流程，**二选一**，看你的习惯：

---

## 流程一：先在 GitHub 建仓库，再克隆到本地（推荐新手）

### Step 1：GitHub 上创建仓库

1. 登录 GitHub，点击右上角 `+` → **New repository**
2. 填写仓库信息：
   - **Repository name**：仓库名（如 `my-blog`、`todo-app`），必填，建议英文短横线命名
   - **Description**（可选）：一句话描述项目
   - **Public / Private**：Public 所有人可见，Private 仅自己和协作者可见
   - **✅ 勾选 `Add a README file`**（新手建议勾上，仓库建好就有文件）
   - **✅ 勾选 `Add .gitignore`**：选择项目语言模板（如 Node、Python），自动排除不必要的文件
3. 点击 **Create repository**

### Step 2：克隆到本地

仓库创建后，进入仓库页面，点击绿色 `Code` 按钮，复制 HTTPS 或 SSH 链接：

```bash
# HTTPS 方式（配合 Personal Access Token 使用）
git clone https://github.com/你的用户名/仓库名.git

# SSH 方式（需先配置 SSH Key，推荐，一次配置永久免密）
git clone git@github.com:你的用户名/仓库名.git
```

### Step 3：进入目录，开始开发

```bash
cd 仓库名
# 此时本地已关联远程，可以直接进行日常提交
```

### Step 4：日常提交流程

```bash
# 1. 查看当前修改状态（红色 = 未跟踪/修改，绿色 = 已暂存）
git status

# 2. 添加修改到暂存区
git add 文件名        # 添加指定文件
git add .             # 添加所有修改（慎用，先 git status 确认）

# 3. 提交到本地仓库
git commit -m "feat: 添加了某某功能"

# 4. 推送到 GitHub
git push
```

> ✅ 因为是用 `git clone` 下载的，远程已默认关联到 `origin`，`git push` 直接推送即可。

---

## 流程二：本地已有项目，推送到新建的 GitHub 仓库

适用于：你已经在本地写了代码，现在想把代码放到 GitHub 上。

### Step 1：GitHub 上创建**空**仓库

1. 点击 `+` → **New repository**
2. 填写仓库名
3. **❌ 不要勾选任何初始化选项**（不勾 README、.gitignore、license）
4. 点击 **Create repository**

创建后会跳转到一个页面，显示两套命令，我们选「…or push an existing repository from the command line」。

### Step 2：本地项目关联远程仓库

在本地项目文件夹下打开终端：

```bash
# 1. 如果本地还没初始化 Git
git init

# 2. 添加远程仓库（仓库地址替换成你自己的）
git remote add origin https://github.com/你的用户名/仓库名.git
# 或 SSH：
# git remote add origin git@github.com:你的用户名/仓库名.git

# 3. 验证关联成功
git remote -v
# 输出示例：
# origin  https://github.com/你的用户名/仓库名.git (fetch)
# origin  https://github.com/你的用户名/仓库名.git (push)
```

### Step 3：首次推送

```bash
# 4. 添加文件到暂存区
git add .

# 5. 提交到本地仓库
git commit -m "feat: initial commit"

# 6. 首次推送到远程（-u 建立本地 main 与远程 origin/main 的追踪关系）
git push -u origin main
```

> ⚠️ 如果你本地的默认分支是 `master`，而 GitHub 默认分支是 `main`，推送前可以统一：
> ```bash
> git branch -m main          # 将本地 master 重命名为 main
> ```

---

## 日常提交速查

仓库关联好后，每天的工作就是「三连」：

```bash
git add .
git commit -m "feat: 做了什么事"
git push
```

如果提示 `git pull` 先拉取（多人协作时远程有更新）：

```bash
git pull              # 拉取远程最新代码并合并
# 如有冲突 → 手动解决 → git add → git commit → git push
```

---

## 两种流程对比

| 场景 | 推荐流程 | 原因 |
|------|----------|------|
| 全新项目，还没写代码 | 流程一（先建仓库再 clone） | 简单，GitHub 帮你初始化好 README 和 .gitignore |
| 本地已经写了代码 | 流程二（本地已有项目 push） | 不用重新克隆，直接关联 |
| 新手第一次操作 | 流程一 | 不容易出错 |

---

## 常见问题

### Q：推送时提示 `remote origin already exists`
说明已经关联过远程仓库，可以先修改：

```bash
git remote set-url origin https://github.com/你的用户名/新仓库名.git
```

### Q：推送被拒绝 `non-fast-forward`
远程有本地没有的提交，先拉取再推送：

```bash
git pull --rebase origin main
git push
```

### Q：如何更换远程仓库地址

```bash
git remote remove origin
git remote add origin 新仓库地址
```

---

## 相关笔记

- [[基础工具/Git/git基础操作|Git 常用命令速查指南]] — Git 本地命令详解
- [[基础工具/Git/GitHub新手入门全流程|GitHub 新手入门全流程]] — Fork、PR、开源贡献完整流程
- [[容器与编排/Kubernetes/CI-CD与集成/CI-CD集成详解|CI/CD 集成详解]] — 推送代码后自动构建部署
