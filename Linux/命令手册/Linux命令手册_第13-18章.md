# Linux命令手册

## 第13章：系统服务管理

### systemctl
#### 语法
systemctl [选项] 命令 [单元...]
#### 描述
控制系统和服务管理器
#### 命令
start              启动单元
stop               停止单元
restart            重启单元
reload             重新加载单元配置
status             显示单元状态
enable             启用单元（开机自启）
disable            禁用单元（取消开机自启）
is-active          检查单元是否活动
is-enabled         检查单元是否启用
list-units         列出单元
list-unit-files    列出单元文件
#### 示例
```bash
# 启动服务
sudo systemctl start nginx

# 停止服务
sudo systemctl stop nginx

# 重启服务
sudo systemctl restart nginx

# 查看服务状态
systemctl status nginx

# 启用开机自启
sudo systemctl enable nginx

# 禁用开机自启
sudo systemctl disable nginx

# 列出所有活动服务
systemctl list-units --type=service --state=active

# 列出所有服务文件
systemctl list-unit-files --type=service

# 检查服务是否活动
systemctl is-active nginx

# 检查服务是否启用
systemctl is-enabled nginx
```

### service
#### 语法
service 服务名 命令
#### 描述
运行System V init脚本
#### 命令
start              启动服务
stop               停止服务
restart            重启服务
reload             重新加载配置
status             显示服务状态
#### 示例
```bash
# 启动服务
sudo service nginx start

# 停止服务
sudo service nginx stop

# 重启服务
sudo service nginx restart

# 重新加载配置
sudo service nginx reload

# 查看服务状态
service nginx status

# 列出所有服务状态
service --status-all
```

### chkconfig
#### 语法
chkconfig [选项] [服务名 [开|关]]
#### 描述
管理系统服务（SysV init）
#### 选项
--list             列出服务状态
--add              添加服务
--del              删除服务
--level 级别       指定运行级别
#### 示例
```bash
# 列出所有服务
chkconfig --list

# 列出特定服务
chkconfig --list httpd

# 启用服务（所有级别）
chkconfig httpd on

# 禁用服务（所有级别）
chkconfig httpd off

# 在特定级别启用服务
chkconfig --level 35 httpd on

# 添加服务
chkconfig --add myservice

# 删除服务
chkconfig --del myservice
```

### init
#### 语法
init [运行级别]
#### 描述
进程初始化和控制
#### 运行级别
0                  关机
1, s, S            单用户模式
2                  多用户模式（无NFS）
3                  完全多用户模式（文本界面）
4                  未使用
5                  图形界面模式
6                  重启
#### 示例
```bash
# 切换到图形界面
sudo init 5

# 切换到文本界面
sudo init 3

# 关机
sudo init 0

# 重启
sudo init 6

# 进入单用户模式
sudo init 1
```

### runlevel
#### 语法
runlevel
#### 描述
显示以前和当前的运行级别
#### 示例
```bash
# 显示运行级别
runlevel

# 输出示例：N 3（N表示无以前级别，3是当前级别）
```

## 第14章：远程操作和传输

### ssh
#### 语法
ssh [选项] [用户@]主机 [命令]
#### 描述
安全远程登录
#### 选项
-p 端口            指定端口
-i 密钥文件        指定私钥文件
-L 本地端口:主机:端口 本地端口转发
-R 远程端口:主机:端口 远程端口转发
-D 端口            动态端口转发（SOCKS代理）
-X                 启用X11转发
-C                 启用压缩
-v                 详细输出
#### 示例
```bash
# 基本SSH连接
ssh user@hostname

# 指定端口
ssh -p 2222 user@hostname

# 使用密钥文件
ssh -i ~/.ssh/id_rsa user@hostname

# 执行远程命令
ssh user@hostname "ls -l"

# 本地端口转发
ssh -L 8080:localhost:80 user@hostname

# X11转发（图形界面）
ssh -X user@hostname

# 启用压缩
ssh -C user@hostname

# 详细输出（调试）
ssh -v user@hostname
```

### scp
#### 语法
scp [选项] 源... 目标
#### 描述
安全复制文件
#### 选项
-P 端口            指定端口
-r                 递归复制目录
-C                 启用压缩
-p                 保留文件属性
-v                 详细输出
#### 示例
```bash
# 复制本地文件到远程
scp file.txt user@hostname:/path/

# 复制远程文件到本地
scp user@hostname:/path/file.txt ./

# 递归复制目录
scp -r /local/dir user@hostname:/remote/dir

# 指定端口
scp -P 2222 file.txt user@hostname:/path/

# 启用压缩
scp -C file.txt user@hostname:/path/

# 保留文件属性
scp -p file.txt user@hostname:/path/
```

### sftp
#### 语法
sftp [选项] [用户@]主机
#### 描述
安全文件传输协议客户端
#### 选项
-P 端口            指定端口
-i 密钥文件        指定私钥文件
#### 常用命令
get 文件           下载文件
put 文件           上传文件
ls                 列出远程文件
lls                列出本地文件
cd 目录            切换远程目录
lcd 目录           切换本地目录
mkdir 目录         创建远程目录
lmkdir 目录        创建本地目录
rm 文件            删除远程文件
exit               退出
#### 示例
```bash
# 连接到SFTP服务器
sftp user@hostname

# 指定端口连接
sftp -P 2222 user@hostname

# 使用密钥文件
sftp -i ~/.ssh/id_rsa user@hostname

# 交互式操作：
# sftp> ls
# sftp> get remote_file.txt
# sftp> put local_file.txt
# sftp> cd /remote/path
# sftp> lcd /local/path
# sftp> exit
```

### rsync
#### 语法
rsync [选项] 源... 目标
#### 描述
远程和本地文件同步工具
#### 选项
-a, --archive      归档模式（递归、保留属性）
-v, --verbose      详细输出
-z, --compress     传输时压缩
-h, --human-readable 人类可读格式
--progress         显示进度
--delete           删除目标中多余的文件
-e ssh             指定远程shell
#### 示例
```bash
# 本地同步
rsync -av /source/ /destination/

# 远程同步（推送）
rsync -avz /local/dir/ user@hostname:/remote/dir/

# 远程同步（拉取）
rsync -avz user@hostname:/remote/dir/ /local/dir/

# 显示进度
rsync -av --progress /source/ /destination/

# 删除多余文件
rsync -av --delete /source/ /destination/

# 使用SSH指定端口
rsync -av -e "ssh -p 2222" /local/ user@hostname:/remote/

# 仅显示将要传输的文件
rsync -avn /source/ /destination/
```

### wget
#### 语法
wget [选项] URL...
#### 描述
非交互式网络下载器
#### 选项
-O 文件            指定输出文件
-P 目录            指定下载目录
-c                 断点续传
-q                 静默模式
-v                 详细输出
--user-agent=字符串 设置User-Agent
--referer=URL      设置Referer
--limit-rate=速率  限制下载速度
-r, --recursive    递归下载
--no-parent        不下载父目录
#### 示例
```bash
# 基本下载
wget http://example.com/file.zip

# 指定输出文件
wget -O myfile.zip http://example.com/file.zip

# 断点续传
wget -c http://example.com/largefile.zip

# 限制下载速度
wget --limit-rate=100k http://example.com/file.zip

# 递归下载网站
wget -r -np -k http://example.com/

# 静默下载
wget -q http://example.com/file.zip

# 设置User-Agent
wget --user-agent="Custom-Agent" http://example.com/file.zip

# 下载到指定目录
wget -P /downloads/ http://example.com/file.zip
```

