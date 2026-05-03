# API / 接口设计分析规则

> API 的终极目标：让用户在 30 秒内写出一个可运行的正确示例。

---

## 一、函数签名设计

### 1.1 最小化必选参数

```python
# 差：必选参数过多
def create_user(name, email, password, role, department, manager, notify, locale):

# 好：只保留本质必选参数
def create_user(name, email, *, role="member", locale="en_US",
                notify_settings=None, department_id=None):

# 更好：用配置对象
user = User.builder()
    .name("Alice")
    .email("alice@example.com")
    .build()  # ← build() 时才校验必填项
```

### 1.2 参数顺序规则

```
必选参数 → 可选参数 → 回调/配置
输入参数 → 输出参数
Context/Options → 具体的值
```

### 1.3 类型驱动的设计

好的 API 用类型系统禁止非法状态：

```typescript
// 差：status 可以是任意 string，什么都能传
function updateOrder(orderId: string, status: string) {}

// 好：status 是有限枚举
type OrderStatus = "pending" | "confirmed" | "shipped" | "delivered";
function updateOrder(orderId: string, status: OrderStatus) {}

// 更好：用类型系统禁止非法状态组合
type PendingOrder = { status: "pending"; items: Item[] };
type ConfirmedOrder = { status: "confirmed"; items: Item[]; paymentId: string };
type Order = PendingOrder | ConfirmedOrder | ShippedOrder | DeliveredOrder;
```

### 1.4 Go 接口设计专项

> Go 社区黄金法则：Accept interfaces, return structs.

```go
// 好：接受小而精的 interface
type Reader interface {
    Read(p []byte) (n int, err error)
}
func Process(r Reader) error { ... }

// 好：返回具体 struct（调用方可以自由使用）
func NewClient(cfg Config) *Client { ... }

// 注意：不要返回 interface（除非有特殊理由）
func NewReader(path string) (*os.File, error) { ... } // 好，返回具体类型
```

---

## 二、Builder / Fluent API

### 2.1 何时用 Builder

| 场景 | 建议 |
|------|------|
| 对象有 5+ 个可选字段 | 用 Builder |
| 对象构造有复杂逻辑 | 用 Builder 或工厂函数 |
| 对象只有 1-2 个必填 + 少量可选 | 直接用构造函数 |
| 构建有中间步骤（先设置 A 才能设置 B） | 用 Builder（甚至状态类型） |

### 2.2 Builder 质量检查

- `build()` 方法是否校验了所有必填项？
- 链式调用是否可以中途打断？`builder.a().b(); builder.build()` 还好吗？
- 错误是在 `build()` 时报还是 setter 时报？（推荐 build() 时报，更灵活的构建顺序）

### 2.3 Rust 的 Builder 模式（类型状态）

```rust
// Rust 可以让 Builder 的类型状态在编译期保证正确
let user = User::builder()
    .name("Alice")           // 返回 UserBuilder<HasName>
    .email("alice@e.com")    // 返回 UserBuilder<HasNameAndEmail>
    .build()                 // 只有 HasNameAndEmail 才有 build()
    .unwrap();
```

---

## 三、错误处理策略

### 3.1 什么时候用什么

| 机制 | 适用 | 语言 |
|------|------|------|
| 异常（Exception） | 不可恢复的错误，业务流程中断 | Python, Java, C++, JS/TS |
| Result / Either | 可恢复的错误，调用方必须处理 | Rust, Go（多返回值）, FP 风格 TS |
| 错误码 | 简单的 API 层，向下兼容 | C, 某些系统 API |
| 返回 null/undefined | **不推荐**。丢失了错误原因 | -- |

### 3.2 异常粒度

```python
# 差：只有一个泛化的异常
class AppError(Exception): ...

# 好：细粒度的错误类型层次
class DomainError(Exception): ...
class NotFoundError(DomainError): ...
class InvalidStateError(DomainError): ...
class ValidationError(DomainError): ...
```

### 3.3 错误消息的可操作性

错误消息应该告诉用户「怎么修正」：

