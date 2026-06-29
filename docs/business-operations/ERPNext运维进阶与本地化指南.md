# ERPNext 运维进阶与本地化指南

> 适用读者：已经成功启动 Demo 环境，现在需要日常维护、中国本地化、性能调优的人
> 核心理念：**知道"为什么"比知道"怎么做"重要。理解原理后你不需要背命令。**

---

## 目录

1. [日常运维：每天花 5 分钟确保系统健康](#1-日常运维每天花-5-分钟确保系统健康)
2. [中国本地化：让系统适合中国公司使用](#2-中国本地化让系统适合中国公司使用)
3. [不需要写代码的定制](#3-不需要写代码的定制)
4. [性能调优：理解每个参数对你的业务意味着什么](#4-性能调优理解每个参数对你的业务意味着什么)
5. [简易监控：在客户发现之前你知道出事了](#5-简易监控在客户发现之前你知道出事了)
6. [常见业务场景配置](#6-常见业务场景配置)
7. [故障案例集：症状 → 原因 → 解决](#7-故障案例集症状--原因--解决)
8. [Docker 不可变性与自定义镜像](#8-docker-不可变性与自定义镜像)

---

## 1. 日常运维：每天花 5 分钟确保系统健康

### 1.1 为什么要每天检查？

ERPNext 就像一辆每天都在跑的车。如果从来不看机油、不检查轮胎，某天高速上抛锚就晚了。每天花 5 分钟检查，可以避免 95% 的紧急故障。

### 1.2 五项基础检查

以下检查不需要理解技术细节，会看输出就行。每条命令后面标注了"正常应该看到什么"和"看到什么说明出问题了"。

**检查一：服务是否都在正常运行？**

```bash
docker compose ps
```

正常输出：每个服务 `STATUS` 列显示 `Up` 或 `Up (healthy)`。
异常信号：某个服务显示 `Restarting`、`Exit` 或者根本没有该行。

**检查二：有没有任务卡住了？**

```bash
docker compose exec backend bench --site mysite show-pending-jobs
```

这条命令的意思是：进入 backend 容器，查看你的站点上有没有排队等待但没被执行的任务。

正常输出：只有少量几行或为空。
异常信号：输出几十上百行。说明后台处理能力不够，用户在等（比如 PDF 一直生成不出来）。

**检查三：有没有报错？**

```bash
docker compose logs backend --tail 50 | grep -iE "error|exception|traceback"
```

正常输出：什么都没有（没有 error 就是最好的 news）。
异常信号：出现大量报错行。把输出保存下来，对照第 7 节"故障案例集"排查。

**检查四：磁盘还够不够？**

```bash
df -h /
```

正常输出：`Use%` 这一列的数字 < 80%。
异常信号：如果 > 85%，说明磁盘快满了。磁盘满了 = 系统写不了数据 = 任何新操作全部失败。这是最紧急的故障之一。

**检查五：数据库有没有被人暴力破解的迹象？**

```bash
docker compose exec db mysql -u root -p你的密码 -e "SHOW STATUS LIKE 'Aborted_connects';"
```

正常输出：一个很小的数字（几十以内）。
异常信号：这个数字很大（几千几万），说明有人在不停地尝试猜你的数据库密码。立刻去改一个更强的密码，并检查防火墙。

### 1.3 把五项检查做成一个"每日体检脚本"

你不用每天手动敲这五条命令。把它们写进一个文件，每天运行一次：

```bash
# 创建每日检查脚本
cat > ~/erpnext-daily-check.sh << 'SCRIPT'
#!/bin/bash
echo "===== ERPNext 每日检查 $(date) ====="
echo ""
echo "1. 服务状态："
docker compose -f ~/erpnext/frappe_docker/compose.yaml ps 2>/dev/null || echo "请先进入 frappe_docker 目录"
echo ""
echo "2. 积压任务数："
docker compose exec -T backend bench --site mysite show-pending-jobs 2>/dev/null | wc -l
echo ""
echo "3. 最近错误日志（最后 5 条）："
docker compose logs backend --tail 100 2>/dev/null | grep -iE "error|exception" | tail -5
echo ""
echo "4. 磁盘使用："
df -h / | tail -1
echo ""
echo "===== 检查完毕 ====="
SCRIPT

chmod +x ~/erpnext-daily-check.sh
# chmod +x = 让这个文件变成"可执行"的脚本
```

以后每天只需要运行：

```bash
cd ~/erpnext/frappe_docker && ~/erpnext-daily-check.sh
```

### 1.4 日志管理：不让日志撑爆你的磁盘

Docker 默认会把每个容器的运行日志存下来。运行几个月后，这些日志可能占到几十 GB。

**为什么会这样？** 每次用户访问网页、后台执行任务，都会产生日志。就像快递公司每个包裹都登记，日积月累登记本就很厚了。

**如何限制？** 在 Docker Desktop 或 Docker daemon 的设置中：

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

这段配置的意思是：每个容器的日志最多存 10MB，最多保留 3 个文件（总共 30MB）。超出后自动删旧日志。

### 1.5 用户管理

**创建新用户：** 在 ERPNext 网页界面操作更方便：搜索 "User" → New。如果在命令行创建：

```bash
docker compose exec backend bench --site mysite add-user zhang@company.com \
  --first-name 张 --last-name 三 --password 初始密码
# add-user = 创建用户命令
# 邮箱地址也是登录用户名
# --first-name 和 --last-name 拼起来就是显示的名字
```

**重置管理员密码（忘记密码时用）：**

```bash
docker compose exec backend bench --site mysite set-admin-password 新密码
```

### 1.6 队列：理解你的"后台任务排队系统"

```
你的用户在页面上点"导出全年销售报表"
    ↓
ERPNext 收到请求："这个任务需要处理 10 万条数据，不能立刻完成"
    ↓
把任务放进队列："请在 queue-long 排队，轮到你了就处理"
    ↓
用户看到"报表生成中，稍后下载"
    ↓
queue-long worker 从队列里取任务 → 处理完成 → 通知用户
```

**三种队列的分工：**

| 队列 | 处理什么 | 类比 |
|------|---------|------|
| short | 发邮件通知、更新缓存、小计算 | 取快递，随到随取 |
| default | 生成 PDF、导入数据、中等任务 | 寄普通快递，排几分钟队 |
| long | 大批量导出、复杂报表、大量数据处理 | 搬家，需要预约时间 |

**查看队列有没有积压：**

```bash
docker compose exec backend bench --site mysite show-pending-jobs
```

积压 = 你只有 1 个 worker 在处理，但任务来得太快。解决：增加 queue worker 数量或增加 backend 实例。

---

## 2. 中国本地化：让系统适合中国公司使用

### 2.1 为什么选了中文还有很多英文？

ERPNext 是个国际化的软件，翻译靠全球志愿者贡献。截至 v16，中文覆盖率大约 45-60%。你看到的英文大多是**业务术语、错误提示、系统配置项**。

**打个比方：** 就像你买了一台进口设备，操作面板上常用的按钮已经贴了中文标签，但维修手册、内部设置界面还是英文的。

以下是三种解决方案，从易到难：

**方案一（零技术）：通过 Crowdin 在线贡献翻译**

1. 访问 https://translate.erpnext.com
2. 注册账号，加入 Chinese (Simplified) 团队
3. 搜索你看到的英文词，提交对应的中文翻译
4. 翻译被审核通过后，会在下一个 ERPNext 版本中生效

优点：不需要碰技术。缺点：不是立刻生效，需要等版本更新。

**方案二（推荐，立刻生效）：创建翻译补丁**

这套方案的本质是：你创建一个"翻译覆盖文件"，告诉系统"以后看到 Customer 就显示成 客户"。

**重要提示：以下 Demo 环境操作。生产环境需要把这些翻译打包进自定义镜像（见第 8 章），否则容器重启就丢失。**

```bash
# 第一步：进入 backend 容器
docker compose exec backend bash
# exec = execute，意思是"在 backend 容器里执行 bash（命令行）"

# 第二步：在容器里创建一个 App（给翻译补丁一个"壳"）
bench new-app zh_cn_patches
# new-app = 创建一个新的应用骨架
# zh_cn_patches = 我们给这个补丁 App 起的名字

# 第三步：进入这个 App 的目录
cd /home/frappe/frappe-bench/apps/zh_cn_patches

# 第四步：创建翻译文件夹和翻译文件
mkdir -p zh_cn_patches/translations
# mkdir -p = 创建文件夹，如果父文件夹不存在也自动创建

cat > zh_cn_patches/translations/zh.csv << 'EOF'
# 格式：英文原文,中文翻译
# 每一行就是一个"翻译对照"
"Customer","客户"
"Supplier","供应商"
"Sales Invoice","销售发票"
"Purchase Order","采购订单"
"General Ledger","总账"
"Chart of Accounts","会计科目表"
"Fiscal Year","会计年度"
"Cost Center","成本中心"
"Payment Entry","付款凭证"
"Journal Entry","日记账凭证"
"Item","物料"
"Bill of Materials","物料清单 (BOM)"
"Work Order","工单"
"Delivery Note","发货单"
"Purchase Receipt","采购收货单"
"Stock Entry","库存凭证"
"Price List","价目表"
"Terms and Conditions","条款与条件"
"Print Format","打印格式"
"Custom Field","自定义字段"
"Report","报表"
"Dashboard","仪表盘"
"Lead","线索"
"Opportunity","商机"
"Quotation","报价单"
"Sales Order","销售订单"
"Expense Claim","费用报销"
"Asset","固定资产"
"Leave Application","请假申请"
"Employee","员工"
EOF

# 第五步：把这个补丁 App 装到你的站点上
bench --site mysite install-app zh_cn_patches
# install-app = 安装应用

# 第六步：让翻译生效
bench --site mysite clear-cache
# clear-cache = 清理缓存，让系统重新加载翻译

# 第七步：退出容器
exit
```

**翻译生效后你发现还有漏掉的英文词：** 编辑 `zh.csv`，加一行，再 `clear-cache`。持续维护下去，这就是你自己的中文术语库。

### 2.2 会计科目表：中国企业最基本的需求

#### 为什么内置的中国科目表不够用？

ERPNext 内置了一个社区上传的中国会计科目表（COA），但只有约 274 个科目，且标记为"未经官方验证"。一个正常运营的中型企业通常需要 300-500 个科目。

#### 中国标准科目编码体系

中国会计科目编码遵循 `4 位一级 / 6 位二级 / 8 位三级` 的规则：

```
1xxx = 资产类
  1001 = 库存现金
  1002 = 银行存款
  1122 = 应收账款
  1403 = 原材料
  1601 = 固定资产

2xxx = 负债类
  2001 = 短期借款
  2202 = 应付账款
  2221 = 应交税费

4xxx = 所有者权益类
  4001 = 实收资本
  4103 = 本年利润

5xxx = 成本类
  5001 = 生产成本

6xxx = 损益类
  6001 = 主营业务收入
  6401 = 主营业务成本
  6601 = 销售费用
  6602 = 管理费用
```

**在 ERPNext 中设置：** 创建公司时，在 Setup Wizard 中选择 China 作为国家。如果内置 COA 不够，可以在 ERPNext 界面中 Accounting → Chart of Accounts 手动添加科目。

### 2.3 增值税配置

> **本节所有操作都会直接影响你的发票金额和税务申报。务必仔细核对每一项。**

#### 先搞懂增值税在 ERPNext 里是怎么计算的

```
一笔销售，金额 10,000 元，增值税率 13%。
ERPNext 的处理逻辑：

不含税金额 (total)          = 10,000
税额 (total_taxes)          = 10,000 × 13% = 1,300
价税合计 (grand_total)      = 10,000 + 1,300 = 11,300

发票上显示：
  金额  ¥ 10,000.00
  税额  ¥  1,300.00
  合计  ¥ 11,300.00
```

#### 创建中国的增值税 Tax Template

在 ERPNext 界面中操作（不需要命令）：

```
1. 搜索 "Sales Taxes and Charges Template" → 点击 New
2. Title 填 "增值税 13%"
3. Company 选你的公司
4. 在 Taxes 表格中，添加一行：
   - Charge Type: On Net Total（基于不含税金额计算）
   - Account Head: 选择"销项税额"科目（需要先在科目表中创建此科目）
   - Rate: 13
5. Save

其他常用税率按同样方式创建：
- 增值税 9%（适用于交通运输、邮政、基础电信、建筑、不动产租赁等）
- 增值税 6%（适用于现代服务业、金融服务、生活服务等）
- 征收率 3%（小规模纳税人）
```

#### 中国主要税种速查

| 税种 | 适用场景 | 常用税率 | ERPNext 中如何配置 |
|------|---------|---------|------------------|
| 增值税（一般纳税人） | 销售货物、提供服务 | 13%, 9%, 6% | Sales Taxes and Charges Template |
| 增值税（小规模纳税人） | 年销售额 < 500 万 | 3%, 5% | 同上 |
| 企业所得税 | 公司盈利 | 25%（标准） | 年底手工计算申报，ERPNext 不自动计算 |
| 城建税 | 附加在增值税上 | 7%, 5%, 1% | 同上，附加税 |
| 教育费附加 | 附加在增值税上 | 3% | 同上 |
| 地方教育附加 | 附加在增值税上 | 2% | 同上 |
| 印花税 | 合同、账簿 | 0.03%-0.1% | 按次申报 |

### 2.4 单据编号改成中国习惯

默认的发票编号是 `ACC-SINV-2026-00001`，中国公司习惯的格式是 `INV-2026-05-0001`。

```bash
docker compose exec backend bench --site mysite console << 'PY'
import frappe

# 以下代码逐行解释：
# frappe.db.set_value = 修改系统中的某个设置项
# 参数 1："DocType" = 我们改的是"单据类型定义"
# 参数 2："Sales Invoice" = 具体改"销售发票"这个单据类型
# 参数 3："autoname" = 改它的"自动命名规则"
# 参数 4："INV-.YYYY.-.MM.-.####" = 新的命名格式
#   INV-   = 固定前缀（发票 Invoice 的缩写）
#   .YYYY. = 年份四位数（如 2026）
#   .MM.   = 月份两位数（如 05）
#   .####  = 四位数流水号（如 0001, 0002...）

frappe.db.set_value(
    "DocType", "Sales Invoice",
    "autoname", "INV-.YYYY.-.MM.-.####"
)

# 采购单编号格式：PO-2026-05-0001
frappe.db.set_value(
    "DocType", "Purchase Order",
    "autoname", "PO-.YYYY.-.MM.-.####"
)

frappe.clear_cache()
# 刷新缓存，让新编号规则立刻生效
PY
```

### 2.5 中国日期和货币格式

```bash
docker compose exec backend bench --site mysite console << 'PY'
import frappe

# 设置系统级别的默认格式
frappe.db.set_value("System Settings", "System Settings", {
    "date_format": "yyyy-mm-dd",        # 日期：2026-05-09
    "number_format": "#,###.##",         # 数字：1,234.56
    "float_precision": 2,                # 小数保留 2 位
    "currency_precision": 2,             # 金额保留 2 位
    "default_currency": "CNY"            # 默认币种：人民币
})

frappe.clear_cache()
PY
```

---

## 3. 不需要写代码的定制

> **本节所有操作仅在 Demo 环境（pwd.yml）中可以随时试验。生产环境需要将这些定制打包进镜像（见第 8 章）。**

### 3.1 给你的客户资料加一个"税号"字段

ERPNext 原生的 Customer 表单没有"纳税人识别号"字段。你需要自己加：

**方法一（推荐，零代码）：在界面上操作**

```
1. 搜索栏输入 "Custom Field" → 点击 New
2. 填写：
   - Label: 纳税人识别号
   - Fieldname: tax_id（系统自动从 Label 生成，不要改）
   - Field Type: Data
   - Length: 20
   - 勾选 "In List View"（在列表页就显示出来）
   - 勾选 "In Standard Filter"（可以按税号搜索）
   - Insert After: customer_name（放在客户名称下面）
3. Save
```

完成之后，每个 Customer 表单上就多了一个"纳税人识别号"输入框。你在打印模板中引用这个字段时用 `{{ doc.custom_tax_id }}`。

**方法二（用命令批量创建多个字段）：**

如果你需要一次性为多个 DocType 添加字段（比如 Customer 和 Company 都需要税号），用命令更快：

```bash
docker compose exec backend bench --site mysite console << 'PY'
import frappe

# 为 Customer 添加税号字段
# 逐个字段解释：
# doctype: "Custom Field" = 我们要创建一个"自定义字段"
# dt: "Customer" = 这个字段加到"客户"表单上
# fieldname: "tax_id" = 字段的内部名字（代码里用）
# label: "纳税人识别号" = 字段的显示名字（用户看到的）
# fieldtype: "Data" = 字段类型是"文本"
# insert_after: "customer_name" = 放在"客户名称"后面
# unique: 1 = 这个字段的值必须唯一（两个客户不能有相同的税号）

frappe.get_doc({
    "doctype": "Custom Field",
    "dt": "Customer",
    "fieldname": "tax_id",
    "label": "纳税人识别号",
    "fieldtype": "Data",
    "length": 20,
    "insert_after": "customer_name",
    "unique": 1,
    "in_list_view": 1
}).insert()

# 为 Company 添加税号字段（同理）
frappe.get_doc({
    "doctype": "Custom Field",
    "dt": "Company",
    "fieldname": "tax_id",
    "label": "纳税人识别号",
    "fieldtype": "Data",
    "length": 20,
    "insert_after": "company_name",
    "unique": 1
}).insert()

frappe.clear_cache()
print("✅ 字段创建完成！现在 Customer 和 Company 表单上都有税号输入框了。")
PY
```

### 3.2 自定义脚本：发票保存时自动做点事

Server Script 是 ERPNext 给你准备的一个"不写完整 App 也能加业务逻辑"的功能。你可以把它理解为 Excel 的宏——在特定事件发生时自动执行一段代码。

**场景：发票保存时自动计算大写金额**

```
需求：每次保存 Sales Invoice 时，自动把金额转成中文大写
      （比如 56500.00 → "伍万陆仟伍佰元整"）
```

在 ERPNext 界面操作：

```
1. 搜索 "Server Script" → 点击 New
2. Script Type 选 "DocType Event"（单据事件触发）
3. DocType 选 "Sales Invoice"（在发票上触发）
4. Event 选 "Before Save"（在保存之前执行）
5. 把下面的代码粘贴进去
6. Save
```

以下是代码和逐行解释：

```python
import frappe
# import frappe = 导入 ERPNext 的工具箱，让我们能操作数据库

# 定义一个函数：把数字变成中文大写
def number_to_cn(amount):
    """把一个金额数字转成中文大写。比如 56500.50 → 伍万陆仟伍佰元伍角"""
    if amount is None or amount == 0:
        return "零元整"

    # 中文数字对应表
    digits = ["零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖"]
    # 金额单位
    units = ["", "拾", "佰", "仟", "万", "拾", "佰", "仟", "亿"]

    yuan = int(amount)  # 取整数部分（元）
    jiao = int(round((amount - yuan) * 10))  # 取角
    fen = int(round((amount - yuan) * 100)) % 10  # 取分

    # 转换整数部分
    if yuan == 0:
        result = "零"
    else:
        str_yuan = str(yuan)
        result = ""
        length = len(str_yuan)
        for i, c in enumerate(str_yuan):
            d = int(c)
            pos = length - i - 1
            if d == 0:
                # 跳过多余的零（比如"壹仟零零零壹"变成"壹仟零壹"）
                if i < length - 1 and str_yuan[i+1] != '0':
                    result += "零"
            else:
                result += digits[d] + units[pos]

    result += "元"

    # 转换角分
    if jiao == 0 and fen == 0:
        result += "整"
    else:
        if jiao > 0:
            result += digits[jiao] + "角"
        if fen > 0:
            result += digits[fen] + "分"

    return result

# ⬇ 这是实际执行的代码——把计算结果写入单据的自定义字段
doc.custom_grand_total_cn = number_to_cn(doc.grand_total)
# doc = 当前正在保存的发票
# custom_grand_total_cn = 发票上的"大写金额"自定义字段（需要先在 Custom Field 中创建）
# doc.grand_total = 发票的价税合计数额
```

**前提条件：** 先在 Sales Invoice 上创建一个 Custom Field，Fieldname 设为 `grand_total_cn`，Label 为"价税合计大写"。

### 3.3 审批流程：不写代码实现多级审批

中国企业的典型审批流程完全可以通过 ERPNext 的 Workflow 引擎配置，不需要写代码：

```
采购申请流程：
  员工提交采购申请
    → 部门经理审批（金额 < 5000 元直接通过，≥ 5000 元进入下一级）
      → 财务经理审批
        → 总经理审批（金额 ≥ 50000 元需要）
          → 采购执行
```

在 ERPNext 中的操作路径：
```
Workflow → New Workflow
  → 选择 DocType（如 Purchase Order）
  → 定义 States（草稿 → 待审批 → 已批准 → 已拒绝）
  → 定义 Actions（提交审批、批准、拒绝）
  → 定义 Conditions（金额 < 5000 自动批准）
  → 保存
```

---

## 4. 性能调优：理解每个参数对你的业务意味着什么

### 4.1 性能问题的"症状翻译器"

当你或同事说系统慢时，先判断具体症状，对症下药：

```
症状 A：打开任何页面都慢（登录后首页要转 5 秒）
  → 大概率是 backend 处理能力不够
  → 解决：增加 backend 实例（4.3 节）

症状 B：报表/导出特别慢，其他操作正常
  → 大概率是数据库查询慢
  → 解决：数据库调优（4.2 节）

症状 C：上传大文件卡住，或者 PDF 生成超时
  → 大概率是 nginx 超时或文件大小限制
  → 解决：调整 PROXY_READ_TIMEOUT 和 CLIENT_MAX_BODY_SIZE

症状 D：系统用着用着突然变慢，重启后又好了
  → 大概率是内存不够，数据库缓存被挤掉
  → 解决：增加服务器内存或降低 innodb_buffer_pool_size
```

### 4.2 数据库调优：每个参数对业务的影响

MariaDB 的配置参数决定了数据读写速度。以下是关键参数，用"公路收费站"来类比理解：

```
innodb_buffer_pool_size（最重要的参数）
  = 数据库的内存工作区大小
  类比：收费站的处理窗口。窗口越多（内存越大），能同时处理的车越多。
  → 设大了：数据库速度明显变快。
  → 设太大（超过物理内存 70%）：系统其他部分内存不够，反而变慢。
  → 建议：服务器总内存的 50-60%。
  业务影响：这个参数直接影响你点开任何一个页面的响应速度。

max_connections
  = 数据库同时接受多少个连接请求
  类比：收费站最多同时有几条车道。
  → 设小了：人多的时候新来的人得等。
  → 设大了：每条车道太窄（每个连接占内存），容易撞车（数据库崩溃）。
  → 建议：1-10 人用 → 50；10-50 人 → 100；50+ 人 → 150-200。
  业务影响：决定"同时能有多少人在系统里操作"。

innodb_flush_log_at_trx_commit
  = 数据库每次写入后多久才真正写到磁盘
  类比：出纳收到现金后，是立刻存银行（安全但慢），还是先放抽屉里（快但有风险）。
  → 1 = 立刻存银行，最安全但最慢
  → 2 = 先放抽屉，1 秒后批量存，折中方案
  → 0 = 不主动存，等系统自己存，最快但不安全（万一断电丢 1 秒数据）
  业务影响：选 1 适合金融类业务（交易记录绝对不能丢）；选 2 适合一般贸易公司。
```

**配置文件模板（根据你的服务器规模选一个）：**

```ini
# ===== 小规模 (< 10 人，4GB 内存) =====
innodb_buffer_pool_size = 1.5G
innodb_log_file_size = 256M
max_connections = 50
innodb_flush_log_at_trx_commit = 2

# ===== 中等规模 (10-50 人，8-16GB 内存) =====
innodb_buffer_pool_size = 8G
innodb_log_file_size = 1G
max_connections = 150
innodb_flush_log_at_trx_commit = 1
innodb_io_capacity = 2000

# ===== 较大规模 (50+ 人，16-32GB 内存) =====
innodb_buffer_pool_size = 16G
innodb_buffer_pool_instances = 8
innodb_log_file_size = 2G
max_connections = 300
innodb_flush_log_at_trx_commit = 1
innodb_io_capacity = 4000
```

### 4.3 增加"处理请求的人手"

```bash
# 增加 backend 实例从 1 到 3
docker compose up -d --scale backend=3
```

**这行命令做了什么？** `--scale backend=3` 告诉 Docker "给我启动 3 个 backend 容器"。Docker 自动把进来的请求轮流转发给这 3 个实例。

**经验公式：** CPU 核心数 × 1.5，但不超过 8。比如 4 核 CPU → 3-4 个 backend。

### 4.4 超时和文件大小

```env
# 在 .env 中加这些配置（如果不加就用默认值）

PROXY_READ_TIMEOUT=300
# 含义：nginx 等待 backend 响应的最长时间（秒）
# 默认 120 秒。如果你的报表生成需要 3 分钟，120 秒就超时了，用户看到 504 错误。
# 改成 300（5 分钟）给报表留足时间。

CLIENT_MAX_BODY_SIZE=100m
# 含义：允许上传的最大文件大小
# 默认 50M。如果你的发票附件、导入文件可能超过 50MB，改大这个值。
```

---

## 5. 简易监控：在客户发现之前你知道出事了

### 5.1 最简单的健康检查

创建一个脚本，每 15 分钟自动检查一次系统是否活着：

```bash
#!/bin/bash
# 保存为 ~/erpnext-healthcheck.sh

SITE="mysite"
ALERT_EMAIL="your-phone@alert.com"  # 改成你的邮箱或手机邮箱

# 检查 1：ERPNext 页面还能打开吗？
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
# curl = 模拟浏览器访问网页
# -s = 静默模式，不显示进度条
# -o /dev/null = 不保存网页内容
# -w "%{http_code}" = 只输出 HTTP 状态码
# 200 = 正常，其他都表示有问题

if [ "$HTTP_CODE" != "200" ]; then
    echo "ERPNext 网站无法访问！HTTP 状态码: $HTTP_CODE" | mail -s "⚠ ERPNext 挂了" $ALERT_EMAIL
    # 发送告警邮件
fi

# 检查 2：磁盘快满了吗？
DISK_USE=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
# df -h / = 查看根目录磁盘使用
# tail -1 = 只取最后一行
# awk '{print $5}' = 取第 5 列（使用百分比）
# tr -d '%' = 去掉百分号，只留数字

if [ "$DISK_USE" -gt 85 ]; then
    echo "磁盘使用率已达 ${DISK_USE}%，达到危险水平！" | mail -s "⚠ 磁盘快满" $ALERT_EMAIL
fi
```

### 5.2 设置定时检查

```bash
# 编辑 crontab 定时任务
crontab -e

# 在打开的文件中添加这一行：
*/15 * * * * /bin/bash ~/erpnext-healthcheck.sh
# 含义：每 15 分钟执行一次健康检查脚本
# */15 = 每 15 分钟
# * * * * = 每天每小时每个分钟...
```

---

## 6. 常见业务场景配置

### 6.1 多公司：一家集团两家子公司

如果你的集团有两家独立核算的子公司，不要混在一个 Site 里，也不一定要建两个 Site。同一个 Site 内可以创建多个 Company：

在 ERPNext 界面：Accounting → Company → New。每个 Company 有独立的会计科目表、独立的银行账户、独立的税号。

### 6.2 多币种与汇率

如果你有进出口业务，需要在 ERPNext 中处理美元、欧元等外币：

```bash
docker compose exec backend bench --site mysite console << 'PY'
import frappe

# 启用自动汇率更新
frappe.db.set_value("Currency Exchange Settings", None,
    "enabled", 1)

# 设置汇率数据来源（frankfurter.app 是免费的汇率 API）
frappe.db.set_value("Currency Exchange Settings", None,
    "service_provider", "frankfurter.app")
# 如果你需要更稳定的商用汇率服务，可以换成银行提供的 API

print("✅ 自动汇率更新已启用。系统会每天更新一次汇率。")
PY
```

### 6.3 邮件配置

ERPNext 可以通过你自己的企业邮箱发送邮件（通知、提醒、报表）：

在 ERPNext 界面：Settings → Email Account → New。

中国常用邮箱的 SMTP 设置：

| 邮箱 | SMTP 地址 | 端口 | 加密 |
|------|----------|------|------|
| QQ 邮箱 | smtp.qq.com | 465 | SSL |
| 163 邮箱 | smtp.163.com | 465 | SSL |
| 企业微信 | smtp.exmail.qq.com | 465 | SSL |

**注意：** 使用 QQ/163 邮箱时，密码不是你的邮箱密码，而是"授权码"。在邮箱设置 → POP3/SMTP 服务中开启并获取。

---

## 7. 故障案例集：症状 → 原因 → 解决

### 案例 1：上班发现系统打不开（502/504 错误）

**症状：** 浏览器显示 502 Bad Gateway 或 504 Gateway Timeout

**判断流程：**

```
Step 1：backend 还活着吗？
  docker compose ps backend
  → 如果 STATUS 是 Restarting 或 Exit，说明 backend 挂了

Step 2：看 backend 的"遗言"（最后的日志）
  docker compose logs backend --tail 50
  → 搜索关键词：error, killed, OOM, out of memory

Step 3：根据日志判断：
  - 看到 "Out of memory" / "OOM" → 内存不够 → 减少 worker 数量或给服务器加内存
  - 看到 "Can't connect to MySQL" → 数据库连不上 → 检查 db 服务状态
  - 看到大量 Python traceback → 代码 bug → 记下错误信息，查社区论坛
```

**快速恢复（不找原因先恢复业务）：**
```bash
docker compose restart backend
# restart = 重启这个容器
# 这能解决 80% 的临时问题（内存泄漏、连接池耗尽等）
```

### 案例 2：磁盘被写满

**症状：** 任何操作都报错，`df -h` 显示磁盘 95%+

```bash
# Step 1：找出谁占了磁盘
# 查看 Docker 占了多少
docker system df
# 查看各目录大小
du -sh /var/lib/docker/* 2>/dev/null | sort -h
# du -sh = 查看文件夹大小
# sort -h = 按大小排序

# Step 2：最常见的元凶是 Docker 日志
docker compose logs --tail 0 2>/dev/null  # 看日志大小

# 或者数据库里积累的历史日志表
docker compose exec backend bench --site mysite console << 'PY'
from frappe.utils import get_datetime
from datetime import timedelta

# 删除 30 天前的错误日志（这些日志存在 MariaDB 里）
cutoff = get_datetime() - timedelta(days=30)
frappe.db.sql("DELETE FROM `tabError Log` WHERE creation < %s", cutoff)
frappe.db.sql("DELETE FROM `tabScheduled Job Log` WHERE creation < %s", cutoff)
frappe.db.commit()
print("✅ 已清理 30 天前的旧日志")
PY
```

### 案例 3：邮件发不出去

**症状：** 系统没有报错，但客户收不到邮件

```bash
# Step 1：在 ERPNext 中测试发送
docker compose exec backend bench --site mysite console << 'PY'
frappe.sendmail(
    recipients=["your-email@test.com"],  # 先发给自己测试
    subject="测试邮件",
    message="如果你收到这封邮件，说明发送功能正常。"
)
print("✅ 已发送测试邮件，请检查收件箱（包括垃圾邮件箱）")
PY

# Step 2：如果收不到
# 检查 1：Email Account 配置的 SMTP 地址和端口是否正确？
# 检查 2：QQ/163 邮箱用的是"授权码"而不是登录密码？
# 检查 3：服务器防火墙是否允许访问 SMTP 端口（465/587）？
```

### 案例 4：中文翻译突然变成英文

```bash
# 原因：缓存被清掉了，翻译没有重新加载
docker compose exec backend bench --site mysite clear-cache
# 如果还不行：
docker compose exec backend bench --site mysite console << 'PY'
from frappe.translate import clear_cache
clear_cache()
print("✅ 翻译缓存已刷新")
PY
```

---

## 8. Docker 不可变性与自定义镜像

> **这是从 Demo 到生产最关键的一课。** 第 2、3 节中那些在容器内的操作，全部只在 Demo 环境有效。生产环境必须走构建镜像这条路。

### 8.1 核心原则（用人话版）

Docker 容器的设计就是**即用即抛**——就像一次性杯子，用完了就扔，要用时从模板（镜像）重新生成一个全新的。

```
你把一个一次性杯子从模具里拿出来，
在里面画了一朵花（等于你在容器里执行了 bench new-app），
然后把杯子扔了（等于 docker compose down），
下次从模具里拿出来的杯子当然没有那朵花（等于你的 App 丢了）。
```

**什么会丢？** 容器内部文件系统的任何修改。
**什么不会丢？** Volume 里的数据、数据库里的数据、ERPNext 界面上的配置。

```
会丢的（重启就没了）：
  ✗ 容器内 bench new-app 创建的 App
  ✗ 容器内 apt-get install 安装的系统包
  ✗ 容器内 pip install 安装的 Python 包
  ✗ 容器内手动修改的 frappe/erpnext 源代码

不会丢的（存在数据库或 Volume 里）：
  ✓ 通过界面创建的 Custom Field
  ✓ 通过界面创建的 Print Format
  ✓ 通过界面创建的 Server Script
  ✓ 上传的文件
  ✓ 所有业务数据（客户、发票、库存...）
```

### 8.2 什么时候需要构建自定义镜像？

以下任何一项选了"是"，就需要：

- [ ] 需要中文字体（PDF 打印用）
- [ ] 安装了翻译补丁 App
- [ ] 自己写了自定义 App
- [ ] 需要 `cn2an` 等 Python 包（中文金额大写）
- [ ] 需要修改 ERPNext 源代码

### 8.3 自定义镜像构建（最简步骤）

```bash
# 第一步：创建构建文件
cd ~/erpnext/frappe_docker
mkdir -p custom-build

# 第二步：写 Dockerfile（告诉系统"基于官方镜像，往里加这些东西"）
cat > custom-build/Containerfile << 'EOF'
# 基于官方 erpnext 镜像（这是你的"模具"）
FROM frappe/erpnext:v16.17.0

# 切换到管理员身份（装软件需要管理员权限）
USER root

# 安装中文字体（让 PDF 打印能正常显示中文）
RUN apt-get update && apt-get install -y --no-install-recommends \
    fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*
# && = 前一条命令成功后才执行下一条
# rm -rf /var/lib/apt/lists/* = 删掉安装包缓存，减小镜像体积

# 安装 Python 包（中文金额大写转换）
RUN pip install --no-cache-dir cn2an

# 切回普通用户（安全原则：不需要管理员时就用普通用户）
USER frappe
EOF

# 第三步：构建镜像
docker build -t yourcompany/erpnext:v16.17.0-cn \
  -f custom-build/Containerfile \
  custom-build/
# docker build = 构建镜像
# -t = 给镜像打标签（名字:版本）
# -f = 指定 Dockerfile 路径

# 第四步：验证——确认中文字体已安装
docker run --rm yourcompany/erpnext:v16.17.0-cn fc-list :lang=zh
# --rm = 运行完就删除这个临时容器
# fc-list :lang=zh = 列出所有中文字体
# 应该能看到 "Noto Sans CJK" 字样

# 第五步：在 .env 中改用你的镜像
# CUSTOM_IMAGE=yourcompany/erpnext
# CUSTOM_TAG=v16.17.0-cn

# 第六步：照常启动
docker compose up -d
```

### 8.4 推送到私有仓库（让公司的 Ubuntu 虚拟机也能用）

你在 M3 上构建的镜像怎么让公司的 Ubuntu 服务器用？上传到镜像仓库：

```bash
# 用阿里云容器镜像服务（国内访问快，私有）
# 1. 去 https://cr.console.aliyun.com 注册
# 2. 创建命名空间和仓库
# 3. 登录
docker login --username=你的阿里云账号 registry.cn-hangzhou.aliyuncs.com

# 4. 给镜像打上阿里云的标签
docker tag yourcompany/erpnext:v16.17.0-cn \
  registry.cn-hangzhou.aliyuncs.com/你的命名空间/erpnext:v16.17.0-cn
# tag = 给同一个镜像贴一个新标签，就像同一个人叫两个名字

# 5. 推送到阿里云
docker push registry.cn-hangzhou.aliyuncs.com/你的命名空间/erpnext:v16.17.0-cn
# push = 上传镜像到远程仓库

# 6. 在 Ubuntu 服务器的 .env 中：
# CUSTOM_IMAGE=registry.cn-hangzhou.aliyuncs.com/你的命名空间/erpnext
# CUSTOM_TAG=v16.17.0-cn
```

### 8.5 版本升级时更新镜像

ERPNext 发布新版本时，重建镜像：

```bash
# 1. 改 Dockerfile 第一行
# FROM frappe/erpnext:v16.18.0

# 2. 重新构建
docker build -t yourcompany/erpnext:v16.18.0-cn -f custom-build/Containerfile custom-build/

# 3. 推送新版本
docker tag yourcompany/erpnext:v16.18.0-cn registry.cn-hangzhou.aliyuncs.com/你的命名空间/erpnext:v16.18.0-cn
docker push registry.cn-hangzhou.aliyuncs.com/你的命名空间/erpnext:v16.18.0-cn

# 4. 修改 .env 中的 CUSTOM_TAG
# CUSTOM_TAG=v16.18.0-cn

# 5. 拉新镜像 + 重启
docker compose pull
docker compose up -d

# 6. 更新数据库结构
docker compose exec backend bench --site all migrate
```

---

## 附录：快速排错速查

### 看一眼就知道系统状态

```bash
docker compose ps                              # 所有服务状态（Up = 正常）
docker compose logs backend --tail 20          # 最近 20 条日志
df -h                                          # 磁盘使用量
```

### 常见急救操作

```bash
docker compose restart backend                 # 重启 backend（80% 临时问题能恢复）
docker compose exec backend bench --site mysite clear-cache  # 清缓存
docker compose down && docker compose up -d     # 全部重启
```

---

> 最后更新：2026-05-09
> 适用版本：ERPNext v16.x
>
> 配套文档：
> - 部署：`ERPNext部署指南_从零到生产.md`
> - 打印：`ERPNext打印模板定制指南_从零到客户交付.md`
> - 运维：本指南
