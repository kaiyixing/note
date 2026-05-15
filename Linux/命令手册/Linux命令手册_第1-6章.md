# Linux命令手册（第1-6章）

## 第1章：基础系统信息命令

### uname
#### 语法
uname [选项]
#### 描述
显示系统信息
#### 选项
-a, --all          显示所有信息
-s, --kernel-name  显示内核名称
-n, --nodename     显示网络节点主机名
-r, --kernel-release 显示内核发布版本
-v, --kernel-version 显示内核版本
-m, --machine      显示机器硬件名称
-p, --processor    显示处理器类型
-i, --hardware-platform 显示硬件平台
-o, --operating-system 显示操作系统
#### 示例
```bash
# 显示所有系统信息
uname -a

# 仅显示内核版本
uname -r

# 显示机器架构
uname -m
```

### hostname
#### 语法
hostname [选项] [新主机名]
#### 描述
显示或设置系统主机名
#### 选项
--help             显示帮助信息
--version          显示版本信息
-f, --fqdn         显示完整域名
-A, --all-fqdns    显示所有FQDN
-I, --all-ip-addresses 显示所有IP地址
-i, --ip-address   显示IP地址
#### 示例
```bash
# 显示当前主机名
hostname

# 显示完整域名
hostname -f

# 显示所有IP地址
hostname -I
```

### uptime
#### 语法
uptime [选项]
#### 描述
显示系统运行时间和负载平均值
#### 选项
-p, --pretty       以易读格式显示
-s, --since        显示系统启动时间
-V, --version      显示版本信息
-h, --help         显示帮助信息
#### 示例
```bash
# 显示系统运行时间
uptime

# 以易读格式显示
uptime -p

# 显示系统启动时间
uptime -s
```

### date
#### 语法
date [选项] [+格式] [日期]
#### 描述
显示或设置系统日期和时间
#### 选项
-d, --date=字符串   显示指定日期的时间
-s, --set=字符串   设置日期
-u, --utc          显示UTC时间
-R, --rfc-email    显示RFC 5322格式日期
-I, --iso-8601[=timespec] 显示ISO 8601格式日期
#### 示例
```bash
# 显示当前日期时间
date

# 显示特定格式的日期
date "+%Y-%m-%d %H:%M:%S"

# 显示昨天的日期
date -d "yesterday"

# 设置系统时间（需要root权限）
sudo date -s "2024-01-01 12:00:00"
```

### cal
#### 语法
cal [选项] [[月] 年]
#### 描述
显示日历
#### 选项
-1, --one          只显示当前月份（默认）
-3, --three        显示上月、本月和下月
-y, --year         显示整年日历
-j, --julian       显示儒略日
-m, --month        显示指定月份
#### 示例
```bash
# 显示当前月份日历
cal

# 显示2024年整年日历
cal -y 2024

# 显示上月、本月、下月
cal -3

# 显示2024年3月日历
cal 3 2024
```

### arch
#### 语法
arch
#### 描述
显示机器硬件架构
#### 示例
```bash
# 显示硬件架构
arch
```

### dmidecode
#### 语法
dmidecode [选项]
#### 描述
从DMI表中解码系统硬件信息
#### 选项
-t, --type TYPE    只显示指定类型的条目
-s, --string KEYWORD 只显示指定关键字的值
-u, --dump         显示原始DMI数据
-q, --quiet        静默模式
--help             显示帮助信息
#### 示例
```bash
# 显示所有DMI信息（需要root权限）
sudo dmidecode

# 显示BIOS信息
sudo dmidecode -t bios

# 显示系统序列号
sudo dmidecode -s system-serial-number

# 显示内存信息
sudo dmidecode -t memory
```

## 第2章：文件和目录管理

### ls
#### 语法
ls [选项] [文件...]
#### 描述
列出目录内容
#### 选项
-a, --all          显示所有文件，包括隐藏文件
-l                 使用长列表格式
-h, --human-readable 以易读格式显示文件大小
-t                 按修改时间排序
-r, --reverse      反向排序
-S                 按文件大小排序
-d, --directory    列出目录本身而非内容
-R, --recursive    递归列出子目录
#### 示例
```bash
# 列出当前目录所有文件（包括隐藏文件）
ls -a

# 以长格式显示文件详情
ls -l

# 按文件大小排序显示
ls -lhS

# 递归列出目录树
ls -R /etc
```

