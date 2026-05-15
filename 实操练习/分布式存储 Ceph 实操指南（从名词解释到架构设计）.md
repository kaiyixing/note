# 分布式存储 Ceph 实操指南（从"名词解释"到"架构设计"）

以下是两个核心任务的完整实验手册，建议在**3台虚拟机环境**中操作。

------

## 📋 实验环境准备

### 软件与硬件要求

| 项目          | 要求                                    | 说明                         |
| ------------- | --------------------------------------- | ---------------------------- |
| **操作系统**  | Rocky Linux 8 / CentOS 8 / Ubuntu 22.04 | 推荐 Rocky Linux 8           |
| **Ceph 版本** | Quincy (17.x) / Reef (18.x)             | 当前稳定版本                 |
| **部署方式**  | Cephadm (容器化) / Ceph-deploy          | 推荐 Cephadm                 |
| **节点数量**  | 最少 3 节点                             | 生产环境建议 5+              |
| **内存**      | 每节点 8GB+                             | MON 和 OSD 需要足够内存      |
| **磁盘**      | 每节点 2 块盘                           | 1 块系统盘 + 1 块 OSD 数据盘 |
| **网络**      | 万兆网络推荐                            | 公共网络 + 集群网络分离      |

### 实验拓扑设计

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Ceph 存储集群 (3 节点)                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐            │
│   │   ceph-node1    │    │   ceph-node2    │    │   ceph-node3    │            │
│   │   192.168.1.11  │    │   192.168.1.12  │    │   192.168.1.13  │            │
│   │                 │    │                 │    │                 │            │
│   │  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │            │
│   │  │   MON     │  │    │  │   MON     │  │    │  │   MON     │  │            │
│   │  │   MGR     │  │    │  │   OSD     │  │    │  │   OSD     │  │            │
│   │  │   OSD     │  │    │  │           │  │    │  │           │  │            │
│   │  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │            │
│   │                 │    │                 │    │                 │            │
│   │  /dev/sdb OSD   │    │  /dev/sdb OSD   │    │  /dev/sdb OSD   │            │
│   └────────┬────────┘    └────────┬────────┘    └────────┬────────┘            │
│            │                      │                      │                       │
│            └──────────────────────┼──────────────────────┘                       │
│                                   │                                               │
│                          ┌────────▼────────┐                                     │
│                          │   Ceph 客户端    │                                     │
│                          │  (RBD/RGW/CephFS)│                                     │
│                          └─────────────────┘                                     │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

------

## 🔴 任务 A：理解 Pool 类型

### A1：Pool 类型对比表

```
┌──────────────────┬─────────────────────┬─────────────────────┬─────────────────┐
│      特性        │    Replicated Pool  │  Erasure Coded Pool │     备注        │
├──────────────────┼─────────────────────┼─────────────────────┼─────────────────┤
│   中文名         │      副本池         │      纠删码池       │                 │
│   数据冗余       │   多份完整拷贝      │   分片 + 校验块     │                 │
│   存储空间       │   3 副本 = 300%      │   EC 4+2 = 150%     │   EC 更节省     │
│   读写性能       │   高 (直接读写)     │   中 (需计算)       │   副本池更快    │
│   CPU 开销       │   低                │   高 (编解码计算)   │                 │
│   适用场景       │   RBD 块存储        │   RGW 对象存储      │                 │
│   最小 OSD 数    │   3                 │   5+ (推荐)         │   EC 要求更高   │
│   数据一致性     │   强一致性          │   最终一致性        │                 │
│   故障恢复       │   快 (直接拷贝)     │   慢 (需重新计算)   │                 │
│   类比 RAID      │   RAID 1            │   RAID 5/6          │                 │
└──────────────────┴─────────────────────┴─────────────────────┴─────────────────┘
```

### A2：副本池 (Replicated Pool) 创建与使用

