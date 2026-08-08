---
title: MySQL 主从复制与数据恢复（追溯·备份·恢复）
tags:
  - 数据库/MySQL
  - 主从复制
  - 备份恢复
---

# MySQL 主从复制与数据恢复（追溯·备份·恢复）

> 覆盖三大主题：**主从复制**（原理、架构、GTID、延迟、高可用）、**数据追溯**（binlog 追溯、闪回、PITR 时间点恢复）、**备份恢复**（逻辑备份、物理备份、全量+增量恢复）。是面试高频考点与生产必会技能。

---

## 一、主从复制概述

**主从复制（Master-Slave Replication）** 指将主库（Master）上的数据变更，通过 **Binlog** 实时同步到一台或多台从库（Slave），并在从库上重放，使从库与主库数据保持一致。

### 1.1 为什么需要主从复制

| 目的 | 说明 |
|------|------|
| **读写分离** | 主库承担写，从库承担读，分摊读压力，提升并发吞吐 |
| **高可用（HA）** | 主库故障时从库可切换为主库，缩短业务中断时间 |
| **数据备份** | 从库是主库的实时"备份"，可用来做备份/统计/分析，避免影响主库 |
| **容灾** | 跨机房/跨地域部署从库，防止单机房故障 |
| **在线迁移/升级** | 借助复制滚动升级数据库版本，平滑迁移 |

### 1.2 基本架构

```
                ┌─────────────────┐
  写入 ───────► │    Master 主库    │
                │    (可读可写)    │
                └────────┬────────┘
                         │ Binlog 推送
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
   ┌────────────┐  ┌────────────┐  ┌────────────┐
   │  Slave 从库1│  │  Slave 从库2│  │  Slave 从库N│
   │  (只读)    │  │  (只读)    │  │  (只读)    │
   └────────────┘  └────────────┘  └────────────┘
   读取 ────► 应用层按需路由到任意从库
```

---

## 二、主从复制原理

### 2.1 三个关键线程

主从复制由 **3 个线程**协作完成：

| 线程 | 所在节点 | 作用 |
|------|----------|------|
| `Binlog Dump Thread`（dump 线程） | 主库 | 读取 Binlog 并发送给从库的 IO 线程 |
| `IO Thread`（IO 线程） | 从库 | 接收主库推送的 Binlog，写入从库本地的 **Relay Log（中继日志）** |
| `SQL Thread`（SQL 线程） | 从库 | 读取 Relay Log 并重放其中的 SQL/事务，应用到从库数据 |

### 2.2 复制完整流程

```
1. 主库执行写操作（INSERT/UPDATE/DELETE/DDL），记录到 Binlog（事务提交时落盘）
2. 从库通过 CHANGE MASTER TO 建立连接，请求从指定 binlog 文件名+位置开始复制
3. 主库的 Binlog Dump 线程把新产生的 Binlog 推送给从库
4. 从库 IO 线程把收到的内容写入本地 Relay Log
5. 从库 SQL 线程读取 Relay Log，逐条/并行重放，更新从库数据
6. 从库更新 Master 状态信息（File、Position、GTID 等），用于断点续传
```

> 关键点：**主库负责"产生"日志，从库负责"拉取"与"重放"**。从库是主动发起连接的一方（`Slave_IO_Running`、`Slave_SQL_Running` 两个状态）。

### 2.3 为什么用 Binlog 而不是 Redo Log 复制？

| 对比项 | Binlog | Redo Log |
|--------|--------|----------|
| 归属 | **Server 层**，所有存储引擎共用 | **InnoDB 存储引擎层** |
| 内容 | 逻辑日志（记录 SQL 语句或行变更） | 物理日志（记录页的物理修改） |
| 记录时机 | 事务**提交时**生成 | 事务**执行过程**实时写入 |
| 存储方式 | 追加保存，不循环覆盖（可配置过期） | 循环写，空间有限，会被覆盖 |
| 用途 | 复制、备份恢复、闪回 | 崩溃恢复（Crash Recovery）、宕机不丢数据 |