### cd
#### 语法
cd [目录]
#### 描述
更改当前工作目录
#### 示例
```bash
# 进入用户主目录
cd

# 进入指定目录
cd /home/user

# 返回上一级目录
cd ..

# 返回上次访问的目录
cd -
```

### pwd
#### 语法
pwd [选项]
#### 描述
打印当前工作目录
#### 选项
-L, --logical      使用逻辑路径（默认）
-P, --physical     使用物理路径（解析符号链接）
#### 示例
```bash
# 显示当前目录路径
pwd

# 显示物理路径（不包含符号链接）
pwd -P
```

### mkdir
#### 语法
mkdir [选项] 目录...
#### 描述
创建目录
#### 选项
-p, --parents      创建父目录（如果不存在）
-v, --verbose      显示创建的每个目录
-m, --mode=模式    设置权限模式
#### 示例
```bash
# 创建单个目录
mkdir newdir

# 创建多级目录
mkdir -p parent/child/grandchild

# 创建目录并设置权限
mkdir -m 755 secure_dir
```

### rmdir
#### 语法
rmdir [选项] 目录...
#### 描述
删除空目录
#### 选项
-p, --parents      删除目录及其空的父目录
-v, --verbose      显示删除的每个目录
#### 示例
```bash
# 删除空目录
rmdir empty_dir

# 删除多级空目录
rmdir -p parent/child/grandchild
```

### touch
#### 语法
touch [选项] 文件...
#### 描述
创建空文件或更新文件时间戳
#### 选项
-a                 只更改访问时间
-m                 只更改修改时间
-c, --no-create    不创建不存在的文件
-r, --reference=文件 使用参考文件的时间戳
-t STAMP           使用指定时间戳
#### 示例
```bash
# 创建空文件
touch newfile.txt

# 更新文件时间戳
touch existing_file.txt

# 使用参考文件的时间戳
touch -r reference.txt target.txt

# 设置特定时间戳
touch -t 202401011200 file.txt
```

### cp
#### 语法
cp [选项] 源文件 目标文件
cp [选项] 源文件... 目录
#### 描述
复制文件和目录
#### 选项
-r, -R, --recursive 递归复制目录
-i, --interactive  覆盖前询问
-f, --force        强制覆盖
-v, --verbose      显示详细过程
-p, --preserve     保留文件属性
-a, --archive      归档模式（等同于-dR --preserve=all）
#### 示例
```bash
# 复制单个文件
cp file1.txt file2.txt

# 递归复制目录
cp -r source_dir/ destination_dir/

# 交互式复制（覆盖前询问）
cp -i file.txt existing_file.txt

# 归档复制（保留所有属性）
cp -a original/ backup/
```

### mv
#### 语法
mv [选项] 源文件 目标文件
mv [选项] 源文件... 目录
#### 描述
移动或重命名文件和目录
#### 选项
-i, --interactive  覆盖前询问
-f, --force        强制覆盖
-v, --verbose      显示详细过程
-n, --no-clobber   不覆盖已存在的文件
#### 示例
```bash
# 重命名文件
mv oldname.txt newname.txt

# 移动文件到目录
mv file.txt /path/to/directory/

# 交互式移动（覆盖前询问）
mv -i file.txt existing_file.txt

# 移动多个文件到目录
mv file1.txt file2.txt /destination/
```

### rm
#### 语法
rm [选项] 文件...
#### 描述
删除文件或目录
#### 选项
-f, --force        忽略不存在的文件，不提示
-i, --interactive  删除前询问
-r, -R, --recursive 递归删除目录
-v, --verbose      显示删除过程
#### 示例
```bash
# 删除单个文件
rm file.txt

# 强制删除文件
rm -f file.txt

# 递归删除目录
rm -r directory/

# 交互式删除（删除前询问）
rm -i important_file.txt
```