### curl
#### 语法
curl [选项] [URL...]
#### 描述
传输URL数据的命令行工具
#### 选项
-o 文件            指定输出文件
-O                 保存为远程文件名
-L                 跟随重定向
-I                 只显示HTTP头
-X 方法            指定HTTP方法
-H 头              设置HTTP头
-d 数据            发送POST数据
-u 用户:密码       设置基本认证
--compressed       请求压缩响应
--limit-rate 速率  限制传输速度
#### 示例
```bash
# 基本GET请求
curl http://example.com

# 保存到文件
curl -o myfile.html http://example.com

# 保存为远程文件名
curl -O http://example.com/file.zip

# 跟随重定向
curl -L http://example.com

# 只显示HTTP头
curl -I http://example.com

# POST请求
curl -d "name=value" http://example.com/form

# 设置HTTP头
curl -H "Content-Type: application/json" http://example.com/api

# 基本认证
curl -u username:password http://example.com

# 上传文件
curl -F "file=@localfile.txt" http://example.com/upload

# 限制传输速度
curl --limit-rate 100k http://example.com/file.zip
```

## 第15章：查找和搜索

### find
#### 语法
find [路径...] [表达式]
#### 描述
在目录树中查找文件
#### 表达式
-name 模式         按名称查找
-type 类型         按类型查找（f=file, d=directory, l=link）
-size [+/-]大小    按大小查找
-mtime [+/-]天数   按修改时间查找
-atime [+/-]天数   按访问时间查找
-exec 命令 {} \;   对找到的文件执行命令
-delete            删除找到的文件
-perm 模式         按权限查找
-user 用户         按所有者查找
-group 组          按组查找
#### 示例
```bash
# 按名称查找
find /home -name "*.txt"

# 按类型查找（只找文件）
find /var -type f

# 按大小查找（大于100MB）
find / -size +100M

# 按修改时间查找（最近7天）
find /home -mtime -7

# 按权限查找
find /etc -perm 644

# 按所有者查找
find /home -user username

# 删除空文件
find /tmp -type f -empty -delete

# 对找到的文件执行命令
find /logs -name "*.log" -exec gzip {} \;

# 查找并显示详细信息
find /home -name "*.conf" -ls
```

### locate
#### 语法
locate [选项] 模式
#### 描述
通过数据库快速查找文件
#### 选项
-i                 忽略大小写
-c                 只显示匹配数量
-r                 使用正则表达式
--limit 数量       限制结果数量
--existing         只显示存在的文件
#### 示例
```bash
# 基本查找
locate filename.txt

# 忽略大小写
locate -i README

# 使用正则表达式
locate -r "\.conf$"

# 只显示数量
locate -c "*.log"

# 限制结果数量
locate --limit 10 "*.py"

# 更新数据库
sudo updatedb
```

### which
#### 语法
which [选项] 命令...
#### 描述
显示命令的完整路径
#### 选项
-a                 显示所有匹配的路径
#### 示例
```bash
# 查找命令路径
which python

# 显示所有匹配路径
which -a python

# 在脚本中使用
PYTHON_PATH=$(which python)
```

### whereis
#### 语法
whereis [选项] 文件...
#### 描述
定位二进制文件、源代码和手册页
#### 选项
-b                 只显示二进制文件
-m                 只显示手册页
-s                 只显示源代码
-u                 显示不寻常的条目
#### 示例
```bash
# 查找所有相关信息
whereis python

# 只显示二进制文件
whereis -b python

# 只显示手册页
whereis -m python

# 只显示源代码
whereis -s python
```

### type
#### 语法
type [选项] 名称...
#### 描述
显示命令类型
#### 选项
-t                 只显示类型
-p                 显示路径（如果是文件）
-a                 显示所有位置
#### 类型
alias              别名
keyword            Shell关键字
function           函数
builtin            内建命令
file               外部文件
#### 示例
```bash
# 显示命令类型
type ls

# 只显示类型
type -t ls

# 显示所有位置
type -a echo

# 检查命令是否存在
if type git >/dev/null 2>&1; then
    echo "Git is installed"
fi
```

## 第16章：备份和恢复

### dd
#### 语法
dd [选项]
#### 描述
转换和复制文件
#### 选项
if=文件            输入文件
of=文件            输出文件
bs=字节数          块大小
count=块数         复制块数
skip=块数          跳过输入块数
seek=块数          跳过输出块数
conv=转换          转换选项（如notrunc, sync, noerror）
#### 示例
```bash
# 创建磁盘镜像
sudo dd if=/dev/sda of=disk.img bs=4M

# 恢复磁盘镜像
sudo dd if=disk.img of=/dev/sdb bs=4M

# 创建可启动USB
sudo dd if=ubuntu.iso of=/dev/sdb bs=4M

# 备份MBR
sudo dd if=/dev/sda of=mbr.img bs=512 count=1

# 恢复MBR
sudo dd if=mbr.img of=/dev/sda bs=512 count=1

# 转换文件大小写
dd if=input.txt of=output.txt conv=ucase

# 创建空文件
dd if=/dev/zero of=emptyfile bs=1M count=100
```

### rsync
#### 语法
rsync [选项] 源... 目标
#### 描述
远程和本地文件同步工具（也用于备份）
#### 选项
-a, --archive      归档模式
-v, --verbose      详细输出
-z, --compress     传输时压缩
-h, --human-readable 人类可读格式
--progress         显示进度
--delete           删除目标中多余的文件
-b, --backup       创建备份
--backup-dir=目录  指定备份目录
--suffix=后缀      指定备份后缀
#### 示例
```bash
# 增量备份
rsync -av --progress /home/ /backup/home/

# 带备份的同步
rsync -avb --suffix=.bak /source/ /destination/

# 指定备份目录
rsync -av --backup --backup-dir=/backup/old /current/ /destination/

# 排除文件
rsync -av --exclude="*.tmp" /source/ /destination/

# 仅显示差异
rsync -avn /source/ /destination/

# 压缩传输
rsync -avz /local/ user@remote:/backup/
```

### tar
#### 语法
tar [选项] [归档文件] [文件]...
#### 描述
创建和操作tar归档文件（也用于备份）
#### 选项
-c, --create       创建新归档
-x, --extract      提取归档
-t, --list         列出归档内容
-f, --file=归档    指定归档文件名
-z, --gzip         通过gzip过滤
-j, --bzip2        通过bzip2过滤
-J, --xz           通过xz过滤
-v, --verbose      详细输出
-p, --preserve-permissions 保留权限
--exclude=PATTERN  排除文件
#### 示例
```bash
# 创建完整备份
tar -czvf backup.tar.gz /home/user

# 创建增量备份
tar -czvf backup-$(date +%Y%m%d).tar.gz --newer-mtime="2024-01-01" /home

# 提取备份
tar -xzvf backup.tar.gz -C /restore/

# 列出备份内容
tar -tzvf backup.tar.gz

# 排除临时文件
tar -czvf backup.tar.gz --exclude="*.tmp" --exclude=".cache" /home

# 从标准输入创建备份
find /home -name "*.doc" | tar -czvf docs.tar.gz -T -

# 远程备份
tar -czf - /home | ssh user@backup-server "cat > backup.tar.gz"
```

