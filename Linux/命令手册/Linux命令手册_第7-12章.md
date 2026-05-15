# Linux命令手册（第7-12章）

## 第7章：进程管理

### ps
#### 语法
ps [选项]
#### 描述
报告当前进程状态
#### 选项
-e                 显示所有进程
-f                 完整格式
-u 用户            显示指定用户的进程
-p PID             显示指定PID的进程
--forest           以树状结构显示
-o 格式            自定义输出格式
#### 示例
```bash
# 显示所有进程
ps -e

# 完整格式显示所有进程
ps -ef

# 显示指定用户的进程
ps -u username

# 自定义输出格式
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem

# 树状结构显示进程
ps -ef --forest
```

--sort

`--sort` 的语法：

```
ps aux --sort=<字段>
```

或：

```
ps -eo pid,cmd,%cpu --sort=-%cpu
```

👉 **支持升序和降序：**

- 升序：`字段名`
- 降序：`-字段名`（前面加负号）

# 🟦 1. 最常用排序字段（你 90% 会用到的）

| 字段    | 含义           | 示例           |
| ------- | -------------- | -------------- |
| `%cpu`  | CPU 使用率     | `--sort=-%cpu` |
| `%mem`  | 内存使用率     | `--sort=-%mem` |
| `pid`   | 进程 ID        | `--sort=pid`   |
| `ppid`  | 父进程 ID      | `--sort=ppid`  |
| `stime` | 启动时间       | `--sort=stime` |
| `time`  | 累计 CPU 时间  | `--sort=-time` |
| `rss`   | 常驻内存（KB） | `--sort=-rss`  |
| `vsz`   | 虚拟内存（KB） | `--sort=-vsz`  |
| `cmd`   | 命令名         | `--sort=cmd`   |

### top

#### 语法
top [选项]
#### 描述
动态显示系统进程信息
#### 选项
-d 秒数            设置刷新间隔
-p PID             监控指定进程
-u 用户            显示指定用户的进程
-b                 批处理模式
-n 次数            设置更新次数
#### 示例
```bash
# 默认启动top
top

# 设置2秒刷新间隔
top -d 2

# 监控特定进程
top -p 1234

# 批处理模式（适合脚本）
top -b -n 1

# 显示指定用户的进程
top -u username
```

### htop
#### 语法
htop [选项]
#### 描述
交互式进程查看器（top的增强版）
#### 选项
-d 毫秒            设置延迟时间
-u 用户            显示指定用户的进程
-p PID             显示指定PID的进程
-s 列              按指定列排序
#### 示例
```bash
# 启动htop
htop

# 显示指定用户的进程
htop -u username

# 按CPU使用率排序
htop -s PERCENT_CPU

# 显示特定进程
htop -p 1234,5678
```

### pstree
#### 语法
pstree [选项] [PID或用户]
#### 描述
以树状结构显示进程
#### 选项
-a                 显示命令行参数
-p                 显示进程ID
-u                 显示进程用户
-h                 高亮当前进程及其祖先
-H PID             高亮指定进程及其祖先
#### 示例
```bash
# 显示进程树
pstree

# 显示进程ID
pstree -p

# 显示命令行参数
pstree -a

# 高亮特定进程
pstree -H 1234

# 显示指定用户的进程树
pstree username
```

### kill
#### 语法
kill [选项] PID...
#### 描述
向进程发送信号
#### 选项
-l                 列出信号名称
-s 信号            指定信号（如TERM, KILL, HUP）
-信号              直接指定信号编号
#### 示例
```bash
# 终止进程（默认SIGTERM）
kill 1234

# 强制终止进程（SIGKILL）
kill -9 1234

# 重新加载配置（SIGHUP）
kill -HUP 1234

# 列出所有信号
kill -l

# 发送SIGUSR1信号
kill -USR1 1234
```

### pkill
#### 语法
pkill [选项] 模式
#### 描述
根据名称或其他属性向进程发送信号
#### 选项
-f                 匹配完整命令行
-u 用户            匹配指定用户的进程
-x                 精确匹配进程名
-n                 匹配最近启动的进程
-o                 匹配最早启动的进程
#### 示例
```bash
# 终止所有nginx进程
pkill nginx

# 终止指定用户的进程
pkill -u username

# 匹配完整命令行
pkill -f "python script.py"

# 精确匹配进程名
pkill -x firefox

# 终止最近启动的ssh进程
pkill -n ssh
```

