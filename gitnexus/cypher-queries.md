# 分析专用 Cypher 查询库

> 以下所有查询需要在已索引的仓库上执行：`gitnexus cypher "<查询>" --repo <仓库名>`

---

## 一、架构检测

### 循环依赖检测

```cypher
MATCH (a:Module)-[:IMPORTS]->(b:Module)
MATCH (b)-[:IMPORTS*1..5]->(a)
RETURN DISTINCT a.name AS module_a, b.name AS module_b
```

**用途**：发现模块间的循环依赖关系。任何返回结果都是架构异味信号。

### 层级违规检测

```cypher
MATCH (domain:Module)-[:IMPORTS]->(infra:Module)
WHERE domain.name CONTAINS 'domain' OR domain.name CONTAINS 'core'
  AND (infra.name CONTAINS 'infra' OR infra.name CONTAINS 'adapter'
    OR infra.name CONTAINS 'database' OR infra.name CONTAINS 'http')
RETURN domain.name, infra.name
```

**用途**：检查领域层是否依赖了基础设施层（整洁架构/六边形架构违规）。

### 被依赖排行

```cypher
MATCH (m:Module)<-[:IMPORTS]-(other)
WHERE NOT m.name CONTAINS 'test' AND NOT m.name CONTAINS 'spec'
RETURN m.name AS module, count(other) AS fan_in
ORDER BY fan_in DESC
LIMIT 10
```

**用途**：找出架构的关键节点。fan_in > 20 的模块修改风险极高。

### 无被依赖模块（死代码候选）

```cypher
MATCH (m:Module)
WHERE NOT (m)<-[:IMPORTS]-()
  AND NOT m.name CONTAINS 'main'
  AND NOT m.name CONTAINS 'app'
  AND NOT m.name CONTAINS 'index'
RETURN m.name AS module
ORDER BY module
```

**用途**：发现可能无人使用的模块。需要人工确认后再决定是否删除。

### 模块聚类

```cypher
MATCH (a:Module)-[:IMPORTS]->(b:Module)
RETURN a.name AS source, b.name AS target
LIMIT 50
```

**用途**：手动分析模块间的关系网络，识别自然的模块群组。

---

## 二、反模式检测

### 上帝对象检测

```cypher
MATCH (c:Class)
OPTIONAL MATCH (c)-[:HAS_METHOD]->(m:Method)
WITH c, count(m) AS method_count
WHERE method_count > 20
RETURN c.name AS class, method_count
ORDER BY method_count DESC
```

**用途**：方法数 > 20 的类很可能违反了单一职责原则。阈值可调整为 15（更严格）或 30（更宽松）。

### 散弹修改风险

```cypher
MATCH (m:Module)<-[:IMPORTS]-(other)
WHERE NOT m.name CONTAINS 'test' AND NOT m.name CONTAINS 'spec'
WITH m, count(other) AS fan_in
WHERE fan_in > 15
RETURN m.name AS module, fan_in
ORDER BY fan_in DESC
```

**用途**：fan_in > 15 的模块被大量其他模块依赖，修改时需要关注散弹式影响。

### 过度抽象检测

```cypher
MATCH (i:Interface)
OPTIONAL MATCH (c:Class)-[:IMPLEMENTS]->(i)
WITH i, count(c) AS impl_count
WHERE impl_count <= 1
RETURN i.name AS interface, impl_count
ORDER BY impl_count
```

**用途**：只有 0-1 个实现的接口大概率是过度抽象。例外：测试 mock 也算 1 个实现。

### 高耦合模块

```cypher
MATCH (m:Module)-[:IMPORTS]->(other)
WITH m, count(other) AS fan_out
WHERE fan_out > 15
RETURN m.name AS module, fan_out
ORDER BY fan_out DESC
```

**用途**：依赖超过 15 个其他模块的模块可能存在耦合过重的问题。

---

## 三、质量量化

### 大文件排行

```cypher
MATCH (m:Module)
RETURN m.name AS module, m.lines AS lines
ORDER BY lines DESC
LIMIT 10
```

**用途**：找出最大的文件。Python/TS 超过 500 行的文件需要关注，超过 1000 行几乎肯定需要拆分。

### 依赖深度

