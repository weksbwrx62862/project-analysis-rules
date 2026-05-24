<div align="center">

# Project Analysis Rules

**开源项目分析规则体系** — 让每一次代码阅读都有章可循

</div>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/languages-Python%20%7C%20TS%20%7C%20Go%20%7C%20Rust-orange" alt="Languages">
  <img src="https://img.shields.io/github/stars/weksbwrx62862/project-analysis-rules?style=social" alt="Stars">
  <img src="https://img.shields.io/github/last-commit/weksbwrx62862/project-analysis-rules" alt="Last Commit">
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
cd project-analysis-rules

# 2. 安装 GitNexus（如尚未安装）
npm install -g gitnexus@1.6.4-rc.43

# 3. 索引目标项目
cd /path/to/target-project
gitnexus analyze -f
# 确认输出包含 "Repository indexed successfully"

# 4. 执行快速健康检查（可选，生成概览数据）
bash /path/to/project-analysis-rules/gitnexus/analysis-scripts/quick-health-check.sh

# 5. 按规则逐项分析
# 打开 rules/01-architecture.md ~ 07-evolution-ops.md，逐维度检查
# 或使用 workflow/analysis-checklist.md 作为检查清单

# 6. 生成分析报告
# 按 workflow/report-template.md 模板输出分析报告
# 或运行脚本自动生成数据：
bash /path/to/project-analysis-rules/gitnexus/analysis-scripts/generate-report-data.sh
```

### 分析模式选择

| 模式 | 适用场景 | 时间预算 | 建议维度 |
|------|----------|----------|----------|
| **快速** | 1k 行以下小库 / 初步筛选 | 15-30 min | 01 架构 + 02 代码质量 |
| **标准** | 1k-50k 行中型项目 | 60-90 min | 01-04 全部核心维度 |
| **深度** | 50k+ 行大型项目 / 技术选型 | 2-4 h | 01-07 全维度 + 语言专项 |

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

### 代码风格

- Markdown 文件使用中文撰写，技术术语保留英文
- 文件命名：小写 + 连字符（kebab-case），如 `01-architecture.md`
- 规则文件结构统一：**重点关注点** → **检查清单** → **评分标准** → **GitNexus 查询**

### 测试与验证

本仓库为规则文档仓库，无单元测试。验证方式：

1. **规则完整性**：确保每个维度文件包含完整的 4 个章节（重点关注点 / 检查清单 / 评分标准 / GitNexus 查询）
2. **示例验证**：用已有示例项目（FastAPI / Express）重新走一遍分析流程，确认规则可执行
3. **GitNexus 查询验证**：在已索引项目上运行 `gitnexus/analysis-scripts/quick-health-check.sh`，确认脚本无报错

### CI

- 当前未配置 CI 流水线
- 建议后续添加 Markdown lint（如 `markdownlint`）和链接检查（如 `lychee`）

---

## 路线图

### v1.0 — 基础规则体系 ✅

- [x] 7 大分析维度规则
- [x] 6 阶段分析流程
- [x] GitNexus 深度集成
- [x] 4 语言专项指南（Python / TS / Go / Rust）
- [x] Agent Skill 定义
- [x] 示例分析报告（FastAPI / Express）

### v1.1 — 扩展覆盖（进行中）

- [ ] 更多语言专项（Java / C# / Zig / Elixir）
- [ ] 更多分析示例报告（Django / Next.js / Gin / Actix）
- [ ] 自动化一键分析命令（CLI 工具）

### v1.2 — 可视化与对比

- [ ] 项目横向对比雷达图
- [ ] HTML 可视化分析报告
- [ ] 分析结果导出为 PDF / JSON

### v2.0 — 智能化

- [ ] LLM 辅助自动评分（基于规则 + RAG）
- [ ] 增量分析（仅分析变更部分）
- [ ] 与 CI/CD 集成（PR 自动评审）

---

## 常见问题

**Q: 这套规则适合分析什么规模的项目？**
A: 任何规模。但时间预算需要调整——1k 行的小库用快速模式（15min），50k+ 行的项目建议深度模式（90min+）。

**Q: GitNexus 是必须的吗？**
A: 不是强依赖，但强烈推荐。不装 GitNexus 则跳过图谱查询步骤，分析质量会下降（变得更依赖主观判断）。

**Q: 评分是绝对的吗？**
A: 不。评分是**相对**的——在同一类项目中比较。一个 1000 行的 CLI 工具不需要 DDD 架构。

**Q: 如何为非 Python/TS/Go/Rust 的项目做分析？**
A: 7 大维度规则是语言无关的，适用于任何语言。语言专项指南仅提供特定语言的常见陷阱和最佳实践。对于 Java、C# 等语言，可暂时跳过语言专项，仅使用通用规则。

**Q: 分析报告可以用于商业项目评估吗？**
A: 可以。本规则体系基于 MIT 许可证发布，分析产出归分析者所有。但请注意，分析他人项目时需遵守目标项目的许可证规定，尤其是涉及源码引用时。

**Q: 如何与团队协作使用这套规则？**
A: 建议做法：1) 团队统一克隆本仓库到共享位置；2) 分析前先对齐评分标准（可在示例报告上校准）；3) 每人负责不同维度，最后汇总讨论；4) 将分析报告存入团队知识库。

---

## Contributing

欢迎提交 Issue 和 PR，改进分析规则、新增语言指南、贡献分析示例。

### 工作流

1. **Fork** 本仓库到你的 GitHub 账户
2. **创建分支**：`git checkout -b feat/your-feature`
3. **提交变更**：遵循 Conventional Commits 规范（如 `feat(rules): add security audit checklist`）
4. **推送分支**：`git push origin feat/your-feature`
5. **创建 PR**：描述变更内容、动机和影响范围

### 贡献类型

| 类型 | 说明 | 示例 |
|------|------|------|
| **规则改进** | 优化现有维度的检查项或评分标准 | 补充架构维度的微服务检查项 |
| **新增语言** | 添加语言专项指南 | Java 语言指南 |
| **示例报告** | 贡献真实项目的分析报告 | Django 项目分析报告 |
| **工具脚本** | 改进 GitNexus 分析脚本 | 新增依赖热度排序脚本 |
| **文档修复** | 修正错别字、链接失效等 | 修复 README 中的链接 |

### PR 检查清单

- [ ] 变更与现有规则体系风格一致
- [ ] 如新增规则，已同步更新 `workflow/analysis-checklist.md`
- [ ] 如新增 Cypher 查询，已同步更新 `gitnexus/cypher-queries.md`
- [ ] Markdown 格式正确，无链接失效

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
