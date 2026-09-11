# MQTT/EMQX 消息中间件

## 一、MQTT 是什么？

**一句话理解**：MQTT 是一种**轻量级的消息传输协议**，专门给**物联网（IoT）设备**用的。

### 为什么需要 MQTT？

传统 HTTP 的问题：
- 设备要一直保持连接 → 费电
- 数据包大 → 流量贵
- 不支持"发布/订阅"模式 → 不灵活

MQTT 解决了这些问题：
- **省电**：设备可以休眠，有消息才醒
- **省流量**：消息头只有 2 字节
- **灵活**：发布/订阅模式，设备之间解耦

---

## 二、核心概念：发布/订阅模式

```
传统 HTTP（请求/响应）：
客户端 ──请求──→ 服务器
客户端 ←─响应── 服务器
（一对一，客户端必须主动问）

MQTT（发布/订阅）：
发布者（传感器）──→ [MQTT Broker] ──→ 订阅者（手机App）
（一对多，发布者不需要知道谁在听）
```

### 类比理解

想象一个**微信公众号**：
- **发布者**：公众号作者，发文章
- **Broker**：微信服务器，负责转发
- **订阅者**：读者，关注了就能收到

作者不需要知道有多少读者，读者也不需要主动去刷，有更新自动推送。

---

## 三、MQTT 核心概念

### 1. Topic（主题）

消息的"地址"，类似文件路径：

```
home/kitchen/temperature    → 厨房温度
home/living-room/light      → 客厅灯
factory/machine1/status     → 工厂1号机状态
```

**通配符**：
- `+`：单层匹配 → `home/+/temperature` 匹配所有房间温度
- `#`：多层匹配 → `home/#` 匹配 home 下所有消息

### 2. QoS（服务质量等级）

| QoS | 含义 | 保证 | 适用场景 |
|-----|------|------|----------|
| 0 | 最多一次 | 可能丢失 | 温度数据（丢一个无所谓） |
| 1 | 至少一次 | 可能重复 | 控制指令（宁可多发不能漏） |
| 2 | 恰好一次 | 不丢不重 | 计费数据（必须精确） |

**类比**：
- QoS 0 = 普通快递（丢了就丢了）
- QoS 1 = 挂号信（一定送到，可能重复）
- QoS 2 = 本人签收（保证一次）

### 3. Retained Message（保留消息）

Broker 保留该主题的最后一条消息。新订阅者一订阅就能收到最新状态，而不是等下一次发布。

```
场景：灯的开关状态
发布者发了 "ON" → Broker 保留
新设备订阅 "light/status" → 立即收到 "ON"
```

### 4. Last Will（遗嘱消息）

设备断开连接时，Broker 自动发布的消息。

```
设备上线时告诉 Broker：
"如果我断连了，请发布 'device1/offline' 到 'status' 主题"

设备意外断线 → Broker 自动发布遗嘱消息
其他设备就能知道："哦，device1 掉线了"
```

---

## 四、EMQX 是什么？

**一句话理解**：EMQX 是**国产的 MQTT Broker**，处理百万级并发连接。

### MQTT Broker 对比

| 特性 | Mosquitto | EMQX | HiveMQ |
|------|-----------|------|--------|
| 语言 | C | Erlang | Java |
| 并发 | 万级 | **百万级** | 十万级 |
| 集群 | 不支持 | **支持** | 支持 |
| Dashboard | 无 | **有** | 有 |
| 适用 | 学习/小项目 | **生产环境** | 企业级 |

### 为什么选 EMQX？

1. **性能强**：单节点 200万+ 连接
2. **集群能力**：多节点组成集群，水平扩展
3. **规则引擎**：消息可以转发到 Kafka/MySQL/HTTP
4. **国产**：中文文档好，社区活跃
5. **开源版够用**：大部分功能免费

---

## 五、EMQX 架构

```
设备层（MQTT客户端）          EMQX Broker              应用层
┌─────────────┐          ┌─────────────────┐      ┌─────────────┐
│ 温度传感器   │──MQTT──→│                 │──→   │ 数据库       │
│ 摄像头      │──MQTT──→│  MQTT 协议处理   │──→   │ Kafka       │
│ 智能门锁    │──MQTT──→│  连接管理        │──→   │ Web 应用     │
│ 手机 App    │──MQTT──→│  规则引擎        │──→   │ 告警系统     │
└─────────────┘          └─────────────────┘      └─────────────┘
                              ↓
                         集群节点1
                         集群节点2
                         集群节点3
```

---

## 六、EMQX 核心功能

### 1. 规则引擎（Rule Engine）

消息进来后，可以做各种处理：

```sql
-- SQL 语法配置
SELECT payload.temperature, payload.humidity
FROM "sensor/#"
WHERE payload.temperature > 30
-- 结果转发到 Kafka，触发高温告警
```

### 2. 消息持久化

```
MQTT 消息 → EMQX → 数据库（MySQL/PostgreSQL/TDengine）
                  → 时序数据库（InfluxDB）
                  → 消息队列（Kafka/RabbitMQ）
```

### 3. HTTP Webhook

设备发消息 → EMQX 调用你的 HTTP 接口 → 触发业务逻辑

```json
{
  "clientid": "sensor_001",
  "topic": "home/kitchen/temperature",
  "payload": {"temp": 25.6},
  "timestamp": 1700000000
}
```

---

## 七、实战：EMQX 快速上手

### Docker 部署

```bash
# 启动 EMQX
docker run -d --name emqx \
  -p 1883:1883 \    # MQTT 端口
  -p 8083:8083 \    # WebSocket 端口
  -p 18083:18083 \  # Dashboard 端口
  emqx/emqx:latest

# 访问 Dashboard
# http://localhost:18083
# 用户名: admin 密码: public
```

### Python 客户端示例

```python
import paho.mqtt.client as mqtt

# 连接 Broker
client = mqtt.Client()
client.connect("localhost", 1883, 60)

# 订阅主题
def on_message(client, userdata, msg):
    print(f"收到: {msg.topic} → {msg.payload.decode()}")

client.subscribe("home/temperature")
client.on_message = on_message

# 发布消息
client.publish("home/temperature", "25.6")

client.loop_forever()
```

---

## 八、面试高频问题

**Q1: MQTT 和 Kafka 的区别？**

| | MQTT | Kafka |
|--|------|-------|
| 定位 | IoT 设备通信 | 大数据流处理 |
| 连接数 | 百万级设备 | 服务间通信 |
| 消息大小 | 小（字节级） | 大（MB级） |
| 场景 | 传感器→云端 | 日志/事件流 |

**Q2: QoS 0/1/2 怎么选？**
- QoS 0：数据量大，丢几个无所谓（如每秒上报温度）
- QoS 1：重要指令，不能丢但可以重复（如开灯指令）
- QoS 2：涉及钱的数据，必须精确（如电量计费）

**Q3: EMQX 如何保证高可用？**
- 多节点集群：节点挂了其他顶上
- 共享订阅：消息分发到多个消费者
- 持久化存储：消息不丢

---

## 九、相关链接

- [[消息队列]]
- [[Kafka]]
- [[RabbitMQ]]