### killall
#### 语法
killall [选项] 进程名...
#### 描述
按名称终止所有匹配的进程
#### 选项
-i                 交互式确认
-q                 静默模式
-r                 使用正则表达式
-u 用户            只终止指定用户的进程
-v                 详细输出
#### 示例
```bash
# 终止所有firefox进程
killall firefox

# 交互式终止
killall -i chrome

# 终止指定用户的进程
killall -u username

# 使用正则表达式
killall -r "^python.*"

# 静默模式
killall -q process_name
```

### nice
#### 语法
nice [选项] [命令 [参数...]]
#### 描述
以指定优先级运行程序
#### 选项
-n 优先级          设置niceness值（-20到19）
#### 示例
```bash
# 以较低优先级运行命令
nice -n 10 command

# 以较高优先级运行命令（需要root权限）
sudo nice -n -10 command

# 默认优先级运行
nice command
```

### renice
#### 语法
renice [选项] 优先级 PID...
#### 描述
更改正在运行进程的优先级
#### 选项
-p                 指定进程ID（默认）
-g                 指定进程组ID
-u                 指定用户
#### 示例
```bash
# 更改进程优先级
renice 10 -p 1234

# 更改用户所有进程的优先级
renice 5 -u username

# 更改进程组优先级
renice -5 -g 5678

# 提高优先级（需要root权限）
sudo renice -10 -p 1234
```

### nohup
#### 语法
nohup 命令 [参数...] &
#### 描述
在后台运行命令，忽略挂起信号
#### 示例
```bash
# 在后台运行命令，忽略挂起信号
nohup ./long_running_script.sh &

# 重定向输出到自定义文件
nohup ./script.sh > output.log 2>&1 &

# 查看nohup.out文件
cat nohup.out
```

## 第8章：系统监控和性能

### journalctl

journalctl -u <service> --since "10 min ago" 最近十分钟的系统及日志

### free
#### 语法
free [选项]
#### 描述
显示内存使用情况
#### 选项
-b                 以字节为单位显示
-k                 以KB为单位显示（默认）
-m                 以MB为单位显示
-g                 以GB为单位显示
-h                 以人类可读格式显示
-s 秒数            持续显示，间隔指定秒数
-c 次数            与-s一起使用，指定显示次数
#### 示例
```bash
# 显示内存使用情况（默认KB）
free

# 以MB为单位显示
free -m

# 以人类可读格式显示
free -h

# 每2秒更新一次，显示5次
free -s 2 -c 5

# 显示总计行
free -t
```

### vmstat
#### 语法
vmstat [选项] [延迟 [次数]]
#### 描述
报告虚拟内存统计信息
#### 选项
-a                 显示活动/非活动内存
-d                 显示磁盘统计信息
-p                 显示分区统计信息
-s                 显示内存使用摘要
-w                 宽输出格式
#### 示例
```bash
# 显示一次虚拟内存统计
vmstat

# 每2秒显示一次
vmstat 2

# 每2秒显示5次
vmstat 2 5

# 显示磁盘统计信息
vmstat -d

# 显示内存使用摘要
vmstat -s
```

### mpstat
#### 语法
mpstat [选项] [间隔 [次数]]
#### 描述
报告处理器相关统计信息
#### 选项
-P {cpu|ALL}       指定CPU（默认ALL）
-I {SUM|CPU|SCPU}  中断统计信息
-u                 显示CPU利用率
#### 示例
```bash
# 显示所有CPU统计信息
mpstat

# 每2秒显示一次
mpstat 2

# 显示特定CPU统计信息
mpstat -P 0

# 显示所有CPU统计信息
mpstat -P ALL

# 显示中断统计信息
mpstat -I SUM
```

### iostat
#### 语法
iostat [选项] [设备...] [间隔 [次数]]
#### 描述
报告CPU和I/O统计信息
#### 选项
-c                 只显示CPU统计信息
-d                 只显示设备统计信息
-x                 显示扩展统计信息
-p [设备|ALL]      显示分区统计信息
#### 示例
```bash
# 显示CPU和设备统计信息
iostat

# 只显示设备统计信息
iostat -d

# 显示扩展统计信息
iostat -x

# 每2秒显示一次
iostat 2

# 显示特定设备统计信息
iostat -p sda
```

### sar
#### 语法
sar [选项] [间隔 [次数]]
#### 描述
系统活动报告器
#### 选项
-A                 显示所有报告
-b                 显示I/O和传输速率统计
-n {DEV|EDEV|NFS|SOCK|...} 网络统计
-q                 显示队列长度和负载平均值
-r                 显示内存利用率
-u                 显示CPU利用率
#### 示例
```bash
# 显示CPU利用率
sar -u

# 显示内存利用率
sar -r

# 显示网络统计信息
sar -n DEV

# 每2秒显示一次CPU统计
sar -u 2 5

# 显示所有统计信息
sar -A
```

