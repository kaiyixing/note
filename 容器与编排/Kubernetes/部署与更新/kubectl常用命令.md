## kubectl 常用命令速查

> 最后更新：2026-09-18

### 资源查询

| 命令 | 说明 |
|------|------|
| `kubectl get pods -A` | 查看所有命名空间 Pod |
| `kubectl get pods -n <ns> -o wide` | 查看 Pod 并带 IP/节点详情 |
| `kubectl get pod <name> -o yaml` | 查看 Pod 完整配置 |
| `kubectl describe pod <name> -n <ns>` | 查看事件、重启原因、调度详情 |
| `kubectl get svc,deploy,cm,secret -n <ns>` | 一次查看多种资源 |
| `kubectl get nodes -o wide` | 查看节点状态 |
| `kubectl get events -n <ns> --sort-by='.lastTimestamp'` | 按时间排序查看事件 |

### 日志与调试

| 命令 | 说明 |
|------|------|
| `kubectl logs <pod> -n <ns> -f --tail=100` | 跟踪最近 100 行日志 |
| `kubectl logs <pod> -c <container>` | 多容器场景指定容器 |
| `kubectl logs --previous <pod>` | 查看崩溃前（上一个）容器日志 |
| `kubectl exec -it <pod> -- /bin/sh` | 进入容器执行 shell |
| `kubectl debug -it <pod> --image=busybox` | 创建调试容器（同 Pod 内注入） |
| `kubectl port-forward <pod> 8080:80` | 本地端口转发到 Pod |
| `kubectl cp <pod>:/path ./local` | 从 Pod 拷贝文件到本地 |

### 部署与更新

| 命令 | 说明 |
|------|------|
| `kubectl apply -f deploy.yaml` | 创建/更新资源 |
| `kubectl apply -f - < deploy.yaml` | 管道输入 |
| `kubectl delete -f deploy.yaml` | 按清单删除 |
| `kubectl rollout status deploy/<name>` | 观察滚动更新进度 |
| `kubectl rollout undo deploy/<name>` | 回滚到上一版本 |
| `kubectl set image deploy/<name> app=nginx:1.25` | 直接改镜像版本触发滚动更新 |
| `kubectl scale deploy/<name> --replicas=5` | 扩缩容 |

### 命名空间操作

| 命令 | 说明 |
|------|------|
| `kubectl create namespace <name>` | 创建命名空间 |
| `kubectl get namespaces` / `kubectl get ns` | 查看所有命名空间 |
| `kubectl delete namespace <name>` | 删除命名空间（需手动清理该 ns 下所有资源才能删干净） |
| `kubectl config set-context --current --namespace=<ns>` | 将当前 context 默认命名空间设为 `<ns>`，后续命令无需再写 `-n` |
| `kubectl config view` | 查看当前 context 默认命名空间配置 |

### 常用技巧

| 命令 | 说明 |
|------|------|
| `kubectl explain pod.spec` | 查看字段官方说明 |
| `kubectl api-resources` | 列出所有可操作资源类型及缩写 |
| `kubectl config get-contexts` | 列出所有可用集群 context |
| `kubectl config use-context <name>` | 切换集群 |
| `kubectl delete pod <name> --grace-period=0 --force` | 强制删除 Pod |
| `kubectl cluster-info dump > dump.txt` | 导出集群全部信息（排障用） |

### 关联概念

- [[k8s滚动更新]]
- [[PodSpec详解]]
- [[RBAC权限管理详解]]
- [[Kubernetes组件详细解析]]