### ln
#### 语法
ln [选项] 目标 链接名
#### 描述
创建硬链接或符号链接
#### 选项
-s, --symbolic     创建符号链接
-f, --force        强制创建（删除已存在的目标）
-i, --interactive  覆盖前询问
-v, --verbose      显示详细过程
#### 示例
```bash
# 创建硬链接
ln source_file hard_link

# 创建符号链接
ln -s source_file symbolic_link

# 强制创建符号链接
ln -sf existing_target new_link

# 创建目录符号链接
ln -s /path/to/directory dir_link
```

## 第3章：文件内容和查看

### cat
#### 语法
cat [选项] [文件]...
#### 描述
连接文件并打印到标准输出
#### 选项
-n, --number       显示行号
-b, --number-nonblank 对非空行编号
-s, --squeeze-blank 压缩连续空行为一行
-E, --show-ends    在每行末尾显示$
-T, --show-tabs    显示制表符为^I
#### 示例
```bash
# 显示文件内容
cat file.txt

# 显示带行号的内容
cat -n file.txt

# 合并多个文件
cat file1.txt file2.txt > combined.txt

# 显示不可见字符
cat -A file.txt
```

### tac
#### 语法
tac [选项] [文件]...
#### 描述
反向连接并打印文件内容（从最后一行开始）
#### 选项
-b, --before       在分隔符前附加而不是附加
-r, --regex        将分隔符视为正则表达式
-s, --separator=字符串 使用指定分隔符
#### 示例
```bash
# 反向显示文件内容
tac file.txt

# 反向合并多个文件
tac file1.txt file2.txt
```

### head
#### 语法
head [选项] [文件]...
#### 描述
显示文件开头部分
#### 选项
-n, --lines=[-]NUM 显示前NUM行（负数表示除最后NUM行外的所有行）
-c, --bytes=[-]NUM 显示前NUM字节
-q, --quiet        不显示文件头
-v, --verbose      总是显示文件头
#### 示例
```bash
# 显示文件前10行（默认）
head file.txt

# 显示文件前20行
head -n 20 file.txt

# 显示文件前100字节
head -c 100 file.txt

# 显示除最后5行外的所有行
head -n -5 file.txt
```

### tail
#### 语法
tail [选项] [文件]...
#### 描述
显示文件末尾部分
#### 选项
-n, --lines=[+]NUM 显示最后NUM行（+NUM表示从第NUM行开始）
-c, --bytes=[+]NUM 显示最后NUM字节
-f, --follow[=name|descriptor] 实时跟踪文件变化
-F                 等同于--follow=name --retry
#### 示例
```bash
# 显示文件最后10行（默认）
tail file.txt

# 显示文件最后20行
tail -n 20 file.txt

# 实时跟踪日志文件
tail -f /var/log/syslog

# 从第100行开始显示
tail -n +100 file.txt
```

### more
#### 语法
more [选项] 文件...
#### 描述
分页显示文件内容
#### 选项
-d                 显示帮助信息而不是响铃
-f                 计算逻辑行数而非屏幕行数
-l                 忽略换页符
-p                 清屏而不是滚动
-c                 清屏并从顶部开始显示
-s                 压缩连续空行为一行
-u                 抑制下划线
#### 示例
```bash
# 分页查看文件
more file.txt

# 压缩空行并分页查看
more -s long_file.txt
```

### less
#### 语法
less [选项] 文件...
#### 描述
更灵活的分页查看器
#### 选项
-N                 显示行号
-S                 截断长行而不是换行
-i                 搜索时忽略大小写
-I                 搜索时始终忽略大小写
-f                 强制打开特殊文件
-e, -E             退出后不返回到less
#### 示例
```bash
# 分页查看文件（带行号）
less -N file.txt

# 查看长行文件（不换行）
less -S wide_file.txt

# 忽略大小写搜索
less -i file.txt
```

### nl
#### 语法
nl [选项] [文件]...
#### 描述
对文件行进行编号
#### 选项
-b, --body-numbering=样式 主体行编号样式
-h, --header-numbering=样式 页眉行编号样式  
-f, --footer-numbering=样式 页脚行编号样式
-n, --number-format=格式 数字格式（ln, rn, rz）
-w, --number-width=数字 行号宽度
#### 示例
```bash
# 对所有行编号
nl file.txt

# 只对非空行编号
nl -ba file.txt

# 设置行号宽度为3位
nl -w3 file.txt

# 右对齐行号
nl -n rn file.txt
```

