从 0 开始建站文档
1. 目标定义
这个项目不是普通静态个人站，而是一个“个人经营延伸型网站系统”，前台用于展示你的方向、项目与方法论，后台用于长期内容管理，数据库作为全部内容的唯一来源。
因此，源码负责界面、结构、样式、读写逻辑和迁移能力，不负责保存正式内容；正式内容必须保存在数据库中，由前台读取、由后台维护。

2. 先纠正部署前提
如果“所有内容都建立在数据库而不是源码”，那 GitHub Pages 不能继续作为唯一生产承载，因为 GitHub Pages 是静态站点托管服务，只发布仓库中的 HTML、CSS、JavaScript 文件，可选构建，但不提供数据库运行时。
而 Astro 对这类需求的官方路径是启用 adapter，让部分或全部路由按请求在服务器端渲染；Cloudflare 官方也提供了 Astro 的运行方案，并说明在启用 Cloudflare adapter 后，项目可使用 output: 'server' 进行服务端渲染。

3. 最终架构
建议把系统固定成三层结构：

层级	作用	关键原则
Public Site	对外网站前台，负责展示首页、About、Projects、项目详情、Contact、法务页	只读数据库，不把正式内容写死在页面源码里。
CMS / Admin	你自己的后台管理界面，负责维护页面、项目、链接、站点设置	GUI 管理为主，尽量无代码运维。
Data Layer	内容与配置的数据库层	数据库是唯一真相源，结构清晰，可导出，可迁移。
这三层必须边界明确：前台渲染，后台管理，数据库存储；任何一层都不应该兼职另一层的“真相源”。
也就是说，src/pages 不再承担内容仓库角色，数据库 schema 才是站点内容系统的核心。

4. 页面范围
前台首批固定页面如下：

/：定位页，说明你在做什么、关注什么、站内入口是什么。

/about：视角页，表达工作观、系统观、构建方式。

/projects：项目列表页。

/projects/[slug]：项目详情页，至少先有 erpnext-deployment 和 ai-workflow。

/contact：关系入口页。

/privacy：隐私页。

/terms：条款页。

后台首批固定模块如下：

/admin

/admin/pages

/admin/projects

/admin/resources

/admin/settings

后台先不做企业级复杂权限系统，但必须形成完整的内容管理闭环。

5. 为什么不用“源码存内容”
源码存内容的好处只是第一天快，但它会把你锁定在“以后每次更新都要进仓库改文件”的维护模式里，这正好违背你“尽可能无代码运维”的要求。
而数据库驱动的真正价值在于：前台读取内容，后台写入内容，迁移时导出数据库和 schema 即可，内容与模板不再互相绑死。

6. 技术选型
固定技术栈建议如下：

前台框架：Astro

样式：原生 CSS，tokens 先行

运行时：Cloudflare Workers / Cloudflare Pages with runtime

数据库：Cloudflare D1

部署/CLI：Wrangler

语言：TypeScript strict

客户端交互：默认零 JS，后台必要处允许极少量原生 JS

不引入 React / Vue，除非后台局部交互已无法用 Astro + HTML + 少量 JS 合理实现

这样选的原因不是追潮流，而是为了同时满足：内容型站点性能、数据库驱动、后台可维护，以及未来迁移时结构可解释。

7. 目录结构
建议项目目录从第一天就按“前台 / 后台 / 数据层”拆开：

