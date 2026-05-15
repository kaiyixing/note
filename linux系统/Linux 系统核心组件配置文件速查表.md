# Linux 系统核心组件配置文件速查表（RedHat/CentOS 系）

我把**网络、用户/组、权限、服务/进程、日志、文件系统**等高频组件都整理成表格，方便你一次性记忆。

---

## 一、网络相关（回顾版）

|配置文件路径|核心作用|关键配置项/示例|
|---|---|---|
|`/etc/sysconfig/network-scripts/ifcfg-<网卡名>`|网卡核心配置（IP/网关/开机自启）|`IPADDR=192.168.233.151`, `ONBOOT=yes`|
|`/etc/hostname`|系统主机名|`master`|
|`/etc/hosts`|本地域名-IP 映射|`192.168.233.151 master`|
|`/etc/resolv.conf`|DNS 服务器地址|`nameserver 8.8.8.8`|
|`/etc/sysctl.conf`|内核网络参数|`net.ipv4.ip_forward=1`|
---

## 二、用户与组管理

|配置文件路径|核心作用|关键内容/示例|
|---|---|---|
|`/etc/passwd`|用户账号信息|`root:x:0:0:root:/root:/bin/bash`|
|`/etc/group`|用户组信息|`root:x:0:`|
|`/etc/shadow`|用户密码（加密存储）|`root:$6$...:18990:0:99999:7:::`|
|`/etc/sudoers`|sudo 权限配置|`student ALL=(ALL) ALL`|
|`/etc/skel/`|新用户默认家目录模板|存放 `.bashrc` 等初始化文件|
---

## 三、权限与文件系统

|配置文件路径|核心作用|关键内容/示例|
|---|---|---|
|`/etc/fstab`|开机自动挂载分区|`/dev/sda1 / xfs defaults 0 0`|
|`/etc/security/limits.conf`|资源限制（打开文件数/进程数）|`* soft nofile 65535`|
|`/etc/login.defs`|用户账号默认规则（密码长度/UID范围）|`PASS_MIN_LEN 8`, `UID_MIN 1000`|
|`/etc/pam.d/*`|PAM 认证策略（密码复杂度/登录限制）|`pam_pwquality.so minlen=10`|
---

## 四、服务与进程管理

|配置文件路径|核心作用|关键内容/示例|
|---|---|---|
|`/etc/systemd/system/`|systemd 服务单元文件（自定义服务）|`nginx.service` 定义启动方式|
|`/usr/lib/systemd/system/`|系统默认服务单元文件|系统自带服务的配置模板|
|`/etc/rc.d/rc.local`|开机自启脚本（兼容传统方式）|需 `chmod +x` 后生效|
|`/proc/`|内核/进程实时信息（虚拟文件系统）|`/proc/cpuinfo`, `/proc/meminfo`|
---

## 五、日志与监控

|配置文件路径|核心作用|关键内容/示例|
|---|---|---|
|`/var/log/`|系统日志目录|`messages`, `secure`, `dmesg`|
|`/etc/rsyslog.conf`|rsyslog 日志收集规则|`*.info;mail.none;authpriv.none /var/log/messages`|
|`/etc/logrotate.conf`|日志轮转（自动切割/清理旧日志）|配置日志保留天数、大小限制|
|`/var/log/secure`|安全日志（登录/认证/权限操作）|记录 SSH 登录、sudo 操作等|
---

## 六、其他核心系统组件

|配置文件路径|核心作用|关键内容/示例|
|---|---|---|
|`/etc/shells`|合法登录 Shell 列表|`/bin/bash`, `/sbin/nologin`|
|`/etc/issue`|登录前提示信息|显示系统版本、欢迎语|
|`/etc/motd`|登录后提示信息|登录成功后显示的公告|
|`/etc/selinux/config`|SELinux 模式配置|`SELINUX=enforcing`|
---

### 快速记忆口诀

- **用户组**：`passwd`/`group`/`shadow` 管账号，`sudoers` 管权限

- **文件系统**：`fstab` 管挂载，`limits.conf` 管资源

- **服务**：`systemd` 目录管自启，`rc.local` 是兼容方案

- **日志**：`/var/log/` 看记录，`rsyslog.conf` 管收集

---

要不要我再帮你做一份**高频命令 vs 对应配置文件**的对照表，让你知道“改这个配置要用哪个命令生效”？
> 