### wc
#### 语法
wc [选项] [文件]...
#### 描述
统计文件的行数、字数和字节数
#### 选项
-c, --bytes        显示字节数
-m, --chars        显示字符数
-l, --lines        显示行数
-w, --words        显示字数
-L, --max-line-length 显示最长行长度
#### 示例
```bash
# 显示文件的行数、字数、字节数
wc file.txt

# 只显示行数
wc -l file.txt

# 只显示字数
wc -w file.txt

# 统计多个文件
wc *.txt
```

### od
#### 语法
od [选项] [文件]...
#### 描述
以八进制或其他格式转储文件
#### 选项
-A, --address-radix=RADIX 输出地址的基数（d, o, x, n）
-t, --format=TYPE  指定输出格式（a, c, d, f, o, u, x）
-N, --read-bytes=BYTES 限制读取字节数
-j, --skip-bytes=BYTES 跳过指定字节数
-v, --output-duplicates 不使用*省略重复行
#### 示例
```bash
# 以十六进制格式显示文件
od -tx1 file.bin

# 以字符格式显示
od -tc file.txt

# 显示前100字节
od -N 100 file.bin

# 跳过前50字节后显示
od -j 50 file.bin
```

## 第4章：文件权限和属性

### chmod
#### 语法
chmod [选项] 模式 文件...
#### 描述
更改文件权限
#### 选项
-c, --changes      类似--verbose但只报告实际更改
-f, --silent       抑制大多数错误消息
-v, --verbose      输出诊断信息
-R, --recursive    递归更改目录及内容
#### 示例
```bash
# 使用符号模式设置权限
chmod u+x script.sh
chmod go-rwx secret.txt
chmod a+r file.txt

# 使用数字模式设置权限
chmod 755 script.sh
chmod 644 document.txt
chmod 600 private.key

# 递归设置目录权限
chmod -R 755 /path/to/directory
```

### chown
#### 语法
chown [选项] 所有者[:组] 文件...
#### 描述
更改文件所有者和组
#### 选项
-c, --changes      类似--verbose但只报告实际更改
-f, --silent       抑制错误消息
-v, --verbose      输出诊断信息
-R, --recursive    递归更改目录及内容
--from=当前所有者:当前组 只更改匹配的文件
#### 示例
```bash
# 更改文件所有者
chown user file.txt

# 更改文件所有者和组
chown user:group file.txt
chown :group file.txt

# 递归更改目录所有权
chown -R user:group /path/to/directory

# 从参考文件复制所有权
chown --reference=ref_file target_file
```

### chgrp
#### 语法
chgrp [选项] 组 文件...
#### 描述
更改文件组所有权
#### 选项
-c, --changes      类似--verbose但只报告实际更改
-f, --silent       抑制错误消息
-v, --verbose      输出诊断信息
-R, --recursive    递归更改目录及内容
--reference=参考文件 使用参考文件的组
#### 示例
```bash
# 更改文件组
chgrp developers file.txt

# 递归更改目录组
chgrp -R developers /path/to/project

# 使用参考文件的组
chgrp --reference=ref_file target_file
```

### umask
#### 语法
umask [-p] [-S] [模式]
#### 描述
设置或显示文件创建掩码
#### 选项
-p                 以可重用格式输出
-S                 以符号格式输出
#### 示例
```bash
# 显示当前umask（八进制）
umask

# 显示当前umask（符号格式）
umask -S

# 设置umask为022（新文件权限为644，新目录为755）
umask 022

# 设置umask为007（组内完全访问，其他人无访问）
umask 007
```

### chattr
#### 语法
chattr [选项] 属性 文件...
#### 描述
更改文件属性（ext2/ext3/ext4文件系统）
#### 选项
-R                 递归更改目录及内容
-V                 详细输出
-f                 抑制大部分错误消息
#### 示例
```bash
# 设置不可变属性（需要root权限）
sudo chattr +i important_file.txt

# 设置追加-only属性
sudo chattr +a log_file.txt

# 移除不可变属性
sudo chattr -i important_file.txt

# 查看文件属性
lsattr file.txt
```

