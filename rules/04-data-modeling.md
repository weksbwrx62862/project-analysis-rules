# 数据建模分析规则

> 数据模型是系统的骨架，骨架歪了，再好的肌肉也会出问题。

---

## 一、实体设计

### 1.1 Entity vs Value Object

| 特征 | Entity | Value Object |
|------|--------|--------------|
| 身份 | 有唯一 ID | 无 ID，由所有属性值定义身份 |
| 可变性 | 可随时间变化 | **不可变**（修改 = 创建新实例） |
| 相等性 | 通过 ID 判断 | 通过所有属性判断 |
| 生命周期 | 独立存在 | 依附于 Entity |
| 例子 | User, Order, Product | Email, Money, Address, Color |

**检测**：项目是否区分了这两者？还是所有对象都有 ID？

### 1.2 聚合（Aggregate）设计

聚合 = 一组需要作为整体操作的 Entity + Value Object。

```
聚合的核心规则：
1. 一个事务只修改一个聚合（强一致性边界）
2. 跨聚合的修改通过事件最终一致性
3. 聚合根是外部唯一能引用的入口
4. 聚合尽量小（宁可更多小聚合，不要一个大聚合）
```

**坏味道**：
- 一个聚合包含 10+ 个 Entity → 太大
- 一个事务跨多个聚合的修改 → 边界可能画错了
- 外部直接修改聚合内部的 Entity → 违反聚合规则

### 1.3 ID 生成策略

| 策略 | 优点 | 缺点 | 适用 |
|------|------|------|------|
| UUID v4 | 独立生成，不依赖数据库 | 无序，索引性能差 | 分布式系统 |
| UUID v7 | 时间有序 + 独立生成 | 相对较新 | 新项目首选 |
| ULID | 时间有序 + 可排序 | 较新，不是所有数据库都原生支持 | 现代应用 |
| 自增 ID | 简单，索引友好 | 单点瓶颈，泄露信息 | 单体应用 |
| 雪花算法 | 分布式 + 时间有序 | 需要机器 ID 管理 | 大规模分布式 |
| NanoID | 短、安全、可定制 | 不保证唯一（冲突概率极低） | 前端/短 ID 场景 |

---

## 二、状态机设计

### 2.1 是否需要显式状态机？

以下场景建议用显式状态机：
- 订单（pending → confirmed → shipped → delivered → cancelled）
- 审批流程（draft → submitted → approved / rejected）
- 任务调度（queued → running → success / failed → retrying）
- 用户账户（active → suspended → deleted）

### 2.2 状态机质量检查

```python
# 差：状态是任意 string，转换无校验
order.status = "confirmed"
order.save()

# 中：状态是 enum，但转换逻辑散落各处
class OrderStatus(Enum):
    PENDING = 1
    CONFIRMED = 2

if order.status == OrderStatus.PENDING:
    order.status = OrderStatus.CONFIRMED

# 好：状态转换集中管理 + 校验
class Order:
    def confirm(self):
        if self.status != OrderStatus.PENDING:
            raise InvalidTransition(f"Cannot confirm from {self.status}")
        self.status = OrderStatus.CONFIRMED
        self.add_event(OrderConfirmed(self.id))

# 更好：类型状态（Rust）
// 编译期保证状态转换正确
let order = PendingOrder::new(items);
let order = order.confirm(payment_id); // 返回 ConfirmedOrder
// order.ship() ← 编译错误！PendingOrder 没有 ship 方法
```

### 2.3 状态机检查清单

- [ ] 状态转换是否有显式校验？（不允许非法跳转）
- [ ] 状态变化是否触发事件通知？
- [ ] 是否有终态？（避免永远无法完成的状态）
- [ ] 流程中是否有死状态？（从未到达的状态）

---

## 三、不变性（Immutability）

### 3.1 不可变 vs 可变

```python
# 可变：原地修改
user.email = "new@email.com"

# 不可变：返回新对象
user = user.with_email("new@email.com")
```

### 3.2 语言偏好

| 语言 | 默认倾向 | 工具 |
|------|----------|------|
| Rust | 默认不可变，mut 显式声明 | borrow checker |
| Go | 倾向于不可变，但没有强制 | convention |
| Python | 倾向于可变 | `dataclass(frozen=True)`, `NamedTuple` |
| TypeScript | 混合 | `readonly`, `as const`, `Object.freeze()` |

### 3.3 不可变性的好处

