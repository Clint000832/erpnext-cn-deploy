# ERPNext 部署指南 — 从零到生产

> 适用读者：只会 Excel 基础公式的人，不需要任何编程知识
> 适用场景：本地学习 → Demo 验证 → 公司生产部署
> 核心理念：**每一步都解释为什么这样做，不这样做会怎样**

---

## 目录

1. [先搞懂你在搭什么](#1-先搞懂你在搭什么)
2. [准备工作：在你的电脑上装 Docker](#2-准备工作在你的电脑上装-docker)
3. [第一次启动 ERPNext（Demo 模式）](#3-第一次启动-erpnextdemo-模式)
4. [创建你的第一个站点](#4-创建你的第一个站点)
5. [从 Demo 升级到正式部署](#5-从-demo-升级到正式部署)
6. [让系统跑得更快（性能调优）](#6-让系统跑得更快性能调优)
7. [出问题怎么办（故障排查）](#7-出问题怎么办故障排查)
8. [备份：你的救命稻草](#8-备份你的救命稻草)
9. [升级 ERPNext 版本](#9-升级-erpnext-版本)
10. [常用操作速查表](#10-常用操作速查表)

---

## 1. 先搞懂你在搭什么

### 1.1 用盖房子来理解这套系统

你在搭的 ERPNext 不是"一个软件"，而是**一栋楼**。楼里每个房间管不同的业务。

```
你的公司 = 一栋办公楼
    └── ERPNext = 楼里的一套完整办公系统
          ├── 销售模块 = 销售部办公室 → 管报价、订单、发货、开票
          ├── 采购模块 = 采购部办公室 → 管采购申请、收货、付款
          ├── 财务模块 = 财务部办公室 → 管记账、应收应付、报表
          ├── 库存模块 = 仓库办公室   → 管入库、出库、盘点
          ├── 制造模块 = 车间办公室   → 管生产计划、工单、BOM
          └── 人事模块 = 人事部办公室 → 管员工、考勤、工资
```

### 1.2 用快递公司来理解这套系统的技术架构

你启动 ERPNext 后，后台其实跑了 **9 个不同的程序**，它们像快递公司的不同部门，各管一摊：

```
┌─────────────────────────────────────────────────────┐
│  你的浏览器（前台接待大厅）                            │
│  你在这里点按钮、填数据、看报表                         │
└───────────────┬─────────────────────────────────────┘
                │  http://localhost:8080
                ↓
┌─────────────────────────────────────────────────────┐
│  frontend（前台服务员）                               │
│  职责：接待你的浏览器请求，转给后台处理                   │
│  类比：快递公司的前台客服，你打电话给他，他帮你查单号      │
└───────────────┬─────────────────────────────────────┘
                │
    ┌───────────┼───────────┬──────────────┐
    ↓           ↓           ↓              ↓
┌────────┐ ┌────────┐ ┌──────────┐ ┌──────────┐
│backend │ │queue-  │ │queue-long│ │scheduler │
│（会计）│ │short   │ │（搬运工）│ │（闹钟）   │
│        │ │（快递员│ │          │ │          │
│ 处理你  │ │ 取件）  │ │ 处理耗时  │ │ 定时执行  │
│ 的每个  │ │        │ │ 的大任务  │ │ 的任务    │
│ 页面请求│ │ 处理快  │ │          │ │          │
│        │ │ 速任务  │ │          │ │          │
└────────┘ └────────┘ └──────────┘ └──────────┘
    ↑           ↑           ↑
    └───────────┴───────────┘
        都需要跟这两个打交道
    ┌────────────────────────────┐
    │  MariaDB（档案室）          │  ← 存所有数据：客户、发票、库存...
    │  Redis（便签墙）            │  ← 记临时信息：待办任务、缓存
    └────────────────────────────┘
```

- **backend**：最核心的程序。你每次在页面上点击按钮，都是它在背后运算。类比：Excel 的计算引擎，你改了 A1 单元格，它帮你把 B1 的结果也算出来。
- **frontend**：前台接待。负责把你的浏览器请求转发给 backend。类比：你打电话给公司总机，总机帮你转接到对应部门。
- **queue-short / queue-long**：任务的流水线工人。有些事不需要立刻做完（比如发邮件通知、生成 PDF 报表），就交给它们排队处理。short 处理快件，long 处理大件。
- **scheduler**：闹钟。每天凌晨自动备份、每小时更新汇率，都是它按时间触发。
- **MariaDB**：档案室。所有数据（客户资料、发票、库存数量）都存在这里。
- **Redis**：便签墙。系统临时记东西的地方，比如"还有 3 个任务在排队"。

### 1.3 几个关键名词，用 Excel 来理解

| 名词 | 是干什么的 | Excel 类比 |
|------|-----------|-----------|
| **Frappe** | 一个做网站的工具箱，ERPNext 是用它造出来的 | Excel 软件本身 |
| **ERPNext** | 跑在 Frappe 之上的 ERP 系统 | 你用 Excel 做的一个财务管理表格 |
| **bench** | 管理 ERPNext 的命令行工具 | Excel 的菜单栏（只不过 bench 是敲命令而不是点鼠标） |
| **Site（站点）** | 一个独立的数据库 + 文件系统，可以理解为一个"账套" | 一个 `.xlsx` 文件 |
| **App（应用）** | 安装在 Site 上的功能模块 | Excel 文件里的一个工作表（Sheet） |
| **DocType** | 定义一种数据的格式 | Excel 的表头行（定义了每列存什么类型的数据） |

**重要理解：** 一个 Site 就像你们公司的一本总账，里面可以装多个 App（财务模块、销售模块、库存模块等）。如果你有两家完全独立的公司，就应该创建两个 Site，而不是混在一个 Site 里。

### 1.4 Docker 是什么？为什么非要用它？

**不用 Docker 的话：** 你得自己在电脑上装 Python、装数据库、装各种依赖包，装不对就启动不了。就像你要自己做一张桌子——先去买木头、买钉子、买胶水、借电锯，每一步都可能出错。

**用 Docker 的话：** Docker 就像一个**搬家公司的打包箱**。箱子里已经有做桌子的所有材料和工具，你只需要把箱子搬到你家，打开就能用。这个"箱子"就是 **Docker 镜像（Image）**。

```
Docker 镜像（Image） = 一个打包好的程序安装包，里面什么都有了
Docker 容器（Container） = 你把镜像"运行起来"后的实例，是活的程序
Docker Compose = 一次性启动多个容器的指挥中心
Volume = 一个独立的"保险箱"，数据存在这里，容器删了数据还在
```

**类比：** 镜像就是游戏安装光盘，容器就是安装后正在运行的游戏，Volume 就是你的游戏存档。光盘坏了不重要，可以再买一张。存档丢了你就得重头打。

---

## 2. 准备工作：在你的电脑上装 Docker

### 2.1 macOS 安装（你的 M3 MacBook）

```bash
# 在终端里粘贴这行命令，回车
brew install --cask docker
```

**这行命令在做什么？** `brew` 是 Mac 上的软件商店（类似 iPhone 的 App Store，但是用命令行操作的），`install --cask docker` 就是告诉它"给我装 Docker Desktop 这个软件"。

如果提示 `brew: command not found`，说明你的 Mac 还没装 Homebrew。先去 https://brew.sh 复制安装命令。

安装完成后：
1. 在应用程序里找到 **Docker** 图标，双击打开
2. 等菜单栏出现鲸鱼图标（可能需要 30 秒）
3. 验证安装成功：

```bash
docker --version
# 你应该看到类似这样的输出：
# Docker version 29.x.x
```

**M3 Mac 特别注意：** 因为 ERPNext 官方打包的程序是给 Intel 芯片的电脑准备的，而 M3 是苹果自己的芯片，中间需要一个翻译官。打开 Docker Desktop → 右上角齿轮 Settings → General → 勾选 **"Use Rosetta for x86_64/amd64 emulation on Apple Silicon"** → 右下角 Apply & Restart。

**不勾这个会怎样？** 启动时会报错，类似 `image platform does not match host platform`，意思就是"这个程序是给 Intel 电脑的，你的 M3 跑不了"。

**如果你的内置硬盘空间紧张（< 50GB 可用）：** Docker 的数据（镜像 + 容器）默认存在内置盘，ERPNext 一套下来大约占用 5-10GB。建议在 Docker Desktop → Settings → Resources → Advanced → Disk image location 改到外置硬盘。

### 2.2 Windows 安装（公司 VirtualBox 方案）

你的方案是 Windows 宿主机 → VirtualBox → Ubuntu → ERPNext。分两步：

**第一步：在 Windows 上装 VirtualBox 和创建 Ubuntu 虚拟机**

```
1. 下载 VirtualBox：https://www.virtualbox.org/ → 下载 Windows 版本 → 安装
2. 下载 Ubuntu Server：https://ubuntu.com/download/server → 下载 Ubuntu Server 24.04 LTS
3. 打开 VirtualBox → 新建 → 名称填 "ERPNext" → 类型选 Linux → 版本选 Ubuntu 64-bit
4. 内存分配：最少 4096 MB（4GB），推荐 8192 MB（8GB）
5. 虚拟硬盘：选"现在创建虚拟硬盘" → 大小至少 50GB → 格式选 VDI → 选"动态分配"
6. 创建完成后，点"设置" → 存储 → 挂载你下载的 Ubuntu Server ISO → 启动
7. 按 Ubuntu 安装向导完成安装（大部分选项用默认即可）
```

**每个选项是什么意思？**
- 内存 4GB：相当于这台虚拟电脑的"运行内存"。太小了 ERPNext 会卡。宿主机（你的 Windows）至少要有 8GB 内存才能分 4GB 给虚拟机。
- 硬盘 50GB：存放 Ubuntu 系统 + Docker + ERPNext 镜像和数据。如果不确定够不够，就设 100GB。"动态分配"意思是不会立刻占满 100GB，用多少占多少。
- 网络模式建议选"桥接"：让虚拟机有独立 IP，局域网内的其他电脑可以直接访问 ERPNext。

**第二步：在 Ubuntu 里装 Docker**

虚拟机启动后，登录进入 Ubuntu 的命令行，逐行执行：

```bash
# 1. 更新系统（类似 Windows 更新，确保系统是最新的）
sudo apt update && sudo apt upgrade -y
# sudo = 以管理员身份执行
# apt update = 检查有哪些软件可以更新
# apt upgrade = 安装这些更新
# -y = 所有确认都自动回答"是"

# 2. 安装 Docker（这行命令会自动检测你的系统并安装正确版本）
curl -fsSL https://get.docker.com | sudo sh
# curl = 从网上下载文件
# | sudo sh = 把下载的内容交给管理员权限执行

# 3. 让你自己不用每次输入 sudo（不用每次都输入管理员密码）
sudo usermod -aG docker $USER
# usermod -aG docker = 把你加入 docker 用户组
# $USER = 你当前的用户名
# 执行完这行后，退出终端重新登录才生效！
```

### 2.3 Linux 直接安装（如果公司直接用 Linux 服务器）

如果你的公司服务器是裸 Linux（不是虚拟机），按照 2.2 第二步的三行命令即可。完成后执行 `docker --version` 确认安装成功。

---

## 3. 第一次启动 ERPNext（Demo 模式）

### 3.1 获取启动文件

```bash
# 1. 进入你的工作目录（选一个空间充裕的磁盘位置）
mkdir -p ~/erpnext && cd ~/erpnext
# mkdir -p = 创建文件夹，-p 表示如果父文件夹不存在也一起创建
# cd = 进入这个文件夹

# 2. 下载官方部署文件
git clone https://github.com/frappe/frappe_docker.git
# git clone = 从 GitHub 下载整个项目文件到本地
# 类比：把别人的 Excel 模板下载到你的电脑

# 3. 进入下载的文件夹
cd frappe_docker
```

### 3.2 配置你的环境变量

在启动之前，要告诉系统一些基本信息。创建一个叫 `.env` 的文件（注意前面有个点）：

```bash
cat > .env << 'EOF'
ERPNEXT_VERSION=v16.17.0
DB_PASSWORD=请换成你自己的强密码_至少20位
MARIADB_ROOT_PASSWORD=请换成你自己的强密码_至少20位
HTTP_PUBLISH_PORT=8080
EOF
```

**每一行是什么意思？**

| 变量 | 含义 | 不乱填的后果 |
|------|------|------------|
| `ERPNEXT_VERSION=v16.17.0` | 告诉系统"用 v16.17.0 这个版本的 ERPNext" | 不指定版本可能拉到最新版，但最新版不一定最稳定 |
| `DB_PASSWORD=...` | 数据库的密码，保护你的数据不被别人访问 | 用弱密码（如 123），数据库可能被人入侵，所有数据泄露 |
| `HTTP_PUBLISH_PORT=8080` | 你用浏览器访问的端口号 | 不设的话有些配置默认用 80 端口，可能跟其他程序冲突 |

### 3.3 两种启动方式：选哪个？

ERPNext 提供了两种本地启动方式。对新手来说，**先选方式 A**（你刚才用的就是这个），后面再学方式 B。

| | 方式 A：`pwd.yml`（一键 Demo） | 方式 B：`compose.yaml + overrides`（积木拼接） |
|------|---------|---------|
| 文件数量 | 一个文件搞定一切 | 底板 + 5 块积木 |
| 自动创建站点 | ✅ 自动创建 `frontend` 站点 | ✗ 需要自己手动创建 |
| 自动安装 ERPNext | ✅ 自动安装 | ✗ 需要手动 `install-app erpnext` |
| 复杂度 | ★☆☆ 一行命令 | ★★☆ 需要理解每块积木的作用 |
| 密码 | 固定 `admin`（仅适合本地学习） | 你自己在 `.env` 里设置 |
| 适用场景 | 第一次体验、学习功能 | 理解架构、模拟生产 |

### 3.4 方式 A：一键 Demo（推荐，你刚才用的就是这个）

```bash
# 确保在 frappe_docker 目录下
cd ~/erpnext/frappe_docker

# 一行命令启动
docker compose -f pwd.yml up -d
# -f pwd.yml = 用 pwd.yml 这一个文件
# up -d = 启动并在后台运行
```

**pwd.yml 做了什么？** 它在文件里定义好了 11 个服务，包括数据库、缓存、ERPNext 全部核心组件。其中有一个 `create-site` 服务会自动：
1. 等数据库和 Redis 就绪
2. 创建一个叫 `frontend` 的站点
3. 自动安装 Frappe 框架和 ERPNext 应用
4. 设置 Administrator 密码为 `admin`

**等 2-5 分钟**（M3 Mac 走 Rosetta 转译会慢一些），访问 `http://localhost:8080`，用户名 `Administrator`，密码 `admin`。

**如果登录后看到 Setup Wizard：** 按照 `ERPNext首次登录与基础配置.md` 第 1 节操作。

### 3.5 方式 B：积木拼接（理解架构用，之后再看）

积木模式的思想：你有一块**底板**（`compose.yaml`，定义了 7 个核心服务），然后按需往上拼不同的**积木块**（`overrides/` 目录下的文件）。

```
底板          积木块                         效果
─────        ──────────                    ──────
compose.yaml  (必选)  定义了 7 个核心服务    backend、frontend、queue、scheduler、websocket 等
    +
mariadb.yaml  (推荐)  加一个数据库           MariaDB
    +
redis.yaml    (推荐)  加缓存和队列服务        Redis
    +
migrator.yaml (推荐)  启动时自动更新数据库结构  不用手动 migrate
    +
noproxy.yaml  (本地)  直接暴露 8080 端口      浏览器直接访问

每加一块积木，就多一个功能。不加就不启动对应的服务。这是正式部署的套路。
```

```bash
# 启动（镜像下载同样要几分钟，之后重启只需几十秒）
docker compose \
  -f compose.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.migrator.yaml \
  -f overrides/compose.noproxy.yaml \
  up -d

# ⚠ 方式 B 启动后，需要手动创建站点（和方式 A 最大的区别）：
docker compose exec backend bench new-site mysite \
  --mariadb-root-password 你设的密码 \
  --admin-password 你设的管理员密码 \
  --db-host db

docker compose exec backend bench --site mysite install-app erpnext
```

**两种方式的共同点：** 第一次启动都需下载镜像（2-3GB），耗时 5-20 分钟。之后再次启动只需几十秒。

### 3.6 确认启动成功

```bash
# 查看所有服务的状态
docker compose ps
```

**看什么？** 你会看到一个表格，每行是一个服务。注意 `STATUS` 列：
- `Up` = 正常运行
- `Up (healthy)` = 正常运行且通过了健康检查
- `Restarting` = 出问题了，反复重启

**所有服务都是 `Up` 才算成功。** 如果某个服务一直在 `Restarting`，跳到第 7 节"故障排查"。

### 3.7 如果镜像下载太慢（中国大陆用户）

Docker 默认从国外服务器下载，国内可能很慢。配置镜像加速器：

打开 Docker Desktop → 右上角齿轮 Settings → Docker Engine → 在 JSON 配置中加入：

```json
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://docker.m.daocloud.io"
  ]
}
```

然后点 Apply & Restart，等 Docker 重启后再执行启动命令。

---

## 4. 创建你的第一个站点

### 4.1 先搞清楚：容器启动 ≠ 可以用了

服务启动后，你访问 `http://localhost:8080` 看到的可能是个空白页面。就像你盖好了办公楼（启动了容器），但**办公室里还没有桌子、还没有人、还没挂牌**。你需要：

1. **创建一个"站点"** = 在办公楼里挂牌"XX 公司财务部"
2. **安装 ERPNext 应用到站点** = 在办公室里布置桌子、电脑

### 4.2 创建站点

```bash
docker compose exec backend bench new-site mysite \
  --mariadb-root-password 你的数据库密码 \
  --admin-password 你的管理员密码 \
  --db-host db
```

**拆解这行命令：**

| 命令片段 | 含义 |
|---------|------|
| `docker compose exec backend` | "进入 backend 这个容器，在里面执行命令" |
| `bench new-site mysite` | "用 bench 工具创建一个叫 mysite 的新站点" |
| `--mariadb-root-password xxx` | "数据库的 root 密码是 xxx，用来创建站点自己的数据库" |
| `--admin-password xxx` | "这个站点的管理员密码设为 xxx，用来登录 ERPNext 界面" |
| `--db-host db` | "数据库在哪？在名字叫 db 的那个容器里" |

### 4.3 安装 ERPNext 应用

```bash
docker compose exec backend bench --site mysite install-app erpnext
```

**为什么需要这一步？** 创建站点只是搭了一个空框架，里面没有任何业务功能。`install-app erpnext` 把 ERP 的所有功能模块（销售、采购、财务、库存等）安装进去。

**如果跳过这一步会怎样？** 登录后看到的是空白页面，没有任何菜单和功能。只装了操作系统，没装应用软件。

### 4.4 验证：确认一切就绪

```bash
# 列出已安装的应用
docker compose exec backend bench --site mysite list-apps
```

输出应该包含：
```
frappe   16.x.x
erpnext  16.x.x
```

两个都显示版本号才算成功。然后访问 `http://localhost:8080`，用 `Administrator` 和你设置的密码登录。

---

## 5. 从 Demo 升级到正式部署

### 5.1 Demo 和正式部署的区别

| 方面 | Demo 模式 | 正式部署 |
|------|----------|---------|
| 数据库 | 密码是弱密码 | 强密码 |
| 备份 | 没有 | 每天自动备份 |
| SSL | 没有（http） | 有（https，数据加密） |
| 中文字体 | 没有（PDF 中文变方块） | 有 |
| 性能 | 单 worker | 多 worker |

### 5.2 正式部署命令

```bash
# 完整生产栈（含 SSL + 自动备份）
docker compose \
  -f compose.yaml \
  -f overrides/compose.mariadb.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.migrator.yaml \
  -f overrides/compose.nginxproxy-ssl.yaml \
  -f overrides/compose.backup-cron.yaml \
  up -d
```

**比 Demo 多了什么？**
- `nginxproxy-ssl.yaml` 替代了 `noproxy.yaml`：加了一个专业的前台接待（nginx），还支持 HTTPS 加密
- `backup-cron.yaml`：加了一个定时备份闹钟

**前提条件：** 使用 SSL 需要你有一个域名（如 `erp.yourcompany.com`），并且在 `.env` 中设置了 `LETSENCRYPT_EMAIL` 和 `NGINX_PROXY_HOSTS`。

### 5.3 安全加固清单

这是发生产前**必须逐项完成**的清单，每一项不做的后果见括号：

- [ ] 把 `admin` 密码改成 20 位以上强密码（否则：别人可以登录你的系统）
- [ ] 把数据库密码改成 20 位以上强密码（否则：所有数据可能被拖走）
- [ ] 在服务器防火墙只开放 443 端口（否则：数据库端口暴露在公网）
- [ ] 配置自动备份（否则：硬盘坏了数据全丢）
- [ ] 配置异地备份（否则：服务器被偷/机房火灾 = 数据全丢）

---

## 6. 让系统跑得更快（性能调优）

### 6.1 性能问题的"翻译"

当用户说"系统好慢"时，其实可能是不同的问题。你需要先判断是哪种慢：

```
"系统好慢" 可能是：
├── 点一个页面要等 5 秒才出来 → 可能是 backend 不够用
├── 打开报表要等很久 → 可能是数据库查询慢
├── 上传文件/导出大表卡住 → 可能是 nginx 超时设置太短
├── PDF 生成卡住不动 → 可能是队列积压
└── 登录页面都要转圈 → 可能是服务器内存不够了
```

### 6.2 数据库调优：用仓库类比

MariaDB 的配置就像管理一个仓库：

```
innodb_buffer_pool_size = 数据库的"工作台"大小
类比：仓库管理员的工作台。工作台越大，他在上面摆的东西越多，
找东西越快。但太大了会占掉其他工作区。建议设为你服务器内存的 50-60%。

innodb_log_file_size = 数据库的"便签本"大小
类比：仓库管理员记录每次操作的便签。便签太小他就得频繁换页（写磁盘），
太大则万一停电丢失的记录更多。建议 512MB-2G。

max_connections = 同时最多多少人进仓库
类比：仓库最多同时容纳的工人数。超过这个数，新来的人得在门口等。
```

**配置表（根据你的服务器内存选择）：**

| 服务器总内存 | innodb_buffer_pool_size | max_connections | 适用场景 |
|-------------|------------------------|-----------------|---------|
| 4 GB | 1.5 GB | 50 | 1-10 人用 |
| 8 GB | 4 GB | 100 | 10-50 人用 |
| 16 GB | 8 GB | 150 | 50-100 人用 |

**如何应用这些配置？** 编辑 `overrides/compose.mariadb.yaml`，在 `command:` 下面加参数。

### 6.3 增加"处理请求的人手"

Backend 就像银行柜台——你只有一个柜台，10 个人排队就得等。增加 backend 实例 = 多开几个柜台：

```bash
# 从 1 个 backend 增加到 3 个
docker compose up -d --scale backend=3
```

**原理：** Docker 自动把进来的请求分给不同的 backend 实例，就像银行取号机把客户分配到空闲柜台。

**多少合适？** 1-10 人 → 1-2 个；10-50 人 → 3-4 个；50+ 人 → 5-8 个。不是越多越好，因为后端还要跟数据库打交道，太多了数据库自己会变成瓶颈。

### 6.4 让报表和导出不超时

有些操作（比如导出全年的销售数据）需要很长时间，nginx 默认 120 秒超时。如果你的报表生成需要更久：

```env
# 在 .env 中加入
PROXY_READ_TIMEOUT=300      # 把超时从 120 秒提高到 300 秒（5分钟）
CLIENT_MAX_BODY_SIZE=100m   # 允许上传最大 100MB 的文件
```

---

## 7. 出问题怎么办（故障排查）

### 7.1 故障排查的基本思路

就像医生看病：**先问症状，再定位病因，最后开药。** 不要一上来就重启。

```
第一步：具体是什么症状？
  □ 网站打不开（502/504 错误）
  □ 页面能打开但特别慢
  □ 某个功能报错
  □ 中文显示为方块
  □ 数据库连接失败

第二步：查看服务状态
  docker compose ps
  → 哪个服务的 STATUS 不是 "Up"？

第三步：查看那个服务的日志
  docker compose logs <服务名> --tail 50
  → 日志里有没有 error、exception、traceback 这些关键词？

第四步：根据日志信息，对照下面的常见问题处理
```

### 7.2 常见问题速查

**症状：访问 http://localhost:8080 打不开，浏览器显示"无法连接"**

```
可能原因 1：Docker 服务没启动
检查：运行 docker ps，如果报 "Cannot connect"，说明 Docker 没启动
解决：打开 Docker Desktop，等鲸鱼图标出现

可能原因 2：容器没启动
检查：docker compose ps，看有没有服务
解决：docker compose up -d

可能原因 3：端口被别的程序占用了
检查：在终端运行 lsof -i :8080
解决：改 .env 中 HTTP_PUBLISH_PORT 为其他端口（如 8081）
```

**症状：后台任务（PDF 生成、邮件发送、报表导出）卡住不动**

```
原因：队列 worker 可能挂了
检查：docker compose ps queue-short queue-long
      → STATUS 是不是 "Up"？
解决：docker compose restart queue-short queue-long
原理：queue 就像流水线工人，卡住了就让他重新开始工作
```

**症状：页面报错 "Site does not exist"**

```
原因：站点没创建，或者站点名写错了
检查：docker compose exec backend bench --site all list-sites
      → 你的站点在列表里吗？
解决：如果在列表里但对不上，确认你访问的域名/站点名和创建时一致
      如果不在列表里，回到第 4 节重新创建站点
```

**症状：中文显示为方块 □□□**

```
原因：Docker 容器里没有中文字体
检查：docker compose exec backend fc-list :lang=zh
      → 如果没有任何输出，说明没有中文字体
临时解决（容器重启后失效）：
  docker compose exec backend apt-get update
  docker compose exec backend apt-get install -y fonts-noto-cjk
永久解决：见运维指南第 8 章"自定义镜像构建"
```

### 7.3 彻底重置环境

如果系统被你玩坏了，想从头再来：

```bash
# 1. 停掉所有服务
docker compose down

# 2. 删除所有数据（包括数据库、站点文件、上传的文件）—— 这一步不可逆！
docker compose down -v
# -v 的意思是"把 volumes（数据保险箱）也删掉"
# 不加 -v 的话，下次启动数据还在

# 3. 重新启动
docker compose up -d

# 4. 回到第 4 节重新创建站点
```

---

## 8. 备份：你的救命稻草

### 8.1 为什么备份是第一重要的事？

想象你的笔记本电脑明天早上突然打不开了。如果 ERPNext 的数据有备份，损失 = 今天的数据。如果没有备份，损失 = 公司从开业到现在所有的数据。

**备份就是买保险——平时觉得麻烦，出事时谢天谢地。**

### 8.2 手动备份

```bash
# 备份所有站点（数据库 + 上传的文件）
docker compose exec backend bench --site all backup --with-files
# bench --site all = 对所有站点执行
# backup = 备份命令
# --with-files = 连同上传的文件（发票扫描件、附件等）一起备份

# 把备份文件复制到你的电脑上（这样容器删了备份还在）
docker compose cp backend:/home/frappe/frappe-bench/sites/mysite/private/backups ./my-backups/
# docker compose cp = 把容器里的文件复制到你的电脑
```

### 8.3 自动备份

使用 `backup-cron` 积木块后，系统会每天自动备份。在正式部署命令中已经包含了。

### 8.4 异地备份

本地备份只能防硬盘坏，防不了火灾/盗窃/机房事故。异地备份 = 把备份文件复制到另一个物理位置的服务器。

```bash
# 如果公司有另一台服务器或 NAS，设置每天凌晨 3 点同步
# 在 crontab 中添加：
0 3 * * * rsync -avz ~/erpnext/my-backups/ user@backup-server:/backups/
```

### 8.5 恢复数据

```bash
# 1. 把备份文件放回容器
docker compose cp backup_file.tar.gz backend:/home/frappe/frappe-bench/sites/

# 2. 执行恢复
docker compose exec backend bench --site mysite restore backup_file.tar.gz

# 3. 更新数据库结构（如果备份是旧版本的）
docker compose exec backend bench --site mysite migrate
```

---

## 9. 升级 ERPNext 版本

### 9.1 升级前必须做的事

```bash
# 1. 先备份！（不做这一步就不要继续往下）
docker compose exec backend bench --site all backup --with-files

# 2. 确认当前版本
docker compose exec backend bench version
# 记下版本号，万一升级失败要知道从哪回滚
```

### 9.2 执行升级

```bash
# 1. 修改 .env 中的版本号
# ERPNEXT_VERSION=v16.18.0  （从 v16.17.0 改成新版本）

# 2. 拉取新版本的镜像（就是下载新版本的"打包箱"）
docker compose pull
# pull = 只下载镜像，不重启服务

# 3. 用新镜像重启所有服务
docker compose up -d

# 4. 更新数据库结构（这一步很关键！）
docker compose exec backend bench --site all migrate
# migrate = 把数据库结构调整为新版本需要的格式
# 如果跳过这一步，可能页面报错或功能异常

# 5. 重新生成前端文件
docker compose exec backend bench --site all build
# build = 重新生成网页的 JS/CSS 文件
```

### 9.3 如果升级后出问题

```bash
# 回滚步骤：
# 1. 把 .env 里的版本号改回旧版本
# 2. docker compose up -d
# 3. 用之前备份的文件恢复数据
docker compose exec backend bench --site mysite restore 备份文件.tar.gz
```

---

## 10. 常用操作速查表

### 服务管理

```bash
docker compose ps                          # 查看所有服务的状态（绿灯还是红灯）
docker compose up -d                       # 启动所有服务
docker compose down                        # 停止所有服务
docker compose restart backend             # 只重启 backend（其他不受影响）
docker compose logs -f backend             # 实时查看 backend 的运行日志（按 Ctrl+C 退出）
docker compose logs backend --tail 50      # 查看 backend 最近 50 条日志
```

### 站点管理

```bash
docker compose exec backend bench --site all list-sites      # 列出所有站点
docker compose exec backend bench --site mysite list-apps     # 列出站点上安装的应用
docker compose exec backend bench --site mysite console      # 进入 Python 控制台（高级操作）
docker compose exec backend bench --site mysite clear-cache  # 清理缓存（改配置后可能需要）
docker compose exec backend bench --site mysite set-admin-password 新密码  # 重置管理员密码
```

### 备份

```bash
docker compose exec backend bench --site all backup --with-files  # 备份所有站点
docker compose cp backend:/home/frappe/frappe-bench/sites/mysite/private/backups ./  # 备份文件下载到本地
```

---

## 附录：各平台快速排错

### macOS
| 症状 | 最可能的原因 | 解决 |
|------|------------|------|
| `docker: Cannot connect` | Docker Desktop 没启动 | 打开 Docker Desktop，等 30 秒 |
| 镜像下载极慢 | 没配置国内镜像源 | 按 3.6 节配置镜像加速 |
| Apple Silicon 性能差 | 没开 Rosetta | 按 2.1 节勾选 Rosetta |
| 内置盘空间不足 | Docker 数据占空间 | 迁移到外置硬盘（2.1 节） |

### Windows + VirtualBox
| 症状 | 最可能的原因 | 解决 |
|------|------------|------|
| VM 中无法上网 | 网络模式不对 | 改为"桥接模式" |
| 宿主机无法访问 VM | 没有端口转发 | VirtualBox 设置 → 网络 → 端口转发 |
| VM 性能极差 | 分配的 CPU/内存不够 | 给 VM 至少 2 核 CPU + 4GB 内存 |

---

> 最后更新：2026-05-09
> 基于 ERPNext v16.17.0 + frappe_docker v3.2+
>
> 阅读下一步：`ERPNext运维进阶与本地化指南.md` — 日常维护、中国本地化、性能调优