text
/
├── src/
│   ├── layouts/
│   │   ├── Base.astro
│   │   ├── Page.astro
│   │   ├── ProjectDetail.astro
│   │   └── Admin.astro
│   ├── pages/
│   │   ├── index.astro
│   │   ├── about.astro
│   │   ├── projects/
│   │   │   ├── index.astro
│   │   │   └── [slug].astro
│   │   ├── contact.astro
│   │   ├── privacy.astro
│   │   ├── terms.astro
│   │   ├── admin/
│   │   │   ├── index.astro
│   │   │   ├── pages.astro
│   │   │   ├── projects.astro
│   │   │   ├── resources.astro
│   │   │   └── settings.astro
│   │   └── api/
│   │       ├── admin/
│   │       │   ├── pages.ts
│   │       │   ├── projects.ts
│   │       │   ├── resources.ts
│   │       │   └── settings.ts
│   │       └── auth/
│   │           └── login.ts
│   ├── components/
│   │   ├── Header.astro
│   │   ├── Footer.astro
│   │   ├── SectionHeader.astro
│   │   ├── ProjectCard.astro
│   │   ├── Callout.astro
│   │   ├── AdminSidebar.astro
│   │   └── AdminTable.astro
│   ├── lib/
│   │   ├── db.ts
│   │   ├── queries/
│   │   │   ├── pages.ts
│   │   │   ├── projects.ts
│   │   │   ├── resources.ts
│   │   │   └── settings.ts
│   │   ├── services/
│   │   │   ├── page-service.ts
│   │   │   ├── project-service.ts
│   │   │   ├── resource-service.ts
│   │   │   └── setting-service.ts
│   │   └── auth.ts
│   ├── styles/
│   │   ├── tokens.css
│   │   ├── base.css
│   │   ├── utility.css
│   │   └── admin.css
│   └── types/
│       ├── page.ts
│       ├── project.ts
│       ├── resource.ts
│       └── setting.ts
├── migrations/
│   ├── 0001_init.sql
│   ├── 0002_seed_core_pages.sql
│   └── 0003_seed_projects.sql
├── public/
├── astro.config.mjs
├── wrangler.toml
├── tsconfig.json
├── package.json
└── README.md
这个目录的重点不是“看起来完整”，而是强制边界清楚：页面只渲染，lib/services 负责业务，lib/queries 负责数据访问，migrations 负责 schema 与初始化。

8. 数据库是唯一真相源
从现在开始，下面这些内容都必须只存在于数据库中：

首页文本与区块内容

About 页面文本

Contact 页面信息

Privacy / Terms 文本

项目列表

项目详情内容

ERPNext 的 8 份文档入口

站点设置：站点标题、简介、导航、页脚、外链入口等

允许源码保留的只有两类“非内容”信息：

数据模型定义与类型

页面结构和渲染逻辑

换句话说，源码里可以有 interface Project，但不应有正式生产内容的长文本常量。

9. 数据库表设计
建议第一版 schema 这样设计。

9.1 site_settings

作用：保存站点层全局配置。

字段建议：

id

site_name

site_tagline

site_description

contact_email

footer_text

navigation_json

seo_default_title

seo_default_description

created_at

updated_at

这里 navigation_json 可以先用 JSON 字段风格保存导航配置，以降低第一版复杂度。

9.2 pages

作用：保存固定页面内容。

字段建议：

id

slug，如 home、about、contact、privacy、terms

title

subtitle

summary

content_json

status

created_at

updated_at

关键点：不要把页面做成单一 content 大文本。
content_json 应保存结构化区块，例如 hero、intro、sections、cta，这样后台和前台都容易扩展。

9.3 projects

作用：保存项目主信息。

字段建议：

id

slug

title

subtitle

summary

status

featured

sort_order

cover_variant

created_at

updated_at

9.4 project_sections

作用：保存项目详情区块。

字段建议：

id

project_id

section_key，如 context、scope、approach、implementation、outcome

heading

body

sort_order

created_at

updated_at

这个表非常重要，因为它避免你把项目详情又塞回一个大字段里。
项目详情页真正长期主义的形式，不是一个超长 blob，而是多个结构化区块。

9.5 resource_links

作用：保存项目关联文档与外链。

字段建议：

id

project_id

label

url

description

resource_type

sort_order

created_at

updated_at

ERPNext 的 8 份文档入口应该在这里，而不是写死在项目页面源码里。

10. 内容建模原则
第一版建模要遵守四条原则：

先结构化，不先模板化。

先保证数据库表达力，再谈页面排版。

不为了“通用”而过度抽象。

不为了“快”把所有内容都做成一列大文本。

你真正要避免的，不是“表太少”，而是“表看着有了，内容还是没结构”。

11. 初始化内容策略
项目第一版需要初始化这些内容到数据库中：

pages：home、about、contact、privacy、terms

projects：erpnext-deployment、ai-workflow

project_sections：两项目的结构区块