### uptime
#### 语法
uptime [选项]
#### 描述
显示系统运行时间和负载平均值
#### 选项
-p, --pretty       以易读格式显示
-s, --since        显示系统启动时间
#### 示例
```bash
# 显示系统运行时间
uptime

# 以易读格式显示
uptime -p

# 显示系统启动时间
uptime -s
```

### dmesg
#### 语法
dmesg [选项]
#### 描述
显示或控制内核环缓冲区
#### 选项
-C, --clear        清除环缓冲区
-D, --console-off  禁用控制台输出
-E, --console-on   启用控制台输出
-T, --ctime        显示人类可读时间戳
-t, --notime       不显示时间戳
-H, --human        人类可读输出
--level=列表       过滤消息级别
#### 示例
```bash
# 显示内核消息
dmesg

# 显示人类可读时间戳
dmesg -T

# 过滤错误消息
dmesg --level=err

# 清除环缓冲区（需要root权限）
sudo dmesg -C

# 分页查看
dmesg | less
```

## 第9章：磁盘和文件系统

### df
#### 语法
df [选项] [文件...]
#### 描述
报告文件系统磁盘空间使用情况
#### 选项
-h, --human-readable 以人类可读格式显示
-H                 以1000为基数的人类可读格式
-T, --print-type   显示文件系统类型
-i, --inodes       显示inode信息
-t 类型            只显示指定类型的文件系统
-x 类型            排除指定类型的文件系统
#### 示例
```bash
# 显示磁盘使用情况
df

# 以人类可读格式显示
df -h

# 显示文件系统类型
df -T

# 显示inode使用情况
df -i

# 只显示ext4文件系统
df -t ext4

# 排除tmpfs文件系统
df -x tmpfs
```

### du
#### 语法
du [选项] [文件...]
#### 描述
估计文件空间使用情况
#### 选项
-a, --all          显示所有文件
-h, --human-readable 以人类可读格式显示
-s, --summarize    只显示总计
-d N, --max-depth=N 限制目录深度
-c, --total        显示总计
--exclude=PATTERN  排除匹配的文件
#### 示例
```bash
# 显示当前目录大小
du

# 以人类可读格式显示
du -h

# 只显示总计
du -sh

# 限制深度为2
du -h --max-depth=2

# 显示总计
du -ch

# 排除日志文件
du -h --exclude="*.log"
```

### fdisk
#### 语法
fdisk [选项] 设备
#### 描述
磁盘分区表操作工具
#### 选项
-l, --list         列出分区表
-t, --type 类型    指定分区表类型
-u, --units 单位   指定显示单位
#### 示例
```bash
# 列出所有磁盘分区
sudo fdisk -l

# 对特定磁盘进行分区
sudo fdisk /dev/sdb

# 列出特定磁盘分区
sudo fdisk -l /dev/sda

# 交互式分区命令：
# m - 显示帮助
# p - 打印分区表
# n - 新建分区
# d - 删除分区
# w - 写入更改
# q - 退出不保存
```

### parted
#### 语法
parted [选项] [设备 [命令]]
#### 描述
磁盘分区和分区大小调整工具
#### 选项
-l, --list         列出分区布局
-s, --script       非交互模式
#### 示例
```bash
# 列出所有磁盘分区
sudo parted -l

# 非交互式创建分区
sudo parted /dev/sdb mklabel gpt
sudo parted /dev/sdb mkpart primary ext4 0% 100%

# 交互式分区
sudo parted /dev/sdb

# 调整分区大小
sudo parted /dev/sdb resizepart 1 50GB
```

### mkfs
#### 语法
mkfs [选项] [-t 类型] 设备 [块大小]
#### 描述
创建文件系统
#### 选项
-t, --type 类型    指定文件系统类型
-V, --verbose      详细输出
#### 示例
```bash
# 创建ext4文件系统
sudo mkfs -t ext4 /dev/sdb1

# 创建xfs文件系统
sudo mkfs.xfs /dev/sdb1

# 创建fat32文件系统
sudo mkfs -t vfat /dev/sdb1

# 创建文件系统时指定块大小
sudo mkfs -t ext4 -b 4096 /dev/sdb1
```

