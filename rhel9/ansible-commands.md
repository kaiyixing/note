# Ansible 常用命令速查

> RHCE / EX294 演示 & 备考 · 三节点集群

---

## 连通与信息

```bash
ansible web -m ping                                # 测 SSH 连通
ansible web -m setup -a "filter=ansible_os_family" # 看系统事实
ansible all --list-hosts                           # 看清单里有哪些主机
```

## Ad-Hoc 临时操作

```bash
ansible web -m command -a "uptime"                            # 跑命令
ansible web -m dnf -a "name=vim-enhanced state=present"       # 装包
ansible web -m service -a "name=httpd state=started enabled=yes"  # 管服务
ansible web -m debug -a "var=ansible_hostname"                # 打印变量
```

## Playbook 执行

```bash
ansible-playbook playbooks/site.yml               # 执行
ansible-playbook playbooks/site.yml --check       # 干跑（预检查）
ansible-playbook playbooks/site.yml --syntax-check  # 语法检查
ansible-playbook playbooks/site.yml --limit node01  # 只跑一台
ansible-playbook playbooks/site.yml -e "site_title=Hello"  # 覆盖变量
```

## Role 管理

```bash
ansible-galaxy init roles/webserver   # 生成 role 骨架
tree roles/webserver                  # 看目录结构
ansible-galaxy list                   # 看已装的 role
```
