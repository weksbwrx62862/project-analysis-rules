# project-analyzer

## 概述

项目分析专家 Skill。让 Agent 按照统一的 6 阶段流程，结合 GitNexus 知识图谱引擎，深入分析任意开源项目的架构、代码质量、设计模式和工程实践。

## 触发条件

以下用户输入应激活此 Skill：
- "分析 xxx 项目"
- "帮我看看 xxx 的架构"
- "学习一下 xxx 的设计"
- "评估xxx项目的代码质量"
- "xxx 用了哪些设计模式"
- 指定项目路径并要求深度解析

## 分析流程（6 阶段 + GitNexus 集成）

严格按以下流程执行，每个阶段必须产出中间结果：

### 阶段 1：视角定位（~5% 时间）
**目标**：明确这次分析「学什么」

1. 阅读项目 README、官网、核心文档
2. 用一句话总结项目核心价值
3. 确定分析聚焦点（勾选 1-2 项）：
   - 宏观架构 / 中观模块 / 微观实现 / 设计模式 / 工程实践 / 特定技术
4. 设定时间预算：快速(15min) / 标准(45min) / 深度(90min+)
5. 如项目有 ADR，先行阅读

**产出**：分析聚焦声明 + 时间预算

### 阶段 2：结构扫描（~15% 时间）
**目标**：建立项目的「心智地图」

1. 目录树直觉判断（单体/monorepo？按功能/按层次？核心模块在哪？）
2. 入口点识别（CLI / HTTP / 事件 / 定时任务）
3. 模块边界画图（职责一句话 + 依赖方向箭头）
4. 依赖方向检查（领域→基础？底层→上层？第三方渗透？）

**GitNexus 必用（本阶段不可跳过）**：
- `gitnexus impact <核心类>` — 识别高影响力模块（TS 优先）
- cypher 循环依赖检测 — Python 必做
- cypher 被依赖排行 Top 10 — 识别架构关键节点
- cypher 无被依赖模块 — 死代码候选

**产出**：ASCII 模块依赖图 + 模块职责清单 + 影响排行

### 阶段 3：流程追踪（~25% 时间）
**目标**：追踪 2-3 条核心业务流程

1. 挑选关键流程（根据项目类型选择）
2. 逐层记录：做了什么？为什么在这做？数据如何转换？错误如何传播？
3. 画时序图：标注同步/异步边界、资源获取/释放点、并发点

**GitNexus 必用（本阶段核心工具）**：
- `gitnexus query` 搜索关键流程
- `gitnexus context <入口函数>` 查看完整调用链
- cypher 多跳调用链追踪
- cypher 中间件/拦截器识别

**产出**：2-3 条流程时序图 + 每环节设计解读

### 阶段 4：模式识别（~25% 时间）
**目标**：识别设计模式和反模式

1. 扫描：策略、工厂、装饰器、观察者、适配器、责任链、模板方法、建造者、单例、Repository、CQRS、Event Sourcing、Pipeline
2. 反模式扫描：上帝对象、散弹修改、过度工程化、特性依恋、回调地狱
3. 横向对比同类项目

**GitNexus 必用**：
- `gitnexus query` 搜索模式概念
- cypher 上帝对象检测（方法 > 20）
- cypher 散弹修改风险（fan_in > 15）
- cypher 过度抽象检测（0-1 实现）

**产出**：模式清单 + 反模式清单 + 横向对比

### 阶段 5：质量量化（~15% 时间）
**目标**：用数据说话

1. 自动化工具：cloc、git shortlog、语言特定静态分析
2. 品味指标：纯函数比例、抽象一致性、命名质量、注释质量
3. 测试质量：金字塔形状、场景命名、边界覆盖

**GitNexus 必用**：
- `gitnexus list` — 图谱健康度
- cypher 大文件排行
- cypher 依赖深度
- cypher 测试空白区

**产出**：量化指标表 + 测试评估 + 图谱健康度

### 阶段 6：精华提炼（~15% 时间）
**目标**：可落地的学习成果

1. 可复用模式提炼（3-5 个，附源码位置）
2. 实现技巧记录（眼前一亮的代码）
3. 陷阱警告
4. 改进清单（P0/P1/P2）
5. 学习行动计划

**GitNexus 必用**：
- `gitnexus query` 独特设计搜索
- cypher 技术债务热点（行数 > 500 + fan_in > 5）

**产出**：模式卡片 + 陷阱清单 + 改进建议 + 债务热点

## GitNexus 集成规则（强制）

1. **分析前必须索引**：`gitnexus analyze -f` 目标项目，否则跳过所有 GitNexus 步骤
2. **语言感知**：
   - Python：`impact` 不可单独依赖，必须用 cypher 补充
   - TypeScript：优先用 `impact` 和 `context` 追踪依赖
3. **每阶段必用 GitNexus**：具体命令见各阶段的「GitNexus 必用」部分
4. **图谱数据优先**：先用 Cypher 获取客观数据，再人肉阅读理解

## 参考文档

分析时请参考 `rules/`、`workflow/`、`gitnexus/`、`language-guides/` 目录下的详细规则文档：

- 规则文档：`rules/01-architecture.md` ~ `rules/07-evolution-ops.md`
- 检查清单：`workflow/analysis-checklist.md`
- 报告模板：`workflow/report-template.md`
- GitNexus 集成：`gitnexus/gitnexus-integration.md`
- Cypher 查询库：`gitnexus/cypher-queries.md`
- 语言指南：`language-guides/python.md`, `typescript.md`, `go.md`, `rust.md`

## 分析完成后

1. 按报告模板（`workflow/report-template.md`）生成标准化报告
2. 确保所有观点附带源代码引用（文件:行号）
3. 确保 7 个维度都有评分和简评
4. 如有大量不确定内容，标注分析深度（快速/标准/深度）并说明限制