### cpio
#### 语法
cpio [选项]
#### 描述
复制文件到归档或从归档提取
#### 模式
-o, --create       创建归档（输出）
-i, --extract      提取归档（输入）
-p, --pass-through 直接复制（传递）
#### 选项
-v                 详细输出
-t                 列出归档内容
-u                 无条件替换
-d                 创建目录
-m                 保留修改时间
#### 示例
```bash
# 创建归档
find /home -print | cpio -ov > backup.cpio

# 提取归档
cpio -iv < backup.cpio

# 列出归档内容
cpio -it < backup.cpio

# 直接复制目录
find /source -depth -print | cpio -pmd /destination

# 创建压缩归档
find /home -print | cpio -ov | gzip > backup.cpio.gz

# 提取压缩归档
gunzip -c backup.cpio.gz | cpio -iv
```

### dump
#### 语法
dump [选项] 文件系统
#### 描述
文件系统备份工具（主要用于ext2/ext3/ext4）
#### 选项
-0                 0级备份（完整备份）
-1..-9             1-9级备份（增量备份）
-f 文件            指定备份文件
-L 标签            指定卷标
-u                 更新/etc/dumpdates
-v                 详细输出
#### 示例
```bash
# 完整备份
sudo dump -0uf /backup/root.dump /

# 增量备份
sudo dump -1uf /backup/root.dump /

# 列出备份级别
cat /etc/dumpdates

# 备份到磁带
sudo dump -0f /dev/st0 /home

# 备份并压缩
sudo dump -0f - /home | gzip > home.dump.gz
```

### restore
#### 语法
restore [选项] [文件...]
#### 描述
从dump备份中恢复文件系统
#### 选项
-r                 交互式恢复
-t                 列出备份内容
-x                 提取指定文件
-f 文件            指定备份文件
-v                 详细输出
#### 示例
```bash
# 列出备份内容
restore -tf /backup/root.dump

# 交互式恢复
sudo restore -rf /backup/root.dump

# 提取特定文件
restore -xf /backup/root.dump etc/passwd

# 恢复压缩备份
gunzip -c home.dump.gz | restore -rf -

# 比较备份和文件系统
restore -Cf /backup/root.dump
```

## 第17章：安全和审计

### 17.1 身份认证和权限提升

#### sudo
##### 语法
sudo [选项] 命令
##### 描述
以其他用户权限执行命令（默认root）
##### 选项
-u 用户            以指定用户身份执行
-l                 列出允许的命令
-k                 使时间戳失效
-b                 后台运行
-S                 从标准输入读取密码
##### 示例
```bash
# 以root身份执行命令
sudo apt update

# 以指定用户身份执行
sudo -u postgres psql

# 列出允许的命令
sudo -l

# 后台运行
sudo -b long_running_command

# 从标准输入读取密码
echo "password" | sudo -S command
```

#### su
##### 语法
su [选项] [用户名]
##### 描述
切换用户身份
##### 选项
-, -l, --login     登录shell（完整环境）
-c 命令            执行单个命令
-s shell           指定shell
##### 示例
```bash
# 切换到root
su -

# 切换到指定用户
su - username

# 执行单个命令
su -c "whoami" username

# 指定shell
su -s /bin/zsh username
```

#### visudo
##### 语法
visudo [选项]
##### 描述
安全编辑sudoers文件
##### 选项
-f 文件            编辑指定文件
-s                 严格模式
##### 示例
```bash
# 编辑sudoers文件
sudo visudo

# 编辑特定sudoers文件
sudo visudo -f /etc/sudoers.d/myrules

# 检查语法
sudo visudo -c
```

#### pam
##### 描述
可插拔认证模块配置
##### 相关文件
/etc/pam.d/        PAM配置目录
/etc/pam.conf      主配置文件（较少使用）
##### 示例配置
```bash
# /etc/pam.d/common-auth 示例
auth    required    pam_unix.so
auth    sufficient  pam_ldap.so
auth    required    pam_deny.so

# /etc/pam.d/sudo 示例
auth    sufficient  pam_rootok.so
@include common-auth
```

### 17.2 防火墙管理

#### iptables
##### 语法
iptables [选项] 链 规则
##### 描述
IPv4包过滤和NAT管理
##### 链
INPUT              输入链
OUTPUT             输出链
FORWARD            转发链
##### 选项
-A                 追加规则
-D                 删除规则
-I                 插入规则
-L                 列出规则
-F                 清空规则
-P                 设置默认策略
-N                 创建新链
##### 示例
```bash
# 列出所有规则
sudo iptables -L -v

# 允许SSH连接
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 拒绝所有其他连接
sudo iptables -A INPUT -j DROP

# 设置默认策略
sudo iptables -P INPUT DROP

# 删除规则
sudo iptables -D INPUT -p tcp --dport 22 -j ACCEPT

# 保存规则（CentOS/RHEL）
sudo service iptables save

# 保存规则（Ubuntu/Debian）
sudo iptables-save > /etc/iptables/rules.v4
```

#### ufw
##### 语法
ufw [选项] 命令
##### 描述
Uncomplicated Firewall（简化防火墙）
##### 命令
enable             启用防火墙
disable            禁用防火墙
status             显示状态
allow              允许连接
deny               拒绝连接
delete             删除规则
##### 示例
```bash
# 启用防火墙
sudo ufw enable

# 禁用防火墙
sudo ufw disable

# 允许SSH
sudo ufw allow 22/tcp

# 允许HTTP/HTTPS
sudo ufw allow http
sudo ufw allow https

# 拒绝特定IP
sudo ufw deny from 192.168.1.100

# 显示状态
sudo ufw status verbose

# 删除规则
sudo ufw delete allow 22/tcp
```

#### firewalld
##### 语法
firewall-cmd [选项]
##### 描述
动态防火墙管理器（RHEL/CentOS 7+）
##### 选项
--permanent        永久规则
--zone=区域        指定区域
--add-service=服务 添加服务
--remove-service=服务 删除服务
--add-port=端口/协议 添加端口
--list-all         列出所有规则
--reload           重新加载配置
##### 示例
```bash
# 启用防火墙
sudo systemctl enable --now firewalld

# 允许SSH
sudo firewall-cmd --add-service=ssh

# 永久允许HTTP
sudo firewall-cmd --permanent --add-service=http

# 添加自定义端口
sudo firewall-cmd --add-port=8080/tcp

# 列出所有规则
sudo firewall-cmd --list-all

# 重新加载配置
sudo firewall-cmd --reload

# 查看区域
sudo firewall-cmd --get-active-zones
```

### 17.3 SSH安全

#### ssh-keygen
##### 语法
ssh-keygen [选项]
##### 描述
生成SSH密钥对
##### 选项
-t 类型            指定密钥类型（rsa, ecdsa, ed25519）
-b 位数            指定位数（RSA）
-f 文件            指定文件名
-N 密码            指定密码（空字符串表示无密码）
-C 注释            添加注释
##### 示例
```bash
# 生成RSA密钥对
ssh-keygen -t rsa -b 4096 -C "user@example.com"

# 生成Ed25519密钥对
ssh-keygen -t ed25519 -C "user@example.com"

# 生成无密码密钥
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa_nopass

# 指定文件名
ssh-keygen -t rsa -f ~/.ssh/mykey

# 更改密钥密码
ssh-keygen -p -f ~/.ssh/id_rsa
```

#### 密钥登录配置
##### 服务器端配置 (/etc/ssh/sshd_config)
```bash
# 启用公钥认证
PubkeyAuthentication yes

# 指定授权密钥文件
AuthorizedKeysFile .ssh/authorized_keys

# 禁用密码认证（可选）
PasswordAuthentication no

# 重启SSH服务
sudo systemctl restart sshd
```