### lsattr
#### 语法
lsattr [选项] 文件...
#### 描述
列出文件属性（ext2/ext3/ext4文件系统）
#### 选项
-R                 递归列出目录及内容
-a                 列出所有文件（包括隐藏文件）
-d                 列出目录本身而非内容
-V                 显示版本信息
#### 示例
```bash
# 列出文件属性
lsattr file.txt

# 递归列出目录属性
lsattr -R /path/to/directory

# 列出所有文件属性（包括隐藏文件）
lsattr -a
```

### setfacl
#### 语法
setfacl [选项] 规则 文件...
#### 描述
设置文件访问控制列表（ACL）
#### 选项
-m                 修改ACL条目
-x                 删除ACL条目
-b                 删除所有扩展ACL条目
-k                 删除默认ACL
-R                 递归应用到目录
-d                 设置默认ACL
#### 示例
```bash
# 为用户添加读写权限
setfacl -m u:username:rw file.txt

# 为组添加读权限
setfacl -m g:groupname:r file.txt

# 删除特定用户的ACL条目
setfacl -x u:username file.txt

# 设置目录的默认ACL
setfacl -d -m u:username:rx /path/to/directory
```

### getfacl
#### 语法
getfacl [选项] 文件...
#### 描述
获取文件访问控制列表（ACL）
#### 选项
-a                 仅显示访问ACL
-d                 仅显示默认ACL
-R                 递归显示目录ACL
-E                 显示无效ACL条目
#### 示例
```bash
# 显示文件ACL
getfacl file.txt

# 递归显示目录ACL
getfacl -R /path/to/directory

# 仅显示访问ACL
getfacl -a file.txt
```

## 第5章：文本处理和搜索

### grep
#### 语法
grep [选项] 模式 [文件]...
#### 描述
搜索文本模式
#### 选项
-i, --ignore-case  忽略大小写
-v, --invert-match 反向匹配
-r, -R, --recursive 递归搜索目录
-l, --files-with-matches 只显示匹配的文件名
-n, --line-number  显示行号
-c, --count        显示匹配行数
-A NUM             显示匹配行及后面NUM行
-B NUM             显示匹配行及前面NUM行
-C NUM             显示匹配行及前后NUM行
-E, --extended-regexp 使用扩展正则表达式
-F, --fixed-strings 将模式视为固定字符串
#### 示例
```bash
# 基本搜索
grep "pattern" file.txt

# 忽略大小写搜索
grep -i "PATTERN" file.txt

# 递归搜索目录
grep -r "function" /path/to/code/

# 显示行号
grep -n "error" logfile.txt

# 反向匹配（显示不包含模式的行）
grep -v "debug" logfile.txt

# 显示匹配行及上下文
grep -C 2 "critical" logfile.txt
```

### egrep
#### 语法
egrep [选项] 模式 [文件]...
#### 描述
使用扩展正则表达式的grep（等同于grep -E）
#### 示例
```bash
# 使用扩展正则表达式
egrep "word1|word2" file.txt

# 匹配一个或多个字符
egrep "ab+c" file.txt
```

### fgrep
#### 语法
fgrep [选项] 字符串 [文件]...
#### 描述
将模式视为固定字符串的grep（等同于grep -F）
#### 示例
```bash
# 搜索包含特殊字符的字符串
fgrep ".*[]" file.txt

# 搜索多个固定字符串
fgrep -e "string1" -e "string2" file.txt
```

### sed
#### 语法
sed [选项] 脚本 [文件]...
#### 描述
流编辑器，用于文本转换
#### 选项
-e 脚本            添加脚本到执行队列
-f 脚本文件        从文件读取脚本
-n                 抑制自动打印模式空间
-i                 就地编辑文件
-r, --regexp-extended 使用扩展正则表达式
#### 示例
```bash
# 替换文本
sed 's/old/new/g' file.txt

# 删除空行
sed '/^$/d' file.txt

# 就地编辑文件
sed -i 's/old/new/g' file.txt

# 提取特定行范围
sed -n '10,20p' file.txt

# 多个替换操作
sed -e 's/foo/bar/g' -e 's/baz/qux/g' file.txt
```

