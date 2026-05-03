# GitNexus 集成指南

> GitNexus 是代码知识图谱引擎，将「人肉翻代码」升级为「精准图谱查询」。

---

## 一、能力矩阵

| 工具 | 功能 | 返回内容 | 核心分析场景 |
|------|------|----------|-------------|
| `gitnexus analyze` | 索引仓库 | 图谱节点/边的统计 | ⚠️ 分析任何项目前必须先执行 |
| `gitnexus list` | 列出已索引仓库 | 仓库名 + 节点/边/集群/流程数 | 确认索引状态，获取健康度指标 |
| `gitnexus query` | 语义搜索 + BM25 混合检索 | 相关代码片段（函数/类/模块） | 按概念搜索功能实现、设计模式 |
| `gitnexus context` | 符号 360° 上下文 | 调用者列表、被调用者列表、方法列表 | 理解接口影响范围、追踪依赖 |
| `gitnexus impact` | 影响范围分析 | 修改一个符号会波及的文件列表 | 评估模块耦合度、识别关键节点 |
| `gitnexus cypher` | 原生 Cypher 图谱查询 | 自定义图查询结果 | 深度依赖分析、反模式扫描、模式挖掘 |

---

## 二、语言兼容性

| 语言 | query | context | impact | cypher | 说明 |
|------|-------|---------|--------|--------|------|
| TypeScript | ✅ 好 | ✅ 好 | ✅ 好 | ✅ 好 | Tree-sitter 对 TS 支持最完善，所有功能最佳 |
| Python | ✅ 好 | ✅ 好 | ⚠️ 有限 | ✅ 好 | 跨文件 IMPORTS 边检测有限，需用 cypher 补充 |
| Go | ✅ 好 | ✅ 好 | ✅ 好 | ✅ 好 | 所有功能正常 |
| Rust | ✅ 可 | ✅ 可 | ✅ 可 | ✅ 可 | 宏展开后的代码可能有偏差 |

> ⚠️ **核心原则**：Python 项目的跨文件依赖追踪**不可**单独依赖 `impact`，必须用 `cypher` 手动补充。

---

## 三、分析前置操作

每次开始分析一个新项目时，必须执行：

```bash
cd <目标项目目录>

# 1. 强制重新索引（确保是最新状态）
gitnexus analyze -f

# 2. 确认索引成功
gitnexus list
```

**确认内容**：
- 输出包含 `Repository indexed successfully`
- 记录：节点数、边数、集群数、流程数
- 计算边/节点比：> 2.0 = 耦合较多；< 1.5 = 模块较独立

---

## 四、各分析阶段的 GitNexus 使用指南

### 阶段 2：结构扫描

| 目的 | 命令 | 关注点 |
|------|------|--------|
| 找到核心入口 | `gitnexus query "main entry point server startup"` | 定位启动入口 |
| 评估模块影响 | `gitnexus impact <核心类名>` | 波及文件 > 20 → 关键节点 |
| 检测循环依赖 | `cypher` — 见 [cypher-queries.md](cypher-queries.md#循环依赖检测) | 有结果 → 架构异味 |
| 识别关键节点 | `cypher` — 见 [被依赖排行](cypher-queries.md#被依赖排行) | Top 10 = 架构骨架 |
| 发现死代码 | `cypher` — 见 [无被依赖模块](cypher-queries.md#无被依赖模块) | 可能可安全删除 |

### 阶段 3：流程追踪

| 目的 | 命令 | 关注点 |
|------|------|--------|
| 搜索流程概念 | `gitnexus query "request routing middleware chain"` | 找到流程入口 |
| 查看调用链 | `gitnexus context <入口函数名>` | callers + callees |
| 追踪多跳调用 | `cypher` — 见 [多跳调用链](cypher-queries.md#多跳调用链) | 完整请求传播路径 |
| 识别中间件 | `cypher` — 见 [中间件/拦截器](cypher-queries.md#中间件拦截器) | 拦截点位置 |

### 阶段 4：模式识别

| 目的 | 命令 | 关注点 |
|------|------|--------|
| 搜索设计模式 | `gitnexus query "strategy pattern adapter observer"` | 模式实例定位 |
| 检测上帝对象 | `cypher` — 见 [上帝对象检测](cypher-queries.md#上帝对象检测) | 方法数 > 20 |
| 检测散弹修改 | `cypher` — 见 [散弹修改风险](cypher-queries.md#散弹修改风险) | fan_in > 15 |
| 检测过度抽象 | `cypher` — 见 [过度抽象检测](cypher-queries.md#过度抽象检测) | 0-1 个实现 |

### 阶段 5：质量量化

| 目的 | 命令 | 关注点 |
|------|------|--------|
| 图谱健康度 | `gitnexus list` | 边/节点比 |
| 大文件排行 | `cypher` — 见 [大文件排行](cypher-queries.md#大文件排行) | > 1000 行 |
| 依赖深度 | `cypher` — 见 [依赖深度](cypher-queries.md#依赖深度) | > 5 跳 |
| 测试空白区 | `cypher` — 见 [测试空白区](cypher-queries.md#测试空白区) | 无测试覆盖 |

### 阶段 6：精华提炼

| 目的 | 命令 | 关注点 |
|------|------|--------|
| 独特设计 | `gitnexus query "unique custom approach"` | 区别于同类 |
| 技术债务热点 | `cypher` — 见 [技术债务热点](cypher-queries.md#技术债务热点) | 行数 > 500 且 fan_in > 5 |

---

## 五、MCP 服务器配置

在 Trae IDE 中配置 GitNexus MCP：

```json
{
  "mcpServers": {
    "gitnexus": {
      "command": "npx",
      "args": ["-y", "gitnexus@1.6.4-rc.43", "mcp"]
    }
  }
}
```

> ⚠️ 注意：当前需使用 `1.6.4-rc.43` 版本，稳定版 v1.6.3 在 Windows 上存在问题。

---

## 六、故障排除

| 问题 | 可能原因 | 解决 |
|------|----------|------|
| `impact` 返回结果很少 | Python 项目跨文件边检测有限 | 使用 `cypher` 手动补充 |
| `query` 找不到预期结果 | 索引过时 | 执行 `gitnexus analyze -f` |
| `cypher` 报语法错误 | 图谱节点/边标签不匹配 | 先用 `gitnexus list` 确认图结构 |
| MCP 连接失败 | 版本不对或 npx 缓存问题 | 确认版本为 1.6.4-rc.43 |