```cypher
MATCH path = (a:Module)-[:IMPORTS*1..10]->(b:Module)
WITH a, max(length(path)) AS max_depth
RETURN a.name AS module, max_depth
ORDER BY max_depth DESC
LIMIT 10
```

**用途**：依赖深度 > 5 的模块位于调用链深处，修改的连锁反应风险高。

### 测试空白区

```cypher
MATCH (src:Module)
WHERE NOT src.name CONTAINS 'test' AND NOT src.name CONTAINS 'spec'
OPTIONAL MATCH (test:Module)-[:IMPORTS]->(src)
WHERE test.name CONTAINS 'test' OR test.name CONTAINS 'spec'
WITH src, count(test) AS test_count
WHERE test_count = 0
RETURN src.name AS module
LIMIT 20
```

**用途**：没有被任何测试文件 import 的模块，是测试盲区。

### 边/节点比计算

从 `gitnexus list` 输出中计算：
```
边/节点比 = 边数 / 节点数
```
- < 1.5：模块较独立，耦合低
- 1.5-2.0：正常范围
- > 2.0：模块间耦合较多
- > 3.0：高耦合，关注架构健康

---

## 四、流程追踪

### 多跳调用链

```cypher
MATCH path = (start:Function {name: 'handle_request'})-[:CALLS*1..5]->(end:Function)
RETURN path
LIMIT 10
```

**用途**：追踪函数调用链最多 5 跳，看清请求的完整传播路径。需要替换 `handle_request` 为实际的入口函数名。

### 中间件/拦截器识别

```cypher
MATCH (a:Function)-[:CALLS]->(m:Function)-[:CALLS]->(b:Function)
WHERE m.name CONTAINS 'middleware'
   OR m.name CONTAINS 'interceptor'
   OR m.name CONTAINS 'filter'
RETURN a.name AS caller, m.name AS middleware, b.name AS callee
```

**用途**：识别调用链中的中间件/拦截器节点，理解请求是如何被层层处理的。

### 特定概念追踪

```cypher
MATCH (f:Function)
WHERE f.name CONTAINS 'validate' OR f.name CONTAINS 'check' OR f.name CONTAINS 'verify'
RETURN f.name AS function
LIMIT 30
```

**用途**：找出所有与某个概念相关的函数（校验、认证、缓存等），替换 CONTAINS 后的关键词即可。

---

## 五、精华提炼

### 技术债务热点

```cypher
MATCH (m:Module)
WHERE m.lines > 500
OPTIONAL MATCH (m)<-[:IMPORTS]-(other)
WITH m, count(other) AS fan_in
WHERE fan_in > 5
RETURN m.name AS module, m.lines AS lines, fan_in
ORDER BY m.lines DESC
```

**用途**：行数 > 500 且被 5+ 模块依赖的模块是技术债务重灾区。同时满足「大型」和「高依赖」= 重构优先级最高。

### 孤立模块（无调用者）

```cypher
MATCH (f:Function)
WHERE NOT (f)<-[:CALLS]-()
  AND NOT f.name CONTAINS 'main'
  AND NOT f.name CONTAINS 'init'
  AND NOT f.name CONTAINS '__'
RETURN f.name AS function
LIMIT 20
```

**用途**：没有被调用的函数可能是死代码，但需要人工确认（可能是回调/入口函数）。

---

## 六、查询模板速查

| 场景 | 页码 |
|------|------|
| 循环依赖检测 | [架构检测](#循环依赖检测) |
| 层级违规检测 | [架构检测](#层级违规检测) |
| 被依赖排行 | [架构检测](#被依赖排行) |
| 死代码候选 | [架构检测](#无被依赖模块死代码候选) |
| 上帝对象 | [反模式检测](#上帝对象检测) |
| 散弹修改 | [反模式检测](#散弹修改风险) |
| 过度抽象 | [反模式检测](#过度抽象检测) |
| 高耦合模块 | [反模式检测](#高耦合模块) |
| 大文件排行 | [质量量化](#大文件排行) |
| 依赖深度 | [质量量化](#依赖深度) |
| 测试空白区 | [质量量化](#测试空白区) |
| 多跳调用链 | [流程追踪](#多跳调用链) |
| 中间件识别 | [流程追踪](#中间件拦截器识别) |
| 技术债务热点 | [精华提炼](#技术债务热点) |
| 孤立函数 | [精华提炼](#孤立模块无调用者) |