Binlog 是"可追溯、可重放、可无限保留"的逻辑日志，天然适合做复制与恢复；Redo Log 只保证实例崩溃后 InnoDB 自身能恢复到一致状态，无法用于跨实例复制。

### 2.4 Binlog 的三种格式

| 格式 | 记录方式 | 优点 | 缺点 |
|------|----------|------|------|
| **STATEMENT** | 记录原始 SQL 语句 | 日志量小 | 部分函数/存储过程存在不确定性，结果不一致（如 `NOW()`、`UUID()`） |
| **ROW** | 记录每一行数据变更（前像/后像） | 最精确，与主库完全一致；支持闪回 | 日志量大 |
| **MIXED** | 混合模式：默认 STATEMENT，遇到不确定语句自动切换 ROW | 兼顾两者 | 对闪回不友好（大量 STATEMENT） |

> 生产建议：**优先使用 ROW 格式**。虽然日志量大，但复制最可靠，且是 binlog2sql、MyFlash 等闪回工具的前提。

### 2.5 三种复制方式

| 复制方式 | 说明 | 数据一致性 | 可用性 |
|----------|------|------------|--------|
| **异步复制（Async）** | 主库提交事务后立即返回成功，不等待从库确认 | 有数据丢失风险（主库宕机时未同步部分） | 主库性能最好，从库故障不影响主库 |
| **半同步复制（Semi-Sync）** | 至少 **1 个**从库 ACK 确认收到 Binlog 后，主库才提交返回 | 大幅降低丢数据风险 | 从库无响应时退化为异步（或阻塞） |
| **全同步复制（Sync）** | 所有从库都确认后才提交 | 最强一致 | 性能最差，可用性受从库影响 |

- 半同步默认设置：`rpl_semi_sync_master_enabled=1`、`rpl_semi_sync_slave_enabled=1`，从库数 `rpl_semi_sync_master_wait_for_slave_count`（5.7.4+）。
- **宕机后主从数据一致性的保证**：半同步确保「事务已提交」必然「Binlog 至少在一个从库」→ 切换后不丢已提交事务。

---

## 三、复制架构

| 架构 | 拓扑 | 适用场景 |
|------|------|----------|
| **一主一从** | M → S | 读写分离入门、备份 |
| **一主多从** | M → S1/S2/… | 高并发读、多业务线读 |
| **级联复制（多级）** | M → S1 → S2 | 减少主库 dump 压力、跨机房 |
| **双主（主主）** | M1 ⇄ M2 | 高可用互备（配合 VIP/中间件切换），需防止写冲突 |
| **环形/级联环** | M1→M2→M3→M1 | 不推荐，环断裂难处理 |

### 3.1 级联复制
- 中间层从库既是从库，又是下层从库的主库（需要开启 `log-slave-updates`，让它的 Relay Log 重放也写入自己的 Binlog）。
- 好处：主库只与少数几个从库直连，降低 dump 线程压力。

### 3.2 双主互备
- 两个库互为主从，各自开启 `log_slave_updates`、`auto_increment_offset` / `auto_increment_increment` 错开自增主键，避免写冲突。
- 通常配合 VIP 漂移或 MHA/Orchestrator 实现自动切换。

---

## 四、GTID 复制

### 4.1 什么是 GTID

**GTID（Global Transaction Identifier，全局事务标识符）** 是每个已提交事务的全局唯一 ID，格式：

```
GTID = source_id:transaction_id
示例：3E11FA47-71CA-11E1-9E33-C80AA9429562:23
```

- `source_id`：生成该事务的服务器 UUID（`server_uuid`）。
- `transaction_id`：在该服务器上的递增序号。
- GTID 全集记录在 `gtid_executed`，事务被跳过则写入 `gtid_purged`。

### 4.2 基于位置复制 vs GTID 复制

