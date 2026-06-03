# ERPNext 生产部署方案（中文）

> 基于 Docker 的 ERPNext v16 生产级部署完整方案  
> 中文资料太少？这里有一份**开箱即用**的配置 + 文档  
> 适合：PVE LXC / 裸机 / 云服务器

---

## 📖 目录

- [这是什么？](#这是什么)
- [先搞懂几个概念](#先搞懂几个概念)
- [环境要求](#环境要求)
- [架构说明](#架构说明)
- [快速部署（10 分钟上手）](#快速部署10-分钟上手)
- [配置详解](#配置详解)
- [性能调优](#性能调优)
- [备份体系](#备份体系)
- [恢复流程](#恢复流程)
- [运维指南](#运维指南)
- [PVE LXC 适配（重要）](#pve-lxc-适配重要)
- [故障排查](#故障排查)
- [FAQ](#faq)

---

## 这是什么

### 为什么要做这个仓库

ERPNext 是开源 ERP 里功能最完整的之一。但中文资料非常少，官方文档全是英文，部署指南也不够详细。很多中文用户想用但卡在部署这一步。

这个仓库记录了一套**经过验证的生产部署方案**，从零开始到日常运维全覆盖。配置都是实际跑过的，不是理论方案。

### 适用人群

- 想在**生产环境**跑 ERPNext 的中文用户
- 在 **PVE LXC** 或 Linux 服务器上部署
- 需要**备份、监控、性能优化**一体化方案
- **看不懂英文文档**，希望有中文完整指南

### 不适用人群

- 只想在 Windows 上跑一下试试 → 建议用官方 Easy Install
- 需要 Kubernetes 集群部署 → 需要更复杂的方案
- 需要高可用 → 这是单机方案，不是集群

---

## 先搞懂几个概念

如果你是第一次接触 ERPNext，这些概念很重要：

### ERPNext 是什么

ERPNext 是一套**企业管理系统**，包含财务、销售、库存、人力资源、生产制造等模块。类似 SAP、Oracle，但完全开源免费。

### Frappe 是什么

Frappe 是 ERPNext 底层的**开发框架**（类似 Django）。你可以把它理解为"造 ERP 的工具"。ERPNext 是 Frappe 做出来的一套应用。

### Docker 是什么

Docker 是**容器化**技术。传统部署要把软件直接装在操作系统上，出问题很难清理。Docker 把应用和它的依赖打包在一起，隔离运行，卸载就是删一个容器，干净彻底。

### docker compose 是什么

docker compose 是用一个文件管理多个 Docker 容器的工具。ERPNext 不止一个程序（数据库、Web 服务器、队列处理等），compose 让你用一个命令启动全部。

### frappe_docker 是什么

frappe_docker 是官方提供的 **ERPNext Docker 部署方案**。它把 ERPNext 的各个组件打包成 Docker 镜像，提供了编排文件。本项目是基于它的配置文件增强版。

### bench 是什么

bench 是 Frappe/ERPNext 的**命令行管理工具**。创建站点、安装应用、备份、迁移，全靠它。

### 站点（Site）是什么

Frappe 里一个"站点"就是一套独立的 ERPNext 实例。一台服务器可以跑多个站点。每个站点有自己的数据库、配置和文件。生产环境通常一个站点就够了。

---

## 环境要求

### 硬件要求

| 项目 | 最低配置 | 推荐配置 |
|------|---------|---------|
| CPU | 2 核 | 4 核 |
| 内存 | 4 GB | 8 GB |
| 磁盘 | 40 GB | 80+ GB（备份需要额外空间） |
| 操作系统 | Ubuntu 22.04 / Debian 12 | 同上 |
| 网络 | 公网或内网可达 | 固定 IP |

> 为什么内存要求这么高？  
> ERPNext 启动后会有 9 个容器，光是 MySQL 就要占用 2-3GB 的 buffer pool。4GB 只能跑起来，生产建议 8GB。

### 软件要求

| 软件 | 版本要求 | 说明 |
|------|---------|------|
| Docker | 24+ | 容器运行时 |
| Docker Compose | v2 | 服务编排（已集成在 Docker 中） |
| git | 任意版本 | 拉取代码 |

### 安装 Docker

如果你还没有 Docker，用这一条命令安装：

```bash
# 一键安装 Docker（官方脚本）
curl -fsSL https://get.docker.com | bash

# 验证
docker --version
docker compose version

# 让当前用户能执行 docker（避免每次都要 sudo）
sudo usermod -aG docker $USER
# ⚠️ 执行后退出 SSH 重新登录，否则 docker 命令还是需要 sudo
```

---

## 架构说明

### 整体架构图

```
                    ┌──────────────┐
                    │   用户浏览器   │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  Nginx       │  ← frontend 容器
                    │  反向代理     │     端口 80
                    │  静态文件     │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼─────┐ ┌───▼────┐ ┌────▼──────┐
       │  backend    │ │websocket│ │  queue-*   │
       │  Gunicorn   │ │Socket.IO│ │  后台任务   │
       │  Python App │ │实时通信  │ │  3个容器    │
       └──────┬──────┘ └────────┘ └────────────┘
              │
       ┌──────▼──────┐
       │   MariaDB   │  ← 数据库容器
       │   MySQL兼容  │
       └──────┬──────┘
              │
       ┌──────▼──────┐
       │   Redis     │  ← 缓存 + 队列
       │  2个容器     │
       └─────────────┘
```

### 9 个容器各自干什么

| 容器名 | 角色 | 通俗理解 | 内存限制 |
|--------|------|---------|---------|
| **frontend** | Web 服务器（Nginx） | 接待用户请求，转发给后端 | 512M |
| **backend** | Gunicorn（Python） | 真正处理业务逻辑的地方 | 2G |
| **websocket** | 实时通信 | 通知你"有新单据啦" | 512M |
| **db** | MariaDB 数据库 | 存所有数据 | 4G |
| **redis-cache** | 缓存 | 加速数据读取 | 256M |
| **redis-queue** | 队列 | 协调任务排队 | 256M |
| **queue-short** | 快速任务处理 | 处理不太耗时的工作 | 1G |
| **queue-long** | 慢速任务处理 | 处理耗时工作（如报表） | 1G |
| **scheduler** | 定时任务 | 定期执行的工作（如邮件提醒） | 512M |

> 加上 configurator（一次性初始化脚本），总共 10 个服务，但 configurator 跑完就退出，不算运行中的服务。

### 为什么不是直接装一个软件，要用 9 个容器？

传统 LAMP 安装（Linux + Apache + MySQL + PHP）是把所有功能混在一起。Docker 的方案是把每个功能拆成独立容器，好处是：

- **互不影响**：数据库出问题，不影响 Web 服务器重启
- **独立升级**：可以单独升级某个组件
- **资源可控**：限制每个容器用多少内存 CPU，防止某个功能占满资源
- **容易迁移**：换个服务器，同样的配置跑起来就完事

---

## 快速部署（10 分钟上手）

### 第一步：创建项目目录并克隆代码

```bash
# 创建项目目录（路径可以自己选）
mkdir -p ~/erpnext
cd ~/erpnext

# 克隆官方 frappe_docker
git clone https://github.com/frappe/frappe_docker.git
cd frappe_docker
```

> 📌 `~/` 表示当前用户的家目录。`root` 用户的话就是 `/root/`。

### 第二步：配置环境变量

```bash
# 复制官方提供的示例环境变量文件
cp example.env .env

# 用 nano 编辑（你也可以用 vim）
nano .env
```

找到以下关键项并修改：

```env
# ─── 必须修改的项目 ───

# DB 密码（数据库的密码，很重要！）
DB_PASSWORD=你的数据库密码

# 管理员密码（ERPNext 后台的 Administrator 密码）
ADMIN_PASSWORD=你的管理员密码

# ─── 建议确认的项目 ───

# 站点域名或 IP（后面创建站点会用）
SITE_NAME=erpnext.example.com

# 你的时区
TZ=Asia/Shanghai
```

> ⚠️ 密码不要用简单密码，至少 12 位，包含字母数字特殊符号。

### 第三步：创建 MariaDB 调优配置

```bash
# 回到项目根目录
cd ~/erpnext

# 创建 MariaDB 配置目录
mkdir -p mariadb-conf
```

创建文件 `~/erpnext/mariadb-conf/tuning.cnf`，内容如下：

```ini
[mariadb]
# 缓冲池大小：建议设为物理内存的 60-70%
# 如果服务器只有 4G 内存，设为 2G
innodb_buffer_pool_size=3G

# 最大连接数
max_connections=200

# 连接线程缓存
thread_cache_size=8

# 慢查询日志（帮助排查性能问题）
slow_query_log=1
long_query_time=1

# 临时表大小（排序等操作会用到）
tmp_table_size=64M
max_heap_table_size=64M

# InnoDB 日志
innodb_log_file_size=512M
innodb_flush_log_at_trx_commit=2
innodb_flush_method=O_DIRECT
```

> 这个文件的作用是让 MariaDB 数据库跑得更快。不配置也能用，但生产环境建议配置。

### 第四步：准备 LXC 适配（如果在 PVE 上）

检查你的环境是否需要用这个配置：

```bash
cat /sys/kernel/security/apparmor/enabled
```

- 如果输出 `1` → AppArmor 正常工作，跳过此步
- 如果输出 `0` 或提示文件不存在 → **必须做 LXC 适配**

创建文件 `~/erpnext/frappe_docker/overrides/compose.lxc.yaml`：

```yaml
services:
  configurator:
    security_opt:
      - apparmor=unconfined
  backend:
    security_opt:
      - apparmor=unconfined
  frontend:
    security_opt:
      - apparmor=unconfined
  websocket:
    security_opt:
      - apparmor=unconfined
  queue-short:
    security_opt:
      - apparmor=unconfined
  queue-long:
    security_opt:
      - apparmor=unconfined
  scheduler:
    security_opt:
      - apparmor=unconfined
  db:
    security_opt:
      - apparmor=unconfined
  redis-cache:
    security_opt:
      - apparmor=unconfined
  redis-queue:
    security_opt:
      - apparmor=unconfined
```

然后在 `.env` 文件末尾追加：

```env
# 告诉 docker compose 需要加载哪些配置文件
COMPOSE_FILE=compose.yaml:overrides/compose.mariadb.yaml:overrides/compose.redis.yaml:overrides/compose.noproxy.yaml:overrides/compose.lxc.yaml
```

### 第五步：启动全部服务

```bash
cd ~/erpnext/frappe_docker

# 启动所有容器
docker compose up -d

# 查看容器状态
docker compose ps
```

第一次启动会拉取镜像，时间取决于网络速度。启动后等待 1-2 分钟让数据库初始化。

正常状态应该是：

```
NAME                       STATUS              PORTS
erpnext-backend-1          Up                  ...
erpnext-frontend-1         Up                  ...
erpnext-db-1               Up                  ...
erpnext-redis-cache-1      Up                  ...
erpnext-redis-queue-1      Up                  ...
erpnext-queue-short-1      Up                  ...
erpnext-queue-long-1       Up                  ...
erpnext-scheduler-1        Up                  ...
erpnext-websocket-1        Up                  ...
```

如果看到 `Exit` 或 `Restarting`，看后面的故障排查部分。

### 第六步：创建站点

```bash
docker compose exec backend \
  bench new-site erpnext.example.com \
  --admin-password "你的管理员密码" \
  --db-root-password "你的数据库密码"
```

这条命令做了以下事情：
1. 连接数据库，创建一个新的数据库（名字自动生成）
2. 在 containers 中创建站点目录
3. 初始化站点配置
4. 设置管理员密码

> 📌 `docker compose exec backend` 的意思是"进入 backend 容器执行命令"。  
> `bench` 是 Frappe 的命令行工具。  
> `new-site` 表示创建一个新站点。

### 第七步：安装 ERPNext

```bash
# 安装 ERPNext 应用（这一步最耗时，可能需要 5-10 分钟）
docker compose exec backend bench --site erpnext.example.com install-app erpnext

# 数据库迁移
docker compose exec backend bench --site erpnext.example.com migrate

# 清理缓存
docker compose exec backend bench --site erpnext.example.com clear-cache

# 健康检查
docker compose exec backend bench --site erpnext.example.com doctor
```

`install-app erpnext` 这一步会安装 ERPNext 的所有模块：财务、销售、库存、HR 等。安装完成后 `doctor` 应该显示没有严重错误。

### 第八步：验证

在浏览器中访问：

```
http://你的服务器IP/login
```

登录信息：
- 用户名：`Administrator`
- 密码：你设置的管理员密码

如果看到 ERPNext 的登录页面，部署成功！

---

## 配置详解

### .env 文件说明

`.env` 是 docker compose 的环境变量文件，掌控所有容器的配置。以下是核心参数：

```env
# ─── 基本配置 ───
COMPOSE_PROJECT_NAME=erpnext
# 容器名字的前缀。比如 backend 容器实际叫 erpnext-backend-1
# 如果在一台机器上跑多个 ERPNext 实例，用这个区分

# ─── 版本控制（非常重要！）───
ERPNEXT_VERSION=v16.19.1
# 锁定 ERPNext 版本，不要用 latest
# 用 latest 的话，哪天官方发布了不兼容的版本，你的系统可能启动不了
# 升级时手动改这个版本号就好

# ─── 数据库 ───
DB_PASSWORD=YOUR_DB_PASSWORD
# MariaDB 数据库 root 密码
# 一旦创建号站点后不要随意修改，否则站点无法连接数据库

# ─── Gunicorn（Python Web 服务器）───
GUNICORN_WORKERS=4
GUNICORN_THREADS=4
GUNICORN_TIMEOUT=120
# workers × threads = 最大并发处理数
# 4 workers × 4 threads = 16 个请求同时处理
# 调高会占用更多内存

# ─── 时区 ───
TZ=Asia/Shanghai
# 中国时区，影响日志时间和数据库时间

# ─── 网络 ───
HTTP_PUBLISH_PORT=80
# 对外暴露的 HTTP 端口，默认 80
# 如果 80 被占用，可以改成 8080，访问时用 http://ip:8080

FRAPPE_SITE_NAME_HEADER=erpnext.example.com
# 默认站点，访问时自动导向这个站点
```

### MariaDB 配置说明

MariaDB 的配置通过 volume 挂载到容器的 `/etc/mysql/conf.d/` 目录下。

核心配置项：

| 配置项 | 建议值 | 作用 |
|--------|-------|------|
| `innodb_buffer_pool_size` | 物理内存的 60-70% | MariaDB 的"工作台"，越大越快 |
| `max_connections` | 200 | 最多允许多少个连接同时访问 |
| `slow_query_log` | 1 | 记录慢查询（执行超过 1 秒的 SQL） |
| `long_query_time` | 1 | 超过多少秒算慢查询 |
| `innodb_flush_log_at_trx_commit` | 2 | 性能模式（牺牲一点安全性换速度） |

> 新手建议先不改这些，跑起来后再优化。

### common_site_config.json 说明

这个文件在 backend 容器内的 `sites/common_site_config.json`，是所有站点共享的配置：

```json
{
  "db_host": "db",           // 数据库主机名（容器名）
  "db_port": 3306,           // 数据库端口
  "default_site": "erpnext.example.com",  // 默认访问的站点
  "redis_cache": "redis://redis-cache:6379",
  "redis_queue": "redis://redis-queue:6379",
  "redis_socketio": "redis://redis-queue:6379"
}
```

### site_config.json 说明

每个站点有自己的 `site_config.json`，包含：

```json
{
  "db_name": "随机的数据库名",
  "db_password": "数据库访问密码",
  "db_type": "mariadb",
  "developer_mode": 0,       // 生产务必是 0
  "max_file_size": 10485760, // 上传文件大小限制（字节）
  "max_request_size": 10485760
}
```

> ⚠️ 如果你备份了这个文件，恢复时要一起恢复。没有它连不上数据库。

---

## 性能调优

### 调优原则

1. **先保守，后放开**：刚开始用保守配置，观察内存 CPU 占用后再逐步调高
2. **一次只改一个参数**：改完观察效果
3. **不做没有测试的调整**：生产环境慎改

### Gunicorn 调优

Gunicorn 是 Python Web 服务器，backend 容器就是跑它。

```env
# .env 中的配置
GUNICORN_WORKERS=4     # worker 进程数
GUNICORN_THREADS=4     # 每个 worker 的线程数
GUNICORN_TIMEOUT=120   # 请求超时时间（秒）
```

**worker 数量怎么定？**

公式：`2 × CPU 核心数 + 1`

- 2 核服务器：5 workers
- 4 核服务器：9 workers
- 但 ERPNext 每个 worker 大约占用 200-300MB 内存

**新手建议**：先用 4 workers × 4 threads，跑一周观察内存使用，如果还有富余再增加。

### MariaDB 调优

核心：`innodb_buffer_pool_size` 最重要，设置到物理内存的 60-70%。

假设你的服务器有 8GB 内存：
- 操作系统占用：约 1-2GB
- 其他容器占用：约 3GB
- 留给 MariaDB：3-4GB
- 所以 `buffer_pool` 设为 3G 比较合理

### Docker 日志调优

Docker 默认不限制日志大小，跑几个月可能把磁盘写满。建议配置：

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
```

这个配置的意思是：每个容器的日志最多 3 个文件，每个最大 50MB。

配置方法：

```bash
# 创建 Docker 守护进程配置
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF

# 重启 Docker
sudo systemctl restart docker

# 验证
docker info | grep -i logging
```

> 注意：重启 Docker 会使所有容器短暂中断，建议在维护窗口执行。

---

## 备份体系

### 为什么需要双重备份

| 备份 | 保护什么 | 不足 |
|------|---------|------|
| 应用备份（bench backup） | 数据库 + 附件 + 配置 | 如果系统彻底损坏，恢复需要先部署环境 |
| 整机备份（PVE vzdump） | 完整操作系统 + 所有数据 | 只能在虚拟机/容器层面恢复 |

**建议两者都做**：应用备份用于快速恢复单个站点，整机备份用于灾难恢复。

### 应用层备份

#### 备份内容

每天凌晨 2:00 自动执行 `backup.sh`，备份以下内容：

1. **数据库**：通过 `bench backup --with-files` 在容器内生成 SQL dump
2. **站点配置**：site_config.json、letter_heads（信纸模板）、letters
3. **Docker 配置**：compose.yaml、.env、compose.lxc.yaml
4. **MariaDB 配置**：tuning.cnf

#### 备份脚本

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE=~/erpnext
COMPOSE_DIR=$BASE/frappe_docker
TS=$(date +%F_%H-%M-%S)
BKDIR=$BASE/backups/$TS
RETENTION_DAYS=7

mkdir -p $BKDIR
cd $COMPOSE_DIR

# 1. 在容器内执行备份
docker compose exec -T backend bash -c "bench --site erpnext.example.com backup --with-files"

# 2. 把备份文件从容器复制到宿主机
docker compose cp backend:"/home/frappe/frappe-bench/sites/erpnext.example.com/private/backups" $BKDIR/

# 3. 备份站点配置
docker compose exec -T backend bash -c "tar -czf /tmp/sites-config.tar.gz -C sites erpnext.example.com/site_config.json erpnext.example.com/letters erpnext.example.com/letter_heads"
docker compose cp backend:/tmp/sites-config.tar.gz $BKDIR/

# 4. 备份 compose 配置
cp $COMPOSE_DIR/compose.yaml $BKDIR/
cp $COMPOSE_DIR/.env $BKDIR/
cp $COMPOSE_DIR/overrides/compose.lxc.yaml $BKDIR/
cp $BASE/mariadb-conf/tuning.cnf $BKDIR/

# 5. 清理 7 天前的备份
find $BASE/backups -maxdepth 2 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;
```

#### 配置定时备份

```bash
# 添加到 crontab
echo '0 2 * * * root /root/erpnext/backup.sh > /root/erpnext/logs/backup.log 2>&1' \
  | sudo tee /etc/cron.d/erpnext
```

> 📌 `0 2 * * *` 表示每天凌晨 2:00 执行。如果你不熟悉 crontab 格式，可以用 [crontab.guru](https://crontab.guru/) 查看说明。

### PVE 整机备份

如果你在 PVE 上运行 LXC 容器，可以在 PVE 宿主机上设置快照级整机备份：

```bash
# 手动备份
vzdump 100 --mode snapshot --compress zstd --storage hdd

# 参数说明：
# 100 = LXC 容器的 ID
# --mode snapshot = 零停机快照模式
# --compress zstd = 使用 zstd 压缩
# --storage hdd = 备份存储位置
```

**推荐配置**：
- 模式：snapshot（不停机）
- 压缩：zstd
- 保留：最近 7 份
- 时间：每天凌晨 4:00（与应用备份错开时间）

---

## 恢复流程

### 恢复单个站点（从应用备份）

```bash
# 1. 如果有必要，先创建一个新站点
docker compose exec backend \
  bench new-site erpnext.example.com \
  --admin-password "你的管理员密码" \
  --db-root-password "你的数据库密码"

# 2. 找到最近的备份文件
ls -lt ~/erpnext/backups/*/backups/*.sql.gz

# 3. 恢复数据库
docker compose exec -T backend \
  bench --force --site erpnext.example.com \
  restore /path/to/备份文件.sql.gz

# 4. 恢复后运行迁移
docker compose exec backend bench --site erpnext.example.com migrate

# 5. 清理缓存
docker compose exec backend bench --site erpnext.example.com clear-cache

# 6. 健康检查
docker compose exec backend bench --site erpnext.example.com doctor
```

> ⚠️ **加密密钥**：如果备份的站点启用了文件加密（会有 `encryption_key`），恢复后需要手动将旧 `site_config.json` 中的 `encryption_key` 复制到新站点的配置中，否则已加密的附件无法解密。

### 恢复整机（从 PVE 快照）

1. 登录 PVE Web 界面
2. 选择对应的 LXC 容器
3. 点 **Backup** 标签
4. 选择要恢复的备份版本
5. 点击 **Restore**
6. 确认恢复

> ⚠️ 整机恢复会覆盖容器当前状态，谨慎操作。

### 恢复验收

恢复后必须验证：

- [ ] 网页能正常打开
- [ ] 能登录（用户名 Administrator）
- [ ] 历史数据完整（打开几个旧单据看看）
- [ ] 附件能正常下载
- [ ] 打印功能正常

---

## 运维指南

### 日常命令速查

以下是你最常用的命令，建议收藏：

```bash
# ─── 进入工作目录 ───
cd ~/erpnext/frappe_docker

# ─── 查看容器状态 ───
docker compose ps
# 输出示例：
# NAME                    STATUS
# erpnext-backend-1       Up 3 days    ← "Up" 表示正常运行
# erpnext-db-1            Up 3 days

# ─── 查看日志 ───
docker compose logs -f --tail=100         # 所有服务的日志
docker compose logs -f --tail=100 backend # 只看 backend
docker compose logs -f --tail=100 db      # 只看数据库

# ─── 启动 / 停止 ───
docker compose up -d    # 启动所有服务
docker compose stop     # 暂停所有服务（容器还在）
docker compose start    # 恢复暂停的服务
docker compose down     # 完全下线（删容器）
docker compose restart  # 重启所有服务

# ─── 进入容器内部 ───
docker compose exec backend bash  # 进入 backend 容器
```

### 在容器内用 bench 命令

```bash
# 直接执行
docker compose exec backend bench --site erpnext.example.com doctor

# 或者先进容器再执行
docker compose exec backend bash
# 进去后：
bench --site erpnext.example.com doctor
bench --site erpnext.example.com migrate
bench --site erpnext.example.com clear-cache
```

### 健康检查

一键查看系统状态：

```bash
bash ~/erpnext/monitor.sh
```

输出示例：

```
=== Container Status ===
erpnext-backend-1     Up 3 days
erpnext-frontend-1    Up 3 days
erpnext-db-1          Up 3 days
...
=== Disk Usage ===
/dev/mapper/pve-root   79G   9G  70G   11% /
=== Memory ===
Mem:  7.2Gi  3.1Gi  2.6Gi
=== Backup Space ===
1.8G    /root/erpnext/backups
=== Last Backup ===
2026-05-27_02-00-01
```

如果某个容器不是 `Up`，就是有问题。

### 升级 ERPNext 版本

```bash
# 1. 先备份
bash ~/erpnext/backup.sh

# 2. 修改版本号
nano ~/erpnext/frappe_docker/.env
# 把 ERPNEXT_VERSION=v16.19.1 改成新版本号

# 3. 拉取新镜像
cd ~/erpnext/frappe_docker
docker compose pull

# 4. 重建容器
docker compose up -d

# 5. 运行数据库迁移（重要！）
docker compose exec backend bench migrate
docker compose exec backend bench clear-cache
```

> 不要跨大版本升级（如 v13 → v16 直接跳），否则数据库迁移会失败。

---

## PVE LXC 适配（重要）

### 问题表现

在 Proxmox VE 的 LXC 容器里装 Docker 后，启动容器会报错：

```
Error response from daemon: failed to create task for container:
failed to create shim task: OCI runtime create failed:
unable to apply apparmor profile: no such file or directory
```

### 原因

LXC 容器出于安全限制，默认禁用了 AppArmor 的内核接口。Docker 启动容器时会尝试加载 AppArmor 安全策略，但在 LXC 里找不到这个功能，所以报错。

### 解决方案

在 compose 配置中给所有服务加上 `security_opt: [apparmor=unconfined]`。意思是"不启用 AppArmor 安全策略"。

### 判断是否需要

```bash
cat /sys/kernel/security/apparmor/enabled
```

- 返回 `1` → AppArmor 正常，**不需要**
- 返回 `0` 或 `No such file or directory` → **必须加**

### 配置方法

在 `overrides/compose.lxc.yaml` 中配置（本仓库已提供），然后在 `.env` 中引用即可。

### 验证解决

配置好后重启容器：

```bash
docker compose down
docker compose up -d
docker compose ps
```

如果所有容器都正常启动不再报错，就解决了。

---

## 故障排查

### 容器反复重启

```bash
# 查看日志
docker compose logs --tail=50 容器名
```

**常见错误 1：AppArmor**
```
apparmor profile: no such file or directory
```
**解决**：应用 LXC 适配（见上文）

**常见错误 2：端口被占用**
```
port is already allocated
```
**解决**：找出占用端口的程序并处理
```bash
netstat -tlnp | grep 80
```

**常见错误 3：数据库连接失败**
```
Can't connect to MySQL server on 'db' (113)
```
**解决**：
```bash
# 检查数据库容器是否正常
docker compose ps db
docker compose logs --tail=20 db

# 如果 DB_PASSWORD 最近改过，需要同步更新
```

### 无法访问网页

```bash
# 检查 Nginx 是否正常
curl -s -o /dev/null -w "HTTP状态码: %{http_code}\n" http://localhost/

# 如果返回 502：backend 可能没启动好
docker compose logs --tail=20 backend

# 如果返回 403：可能站点配置有问题
docker compose exec backend bench --site erpnext.example.com doctor
```

### 磁盘空间报警

```bash
# 看看谁占了空间
df -h
du -sh /var/lib/docker/

# 清理 Docker 无用资源
docker system prune -f --volumes

# 清理旧的备份文件
find ~/erpnext/backups -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;

# 查看日志占用
du -sh /var/lib/docker/containers/*/*.log

# 查看备份日志磁盘占用
du -sh ~/erpnext/logs/
```

### 备份失败

```bash
# 查看备份日志
tail -50 ~/erpnext/logs/backup.log

# 常见原因 1：磁盘空间不足
df -h

# 常见原因 2：backup 容器没在运行
docker compose ps backend

# 手动执行备份看具体报错
bash ~/erpnext/backup.sh
```

---

## FAQ

### Q: 我只有 4GB 内存能跑吗？

能跑，但建议降低配置：
```env
GUNICORN_WORKERS=2
GUNICORN_THREADS=2
```
MariaDB 的 `innodb_buffer_pool_size` 改成 1G。但这只是"能跑"，不保证生产稳定。

### Q: 80 端口被占用了怎么办？

修改 `.env`：
```env
HTTP_PUBLISH_PORT=8080
```
然后访问 `http://你的IP:8080`。

### Q: 怎么添加自定义 App？

```bash
# 1. 把 app 代码放到容器中
docker cp 你的app erpnext-backend-1:/home/frappe/frappe-bench/apps/

# 2. 在容器内安装
docker compose exec backend bench --site erpnext.example.com install-app 你的app名
```

### Q: 数据库密码忘了怎么办？

```bash
docker compose exec backend cat sites/erpnext.example.com/site_config.json
```

输出中包含 `db_password` 字段。

### Q: 这个方案安全吗？

这是**单机方案**，没有高可用能力。安全建议：
- 修改所有默认密码（MySQL、管理员、Redis）
- 不要让服务器直接暴露在公网（用 VPN 或防火墙）
- 定期更新系统安全补丁
- 异地备份（本方案只包含本地备份）

### Q: 腾讯云/阿里云上能用吗？

能用。只需要注意：
- 安全组开放相应端口（80 或自定义端口）
- 不需要 LXC 适配（云服务器不是 LXC 容器）
- 数据盘建议单独挂载，不要把备份放在系统盘

---

## 为什么做这个仓库

中文 ERPNext 部署资料真的很少。官方文档是英文的，社区讨论也以英文为主。很多中文用户连 Docker 都没接触过，看到命令就头疼。

这个仓库的初衷是：
- **用中文**把每一步说清楚
- **不省略**任何细节
- **解释为什么**这么配，不只是告诉你怎么配
- **可复用**的配置，clone 就能用

如果你觉得有用，欢迎 Star。如果有问题或建议，提 Issue。

---

## 📚 文档索引

详细文档在 [`docs/`](docs/) 目录下：

| 文档 | 说明 |
|------|------|
| [01-部署指南.md](docs/01-部署指南.md) | 从零开始部署 ERPNext |
| [02-备份与恢复.md](docs/02-备份与恢复.md) | 备份策略和恢复流程 |
| [03-运维手册.md](docs/03-运维手册.md) | 日常运维、升级、故障处理 |
| [04-网络代理配置.md](docs/04-网络代理配置.md) | ⚠️ 中国大陆用户必读：Docker 代理配置 |

> **最后说一句**：单机生产环境的核心不是性能，而是**不出问题时能安心，出问题时能快速恢复**。备份 + 恢复演练 + 资源限制，这三件事做好，已经可以应对大部分故障。