### fsck
#### 语法
fsck [选项] [-t 类型] 设备
#### 描述
检查和修复文件系统
#### 选项
-a                 自动修复
-f                 强制检查
-n                 非交互模式（不修复）
-y                 对所有问题回答yes
-t 类型            指定文件系统类型
#### 示例
```bash
# 检查ext4文件系统
sudo fsck /dev/sdb1

# 自动修复文件系统
sudo fsck -a /dev/sdb1

# 强制检查文件系统
sudo fsck -f /dev/sdb1

# 非交互模式检查
sudo fsck -n /dev/sdb1

# 检查特定类型的文件系统
sudo fsck -t ext4 /dev/sdb1
```

### mount
#### 语法
mount [选项] 设备 目录
mount [选项] 设备
mount [选项]
#### 描述
挂载文件系统
#### 选项
-t 类型            指定文件系统类型
-o 选项            指定挂载选项
-a                 挂载/etc/fstab中所有文件系统
-r                 只读挂载
-w                 读写挂载（默认）
#### 示例
```bash
# 挂载ext4分区
sudo mount /dev/sdb1 /mnt/data

# 只读挂载
sudo mount -r /dev/sdb1 /mnt/data

# 挂载ISO文件
sudo mount -t iso9660 -o loop image.iso /mnt/iso

# 挂载所有fstab文件系统
sudo mount -a

# 指定挂载选项
sudo mount -o rw,noatime /dev/sdb1 /mnt/data
```

### umount
#### 语法
umount [选项] 设备|目录
#### 描述
卸载文件系统
#### 选项
-a                 卸载所有文件系统
-f                 强制卸载
-l                 懒卸载
-n                 不更新/etc/mtab
#### 示例
```bash
# 卸载文件系统
sudo umount /mnt/data

# 强制卸载
sudo umount -f /mnt/data

# 懒卸载（当设备忙时）
sudo umount -l /mnt/data

# 卸载所有文件系统
sudo umount -a
```

### lsblk
#### 语法
lsblk [选项] [设备...]
#### 描述
列出块设备信息
#### 选项
-a                 显示所有设备
-d                 不显示从设备
-f                 显示文件系统信息
-m                 显示权限信息
-o 列表            指定输出列
#### 示例
```bash
# 列出所有块设备
lsblk

# 显示文件系统信息
lsblk -f

# 显示权限信息
lsblk -m

# 自定义输出列
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

# 不显示从设备
lsblk -d
```

### blkid
#### 语法
blkid [选项] [设备...]
#### 描述
探测块设备属性
#### 选项
-c 文件            缓存文件（默认/dev/null）
-g                 垃圾回收缓存
-s 标签            显示指定标签
-t 类型            只显示指定类型的设备
#### 示例
```bash
# 显示所有块设备UUID和类型
blkid

# 显示特定设备信息
blkid /dev/sda1

# 只显示ext4设备
blkid -t TYPE=ext4

# 显示UUID标签
blkid -s UUID

# 垃圾回收缓存
sudo blkid -g
```

## 第10章：网络配置和诊断

### ip
#### 语法
ip [选项] 对象 命令
#### 描述
显示/操作路由、设备、策略路由和隧道
#### 对象
addr, address      协议地址管理
link               网络设备管理
route              路由表管理
neigh, neighbour   邻居/ARP表管理
rule               策略数据库管理
tunnel             隧道管理
#### 示例
```bash
# 显示网络接口信息
ip addr show

# 显示路由表
ip route show

# 启用网络接口
sudo ip link set eth0 up

# 添加IP地址
sudo ip addr add 192.168.1.100/24 dev eth0

# 删除IP地址
sudo ip addr del 192.168.1.100/24 dev eth0

# 添加默认路由
sudo ip route add default via 192.168.1.1

# 显示邻居表（ARP表）
ip neigh show
```

### netstat
#### 语法
netstat [选项]
#### 描述
显示网络连接、路由表、接口统计等信息（已弃用，推荐使用ss）
#### 选项
-a, --all          显示所有连接和监听端口
-t, --tcp          显示TCP连接
-u, --udp          显示UDP连接
-l, --listening    显示监听端口
-p, --programs     显示进程ID和程序名
-r, --route        显示路由表
-i, --interfaces   显示接口表
#### 示例
```bash
# 显示所有连接
netstat -a

# 显示TCP连接
netstat -t

# 显示监听端口
netstat -l

# 显示进程信息
sudo netstat -p

# 显示路由表
netstat -r

# 显示接口统计
netstat -i

# 显示数字形式（不解析主机名）
netstat -n
```

