# 架构设计分析规则

> 架构不是层的数量，而是依赖的方向。

---

## 一、核心判断框架

### 1.1 先回答三个问题

分析项目架构时，先不看代码，回答这三个问题：

| 问题 | 怎么判断 | 好 | 坏 |
|------|---------|----|----|
| 代码是怎么组织的？ | 看顶层目录 | `core/`, `api/`, `infra/` 职责清晰 | `utils/`, `common/`, `helpers/` 万能兜底 |
| 依赖往哪走？ | 看 import 方向 | 基础设施 → 领域（外→内） | 领域 import 了具体数据库驱动 |
| 改一个功能动多少文件？ | 脑内模拟小改动 | 只动 1-2 个文件/模块 | 需要改 5+ 个文件 |

### 1.2 架构风格识别

| 风格 | 特征 | 典型项目 |
|------|------|----------|
| **经典三层** | Controller → Service → Repository | Django REST, NestJS |
| **六边形架构** | Domain ↔ Ports ↔ Adapters | 大多数 DDD 项目 |
| **整洁架构** | Entities → UseCases → Adapters → Infra | Go 项目（无框架依赖）、Rust 项目 |
| **CQRS** | 读写分离的 Command/Query 模型 | 事件溯源项目、高并发场景 |
| **微内核/插件** | Core + Plugin API + 插件市场 | VS Code, Webpack, Obsidian |
| **事件驱动** | 消息/事件总线连接松耦合服务 | 消息队列项目、IoT 平台 |
| **管道/过滤器** | 数据流经一系列变换 | ETL 工具、编译器、图像处理 |

### 1.3 架构适配度判断

> 不是所有项目都需要 DDD/六边形架构。判断架构是否「恰到好处」：

- **小型 CLI 工具**（< 5k 行）：Layered 就够了，不需要 Ports/Adapters
- **中型 Web 应用**（5k-50k 行）：六边形/整洁架构开始显现价值
- **大型分布式系统**（> 50k 行）：CQRS/事件驱动可能是必要的
- **库/SDK**：关注的是公共 API 的稳定性，而非内部分层

**反例**：一个 3000 行的 TODO 应用用了 CQRS + Event Sourcing + DDD → 过度工程化。

---

## 二、模块边界分析

### 2.1 公共接口显式化

检查项目如何向外部暴露模块：

| 语言 | 检查方式 |
|------|----------|
| Python | `__all__` 是否定义？`__init__.py` 是空的还是 re-export 了公共 API？ |
| TypeScript | `index.ts` barrel export 的内容是否克制？是否有 `export *` 的懒人做法？ |
| Go | 包名是否反映单一职责？`internal/` 是否用于保护内部实现？ |
| Rust | `pub` 的使用是否克制？`pub(crate)` 的使用是否恰当？ |

```
好的模式：
  mylib/
    __init__.py     → from mylib.core import Engine, Config  # 只暴露公共 API
    core.py         → 内部实现

坏的模式：
  mylib/
    __init__.py     → 空文件，用户需要 from mylib.core.internals.v2.engine import Engine
```

### 2.2 高内聚检测

- 改一个功能时，相关代码集中在 1-2 个文件/模块 → 高内聚
- 改一个功能时，需要跨 5+ 个模块修改 → 低内聚（散弹式修改的前兆）

### 2.3 上帝模块检测

单文件行数预警阈值：
- **Python/TS/Rust**：> 500 行 → 需要审视；> 1000 行 → 几乎肯定需要拆分
- **Go**：> 300 行 → 需要考虑拆分（Go 的文件组织倾向于多文件小模块）
- **Java/C#**：> 300 行 → 单一职责可能被违反

---

## 三、依赖方向分析

### 3.1 依赖规则

```
正确方向（整洁架构）：
  外圈（框架/平台）→ 内圈（领域/业务逻辑）
  
  Frameworks → Adapters → Application → Domain
  （最外层）                                    （最内层）
```

### 3.2 具体检查项

| 检查项 | 怎么看 |
|--------|-------|
| 领域层是否依赖框架？ | 打开核心业务逻辑文件，搜索 `from django`, `from fastapi`, `from express` 等 |
| 是否存在循环依赖？ | Python：尝试 import 会报错；TS：看 barrel export；Go：编译器自动拒绝 |
| 第三方库渗透深度？ | 如果 ORM 类型出现在 Service 层，可能耦合过深 |

### 3.3 模块间耦合度量

| 指标 | 含义 | 好 | 中 | 坏 |
|------|------|----|----|----|
| Fan-in | 被多少模块依赖 | 越多越核心，但要警惕变化成本 | 3-10 | 11-20 | > 20 |
| Fan-out | 依赖多少模块 | 越少越独立 | 1-5 | 6-10 | > 10 |
| Instability | Fan-out / (Fan-in + Fan-out) | 0（稳定）~ 1（不稳定） | < 0.3 | 0.3-0.7 | > 0.7 |

---

## 四、扩展点设计

### 4.1 插件/扩展系统模式

| 模式 | 描述 | 示例 |
|------|------|------|
| **注册-发现** | 插件注册自己到注册表，核心通过注册表发现 | Webpack plugins, pytest plugins |
| **中间件链** | 请求/响应经过一条可配置的处理链 | Express/Koa middleware, Django middleware |
| **策略注入** | 通过接口/策略替换核心算法 | 自定义 Storage 后端、自定义加密算法 |
| **Hook/事件** | 在关键节点触发回调 | Git hooks, React lifecycle |
| **扩展点/SPI** | 预留接口等待实现 | JDK ServiceLoader, Python entry_points |

### 4.2 评价标准

- **开闭原则（OCP）**：添加新功能是否需要修改核心代码？
  - 如果只是新增一个文件/模块 → 好
  - 如果需要在核心代码中加 if/else → 差
- **插件接口稳定性**：插件 API 是否会频繁 breaking change？
- **发现机制**：用户写的插件如何被框架发现？

---

## 五、GitNexus 辅助命令

```bash
# 循环依赖检测（Python 必做）
gitnexus cypher "
  MATCH (a:Module)-[:IMPORTS]->(b:Module)
  MATCH (b)-[:IMPORTS*1..5]->(a)
  RETURN a.name, b.name
" --repo <名称>

# 被依赖 Top 10（架构关键节点）
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

# 高影响模块
gitnexus impact <核心类名> --repo <名称>
```

---

## 六、评分标准

| 维度 | 1分（差） | 2分（可接受） | 3分（好） | 4分（优秀） |
|------|----------|-------------|---------|-----------|
| 分层清晰度 | 无分层，一盘散沙 | 有分层但不一致 | 分层清晰，偶尔泄露 | 严格分层，依赖方向精确 |
| 模块内聚 | 功能散落各处 | 大部分功能集中 | 功能高度集中 | 模块边界即业务边界 |
| 依赖管理 | 循环依赖 | 偶有违规 | 依赖方向正确 | 依赖图是 DAG，稳定/不稳定分离 |
| 扩展性 | 不可扩展 | 强行 hack 可扩展 | 有预留扩展点 | 插件体系完善，OCP 良好 |
| 架构-规模匹配 | 明显过重/过轻 | 大致合适 | 恰到好处 | 精准匹配，无浪费 |
