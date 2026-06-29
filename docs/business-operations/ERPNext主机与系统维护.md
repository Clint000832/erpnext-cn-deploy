# ERPNext 主机与系统维护

> 你的 ERPNext 跑在 Ubuntu 上（无论是物理机还是 VirtualBox 虚拟机）。Ubuntu 本身也需要定期维护，就像汽车需要换机油。不维护的结果：安全漏洞、磁盘写满、系统崩溃。

---

## 1. 为什么主机维护跟 ERPNext 业务相关？

```
故事：某公司 ERPNext 跑了 8 个月一直正常。某天突然所有人登不进去。
原因：Docker 日志和旧镜像悄悄攒了 60GB，磁盘满了 → MariaDB 无法写入 → 系统瘫痪。
教训：主机维护不是"IT 的事"，是"你的生意能不能继续运转"的事。
```

---

## 2. 每周维护（5 分钟）

### 2.1 检查磁盘空间

```bash
df -h /
# 看 Use% 列。超过 80% 就该清理了。

# 看看谁占的最多
du -sh /var/lib/docker/* 2>/dev/null | sort -h
# du = 查看磁盘使用
# sort -h = 按大小从小到大排
# 最大的几个目录就是需要关注的
```

### 2.2 清理没用的 Docker 垃圾

```bash
# 清理悬空镜像（没打标签的、旧版本不要了的）
docker image prune -f
# 清理停止的容器
docker container prune -f
# 清理未使用的 volume（⚠ 确认没有重要数据再执行）
docker volume prune -f
# 一键清理以上所有（推荐每月一次）
docker system prune -f
```

**这些命令安全吗？** `docker system prune` 只删"当前没在使用"的东西。正在运行的容器、正在使用的 volume 不受影响。但 `docker volume prune` 会删除所有没被任何容器挂载的 volume，如果你手动创建过 volume 可能被误删。不确定时只执行前两个。

### 2.3 检查自动备份是否在正常运行

```bash
# 如果用了 backup-cron，检查最近的备份文件
docker compose exec backend ls -la /home/frappe/frappe-bench/sites/mysite/private/backups/ | tail -5
# 应该看到最近几天的备份文件。如果最新的是一周前的，说明备份没在跑。
```

---

## 3. 每月维护（15 分钟）

### 3.1 给 Ubuntu 打安全补丁

```bash
# 更新软件包列表
sudo apt update

# 安装所有安全更新
sudo apt upgrade -y

# 如果更新了内核，可能需要重启
# 检查是否需要重启：
ls /var/run/reboot-required 2>/dev/null && echo "需要重启" || echo "不需要重启"
```

**建议：** 每月选一个业务低峰时段（如周六晚上），执行更新后重启。重启前先确保有最新的备份。

### 3.2 检查 Docker 版本

```bash
docker --version
# 如果版本落后太多（比如一年以上），考虑更新 Docker
```

### 3.3 做一次恢复演习（每 3 个月一次）

按上线清单第 8 节的步骤，在备用机上恢复备份，确认备份文件有效。

---

## 4. VirtualBox 虚拟机特别注意事项

如果你用 VirtualBox 方案（Windows 宿主机 + Ubuntu 虚拟机），额外注意：

### 4.1 防止 Windows 更新自动重启

```
Windows 默认会在半夜自动更新并重启。重启 → VirtualBox 关闭 → 虚拟机被强制关闭 → MariaDB 可能损坏。

解决办法：
  控制面板 → Windows 更新 → 高级选项 → 把"活跃时段"设为你公司的营业时间
  → 关闭"在重启应用时自动重启"
  → 或者直接改成"手动检查更新"
```

### 4.2 设置虚拟机开机自启

如果 Windows 重启了，虚拟机不会自动启动。你需要配置：

```
方法一（简单）：Windows 计划任务
  1. 打开"任务计划程序"
  2. 创建任务 → 触发器：系统启动时
  3. 操作：启动程序 "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
  4. 参数：startvm "你的虚拟机名称" --type headless
     （headless = 无界面模式，在后台运行）

方法二（更可靠）：写一个 .bat 脚本，放到 Windows 的启动文件夹
  "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm "ERPNext" --type headless
```

### 4.3 监控宿主机磁盘空间

虚拟机的虚拟磁盘文件（.vdi）会随着时间增长。Windows 上检查：

```
打开"此电脑" → 看 C 盘剩余空间。如果小于 20GB，需要：
  1. 在 Ubuntu 虚拟机里清理（按第 2 节做）
  2. 压缩虚拟磁盘：
     VBoxManage modifymedium disk "你的磁盘.vdi" --compact
     （这个操作需要在虚拟机停止后执行）
```

---

## 5. 数据库维护（每季度）

```bash
# 1. 检查各表大小（找出异常增长的表）
docker compose exec db mysql -u root -p你的密码 -e "
  SELECT table_name,
  ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb
  FROM information_schema.tables
  WHERE table_schema = '你的数据库名'
  ORDER BY (data_length + index_length) DESC LIMIT 20;
"

# 2. 如果某些日志表异常大（比如 tabError Log 占了好几 GB）
#    在运维指南 7.2 节有清理脚本

# 3. 优化数据库表（重建索引，提升查询速度）
docker compose exec db mysqlcheck -u root -p你的密码 --optimize --all-databases
# mysqlcheck --optimize = 整理数据库碎片，就像磁盘碎片整理
# 建议在业务低峰期执行，因为大表优化时会锁表
```

---

## 6. 安全维护清单

```
每月必做：
  □ sudo apt update && sudo apt upgrade     （系统安全更新）
  □ 检查 /var/log/auth.log 有没有可疑登录尝试
  □ 确认防火墙规则正确

每季度做：
  □ docker system prune                      （清理 Docker 垃圾）
  □ 数据库优化                                （第 5 节）
  □ 恢复演习                                  （上线清单第 8 节）

每半年做：
  □ 检查所有密码（数据库、管理员、用户）是否需要更新
  □ 更新 Docker 版本
  □ 检查 SSL 证书有效期（如果用了 Let's Encrypt，会自动续约）
```

---

> 最后更新：2026-05-10
> 适用版本：Ubuntu 22.04/24.04 + Docker + ERPNext v16.x