| 对比项 | 基于文件位置（File+Position） | 基于 GTID |
|--------|-------------------------------|-----------|
| 定位方式 | `binlog 文件名 + 偏移量` | `gtid_executed` 集合 |
| 操作复杂度 | 手动找 pos，易错（如从库与主库数据不同步时） | 自动匹配事务，无需手工定位 |
| 断点续传 | 依赖记录位置，可能重放/漏放 | 天然去重，每个事务只执行一次 |
| 主从切换 | 需重新找新主的 binlog pos | 切换无感，自动续传 |
| 限制 | 无 | 需注意跳过事务、临时表、非事务引擎等限制 |

### 4.3 开启与运维
```sql
-- 主从都要开启
SET GLOBAL gtid_mode = ON;          -- 8.0 直接 ON；5.7 需 ON_PERMISSIVE → OFF_PERMISSIVE → ON 平滑升级
SET GLOBAL enforce_gtid_consistency = ON;

-- 从库指定 GTID 位置建立复制
CHANGE MASTER TO
  MASTER_HOST='10.0.0.1',
  MASTER_USER='repl',
  MASTER_PASSWORD='xxx',
  MASTER_AUTO_POSITION=1;           -- 使用 GTID 自动定位

START SLAVE;
```

> 5.7 平滑开启 GTID 的三步：`OFF_PERMISSIVE` → `ON_PERMISSIVE` → `ON`，避免业务中断。

---

## 五、主从延迟（Replication Lag）

### 5.1 为什么会出现延迟

| 原因 | 说明 |
|------|------|
| **大事务** | 主库一条大事务秒级完成，从库重放需要更长时间 |
| **从库单线程回放** | 旧版 SQL 线程单线程重放，天然慢于主库并行写 |
| **从库繁忙** | 从库自身承担大量读/后台任务（备份、报表） |
| **硬件/网络差异** | 主从机器性能不一致、网络抖动 |
| **DDL 长时间锁表** | 从库重放 DDL 时阻塞 |
| **从库有查询占用锁** | 长查询与 SQL 线程抢资源 |

### 5.2 并行复制（MTS，Multi-Threaded Slave）

- **MySQL 5.6**：按数据库（schema）并行，粒度粗。
- **MySQL 5.7**：`slave_parallel_type=LOGICAL_CLOCK`，基于 **组提交（Group Commit）**，同一组提交的事务并行重放，粒度细。
- **MySQL 8.0**：`slave_parallel_workers` 更大范围并行 + binlog 事务压缩。
- 相关参数：`slave_parallel_workers`（并行线程数）、`slave_parallel_type`。

### 5.3 延迟监控与解决

```sql
SHOW SLAVE STATUS\G
-- 关注：Seconds_Behind_Master（主从延迟秒数）
--      Slave_IO_Running / Slave_SQL_Running 是否为 Yes
--      通过秒级对比：主库 show master status 的 pos 与从库 read pos 差距
```

解决手段：
1. 拆分大事务为小事务，分批提交。
2. 开启并行复制（MTS）。
3. 从库关闭 `sync_binlog`/降低 fsync 频率、提高性能（注意与备份场景权衡）。
4. 读写分离的路由层对"延迟敏感"请求强制走主库。
5. 监控 `Seconds_Behind_Master`，超过阈值告警；从库掉队严重时重建从库。

> `Seconds_Behind_Master` 的局限：主库无新事务时该值可能为 0，但实际差距仍存在；更可靠的是对比主从 binlog pos / GTID 集合。

---

## 六、故障处理与高可用

### 6.1 从库故障
- 影响主库：异步复制几乎无影响；半同步在等待窗口内可能阻塞写（可用超时降级：`rpl_semi_sync_master_timeout`）。
- 处理：排查 `Slave_SQL_Running=No` 的报错（如 1062 主键冲突、数据不一致），修复或重建从库。

### 6.2 主库故障切换（Failover）