### awk
#### 语法
awk [选项] '程序' 文件...
#### 描述
模式扫描和处理语言
#### 选项
-F 分隔符          设置字段分隔符
-v var=value       设置变量
-f 程序文件        从文件读取程序
#### 示例
```bash
# 打印第一列
awk '{print $1}' file.txt

# 使用自定义分隔符
awk -F ':' '{print $1}' /etc/passwd

# 条件处理
awk '$3 > 1000 {print $1}' /etc/passwd

# 计算总和
awk '{sum += $1} END {print sum}' numbers.txt

# 格式化输出
awk '{printf "%-20s %s\n", $1, $2}' data.txt
```

### cut
#### 语法
cut [选项] 文件...
#### 描述
删除文件的每一行的某些字段
#### 选项
-f, --fields=列表  选择字段
-d, --delimiter=分隔符 指定字段分隔符
-c, --characters=列表 选择字符
--complement       补充选择
#### 示例
```bash
# 提取第1和第3字段（以:分隔）
cut -d ':' -f 1,3 /etc/passwd

# 提取前10个字符
cut -c 1-10 file.txt

# 提取除第1字段外的所有字段
cut -d ',' -f 2- data.csv
```

### sort
#### 语法
sort [选项] 文件...
#### 描述
对文本行进行排序
#### 选项
-n                 按数值排序
-r                 反向排序
-k POS             按指定字段排序
-t SEP             指定字段分隔符
-u                 删除重复行
-f                 忽略大小写
#### 示例
```bash
# 按字母顺序排序
sort file.txt

# 按数值排序
sort -n numbers.txt

# 按第二字段排序（以:分隔）
sort -t ':' -k 2 /etc/passwd

# 反向排序并去重
sort -ru file.txt
```

### uniq
#### 语法
uniq [选项] [输入文件] [输出文件]
#### 描述
报告或忽略重复行
#### 选项
-c                 显示每行出现次数
-d                 只显示重复行
-u                 只显示唯一行
-i                 忽略大小写
#### 示例
```bash
# 删除相邻重复行
uniq file.txt

# 显示每行出现次数
uniq -c file.txt

# 只显示重复行
uniq -d file.txt

# 结合sort使用（处理所有重复行）
sort file.txt | uniq -c
```

### tr
#### 语法
tr [选项] 集合1 [集合2]
#### 描述
转换或删除字符
#### 选项
-d                 删除字符
-s                 压缩重复字符
-c                 使用补集
#### 示例
```bash
# 转换大小写
tr 'a-z' 'A-Z' < file.txt

# 删除数字
tr -d '0-9' < file.txt

# 压缩空格
tr -s ' ' < file.txt

# 删除换行符
tr -d '\n' < file.txt
```

## 第6章：压缩和解压

### tar
#### 语法
tar [选项] [归档文件] [文件]...
#### 描述
创建和操作tar归档文件
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
# 创建gzip压缩的tar归档
tar -czvf archive.tar.gz directory/

# 创建bzip2压缩的tar归档
tar -cjvf archive.tar.bz2 directory/

# 创建xz压缩的tar归档
tar -cJvf archive.tar.xz directory/

# 提取tar归档
tar -xvf archive.tar

# 提取gzip压缩的tar归档
tar -xzvf archive.tar.gz

# 列出归档内容
tar -tvf archive.tar

# 创建归档时排除特定文件
tar -czvf archive.tar.gz --exclude='*.log' directory/
```

### gzip
#### 语法
gzip [选项] [文件]...
#### 描述
压缩或解压缩文件（使用Lempel-Ziv编码）
#### 选项
-d, --decompress   解压缩
-c, --stdout       写到标准输出
-k, --keep         保留原始文件
-l, --list         列出压缩文件信息
-r, --recursive    递归压缩目录
-v, --verbose      详细输出
-1..-9             压缩级别（1最快，9最好）
#### 示例
```bash
# 压缩文件
gzip file.txt

# 解压缩文件
gzip -d file.txt.gz

# 保持原始文件
gzip -k file.txt

# 列出压缩信息
gzip -l file.txt.gz

# 最快压缩
gzip -1 large_file.txt