resource_links：ERPNext 的 8 个文档入口

site_settings：站点标题、默认说明、导航、页脚

这意味着第一批内容虽然会通过 seed 脚本进入数据库，但进入数据库后，正式维护入口应转为后台 GUI，而不是继续改 seed 文件。

12. Astro 渲染模式
Astro 默认会在构建期把页面预渲染成静态 HTML，但如果页面或路由需要按请求读取数据库，则需要启用 adapter，并使用 on-demand rendering；Astro 文档明确说明，添加适配器后可以为需要的页面关闭预渲染，或将整个站点设为 output: 'server'。
对你这个项目，更合理的策略是把站点设为服务端模式，让内容页默认从数据库读取；只有完全不依赖实时数据库的少数资源，才考虑单独预渲染。

13. Cloudflare 运行时
Cloudflare 的 Astro 指南明确说明，若站点使用按需渲染，需要安装 @astrojs/cloudflare，并且该适配器会把 Astro 构建输出设置成 output: 'server'，由 Cloudflare Worker 承担服务端渲染。
同时，Cloudflare D1 是其面向 Workers 和 Pages 项目的托管、无服务器 SQL 数据库，具备 SQLite 语义，并支持导入、查询以及时间恢复能力。

这正好符合你的三个目标：

数据库为唯一内容源。

前台具备数据库读取能力。

未来迁移时可以导出 schema 和内容，不必再从源码里抠正文。

14. 后台设计
后台不追求“企业控制台”，而追求稳定、清晰、可操作。

14.1 /admin

显示：

站点概览

页面总数

项目总数

最近更新

快速入口

14.2 /admin/pages

用于编辑固定页面：

首页

About

Contact

Privacy

Terms

操作方式建议：

表单编辑 metadata

结构化区块编辑 content_json

保存后直接写数据库

14.3 /admin/projects

用于管理项目：

新建项目

编辑项目 metadata

编辑项目 sections

管理资源链接

调整排序与状态

14.4 /admin/resources

用于统一管理文档链接和外部资源。
ERPNext 的 8 份文档入口应优先在这里维护，而不是散落在页面配置里。

14.5 /admin/settings

用于站点级配置：

站点名

描述

导航

页脚

联系方式

默认 SEO 字段

15. 后台交互原则
后台要做到“后期尽量无代码运维”，但不等于第一版就做富文本编辑器、拖拽布局器、可视化 page builder。
第一版更合理的是：结构化表单 + 文本域 + 排序字段 + 状态控制，这样最稳，也最利于迁移。

也就是说：

不要先做所见即所得编辑器

不要先做 block builder

不要先做复杂媒体库

不要先做角色权限系统

先把内容系统做对，比把 CMS 做花哨更重要。

16. 身份验证
后台必须有最小可用身份验证，否则 /admin 只是公开入口。
第一版建议做最小管理员登录，只支持单管理员使用，目标是：

简单登录

Cookie / session 维持状态

未登录访问 /admin 时跳转登录

Astro 在按需渲染模式下可访问请求、响应和 cookies，适合做这类最小后台鉴权。
Cloudflare 的 Astro 运行方案也提到 Astro 的 Sessions API 在 Cloudflare 适配器下会自动使用 KV 进行会话存储。

如果你追求更低复杂度，第一版也可先使用简化凭证方案，但必须保留未来升级路径。