##### 客户端配置 (~/.ssh/config)
```bash
# 基本配置
Host myserver
    HostName 192.168.1.100
    User myuser
    IdentityFile ~/.ssh/id_rsa
    Port 2222

# 禁用主机密钥检查（不推荐生产环境）
Host insecure
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

#### sshd_config加固
##### 推荐配置 (/etc/ssh/sshd_config)
```bash
# 禁用root登录
PermitRootLogin no

# 使用协议2
Protocol 2

# 限制认证尝试次数
MaxAuthTries 3

# 设置空闲超时
ClientAliveInterval 300
ClientAliveCountMax 2

# 限制用户
AllowUsers user1 user2
DenyUsers baduser

# 限制IP范围
AllowTcpForwarding no
X11Forwarding no

# 使用强加密算法
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com
```

### 17.4 入侵检测和防护

#### fail2ban
##### 配置文件
/etc/fail2ban/jail.local    本地配置
/etc/fail2ban/jail.conf     默认配置
##### 常用命令
```bash
# 启动fail2ban
sudo systemctl enable --now fail2ban

# 查看状态
sudo fail2ban-client status

# 查看特定监狱状态
sudo fail2ban-client status sshd

# 手动禁止IP
sudo fail2ban-client set sshd banip 192.168.1.100

# 手动解禁IP
sudo fail2ban-client set sshd unbanip 192.168.1.100
```

##### 基本配置 (/etc/fail2ban/jail.local)
```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = %(sshd_log)s
maxretry = 3
bantime = 86400
```

#### rkhunter
##### 语法
rkhunter [选项]
##### 描述
Rootkit、后门和本地漏洞扫描器
##### 选项
--check            执行检查
--update           更新文件属性数据库
--propupd          更新属性文件
--sk               跳过确认提示
##### 示例
```bash
# 更新数据库
sudo rkhunter --propupd

# 执行检查
sudo rkhunter --check --sk

# 查看警告
sudo rkhunter --report-warnings-only

# 检查特定文件
sudo rkhunter --check --file /bin/ls
```

#### lynis
##### 语法
lynis [选项] 命令
##### 描述
安全审计工具
##### 命令
audit              执行系统审计
update             更新Lynis
show               显示信息
##### 示例
```bash
# 执行系统审计
sudo lynis audit system

# 更新Lynis
sudo lynis update

# 显示安装信息
sudo lynis show version

# 执行部分审计
sudo lynis audit system --tests authentication,filesystems

# 查看建议
sudo lynis show suggestions
```

#### auditd
##### 配置文件
/etc/audit/auditd.conf      守护进程配置
/etc/audit/rules.d/         规则目录
##### 常用命令
```bash
# 启动auditd
sudo systemctl enable --now auditd

# 添加规则
sudo auditctl -w /etc/passwd -p wa -k passwd_changes

# 列出规则
sudo auditctl -l

# 搜索日志
sudo ausearch -k passwd_changes

# 生成报告
sudo aureport -f

# 实时监控
sudo ausearch -f /etc/shadow --raw | aureport -f --input -
```

##### 基本规则 (/etc/audit/rules.d/audit.rules)
```bash
# 监控关键文件
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k priv_esc

# 监控系统调用
-a always,exit -F arch=b64 -S execve -k exec

# 监控网络配置
-w /etc/hosts -p wa -k hosts
-w /etc/resolv.conf -p wa -k dns
```

### 17.5 用户会话和登录监控

#### who
##### 语法
who [选项]
##### 描述
显示当前登录用户
##### 选项
-a                 显示所有信息
-b                 显示系统启动时间
-H                 显示列标题
-l                 显示登录进程
-m                 显示当前终端
-p                 显示活动进程
-r                 显示运行级别
-T                 显示终端状态
-u                 显示空闲时间
##### 示例
```bash
# 显示所有登录信息
who -a

# 显示系统启动时间
who -b

# 显示带标题的登录用户
who -H

# 只显示当前终端
who am i
```

#### last
##### 语法
last [选项] [用户名...]
##### 描述
显示最近登录记录
##### 选项
-n 数量            限制显示数量
-F                 显示完整时间
-R                 不显示主机名
-x                 显示系统关机/启动事件
##### 示例
```bash
# 显示最近登录
last

# 限制显示数量
last -n 10

# 显示完整时间
last -F

# 显示特定用户
last username

# 显示系统事件
last -x

# 显示不带主机名
last -R
```

#### lastlog
##### 语法
lastlog [选项]
##### 描述
显示所有用户的最后登录时间
##### 选项
-u 用户            显示特定用户
-b 天数            显示超过指定天数未登录的用户
-t 天数            显示最近指定天数内登录的用户
##### 示例
```bash
# 显示所有用户最后登录
lastlog

# 显示特定用户
lastlog -u username

# 显示超过30天未登录的用户
lastlog -b 30

# 显示最近7天内登录的用户
lastlog -t 7
```

#### ac
##### 语法
ac [选项] [用户名...]
##### 描述
显示用户连接时间统计
##### 选项
-d                 显示每日统计
-p                 显示每个用户的统计
-y                 显示年份
##### 示例
```bash
# 显示总连接时间
ac

# 显示每日统计
ac -d

# 显示每个用户的统计
ac -p

# 显示特定用户的统计
ac username

# 显示带年份的每日统计
ac -dy
```

#### psacct
##### 描述
进程记账工具
##### 相关命令
```bash
# 启用进程记账
sudo accton /var/log/pacct

# 查看用户统计
sudo sa

# 查看特定用户命令
sudo lastcomm --user username

# 查看特定命令
sudo lastcomm ls

# 查看所有命令
sudo lastcomm
```

### 17.6 文件完整性和监控

#### tripwire
##### 配置步骤
```bash
# 初始化数据库
sudo tripwire --init

# 检查完整性
sudo tripwire --check

# 更新数据库
sudo tripwire --update --accept-all

