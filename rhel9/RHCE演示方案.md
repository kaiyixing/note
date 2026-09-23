# RHCE 演示方案：实操 + PPT 结合

> 面向面试 / 培训机构 · 三节点集群（master 控制 + node01/node02 受管）
> 总时长约 50-55 分钟 · 基于 Rocky Linux 9.8 minimal + Ansible

---

## 基本信息

| 项目 | 内容 |
|---|---|
| 主线逻辑 | "标准目录 → 连通 → Playbook → Role" 逐步升级 |
| PPT | 17 页精简版（飞书 Slides 在线版 + 本地 pptx） |
| 实操项目 | `rhce-demo/`（ansible.cfg · inventories · playbooks · roles/webserver） |
| 一句话主线 | **"同一套代码，两台主机，可重复执行"** |
| 贯穿悬念 | 同一份代码跑两遍，第二遍的结果会不一样吗？ |

---

## 演示时间轴

### 01 · 开场立题（3 分钟 · 讲）

**对应 PPT**：封面

**讲什么**：
- 一句话讲清背景："今天用三台真实主机演示 RHCE/EX294 的核心——Ansible 自动化运维"
- 亮出环境：控制节点 master、受管节点 node01/node02，Rocky Linux 9.8
- 抛出贯穿全场的悬念：**"同一份代码跑两遍，第二遍的结果会不一样吗？"**

**关键句**：
> "RHCE 考的不是命令，是把重复劳动变成可复用的代码。"

---

### 02 · RHCE 认证 + 目录总览（5 分钟 · 讲）

**对应 PPT**：第 2-3 页

**讲什么**：
- 按 PPT 第 2 页目录交代知识地图，强调本场只讲 Ansible 主线 + 服务部署
- 第 3 页点出 EX294 定位：**"全程上机、按完成度评分、重启后依然生效才算得分"**
- 这句话是本场演示的验收标准，后面每一步都拿它对照

---

### 03 · 实操 Demo 1 · 标准目录 + 连通性（10 分钟 · 实操）

**对应 PPT**：第 4-6 页（演示路线图 + 架构 + 环境拓扑）

**讲什么**：
- 控制节点 vs 受管节点（无代理、仅 Python3 + SSH）
- 项目标准目录的意义（inventories / playbooks / roles）

**跑什么（在 master 上）**：

```bash
# 1. 展示项目结构，对照"Ansible 标准目录结构"
cd rhce-demo
tree .

# 2. 看配置文件
cat ansible.cfg

# 3. 连通性：无代理，走 SSH
ansible all -m ping

# 4. 信息类模块 setup：采集系统事实
ansible web -m setup -a "filter=ansible_default_ipv4"
ansible web -m setup -a "filter=ansible_os_family"
```

**收尾句**：
> "受管节点上没装任何 agent，这就是 Agentless——只要有 Python3 和 SSH 就能管。"

---

### 04 · 核心模块 + Ad-Hoc（5 分钟 · 讲）

**对应 PPT**：第 7 页（核心模块与 Ad-Hoc 命令）

**讲什么**：
- 四类高频模块：
  - **文件类**：copy、template、file、lineinfile
  - **系统类**：user、service、dnf、firewalld
  - **命令类**：command、shell、script
  - **信息类**：setup（采集系统事实）
- 指出刚才已实际用过 `ping` 和 `setup`
- 拆 Ad-Hoc 命令格式：`ansible 主机组 -m 模块名 -a "参数"`

**可选现场演示**：
```bash
ansible web -m dnf -a "name=curl state=present"
```

**适用场景**：批量单次任务、快速验证、临时运维操作

---

### 05 · 实操 Demo 2 · Playbook 部署 httpd（12 分钟 · 实操）

**对应 PPT**：第 8 页（Playbook 基础语法）

**讲什么**：
- YAML 三大结构：hosts / become / tasks
- `--check` 预检查的意义（先检查再执行）
- 幂等性概念（埋下悬念）

**跑什么**：

```bash
# 1. 预检查（干跑，不落地）——体现"先检查再执行"的习惯
ansible-playbook playbooks/site.yml --check

# 2. 正式执行
# 集群防火墙保持关闭，firewalld 任务会显示 skipped
ansible-playbook playbooks/site.yml

# 3. 幂等性验证：再跑一遍，应全部 ok、0 changed
# —— 呼应开场悬念
ansible-playbook playbooks/site.yml
```

**演示亮点**：
- 输出里的 `skipping: [node0x]` 正是 `when: manage_firewall` 条件不满足的结果
- 顺势讲："这就是 when 条件判断在真实场景里的样子——不满足就跳过，不报错"

**验证**：
```bash
# 看渲染出来的页面
curl -s http://NODE01_IP/

# 确认服务状态
ansible web -m command -a "systemctl status httpd"
```

**关键句**：
> "注意看，第二次执行全是 ok、没有 changed——同一份代码跑多少遍结果一致，这就是幂等。"