# 最佳压缩
gzip -9 large_file.txt
```

### gunzip
#### 语法
gunzip [选项] [文件]...
#### 描述
解压缩gzip文件（等同于gzip -d）
#### 示例
```bash
# 解压缩gzip文件
gunzip file.txt.gz

# 解压缩到标准输出
gunzip -c file.txt.gz > file.txt
```

### bzip2
#### 语法
bzip2 [选项] [文件]...
#### 描述
压缩或解压缩文件（使用Burrows-Wheeler算法）
#### 选项
-d, --decompress   解压缩
-c, --stdout       写到标准输出
-k, --keep         保留原始文件
-f, --force        强制覆盖
-v, --verbose      详细输出
-1..-9             压缩级别（1最快，9最好）
#### 示例
```bash
# 压缩文件
bzip2 file.txt

# 解压缩文件
bzip2 -d file.txt.bz2

# 保持原始文件
bzip2 -k file.txt

# 最佳压缩
bzip2 -9 large_file.txt
```

### bunzip2
#### 语法
bunzip2 [选项] [文件]...
#### 描述
解压缩bzip2文件（等同于bzip2 -d）
#### 示例
```bash
# 解压缩bzip2文件
bunzip2 file.txt.bz2

# 解压缩到标准输出
bunzip2 -c file.txt.bz2 > file.txt
```

### xz
#### 语法
xz [选项] [文件]...
#### 描述
压缩或解压缩文件（使用LZMA算法）
#### 选项
-d, --decompress   解压缩
-c, --stdout       写到标准输出
-k, --keep         保留原始文件
-f, --force        强制覆盖
-v, --verbose      详细输出
-0..-9             压缩预设（0最快，9最好）
--threads=NUM      使用多线程
#### 示例
```bash
# 压缩文件
xz file.txt

# 解压缩文件
xz -d file.txt.xz

# 保持原始文件
xz -k file.txt

# 使用多线程压缩
xz -T 4 large_file.txt

# 最佳压缩
xz -9 large_file.txt
```

### zip
#### 语法
zip [选项] 归档文件 文件...
#### 描述
创建ZIP归档文件
#### 选项
-r                 递归压缩目录
-e                 加密归档
-P 密码            设置密码（不安全）
-9                 最佳压缩
-v                 详细输出
--exclude=GLOB     排除文件
#### 示例
```bash
# 创建ZIP归档
zip archive.zip file1.txt file2.txt

# 递归压缩目录
zip -r archive.zip directory/

# 最佳压缩
zip -9 archive.zip files/

# 排除特定文件
zip -r archive.zip directory/ --exclude="*.log"

# 加密归档（交互式输入密码）
zip -e secure.zip sensitive_files/
```

### unzip
#### 语法
unzip [选项] 归档文件 [文件]...
#### 描述
提取ZIP归档文件
#### 选项
-l                 列出归档内容
-v                 详细列出归档内容
-t                 测试归档完整性
-o                 覆盖现有文件（不提示）
-n                 不覆盖现有文件
-d 目录            提取到指定目录
-P 密码            设置密码（不安全）
#### 示例
```bash
# 提取ZIP归档
unzip archive.zip

# 列出归档内容
unzip -l archive.zip

# 测试归档完整性
unzip -t archive.zip

# 提取到指定目录
unzip archive.zip -d /path/to/extract/

# 覆盖现有文件
unzip -o archive.zip
```

### 7z
#### 语法
7z [命令] [选项] 归档文件 [文件]...
#### 描述
7-Zip文件归档器
#### 命令
a                  添加文件到归档
e                  提取文件（不保留路径）
x                  提取文件（保留完整路径）
l                  列出归档内容
t                  测试归档完整性
d                  从归档中删除文件
u                  更新归档中的文件
#### 选项
-m0=method         设置压缩方法
-mx=N              设置压缩级别（0-9）
-p密码             设置密码
-ttype             设置归档类型
#### 示例
```bash
# 创建7z归档
7z a archive.7z files/

# 提取7z归档（保留路径）
7z x archive.7z

# 列出归档内容
7z l archive.7z

# 创建加密归档
7z a -p archive.7z sensitive_files/

# 最佳压缩
7z a -mx=9 archive.7z files/

# 测试归档完整性
7z t archive.7z
```