# 生成报告
sudo twprint --print-report -r /var/lib/tripwire/report/*.twr
```

##### 配置文件
/etc/tripwire/twcfg.txt     配置文件
/etc/tripwire/twpol.txt     策略文件

#### aide
##### 配置步骤
```bash
# 初始化数据库
sudo aide --init

# 安装数据库
sudo cp /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# 检查完整性
sudo aide --check

# 更新数据库
sudo aide --update
```

##### 配置文件
/etc/aide/aide.conf         主配置文件

#### inotify
##### 相关工具
```bash
# 安装inotify-tools
sudo apt install inotify-tools  # Debian/Ubuntu
sudo yum install inotify-tools  # RHEL/CentOS

# 监控文件变化
inotifywait -m -e modify,create,delete /path/to/watch

# 一次性监控
inotifywait -e close_write /path/to/file

# 监控目录树
inotifywait -r -m -e modify /var/www/

# 在脚本中使用
inotifywait -m /path | while read path action file; do
    echo "File $file in $path was $action"
done
```

#### audit.rules
##### 文件完整性监控规则
```bash
# 监控关键系统文件
-w /bin -p wa -k bin_files
-w /sbin -p wa -k sbin_files
-w /usr/bin -p wa -k usr_bin_files
-w /usr/sbin -p wa -k usr_sbin_files

# 监控配置文件
-w /etc -p wa -k etc_files
-w /boot -p wa -k boot_files

# 监控库文件
-w /lib -p wa -k lib_files
-w /lib64 -p wa -k lib64_files
-w /usr/lib -p wa -k usr_lib_files
```

### 17.7 SELinux/AppArmor

#### getenforce
##### 语法
getenforce
##### 描述
显示SELinux强制模式
##### 示例
```bash
# 显示当前模式
getenforce
# 输出：Enforcing, Permissive, 或 Disabled
```

#### sestatus
##### 语法
sestatus [选项]
##### 描述
显示SELinux状态
##### 选项
-v                 显示详细信息
-b                 显示布尔值
##### 示例
```bash
# 显示基本状态
sestatus

# 显示详细信息
sestatus -v

# 显示布尔值
sestatus -b
```

#### apparmor_status
##### 语法
apparmor_status [选项]
##### 描述
显示AppArmor状态
##### 选项
--enabled          检查是否启用
--profiled         显示配置文件数量
--enforced         显示强制模式配置文件
--complaining      显示抱怨模式配置文件
##### 示例
```bash
# 显示完整状态
apparmor_status

# 检查是否启用
apparmor_status --enabled

# 显示配置文件统计
apparmor_status --profiled --enforced --complaining
```

### 17.8 密码策略

#### chage
##### 语法
chage [选项] 用户名
##### 描述
更改密码过期信息
##### 选项
-l                 显示密码过期信息
-m 天数            最小密码年龄
-M 天数            最大密码年龄
-W 天数            密码过期警告天数
-I 天数            密码过期后锁定天数
-E 日期            账户过期日期
-d 日期            最后密码更改日期
##### 示例
```bash
# 显示密码过期信息
chage -l username

# 设置密码90天后过期
chage -M 90 username

# 设置密码过期前7天警告
chage -W 7 username

# 设置账户过期日期
chage -E 2024-12-31 username

# 强制用户下次登录时更改密码
chage -d 0 username
```

#### passwd
##### 密码策略相关选项
```bash
# 锁定用户密码
sudo passwd -l username

# 解锁用户密码
sudo passwd -u username

# 删除用户密码
sudo passwd -d username

# 立即过期密码
sudo passwd -e username

# 显示密码状态
sudo passwd -S username
```

#### pam_cracklib
##### 配置示例 (/etc/pam.d/common-password)
```bash
password requisite pam_cracklib.so retry=3 minlen=8 difok=3 \
    ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 \
    reject_username enforce_for_root
```

##### 参数说明
- `minlen=8`: 最小长度8字符
- `difok=3`: 新密码至少3个字符不同于旧密码
- `ucredit=-1`: 至少1个大写字母
- `lcredit=-1`: 至少1个小写字母
- `dcredit=-1`: 至少1个数字
- `ocredit=-1`: 至少1个特殊字符

#### login.defs
##### 密码策略配置 (/etc/login.defs)
```bash
# 密码过期设置
PASS_MAX_DAYS   90
PASS_MIN_DAYS   1
PASS_MIN_LEN    8
PASS_WARN_AGE   7

# 用户ID范围
UID_MIN         1000
UID_MAX         60000

# 组ID范围
GID_MIN         1000
GID_MAX         60000
```

### 17.9 网络安全工具

#### nmap
##### 语法
nmap [选项] 目标
##### 描述
网络发现和安全审计
##### 选项
-sS                TCP SYN扫描
-sT                TCP连接扫描
-sU                UDP扫描
-O                 操作系统检测
-sV                服务版本检测
-p 端口            指定端口
-A                 全面扫描
-T4                快速扫描
##### 示例
```bash
# 基本扫描
nmap 192.168.1.1

# 扫描特定端口
nmap -p 22,80,443 192.168.1.1

# 操作系统检测
nmap -O 192.168.1.1

# 服务版本检测
nmap -sV 192.168.1.1

# 全面扫描
nmap -A 192.168.1.1

# 快速扫描
nmap -T4 -F 192.168.1.1

# UDP扫描
nmap -sU -p 53,67,68 192.168.1.1

# 扫描整个子网
nmap 192.168.1.0/24
```

#### netcat
##### 语法
nc [选项] 主机 端口
##### 描述
网络工具（瑞士军刀）
##### 选项
-l                 监听模式
-p 端口            本地端口
-u                 UDP模式
-v                 详细输出
-z                 扫描模式（不发送数据）
##### 示例
```bash
# 端口扫描
nc -zv 192.168.1.1 22

# 监听端口
nc -lvp 8080

# 发送文件
# 发送端：nc 192.168.1.100 8080 < file.txt
# 接收端：nc -lvp 8080 > file.txt

# 简单聊天
# 服务器：nc -lvp 1234
# 客户端：nc 192.168.1.100 1234

# 端口转发
mkfifo backpipe
nc -lvp 8080 0<backpipe | nc 192.168.1.100 80 1>backpipe

# HTTP请求
printf "GET / HTTP/1.0\r\n\r\n" | nc google.com 80
```

#### tcpdump
##### 语法
tcpdump [选项] [表达式]
##### 描述
网络流量分析工具
##### 选项
-i 接口            指定接口
-n                 不解析主机名
-v, -vv, -vvv      详细程度
-c 数量            捕获包数量
-w 文件            写入文件
-r 文件            读取文件
-s 长度            捕获长度
##### 示例
```bash
# 基本捕获
sudo tcpdump -i eth0

# 不解析主机名
sudo tcpdump -i eth0 -n

# 捕获指定数量
sudo tcpdump -i eth0 -c 10

# 写入文件
sudo tcpdump -i eth0 -w capture.pcap

# 读取文件
tcpdump -r capture.pcap

# 过滤HTTP流量
sudo tcpdump -i eth0 port 80

# 过滤特定主机
sudo tcpdump -i eth0 host 192.168.1.100

# 过滤TCP SYN包
sudo tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0'

# 详细输出
sudo tcpdump -i eth0 -vvv
```

#### tshark
##### 语法
tshark [选项] [过滤器]
##### 描述
Wireshark命令行版本
##### 选项
-i 接口            指定接口
-c 数量            捕获包数量
-w 文件            写入文件
-r 文件            读取文件
-Y 过滤器          显示过滤器
-T 格式            输出格式
##### 示例
```bash
# 基本捕获
sudo tshark -i eth0

# 捕获指定数量
sudo tshark -i eth0 -c 10

# 写入文件
sudo tshark -i eth0 -w capture.pcap

# 读取文件
tshark -r capture.pcap

# HTTP流量分析
sudo tshark -i eth0 -Y "http"

# DNS查询分析
sudo tshark -i eth0 -Y "dns"

# 自定义输出格式
sudo tshark -i eth0 -T fields -e ip.src -e ip.dst -e tcp.port

# 过滤特定协议
sudo tshark -i eth0 -Y "tcp.port == 22"
```

## 第18章：实用场景专题

### 18.1 本地软件安装

#### tar.gz/tar.bz2/tar.xz 源码编译安装
##### 基本步骤
```bash
# 1. 下载源码包
wget https://example.com/software-1.0.tar.gz

# 2. 解压源码包
tar -xzf software-1.0.tar.gz    # .tar.gz
tar -xjf software-1.0.tar.bz2   # .tar.bz2  
tar -xJf software-1.0.tar.xz    # .tar.xz

# 3. 进入源码目录
cd software-1.0

# 4. 配置编译选项
./configure --prefix=/usr/local --enable-feature

# 5. 编译
make

# 6. 安装（需要root权限）
sudo make install

# 7. 验证安装
software --version
```

##### 常见configure选项
```bash
# 安装前缀
--prefix=/usr/local

# 系统配置目录
--sysconfdir=/etc

# 启用/禁用特性
--enable-feature
--disable-feature

# 指定依赖路径
--with-library=/path/to/library

# 优化选项
--enable-optimizations
--disable-debug

# 静态/动态链接
--enable-static
--enable-shared
```

##### 处理依赖问题
```bash
# Ubuntu/Debian: 安装构建依赖
sudo apt build-dep package-name

# RHEL/CentOS: 安装开发工具
sudo yum groupinstall "Development Tools"

# 检查缺失的头文件
./configure 2>&1 | grep "not found"

# 安装缺失的开发包
sudo apt install libssl-dev zlib1g-dev
```

#### make/cmake 构建
##### Makefile项目
```bash
# 查看可用目标
make help

# 清理构建
make clean

# 并行编译
make -j$(nproc)

# 指定安装目录
make DESTDIR=/tmp/install install

# 调试构建
make CFLAGS="-g -O0"

# 发布构建
make CFLAGS="-O2 -DNDEBUG"
```

##### CMake项目
```bash
# 创建构建目录
mkdir build && cd build

# 配置项目
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local

# 编译
make

# 安装
sudo make install

# 清理
make clean

# 重新配置
cmake .. -DENABLE_FEATURE=ON

# 生成不同构建类型
cmake .. -DCMAKE_BUILD_TYPE=Debug
cmake .. -DCMAKE_BUILD_TYPE=Release
```

#### 编程语言包管理器
##### pip (Python)
```bash
# 安装包
pip install package-name

# 安装特定版本
pip install package-name==1.2.3

# 从requirements.txt安装
pip install -r requirements.txt

# 用户级安装
pip install --user package-name

# 升级包
pip install --upgrade package-name

# 卸载包
pip uninstall package-name

# 列出已安装包
pip list

# 显示包信息
pip show package-name
```

##### npm (Node.js)
```bash
# 初始化项目
npm init

# 安装依赖
npm install package-name

# 安装开发依赖
npm install --save-dev package-name

# 全局安装
npm install -g package-name

# 卸载包
npm uninstall package-name

# 更新包
npm update package-name

# 列出已安装包
npm list

# 运行脚本
npm run script-name
```

##### gem (Ruby)
```bash
# 安装gem
gem install gem-name

# 安装特定版本
gem install gem-name -v 1.2.3

# 卸载gem
gem uninstall gem-name

# 列出已安装gem
gem list

# 显示gem信息
gem info gem-name

# 更新gem
gem update gem-name

# 更新所有gem
gem update
```

##### cargo (Rust)
```bash
# 初始化项目
cargo new project-name

# 构建项目
cargo build

# 构建发布版本
cargo build --release

# 运行项目
cargo run

# 测试项目
cargo test

# 安装二进制包
cargo install crate-name

# 更新依赖
cargo update

# 清理构建
cargo clean
```

#### 常见问题解决
##### 权限问题
```bash
# 使用用户目录安装
./configure --prefix=$HOME/.local
make && make install

# 添加到PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

##### 库路径问题
```bash
# 设置LD_LIBRARY_PATH
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# 永久设置
echo '/usr/local/lib' | sudo tee /etc/ld.so.conf.d/local.conf
sudo ldconfig
```

##### 头文件找不到
```bash
# Ubuntu/Debian
sudo apt install build-essential
sudo apt install libxxx-dev

# RHEL/CentOS
sudo yum install gcc gcc-c++ make
sudo yum install libxxx-devel
```

### 18.2 Docker/容器管理

#### docker run/build/images/ps/volume/network
##### 基本命令
```bash
# 运行容器
docker run -it ubuntu:20.04 /bin/bash

# 后台运行
docker run -d --name web nginx

# 端口映射
docker run -d -p 8080:80 nginx

# 挂载卷
docker run -v /host/path:/container/path ubuntu

# 环境变量
docker run -e ENV_VAR=value ubuntu

# 构建镜像
docker build -t myapp:latest .

# 列出容器
docker ps
docker ps -a  # 包括停止的

# 列出镜像
docker images

# 停止容器
docker stop container_name

# 删除容器
docker rm container_name

# 删除镜像
docker rmi image_name
```

##### 卷管理
```bash
# 创建命名卷
docker volume create myvolume

# 使用命名卷
docker run -v myvolume:/data ubuntu

# 列出卷
docker volume ls

# 检查卷
docker volume inspect myvolume

# 删除卷
docker volume rm myvolume

# 清理未使用的卷
docker volume prune
```

##### 网络管理
```bash
# 创建网络
docker network create mynetwork

# 使用自定义网络
docker run --network mynetwork ubuntu

# 列出网络
docker network ls

# 检查网络
docker network inspect mynetwork

# 连接容器到网络
docker network connect mynetwork container_name

# 删除网络
docker network rm mynetwork
```

#### docker-compose
##### docker-compose.yml 示例
```yaml
version: '3.8'
services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html
    networks:
      - frontend
    depends_on:
      - db
  
  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: myapp
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - backend

volumes:
  db_data:

networks:
  frontend:
  backend:
```

##### 常用命令
```bash
# 启动服务
docker-compose up

# 后台启动
docker-compose up -d

# 停止服务
docker-compose down

# 重建服务
docker-compose up --build

# 查看日志
docker-compose logs

# 执行命令
docker-compose exec web bash

# 扩展服务
docker-compose up --scale web=3
```

#### containerd/nerdctl
##### nerdctl 基本命令
```bash
# 运行容器
nerdctl run -d --name nginx nginx

# 列出容器
nerdctl ps

# 列出镜像
nerdctl images

# 构建镜像
nerdctl build -t myapp .

# 拉取镜像
nerdctl pull nginx

# 推送镜像
nerdctl push myregistry/myapp

# 命名空间管理
nerdctl namespace list
nerdctl namespace create myns
nerdctl --namespace myns ps
```

### 18.3 Git版本控制

#### git init/add/commit/push/pull/clone
##### 基本工作流
```bash
# 初始化仓库
git init

# 克隆仓库
git clone https://github.com/user/repo.git

# 添加文件到暂存区
git add file.txt
git add .

# 提交更改
git commit -m "Add new feature"

# 推送到远程
git push origin main

# 从远程拉取
git pull origin main

# 查看状态
git status

# 查看差异
git diff
```

#### git branch/checkout/rebase/merge
##### 分支管理
```bash
# 创建分支
git branch feature-branch

# 切换分支
git checkout feature-branch

# 创建并切换分支
git checkout -b feature-branch

# 列出分支
git branch

# 合并分支
git checkout main
git merge feature-branch

# 变基
git checkout feature-branch
git rebase main

# 删除分支
git branch -d feature-branch

# 强制删除分支
git branch -D feature-branch
```

#### git stash/log/diff/status
##### 日常操作
```bash
# 临时保存更改
git stash

# 应用最近的stash
git stash pop

# 列出stash
git stash list

# 查看提交历史
git log

# 查看简洁历史
git log --oneline

# 查看图形化历史
git log --graph --oneline --all

# 查看文件差异
git diff file.txt

# 查看暂存区差异
git diff --cached

# 查看状态
git status

# 查看简短状态
git status -s
```

#### .gitignore配置
##### 常见.gitignore规则
```gitignore
# 编译文件
*.o
*.obj
*.exe
*.dll
*.so
*.dylib

# 依赖目录
node_modules/
vendor/
target/

# 日志文件
*.log
logs/

# 环境变量
.env
.env.local

# 编辑器文件
*.swp
*.swo
.DS_Store
.vscode/
.idea/

# 构建输出
dist/
build/
out/

# 临时文件
tmp/
temp/
*.tmp
```

### 18.4 日志分析

#### journalctl
##### 基本用法
```bash
# 查看所有日志
journalctl

# 查看特定服务日志
journalctl -u nginx

# 实时跟踪日志
journalctl -f

# 查看今天日志
journalctl --since today

# 查看最近1小时日志
journalctl --since "1 hour ago"

# 按优先级过滤
journalctl -p err

# 查看内核日志
journalctl -k

# 导出日志
journalctl -u nginx --no-pager > nginx.log
```

#### logrotate
##### 配置文件示例 (/etc/logrotate.d/nginx)
```bash
/var/log/nginx/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 www-data adm
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
```

##### 常用选项
```bash
# 测试配置
logrotate -d /etc/logrotate.conf

# 强制轮转
logrotate -f /etc/logrotate.d/nginx

# 详细输出
logrotate -v /etc/logrotate.conf
```

#### tail -f / grep 实时监控
##### 实时日志监控
```bash
# 基本实时监控
tail -f /var/log/nginx/access.log

# 监控错误日志
tail -f /var/log/nginx/error.log

# 过滤特定内容
tail -f /var/log/syslog | grep "error"

# 监控多个文件
tail -f /var/log/nginx/*.log

# 显示最后100行并实时监控
tail -n 100 -f /var/log/application.log

# 高亮特定关键词
tail -f /var/log/syslog | grep --color=always "warning\|error"
```

#### awk/sed 日志提取
##### 日志分析示例
```bash
# 提取IP地址（Apache/Nginx日志）
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr

# 统计HTTP状态码
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c

# 提取特定时间段日志
awk '$4 >= "[01/Jan/2024:00:00:00" && $4 <= "[01/Jan/2024:23:59:59"' /var/log/nginx/access.log

# 提取POST请求
awk '$6 == "POST"' /var/log/nginx/access.log

# 提取特定URL访问
awk '$7 ~ /api\/v1/' /var/log/nginx/access.log
```

### 18.5 定时任务

#### crontab 使用
##### crontab 格式
```bash
# 分 时 日 月 周 命令
# * * * * * command
```

##### 常用示例
```bash
# 编辑当前用户的crontab
crontab -e

# 列出当前用户的crontab
crontab -l

# 删除当前用户的crontab
crontab -r

# 每天凌晨2点执行备份
0 2 * * * /backup/script.sh

# 每小时执行
0 * * * * /monitor/check.sh

# 每5分钟执行
*/5 * * * * /check/status.sh

