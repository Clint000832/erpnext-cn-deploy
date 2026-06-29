# ERPNext 求助指南 — 遇到问题怎么办

> 你一定会遇到报错信息。这不代表你做错了什么——这是正常的。关键是知道去哪里找答案。

---

## 1. 出问题时先做什么（30 秒急救）

```
Step 1：把报错信息截屏或复制下来（完整的错误文字，不要只记大概）

Step 2：确认当前状态
  docker compose ps          → 哪个服务挂了？
  docker compose logs backend --tail 30   → 最后 30 条日志说什么？

Step 3：先试最快的恢复手段
  docker compose restart backend   → 80% 的临时问题能恢复
```

## 2. 去哪里搜答案（按推荐顺序）

### 2.1 ERPNext 官方讨论论坛

```
地址：https://discuss.frappe.io
语言：英文为主
适用：所有问题

搜索技巧：
  - 用英文关键词搜（不要搜整句中文）
  - 加上版本号：erpnext v16 error XXXX
  - 用报错信息中的关键词搜（去掉你公司的具体数据）
```

### 2.2 GitHub Issues

```
地址：https://github.com/frappe/frappe/issues        （Frappe 框架问题）
     https://github.com/frappe/erpnext/issues        （ERPNext 应用问题）
     https://github.com/frappe/frappe_docker/issues   （Docker 部署问题）

搜索技巧：
  - 先在 Issues 页面搜索框搜关键词
  - 如果没找到，看 Closed（已关闭的）Issues，很多已解决的问题在里面
  - Docker 相关的报错一定先去 frappe_docker 的 Issues
```

### 2.3 中文社区（资源有限但能看懂）

```
- ERPNext 中文论坛：https://forum.erpnext.cn （用户少，但有中文资源）
- 知乎搜 "ERPNext"：有一些中文经验文章
- 百度搜 "ERPNext + 你的关键词"：偶尔有 CSDN/博客园的文章
```

### 2.4 通用技术搜索

```
Google / Bing：
  - 用英文关键词（结果多得多）
  - 格式：erpnext + 关键词 + site:github.com
    例如：erpnext "sales invoice" print format error site:discuss.frappe.io
  - 把报错信息中通用的部分复制进去搜（去掉公司名、日期等）
```

## 3. 怎么提问题才能得到回答

论坛和 GitHub 上的人愿意帮忙，但前提是你的问题描述清楚。以下是一个好问题的模板：

```
标题：【简要说清楚什么操作 + 什么报错】
  错误示例："ERPNext 报错"（不知道你在做什么操作时出的错）
  正确示例："创建 Sales Invoice 后点击 Submit 报错 'Duplicate entry for key PRIMARY'"

正文：
  1. 我的环境：
     ERPNext 版本：v16.17.0
     部署方式：Docker (frappe_docker)
     操作系统：Ubuntu 24.04

  2. 我想做什么：
     （用一两句话描述你的操作场景）

  3. 我做了什么操作：
     第 1 步：登录系统
     第 2 步：进入 Sales Invoice → 点击 New
     第 3 步：填写客户、物料、数量、价格
     第 4 步：点击 Submit → 出现报错

  4. 报错信息（完整复制）：
     （把完整的错误文字贴在这里）
     Traceback (most recent call last):
       ...

  5. 我已经尝试过的方法：
     - 试过重启 backend → 没用
     - 试过清理缓存 → 没用
     - 搜过论坛没找到类似问题
```

## 4. 常见报错信息速查

以下是最常遇到的报错，按字母排序：

| 报错关键词 | 最可能原因 | 去哪查 |
|-----------|-----------|--------|
| `Cannot connect to MySQL` | 数据库挂了或密码错了 | 检查 `docker compose ps db` |
| `Connection refused` | 目标服务没启动 | 检查服务状态 |
| `Docker: Cannot connect` | Docker Desktop 没启动 | 打开 Docker Desktop |
| `Duplicate entry` | 重复数据 | 检查是否录入了重复的编号 |
| `ModuleNotFoundError` | Python 包缺失 | 检查自定义镜像是否装了需要的包 |
| `No such file or directory` | 文件路径不对 | 检查 volume 挂载 |
| `Out of memory` | 内存不够 | 减少 worker 数量或加内存 |
| `Permission denied` | 权限不够 | 检查文件和目录权限 |
| `Site does not exist` | 站点名写错了 | bench list-sites 查看站点列表 |
| `SSL certificate problem` | SSL 证书过期或配置错误 | 检查证书有效期 |
| `Too many connections` | 数据库连接用完 | 增加 max_connections |

## 5. 遇到报错时千万不要做的事

```
✗ 不要乱删文件或数据库表（可能删掉关键数据）
✗ 不要在没有备份的情况下执行 docker compose down -v（删除所有数据）
✗ 不要反复重启系统（如果重启一次没解决，重启第三次也不会解决）
✗ 不要在论坛上公开你的管理员密码、数据库密码、公司敏感数据
✗ 不要复制粘贴看不懂的命令直接执行
```

## 6. 可以找我帮忙的问题类型

把错误信息发给我，我可以帮你：
- 翻译报错信息，用大白话说清楚到底出了什么问题
- 判断这个问题是配置错误还是 Bug
- 找到对应的解决步骤

---

> 最后更新：2026-05-10
>
> 记住：遇到问题不丢人，每个人都是从小白过来的。论坛上最好的问题往往来自初学者。
