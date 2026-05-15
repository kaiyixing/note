**Ansible 常见模块详解**  

Ansible 的常见模块主要来自 `ansible.builtin` 集合，这些模块是编写 Playbook 时最基础且使用频率最高的组件。以下选取了 8 个最具代表性的内置模块（基于官方文档最新版本），每个模块均包含功能描述、主要参数、典型用法示例以及重要注意事项。信息来源于 Ansible 官方文档，以确保准确性和时效性。实际使用时建议参考完整文档以获取最新特性。

### 1. ansible.builtin.file 模块  
**功能**：管理文件、目录和符号链接，可设置所有权、权限、时间戳、SELinux 上下文，或创建/删除对象。  
**主要参数**：  
- `path`（必需，别名 `dest`、`name`）：目标路径。  
- `state`：`absent`（删除）、`directory`（创建目录）、`file`（文件）、`link`（符号链接）、`touch`（更新时间戳）等，默认根据对象当前状态。  
- `owner`、`group`、`mode`：所有者、组、权限（八进制需加引号，如 `'0644'`）。  
- `recurse`：目录时递归应用属性。  
- `src`：用于 `state=link` 的源路径。  

**典型示例**：  
```yaml
- name: 创建目录并递归设置权限
  ansible.builtin.file:
    path: /etc/foo
    state: directory
    recurse: yes
    owner: foo
    group: foo
    mode: '0755'
```
**注意事项**：八进制模式必须用引号避免被解释为十进制；`state=file` 不会创建新文件（需搭配 `copy` 或 `template`）；Windows 目标请使用 `ansible.windows.win_file`。

### 2. ansible.builtin.copy 模块  
**功能**：从控制节点（或远程节点）复制文件/目录到目标主机，同时设置权限、所有权和备份。  
**主要参数**：  
- `src`：源文件/目录路径（控制节点默认）。  
- `dest`（必需）：目标绝对路径。  
- `mode`、`owner`、`group`：权限与所有权。  
- `backup`：存在差异时自动备份（时间戳）。  
- `remote_src`：从远程节点复制（默认 `false`）。  
- `content`：直接指定文件内容（无需 `src`）。  

**典型示例**：  
```yaml
- name: 复制配置文件并备份
  ansible.builtin.copy:
    src: /srv/myfiles/foo.conf
    dest: /etc/foo.conf
    owner: root
    group: root
    mode: '0644'
    backup: yes
```
**注意事项**：适合静态文件；动态内容请使用 `template`；大批量文件复制效率较低；`unsafe_writes` 可能导致数据损坏，仅在必要时启用。

### 3. ansible.builtin.template 模块  
**功能**：使用 Jinja2 模板渲染动态配置文件（支持变量、循环、条件），并写入目标主机。  
**主要参数**：  
- `src`（必需）：控制节点上的 `.j2` 模板文件。  
- `dest`（必需）：目标路径。  
- `mode`、`owner`、`group`：与 `copy` 相同。  
- `backup`、`validate`：备份与校验命令（例如 `visudo -cf %s`）。  
- `newline_sequence`：换行格式（`\n` 或 `\r\n`）。  

**典型示例**：  
```yaml
- name: 渲染主机专属配置文件
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
    validate: /usr/sbin/nginx -t -c %s
```
**注意事项**：与 `copy` 的核心区别在于 Jinja2 渲染；模板中可使用 `ansible_managed` 等内置变量；Ansible 2.19+ 模板变化需检查端口指南。

### 4. ansible.builtin.service 模块  
**功能**：管理服务（启动、停止、重启、启用开机自启），自动适配 systemd、SysV、Upstart 等初始化系统。  
**主要参数**：  
- `name`（必需）：服务名称。  
- `state`：`started`、`stopped`、`restarted`、`reloaded`。  
- `enabled`：是否开机自启（`yes`/`no`）。  
- `use`：强制指定后端（默认 `auto`）。  