**手动切换流程（核心思路）**：
1. 确认主库状态，避免脑裂（双主同时写）。
2. 选择**数据最完整**的从库（pos/GTID 最新）。
3. 在候选从库上：`STOP SLAVE; RESET SLAVE ALL;` 使其独立。
4. 补齐未同步的 Binlog（若有），保证不丢已提交事务。
5. 提升为新的主库，把其他从库重新指向它（`CHANGE MASTER TO ... MASTER_AUTO_POSITION=1`）。
6. 修改应用/中间件/客户端连接指向新主库；修复旧主库后作为从库重新挂载。

**自动切换工具**：
- **MHA（Master High Availability）**：经典方案，基于半同步+手动补 binlog，切换秒级到十秒级。
- **Orchestrator**：拓扑可视化、自动检测、可选 `recover` 自动切换，支持跨机房。
- **MySQL InnoDB Cluster / Group Replication（MGR）**：基于 Paxos 的组复制，官方原生，自动选主。
- **Proxy 层（ProxySQL / MyCat / ShardingSphere / 自研）**：路由层负责探测与切换。

### 6.3 数据一致性的关键
- 半同步 + `sync_binlog=1` + `innodb_flush_log_at_trx_commit=1` 双 1 配置 → 保证主库崩溃不丢已提交事务。
- 切换前用半同步确保"提交即复制到从库"，是**零丢失切换**的基础。

---

## 七、数据追溯（Traceability）

「追溯」指**从历史日志中还原"某笔数据在什么时间被改成了什么"**，常用于：定位线上数据异常、误操作责任追溯、以及最重要的**闪回恢复误删数据**。核心载体就是 **Binlog**。

### 7.1 用 mysqlbinlog 查看/追溯 Binlog

```bash
# 解析 binlog 为可读 SQL
mysqlbinlog --base64-output=DECODE-ROWS -v /var/lib/mysql/binlog.000023

# 按时间点追溯
mysqlbinlog --start-datetime="2026-08-01 10:00:00" \
            --stop-datetime="2026-08-01 12:00:00" binlog.000023

# 按位置点追溯（最精确）
mysqlbinlog --start-position=1560 --stop-position=4520 binlog.000023

# 指定具体表（ROW 格式下非常有用）
mysqlbinlog --base64-output=DECODE-ROWS -v \
            --database=order_db \
            --table=orders binlog.000024
```

- ROW 格式下每条变更会以 `### INSERT INTO ... VALUES (...)` / `### UPDATE` / `### DELETE` 形式展现前像（before-image）与后像（after-image）。
- 追溯结论 = 根据 `@2`、`@3` 等行内字段值，还原出该行某时刻的具体数据。

### 7.2 时间点恢复（PITR，Point-In-Time Recovery）

**原理**：`全量备份（恢复到某时间点） + 重放该时间点之后的 Binlog（增量） = 精确恢复到任意时刻**。

```bash
# 1. 从全量备份恢复基础数据
# 2. 找到全量备份时刻对应的 binlog 文件与 position
# 3. 重放之后的 binlog 到目标时间点（例如误删前 1 秒）
mysqlbinlog --start-position=1560 --stop-datetime="2026-08-01 11:59:59" \
  binlog.000023 binlog.000024 | mysql -uroot -p
```

> 前提：Binlog 从备份开始就保留完整（`expire_logs_days`/`binlog_expire_logs_seconds` 要覆盖恢复窗口）。

### 7.3 闪回（Flashback）：逆向恢复误操作

**闪回** = 基于 **ROW 格式** Binlog，把变更**逆向**生成反向 SQL：`DELETE` → `INSERT`、`UPDATE` 前后像互换、`INSERT` → `DELETE`，从而**撤销误操作**。

**常见工具**：
| 工具 | 特点 |
|------|------|
| **binlog2sql**（danfengcao） | 解析 ROW binlog 生成 SQL，支持从库在线、过滤库表、暂停恢复 |
| **MyFlash**（美团） | 高性能 binlog 回滚，生成回滚 SQL |
| **mysqlbinlog 逆向手写** | 无工具时的原始手段 |

**闪回通用流程（以 binlog2sql 为例）**：
```bash
# 1. 生成回滚 SQL（把误删/误更新转成反向语句）
python binlog2sql/binlog2sql.py \
  -h主库IP -P3306 -uroot -p'pwd' \
  -d order_db -t orders \
  --start-file='binlog.000024' --start-pos=1560 --stop-pos=4520 -B > rollback.sql