### ss
#### 语法
ss [选项] [过滤器]
#### 描述
另一个网络统计工具（netstat的现代替代品）
#### 选项
-a, --all          显示所有连接
-t, --tcp          显示TCP连接
-u, --udp          显示UDP连接
-l, --listening    显示监听端口
-p, --processes    显示进程信息
-n, --numeric      显示数字地址
-s, --summary      显示统计摘要
#### 示例
```bash
# 显示所有连接
ss -a

# 显示TCP连接
ss -t

# 显示监听端口
ss -l

# 显示进程信息
sudo ss -p

# 显示数字地址
ss -n

# 显示统计摘要
ss -s

# 显示特定端口连接
ss -t state established '( dport = :80 or sport = :80 )'
```

### ping
#### 语法
ping [选项] 主机
#### 描述
测试网络连通性
#### 选项
-c 次数            指定发送包的数量
-i 秒数            指定发送间隔
-W 秒数            指定超时时间
-s 字节数          指定包大小
-q                 静默模式
#### 示例
```bash
# 基本ping测试
ping google.com

# 发送4个包后停止
ping -c 4 google.com

# 指定包大小
ping -s 1024 google.com

# 静默模式
ping -q -c 4 google.com

# 指定间隔时间
ping -i 2 google.com
```

### traceroute
#### 语法
traceroute [选项] 主机 [跳数]
#### 描述
跟踪数据包到目标主机的路径
#### 选项
-n                 不解析主机名
-I                 使用ICMP协议
-T                 使用TCP协议
-p 端口            指定目标端口
-m 跳数            指定最大跳数
-q 查询数          指定每跳查询数
#### 示例
```bash
# 基本traceroute
traceroute google.com

# 不解析主机名
traceroute -n google.com

# 使用ICMP协议
traceroute -I google.com

# 使用TCP协议到特定端口
traceroute -T -p 443 google.com

# 限制最大跳数
traceroute -m 10 google.com
```

### tracepath
#### 语法
tracepath [选项] 主机 [端口]
#### 描述
发现到目标主机的路径（不需要root权限）
#### 选项
-n                 不解析主机名
-p 端口            指定目标端口
-l 数据包长度      指定数据包长度
#### 示例
```bash
# 基本tracepath
tracepath google.com

# 不解析主机名
tracepath -n google.com

# 指定目标端口
tracepath google.com 443

# 指定数据包长度
tracepath -l 1024 google.com
```

### nslookup
#### 语法
nslookup [选项] [主机] [服务器]
#### 描述
查询DNS记录
#### 示例
```bash
# 交互模式
nslookup

# 查询A记录
nslookup google.com

# 查询MX记录
nslookup -type=mx google.com

# 查询NS记录
nslookup -type=ns google.com

# 指定DNS服务器
nslookup google.com 8.8.8.8
```

### dig
#### 语法
dig [选项] [@服务器] 主机 [类型]
#### 描述
DNS查询工具
#### 选项
@服务器            指定DNS服务器
-t 类型            指定记录类型
-x 地址            反向DNS查询
+short             简洁输出
+noall +answer     只显示答案部分
#### 示例
```bash
# 查询A记录
dig google.com

# 查询MX记录
dig google.com MX

# 反向DNS查询
dig -x 8.8.8.8

# 指定DNS服务器
dig @8.8.8.8 google.com

# 简洁输出
dig +short google.com

# 只显示答案
dig +noall +answer google.com
```

### host
#### 语法
host [选项] 主机 [服务器]
#### 描述
DNS查找工具
#### 选项
-t 类型            指定记录类型
-a                 显示所有记录
-v                 详细输出
#### 示例
```bash
# 基本DNS查询
host google.com

# 查询MX记录
host -t mx google.com

# 显示所有记录
host -a google.com

# 反向DNS查询
host 8.8.8.8

# 指定DNS服务器
host google.com 8.8.8.8
```

### arp
#### 语法
arp [选项] [-i 接口] 主机
#### 描述
操作ARP缓存
#### 选项
-a                 显示ARP缓存
-d                 删除ARP条目
-s                 添加静态ARP条目
#### 示例
```bash
# 显示ARP缓存
arp -a

# 删除ARP条目
sudo arp -d 192.168.1.100

# 添加静态ARP条目
sudo arp -s 192.168.1.100 aa:bb:cc:dd:ee:ff

# 显示特定接口的ARP缓存
arp -a -i eth0
```

### route
#### 语法
route [选项] 命令 [参数]
#### 描述
显示/操作IP路由表（已弃用，推荐使用ip route）
#### 选项
-A 地址族          指定地址族
-F                 操作转发路由表
-C                 操作缓存路由表
-n                 显示数字地址
#### 示例
```bash
# 显示路由表
route -n

# 添加默认路由
sudo route add default gw 192.168.1.1

# 删除路由
sudo route del -net 192.168.2.0 netmask 255.255.255.0

# 添加网络路由
sudo route add -net 192.168.2.0 netmask 255.255.255.0 gw 192.168.1.1
```

