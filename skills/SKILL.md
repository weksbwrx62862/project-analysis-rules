---
name: project-analyzer
description: 开源项目深度分析专家。当用户要求分析、评估、学习或审计任意开源项目时使用此 Skill。按 7 阶段结构化流程（含强制报告输出）结合 GitNexus 知识图谱执行分析，输出各维度 1-4 评分的标准化报告并自动保存为 Markdown 文件。
# EXTENDED METADATA (MANDATORY)
github_url: https://github.com/weksbwrx62862/project-analysis-rules
github_hash: a31bdc3
version: 1.1.0
created_at: 2026-05-03
dependencies: ["gitnexus@1.6.4-rc.43"]
---

# 开源项目分析专家

按统一流程深度分析任意开源项目，提炼可学习借鉴的设计智慧。

## 触发条件

- "分析 xxx 项目"
- "帮我看看 xxx 的架构"
- "学习一下 xxx 的设计"
- "评估 xxx 项目的代码质量"
- "xxx 用了哪些设计模式"
- 指定项目路径要求深度解析

---

## 分析前置（强制）

开始分析前必须执行：

```bash
cd <目标项目目录>
gitnexus analyze -f          # 强制重新索引，确保图谱最新
gitnexus list                # 确认索引成功，记录节点/边/集群/流程数
```

**语言兼容性提醒**：

| 语言 | query | context | impact | cypher | 说明 |
|------|-------|---------|--------|--------|------|
| TypeScript | ✅ 好 | ✅ 好 | ✅ 好 | ✅ 好 | 所有功能最佳 |
| Python | ✅ 好 | ✅ 好 | ⚠️ 有限 | ✅ 好 | impact 不可单独依赖，必须用 cypher 补充 |
| Go | ✅ 好 | ✅ 好 | ✅ 好 | ✅ 好 | |
| Rust | ✅ 可 | ✅ 可 | ✅ 可 | ✅ 可 | |

---

## 分析流程（7 阶段）

严格按阶段递进，不可跳过。每个阶段有明确产出。

### 阶段 1：视角定位（~5%）

1. 阅读 README/官网/文档，一句话总结项目核心价值
2. 确定分析聚焦点（勾选 1-2 项）：
   - 宏观架构 / 中观模块 / 微观实现 / 设计模式 / 工程实践 / 特定技术
3. 设定时间预算：快速(15min) / 标准(45min) / 深度(90min+)
4. 如项目有 ADR，先行阅读

**产出**：分析聚焦声明 + 时间预算

### 阶段 2：结构扫描（~15%）

**手动分析**：
1. 目录树直觉判断：单体/monorepo？按功能/按层次？核心模块在哪？
2. 入口点识别：CLI / HTTP / 事件 / 定时任务
3. 每个核心模块一句话职责 + ASCII 依赖方向图
4. 领域层→基础层？底层→上层？第三方渗透？

**GitNexus 辅助**：
```bash
gitnexus impact <核心类名> --repo <名称>           # 波及 > 20 文件 → 关键节点

# 循环依赖检测（Python 必做）
gitnexus cypher "
  MATCH (a:Module)-[:IMPORTS]->(b:Module)
  MATCH (b)-[:IMPORTS*1..5]->(a)
  RETURN DISTINCT a.name, b.name
" --repo <名称>

# 被依赖排行 Top 10
gitnexus cypher "
  MATCH (m:Module)<-[:IMPORTS]-(other)
  RETURN m.name, count(other) AS importers
  ORDER BY importers DESC LIMIT 10
" --repo <名称>

# 无被依赖模块（死代码候选）
gitnexus cypher "
  MATCH (m:Module)
  WHERE NOT (m)<-[:IMPORTS]-()
  RETURN m.name
" --repo <名称>
```

**产出**：ASCII 依赖图 + 模块职责清单 + GitNexus 影响排行

### 阶段 3：流程追踪（~25%）

**挑选关键流程**（根据项目类型）：

| 项目类型 | 建议追踪流程 |
|----------|-------------|
| Web 框架 | HTTP 请求 → 路由 → 中间件链 → 控制器 → 响应 |
| CLI 工具 | 参数解析 → 配置加载 → 核心逻辑 → 输出 |
| 数据库 | SQL 解析 → 优化 → 执行 → 结果返回 |
| 消息队列 | 消息生产 → 存储 → 分发 → 消费 → ACK |
| 编译器 | 词法分析 → 语法分析 → 语义分析 → 代码生成 |

**逐层记录**：每层做什么？为什么在这层？数据如何转换？错误如何传播？哪里有缓存？