```bash
# ==================== 1. 创建副本池 ====================

# 1.1 创建用于 RBD 的副本池（3 副本）
ceph osd pool create rbd-pool 128 128 replicated
# 参数说明：
# - rbd-pool: 池名称
# - 128: PG 数量 (Placement Group)
# - 128: PGP 数量 (Placement Group for Placement)
# - replicated: 池类型

# 1.2 设置池的应用类型（必须！否则无法使用）
ceph osd pool application enable rbd-pool rbd

# 1.3 设置副本数（默认 3，可调整）
ceph osd pool set rbd-pool size 3
ceph osd pool set rbd-pool min_size 2  # 最小可用副本数

# 1.4 查看池配置
ceph osd pool ls detail
ceph osd pool get rbd-pool all

# ==================== 2. 创建 RBD 镜像 ====================

# 2.1 初始化 RBD 池
rbd pool init rbd-pool

# 2.2 创建 RBD 镜像（块设备）
rbd create --size 10240 rbd-pool/my-image
# 创建 10GB 的块设备

# 2.3 查看 RBD 镜像
rbd ls rbd-pool
rbd info rbd-pool/my-image

# 2.4 映射 RBD 镜像到本地（像硬盘一样使用）
rbd map rbd-pool/my-image
# 输出：/dev/rbd0

# 2.5 格式化并挂载
mkfs.xfs /dev/rbd0
mkdir /mnt/ceph-rbd
mount /dev/rbd0 /mnt/ceph-rbd

# 2.6 测试读写
dd if=/dev/zero of=/mnt/ceph-rbd/testfile bs=1M count=100
ls -lh /mnt/ceph-rbd/

# 2.7 卸载并取消映射
umount /mnt/ceph-rbd
rbd unmap /dev/rbd0

# ==================== 3. 性能测试 ====================

# 3.1 使用 fio 测试读写性能
fio --name=randwrite --ioengine=librbd --pool=rbd-pool \
    --rbdname=my-image --rw=randwrite --bs=4k --size=1G \
    --numjobs=4 --runtime=60 --group_reporting

# 3.2 测试顺序读写
fio --name=seqread --ioengine=librbd --pool=rbd-pool \
    --rbdname=my-image --rw=read --bs=1M --size=1G \
    --numjobs=1 --runtime=60 --group_reporting
```

### A3：纠删码池 (Erasure Coded Pool) 创建与使用

```bash
# ==================== 1. 创建纠删码配置 ====================

# 1.1 创建纠删码配置方案（4+2，即 4 个数据块 +2 个校验块）
ceph osd erasure-code-profile set ec-profile \
    k=4 m=2 crush-failure-domain=host
# 参数说明：
# - k=4: 数据块数量
# - m=2: 校验块数量
# - 存储利用率 = k/(k+m) = 4/6 = 67%
# - 可容忍 m=2 个 OSD 同时故障

# 1.2 查看纠删码配置
ceph osd erasure-code-profile get ec-profile
ceph osd erasure-code-profile ls

# ==================== 2. 创建纠删码池 ====================

# 2.1 创建用于 RGW 的纠删码池
ceph osd pool create rgw-pool 128 128 erasure ec-profile
# 注意：EC 池需要更多 OSD（至少 k+m=6 个 OSD）

# 2.2 设置应用类型
ceph osd pool application enable rgw-pool rgw

# 2.3 查看池配置
ceph osd pool get rgw-pool all
ceph osd pool ls detail

# ==================== 3. 创建 RGW 对象存储 ====================

# 3.1 创建 RGW 用户
radosgw-admin user create --uid="testuser" --display-name="Test User"

# 3.2 创建 RGW 存储池（需要多个池）
ceph osd pool create .rgw.buckets 128 128 erasure ec-profile
ceph osd pool application enable .rgw.buckets rgw

# 3.3 配置 RGW 使用纠删码池（在 ceph.conf 中）
# [client.rgw.ceph-node1]
# rgw_pool_prefix = .rgw
# rgw_data = /var/lib/ceph/rgw/ceph-rgw.ceph-node1

# ==================== 4. 使用 S3 API 测试 ====================

# 4.1 安装 S3 客户端
pip install boto3

# 4.2 Python 测试脚本
cat > test-s3.py << 'EOF'
import boto3
from boto3.s3.transfer import S3Transfer

# 配置 S3 客户端
s3 = boto3.client('s3',
    endpoint_url='http://192.168.1.11:7480',
    aws_access_key_id='YOUR_ACCESS_KEY',
    aws_secret_access_key='YOUR_SECRET_KEY',
    config=boto3.session.Config(signature_version='s3v4'))

# 创建桶
s3.create_bucket(Bucket='test-bucket')

# 上传文件
with open('/etc/passwd', 'rb') as f:
    s3.upload_fileobj(f, 'test-bucket', 'passwd')

# 列出对象
response = s3.list_objects_v2(Bucket='test-bucket')
print(response['Contents'])

# 下载文件
with open('/tmp/passwd-downloaded', 'wb') as f:
    s3.download_fileobj('test-bucket', 'passwd', f)
EOF

python3 test-s3.py
```

