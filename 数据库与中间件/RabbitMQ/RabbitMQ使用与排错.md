# RabbitMQ 使用与排错

> 关联：[[数据库与中间件/RabbitMQ/__学习方向|学习方向]] · [[Kafka]] · [[Redis]]

## 〇、它解决什么问题

RabbitMQ 是**消息队列中间件**，核心作用：让系统 A 和系统 B 不用直接打电话，而是通过"邮局"传信。

典型场景：
- **异步解耦**：用户下单后，要更新库存、加积分、发短信——不用同步全做完，丢一条消息到 MQ，各系统自己消费。
- **削峰填谷**：秒杀瞬间 10 万人下单，先全进队列，后端慢慢消费。

它用 **Erlang** 语言写，天生适合高并发消息场景。

## 一、先建立心智模型

把 RabbitMQ 想象成一个**邮局的内部柜台系统**：

- **Producer（生产者）** = 寄信的人，把"信"（消息）交给邮局。
- **Exchange（交换机）** = 邮局前台分拣台，它**不存信**，只决定"这封信该送哪个队列"。
- **Queue（队列）** = 一个个信箱/抽屉，真正存信的地方，**先进先出**（FIFO）。
- **Consumer（消费者）** = 收信的人，从信箱里把信取走。
- **Binding（绑定）+ Routing Key（路由键）** = 分拣台和信箱之间的"分拣规则"，比如"带 `order.paid` 标签的信放进 1 号信箱"。

关键结论：**消息先给 Exchange，Exchange 按规则路由到 Queue，Queue 再被 Consumer 消费。** 这条链路是后面所有排错的坐标系——消息丢/卡/堆积，一定出在这四段的某一段。

### 为什么要有 Exchange，不直接发队列？
直接"生产者→队列"是最简单的点对点，但一旦"同一个消息要给多个不同业务用"（订单消息既给库存、又给积分、又给物流），Exchange 就能一套规则分发到多个队列，**解耦**生产者要写多少个目标。

### 四种 Exchange 怎么选（面试高频 + 选型依据）
| 类型 | 类比 | 行为 | 典型场景 |
|------|------|------|----------|
| **Direct** | "指定收件箱号" | routing key **完全相等**才投递 | 点对点、RPC |
| **Fanout** | "广播喇叭" | 无视 routing key，**广播**给所有绑定队列 | 失效缓存、通知所有订阅者 |
| **Topic** | "按地区分拣" | routing key 通配：`*` 匹配**恰好一个**词、`#` 匹配**零个或多个**词 | 订单按等级/区域分类路由 |
| **Headers** | "按标签匹配" | 按消息头 KV 键值匹配 | 少用，复杂条件路由 |

> 记忆点：Direct 看"名字"，Fanout 看"广播"，Topic 看"通配符模式"，Headers 看"标签"。

**Topic 通配符示例**：
```
消息 key = order.paid.amazon
绑定 order.*       → 匹配（* 占一个词）
绑定 #.amazon      → 匹配（# 占多词）
绑定 order.paid.#  → 匹配
```

### 用 Spring AMQP 发一条消息（实际写代码方式）
底层是 AMQP 0.9.1 协议，Spring 封装后最省心。

**声明拓扑**（`@Configuration`）：
```java
@Bean
public Queue orderQueue() {
    return new Queue("order.queue", true);  // 参数2: durable
}

@Bean
public DirectExchange orderExchange() {
    return ExchangeBuilder.directExchange("order.exchange").durable(true).build();
}

@Bean
public Binding binding() {
    return BindingBuilder.bind(orderQueue()).to(orderExchange()).with("order.create");
}
```

**生产者发消息**：
```java
@Autowired
private RabbitTemplate rabbitTemplate;

public void send(String orderId) {
    // 参数: exchange名, routingKey, 消息体
    rabbitTemplate.convertAndSend("order.exchange", "order.create", orderId);
}
```

**消费者收消息**：
```java
@Component
public class OrderConsumer {
    @RabbitListener(queues = "order.queue")
    public void handle(String orderId) {
        System.out.println("收到订单: " + orderId);
    }
}
```

> Spring AMQP 默认队列持久化 + 手动 ACK 需自行配置 `acknowledge-mode`。

## 二、消息不丢的三道关卡（排错的核心框架）

消息丢失只会发生在三个环节，排错时**逐段定位**：

```
生产者 ──①──> Broker(RabbitMQ) ──②──> 消费者
```

### ① 生产端：消息有没有真到 Broker？
默认生产者"发完"不等回执，Broker 崩了消息就没了。
- **Publisher Confirm**：生产端开启后，Broker 收到消息会回调 `confirm`；没回调就说明没进 Broker。
- **Mandatory + Return**：消息到了 Exchange 但**没有任何队列能接**（没绑定/路由不上），Broker 会 `return` 回生产端，可据此记日志或重试。
- 类比：寄信要"挂号信"（confirm）+"退件通知"（return），双保险。