# 工作日9-17点每小时执行
0 9-17 * * 1-5 /work/task.sh

# 每月1号执行
0 0 1 * * /monthly/cleanup.sh
```

##### 环境变量设置
```bash
# 在crontab中设置环境变量
MAILTO=admin@example.com
PATH=/usr/local/bin:/usr/bin:/bin
SHELL=/bin/bash

0 2 * * * /backup/script.sh
```

#### at 一次性任务
##### 基本用法
```bash
# 安装at（如果未安装）
sudo apt install at  # Debian/Ubuntu
sudo yum install at  # RHEL/CentOS

# 启用at服务
sudo systemctl enable --now atd

# 在指定时间执行任务
echo "command" | at 14:30

# 在指定日期执行
echo "command" | at 2024-01-01

# 在1小时后执行
echo "command" | at now + 1 hour

# 列出待执行任务
atq

# 删除任务
atrm job_number
```

#### systemd timer
##### 创建timer服务
```bash
# 创建服务文件 /etc/systemd/system/backup.service
[Unit]
Description=Backup Service

[Service]
Type=oneshot
ExecStart=/backup/script.sh
```

```bash
# 创建timer文件 /etc/systemd/system/backup.timer
[Unit]
Description=Backup Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

##### 管理timer
```bash
# 启用timer
sudo systemctl enable --now backup.timer

# 列出所有timer
systemctl list-timers

# 查看timer状态
systemctl status backup.timer

# 手动触发
sudo systemctl start backup.service
```