**GitNexus 辅助**（本阶段核心工具）：
```bash
gitnexus query "request routing middleware chain" --repo <名称>
gitnexus context <入口函数名> --repo <名称>           # 360° 调用链视图

# 多跳调用链（最多 5 跳）
gitnexus cypher "
  MATCH path=(start:Function {name:'handle_request'})-[:CALLS*1..5]->(end:Function)
  RETURN path LIMIT 10
" --repo <名称>

# 中间件/拦截器识别
gitnexus cypher "
  MATCH (a:Function)-[:CALLS]->(m:Function)-[:CALLS]->(b:Function)
  WHERE m.name CONTAINS 'middleware' OR m.name CONTAINS 'interceptor'
  RETURN m.name, a.name, b.name
" --repo <名称>
```

**产出**：2-3 条流程时序图 + 每环节设计解读

### 阶段 4：模式识别（~25%）

**设计模式扫描**（13 种）：策略、工厂、装饰器、观察者、适配器、责任链、模板方法、建造者、单例（警惕滥用！）、Repository、CQRS、Event Sourcing、Pipeline/Filter

**反模式扫描**（8 种）：上帝对象、散弹修改、特性依恋、过度工程化、分布式单体、回调地狱、魔法数字、配置满天飞

**GitNexus 辅助**：
```bash
gitnexus query "strategy pattern observer adapter" --repo <名称>

# 上帝对象（方法 > 20）
gitnexus cypher "
  MATCH (c:Class)
  OPTIONAL MATCH (c)-[:HAS_METHOD]->(m:Method)
  WITH c, count(m) AS method_count
  WHERE method_count > 20
  RETURN c.name, method_count ORDER BY method_count DESC
" --repo <名称>

# 散弹修改风险（fan_in > 15）
gitnexus cypher "
  MATCH (m:Module)<-[:IMPORTS]-(other)
  WITH m, count(other) AS fan_in
  WHERE fan_in > 15
  RETURN m.name, fan_in ORDER BY fan_in DESC
" --repo <名称>

# 过度抽象（0-1 实现）
gitnexus cypher "
  MATCH (i:Interface)
  OPTIONAL MATCH (c:Class)-[:IMPLEMENTS]->(i)
  WITH i, count(c) AS impl_count
  WHERE impl_count <= 1
  RETURN i.name, impl_count
" --repo <名称>
```

**产出**：模式清单 + 反模式清单 + 横向对比

### 阶段 5：质量量化（~15%）

**自动化工具**：cloc、git shortlog、语言静态分析（Python: radon/mypy、TS: eslint/tsc、Go: gocyclo/go vet）

**品味指标**：纯函数比例、抽象层次一致性、命名质量、注释质量（解释"为什么"vs"做什么"）、文件大小分布

**测试质量**：测试金字塔形状、测试命名是否描述场景、边界条件覆盖、是否可离线运行

**GitNexus 辅助**：
```bash
gitnexus list   # 图谱健康度：边/节点比 > 2.0 = 高耦合

# 大文件 Top 10
gitnexus cypher "
  MATCH (m:Module) RETURN m.name, m.lines AS line_count
  ORDER BY line_count DESC LIMIT 10
" --repo <名称>

# 依赖深度 Top 10
gitnexus cypher "
  MATCH path=(a:Module)-[:IMPORTS*1..10]->(b:Module)
  WITH a, max(length(path)) AS max_depth
  RETURN a.name, max_depth ORDER BY max_depth DESC LIMIT 10
" --repo <名称>

# 测试空白区
gitnexus cypher "
  MATCH (src:Module)
  WHERE NOT src.name CONTAINS 'test' AND NOT src.name CONTAINS 'spec'
  OPTIONAL MATCH (test:Module)-[:IMPORTS]->(src)
  WHERE test.name CONTAINS 'test' OR test.name CONTAINS 'spec'
  WITH src, count(test) AS test_count
  WHERE test_count = 0
  RETURN src.name LIMIT 20
" --repo <名称>
```

**产出**：量化指标表 + 测试评估 + 图谱健康度

### 阶段 6：精华提炼（~15%）

1. **可复用模式**：3-5 个可借鉴的模式，附源码位置（文件:行号）+ 适用场景
2. **实现技巧**：眼前一亮的代码片段 + 巧妙语言特性运用
3. **陷阱警告**：什么场景下会出问题？什么设计看似优雅实则增复杂？
4. **改进清单**：P0 不改会出事 / P1 改了更好 / P2 锦上添花
5. **学习行动计划**：如果要应用这些学习，前 3 步是什么？

