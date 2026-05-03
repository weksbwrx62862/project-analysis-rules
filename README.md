# Project Analysis Rules

<p align="center"><strong>开源项目分析规则体系</strong> — 让每一次代码阅读都有章可循</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/languages-Python%20%7C%20TS%20%7C%20Go%20%7C%20Rust-orange" alt="Languages">
</p>

---

## 简介

**Project Analysis Rules** 是一套**稳定、可复用、工程化**的开源项目分析规则体系。它提供：

- **7 大分析维度**的详细检查清单和评分标准
- **6 阶段结构化分析流程**，从视角定位到精华提炼
- **GitNexus 知识图谱**的深度集成，用数据替代感觉
- **4 语言专项指南**（Python / TypeScript / Go / Rust）
- **Agent Skill** 定义，让 AI Agent 自动遵循分析流程

无论你是**技术选型、学习优秀项目、还是代码审查**，这套规则都能帮助你系统化地理解和评估开源代码。

---

## 功能矩阵

| 能力 | 说明 | 产出 |
|------|------|------|
| **架构分析** | 模块边界、依赖方向、分层检测 | 依赖图 + 关键节点排行 |
| **代码质量** | 函数设计、SOLID、命名、错误处理 | 客观指标 + 具体反模式 |
| **API 设计** | 签名、Builder、版本兼容、配置 | API 质量评分 |
| **数据建模** | Entity/VO 区分、状态机、缓存策略 | 建模建议 |
| **并发分析** | 模型识别、锁评估、背压检测 | 并发质量报告 |
| **可测试性** | DI 程度、金字塔形状、Mock 成本 | 测试改进清单 |
| **演进运维** | 可观测性、版本策略、安全实践 | 运维成熟度评分 |
| **GitNexus 集成** | 图谱查询、反模式自动检测、依赖追踪 | 数据驱动的客观分析 |

---

## 架构图

```
                          ┌──────────────────────┐
                          │    Agent Skill        │
                          │  project-analyzer     │
                          └──────────┬───────────┘
                                     │ 调用
                    ┌────────────────┼────────────────┐
                    ▼                ▼                 ▼
            ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
            │    rules/     │ │  workflow/   │ │  gitnexus/   │
            │  7 大维度     │ │  6 阶段流程   │ │  图谱工具集    │
            └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
                   │                │                 │
                   └────────────────┼─────────────────┘
                                    ▼
                         ┌──────────────────┐
                         │  分析报告 (模板)   │
                         │  各维度 1-4 评分   │
                         └──────────────────┘
```

---

## 快速开始

### 前置条件