#### 日志清理脚本示例
```bash
#!/bin/bash
# /cleanup/logs.sh

# 定义日志目录
LOG_DIR="/var/log"
BACKUP_DIR="/backup/logs"

# 创建备份目录
mkdir -p "$BACKUP_DIR/$(date +%Y-%m)"

# 压缩30天前的日志
find "$LOG_DIR" -name "*.log" -mtime +30 -exec gzip {} \;

# 移动压缩后的日志到备份目录
find "$LOG_DIR" -name "*.log.gz" -mtime +7 -exec mv {} "$BACKUP_DIR/$(date +%Y-%m)/" \;

# 删除90天前的备份
find "$BACKUP_DIR" -name "*.log.gz" -mtime +90 -delete

# 清理空目录
find "$BACKUP_DIR" -type d -empty -delete

echo "$(date): Log cleanup completed" >> /var/log/cleanup.log
```

### 18.6 系统安全加固

#### iptables/ufw 防火墙
##### iptables 基础规则
```bash
# 清空现有规则
sudo iptables -F
sudo iptables -X

# 设置默认策略
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# 允许本地回环
sudo iptables -A INPUT -i lo -j ACCEPT

# 允许已建立的连接
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 允许SSH
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 允许HTTP/HTTPS
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# 保存规则
sudo iptables-save > /etc/iptables/rules.v4
```

##### ufw 基础配置
```bash
# 重置ufw
sudo ufw reset

# 设置默认策略
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 允许必要服务
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status verbose
```

#### fail2ban
##### SSH保护配置
```bash
# /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = %(sshd_log)s
maxretry = 3
bantime = 86400
findtime = 600
```

##### Web应用保护
```bash
# Apache/Nginx保护
[apache-auth]
enabled = true
port = http,https
filter = apache-auth
logpath = /var/log/apache2/*error.log

[nginx-botsearch]
enabled = true
port = http,https
filter = nginx-botsearch
logpath = /var/log/nginx/access.log
maxretry = 10
```

#### ssh 密钥登录
##### 生成密钥对
```bash
# 生成Ed25519密钥（推荐）
ssh-keygen -t ed25519 -C "your_email@example.com"

# 生成RSA密钥（兼容性更好）
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

##### 服务器配置
```bash
# /etc/ssh/sshd_config
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
PermitRootLogin no
```

##### 客户端配置
```bash
# ~/.ssh/config
Host production
    HostName 192.168.1.100
    User admin
    IdentityFile ~/.ssh/id_ed25519
    Port 2222
    ServerAliveInterval 60
```

#### SELinux/AppArmor
##### SELinux 基础操作
```bash
# 查看状态
sestatus

# 临时禁用
sudo setenforce 0

# 永久禁用（/etc/selinux/config）
SELINUX=disabled

# 查看布尔值
getsebool -a

# 启用HTTPD网络连接
sudo setsebool -P httpd_can_network_connect 1
```

##### AppArmor 基础操作
```bash
# 查看状态
sudo apparmor_status

# 启用配置文件
sudo aa-enforce /etc/apparmor.d/usr.sbin.nginx

# 禁用配置文件
sudo aa-disable /etc/apparmor.d/usr.sbin.nginx