**GitNexus 辅助**：
```bash
gitnexus query "unique custom novel approach" --repo <名称>

# 技术债务热点（行数 > 500 + fan_in > 5）
gitnexus cypher "
  MATCH (m:Module) WHERE m.lines > 500
  OPTIONAL MATCH (m)<-[:IMPORTS]-(other)
  WITH m, count(other) AS fan_in WHERE fan_in > 5
  RETURN m.name, m.lines, fan_in ORDER BY m.lines DESC
" --repo <名称>
```

**产出**：模式卡片 + 陷阱清单 + 改进建议 + 债务热点

---

## 分析报告模板

分析完成后，按以下模板生成标准化报告。

```markdown
# 项目分析报告：<项目名>　|　分析日期：YYYY-MM-DD

## 项目概览
| 字段 | 值 |
|------|-----|
| 项目名称、GitHub URL、主要语言、代码行数、Stars |
| 分析聚焦点、分析时间、图谱统计（节点/边/集群/流程） |

## 阶段 1：项目定位
> 一句话核心价值
> 架构风格识别 + 理由
> 图谱概览：边/节点比=（X）解读

## 阶段 2：结构扫描
### 模块职责清单（表）
### ASCII 模块依赖图
### 架构关键节点（表）
### 发现：循环依赖？上帝模块？死代码？

## 阶段 3：流程追踪
### 流程 1-3（时序图 + 设计解读）

## 阶段 4：模式识别
### 设计模式清单（表）
### 反模式清单（表）
### 横向对比（表）
### 独特解法

## 阶段 5：质量量化
### 自动化指标（表）
### 品味指标（表）
### 测试质量（表）
### 图谱健康度（表）

## 阶段 6：精华提炼
### 可复用模式 1-5（名称 + 来源 + 描述 + 适用场景 + 代码速览）
### 眼前一亮的实现
### 陷阱警告
### 改进建议（P0/P1/P2）
### 技术债务热点
### 学习行动计划（3 步）

## 总体评分

| 维度 | 评分(1-4) | 简评 |
|------|-----------|------|
| 架构设计 | | |
| 代码质量 | | |
| API/接口设计 | | |
| 数据建模 | | |
| 并发与异步 | | |
| 可测试性 | | |
| 演进与运维 | | |
| **加权平均** | | |
```

---

## 阶段 7：报告输出（强制）

> ⚠️ 分析完成后**必须**将完整报告保存为文件。不可仅在对话中展示后丢弃。

### 7.1 输出规则

| 规则 | 说明 |
|------|------|
| **输出时机** | 6 阶段全部完成后，在对话中展示报告摘要，同时保存完整报告到文件 |
| **文件格式** | Markdown (`.md`) |
| **文件位置** | `<目标项目根目录>/docs/analysis/` |
| **目录创建** | 如 `docs/analysis/` 不存在，自动创建 |
| **文件命名** | `YYYY-MM-DD-<项目名>-analysis.md`（如 `2026-05-03-omnimem-analysis.md`） |
| **编码** | UTF-8 |
| **内容** | 完整分析报告（按上方模板），包含全部 6 阶段产出 + 总体评分 |

### 7.2 输出流程

```
分析完成 (阶段6结束)
  → 检查 docs/analysis/ 目录是否存在，不存在则创建
  → 按命名规则生成文件路径:
    <项目根目录>/docs/analysis/YYYY-MM-DD-<项目名>-analysis.md
  → 将完整报告写入文件
  → 向用户展示:
    ✅ 报告已保存: docs/analysis/2026-05-03-omnimem-analysis.md
    （文件大小: X KB）
  → 在对话中展示核心结论和总体评分（概要，非完整报告）
```

### 7.3 对话展示 vs 文件内容

| 内容 | 对话中展示 | 文件中保存 |
|------|-----------|-----------|
| 项目概览 | ✅ | ✅ |
| 总体评分 + 各维度简评 | ✅ | ✅ |
| 精华提炼（可复用模式 + 学习计划） | ✅ | ✅ |
| 完整模块职责清单 | ❌ | ✅ |
| 完整 ASCII 依赖图 | ❌ | ✅ |
| 全部流程时序图 + 设计解读 | ❌ | ✅ |
| 完整模式/反模式清单 + 横向对比 | ❌ | ✅ |
| 全部量化指标 + 图谱数据 | ❌ | ✅ |
| 技术债务热点详情 | ❌ | ✅ |

> **原则**：对话中展示「可行动的学习成果」，文件中保存「完整的技术档案」。

### 7.4 已分析项目索引

分析完成后，在 `docs/analysis/` 目录下维护一个 `INDEX.md`：

```markdown
# 项目分析索引

| 日期 | 项目 | 评分 | 聚焦点 | 报告 |
|------|------|------|--------|------|
| 2026-05-03 | omnimem | 3.3 | 宏观架构 | [报告](./2026-05-03-omnimem-analysis.md) |
```