**Spring AMQP 中开启 confirm + return**：
```java
@Bean
public RabbitTemplate rabbitTemplate(ConnectionFactory factory) {
    RabbitTemplate template = new RabbitTemplate(factory);
    template.setConfirmCallback((correlationData, ack, cause) -> {
        if (ack) {
            log.info("消息成功进入Broker");
        } else {
            log.error("消息未进Broker, 原因: {}", cause);
            // 这里要自己重试或存库补偿
        }
    });
    // 开 return：消息到了Exchange但没队列接
    template.setReturnCallback((message, replyCode, replyText, exchange, routingKey) -> {
        log.error("消息被退回, exchange={}, key={}", exchange, routingKey);
    });
    return template;
}

// application.yml 必须开
spring:
  rabbitmq:
    publisher-confirm-type: correlated   # 或 simple
    publisher-returns: true
```

### ② Broker 端：Broker 重启消息还在吗？
要**三样全持久化**，缺一不可：
- Exchange 设 `durable`
- Queue 设 `durable`
- 消息设 `deliveryMode = 2`（持久化标志）
- 类比：信封、信箱、信本身都得是"防丢的"，只有一样持久化等于没做。

**Spring 中消息持久化**：
```java
// 发送时指定持久化
rabbitTemplate.convertAndSend(exchange, key, msg, m -> {
    m.getMessageProperties().setDeliveryMode(MessageDeliveryMode.PERSISTENT);
    return m;
});
```

> **常见误区**：只设了 Queue 持久化，Exchange 或消息没设——Broker 重启后 Queue 还在，但消息丢了，或者 Exchange 没恢复导致路由失败。

### ③ 消费端：消息有没有被真正处理完？
- **自动 ACK（默认）**：消息一取出来就算"消费成功"，**就算处理时抛异常，消息也丢了**（已标记删了）。这是最常见的丢消息原因。
- **手动 ACK**：处理成功后才调 `basic.ack`；失败调 `basic.nack(requeue=False)`，消息进**死信队列（DLQ）**，不丢。
- 类比：收信人拆信看完、办完事才签收；办砸了走"退件/转死信"流程，而不是直接烧掉。

**手动 ACK + DLQ 配置**：
```yaml
spring:
  rabbitmq:
    listener:
      simple:
        acknowledge-mode: manual   # 手动确认
        retry:
          enabled: false
```
```java
@RabbitListener(queues = "order.queue")
public void handle(Message msg, Channel channel) throws IOException {
    long deliveryTag = msg.getMessageProperties().getDeliveryTag();
    try {
        doBusiness(msg);
        channel.basicAck(deliveryTag, false);          // 成功：确认
    } catch (Exception e) {
        channel.basicNack(deliveryTag, false, false);   // 失败：拒绝+不重回队列 → 进DLQ
    }
}
```

## 三、死信队列（DLQ）是什么、什么时候触发

普通队列里，满足任一条件的消息会"死掉"，被路由到预先配好的**死信交换机（DLX）**：
1. 消息被 `reject`/`nack` 且 **不重回队列**（`requeue=False`）
2. 消息 **TTL 过期**（超过生存时间还没被消费）
3. 队列长度超过 `x-max-length`，**最老的消息被挤出去**

类比：普通队列是"工作台"，做不完/过期的单子自动转到"废弃件/返工区"（DLQ），由专门的消费者或人工处理，**不让坏消息卡死正常流程**。

## 四、常用诊断命令（按"看什么"组织）

```bash
rabbitmqctl status                       # broker 整体状态、内存、连接数
rabbitmqctl list_queues                  # 每个队列：messages_ready(堆积)/messages_unacknowledged(未ack)/consumers(消费者数)
rabbitmqctl list_consumers               # 谁在消费、channel 状态
rabbitmqctl list_publishers              # 谁在发
rabbitmq-diagnostics check_alarms        # 流控/内存/磁盘告警（重点看 flow control、disk alarm）
rabbitmq-diagnostics memory_usage        # 内存水位
rabbitmq-diagnostics consumers           # 消费者是否被 block
rabbitmqctl list_exchanges type=topic    # 看某类 exchange
rabbitmqctl cluster_status               # 集群各节点状态
```

管理台 `:15672`（默认 guest/guest，**3.10+ 禁止远程用 guest**）：看 Queue 的 **Ready（堆积）曲线** 和 **Unacked**，一眼看出"发得快还是收得慢"。

> 排错口诀：**先看堆积（list_queues 的 messages_ready）→ 再看消费者（list_consumers）→ 再看告警（check_alarms）。**

## 五、典型故障：现象 → 原因 → 处理