### nmcli
#### 语法
nmcli [选项] 对象 命令 [参数]
#### 描述
NetworkManager命令行工具
#### 对象
general            网络管理器状态
networking         整体网络控制
radio              无线射频开关
connection         连接管理
device             设备管理
agent              网络管理器秘密代理
monitor            监视NetworkManager更改
#### 示例
```bash
# 显示网络状态
nmcli general status

# 列出所有连接
nmcli connection show

# 显示活动连接
nmcli connection show --active

# 启用网络
nmcli networking on

# 禁用网络
nmcli networking off

# 连接到WiFi
nmcli device wifi connect "SSID" password "password"

# 重新加载连接
nmcli connection reload
```

## 第11章：用户和组管理

### useradd
#### 语法
useradd [选项] 用户名
#### 描述
创建新用户
#### 选项
-c, --comment 注释  设置用户注释
-d, --home 目录    设置主目录
-g, --gid GID      设置主要组
-G, --groups 组    设置附加组
-m, --create-home  创建主目录
-s, --shell shell  设置登录shell
-u, --uid UID      设置用户ID
#### 示例
```bash
# 创建基本用户
sudo useradd username

# 创建用户并创建主目录
sudo useradd -m username

# 创建用户并指定shell
sudo useradd -m -s /bin/bash username

# 创建用户并指定主目录
sudo useradd -m -d /home/custom username

# 创建用户并添加到附加组
sudo useradd -m -G sudo,developers username

# 创建系统用户
sudo useradd -r -s /usr/sbin/nologin serviceuser
```

### usermod
#### 语法
usermod [选项] 用户名
#### 描述
修改用户账户
#### 选项
-a, --append       附加到组（必须与-G一起使用）
-c, --comment 注释  修改用户注释
-d, --home 目录    修改主目录
-e, --expiredate 日期 设置账户过期日期
-g, --gid GID      修改主要组
-G, --groups 组    修改附加组
-l, --login 新用户名 修改用户名
-L, --lock         锁定用户账户
-s, --shell shell  修改登录shell
-u, --uid UID      修改用户ID
-U, --unlock       解锁用户账户
#### 示例
```bash
# 修改用户主目录
sudo usermod -d /home/newdir username

# 修改用户shell
sudo usermod -s /bin/zsh username

# 添加用户到附加组
sudo usermod -a -G docker username

# 修改用户名
sudo usermod -l newname oldname

# 锁定用户账户
sudo usermod -L username

# 解锁用户账户
sudo usermod -U username

# 设置账户过期日期
sudo usermod -e 2024-12-31 username
```

### userdel
#### 语法
userdel [选项] 用户名
#### 描述
删除用户账户
#### 选项
-f, --force        强制删除
-r, --remove       删除主目录和邮件池
-Z, --selinux-user 删除SELinux用户映射
#### 示例
```bash
# 删除用户（保留主目录）
sudo userdel username

# 删除用户并删除主目录
sudo userdel -r username

# 强制删除用户
sudo userdel -f username

# 删除用户及相关文件
sudo userdel -r -f username
```

### groupadd
#### 语法
groupadd [选项] 组名
#### 描述
创建新组
#### 选项
-g, --gid GID      指定组ID
-r, --system       创建系统组
-f, --force        如果组存在则成功退出
#### 示例
```bash
# 创建基本组
sudo groupadd groupname

# 创建组并指定GID
sudo groupadd -g 1001 groupname

# 创建系统组
sudo groupadd -r systemgroup

# 如果组存在则不报错
sudo groupadd -f groupname
```

### groupdel
#### 语法
groupdel 组名
#### 描述
删除组
#### 示例
```bash
# 删除组
sudo groupdel groupname

# 注意：不能删除用户的主要组
# 需要先修改用户的主要组或删除用户
```

### passwd
#### 语法
passwd [选项] [用户名]
#### 描述
更改用户密码
#### 选项
-d, --delete       删除密码（使账户无密码）
-e, --expire       立即过期密码
-l, --lock         锁定密码
-u, --unlock       解锁密码
-S, --status       显示密码状态
#### 示例
```bash
# 更改自己的密码
passwd

# 更改其他用户密码（需要root权限）
sudo passwd username

# 删除用户密码
sudo passwd -d username

# 立即过期密码
sudo passwd -e username

# 锁定用户密码
sudo passwd -l username

# 解锁用户密码
sudo passwd -u username

# 显示密码状态
sudo passwd -S username
```