- 已安装 [GitNexus](https://www.npmjs.com/package/gitnexus)（`npm install -g gitnexus@1.6.4-rc.43`）
- 目标项目已克隆到本地

### 最小示例

```bash
# 1. 克隆本规则仓库（仅需一次）
git clone https://github.com/weksbwrx62862/project-analysis-rules.git

# 2. 索引目标项目
cd <目标项目>
gitnexus analyze -f

# 3. 按规则分析
# 打开 rules/ 、workflow/analysis-checklist.md，逐项检查
# 或让 AI Agent 加载 skills/project-analyzer.md 自动执行

# 4. 生成报告
# 按 workflow/report-template.md 模板输出分析报告
```

### 对于 AI Agent

将 `skills/project-analyzer.md` 作为 Skill 加载后，只需说：

```
分析 <项目名> 的架构设计
```

Agent 将自动按照 6 阶段流程执行，结合 GitNexus 查询，生成标准化报告。

---

## 核心功能详解

### 7 大分析维度

每个维度都包含：**重点关注点** + **可操作检查清单** + **评分标准(1-4)** + **GitNexus 查询**

| 编号 | 维度 | 文件 | 核心关注 |
|------|------|------|----------|
| 01 | 架构设计 | [rules/01-architecture.md](rules/01-architecture.md) | 分层、依赖方向、扩展点 |
| 02 | 代码质量 | [rules/02-code-quality.md](rules/02-code-quality.md) | 函数设计、SOLID、命名 |
| 03 | API/接口 | [rules/03-api-design.md](rules/03-api-design.md) | 签名设计、错误处理、版本 |
| 04 | 数据建模 | [rules/04-data-modeling.md](rules/04-data-modeling.md) | Entity/VO、状态机、缓存 |
| 05 | 并发异步 | [rules/05-concurrency.md](rules/05-concurrency.md) | 并发模型、锁、背压 |
| 06 | 可测试性 | [rules/06-testability.md](rules/06-testability.md) | DI、金字塔、Mock |
| 07 | 演进运维 | [rules/07-evolution-ops.md](rules/07-evolution-ops.md) | 可观测性、版本、安全 |

### 6 阶段分析流程

```
阶段1: 视角定位 (5%)   — 明确学什么，设定时间预算
阶段2: 结构扫描 (15%)  — 心智地图，GitNexus 依赖分析
阶段3: 流程追踪 (25%)  — 追踪核心流程，GitNexus 调用链
阶段4: 模式识别 (25%)  — 设计模式+反模式，GitNexus 自动检测
阶段5: 质量量化 (15%)  — 数据说话，GitNexus 健康度
阶段6: 精华提炼 (15%)  — 可落地学习成果，技术债务热点
```

### GitNexus 集成

分析流程与 GitNexus 知识图谱深度集成：

- **结构扫描**：自动检测循环依赖、上帝模块、死代码
- **流程追踪**：多跳函数调用链追踪、中间件识别
- **模式识别**：自动发现上帝对象（方法>20）、过度抽象（0-1实现）、散弹修改（fan_in>15）
- **质量量化**：图谱健康度指标、测试空白区检测
- **精华提炼**：技术债务热点定位（行数>500 + 高被依赖）

详见 [gitnexus/gitnexus-integration.md](gitnexus/gitnexus-integration.md) 和 [gitnexus/cypher-queries.md](gitnexus/cypher-queries.md)

---

## 技术栈

| 组件 | 技术 |
|------|------|
| 规则文档 | Markdown |
| 知识图谱 | [GitNexus](https://www.npmjs.com/package/gitnexus) v1.6.4+ |
| Agent Skill | 标准 Skill 格式 |
| 分析脚本 | Bash（quick-health-check, generate-report-data） |

---

## 项目结构

```
project-analysis-rules/
├── README.md
├── .gitignore
├── rules/                              # 7 大分析维度规则
│   ├── 01-architecture.md
│   ├── 02-code-quality.md
│   ├── 03-api-design.md
│   ├── 04-data-modeling.md
│   ├── 05-concurrency.md
│   ├── 06-testability.md
│   └── 07-evolution-ops.md
├── workflow/                           # 分析流程 & 报告
│   ├── analysis-checklist.md
│   ├── report-template.md
│   └── examples/
│       ├── fastapi-analysis.md
│       └── express-analysis.md
├── gitnexus/                           # GitNexus 工具集
│   ├── gitnexus-integration.md
│   ├── cypher-queries.md
│   └── analysis-scripts/
│       ├── quick-health-check.sh
│       └── generate-report-data.sh
├── language-guides/                    # 语言专项
│   ├── python.md
│   ├── typescript.md
│   ├── go.md
│   └── rust.md
└── skills/                             # Agent Skill
    └── project-analyzer.md
```

---

## 开发指南

### 更新分析规则

1. 编辑 `rules/` 下的对应文件
2. 如果新增检查项，同步更新 `workflow/analysis-checklist.md`
3. 如果新增 Cypher 查询，同步更新 `gitnexus/cypher-queries.md`

### 添加新语言

1. 在 `language-guides/` 下创建新的 `.md` 文件
2. 参考现有语言指南的结构
3. 更新 README 的语言列表

---

## 路线图

- [x] 7 大分析维度规则
- [x] 6 阶段分析流程
- [x] GitNexus 深度集成
- [x] 4 语言专项指南（Python / TS / Go / Rust）
- [x] Agent Skill 定义
- [x] 示例分析报告（FastAPI / Express）
- [ ] 更多语言专项（Java / C# / Zig / Elixir）
- [ ] 更多分析示例报告
- [ ] 自动化一键分析命令
- [ ] 项目横向对比雷达图
- [ ] HTML 可视化分析报告

---

## 常见问题

**Q: 这套规则适合分析什么规模的项目？**
A: 任何规模。但时间预算需要调整——1k 行的小库用快速模式（15min），50k+ 行的项目建议深度模式（90min+）。

**Q: GitNexus 是必须的吗？**
A: 不是强依赖，但强烈推荐。不装 GitNexus 则跳过图谱查询步骤，分析质量会下降（变得更依赖主观判断）。

**Q: 评分是绝对的吗？**
A: 不。评分是**相对**的——在同一类项目中比较。一个 1000 行的 CLI 工具不需要 DDD 架构。

---

## Contributing

欢迎提交 Issue 和 PR，改进分析规则、新增语言指南、贡献分析示例。

---

## License

MIT

---

## Security

本仓库不包含任何密钥或敏感信息。分析他人项目时，请遵守目标项目的许可证规定。

---

## 致谢

- [GitNexus](https://www.npmjs.com/package/gitnexus) — 让代码图谱分析成为可能
- 所有被分析的开源项目 — 它们是我们学习的源泉

---

<p align="center"><em>每一次分析都是一次深度学习</em></p>