### 1. 消息一直堆积
- **现象**：`messages_ready` 持续增长。
- **原因**：消费比生产慢 / 消费者挂了 / 卡在某条"毒消息"反复失败。
- **处理**：
  - `list_consumers` 看消费者数量和是否健康，不够就加消费者。
  - 看消费者日志，定位卡在哪条消息（毒消息 → 让它进 DLQ 跳过）。
  - `check_alarms` 看是否被流控 block（生产者被限流，假堆积）。

### 2. 消息丢失
- 按第二节三道关卡逐段查：生产端没 confirm / 没持久化 / 消费端自动 ACK 下异常。
- 处理：开 confirm + return、三样持久化、改手动 ACK + DLQ。

### 3. 连接 / 协议报错
| 报错 | 原因 | 处理 |
|------|------|------|
| `PRECONDITION_FAILED` | 同名 queue/exchange 重复声明但参数（durable/exclusive/arguments）不一致 | 删掉旧的或统一参数 |
| 认证失败 | 密码错、vhost 没建、`guest` 只能 localhost | `rabbitmqctl change_password` + 建用户/授权 |
| 连不上 | 防火墙挡 5672/25672/15672 | `ss -lntp`、`telnet` 端口 |
| `CHANNEL_ERROR` | 参数不匹配、误用 TTL/优先级 | 看 return_code |

### 4. 内存 / 流控（生产者被卡住）
- **原理**：RabbitMQ 默认在**系统内存用到 40%**（`vmem_high_watermark_relative=0.4`）时开启**流控**，主动把生产者"写阻塞"，防止内存爆。
- **现象**：生产端突然发不动、`check_alarms` 报 flow control。
- **处理**：`memory_usage` 看水位；调大阈值 / 加内存 / 拆集群；磁盘快满会触发 disk alarm，消费也停滞。

### 5. 集群 / 高可用
- 3.8+ 用 **Quorum Queue（Raft 多数派）** 替代已废弃的镜像队列。
- 脑裂排查：`cluster_status` 看节点是否分裂；**节点数用奇数**更容易形成多数派。

## 六、常用配置（含说明）

```ini
# /etc/rabbitmq/rabbitmq.conf (3.8+ 新格式)
listeners.tcp.default = 5672        # 业务端口
management.tcp.port = 15672         # 管理台端口
vmem_high_watermark_relative = 0.4  # 内存流控阈值（系统内存的40%）
queue_master_locator = random       # 队列主节点随机分布，避免单点
```

### 两个高频进阶用法
- **延迟 / 定时消息**（原生 RabbitMQ 不支持，两种实现）：
  - 土办法（无需插件）：建一个**无消费者的中间队列**，设 `x-message-ttl=10000`（10秒过期）+ 配 `x-dead-letter-exchange`，消息过期后自动死信到真正的目标队列。
  - 插件法：`rabbitmq_delayed_message_exchange`（延迟交换机），发送时直接指定延迟秒数，更直观，生产环境常用。

**TTL + DLX 实现延迟消息的 Queue 参数配置**：
```java
@Bean
public Queue normalQueue() {
    Map<String, Object> args = new HashMap<>();
    args.put("x-dead-letter-exchange", "order.dlx");        // 死信交换机
    args.put("x-dead-letter-routing-key", "order.dead");    // 死信路由key
    return new Queue("order.queue", true, false, false, args);
}

@Bean
public Queue delayQueue() {
    Map<String, Object> args = new HashMap<>();
    args.put("x-message-ttl", 10000);  // 10秒
    args.put("x-dead-letter-exchange", "order.dlx");
    return new Queue("order.delay.queue", true, false, false, args);
}
// 消息先发 order.delay.queue → 10秒后死信到 order.dlx → 路由到真正的 order.queue
```

- **优先级队列**：queue 参数 `x-max-priority`，消息带 `priority`。**注意：优先级越高内存开销越大，生产慎用。**

## 七、场景速查（一句话 + 做法）

| 场景 | 做法 |
|------|------|
| 异步解耦（注册发邮件） | Direct/Fanout + 手动 ACK |
| 削峰（秒杀） | 大队列 + 限流消费，把瞬时高峰"摊平" |
| 延迟 / 定时 | TTL + DLX，或延迟交换机 |
| 失败兜底 | 业务异常 `nack(requeue=False)` → DLQ → 重试或人工 |
| RPC 远程调用 | Direct + `reply_to` + `correlation_id` 对结果 |

---
*更新时间：2026-09-11*
*更新说明：补充 RabbitMQ 定位与场景、Topic 通配符示例、Spring AMQP 完整代码（拓扑/生产者/消费者）、confirm+return 配置、手动 ACK 代码、TTL+DLX 延迟消息完整实现、队列死信参数配置。*
