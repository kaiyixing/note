# JSON 与 JSONC 区别详解

## 一、JSON 是什么？

**一句话**：JSON（JavaScript Object Notation）是一种轻量级的数据交换格式，人和机器都能轻松读写。

```json
{
  "name": "张三",
  "age": 25,
  "skills": ["Python", "K8s"],
  "address": {
    "city": "北京",
    "street": "朝阳路"
  }
}
```

### JSON 的语法规则

| 类型 | 示例 | 说明 |
|------|------|------|
| 字符串 | `"hello"` | 必须用双引号 |
| 数字 | `42`、`3.14` | 不加引号 |
| 布尔值 | `true`、`false` | 小写 |
| 数组 | `[1, 2, 3]` | 方括号 |
| 对象 | `{"key": "value"}` | 花括号 |
| null | `null` | 小写 |

---

## 二、JSONC 是什么？

**一句话**：JSONC = **JSON with Comments**，就是**带注释的 JSON**。

```jsonc
{
  // 这是单行注释
  "name": "张三",
  "age": 25,
  /* 
    这是多行注释
    可以写很多行
  */
  "skills": ["Python", "K8s"]
}
```

### JSON vs JSONC 对比

| 特性 | JSON | JSONC |
|------|------|-------|
| 注释 | **不支持** | 支持（`//` 和 `/* */`） |
| 尾部逗号 | 不允许 | 允许 |
| 严格性 | 严格 | 宽松 |
| 标准 | 官方标准 | 非官方扩展 |

---

## 三、为什么需要 JSONC？

### 场景1：配置文件需要注释

```jsonc
{
  // 数据库配置
  "database": {
    "host": "localhost",
    "port": 5432,
    // 生产环境用这个
    "host_prod": "db.example.com"
  },
  // 日志级别：debug/info/warn/error
  "logLevel": "info"
}
```

### 场景2：VS Code 的 settings.json

```jsonc
// VS Code 配置文件默认就是 JSONC 格式
{
  // 编辑器设置
  "editor.fontSize": 14,
  "editor.tabSize": 2,
  
  // 保存时自动格式化
  "editor.formatOnSave": true,
  
  // 文件关联：*.jsonc 文件用 JSONC 模式解析
  "files.associations": {
    "*.jsonc": "jsonc"
  }
}
```

---

## 四、哪些工具/场景用 JSONC？

| 工具/场景 | 格式 | 说明 |
|----------|------|------|
| K8s 配置 | JSON | 严格 JSON，不支持注释 |
| VS Code 配置 | JSONC | settings.json 支持注释 |
| tsconfig.json | JSONC | TypeScript 配置支持注释 |
| .eslintrc.json | JSONC | ESLint 配置支持注释 |
| Docker Compose | YAML | 用 YAML 而不是 JSON |
| API 响应 | JSON | 严格 JSON |

---

## 五、JSON vs YAML vs JSONC

| 特性 | JSON | JSONC | YAML |
|------|------|-------|------|
| 注释 | ✗ | ✓ | ✓ |
| 可读性 | 一般 | 一般 | 好 |
| 严格性 | 严格 | 宽松 | 宽松 |
| 数据类型 | 基础 | 基础 | 丰富 |
| 配置文件 | 少用 | 常用 | 最常用 |
| API 数据 | 最常用 | 少用 | 少用 |

```yaml
# YAML 版本（更简洁）
database:
  host: localhost
  port: 5432
  # 这是注释
```

```jsonc
// JSONC 版本
{
  "database": {
    "host": "localhost",
    "port": 5432
    // 这是注释
  }
}
```

---

## 六、如何处理 JSONC？

### 1. 编辑器支持

VS Code 自动识别 `.jsonc` 文件，语法高亮 + 注释支持。

### 2. 命令行工具

```bash
# jq 不支持 JSONC（会报错）
echo '{"a": 1, // comment}' | jq .
# error: Invalid JSON

# 需要先去掉注释，再用 jq
sed '/\/\//d' config.jsonc | jq .
```

### 3. 编程语言处理

```python
# Python 处理 JSONC 需要第三方库
import commentjson

with open('config.jsonc', 'r') as f:
    config = commentjson.load(f)
```

```javascript
// Node.js
const JSONC = require('jsonc-parser');
const fs = require('fs');

const text = fs.readFileSync('config.jsonc', 'utf8');
const config = JSONC.parse(text);
```

---

## 七、面试高频问题

**Q1: JSON 和 JSONC 的区别？**
- JSON 不支持注释，JSONC 支持 `//` 和 `/* */`
- JSONC 还支持尾部逗号
- JSONC 不是官方标准，是扩展

**Q2: 为什么 JSON 不支持注释？**
- JSON 设计目标是"机器间数据交换"
- 注释是给人看的，机器不需要
- 保持格式简单、解析高效

**Q3: 配置文件用 JSON 还是 YAML？**
- 需要注释 → YAML 或 JSONC
- API 数据交换 → JSON（通用性最好）
- K8s 配置 → YAML（官方推荐）

**Q4: 如何用 jq 处理 JSONC？**
- jq 原生不支持 JSONC
- 先用 sed/awk 去掉注释，再传给 jq
- 或者用专门的 JSONC 解析库

---

## 八、相关链接

- [[基础工具/jq与yq/基本使用|jq 与 yq 完全教程]]
