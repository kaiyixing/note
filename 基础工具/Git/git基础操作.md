---
title: Git 常用命令速查指南
tags:
  - 工具/git
---

以下是 **Git 常用命令速查指南**（基于 Git 2.23+，兼顾通用性），按使用场景分类整理，附关键说明与安全提示：

------

### 🔧 一、配置与初始化

```bash
git config --global user.name "Your Name"      # 配置用户名
git config --global user.email "email@example.com" # 配置邮箱
git config --global init.defaultBranch main    # 设置默认分支名为 main（Git 2.28+）
git config --global core.editor "code --wait"  # 设置默认编辑器（以 VS Code 为例）
git config --global credential.helper store    # 缓存凭据，避免每次 push 输密码
git config --list                              # 查看所有配置
git init                                       # 初始化本地仓库
git clone <仓库URL>                            # 克隆远程仓库（含历史）
```

------

### 🔍 二、状态与日志

```bash
git status                                     # 查看工作区/暂存区状态
git log --oneline --graph --all                # 简洁图形化提交历史
git diff                                       # 比较工作区与暂存区差异
git diff --staged                              # 比较暂存区与最新提交差异
git reflog                                     # 查看HEAD操作记录（救命命令！误删可恢复）
```

------

### 📤 三、提交流程（核心工作流）

```bash
git add <文件> / . / -A                        # 添加修改到暂存区（. = 当前目录，-A = 所有变更）
git restore --staged <文件>                    # 从暂存区撤回（Git 2.23+，替代 git reset HEAD）
git commit -m "feat: 简洁描述"                 # 提交（建议遵循提交规范）
git commit --amend                             # 修正最后一次提交（未推送时安全）
```

------

### 🌿 四、分支与切换

```bash
git branch                                     # 列出本地分支（* 表示当前分支）
git branch -d <分支名>                         # 安全删除已合并分支
git switch <分支名>                            # 切换分支（Git 2.23+ 推荐）
git switch -c <新分支名>                       # 创建并切换新分支
# 兼容旧版：git checkout <分支> / git checkout -b <新分支>
git merge <分支>                               # 合并分支（产生合并提交）
git rebase <目标分支>                          # 变基（整理提交历史，慎用于共享分支！）
```

------

### 🌐 五、远程协作

```bash
git remote -v                                  # 查看远程仓库地址
git fetch origin                               # 拉取远程更新（不自动合并）
git pull origin main                           # 拉取并合并（= fetch + merge）
git pull --rebase origin main                  # 拉取时变基（避免多余合并提交）
git push origin <分支>                         # 推送本地提交
git push -u origin <分支>                      # 首次推送并关联上游分支
```

------

### ⚠️ 六、撤销与恢复（重点！）

| 命令                       | 作用                    | 安全提示                     |
| -------------------------- | ----------------------- | ---------------------------- |
| `git restore <文件>`       | 丢弃工作区修改          | 未暂存内容将丢失             |
| `git reset --soft HEAD~1`  | 撤回提交，保留暂存区    | 安全（仅限本地未推送提交）   |
| `git reset --mixed HEAD~1` | 撤回提交+暂存区（默认） | 慎用                         |
| `git reset --hard HEAD~1`  | 彻底回退（含工作区）    | **危险！未提交内容永久丢失** |
| `git revert <commit-id>`   | 新增"反向提交"撤销更改  | **安全！适用于已推送提交**   |

------

### 🧰 七、其他高频命令

```bash
git tag -a v1.0.0 -m "Release v1.0.0"          # 创建附注标签（推荐）
git stash                                      # 临时保存工作区修改
git stash push -u                              # 临时保存（连带未跟踪文件）
git stash list / apply / drop / pop            # 管理暂存列表
git clean -fd                                  # 删除未跟踪文件（先用 -n 预览！）
git cherry-pick <commit-id>                    # 将指定提交应用到当前分支
git branch -a                                  # 查看所有分支（含远程分支）
git fetch --prune                              # 拉取并清理已删除的远程分支记录
git merge --no-ff <分支>                       # 合并并强制生成合并提交
git push --force-with-lease <远程> <分支>      # 安全强制推送（替代 -f）
# bisect 二分法定位 bug（完整流程）：
#   git bisect start     → 开始
#   git bisect bad       → 标记当前提交有问题
#   git bisect good <ID> → 标记某历史提交没问题
#   测试后反复标记 bad/good → 定位首个有问题的提交
#   git bisect reset     → 结束 bisect
```