### id
#### 语法
id [选项] [用户名]
#### 描述
显示用户和组ID
#### 选项
-u, --user         只显示用户ID
-g, --group        只显示主要组ID
-G, --groups       显示所有组ID
-n, --name         显示名称而非ID
-r, --real         显示真实ID而非有效ID
#### 示例
```bash
# 显示当前用户信息
id

# 只显示用户ID
id -u

# 只显示主要组ID
id -g

# 显示所有组ID
id -G

# 显示组名称
id -Gn

# 显示特定用户信息
id username
```

### who
#### 语法
who [选项] [文件]
#### 描述
显示谁登录了系统
#### 选项
-a, --all          显示所有信息
-b, --boot         显示系统启动时间
-H, --heading      显示列标题
-l, --login        显示系统登录进程
-m                 只显示当前终端信息
-p, --process      显示活动进程
-r, --runlevel     显示当前运行级别
-T, --writable     显示终端可写状态
-u, --users        显示空闲时间
#### 示例
```bash
# 显示登录用户
who

# 显示所有信息
who -a

# 显示系统启动时间
who -b

# 显示列标题
who -H

# 只显示当前终端
who am i
```

### whoami
#### 语法
whoami [选项]
#### 描述
打印当前有效用户名
#### 选项
--help             显示帮助信息
--version          显示版本信息
#### 示例
```bash
# 显示当前用户名
whoami

# 在脚本中使用
echo "Current user: $(whoami)"
```

## 第12章：软件包管理

### apt
#### 语法
apt [选项] 命令 [包名...]
#### 描述
高级包管理工具（Debian/Ubuntu）
#### 命令
update             更新包列表
upgrade            升级已安装的包
install            安装包
remove             删除包（保留配置）
purge              删除包和配置
autoremove         删除不需要的依赖
search             搜索包
show               显示包信息
list               列出包
#### 示例
```bash
# 更新包列表
sudo apt update

# 升级所有包
sudo apt upgrade

# 安装包
sudo apt install package-name

# 删除包（保留配置）
sudo apt remove package-name

# 完全删除包
sudo apt purge package-name

# 删除不需要的依赖
sudo apt autoremove

# 搜索包
apt search keyword

# 显示包信息
apt show package-name

# 列出已安装的包
apt list --installed
```

### apt-get
#### 语法
apt-get [选项] 命令 [包名...]
#### 描述
APT包管理工具（底层命令）
#### 命令
update             更新包列表
upgrade            升级包
install            安装包
remove             删除包
purge              完全删除包
autoremove         删除自动安装的依赖
dist-upgrade       智能升级
clean              清理下载的包文件
#### 示例
```bash
# 更新包列表
sudo apt-get update

# 升级包
sudo apt-get upgrade

# 安装包
sudo apt-get install package-name

# 删除包
sudo apt-get remove package-name

# 完全删除包
sudo apt-get purge package-name

# 删除不需要的依赖
sudo apt-get autoremove

# 清理缓存
sudo apt-get clean

# 智能升级
sudo apt-get dist-upgrade
```

### yum
#### 语法
yum [选项] 命令 [包名...]
#### 描述
Yellowdog Updater Modified（RHEL/CentOS 7及以下）
#### 命令
install            安装包
update             更新包
remove             删除包
search             搜索包
info               显示包信息
list               列出包
clean              清理缓存
makecache          生成元数据缓存
#### 示例
```bash
# 安装包
sudo yum install package-name

# 更新包
sudo yum update

# 删除包
sudo yum remove package-name

# 搜索包
yum search keyword

# 显示包信息
yum info package-name

# 列出已安装的包
yum list installed

# 清理缓存
sudo yum clean all

# 生成缓存
sudo yum makecache
```

### dnf
#### 语法
dnf [选项] 命令 [包名...]
#### 描述
Dandified YUM（RHEL/CentOS 8+，Fedora）
#### 命令
install            安装包
update             更新包
remove             删除包
search             搜索包
info               显示包信息
list               列出包
clean              清理缓存
makecache          生成元数据缓存
#### 示例
```bash
# 安装包
sudo dnf install package-name

# 更新包
sudo dnf update

# 删除包
sudo dnf remove package-name

# 搜索包
dnf search keyword

# 显示包信息
dnf info package-name

# 列出已安装的包
dnf list installed

# 清理缓存
sudo dnf clean all

# 列出可用模块
dnf module list
```