1. 并发安全（无共享可变状态）
2. 时间旅行/撤销更容易
3. 推理简单（函数调用不会偷偷改变你的参数）
4. 缓存友好（相等的值可以安全共享引用）

---

## 四、ORM 使用分析

### 4.1 领域模型 vs 持久化模型

```
好的模式：
  User（领域模型） ↔ UserRepository ↔ UserEntity（ORM 模型） ↔ 数据库
  领域逻辑不依赖 ORM

常见的问题模式：
  User（ORM 模型 + 领域模型） ← 两个关注点耦合在一起
  class User extends Model { ... } ← ORM 绑架了领域模型
```

### 4.2 ORM 常见陷阱

| 陷阱 | 表现 | 检测方法 |
|------|------|----------|
| N+1 问题 | 循环中 lazy-load 关联对象 | 看是否用了 `select_related`/`prefetch`/`eager loading` |
| 贫血模型 | Model 只有 getter/setter，业务逻辑全在 Service | 看 Entity 类是否只是数据容器 |
| 过度抽象 | ORM DSL 写的复杂查询难以优化 | 是否保留了 raw SQL 作为逃生舱？ |
| 隐式行为 | ORM 的 cascade/save-update 导致意外操作 | 查看 ORM 配置的 cascade 规则 |

### 4.3 数据映射策略判断

| 策略 | 何时使用 | 检测 |
|------|----------|------|
| Active Record | 简单 CRUD，Model 和表 1:1 | `user.save()`, `User.find(1)` |
| Data Mapper / Repository | 复杂领域，Model 和表可能 N:M | `user_repo.save(user)`, `user_repo.get(id)` |
| Raw SQL | 复杂查询/报表/迁移 | 直接的 SQL 语句 |
| Query Builder | 动态查询，介于 ORM 和 Raw SQL | `query.select().from().where()` |

---

## 五、缓存策略

### 5.1 缓存层次

| 层次 | 粒度 | TTL 典型值 | 示例 |
|------|------|------------|------|
| 浏览器 | 整个响应 | 分钟~天 | HTTP Cache-Control, Service Worker |
| CDN | 静态资源/页面 | 分钟~小时 | CloudFlare, Fastly |
| 应用缓存 | 对象/查询结果 | 秒~分钟 | Redis, Memcached |
| 数据库查询缓存 | 查询结果 | 分钟 | MySQL Query Cache, PostgreSQL 物化视图 |
| 本地内存 | 热点数据 | 秒 | Caffeine, lru_cache |

### 5.2 缓存策略检测

- 哪些数据被缓存了？（看 @cached / cache.get / Redis 操作）
- 缓存 Key 如何设计？（是否需要版本号防止冲突？）
- 缓存失效：TTL 还是主动失效还是版本号？
- 是否有缓存穿透/击穿/雪崩防护？
  - 穿透：查询不存在的数据 → 布隆过滤器或缓存空值
  - 击穿：热点数据过期瞬间大量请求 → 互斥锁/永不过期
  - 雪崩：大量缓存同时过期 → 随机化 TTL

---

## 六、GitNexus 辅助命令

```bash
# 搜索实体定义
gitnexus query "entity model aggregate value object" --repo <名称>

# 搜索 ORM 模式
gitnexus query "repository mapper active record" --repo <名称>

# 搜索缓存相关代码
gitnexus query "cache redis memoize lru_cache" --repo <名称>

# 搜索状态转换
gitnexus query "state machine status transition lifecycle" --repo <名称>
```

---

## 七、评分标准

| 维度 | 1分（差） | 2分（可接受） | 3分（好） | 4分（优秀） |
|------|----------|-------------|---------|-----------|
| 实体设计 | 全部是 Data Object，无领域概念 | 有 Entity 概念 | Entity + VO 区分清晰 | 聚合边界精确 + ID 策略合理 |
| 状态管理 | 任意 string 状态，无校验 | 用了 enum | 显式状态机 + 转换校验 | 类型状态（编译期保证） |
| 不变性 | 全可变 | 偶有不可变 | 值对象不可变 | 全面不可变设计 |
| ORM 使用 | 领域模型被 ORM 绑架 | 基本分离但有泄漏 | 清晰的映射层 | 领域模型纯 POJO/PODO |
| 缓存 | 无缓存或全缓存 | 有缓存但策略模糊 | 策略明确的缓存 | 多层缓存 + 失效策略 + 三防 |