**典型示例**：  
```yaml
- name: 启动并启用 httpd 服务
  ansible.builtin.service:
    name: httpd
    state: started
    enabled: yes
```
**注意事项**：systemd 下部分参数（如 `args`）被忽略；推荐使用 FQCN；Windows 请使用 `win_service`。

### 5. ansible.builtin.apt 模块（Debian/Ubuntu）  
**功能**：管理 APT 软件包，支持安装、升级、移除、更新缓存。  
**主要参数**：  
- `name`（必需）：包名（支持列表、版本如 `foo=1.0`、通配符）。  
- `state`：`present`、`latest`、`absent`、`build-dep`。  
- `update_cache`、`cache_valid_time`：更新缓存（秒）。  
- `autoremove`、`purge`：移除无用依赖与配置文件。  

**典型示例**：  
```yaml
- name: 更新缓存并安装最新 nginx
  ansible.builtin.apt:
    name: nginx
    state: latest
    update_cache: yes
    cache_valid_time: 3600
```
**注意事项**：需 `python3-apt`；`force` 选项会禁用安全检查，请谨慎使用。

### 6. ansible.builtin.dnf 模块（RHEL/CentOS/Fedora）  
**功能**：使用 DNF 管理软件包（YUM 的现代替代），支持安装、升级、组安装、自动移除。  
**主要参数**：  
- `name`（必需）：包名（支持版本、URL、组如 `@Development tools`）。  
- `state`：`present`、`latest`、`absent`。  
- `update_cache`、`autoremove`、`enablerepo`。  

**典型示例**：  
```yaml
- name: 安装最新 httpd 并自动移除无用依赖
  ansible.builtin.dnf:
    name: httpd
    state: latest
    autoremove: yes
```
**注意事项**：Ansible 2.17+ 已移除 YUM 后端，请使用 `dnf` 或 `use_backend=dnf`；支持模块化（AppStream）。

### 7. ansible.builtin.user 模块  
**功能**：创建、修改或删除用户账户，支持主/辅组、Shell、主目录、密码、SSH 密钥等。  
**主要参数**：  
- `name`（必需）：用户名。  
- `state`：`present`/`absent`。  
- `group`、`groups`、`append`：主组与辅组。  
- `password`：哈希密码（Linux 必须哈希）。  
- `create_home`、`shell`、`uid`、`generate_ssh_key`。  

**典型示例**：  
```yaml
- name: 创建用户并生成 SSH 密钥
  ansible.builtin.user:
    name: johnd
    group: admin
    create_home: yes
    generate_ssh_key: yes
    ssh_key_bits: 2048
```
**注意事项**：密码必须预先哈希；`state=absent` 时 `remove=yes` 可删除主目录。

### 8. ansible.builtin.lineinfile 模块  
**功能**：精确管理文本文件中的单行内容（替换、插入、删除），常用于配置修改。  
**主要参数**：  
- `path`（必需）：文件路径。  
- `regexp`/`search_string`：匹配正则或字符串。  
- `line`：要插入/替换的内容。  
- `state`：`present`/`absent`。  
- `insertafter`/`insertbefore`、`backrefs`、`validate`、`backup`。  

**典型示例**：  
```yaml
- name: 确保 SELinux 为 enforcing
  ansible.builtin.lineinfile:
    path: /etc/selinux/config
    regexp: '^SELINUX='
    line: SELINUX=enforcing
```
**注意事项**：适合单行修改；多行请用 `blockinfile`；`validate` 可防止语法错误（如 sudoers）。

以上模块覆盖了文件管理、软件包安装、服务控制、用户配置和配置文件编辑等核心场景，是日常自动化运维的必备工具。建议结合 `ansible.builtin.command`/`shell`（执行任意命令）和 `ansible.builtin.debug`（调试）使用。如需特定模块的完整参数或版本差异，请查阅官方文档。若您有特定场景或版本需求，我可进一步提供针对性示例。