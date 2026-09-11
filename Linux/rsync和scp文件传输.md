# rsync 和 scp 文件传输

## 一、scp（Secure Copy）

**一句话理解**：scp 就是"通过 SSH 加密通道复制文件"，可以理解为 `cp` 命令的网络版。

### 基本语法

```bash
# 本地 → 远程
scp /local/file.txt user@remote:/remote/path/

# 远程 → 本地
scp user@remote:/remote/file.txt /local/path/

# 复制整个目录（加 -r）
scp -r /local/dir/ user@remote:/remote/path/
```

### 常用参数

| 参数 | 作用 |
|------|------|
| `-r` | 递归复制目录 |
| `-P` | 指定端口（大写 P） |
| `-C` | 启用压缩传输 |
| `-p` | 保留文件权限和时间戳 |

### 举例

```bash
# 把本地 index.html 传到服务器的 /var/www/ 目录
scp -P 22 /local/index.html deploy@192.168.1.100:/var/www/

# 从服务器下载整个项目目录
scp -r user@192.168.1.100:/opt/project/ ./backup/
```

---

## 二、rsync（Remote Sync）

**一句话理解**：rsync 是"增量同步工具"，只传输**变化的部分**，而不是整个文件。

### 为什么用 rsync 而不是 scp？

| 场景 | scp | rsync |
|------|-----|-------|
| 传大文件 | 全量传输，慢 | 只传差异部分，快 |
| 断点续传 | 不支持 | 支持 |
| 保留权限/链接 | 部分支持 | 完整支持 |
| 本地同步 | 不适用 | 适用 |

### 核心原理：滚动校验算法

```
rsync 的工作流程：

1. 源文件： "Hello World 2024"
2. 目标文件："Hello World 2023"

rsync 只计算出差异部分 "2024" vs "2023"
只传输差异块，而不是整个文件

这就是为什么 rsync 传大文件特别快！
```

### 基本语法

```bash
# 本地同步
rsync -avz /local/source/ /local/dest/

# 本地 → 远程
rsync -avz /local/source/ user@remote:/remote/dest/

# 远程 → 本地
rsync -avz user@remote:/remote/source/ /local/dest/
```

### 常用参数（必须记住）

| 参数 | 作用 | 记忆方法 |
|------|------|----------|
| `-a` | 归档模式（保留权限、时间戳等） | archive = 归档 |
| `-v` | 显示详细输出 | verbose = 详细 |
| `-z` | 传输时压缩 | zip = 压缩 |
| `-P` | 显示进度 + 断点续传 | progress |
| `--delete` | 删除目标端多余的文件 | 双向同步用 |

### ⚠️ 注意：目标服务器没有文件时

**可以正常传输！** rsync 不要求目标必须有文件。

| 目标服务器状态 | rsync 行为 | 速度对比 |
|---------------|-----------|---------|
| 没有文件 | 传输完整文件 | ≈ scp |
| 有旧版本文件 | 只传差异部分 | >> scp |

```bash
# 目标是空目录，也能正常同步
rsync -avzP /local/bigfile.tar.gz user@remote:/empty/dir/
# 第一次传：完整传输（和 scp 一样慢）
# 第二次传：几乎秒完成（只传差异）
```

**rsync 的真正优势场景**：
1. 大文件多次同步 → 差异传输，极快
2. 断点续传 → 网络断了可以继续
3. 增量备份 → 只传修改过的文件

### ⚠️ 注意末尾斜杠！

```bash
# 末尾有 /：只同步目录里面的【内容】
rsync -avz /data/source/ /data/dest/
# 结果：dest 里直接是 source 的文件

# 末尾无 /：同步整个【目录】
rsync -avz /data/source /data/dest/
# 结果：dest/source/ 里面才有 source 的文件
```

### 实战例子

```bash
# 同步网站文件到服务器
rsync -avzP /var/www/html/ deploy@192.168.1.100:/var/www/html/

# 完整同步（包括删除目标端多余文件）
rsync -avzP --delete /local/data/ user@remote:/remote/data/

# 排除某些文件
rsync -avz --exclude='*.log' --exclude='.git' /src/ /dest/
```

---

## 三、rsync + ssh（组合技）

rsync 默认不加密，但可以通过 SSH 通道传输：

```bash
# 通过 SSH 端口同步
rsync -avzP -e "ssh -p 22" /local/ user@remote:/remote/

# 使用指定密钥
rsync -avzP -e "ssh -i ~/.ssh/id_rsa" /local/ user@remote:/remote/
```

---

## 四、总结对比

| 特性 | scp | rsync |
|------|-----|-------|
| 传输方式 | 全量 | 增量 |
| 加密 | SSH 原生 | 需 `-e ssh` |
| 速度（大文件） | 慢 | 快 |
| 断点续传 | ✗ | ✓ |
| 保留属性 | 部分 | 完整 |
| 适用场景 | 小文件快速传输 | 大文件/频繁同步 |

---

## 五、相关链接

- [[Linux常用命令]]
- [[SSH安全连接]]