> 追加新记录到索引文件顶部（不覆盖已有记录）。

---

## 7 大维度评分速查

每个维度使用 1（差）→ 4（优秀）评分：

### 架构设计
- 4: 严格分层，依赖方向精确，插件体系完善，OCP 良好
- 3: 分层清晰偶有泄露，依赖大部分正确，有预留扩展点
- 2: 有分层但不一致，偶有违规，勉强可扩展
- 1: 无分层一盘散沙，循环依赖，不可扩展

### 代码质量
- 4: 函数短小纯函数 > 60%，领域驱动命名，细粒度错误
- 3: 大部分 < 60 行，抽象干净，基本可读，有错误上下文
- 2: 基本可读但偶有泄漏，命名一般，错误处理不一致
- 1: 大量 100+ 行函数，抽象泄漏，命名差，吞异常

### API/接口设计
- 4: Builder/选项模式优雅，错误可操作，有迁移指南
- 3: 参数合理，有错误类型，有 CHANGELOG
- 2: 基本有序，错误有分类，有版本号
- 1: 参数混乱，单一异常，无版本策略

### 数据建模
- 4: Entity/VO 区分 + 聚合精确 + 类型状态 + 多层缓存
- 3: Entity/VO 清晰，显式状态机，缓存策略明确
- 2: 有 Entity 概念，用了 enum 状态，有基本缓存
- 1: 全 Data Object 无领域概念，string 状态，无缓存

### 并发与异步
- 4: 模型精准 + lock-free + 全链路背压 + 完善资源管理
- 3: 锁粒度合适 + 有界 buffer + 连接池 + 优雅关闭
- 2: 基本安全偶有警告，有锁但粒度偏大，有基本资源管理
- 1: 共享可变无保护，无界 buffer，资源泄露

### 可测试性
- 4: 完美 DI + 小接口 + 行为测试 + 金字塔形 + 1 行 Mock
- 3: 构造注入为主，混合测试风格，基本覆盖
- 2: 部分 DI，有测试但形状不对，Mock 需要 10 行
- 1: 硬编码依赖无法测试，无测试或全是 E2E

### 演进与运维
- 4: 全链路 Tracing + 自动化发布 + 可回滚 migration + flag 清理 + SECURITY.md
- 3: 结构化日志 + SemVer + 可回滚 migration + 输入校验
- 2: 基本 logging + 有 CHANGELOG + 有 migration + 基本安全
- 1: print 调试，随意版本号，无 migration，无安全措施

---

## 语言专项提醒

**Python 项目**：
- `grep -rn "time.sleep\|requests\." --include="*.py"` — 在 async 中调用同步阻塞 = 问题
- 检查 `__all__` 是否定义、`__init__.py` 是否 re-export 公共 API
- 数据类：dataclass vs pydantic vs NamedTuple — 选择是否合理？
- Django：app 拆分粒度、select_related/prefetch_related
- FastAPI：Depends() 注入链深度、Pydantic Schema 复用

**TypeScript 项目**：
- `grep -rn ": any"` — any 占比 > 5% = 类型系统形同虚设
- API 边界是否用 Zod/io-ts/yup 做运行时校验？
- React：useEffect 滥用（应用 useMemo）、组件拆分粒度
- barrel export 是否导致循环依赖/tree shaking 失效？

**Go 项目**：
- 接口是否 1-3 个方法？接口定义在调用方还是实现方？
- `grep -rn "return err"` — 是否用 `%w` 包装保留调用链？
- goroutine 是否有明确退出条件？channel 由发送方关闭？
- 避免 `util/common/helper` 万能包

**Rust 项目**：
- `grep -rn "\.clone()"` — 不必要 clone 的数量
- `grep -rn "\.unwrap()\|\.expect("` — 生产代码中是否过多？
- unsafe 块是否有 SAFETY 注释？FFI 外的 unsafe 需特别关注
- trait 是否只有 0-1 个实现？→ 过度抽象
- 库用 thiserror，应用用 anyhow — 选择是否正确？

---

## 参考规则文档

GitHub 仓库包含完整规则文档（Clone 后查看）：
- `rules/01-architecture.md` ~ `rules/07-evolution-ops.md` — 7 大维度详细规则
- `workflow/analysis-checklist.md` — 可打印的完整检查清单
- `workflow/report-template.md` — 标准化报告模板
- `gitnexus/cypher-queries.md` — 15+ 分析专用 Cypher 查询库
- `language-guides/` — Python / TypeScript / Go / Rust 专项指南
- `workflow/examples/` — FastAPI / Express 分析示例

> 仓库地址：https://github.com/weksbwrx62862/project-analysis-rules