### A4：两种 Pool 性能对比测试

```bash
# ==================== 1. 空间占用对比 ====================

# 1.1 查看池使用统计
ceph df
ceph df detail

# 输出示例：
# POOL           USED     AVAILABLE   RAW USED   %RAW USED
# rbd-pool       10 GiB   100 GiB     30 GiB   30%      # 3 副本
# rgw-pool       10 GiB   100 GiB     15 GiB   15%      # EC 4+2

# 1.2 计算实际空间利用率
# 副本池：10GB 数据 = 30GB 实际占用 (3 副本)
# 纠删码池：10GB 数据 = 15GB 实际占用 (4+2 EC)

# ==================== 2. 读写性能对比 ====================

# 2.1 副本池性能测试
rbd create --size 10240 rbd-pool/perf-test-rep
rbd map rbd-pool/perf-test-rep

fio --name=rep-write --filename=/dev/rbd0 --ioengine=libaio \
    --rw=write --bs=4k --size=1G --numjobs=4 \
    --runtime=60 --group_reporting --direct=1

# 预期：IOPS 8000-15000，延迟 1-5ms

# 2.2 纠删码池性能测试（需要创建 RBD over EC，不推荐但可测试）
# 注意：EC 池通常不用于 RBD，这里仅做对比

# ==================== 3. 故障恢复测试 ====================

# 3.1 模拟 OSD 故障
ceph osd down 0
ceph osd out 0

# 3.2 观察恢复过程
ceph -w  # 实时监控
ceph -s  # 查看集群状态

# 3.3 副本池恢复速度
# - 直接拷贝数据到新 OSD
# - 恢复速度快

# 3.4 纠删码池恢复速度
# - 需要读取其他分片重新计算
# - 恢复速度慢，CPU 开销大

# 3.5 恢复 OSD
ceph osd in 0
ceph osd up 0
```

### A5：Pool 管理命令速查表

```bash
# 创建池
ceph osd pool create <pool-name> <pg-num> <pgp-num> [replicated|erasure]

# 删除池（危险！）
ceph osd pool delete <pool-name> <pool-name> --yes-i-really-really-mean-it

# 查看池
ceph osd pool ls
ceph osd pool ls detail
ceph osd pool get <pool-name> all

# 修改池配置
ceph osd pool set <pool-name> size 3          # 副本数
ceph osd pool set <pool-name> min_size 2      # 最小副本数
ceph osd pool set <pool-name> pg_num 256      # PG 数量
ceph osd pool set <pool-name> pgp_num 256     # PGP 数量

# 查看 PG 状态
ceph pg dump
ceph pg dump_stuck
ceph pg ls

# 查看 OSD 状态
ceph osd tree
ceph osd stat
ceph osd df
```

------

## 🔴 任务 B：部署规划

### B1：3 节点 Ceph 集群规划

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         3 节点 Ceph 集群部署规划                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                        节点规划表                                        │   │
│  ├──────────┬──────────────┬──────────────┬──────────────┬───────────────┤   │
│  │  节点    │     IP       │    MON       │    MGR       │     OSD       │   │
│  ├──────────┼──────────────┼──────────────┼──────────────┼───────────────┤   │
│  │ node1    │ 192.168.1.11 │     ✓        │     ✓        │  /dev/sdb     │   │
│  │ node2    │ 192.168.1.12 │     ✓        │              │  /dev/sdb     │   │
│  │ node3    │ 192.168.1.13 │     ✓        │              │  /dev/sdb     │   │
│  └──────────┴──────────────┴──────────────┴──────────────┴───────────────┘   │
│                                                                                 │
│  说明：                                                                          │
│  - MON: 3 个（奇数，满足法定人数 quorum）                                        │
│  - MGR: 1 个主 + 可配置 standby                                                  │
│  - OSD: 每节点 1 块数据盘，共 3 个 OSD                                           │
│  - 网络：公共网络 + 集群网络（生产环境建议分离）                                 │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### B2：系统初始化（所有节点执行）

