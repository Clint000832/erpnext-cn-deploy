# ERPNext 打印模板定制指南 — 从零到客户交付

> 适用对象：零代码基础 · 面向中国客户 · 商业文件
> **核心原则：准确性第一，合规性第二，美观第三。商业单据的错误等于金钱损失。**

---

## 目录

1. [基础概念](#1-基础概念)
2. [五分钟创建第一张模板](#2-五分钟创建第一张模板)
3. [模板语法速成](#3-模板语法速成)
4. [合规性要求：哪些字段绝对不能错](#4-合规性要求哪些字段绝对不能错)
5. [中国增值税发票完整模板](#5-中国增值税发票完整模板)
6. [付款信息：银行账号、金额大写、到账验证](#6-付款信息银行账号金额大写到账验证)
7. [发文件前的强制检查清单](#7-发文件前的强制检查清单)
8. [进阶技巧](#8-进阶技巧)
9. [常用模板差异要点](#9-常用模板差异要点)
10. [调试与故障排查](#10-调试与故障排查)
11. [附录：字段速查表](#11-附录字段速查表)

---

## 1. 基础概念

### 1.1 打印格式就是一张 HTML 网页，系统把它转成 PDF

ERPNext 的打印格式是 **HTML + Jinja2 模板**。你可以完全不写代码（用可视化编辑器），也可以手写 HTML 精确控制。

### 1.2 最重要的概念：数据源 vs 展示层

```
数据源（DocType 中的实际数据）      展示层（你的打印模板）
──────────────────────────      ────────────────────
数据库里的数字不会变               模板写错了，PDF 就错了
金额字段存的是 50000.0           你用 {{ doc.total }} 显示就是 50000.0
                                你用 {{ doc.get_formatted("total") }} 显示就是 ¥ 50,000.00

→ 模板永远从数据库取数据，模板本身不算账。
→ 如果 PDF 上的数字错了，要么是模板字段用错了，要么是数据库里的数据就错了。
→ 先确保 ERPNext 里的单据数据是对的，再谈打印。
```

---

## 2. 五分钟创建第一张模板

```
1. 登录 ERPNext → 搜索栏输入 "Print Format List"
2. 点击右上角 New
3. 选择 DocType（例如 Sales Invoice）
4. 给模板命名（例如 "测试模板_勿用于业务"）
5. 点击 Save
6. 打开一张单据 → 打印 → 下拉选择你的模板 → 预览
```

**建议：** 创建模板后立即在名称中标记"测试中"，确认无误后再改为正式名称。避免有人误选了未完成的模板发给客户。

---

## 3. 模板语法速成

只需要记住三个写法：

```html
<!-- 显示一个字段 -->
{{ doc.customer_name }}
<!-- 输出：张三贸易有限公司 -->

<!-- 格式化显示（金额、日期用这个） -->
{{ doc.get_formatted("total") }}
<!-- 输出：¥ 50,000.00 -->

<!-- 循环输出表格行 -->
{% for item in doc.items %}
    <tr>
        <td>{{ loop.index }}</td>
        <td>{{ item.item_name }}</td>
        <td>{{ item.get_formatted("amount") }}</td>
    </tr>
{% endfor %}
```

---

## 4. 合规性要求：哪些字段绝对不能错

### 4.1 中国增值税发票法定要素

根据《中华人民共和国发票管理办法》及国家税务总局公告，一份合规的增值税发票**必须包含以下全部要素**，缺一不可：

| 序号 | 法定要素 | ERPNext 模板中对应的字段 | 错误后果 |
|------|---------|------------------------|---------|
| 1 | 发票名称 | 硬编码标题「增值税发票」 | 客户拒收 |
| 2 | 发票号码 | `{{ doc.name }}` | 无法抵扣进项税 |
| 3 | 开票日期 | `{{ doc.get_formatted("posting_date") }}` | 影响当期申报 |
| 4 | 购买方名称 | `{{ doc.customer_name }}` | 发票作废 |
| 5 | **购买方纳税人识别号** | **需自定义字段** | **进项税不能抵扣，这是最常见的致命错误** |
| 6 | 购买方地址、电话 | 需自定义或取客户地址 | 专票要求 |
| 7 | 购买方开户行及账号 | 需自定义 | 专票要求 |
| 8 | 货物/服务名称 | `{{ item.item_name }}` | 发票作废 |
| 9 | 规格型号 | `{{ item.description }}` | 专票要求 |
| 10 | 单位 | `{{ item.uom }}` | 发票作废 |
| 11 | 数量 | `{{ item.qty }}` | 金额不对 |
| 12 | 单价 | `{{ item.get_formatted("rate") }}` | 金额不对 |
| 13 | 金额（不含税） | `{{ item.get_formatted("amount") }}` | **金额错误 = 直接金钱损失** |
| 14 | 税率 | 需从 Tax Table 取 | 税额错误导致税务风险 |
| 15 | 税额 | 需从 Tax Table 取 | **税额错误 = 税务稽查风险** |
| 16 | 价税合计（小写） | `{{ doc.get_formatted("grand_total") }}` | **最关键的金额字段** |
| 17 | 价税合计（大写） | 需额外实现 | 法律要求，大小写不符以大写为准 |
| 18 | 销售方名称 | `{{ doc.company }}` | 发票无效 |
| 19 | **销售方纳税人识别号** | **需自定义字段** | **销项税申报错误** |
| 20 | 销售方地址、电话 | 需自定义 | 专票要求 |
| 21 | 销售方开户行及账号 | 需自定义 | 专票要求 |
| 22 | 备注 | `{{ doc.terms }}` 或自定义 | 特定业务备注 |
| 23 | 开票人 | `{{ doc.owner }}` 或自定义 | 合规要求 |
| 24 | 收款人 | 需自定义 | 合规要求 |
| 25 | 复核人 | 需自定义 | 合规要求 |

### 4.2 最容易出错的前 5 个地方

**第一名：纳税人识别号缺失或错误**

ERPNext 原生的 Customer 和 Company DocType **没有纳税人识别号字段**。这意味着直接打印出来的发票，这一栏是空的——客户拿到这样的发票，税务局系统校验不通过，进项税不能抵扣。

必须做以下操作才能让税号出现在打印模板中：

```bash
# 在 Customer 上添加税号字段（如果在界面操作：Customization → Custom Field → New）
# DocType: Customer
# Fieldname: tax_id
# Label: 纳税人识别号
# Field Type: Data
# Length: 20

# 添加后在模板中使用：
{{ doc.custom_tax_id or "【缺失！请补填客户税号】" }}
```

**第二名：价税合计大写金额不准确**

ERPNext 内置的 `get_formatted("grand_total_in_words")` 输出的是英文 "Fifty Thousand Only"，不是中文大写。中文大写（伍万元整）需要单独实现。在大写功能实现之前，**至少确保小写金额和数据库一致**，并且明显标注"大写金额以手写为准"。

**第三名：金额字段直接取值未格式化**

```html
<!-- 危险：输出 50000.0，缺少千分位，容易看错 -->
{{ doc.grand_total }}

<!-- 安全：输出 ¥ 56,500.00，清晰明确 -->
{{ doc.get_formatted("grand_total") }}
```

**第四名：表格行项目的税额和税率显示为空**

ERPNext 的 Sales Invoice Item 表（`doc.items`）并不直接包含税率和税额，这些信息在 Sales Taxes and Charges 子表（`doc.taxes`）中。很多新手模板在明细行里放了空的税率/税额列，看起来就像税率是 0%——这是致命错误。

**解决：** 明细行不要显示每行的税率和税额，改为在汇总区域显示总的税率和税额：

```html
{% for tax in doc.taxes %}
    <tr>
        <td>{{ tax.description }}</td>
        <td>{{ tax.get_formatted("tax_rate") }}%</td>
        <td>{{ tax.get_formatted("tax_amount") }}</td>
    </tr>
{% endfor %}
```

**第五名：单据状态未显示**

已取消的发票、草稿状态的单据如果被当成正式发票发给客户，是灾难性的。**每一张模板都必须在显眼位置显示单据状态：**

```html
{% if doc.docstatus == 0 %}
    <div style="color:red; font-size:24px; font-weight:bold; border:3px solid red; padding:10px; text-align:center; margin-bottom:15px;">
        ⚠ 草 稿 — 非正式文件，禁止对外使用
    </div>
{% elif doc.docstatus == 2 %}
    <div style="color:red; font-size:24px; font-weight:bold; border:3px solid red; padding:10px; text-align:center; margin-bottom:15px;">
        ⚠ 已 作 废 — 本文件无效
    </div>
{% endif %}
```

### 4.3 税务合规红线

```
红线 1：发票上的纳税人识别号不能为空
红线 2：税率不能为 0（除非确实适用零税率，如出口退税）
红线 3：价税合计大写的金额必须和小写一致
红线 4：发票号码必须唯一且连续
红线 5：不能修改已提交（Submitted）发票的数据再打印
红线 6：发票模板上必须明确区分"专票"和"普票"
```

---

## 5. 中国增值税发票完整模板

以下模板已按合规要求编写。**使用前请逐项对照 4.1 节的法定要素清单确认**，特别是需要自定义字段的部分。

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <style>
        @page {
            size: A4;
            margin: 8mm 12mm 8mm 12mm;
        }
        body {
            font-family: "SimSun", "Noto Sans SC", sans-serif;
            font-size: 11px;
            color: #000;
            line-height: 1.5;
        }
        .invoice-title {
            text-align: center;
            font-size: 22px;
            font-weight: bold;
            letter-spacing: 6px;
            margin-bottom: 2px;
        }
        .invoice-no {
            text-align: center;
            font-size: 10px;
            color: #333;
            margin-bottom: 10px;
        }
        .info-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 8px;
        }
        .info-table td {
            border: 1px solid #000;
            padding: 3px 6px;
            vertical-align: top;
        }
        .info-label {
            background: #f0f0f0;
            font-weight: bold;
            width: 100px;
            font-size: 10px;
        }
        .item-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 8px;
        }
        .item-table th {
            background: #e8e8e8;
            border: 1px solid #000;
            padding: 4px 3px;
            font-size: 10px;
            text-align: center;
        }
        .item-table td {
            border: 1px solid #000;
            padding: 3px;
            font-size: 10px;
        }
        .text-right { text-align: right; }
        .text-center { text-align: center; }
        .total-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 8px;
        }
        .total-table td {
            border: 1px solid #000;
            padding: 4px 8px;
        }
        .total-label {
            background: #f0f0f0;
            font-weight: bold;
            width: 150px;
        }
        .grand-total {
            font-size: 14px;
            font-weight: bold;
        }
        .footer-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 4px;
        }
        .footer-table td {
            border: 1px solid #000;
            padding: 3px 6px;
        }
        .sign-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        .sign-table td {
            padding: 20px 8px 8px 8px;
            text-align: center;
            width: 25%;
            font-size: 10px;
        }
        .draft-warning {
            color: #cc0000;
            font-size: 24px;
            font-weight: bold;
            border: 3px solid #cc0000;
            padding: 12px;
            text-align: center;
            margin-bottom: 15px;
            background: #fff0f0;
        }
        @media print {
            body { -webkit-print-color-adjust: exact; }
            .no-print { display: none; }
        }
    </style>
</head>
<body>

    <!-- ==================== 状态警告（最重要，放在最前面） ==================== -->
    {% if doc.docstatus == 0 %}
    <div class="draft-warning">草 稿 — 非正式文件，仅供内部审核，禁止对外使用</div>
    {% elif doc.docstatus == 2 %}
    <div class="draft-warning">已 作 废 — 本文件无效</div>
    {% endif %}

    <!-- ==================== 标题区 ==================== -->
    <div class="invoice-title">
        {% if doc.custom_invoice_type == "special" %}
            增值税专用发票
        {% else %}
            增值税普通发票
        {% endif %}
    </div>
    <div class="invoice-no">发票号码：{{ doc.name or "【未生成】" }}</div>

    <!-- ==================== 购买方信息 ==================== -->
    <table class="info-table">
        <tr>
            <td class="info-label">购买方名称</td>
            <td width="38%">{{ doc.customer_name or "【缺失】" }}</td>
            <td class="info-label">纳税人识别号</td>
            <td width="38%">{{ doc.custom_customer_tax_id or "【缺失】" }}</td>
        </tr>
        <tr>
            <td class="info-label">地址、电话</td>
            <td>{{ doc.custom_customer_address_phone or "" }}</td>
            <td class="info-label">开户行及账号</td>
            <td>{{ doc.custom_customer_bank_account or "" }}</td>
        </tr>
    </table>

    <!-- ==================== 商品明细 ==================== -->
    <table class="item-table">
        <thead>
            <tr>
                <th style="width:4%">序号</th>
                <th style="width:22%">货物或应税劳务名称</th>
                <th style="width:14%">规格型号</th>
                <th style="width:6%">单位</th>
                <th style="width:8%">数量</th>
                <th style="width:10%">单价</th>
                <th style="width:12%">金额</th>
                <th style="width:8%">税率</th>
                <th style="width:16%">税额</th>
            </tr>
        </thead>
        <tbody>
            {% for item in doc.items %}
            <tr>
                <td class="text-center">{{ loop.index }}</td>
                <td>{{ item.item_name or item.item_code }}</td>
                <td>{{ item.description or "" }}</td>
                <td class="text-center">{{ item.uom or "" }}</td>
                <td class="text-right">{{ item.qty }}</td>
                <td class="text-right">{{ item.get_formatted("rate") }}</td>
                <td class="text-right">{{ item.get_formatted("amount") }}</td>
                <td class="text-center">
                    {# 注意：item 层面没有税率，此行会为空。见下方汇总区域的税额明细 #}
                    —
                </td>
                <td class="text-right">
                    {# 同上，税额在 taxes 子表中 #}
                    —
                </td>
            </tr>
            {% endfor %}

            {# 补空行到至少 5 行 #}
            {% for i in range(5 - (doc.items|length)) %}
            <tr>
                <td class="text-center">{{ doc.items|length + loop.index }}</td>
                <td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td>
            </tr>
            {% endfor %}
        </tbody>
    </table>

    <!-- ==================== 金额汇总区（最关键的区域，每项都要核对） ==================== -->
    <table class="total-table">
        <tr>
            <td class="total-label">金额合计（不含税）</td>
            <td width="30%">{{ doc.get_formatted("total") }}</td>
            <td class="total-label">税率</td>
            <td width="30%">
                {% for tax in doc.taxes %}
                    {{ tax.description }}: {{ "%.0f"|format(tax.rate or 0) }}%
                    {% if not loop.last %}&nbsp;{% endif %}
                {% endfor %}
            </td>
        </tr>
        <tr>
            <td class="total-label">税额合计</td>
            <td>{{ doc.get_formatted("total_taxes_and_charges") }}</td>
            <td class="total-label">价税合计（小写）</td>
            <td class="grand-total">{{ doc.get_formatted("grand_total") }}</td>
        </tr>
        <tr>
            <td class="total-label">价税合计（大写）</td>
            <td colspan="3" style="font-weight:bold; font-size:13px;">
                {% if doc.custom_grand_total_cn %}
                    {{ doc.custom_grand_total_cn }}
                {% else %}
                    <span style="color:#cc0000;">【大写金额未生成，请与财务确认】 小写：{{ doc.get_formatted("grand_total") }}</span>
                {% endif %}
            </td>
        </tr>
    </table>

    <!-- ==================== 销售方信息 ==================== -->
    <table class="info-table">
        <tr>
            <td class="info-label">销售方名称</td>
            <td width="38%">{{ doc.company or "【缺失】" }}</td>
            <td class="info-label">纳税人识别号</td>
            <td width="38%">{{ doc.custom_company_tax_id or "【缺失】" }}</td>
        </tr>
        <tr>
            <td class="info-label">地址、电话</td>
            <td>{{ doc.custom_company_address_phone or "" }}</td>
            <td class="info-label">开户行及账号</td>
            <td>{{ doc.custom_company_bank_account or "" }}</td>
        </tr>
    </table>

    <!-- ==================== 开票信息 ==================== -->
    <table class="footer-table">
        <tr>
            <td class="info-label">开票日期</td>
            <td width="25%">{{ doc.get_formatted("posting_date") }}</td>
            <td class="info-label">开票人</td>
            <td width="25%">{{ doc.owner or "" }}</td>
            <td class="info-label">付款期限</td>
            <td width="25%">{{ doc.get_formatted("due_date") }}</td>
        </tr>
        {% if doc.terms %}
        <tr>
            <td class="info-label">备注</td>
            <td colspan="5">{{ doc.terms }}</td>
        </tr>
        {% endif %}
    </table>

    <!-- ==================== 签名区 ==================== -->
    <table class="sign-table">
        <tr>
            <td>开票人（签章）</td>
            <td>复核人（签章）</td>
            <td>收款人（签章）</td>
            <td>销售方（盖章）</td>
        </tr>
    </table>

    <!-- ==================== 底部合规声明 ==================== -->
    <div style="margin-top:15px; font-size:8px; color:#999; text-align:center; border-top:1px solid #ccc; padding-top:8px;">
        本发票由 ERPNext 系统生成 · 打印时间：{{ frappe.utils.now_datetime().strftime("%Y-%m-%d %H:%M") }} · 本文件一式两联
    </div>

</body>
</html>
```

### 5.1 使用前必须完成的准备工作

粘贴模板代码之前，**必须先在系统中创建以下自定义字段**，否则模板中引用这些字段的地方会显示空白：

```bash
# 在 Customer 上需要添加的字段（通过界面：Customization → Custom Field → New）
# 或在运维指南 3.1 节查看通过 Python 脚本批量创建的方法

# Customer 需要的字段：
# 1. tax_id            (Data, 纳税人识别号, length=20)
# 2. address_phone     (Small Text, 地址电话)
# 3. bank_account      (Data, 开户行及账号, length=100)

# Company 需要的字段：
# 1. tax_id            (Data, 纳税人识别号, length=20)
# 2. address_phone     (Small Text, 地址电话)
# 3. bank_account      (Data, 开户行及账号, length=100)

# Sales Invoice 需要的字段：
# 1. invoice_type      (Select, 发票类型, 选项: 普通发票\n专用发票)
# 2. grand_total_cn    (Data, 价税合计大写, length=200)
```

### 5.2 模板代码中故意留的【缺失】标记

注意代码中有 `【缺失】` 标记——这是故意的安全设计。如果某个关键字段没有数据，会在 PDF 上**显式标注"缺失"**，而不是留空白。这样你在发给客户之前一眼就能发现，而不是客户收到后发现少信息。

**正式使用前，把这些 `【缺失】` 替换为实际数据，或保留作为安全网。**

---

## 6. 付款信息：银行账号、金额大写、到账验证

### 6.1 付款信息的安全原则

付款信息（银行账号、金额）是打印模板中**风险最高**的部分。错误意味着客户把钱打到别人的账户，或者金额对不上。

```
原则 1：银行账号不要手写进模板，必须从 Company/Customer 主数据中读取
原则 2：金额大写必须和小写一致。法律上"大小写不符以大写为准"
原则 3：付款信息必须在每次打印时实时从系统读取，不能硬编码
```

### 6.2 银行账号的正确取法

```html
<!-- 在模板中，公司收款账号应该从 Company 的自定义字段读取 -->
<table class="info-table">
    <tr>
        <td class="info-label">收款银行</td>
        <td>{{ doc.custom_company_bank_name or "" }}</td>
        <td class="info-label">银行账号</td>
        <td>{{ doc.custom_company_bank_account or "" }}</td>
    </tr>
    <tr>
        <td class="info-label">开户行</td>
        <td colspan="3">{{ doc.custom_company_bank_branch or "" }}</td>
    </tr>
</table>
```

**特别注意：** 同一家公司在不同单据上显示的银行账号必须一致。如果银行账号要改，**必须改 Company 主数据**，而不是在打印模板里改。这样所有单据自动同步。

### 6.3 金额大写实现方案

ERPNext 原生不支持中文金额大写。以下是几种实现方案，按推荐度排序：

**方案 A（推荐）：用 Python Server Script 预计算**

优势：数据写入单据，打印模板只需读取，不会算错。

```python
# 在你站点的 Server Script 中创建（Home → Customization → Server Script → New）
# Script Type: DocType Event
# DocType: Sales Invoice
# Event: Before Save

# 金额大写转换
import frappe

def number_to_cn_currency(amount):
    """将金额转为中文大写"""
    if amount is None or amount == 0:
        return "零元整"

    units = ["", "拾", "佰", "仟", "万"]
    digits = ["零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖"]

    # 处理负数
    if amount < 0:
        return "负" + number_to_cn_currency(-amount)

    yuan = int(amount)
    jiao = int(round((amount - yuan) * 100))

    result = ""
    if yuan == 0:
        result = "零"
    else:
        # 亿位
        yi = yuan // 100000000
        if yi > 0:
            result += _convert_group(yi, digits, units) + "亿"
            yuan %= 100000000

        # 万位
        wan = yuan // 10000
        if wan > 0:
            result += _convert_group(wan, digits, units) + "万"
            yuan %= 10000

        # 元位
        if yuan > 0:
            result += _convert_group(yuan, digits, units)
        elif result and result[-1] != "亿" and result[-1] != "万":
            pass  # 零元的情况已处理

    result += "元"

    # 角分
    jiao_fen = jiao
    if jiao_fen == 0:
        result += "整"
    else:
        j = jiao_fen // 10
        f = jiao_fen % 10
        if j > 0:
            result += digits[j] + "角"
        if f > 0:
            result += digits[f] + "分"

    return result

def _convert_group(num, digits, units):
    if num == 0:
        return "零"
    result = ""
    str_num = str(num)
    length = len(str_num)
    for i, c in enumerate(str_num):
        d = int(c)
        pos = length - i - 1
        if d == 0:
            if i < length - 1 and str_num[i+1] != '0':
                result += "零"
        else:
            result += digits[d] + units[pos]
    return result

# 保存时自动生成大写金额
doc.custom_grand_total_cn = number_to_cn_currency(doc.grand_total)
```

然后在模板中：

```html
价税合计（大写）：{{ doc.custom_grand_total_cn or "【大写金额未生成】" }}
```

**方案 B：用 cn2an Python 包**

先在自定义镜像中安装 `cn2an`（见运维指南第 8 章），然后在 Server Script 中：

```python
import cn2an
doc.custom_grand_total_cn = cn2an.an2cn(str(int(doc.grand_total))) + "元"
# 注意：cn2an 不能处理小数角和分，需要自行补充
```

**方案 C：纯模板内计算（不推荐，仅供临时使用）**

```html
<!-- 极度简化版中文大写（仅作临时方案，正式业务不要用） -->
{{ "%.2f"|format(doc.grand_total) }} 元
<!-- 只有小写，需要在打印时手动填写大写 -->
<span style="border-bottom:1px solid #000; min-width:150px; display:inline-block;">
    &nbsp;（手写大写）
</span>
```

### 6.4 付款凭证专用模板的安全要求

付款凭证（Payment Entry）是**直接涉及资金转移**的单据，打印模板要求更高：

```html
<!-- 付款凭证模板关键区域 -->
<table class="info-table">
    <tr>
        <td class="info-label" style="background:#fff3cd;">⚠ 付款金额</td>
        <td style="font-size:16px; font-weight:bold; background:#fff3cd;">
            {{ doc.get_formatted("paid_amount") }}
        </td>
        <td class="info-label">大写</td>
        <td style="font-weight:bold;">
            {{ doc.custom_paid_amount_cn or "【未生成】" }}
        </td>
    </tr>
    <tr>
        <td class="info-label">收款方</td>
        <td>{{ doc.party_name or doc.party }}</td>
        <td class="info-label">收款账号</td>
        <td>{{ doc.custom_party_bank_account or "【缺失】" }}</td>
    </tr>
    <tr>
        <td class="info-label">付款方式</td>
        <td>{{ doc.mode_of_payment or "" }}</td>
        <td class="info-label">付款日期</td>
        <td>{{ doc.get_formatted("posting_date") }}</td>
    </tr>
</table>

<!-- 双重确认提示 -->
<div style="border:2px solid #cc0000; padding:10px; margin:10px 0; text-align:center;">
    <strong>⚠ 付款前请确认：收款方名称、账号、金额三项与银行转账信息完全一致 ⚠</strong>
</div>
```

---

## 7. 发文件前的强制检查清单

**每张商业单据在发给客户之前，必须逐项核对。这不是可选的。**

### 7.1 发票类（Sales Invoice、Purchase Invoice）

```
□ 单据状态是 Submitted（已提交），不是 Draft（草稿）或 Cancelled（已作废）
□ 客户/供应商名称完整且正确
□ 纳税人识别号已填写且格式正确（18 位统一社会信用代码）
□ 开票日期是当天或最近的正确日期
□ 商品明细每一项的名称、数量、单价、金额与实际情况一致
□ 金额合计 = 各明细行金额之和（手工加一遍验证）
□ 税额 = 金额合计 × 税率（心算校验）
□ 价税合计 = 金额合计 + 税额
□ 价税合计大写与小写金额一致
□ 银行账号信息完整
□ 打印出来的 PDF 中没有出现「缺失」「未生成」「undefined」「null」字样
□ 中文字体正常显示，没有方块或乱码
□ 纸张方向正确（A4 纵向）
□ 页码正常（多页时检查）
```

### 7.2 付款凭证（Payment Entry）

```
□ 付款金额与大写一致
□ 收款方名称与银行账户名称一致
□ 收款账号与银行记录完全一致（逐位核对！）
□ 付款方式正确
□ 对应的发票已关联且状态正确
□ 单据状态是 Submitted
```

### 7.3 合同类（Quotation / 自定义合同）

```
□ 合同编号正确
□ 双方公司名称正确（与营业执照一致）
□ 金额与协商一致
□ 付款条件明确
□ 有效期/交付日期明确
□ 签名区保留
□ 附件页码完整
```

### 7.4 建立二审制度

如果公司有两个人以上，建议建立最简单的二审：

```
制单人：在 ERPNext 里录入单据、生成 PDF
审核人：打开 PDF，对照上面的检查清单逐项核对
        审核人在打印件上签字或系统中 Approve
        只有审核通过的单据才能发给客户

→ ERPNext 的 Workflow 功能可以实现审批流（见运维指南 6.3 节）
```

---

## 8. 进阶技巧

### 8.1 自动验证脚本：在打印模板中嵌入数据校验

可以在模板中写简单的校验逻辑，不通过则在 PDF 上显示警告：

```html
<!-- 金额核验 -->
{% set items_sum = namespace(total=0) %}
{% for item in doc.items %}
    {% set items_sum.total = items_sum.total + (item.amount or 0) %}
{% endfor %}

{% if (items_sum.total - doc.total)|abs > 0.01 %}
<div style="color:red; font-weight:bold; border:2px solid red; padding:8px; margin:10px 0;">
    ⚠ 数据异常：明细行金额合计 {{ "%.2f"|format(items_sum.total) }}
    与单据总金额 {{ "%.2f"|format(doc.total) }} 不一致！
    请勿发送本文件，联系系统管理员检查数据。
</div>
{% endif %}
```

### 8.2 给草稿和正式版不同的视觉区分

```css
/* 草稿状态下整个页面变灰 */
{% if doc.docstatus == 0 %}
body { filter: grayscale(30%); }
{% endif %}
```

### 8.3 防止金额被篡改：打印后禁止修改

ERPNext 中 Submitted 状态的单据已经不能直接修改。但如果要做额外保护：

```bash
# 设置打印后锁定
# Home → Customization → Workflow → 创建 Workflow：
# Draft → Submitted（需要 Approve 权限）
# Submitted → 打印（自动记录打印日志）
```

### 8.4 打印日志追踪

每次打印都会在系统中留下记录。可以查询：

```bash
# 查看打印历史
docker compose exec backend bench --site mysite console << 'PY'
from frappe.utils import get_datetime
from datetime import timedelta

# 查看最近 7 天的打印记录
cutoff = get_datetime() - timedelta(days=7)
logs = frappe.get_all("DocType", filters={"name": "Sales Invoice"})
print("检查 Error Log 中的打印相关记录")
PY
```

---

## 9. 常用模板差异要点

每种单据的模板重点不同。以下标注的是**每种单据独有的风险点**：

### 9.1 销售发票（Sales Invoice）
- 专票/普票区分（专票必须包含全部 25 项要素）
- 含税 vs 不含税价格标注
- 最严格合规要求

### 9.2 采购订单（Purchase Order）
- 不是正式发票，必须标注「采购订单 — 非付款凭证」
- 交货日期明确
- 供应商确认栏

### 9.3 发货单（Delivery Note）
- 收货人签收栏（最关键的差异）
- 实发数量 vs 应发数量
- 运输方式、车牌号（如果需要）

### 9.4 报价单（Quotation）
- 必须注明「本报价单有效期为 XX 天」
- 报价单不是合同，需注明「以最终合同为准」
- 联系人信息

### 9.5 付款凭证（Payment Entry）
- **风险最高**，必须二审
- 银行账号、金额大写、收款方名称三重核对
- 关联发票列表

### 9.6 费用报销单（Expense Claim）
- 报销人、审批人、付款状态
- 附件发票张数
- 审批链记录

---

## 10. 调试与故障排查

### 10.1 上线前的测试流程

**新模板上线前，必须经过以下测试：**

```
第 1 轮：用一张真实数据单据，打印预览，逐项对照数据库核对
第 2 轮：用一张金额特殊的单据测试（大金额、零金额、负金额）
第 3 轮：用一张多行商品的单据测试（10+ 行，检查分页）
第 4 轮：用不同状态的单据测试（草稿、已提交、已作废）
第 5 轮：用真实打印机打一张纸质的，检查字体大小和边距
```

### 10.2 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| PDF 中文显示为方块 | 容器内无中文字体 | 自定义镜像装 `fonts-noto-cjk`（运维指南第 8 章） |
| 税率/税额列为空 | Item 层面无税率数据，税在 taxes 子表 | 明细行不显示税率，汇总区用 `doc.taxes` 循环 |
| 金额不对 | 可能用了 `doc.total` 而非 `doc.get_formatted("total")` | 统一用 `get_formatted` |
| 分页位置把签名区切断 | 没控制分页 | 加 `page-break-inside: avoid` |
| 自定义字段不显示 | 字段名拼写错误或未创建 | 在 Custom Field List 中确认字段存在 |
| `【缺失】` 标记出现 | 数据未填写 | 补填数据后再打印 |

---

## 11. 附录：字段速查表

### 11.1 Sales Invoice

| 中文含义 | 模板代码 | 备注 |
|---------|---------|------|
| 发票号码 | `{{ doc.name }}` | 系统自动生成 |
| 客户名称 | `{{ doc.customer_name }}` | |
| 开票日期 | `{{ doc.get_formatted("posting_date") }}` | |
| 到期日 | `{{ doc.get_formatted("due_date") }}` | |
| 不含税金额 | `{{ doc.get_formatted("total") }}` | **必须用 get_formatted** |
| 税额 | `{{ doc.get_formatted("total_taxes_and_charges") }}` | |
| 价税合计 | `{{ doc.get_formatted("grand_total") }}` | **最关键的金额** |
| 已付金额 | `{{ doc.get_formatted("paid_amount") }}` | |
| 未付金额 | `{{ doc.get_formatted("outstanding_amount") }}` | |
| 状态 | `{{ doc.status }}` | Draft/Submitted/Paid/Cancelled |
| 单据状态码 | `{{ doc.docstatus }}` | 0=草稿 1=已提交 2=已作废 |
| 备注 | `{{ doc.terms }}` | |
| 公司名 | `{{ doc.company }}` | |

### 11.2 Items 子表

```html
{% for item in doc.items %}
    {{ loop.index }}                        {# 行号 #}
    {{ item.item_code }}                    {# 物料编码 #}
    {{ item.item_name }}                    {# 物料名称 #}
    {{ item.description }}                  {# 规格描述 #}
    {{ item.qty }}                          {# 数量 #}
    {{ item.uom }}                          {# 单位 #}
    {{ item.get_formatted("rate") }}        {# 单价 #}
    {{ item.get_formatted("amount") }}      {# 行金额 #}
{% endfor %}
```

### 11.3 Taxes 子表

```html
{% for tax in doc.taxes %}
    {{ tax.description }}                   {# 税种描述，如"增值税 13%" #}
    {{ tax.rate }}                          {# 税率数字，如 13 #}
    {{ tax.get_formatted("tax_amount") }}   {# 税额 #}
    {{ tax.get_formatted("total") }}        {# 计税基础金额 #}
{% endfor %}
```

---

> 最后更新：2026-05-09
> 适用版本：ERPNext v15+
>
> **使用本指南的前提：模板上线前必须完成第 7 节的强制检查清单，确认数据准确无误。**

配套文档：
- `ERPNext部署指南_从零到生产.md` — 环境搭建
- `ERPNext运维进阶与本地化指南.md` — 日常运维 + 自定义镜像构建（第 8 章）
- 本指南 — 打印模板 + 合规验证