# 2. 审查 rollback.sql 内容，确认只包含目标表、目标事务
# 3. 执行回滚（务必先备份原库，最好在维护窗口）
mysql -uroot -p < rollback.sql

# 4. 核对数据，确认无误后关闭维护
```

> 闪回的前提与注意：
> - Binlog 必须为 **ROW 格式**（否则没有前像/后像可逆推）。
> - 只对 **DML**（增删改）有效；**DDL 无法闪回**。
> - 必须保留从误操作时刻到现在的 Binlog，越早发现越好。
> - 回滚 SQL 会再次产生 Binlog，需防止二次传播（可临时停从库或在维护窗口执行）。

### 7.4 误删数据的完整处置案例

```
场景：11:59 误执行 DELETE FROM orders WHERE id IN (...);  已提交
处置步骤：
1) 立刻停止写入（或冻结应用），记录当前时间；
2) 保留 binlog 文件，禁止清理（调整 binlog_expire_logs_seconds）；
3) 用 mysqlbinlog / binlog2sql 定位该 DELETE 事务的 position 范围；
4) 生成反向 INSERT 回滚 SQL，人工审查；
5) 在维护窗口执行回滚，恢复被删行；
6) 若为整库误删/TRUNCATE/DROP，则走「全量备份 + binlog 重放到误删前」的 PITR 方案；
7) 恢复后核对数据 + 回归测试，复盘并加防误删机制（权限回收、延迟从库、安全模式）。
```

> 防误删最佳实践：**权限最小化（禁止直连主库 delete/update）、生产环境 SQL 审核平台、延迟从库（如延迟 1 小时）兜底、binlog 长期归档**。

---

## 八、备份与恢复（Backup & Recovery）

### 8.1 备份分类

| 维度 | 类型 | 说明 |
|------|------|------|
| 按形式 | **逻辑备份** | 导出 SQL/表数据，可跨版本跨平台，速度慢 |
| | **物理备份** | 直接拷贝数据文件，速度快，与版本/平台绑定 |
| 按范围 | **全量备份** | 备份整个数据库/实例 |
| | **增量备份** | 只备份变更（通常配合 binlog） |
| 按在线状态 | **冷备份** | 停机备份，一致性最好但中断业务 |
| | **温备份** | 部分只读，一致性弱于冷备 |
| | **热备份** | 不停机备份，生产首选（需配合 binlog） |

### 8.2 mysqldump：逻辑备份

```bash
# 全量逻辑备份（含存储过程/事件/触发器）
mysqldump -h127.0.0.1 -uroot -p \
  --single-transaction --master-data=2 --routines --triggers --events \
  --set-gtid-purged=ON \
  --databases order_db > /backup/order_db_full.sql

# 单表备份
mysqldump -uroot -p order_db orders > /backup/orders.sql

# 压缩备份
mysqldump -uroot -p order_db | gzip > /backup/order_db.sql.gz
```

关键参数：
| 参数 | 作用 |
|------|------|
| `--single-transaction` | InnoDB 下用一致快照，**不锁表**热备 |
| `--master-data=2` | 备份文件第 22 行记录**备份时刻的 binlog 文件名+pos**，PITR 起点依据 |
| `--set-gtid-purged=ON` | 导出 GTID 集合，配合 GTID 复制恢复 |
| `--routines/--triggers/--events` | 备份函数、触发器、事件（默认容易漏） |
| `--flush-logs` | 备份前切换 binlog，便于增量衔接 |

恢复：
```bash
mysql -uroot -p < /backup/order_db_full.sql
# 或指定库
mysql -uroot -p order_db < /backup/orders.sql
```

### 8.3 xtrabackup：物理热备（Percona XtraBackup）

```bash
# 全量备份
xtrabackup --backup --target-dir=/backup/full_20260801 --host=127.0.0.1 --user=root --password=pwd