```bash
# ==================== 1. 系统准备 ====================

# 1.1 配置主机名
hostnamectl set-hostname ceph-node1  # 各节点分别设置

# 1.2 配置 hosts 解析
cat >> /etc/hosts << EOF
192.168.1.11 ceph-node1
192.168.1.12 ceph-node2
192.168.1.13 ceph-node3
EOF

# 1.3 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

# 1.4 关闭 SELinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

# 1.5 配置 NTP 时间同步（重要！Ceph 对时间敏感）
yum install -y chrony
systemctl enable chronyd
systemctl start chronyd
chronyc sources -v

# 1.6 调整内核参数
cat >> /etc/sysctl.conf << EOF
vm.swappiness = 0
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.core.somaxconn = 65535
net.ipv4.ip_local_port_range = 1024 65535
EOF
sysctl -p

# 1.7 安装必要工具
yum install -y vim wget curl net-tools lvm2 xfsprogs

# ==================== 2. 准备 OSD 磁盘 ====================

# 2.1 查看磁盘
lsblk
fdisk -l

# 2.2 清除磁盘原有数据（危险操作！确认是数据盘）
sgdisk --zap-all /dev/sdb
dd if=/dev/zero of=/dev/sdb bs=1M count=100 oflag=direct,dsync
blkdiscard /dev/sdb

# 2.3 创建分区（可选，Cephadm 会自动处理）
# 让 Ceph 直接管理整块磁盘
```

### B3：使用 Cephadm 部署集群

```bash
# ==================== 1. 在 node1 上部署 ====================

# 1.1 安装 Cephadm
curl --silent --remote-name --location \
    https://github.com/ceph/ceph/raw/quincy/src/cephadm/cephadm
chmod +x cephadm
mv cephadm /usr/local/bin/

# 1.2 验证 cephadm
cephadm --version

# 1.3 引导新集群
cephadm bootstrap --mon-ip 192.168.1.11 \
    --dashboard-password-noprompt \
    --dashboard-password admin123 \
    --allow-overwrite

# 输出重要信息（保存！）：
# Ceph Dashboard is now available at:
# https://ceph-node1:8443/
# Username: admin
# Password: admin123

# 1.4 配置 SSH 免密（用于添加其他节点）
ssh-keygen -t rsa -N ""
ssh-copy-id root@ceph-node2
ssh-copy-id root@ceph-node3

# 1.5 添加其他节点到集群
ceph orch host add ceph-node2 192.168.1.12
ceph orch host add ceph-node3 192.168.1.13

# 1.6 查看主机状态
ceph orch host ls

# ==================== 2. 添加 OSD ====================

# 2.1 查看可用磁盘
ceph orch device ls

# 2.2 自动使用所有可用磁盘创建 OSD
ceph orch apply osd --all-available-devices

# 或手动指定磁盘
ceph orch daemon add osd ceph-node1:/dev/sdb
ceph orch daemon add osd ceph-node2:/dev/sdb
ceph orch daemon add osd ceph-node3:/dev/sdb

# 2.3 查看 OSD 状态
ceph osd tree
ceph osd stat

# ==================== 3. 添加 MGR ====================

# 3.1 查看 MGR 状态
ceph mgr stat
ceph mgr ls

# 3.2 添加备用 MGR（可选）
ceph orch apply mgr ceph-node2

# ==================== 4. 查看集群状态 ====================

# 4.1 集群健康状态
ceph status
ceph -s
ceph -w  # 实时监控

# 4.2 查看 Dashboard
# 浏览器访问：https://192.168.1.11:8443
# 用户名：admin
# 密码：admin123
```

### B4：CRUSH 算法与故障域配置