# 重新加载配置文件
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.nginx
```

#### 用户sudo权限配置
##### 安全sudo配置
```bash
# 编辑sudoers文件
sudo visudo

# 授权特定用户
username ALL=(ALL:ALL) ALL

# 授权用户组
%admin ALL=(ALL) ALL

# 无需密码执行特定命令
backupuser ALL=(ALL) NOPASSWD: /usr/bin/rsync, /bin/tar

# 限制命令路径
developer ALL=(ALL) /usr/bin/git, /usr/bin/make, /usr/bin/gcc
```

### 18.7 服务配置和调试

#### nginx/apache 配置
##### Nginx 基础配置
```nginx
# /etc/nginx/sites-available/example.com
server {
    listen 80;
    server_name example.com www.example.com;
    root /var/www/example.com;
    index index.html index.php;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
    }

    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;
}
```

##### Apache 虚拟主机
```apache
# /etc/apache2/sites-available/example.com.conf
<VirtualHost *:80>
    ServerName example.com
    ServerAlias www.example.com
    DocumentRoot /var/www/example.com
    
    <Directory /var/www/example.com>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/example.com_error.log
    CustomLog ${APACHE_LOG_DIR}/example.com_access.log combined
</VirtualHost>
```

#### systemd 服务编写
##### 自定义服务文件
```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=myapp
Group=myapp
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/myapp --config /etc/myapp/config.yaml
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

##### 管理服务
```bash
# 重新加载systemd配置
sudo systemctl daemon-reload

# 启用并启动服务
sudo systemctl enable --now myapp.service

# 查看服务状态
sudo systemctl status myapp.service

# 查看服务日志
sudo journalctl -u myapp.service -f
```

#### 日志级别调整
##### 应用日志级别
```bash
# Nginx日志级别
error_log /var/log/nginx/error.log warn;

# Apache日志级别
LogLevel warn

# Systemd服务日志级别
# 在服务文件中添加环境变量
Environment=LOG_LEVEL=info
```

##### 系统日志级别
```bash
# rsyslog配置 (/etc/rsyslog.conf)
*.info;mail.none;authpriv.none;cron.none /var/log/messages
authpriv.*                                              /var/log/secure
mail.*                                                  -/var/log/maillog
cron.*                                                  /var/log/cron
```

#### 端口和进程排查
##### 端口占用排查
```bash
# 查看端口占用
sudo ss -tlnp | grep :80
sudo netstat -tlnp | grep :80

# 查看特定端口
sudo lsof -i :80

# 查看进程监听的端口
sudo lsof -i -P -n | grep LISTEN

# 查看进程打开的文件
sudo lsof -p PID
```

##### 进程资源排查
```bash
# 查看进程CPU/内存使用
top -p PID
htop -p PID

# 查看进程文件描述符
ls -l /proc/PID/fd/

# 查看进程环境变量
cat /proc/PID/environ | tr '\0' '\n'

# 查看进程命令行参数
cat /proc/PID/cmdline | tr '\0' ' '
```

### 18.8 Shell脚本基础

#### 变量和运算
##### 变量定义和使用

​	read

```
#!/bin/bash
read -p "请输入您的名字: " name
echo "您好，$name"
```

| 选项        | 说明                                     |
| :---------- | :--------------------------------------- |
| `-p "提示"` | 显示提示字符串，并等待输入               |
| `-s`        | 静默模式（不显示输入内容），常用于密码   |
| `-t 秒数`   | 超时（秒），超时后返回非零状态           |
| `-n N`      | 只读取 N 个字符，不必等到换行            |
| `-r`        | 禁止反斜杠转义（raw 模式），保留原文字符 |
| `-a 数组`   | 将分割后的单词存入数组                   |
| `-d 分隔符` | 指定行结束符（默认换行）                 |
| `-e`        | 使用 readline 获得命令行编辑功能         |

```bash
#!/bin/bash

# 字符串变量
name="World"
echo "Hello $name" ##输出  

# 数字变量
count=10
echo "Count: $count"

# 数组
fruits=("apple" "banana" "orange")
echo "First fruit: ${fruits[0]}"
echo "All fruits: ${fruits[@]}"

# 环境变量
export MY_VAR="value"
```

##### 算术运算
```bash
# 算术扩展
a=10
b=5
sum=$((a + b))
product=$((a * b))
echo "Sum: $sum, Product: $product"

# 浮点运算（需要bc）
result=$(echo "scale=2; $a / $b" | bc)
echo "Division: $result"
```

#### 条件判断
##### if语句
```bash
#!/bin/bash

# 基本if
if [ "$name" = "admin" ]; then
    echo "Welcome admin"
elif [ "$name" = "user" ]; then
    echo "Welcome user"
else
    echo "Unknown user"
fi

# 文件测试
if [ -f "/etc/passwd" ]; then
    echo "File exists"
fi

if [ -d "/var/log" ]; then
    echo "Directory exists"
fi

# 数字比较
if [ $count -gt 5 ]; then
    echo "Count is greater than 5"
fi
```

##### case语句
```bash
case "$1" in
    start)
        echo "Starting service"
        ;;
    stop)
        echo "Stopping service"
        ;;
    restart)
        echo "Restarting service"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac
```

#### 循环结构
##### for循环
```bash
# 遍历数组
for fruit in "${fruits[@]}"; do
    echo "Fruit: $fruit"
done

# 数字范围
for i in {1..5}; do
    echo "Number: $i"
done

# C风格
for ((i=0; i<10; i++)); do
    echo "Counter: $i"
done
```

##### while循环
```bash
# 基本while
count=0
while [ $count -lt 5 ]; do
    echo "Count: $count"
    ((count++))
done

# 读取文件
while IFS= read -r line; do
    echo "Line: $line"
done < /etc/passwd
```

#### 函数定义
##### 基本函数
```bash
#!/bin/bash

# 定义函数
log_message() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# 调用函数
log_message "INFO" "Application started"
log_message "ERROR" "Failed to connect to database"

# 带返回值的函数
is_file_readable() {
    local file=$1
    if [ -r "$file" ]; then
        return 0  # true
    else
        return 1  # false
    fi
}

# 使用函数
if is_file_readable "/etc/passwd"; then
    echo "File is readable"
fi
```

#### 常用脚本示例
##### 备份脚本
```bash
#!/bin/bash

# 配置
SOURCE_DIR="/home/user/documents"
BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$DATE.tar.gz"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 执行备份
tar -czf "$BACKUP_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

# 检查备份是否成功
if [ $? -eq 0 ]; then
    echo "Backup completed successfully: $BACKUP_FILE"
    # 删除7天前的备份
    find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +7 -delete
else
    echo "Backup failed!"
    exit 1
fi
```

##### 系统监控脚本
```bash
#!/bin/bash

# CPU使用率
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)

# 内存使用率
mem_usage=$(free | awk 'NR==2{printf "%.2f", $3*100/$2 }')

# 磁盘使用率
disk_usage=$(df / | awk 'NR==2{print $5}' | cut -d'%' -f1)

# 输出结果
echo "CPU Usage: $cpu_usage%"
echo "Memory Usage: $mem_usage%"
echo "Disk Usage: $disk_usage%"

# 告警
if (( $(echo "$cpu_usage > 80" | bc -l) )); then
    echo "WARNING: High CPU usage!"
fi

if (( $(echo "$mem_usage > 80" | bc -l) )); then
    echo "WARNING: High memory usage!"
fi

if [ $disk_usage -gt 80 ]; then
    echo "WARNING: High disk usage!"
fi
```