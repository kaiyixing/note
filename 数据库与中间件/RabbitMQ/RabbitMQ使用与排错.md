# RabbitMQ 使用与排错

> 关联：[[数据库与中间件/RabbitMQ/__学习方向|学习方向]] · [[Kafka]] · [[Redis]]

## 核心概念速览

- 模型：Producer → Exchange → (Binding / Routing Key) → Queue → Consumer
- Exchange 类型：
  - **Direct**：routing key 精确匹配，点对点
  - **Topic**：`*` 单词、`#` 多词通配，选择性分发
  - **Fanout**：广播所有绑定队列
  - **Headers**：按消息头匹配（少用）
- ACK：consumer 手动 `basic.ack` 后消息才删除；未 ack 超时/连接断开会重新投递
- 持久化三要素：exchange `durable` + queue `durable` + 消息 `deliveryMode=2`，缺一即可能重启丢失
- 死信（DLX / DLQ）：消息被 `reject/noRequeue`、TTL 过期、队列超 `x-max-length` 时路由到死信交换机
- Publisher Confirm：生产端开启，broker 收到后回调 confirm，保证消息不丢

## 常用排错命令

```bash
rabbitmqctl status                          # broker 状态
rabbitmqctl list_queues                      # 队列：消息数/消费者数/未 ack
rabbitmqctl list_consumers                   # 消费端
rabbitmqctl list_publishers                  # 生产端连接
rabbitmq-diagnostics check_stacks            # 栈告警
rabbitmq-diagnostics check_alarms            # 流控/内存告警
rabbitmq-diagnostics memory_usage
rabbitmq-diagnostics consumers
rabbitmqctl list_exchanges type=topic        # 列出指定类型 exchange
rabbitmq-diagnostics help                    # 更多诊断子命令
```

管理台 `:15672`（默认 guest/guest，3.10+ 禁远程 guest）看 Queue 的 Ready（堆积）与 Unacked 曲线、Connections、Channels。

## 典型故障排查路径

### 1. 消息堆积
- `list_queues` 看 messages_ready 增长，`list_consumers` 看消费者是否健康
- 消费慢 / 消费者挂了 / 卡在某个长事务
- channel 被流控阻塞：`rabbitmq-diagnostics consumers` 看 blocked
- 是否设了 `x-max-length` 溢出；是否单 consumer 处理慢（加 consumer 数）
- 看消费者日志，定位处理逻辑卡点

### 2. 消息丢失（分环节定位）
- 生产端：未开 publisher confirm / 未开 return → 加 `confirm_callback` + `return_callback`
- 持久化：queue 非 durable 或消息 `deliveryMode=1` → broker 重启丢
- 消费端：自动 ack 下异常未捕获 → 改手动 ack，catch 后 `basic.nack(requeue=False)` 入 DLQ

### 3. 连接 / 协议异常
- `PRECONDITION_FAILED`：queue/exchange 重复声明但参数（durable/exclusive/arguments）不一致
- 认证失败：密码、vhost、`guest` 仅限 localhost；改 `rabbitmqctl change_password` + `add_vhost`
- 网络：5672（amqp）、25672（集群）、15672（管理）被防火墙拦 → `ss -lntp`、`telnet`
- `CHANNEL_ERROR`：看 `return_code`，多为参数不匹配或 TTL/优先级误用

### 4. 内存 / 流控
- 默认 `vmem_high_watermark = 0.4`（系统内存 40% 阈值），触顶开启流控，生产者写阻塞
- `rabbitmq-diagnostics memory_usage` 看水位；调阈值、加机器、扩内存
- 磁盘水位 `dmem_limit` 触发 disk alarm，消费停滞
- 看 `check_alarms` 输出

### 5. 集群与高可用
- 3.8+ 推荐 **Quorum Queue**（Raft）替代已废弃的镜像队列
- 脑裂：`rabbitmq-diagnostics ping`、检查集群节点 `rabbitmqctl cluster_status`
- 仲裁与多数派：奇数节点更易形成 quorum

## 常用配置要点

```ini
# /etc/rabbitmq/rabbitmq.conf (3.8+)
listeners.tcp.default = 5672
management.tcp.port = 15672
vmem_high_watermark_relative = 0.4
dmem_high_watermark_preset = memory
queue_master_locator = random
```

- 延迟任务：`x-dead-letter-exchange` + 普通队列 TTL（`x-message-ttl`）+ 无消费者的专用队列；或插件 `rabbitmq_delayed_message_exchange`
- 优先级队列：queue 参数 `x-max-priority`，消息发时带 `priority`（性能损耗，慎用）

## 场景速查

| 场景 | 做法 |
|------|------|
| 异步解耦（注册发邮件） | Direct/Fanout + 手动 ACK |
| 削峰（秒杀） | 大 `x-max-length` 队列 + 限流消费 |
| 延迟/定时 | TTL + DLX |
| 失败兜底 | 业务异常 `nack` → DLQ → 重试/人工处理 |
| RPC | Direct + `reply_to`/`correlation_id` |

---
*更新时间：2026-09-11*