```bash
# ==================== 1. 理解 CRUSH 算法 ====================

# CRUSH = Controlled Replication Under Scalable Hashing
# 核心思想：客户端自行计算数据位置，无需查询中心服务器

# 1.1 查看 CRUSH Map
ceph osd getcrushmap -o crushmap.txt
crushtool -d crushmap.txt -o crushmap-decomp.txt
cat crushmap-decomp.txt

# 1.2 CRUSH Map 结构
# - tunables: 算法参数
# - types: 设备类型定义 (osd, host, rack, row, room, datacenter, region)
# - buckets: 存储桶层次结构
# - rules: 数据分布规则

# 1.3 查看 CRUSH 层次结构
ceph osd tree
ceph osd tree show-weights

# ==================== 2. 配置故障域 ====================

# 2.1 查看当前故障域配置
ceph osd crush rule dump replicated_rule

# 2.2 创建自定义 CRUSH 规则（按主机故障域）
ceph osd crush rule create-replicated host-rule host replicated_rule

# 2.3 创建自定义 CRUSH 规则（按机架故障域）
# 首先需要定义机架层次
ceph osd crush set-device-class ssd hdd

# 添加机架层级
ceph osd crush add-bucket rack01 rack
ceph osd crush add-bucket rack02 rack
ceph osd crush add-bucket rack03 rack

# 将主机移动到机架下
ceph osd crush move ceph-node1 host=ceph-node1 rack=rack01
ceph osd crush move ceph-node2 host=ceph-node2 rack=rack02
ceph osd crush move ceph-node3 host=ceph-node3 rack=rack03

# 创建机架级别的 CRUSH 规则
ceph osd crush rule create-replicated rack-rule rack replicated_rule

# 2.4 应用 CRUSH 规则到池
ceph osd pool set rbd-pool crush_rule host-rule
ceph osd pool set rgw-pool crush_rule rack-rule

# ==================== 3. 故障域级别对比 ====================

# 故障域级别    | 容忍故障        | 适用场景
# -------------|----------------|------------------
# osd          | 单盘故障        | 测试环境
# host         | 单节点故障      | 生产环境（推荐）
# rack         | 单机架故障      | 大型数据中心
# datacenter   | 单数据中心故障  | 多活架构
# region       | 单地域故障      | 跨地域容灾
```

### B5：故障场景模拟与恢复

```bash
# ==================== 场景 1：单块 OSD 磁盘故障 ====================

# 1.1 模拟 OSD 故障
ceph osd down 0
ceph osd out 0

# 1.2 查看集群状态
ceph -s
# 预期：HEALTH_WARN, 1 OSD down, 1 OSD out

# 1.3 查看数据恢复进度
ceph -w
ceph pg dump | grep -i recovering

# 1.4 副本池恢复过程
# - 检测到其他 OSD 上有完整副本
# - 直接拷贝数据到新 OSD
# - 恢复速度快

# 1.5 纠删码池恢复过程
# - 需要读取 k=4 个数据分片
# - 重新计算丢失的分片
# - 恢复速度慢，CPU 开销大

# 1.6 恢复 OSD
ceph osd in 0
ceph osd up 0

# 1.7 验证数据完整性
rbd ls rbd-pool
rbd info rbd-pool/my-image

# ==================== 场景 2：单节点整机故障 ====================

# 2.1 模拟节点宕机（在 node2 上执行）
systemctl stop ceph-*.service
# 或
shutdown -h now

# 2.2 在管理节点查看集群状态
ceph -s
# 预期：HEALTH_WARN, 1 OSD down, quorum 正常（3 MON 中 2 个在线）

# 2.3 查看数据分布
ceph pg dump | grep -i inactive
ceph pg ls

# 2.4 故障域为 host 时的表现
# - 该节点上的所有 OSD 标记为 down
# - 数据在其他节点上有副本
# - 服务不中断

# 2.5 恢复节点
# 启动节点后，Ceph 会自动重新加入集群
systemctl start ceph-*.service

# 2.6 观察数据再平衡
ceph -w
# 数据会自动回迁到恢复的节点

# ==================== 场景 3：单机架故障（需要机架级故障域） ====================

# 3.1 模拟机架故障（关闭 rack01 下所有节点）
# 在 ceph-node1 上执行
shutdown -h now

# 3.2 查看集群状态
ceph -s
# 预期：HEALTH_WARN, 但数据可访问（如果配置了机架级冗余）

# 3.3 机架级故障域要求
# - 至少 3 个机架
# - 每个机架有足够 OSD
# - CRUSH 规则配置为 rack 级别

# 3.4 验证数据可用性
rbd ls rbd-pool
# 应该能正常列出

# ==================== 场景 4：MON 节点故障 ====================

# 4.1 查看 MON 状态
ceph mon stat
ceph mon dump

# 4.2 模拟 MON 故障
systemctl stop ceph-mon.ceph-node1

# 4.3 查看法定人数
# 3 个 MON，需要 2 个在线才能形成 quorum
ceph quorum_status

# 4.4 恢复 MON
systemctl start ceph-mon.ceph-node1

# 4.5 添加新 MON（如果原 MON 无法恢复）
ceph orch apply mon ceph-node4
```