------

### 💡 实用建议

1. **提交信息规范**：`类型(模块): 描述`（如 `fix(auth): 修复登录超时`），推荐参考 [Conventional Commits](https://www.conventionalcommits.org/)
2. **.gitignore**：提前配置忽略文件（如 node_modules/、.env）
3. **误操作恢复**：
   `git reflog` → 找到丢失的 commit ID → `git reset --hard <ID>`
4. **帮助命令**：
   `git help <命令>` 或 `git <命令> --help`（如 `git commit --help`）
5. **学习资源**：
   📚 《Pro Git》中文版（免费在线）｜ 🌐 https://git-scm.com/book/zh/v2
6. **Git 与 CI/CD**：Git 是 [[容器与编排/Kubernetes/CI-CD与集成/CI-CD集成详解|CI/CD 管道]] 的版本控制基础，代码提交自动触发构建、测试与部署流程。

> ✅ **安全第一**：对 `reset --hard`、`clean`、`push -f` 等危险操作，务必先确认影响范围！需要用 `push -f` 时优先用 `push --force-with-lease`，后者会检查远端是否有新提交，更安全。
> 💬 遇到具体问题（如"如何回退已推送的提交？"），欢迎补充细节，我会提供针对性方案！ 😊

假设你要创建一个名为 `my-website` 的项目。

### **💻 完整命令流（含注释）**

```
# 1. 【本地】创建项目文件夹并进入
mkdir my-website
cd my-website

# 2. 【本地】初始化 Git 仓库（此时生成 .git 隐藏文件夹）
git init

# 3. 【本地】做一些配置（如果是第一次使用）
git config user.name "Your Name"
git config user.email "your.email@example.com"

# 4. 【本地】创建一个文件（模拟写代码）
echo "# My Website" > README.md
# 此时 git status 会显示 README.md 是红色的（未跟踪）

# 5. 【本地】将文件加入暂存区
git add README.md
# 此时 git status 会显示 README.md 是绿色的（已暂存）

# 6. 【本地】提交到本地仓库
git commit -m "feat: init project, add README"

# 7. 【远程】此时你应该去 GitHub/GitLab 创建一个空仓库
#     假设仓库地址是：https://github.com/yourname/my-website.git
#     注意：不要勾选"Initialize this repository with a README" (因为我们本地已经有了)

# 8. 【本地】关联远程仓库，并把远程仓库命名为 'origin'
#     （两种方式二选一，把 URL 换成你自己的）
# HTTPS 方式：
#   git remote add origin https://github.com/yourname/my-website.git
# SSH 方式（推荐，需先配置 SSH Key）：
#   1. ssh-keygen -t ed25519 -C "your.email@example.com"
#   2. 将 ~/.ssh/id_ed25519.pub 添加到 GitHub/GitLab 的 SSH Keys 中
git remote add origin git@github.com:yourname/my-website.git


# 9. 【验证】查看一下是否关联成功
git remote -v
# 输出应该长这样：
# origin  https://github.com/yourname/my-website.git (fetch)
# origin  https://github.com/yourname/my-website.git (push)

# 10. 【首次推送】把本地代码推送到远程
#     -u 参数很重要：它把本地的 main 分支和远程的 origin/main 分支“绑”在了一起
git push -u origin main

# 11. 【后续操作】以后再推送就非常简单了，不需要再写 origin 和 main
#     只需执行（Git 会自动知道推送到哪里）：
git add .
git commit -m "chore: update something"
git push

# 12. 【后续操作】拉取更新（如果别人改了代码，或者你在别处改了）
git pull

## 相关笔记

- [[容器与编排/Docker/Compose进阶/Docker vs Docker Compose|Docker vs Docker Compose]] — Docker 项目中 Git 作为版本控制基础
- [[容器与编排/Kubernetes/CI-CD与集成/CI-CD集成详解|CI/CD 集成详解]] — Git 是 CI/CD 管道的版本控制核心
- [[面试准备/面经/面试问答|面试问答]] — Git 相关面试问题
- [[面试准备/面经/大厂运维运维开发面试高频知识点总结|面试高频知识点总结]] — 运维开发岗位中 Git 知识考察
```