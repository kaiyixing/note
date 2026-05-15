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

# 5. 编译w
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