### B6：思考题解答

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              面试思考题解答                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  【问题 1】如果坏了一块盘，数据怎么恢复？                                        │
│                                                                                 │
│  【回答】                                                                        │
│  1. Ceph 会自动检测 OSD 故障（通过心跳机制）                                     │
│  2. MON 将该 OSD 标记为 down 和 out                                              │
│  3. PG（Placement Group）进入 degraded 状态                                     │
│  4. 根据池类型进行恢复：                                                         │
│     - 副本池：从其他副本直接拷贝数据到新 OSD，速度快                             │
│     - 纠删码池：读取 k 个数据分片，重新计算丢失的分片，速度慢                    │
│  5. 恢复完成后，PG 状态变为 active+clean                                         │
│  6. 使用 ceph -w 可以实时监控恢复进度                                            │
│                                                                                 │
│  关键命令：                                                                      │
│  ceph osd down <osd-id>     # 标记 OSD 为 down                                  │
│  ceph osd out <osd-id>      # 将 OSD 移出集群                                   │
│  ceph -w                  # 监控恢复过程                                        │
│                                                                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  【问题 2】如果坏了一个机架，数据还在吗？                                        │
│                                                                                 │
│  【回答】                                                                        │
│  这取决于 CRUSH Map 的故障域配置：                                               │
│                                                                                 │
│  情况 1：故障域配置为 host（默认）                                               │
│  - 只保证单节点故障时数据可用                                                    │
│  - 如果整个机架宕机，可能多个节点同时故障                                        │
│  - 如果故障节点数超过副本数，数据会丢失                                          │
│                                                                                 │
│  情况 2：故障域配置为 rack                                                       │
│  - Ceph 会将副本分散到不同机架                                                   │
│  - 单机架故障时，其他机架有完整副本                                              │
│  - 数据仍然可用，服务不中断                                                      │
│                                                                                 │
│  配置方法：                                                                      │
│  ceph osd crush rule create-replicated rack-rule rack replicated_rule           │
│  ceph osd pool set <pool-name> crush_rule rack-rule                             │
│                                                                                 │
│  要求：                                                                          │
│  - 至少 3 个机架                                                                 │
│  - 副本池：3 副本需要至少 3 个机架                                               │
│  - 纠删码池：EC 4+2 需要至少 3 个机架（每机架 2 个 OSD）                         │
│                                                                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  【问题 3】PG 数量如何计算？                                                     │
│                                                                                 │
│  【回答】                                                                        │
│  PG 数量计算公式：                                                               │
│  - 副本池：PG 总数 = (OSD 数量 × 100) / 副本数                                   │
│  - 纠删码池：PG 总数 = (OSD 数量 × 100) / (k+m)                                  │
│                                                                                 │
│  示例：3 个 OSD，3 副本                                                          │
│  PG 总数 = (3 × 100) / 3 = 100                                                   │
│  每个池的 PG 数 = PG 总数 / 池数量                                               │
│                                                                                 │
│  Ceph 推荐 PG 数量：                                                             │
│  - < 10 OSD: 32-128 PG                                                           │
│  - 10-50 OSD: 128-512 PG                                                         │
│  - 50-100 OSD: 512-1024 PG                                                       │
│  - > 100 OSD: 1024-4096 PG                                                       │
│                                                                                 │
│  设置命令：                                                                      │
│  ceph osd pool set <pool-name> pg_num 128                                        │
│  ceph osd pool set <pool-name> pgp_num 128                                       │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

------

## 🔴 Ceph 架构核心概念