---

### 06 · 变量 / 流程控制 / Roles（5 分钟 · 讲）

**对应 PPT**：第 9-10 页（变量与流程控制 + Ansible Roles）

**讲什么**：
- when / loop / facts（预告 Demo 3 会用）
- Role 标准目录结构：tasks / handlers / templates / vars / defaults / meta
- 点出"刚才部署 httpd 的代码，现在拆进角色里复用"
- defaults 与 vars 的优先级差异（defaults 最低，可被覆盖）

---

### 07 · 实操 Demo 3 · Role 复用 + 变量优先级（10 分钟 · 实操）

**对应 PPT**：第 9-10 页

**讲什么**：
- 角色即"打包好的运维脚本"
- 变量优先级：defaults < group_vars < play vars < -e 命令行

**跑什么**：

```bash
# 1. 展示 role 目录树
tree roles/webserver

# 2. when / loop / facts 演示
ansible-playbook playbooks/when-loop-demo.yml

# 3. 变量优先级：-e 覆盖 defaults，看首页标题变化
ansible-playbook playbooks/site.yml -e site_title="Override by -e"

# 4. 验证页面标题变了
curl -s http://NODE01_IP/
```

**看点**：
- when-loop-demo.yml 输出里 `(item=vim-enhanced)`、`(item=curl)` 就是 loop 在工作
- facts 变量 `ansible_os_family`、`ansible_hostname` 自动采集，不用自己定义

---

### 08 · 进阶快讲 + 收尾 Q&A（5-8 分钟 · 讲）

**对应 PPT**：第 11-17 页

**讲什么**：
- 第 11-15 页快速带过（存储 / 网络 / 安全 / 容器 / 考试指南），每页一句话给结论
- 第 16 页强调高频丢分点：
  - YAML 缩进语法错误
  - 忘记设置服务开机自启（enabled: true）
  - 忽略 SELinux 与防火墙配置
- 与本场演示的 firewalld permanent、service enabled 呼应

**收尾**：
> "今天跑的是最小闭环：目录 → 清单 → Playbook → Role。
> 考试就是把每个考点都做成这样的闭环，并保证重启后依然生效。"

进入 Q&A。

---

## 演示避坑清单

> 实操前在集群上自检一遍

### 环境准备

- [ ] **SSH 免密**：master → node01/node02 必须 `ssh-copy-id root@IP` 配好
- [ ] **受管节点 python3**：`dnf install -y python3`，缺了模块直接报错
- [ ] **Rocky 9.8 minimal**：tree / curl / vim-enhanced 需提前补装
- [ ] **inventory 换真实 IP**：把 hosts 里 NODE01_IP / NODE02_IP 替换掉

### 配置确认

- [ ] **集群防火墙保持关闭**：role 默认 `manage_firewall=false`，不动原配置
- [ ] **需演示 firewalld 时**：用 `-e manage_firewall=true` 并先自测
- [ ] **网络/镜像源**：dnf 安装需要能访问仓库，离线环境先配本地源

### 预演

- [ ] **预演两遍**：正式演示前按本方案完整跑一遍
- [ ] 确保 `--check` 干跑无报错
- [ ] 确保幂等第二遍的 "ok 无 changed" 效果稳定

---

## 话术要点

### 开场
> "RHCE 考的不是命令，是把重复劳动变成可复用的代码——下面用三台真实主机演示。"

### 幂等时刻
> "注意看，第二次执行全是 ok、没有 changed——同一份代码跑多少遍结果一致，这就是幂等。"

### 收尾
> "今天跑的是最小闭环：目录 → 清单 → Playbook → Role。考试就是把每个考点都做成这样的闭环，并保证重启后依然生效。"

---

## 常见问题预案

| 问题 | 原因 | 处理 |
|---|---|---|
| ping 不通 | SSH 免密没配 | `ssh-copy-id root@IP` 重配 |
| dnf 报错 | 没网 / 源没配 | 检查网络，配本地源 |
| httpd 起不来 | 80 端口被占 | `ss -tlnp \| grep :80` 查谁占了 |
| 显示 Rocky 默认页 | index.html 没渲染 | 检查 template dest 路径拼写 |
| firewalld 任务 skipped | `manage_firewall=false` | 这是正常的，讲 when 条件时提一下 |
| 第二遍还有 changed | 模板里有动态内容 | 检查是否每次都触发 handlers |

---

## 配套文件

- `rhce-demo/`：实操项目骨架
  - `ansible.cfg`：Ansible 配置
  - `inventories/production/hosts`：主机清单
  - `inventories/production/group_vars/web.yml`：组变量
  - `playbooks/site.yml`：主 playbook
  - `playbooks/when-loop-demo.yml`：when/loop/facts 演示
  - `roles/webserver/`：httpd 角色
- `ansible-commands.md`：常用命令速查
- PPT 在线版：飞书 Slides 链接
- PPT 本地版：`RHCE核心知识点-最新版.pptx`