17. API 设计
建议后台通过 src/pages/api/admin/*.ts 提供最小 API：

GET /api/admin/pages

POST /api/admin/pages

GET /api/admin/projects

POST /api/admin/projects

GET /api/admin/resources

POST /api/admin/resources

GET /api/admin/settings

POST /api/admin/settings

这样做的好处是：

前台与后台共用同一套服务层

迁移到别的平台时，接口边界依然清楚

以后想拆成独立后台，也不会推翻数据层设计

18. 服务层设计
建议使用三层访问逻辑：

db.ts：获取 D1 绑定与基础执行器

queries/*：单表或基础查询

services/*：业务聚合逻辑

例如：

project-service.ts 负责“项目 + sections + resource_links”的聚合读取

页面组件只调用 service，不直接写 SQL

这一步看起来比“直接在 page 里查库”多一层，但它能显著降低未来迁移成本。
因为你未来换数据库、换托管，真正要改的是 db + queries，而不是所有页面文件。

19. 样式系统
即使现在有后台，也仍然坚持 tokens 先行：

tokens.css：色彩、字号、间距、圆角、阴影、宽度

base.css：reset、typography、默认节奏

utility.css：克制的工具类

admin.css：后台专用样式层

前台和后台不要完全共用所有视觉规则，但应共用最底层的设计令牌。
这样才能既统一系统气质，又避免后台样式反向污染前台。

20. 前台页面策略
首页 / 不是欢迎页，而是定位页。
其内容来自数据库中的 home 页面配置，至少包含：你在做什么、当前关注方向、代表性项目入口、为什么值得继续看。

About /about 不做简历堆砌。
它应由结构化区块组成，比如：

思考方式

工作方式

系统观

内容观

Projects /projects 从 projects 表直接读取列表。
项目详情 /projects/[slug] 则读取项目主信息、sections 与 resource links 的聚合结果。

21. ERPNext 页面组织
erpnext-deployment 是核心页面，建议在数据库中按以下区块组织：

intro

context

scope

docs-nav

audience

outcome

next-step

其中“8 份文档入口”不直接写进 section 文本，而是放在 resource_links 表中，再由项目页模板渲染出来。
这样未来你要增删文档入口时，只改后台数据，不动页面模板。

22. AI Workflow 页面组织
ai-workflow 先做轻量项目，但不能是空壳。
建议最少有：

项目简介

适用场景

方法路径

当前状态

下一步计划

这同样通过 projects + project_sections 表来表达，而不是单独给它写一个特判页面。

23. 初始化步骤
从 0 开始的真实执行顺序建议是：

初始化 Astro 项目骨架

手动配置 TypeScript strict

安装 Cloudflare adapter

建立 wrangler.toml

创建 D1 数据库并绑定

编写 migrations/0001_init.sql

编写 seed SQL

建立 db / queries / services

建立 layouts 与组件

先打通首页 + 后台页面管理最小闭环

再打通项目管理

再补资源管理与设置管理

再做响应式检查与部署验证

24. 本地开发与验证
Astro 在本地可运行开发服务器，Cloudflare 的 Astro 指南也要求使用项目本地开发命令进行调试，并通过 build + deploy 流程部署到 Workers。
你需要固定执行以下验证：

本地开发可启动

数据库连接可用

/admin 可登录

后台改内容后，前台可正确反映

桌面端无明显布局问题

移动端可用

控制台无明显报错

构建通过

部署通过

25. 迁移策略
你要求“后期服务器迁移”，所以从第一天开始就要约定迁移单位。

未来迁移时需要带走的核心资产应只有三类：

数据库 schema

数据内容导出

前台/后台应用源码

只要这三类边界清楚，你从 Cloudflare 迁到别的平台时，虽然要重接运行时和数据库适配，但不会再遇到“正文埋在源码里”或“后台逻辑绑死在平台页面里”的灾难。

第一版就要做到：

schema 可读

SQL migration 可追踪

内容可导出

服务层可替换

26. 当前推荐部署结论
结论上，最适合你当前目标的生产路线是：

开发：Astro + TypeScript + 原生 CSS

运行：Astro on-demand rendering

承载：Cloudflare Workers/Pages 运行时

数据：Cloudflare D1

后台：站内 /admin CMS

因为 Astro 官方明确支持通过 adapter 进行按需渲染，Cloudflare 官方明确提供 Astro 运行方案，而 D1 则专门面向 Workers 和 Pages 的 SQL 数据库场景。
相反，GitHub Pages 作为静态站点托管服务，不能满足“数据库为唯一内容源”的生产要求。

27. 第一版验收标准
第一版不是“所有功能都做完”，而是这 8 条成立：

所有正式内容都在数据库。

前台页面不再依赖源码硬编码内容。

后台可通过 GUI 改页面与项目内容。

ERPNext 的 8 个文档入口由后台维护。

About、Contact、法务页可后台编辑。

前台与后台样式边界清楚。

部署后可正常读取数据库。

迁移时可明确导出 schema 和内容。