# 准备（应用 redo log，使备份文件一致，可多次 --apply-log-only 直到就绪）
xtrabackup --prepare --target-dir=/backup/full_20260801

# 恢复（拷贝回数据目录，注意权限与先停 MySQL）
xtrabackup --copy-back --target-dir=/backup/full_20260801

# 增量备份（基于上次全量/增量）
xtrabackup --backup --target-dir=/backup/incr_20260802 --incremental-basedir=/backup/full_20260801
```

- **优点**：热备、速度快、一致性高（基于 InnoDB 崩溃恢复机制），适合大数据量（百 GB ~ TB 级）。
- 恢复时按 全量 prepare → 依次 apply 增量 → copy-back 的顺序执行。

### 8.4 完整恢复策略（全量 + binlog 增量）

```
时间线：
  全量备份(08-01 02:00) ──── binlog.000023 ──── binlog.000024 ──── (故障 08-02 14:00)

恢复步骤：
1) 用最近的全量备份恢复到 08-01 02:00 的状态；
2) 找到全量备份记录的位置（mysqldump --master-data / xtrabackup 的 xtrabackup_binlog_info）；
3) 依次重放该位置之后的 binlog 到目标时间点（PITR）或直接追到最新；
4) 若含 DROP/TRUNCATE/误操作，则在误操作前停止重放，然后业务接入；
5) 恢复后检查主从关系是否被破坏，重建从库。
```

### 8.5 备份恢复的黄金法则

1. **3-2-1 原则**：3 份数据、2 种介质、1 份异地。
2. **定期演练恢复**：没演练过的备份等于没有备份（恢复不出数据）。
3. **RPO / RTO**：
   - RPO（Recovery Point Objective，可接受最大丢失时长）→ 决定备份频率与 binlog 保留时长。
   - RTO（Recovery Time Objective，可接受最大停机时长）→ 决定用逻辑备份还是物理备份、是否要备机。
4. **备份校验**：恢复后跑 `CHECKSUM TABLE` / 行数比对，防止静默损坏。
5. **binlog 归档**：把 binlog 同步到对象存储（如 S3/OSS），支持长期追溯与容灾。
6. **备份账号最小权限** + 加密存储 + 异地副本。

---

## 九、最佳实践清单

### 复制层面
- Binlog 格式用 **ROW**，开启 GTID（`MASTER_AUTO_POSITION=1`），便于切换与追溯。
- 主从开启半同步，主库双 1（`sync_binlog=1`、`innodb_flush_log_at_trx_commit=1`）降低丢数据概率。
- 大事务拆分；从库开并行复制（MTS）缓解延迟；延迟敏感读走主库。
- 用 Orchestrator/MGR 做自动故障转移，避免人工切换出错。

### 追溯层面
- binlog 长期保留并归档，设置合理的 `binlog_expire_logs_seconds`。
- 误操作第一时间冻结写入、锁定 binlog，再走 flashback / PITR。
- DDL 无法闪回 → 高危操作前先备份、走审核、加延迟从库。

### 恢复层面
- 周期性全量 + 连续 binlog 增量，定期做恢复演练，验证 RPO/RTO。
- 大库用 xtrabackup（物理），小库/跨版本迁移用 mysqldump（逻辑）。
- 恢复完成后验证主从、校验数据，并复盘优化流程。

---

## 相关笔记

- [[数据库与中间件/数据库与中间件领域总览]] - 数据库领域导航
- [[数据库与中间件/MySQL/__学习方向]] - MySQL 学习方向与实操清单
- [[数据库与中间件/Redis/Redis 知识体系全景总结]] - Redis 主从/哨兵/集群对比