### 核心组件说明

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            Ceph 核心组件                                        │
├──────────────┬──────────────────────────────────────────────────────────────────┤
│    组件      │                          说明                                    │
├──────────────┼──────────────────────────────────────────────────────────────────┤
│    MON       │ Monitor 监控守护进程，维护集群状态映射（OSD Map、PG Map 等）      │
│              │ - 至少 3 个（奇数），形成法定人数 quorum                          │
│              │ - 使用 Paxos 算法保证一致性                                       │
├──────────────┼──────────────────────────────────────────────────────────────────┤
│    MGR       │ Manager 管理守护进程，负责监控指标、Dashboard、REST API          │
│              │ - 至少 1 个，可配置 standby                                       │
│              │ - 提供 ceph-mgr-dashboard  Web 界面                              │
├──────────────┼──────────────────────────────────────────────────────────────────┤
│    OSD       │ Object Storage Device 对象存储守护进程，管理实际磁盘             │
│              │ - 每块磁盘一个 OSD 进程                                           │
│              │ - 负责数据读写、复制、恢复、再平衡                                │
│              │ - 至少 3 个才能形成副本                                           │
├──────────────┼──────────────────────────────────────────────────────────────────┤
│    MDS       │ Metadata Server 元数据服务器，仅 CephFS 需要                     │
│              │ - RBD 和 RGW 不需要 MDS                                           │
│              │ - 管理文件系统元数据（目录结构、权限等）                          │
├──────────────┼──────────────────────────────────────────────────────────────────┤
│   Client     │ 客户端，包括 RBD、RGW、CephFS 客户端                             │
│              │ - 直接与 OSD 通信（无需经过 MON）                                 │
│              │ - 使用 CRUSH 算法计算数据位置                                     │
└──────────────┴──────────────────────────────────────────────────────────────────┘
```

### 数据读写流程

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         Ceph 数据读写流程                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  【写数据流程】                                                                  │
│                                                                                 │
│  1. 客户端获取集群映射（从 MON）                                                 │
│     Client → MON: 获取 OSD Map、PG Map                                          │
│                                                                                 │
│  2. 客户端计算数据位置（CRUSH 算法）                                             │
│     Object Name → Hash → PG ID → OSD List                                       │
│                                                                                 │
│  3. 客户端写入数据（Primary OSD）                                                │
│     Client → Primary OSD: 写入数据                                              │
│                                                                                 │
│  4. Primary OSD 复制到其他 OSD                                                   │
│     Primary OSD → Secondary OSD: 复制数据                                       │
│                                                                                 │
│  5. 确认写入完成                                                                 │
│     Secondary OSD → Primary OSD → Client: 确认                                  │
│                                                                                 │
│  【读数据流程】                                                                  │
│                                                                                 │
│  1. 客户端计算数据位置（CRUSH 算法）                                             │
│  2. 客户端直接从 Primary OSD 读取数据                                            │
│  3. 如果 Primary 不可用，从 Secondary 读取                                       │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

------

## ✅ 实验完成检查清单

| 任务     | 完成标志               | 面试能说出                                                   |
| -------- | ---------------------- | ------------------------------------------------------------ |
| 任务 A   | 能创建两种 Pool 并对比 | "副本池用于 RBD，3 副本；纠删码池用于 RGW，4+2 节省空间"     |
| 任务 B   | 能规划 3 节点集群      | "MON 要 3 个奇数，OSD 每节点 1 块盘，CRUSH 配置 host 故障域" |
| 故障恢复 | 能模拟并修复故障       | "OSD down 后自动恢复，副本池直接拷贝，EC 池需重新计算"       |
| 架构理解 | 能解释数据流程         | "客户端用 CRUSH 计算位置，直接写 OSD，不需要经过 MON"        |

------

## 💡 面试话术模板

```
【面试官】：你了解 Ceph 吗？说说它的架构。

【回答】：
我部署过 3 节点的 Ceph 集群，使用 cephadm 容器化方式部署。

核心组件包括：
- MON：3 个监控节点，维护集群状态，使用 Paxos 保证一致性
- MGR：管理节点，提供 Dashboard 和监控指标
- OSD：每个磁盘一个 OSD 进程，负责实际数据存储

我创建过两种 Pool：
- 副本池：用于 RBD 块存储，3 副本，强一致性，读写性能高
- 纠删码池：用于 RGW 对象存储，4+2 EC，节省 50% 空间，但 CPU 开销大

故障恢复方面：
- 单盘故障：Ceph 自动检测，从其他副本恢复数据
- 单节点故障：配置 host 故障域，数据在其他节点有副本
- 单机架故障：配置 rack 故障域，副本分散到不同机架

数据读写流程：
- 客户端从 MON 获取集群映射
- 用 CRUSH 算法自行计算数据位置
- 直接写入 OSD，不需要经过中心服务器

我还配置过 CRUSH Map，调整故障域级别，从 host 到 rack，
确保不同级别的故障都能容忍。
```

------

## 📚 扩展学习建议

1. **CephFS 文件系统**：学习 MDS 配置和 POSIX 兼容
2. **性能调优**：学习 OSD 参数、网络优化、BLUESTORE 配置
3. **安全加固**：学习 CephX 认证、加密、网络隔离
4. **云原生集成**：学习 Ceph CSI、Rook、Kubernetes 集成
5. **认证考试**：Ceph 官方认证、OpenStack 存储专家

完成这两个任务后，你对 Ceph 的理解会从"名词解释"提升到"架构设计"级别，面试时能自信地说出具体配置和故障处理方案！