```
差：Error: Invalid input
中：Error: Email is invalid
好：Error: Cannot create account with 'alice@@example.com': email must be a valid address like 'user@domain.com'
```

---

## 四、版本兼容

### 4.1 废弃（Deprecation）流程

理想的废弃流程：
1. **v1.x**：新 API 上线，旧 API 标记 `@deprecated`，运行时发出 warning
2. **v2.0**：旧 API 正式移除

**检查**：废弃的 API 是否有过渡期（至少一个大版本）？

### 4.2 破坏性变更信号

以下变更几乎肯定是 breaking change：
- 删除公共函数/类
- 改变公共函数的参数签名
- 改变返回值类型
- 收紧参数校验（原来可以传 `null` 现在不行了）
- 改变排序/输出格式（即使功能相同）

### 4.3 迁移指南质量

好的迁移指南：
```
v1 → v2:
  - client.getConfig() → config.get()
  - server.start(port, host) → server.listen({ port, host })
  - 移除了 deprecated 的 legacy_auth 模块，请用 auth
```

差的迁移指南：
```
v1 → v2:
  请参考源码了解变更
```

---

## 五、配置设计

### 5.1 配置来源优先级

标准优先级（从高到低）：
1. 命令行参数
2. 环境变量
3. 配置文件
4. 默认值

### 5.2 配置校验

- **启动时校验**（Fail-fast）：启动时检查配置有效性，有问题立即报错 → 好
- **运行时校验**：用到某个配置时才报错 → 差（可能导致上线后才发现问题）

### 5.3 敏感配置

- 数据库密码、API Key 等是否支持从环境变量/Secret Manager 读取而非明文写在配置文件？
- `.env.example` 是否存在且不含真实密钥？

---

## 六、文档质量

### 6.1 文档完整性检查

| 文档 | 必要 | 加分 |
|------|------|------|
| README | 一句话介绍 + 安装 + 最简示例 | Logo + Badge + Demo |
| Getting Started | 5 分钟内能跑起来的教程 | 带注释的完整示例 |
| API Reference | 所有公共 API 的签名和用途 | 每个函数有代码示例 |
| Concepts / Guide | 架构概念和核心设计决策 | 图解 + 比较 |
| Changelog | 每个版本的变化 | 区分 Feature / Fix / Breaking |
| Migration Guide | 大版本升级步骤 | Before/After 代码对比 |
| FAQ | 常见问题 | 链接到对应文档 |

### 6.2 文档质量判定

- 看完 Getting Started 能否在 5 分钟内 run 起来？
- 高级用法是否需要翻源码？→ 如果需要，文档不足
- 文档是否和代码同步？（有过时的废弃 API 描述？）

---

## 七、GitNexus 辅助命令

```bash
# 搜索公共 API 入口
gitnexus query "public api entry point exported function" --repo <名称>

# 查看核心 API 的调用者（谁在用这个 API）
gitnexus context <公共API函数名> --repo <名称>

# 检查废弃标记
gitnexus query "deprecated obsolete legacy" --repo <名称>
```

---

## 八、评分标准

| 维度 | 1分（差） | 2分（可接受） | 3分（好） | 4分（优秀） |
|------|----------|-------------|---------|-----------|
| 函数签名 | 混乱的参数顺序，必选参数泛滥 | 基本有序但缺乏一致性 | 参数设计合理，默认值恰当 | Builder/选项模式优雅，类型系统完美利用 |
| 错误处理 | 单一异常/所有错误一样 | 有分类但不细 | 错误类型细粒度 | 错误可恢复性区分，消息可操作 |
| 版本兼容 | 无任何考虑 | 有 CHANGELOG | 有 Deprecation 流程 | 有迁移指南，feature flag |
| 配置设计 | 硬编码常量遍地 | 有配置文件 | 配置来源优先级清晰 | 启动时校验 + 敏感配置分离 |
| 文档质量 | 几乎无文档 | 有 README | Getting Started + API 文档 | 全维度文档覆盖 + 准确 |