### pacman
#### 语法
pacman [选项] [包名...]
#### 描述
Arch Linux包管理器
#### 选项
-S                 同步包（安装）
-R                 删除包
-Q                 查询本地包
-Sy                更新包数据库
-Su                升级系统
-Ss                搜索包
-Si                显示包信息
-Rs                递归删除包和依赖
#### 示例
```bash
# 更新包数据库
sudo pacman -Sy

# 升级系统
sudo pacman -Syu

# 安装包
sudo pacman -S package-name

# 删除包
sudo pacman -R package-name

# 递归删除包和依赖
sudo pacman -Rs package-name

# 搜索包
pacman -Ss keyword

# 显示包信息
pacman -Si package-name

# 列出已安装的包
pacman -Q

# 清理未使用的包
sudo pacman -Rns $(pacman -Qtdq)
```

### zypper
#### 语法
zypper [选项] 命令 [参数]
#### 描述
openSUSE包管理器
#### 命令
install (in)       安装包
remove (rm)        删除包
search (se)        搜索包
info               显示包信息
update (up)        更新包
dist-upgrade (dup) 发行版升级
refresh (ref)      刷新仓库
clean              清理缓存
#### 示例
```bash
# 刷新仓库
sudo zypper refresh

# 安装包
sudo zypper install package-name

# 删除包
sudo zypper remove package-name

# 搜索包
zypper search keyword

# 显示包信息
zypper info package-name

# 更新包
sudo zypper update

# 发行版升级
sudo zypper dist-upgrade

# 清理缓存
sudo zypper clean
```

### dpkg
#### 语法
dpkg [选项] 包名...
#### 描述
Debian包管理器（底层工具）
#### 选项
-i, --install      安装包
-r, --remove       删除包（保留配置）
-P, --purge        完全删除包
-l, --list         列出包
-s, --status       显示包状态
-L, --listfiles    列出包文件
-S, --search       搜索包文件
--configure        配置未配置的包
#### 示例
```bash
# 安装.deb包
sudo dpkg -i package.deb

# 删除包（保留配置）
sudo dpkg -r package-name

# 完全删除包
sudo dpkg -P package-name

# 列出已安装的包
dpkg -l

# 显示包状态
dpkg -s package-name

# 列出包文件
dpkg -L package-name

# 搜索文件所属包
dpkg -S /path/to/file

# 配置未配置的包
sudo dpkg --configure -a
```

### rpm
#### 语法
rpm [选项] [包名...]
#### 描述
RPM包管理器（Red Hat系）
#### 选项
-i, --install      安装包
-e, --erase        删除包
-q, --query        查询包
-U, --upgrade      升级包
-F, --freshen      刷新包
-V, --verify       验证包
--import           导入GPG密钥
--nodeps           忽略依赖
#### 示例
```bash
# 安装.rpm包
sudo rpm -ivh package.rpm

# 删除包
sudo rpm -e package-name

# 查询已安装的包
rpm -qa

# 查询包信息
rpm -qi package-name

# 列出包文件
rpm -ql package-name

# 验证包
rpm -V package-name

# 查询文件所属包
rpm -qf /path/to/file

# 升级包
sudo rpm -Uvh package.rpm
```

### snap
#### 语法
snap [选项] 命令 [参数]
#### 描述
通用Linux包管理器（Canonical）
#### 命令
install            安装snap包
remove             删除snap包
list               列出已安装的snap
find               搜索snap包
info               显示snap信息
refresh            更新snap包
revert             回滚snap包
#### 示例
```bash
# 搜索snap包
snap find keyword

# 安装snap包
sudo snap install package-name

# 列出已安装的snap
snap list

# 显示snap信息
snap info package-name

# 更新snap包
sudo snap refresh package-name

# 更新所有snap
sudo snap refresh

# 删除snap包
sudo snap remove package-name

# 回滚snap包
sudo snap revert package-name
```

### flatpak
#### 语法
flatpak [选项] 命令 [参数]
#### 描述
通用Linux应用分发框架
#### 命令
install            安装应用
uninstall          卸载应用
list               列出已安装的应用
search             搜索应用
info               显示应用信息
update             更新应用
run                运行应用
#### 示例
```bash
# 搜索应用
flatpak search keyword

# 安装应用
flatpak install flathub app-id

# 列出已安装的应用
flatpak list

# 显示应用信息
flatpak info app-id

# 更新应用
flatpak update app-id

# 更新所有应用
flatpak update

# 运行应用
flatpak run app-id

# 卸载应用
flatpak uninstall app-id
```