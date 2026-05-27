# 🚀 GitHub 新手入门全流程（从0到1，手把手保姆级教程）【2026修正版】

全程分为 **5大核心阶段**，从注册账号到第一次提交PR，每一步都有明确操作+避坑指南，新手零门槛也能走通。

---

## 阶段1：账号注册与基础配置（必做第一步）

### 1. 注册 GitHub 账号
1. 打开 [GitHub官网](https://github.com/)，点击右上角 `Sign up`；
2. 按提示填写：邮箱（推荐常用邮箱）、密码、用户名（就是你的 GitHub ID，全局唯一）；
3. 验证邮箱：GitHub 会给你发一封验证邮件，点击邮件里的链接激活账号；
4. 完成人机验证、新手问卷，即可进入 GitHub 主页。

### 2. 基础安全配置（必做，防账号被盗）
1. 点击右上角头像 → 选择 `Settings`（设置）；
2. 开启**双重验证（2FA）**：
   - 左侧菜单找到 `Password and authentication`；
   - 找到 `Two-factor authentication`，点击 `Enable two-factor authentication`；
   - 推荐用「Authenticator App」（手机端 Google Authenticator / 微软验证器），按提示绑定；
   - **保存好生成的恢复码**，防止手机丢失无法登录。
3. 完善个人信息：在 `Public profile` 里填写简介、头像，方便别人认识你。

### 3. 安装 Git 工具（本地操作必备）
GitHub 基于 Git 版本控制，本地操作必须先装 Git：
1. 下载地址：[Git官网](https://git-scm.com/downloads)，对应你的系统（Windows/Mac/Linux）；
2. 安装时全程默认下一步即可，新手不用改配置；
3. 安装完成后，打开终端（Windows 用 Git Bash 或 CMD），配置你的身份（**用户名和邮箱会记录在你的每次提交中，建议与 GitHub 保持一致，但不是强制**）：
   ```bash
   # 配置用户名（推荐和 GitHub 用户名一致）
   git config --global user.name "你的GitHub用户名"
   # 配置邮箱（必须用 GitHub 注册邮箱，否则提交不会关联到你的账号）
   git config --global user.email "你的GitHub注册邮箱"
   ```
4. 验证配置：输入 `git config --list`，能看到刚才配置的信息，说明成功。

> 💡 **小提示**：`--global` 表示全局配置，适用于这台电脑上的所有 Git 仓库。你也可以在某个仓库内去掉 `--global` 单独配置。

---

## 阶段2：GitHub 基础操作（对应上一页的按钮功能）

### 1. 第一次访问仓库，基础互动
打开任意 GitHub 仓库页面，先搞懂这几个高频操作：

| 操作 | 按钮 | 新手场景用法 |
| :--- | :--- | :--- |
| 收藏仓库 | ⭐ Star | 看到有用的项目，点 Star 收藏，在个人主页 `Your stars` 里就能快速找到 |
| 关注仓库 | 👁️ Watch | 想第一时间收到项目更新、Bug 通知，点 Watch，选择「All Activity」即可 |
| 固定仓库 | 📌 Pin | 把常用仓库 Pin 到个人主页，别人访问你的主页就能看到你关注的项目 |
| 下载代码 | 绿色「Code」按钮 | 想把代码存到本地，点 Code → 选择「Download ZIP」，直接下载压缩包，不用 Git 也能看 |

### 2. 仓库核心页面快速上手
| 页面 | 作用 | 新手必看场景 |
| :--- | :--- | :--- |
| Code | 代码主页 | 浏览项目的所有文件、目录，看代码内容 |
| Issues | 问题反馈 | 用项目遇到 Bug、想提新功能，点这里提交；也能看别人的问题找解决方案 |
| Pull requests | 代码合并 | 想给项目贡献代码，最终要通过这里提交申请 |
| About | 项目简介 | 第一次进仓库，先看这里，快速了解项目是干啥的、怎么用 |

---

## 阶段3：核心操作1 → Fork 仓库 + 拉取到本地

这是**给开源项目贡献代码的第一步**，也是新手最常用的操作。

### ⚠️ 重要前置：GitHub 已禁用密码登录
**从 2021 年 8 月起，GitHub 不再支持使用账号密码进行 Git 操作**（如 `git clone`、`git push`）。  
你需要改用 **Personal Access Token（个人访问令牌）** 作为密码。

#### 如何生成 Personal Access Token？
1. 登录 GitHub → 右上角头像 → **Settings**；
2. 左下角找到 **Developer settings** → **Personal access tokens** → **Tokens (classic)**；
3. 点击 **Generate new token (classic)**；
4. 给 token 起一个名字（如 `my-token-for-git`），过期时间建议选 `90 days` 或 `No expiration`（新手期）；
5. 在权限（Scopes）中勾选 `repo`（完全控制私有仓库）和 `workflow`（可选）；
6. 滚动到底部，点击 **Generate token**；
7. **立刻复制并保存这个 token**（只显示一次，丢失后只能重新生成）。

> 🔐 使用方式：在执行 `git clone` 或 `git push` 时，命令行提示输入 `Username` 填你的 **GitHub 用户名**，提示 `Password` 时**粘贴这个 token**（不会显示任何字符，直接粘贴后按回车）。

---

### 1. Fork 目标仓库
1. 打开你想修改/贡献的仓库页面（比如 `octocat/Hello-World` 官方示例仓库）；
2. 点击页面右上角的 `Fork` 按钮；
3. 在弹出的窗口里，确认 Fork 到你自己的账号下，点击 `Create fork`；
4. 等待几秒，页面会跳转到**你账号下的副本仓库**，此时这个仓库的代码和原项目完全一致，你可以随便修改，不会影响原项目。

### 2. 把 Fork 后的仓库克隆到本地
1. 打开你账号下的 Fork 仓库页面，点击绿色的 `Code` 按钮；
2. 复制 **HTTPS 链接**（新手推荐 HTTPS，配合 token 使用）；
3. 打开本地终端 / CMD，进入你想存放代码的文件夹（比如 `D:\GitHub`）；
4. 执行克隆命令（**第一次会要求输入用户名和 token**）：
   ```bash
   # 把下面的链接换成你复制的 HTTPS 链接
   git clone https://github.com/你的用户名/仓库名.git
   ```
5. 等待克隆完成，本地文件夹里就会出现和 GitHub 上完全一致的代码文件。

### 3. 配置上游仓库（关键！防止代码过时）
原项目会持续更新代码，你 Fork 的副本如果不配置上游，会慢慢和原项目脱节：
1. 进入本地克隆的仓库文件夹，右键打开终端；
2. 执行命令，关联原项目（上游仓库）：
   ```bash
   # 格式：git remote add upstream 原项目仓库的 HTTPS 链接
   git remote add upstream https://github.com/原作者用户名/原仓库名.git
   ```
3. 验证配置：输入 `git remote -v`，能看到 `origin`（你的副本仓库）和 `upstream`（原项目仓库）两个地址，说明成功。

### 4. 同步原项目的最新代码
原项目更新后，你可以把最新代码同步到自己的副本：
```bash
# 1. 拉取原项目的最新代码（包括所有分支）
git fetch upstream

# 2. 切换到本地 main 分支（也可能是 master，用 git branch -r 查看上游默认分支名）
git checkout main

# 3. 把原项目的 main 分支代码合并到本地 main
git merge upstream/main

# 4. 把合并后的代码推送到你 GitHub 的副本仓库（会要求输入用户名和 token）
git push origin main
```
> 💡 如果上游默认分支叫 `master`，请把上面的 `main` 换成 `master`。可以用 `git branch -r` 查看远程分支名称。

---

## 阶段4：核心操作2 → 修改代码 + 提交到 GitHub

### 1. 创建开发分支（新手必遵守！）
**绝对不要直接在 main 分支修改代码**，main 分支是稳定版本，所有修改都要在新分支做：
1. 进入本地仓库文件夹，打开终端；
2. 拉取最新代码，保证本地 main 是最新的：
   ```bash
   git checkout main
   git pull upstream main
   ```
3. 创建并切换到新分支（分支名要见名知意，比如 `fix-typo`、`add-new-feature`）：
   ```bash
   # 格式：git checkout -b 分支名
   git checkout -b fix-typo-in-readme
   ```
4. 验证分支：输入 `git branch`，前面带 `*` 的就是你当前所在的分支。

### 2. 修改代码 + 提交
1. 用你熟悉的编辑器（VS Code、记事本等）修改本地文件，比如修改 README.md 里的文字；
2. 终端输入命令，查看哪些文件被修改了：
   ```bash
   git status
   ```
   红色的就是被修改的文件。
3. 把修改的文件加入暂存区：
   ```bash
   # 单个文件：git add 文件名
   # 所有修改的文件：git add .  （注意：会添加所有改动，包括临时文件，建议先用 git status 检查）
   git add README.md
   ```
4. 提交修改，写清晰的提交说明（告诉别人你改了啥）：
   ```bash
   # 格式：git commit -m "提交说明，一句话说清修改内容"
   git commit -m "Fix typo in README.md"
   ```

> 📌 **提交说明最佳实践**：不要写 `update`、`fix bug` 这种模糊的话。推荐格式：`<类型>: <简短描述>`，例如 `docs: fix typo in README`。

### 3. 把本地分支推送到 GitHub
1. 执行推送命令，把本地分支推送到你 GitHub 的副本仓库（会要求输入用户名和 token）：
   ```bash
   # 格式：git push origin 分支名
   git push origin fix-typo-in-readme
   ```
2. 推送成功后，刷新你的 GitHub 仓库页面，会看到页面顶部出现一个提示：`Compare & pull request`，说明推送成功。

---

## 阶段5：核心操作3 → 提交 Pull Request（PR）给原项目

这是**给开源项目贡献代码的最后一步**，也是 GitHub 协作的核心。

### 1. 创建 PR
1. 推送成功后，在 GitHub 仓库页面，点击顶部的 `Compare & pull request` 按钮；
2. 进入 PR 创建页面，确认信息：
   - `base repository`：要合并到哪个仓库（默认是原项目仓库）；
   - `base`：要合并到原项目的哪个分支（默认是 main 或 master）；
   - `head repository`：你的副本仓库；
   - `compare`：你刚才创建的开发分支；
3. 填写 PR 标题和详细描述：
   - 标题：一句话说清修改内容（比如 `Fix typo in README.md`）；
   - 描述：详细说明你改了什么、为什么改、解决了什么问题，方便维护者审核；
4. 确认信息无误，点击 `Create pull request`。

### 2. PR 审核与后续操作
1. PR 提交后，原项目的维护者会收到通知，对你的代码进行审核；
2. 审核过程中，维护者可能会给你提修改意见，你需要：
   - 在本地对应分支继续修改代码；
   - 重新执行 `git add` → `git commit` → `git push` 命令（**不需要新建 PR**，推送后 PR 会自动更新）；
3. 审核通过后，维护者会点击 `Merge pull request`，你的代码就成功合并到原项目里了！
4. **合并完成后，建议删除自己的开发分支**（本地和远程）：
   ```bash
   # 删除本地分支
   git branch -d fix-typo-in-readme
   # 删除远程分支（在 GitHub 上的副本仓库中）
   git push origin --delete fix-typo-in-readme
   ```

---

## 新手避坑指南（90% 的新手都会踩的坑）

1. ❌ **绝对不要直接在 main 分支修改代码**，一定要新建开发分支；
2. ❌ 提交 PR 前，一定要先同步原项目的最新代码，避免冲突；
3. ❌ **提交说明不要写 `update`、`fix bug` 这种模糊的话**，要写清楚改了什么；
4. ❌ Fork 后忘记配置上游仓库，导致副本代码和原项目脱节；
5. ❌ **误以为 HTTPS 克隆要用 GitHub 密码** —— 必须用 **Personal Access Token**；
6. ✅ **遇到冲突不用慌**：先同步原项目代码（`git fetch upstream` → `git merge upstream/main`），在本地解决冲突（`git status` 查看冲突文件 → 手动编辑 → `git add` → `git commit`），重新推送即可；
7. ✅ 多利用 Issues：有问题先搜有没有人提过，不要重复提问；
8. ✅ 本地开发前建议添加 `.gitignore` 文件，排除临时文件、编译产物、依赖包等，避免误提交。

---

## 进阶拓展（入门后可以学这些）

1. **配置 SSH 密钥**：一次配置，永久免密（替代 HTTPS + token），更安全高效；
2. **学习 Git 基础命令**：
   - `git log --oneline` 查看提交历史
   - `git revert <commit>` 回滚某次提交（生成新的反向提交）
   - `git stash` 暂存当前未提交的修改
3. **GitHub Actions**：自动化 CI/CD，代码提交后自动跑测试、构建、部署；
4. **GitHub Pages**：免费托管静态网站，搭建个人博客；
5. **保护分支规则**：在仓库 Settings → Branches 中设置，防止直接 push 到 main。

---

## 🧰 Git 常用命令速查表（新手专用）

| 场景 | 命令 |
|------|------|
| 配置用户名 | `git config --global user.name "你的名字"` |
| 配置邮箱 | `git config --global user.email "你的邮箱"` |
| 克隆仓库 | `git clone <仓库链接>` |
| 查看状态 | `git status` |
| 添加文件到暂存区 | `git add <文件名>` 或 `git add .` |
| 提交 | `git commit -m "说明"` |
| 推送 | `git push origin <分支名>` |
| 拉取远程更新 | `git pull` |
| 查看分支 | `git branch` |
| 创建并切换分支 | `git checkout -b <新分支名>` |
| 切换分支 | `git checkout <分支名>` |
| 删除本地分支 | `git branch -d <分支名>` |
| 删除远程分支 | `git push origin --delete <分支名>` |
| 查看远程仓库 | `git remote -v` |
| 添加上游仓库 | `git remote add upstream <链接>` |
| 合并上游分支 | `git merge upstream/main` |

---

现在你可以按照这份完整教程，从零开始走通 GitHub + Git 的完整协作流程。如果在某个步骤遇到具体报错，可以带着报错信息继续提问。
