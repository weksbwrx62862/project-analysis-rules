# Rust 项目分析专项指南

> Rust 分析的核心不是看编译过不过（编译器帮你保证了），而是看抽象是否恰到好处，unsafe 是否真正必要。

---

## 一、所有权设计

### 1.1 引用 vs Clone

```rust
// 差：不必要的 clone
fn process(data: &Data) -> Result {
    let owned = data.clone(); // ← 如果只需要读取，clone 浪费
    heavy_computation(owned)
}

// 好：借用
fn process(data: &Data) -> Result {
    heavy_computation(data) // ← 能借用就不要拥有
}
```

**检测**：`grep -rn "\.clone()" --include="*.rs"` — 是否有不必要的 clone？

### 1.2 生命周期标注

```rust
// 好：生命周期只标注必要的
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str { ... }

// 过度：滥用 'static
fn create() -> &'static str { ... }  // ← 只有字符串常量或泄露才能用 'static
```

### 1.3 绕开借用检查器的反模式

```rust
// 反模式：用 Rc<RefCell<T>> 绕开借用检查器
// 这意味着在运行时做借用检查（可能 panic），放弃编译期安全
let data: Rc<RefCell<Vec<i32>>> = Rc::new(RefCell::new(vec![]));

// 问自己：能不能重构数据结构而不需要 RefCell？
```

### 1.4 并发安全

```rust
// Arc<Mutex<T>> — 跨线程共享可变状态
let shared = Arc::new(Mutex::new(data));

// Arc<RwLock<T>> — 读多写少的场景
let shared = Arc::new(RwLock::new(data));

// 判断：锁的类型选择是否正确？是否考虑了读多/写多的比例？
```

---

## 二、错误处理

### 2.1 错误处理库选择

| 库 | 何时用 | 特征 |
|-----|--------|------|
| `thiserror` | 库（library） | 定义错误类型，派生 Error trait |
| `anyhow` | 应用（application） | 简单错误传播，不定义类型层次 |
| `color_eyre` | 应用 + 需要彩色输出 | anyhow 的增强版 |

```rust
// 库——用 thiserror
use thiserror::Error;

#[derive(Error, Debug)]
pub enum MyLibError {
    #[error("not found: {0}")]
    NotFound(String),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}

// 应用——用 anyhow
use anyhow::{Context, Result};

fn main() -> Result<()> {
    let content = std::fs::read_to_string("config.toml")
        .context("failed to read config file")?;
    Ok(())
}
```

### 2.2 unwrap/expect 使用

```bash
grep -rn "\.unwrap()" --include="*.rs" | wc -l
grep -rn "\.expect(" --include="*.rs" | wc -l
```

| 频率 | 评价 |
|------|------|
| 仅在示例/测试中出现 | ✅ 好 |
| 出现在生产代码但有理有据（如刚创建的资源） | ⚠️ 可接受 |
| 到处出现且无文档解释为什么不会 panic | ❌ 差 |

### 2.3 错误类型层次

- 是否定义了清晰的错误类型层次？
- 是否区分了可恢复和不可恢复的错误？
- `?` 操作符的使用：是否在合适的地方传递错误？

---

## 三、Trait 设计

### 3.1 孤儿规则（Orphan Rule）

> 不能为外部类型实现外部 trait。这是分析时需要理解的约束。

```rust
// 常见模式：Newtype 绕开孤儿规则
struct MyVec(Vec<i32>);

impl std::fmt::Display for MyVec {  // Vec 是外部的，Display 也是外部的
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "[{}]", self.0.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(", "))
    }
}
```

### 3.2 dyn Trait vs impl Trait

```rust
// dyn Trait：动态分发，有运行时开销
fn process(reader: &dyn Read) { ... }

// impl Trait：静态分发（零成本抽象）
fn process(reader: impl Read) { ... }

// 判断：
// - 小函数/高频率 → impl Trait（但可能导致编译时间增长）
// - 需要异构集合 → dyn Trait
```

### 3.3 过度泛型化

```rust
// 反模式：过度泛型化——只有一个地方用了这个泛型参数
fn process<D: Database>(db: &D) -> Result<()> { ... }
// 如果整个项目中只有一个 Database 实现，这个泛型就是过度抽象
```

---

## 四、Unsafe 审计

### 4.1 Unsafe 最小化原则

```rust
// 好：unsafe 块尽可能小
let slice = unsafe {
    // SAFETY: ptr 来自刚刚分配的 Vec，在生命周期内有效
    std::slice::from_raw_parts(ptr, len)
};

// 好：unsafe 块有 SAFETY 注释解释
```

### 4.2 Unsafe 使用频率

```bash
grep -rn "unsafe" --include="*.rs" | wc -l
```

| unsafe 块数量 | 评价 |
|---------------|------|
| 0-5 | 可能不需要 unsafe |
| 5-20 | 可接受（FFI、底层操作） |
| > 50 | 需要深入审计 — 每个 unsafe 都需要充分理由 |
| 只有 FFI 调用 | ✅ 这是 unsafe 的正当用途 |

---

## 五、异步 Rust

### 5.1 运行时选择

| 运行时 | 何时用 |
|--------|--------|
| tokio | 大多数场景，功能最全 |
| async-std | 倾向于更贴近标准库 API 的项目 |
| smol | 小型项目，轻量 |

判断：是否根据项目规模选了合适的运行时？

### 5.2 Pin/Unpin

```rust
// Pin 是 Rust 异步中最棘手的概念之一
// 检测：是否大量使用了 Pin<Box<dyn Future>>？可能是抽象设计有问题
```

### 5.3 async 中不阻塞

```rust
// 坏：在 async 函数中调用同步阻塞函数
async fn handle_request() {
    std::thread::sleep(Duration::from_secs(5)); // ← 阻塞了整个 tokio 运行时！
}

// 好：用 spawn_blocking 处理 CPU 密集或阻塞操作
async fn handle_request() {
    tokio::task::spawn_blocking(|| {
        std::thread::sleep(Duration::from_secs(5));
    }).await.unwrap();
}
```

---

## 六、常见 Rust 模式

### Builder 模式

```rust
// derive_builder / typed-builder
#[derive(Builder)]
struct Config {
    host: String,
    #[builder(default = "8080")]
    port: u16,
    #[builder(default)]
    timeout: Option<Duration>,
}
```

### Newtype 模式

```rust
// 给基础类型赋予领域语义
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct UserId(uuid::Uuid);  // ← 不会和 OrderId 混淆
struct Email(String);        // ← 不会和 Username 混淆
```

### Extension Trait

```rust
// 给外部类型添加方法
trait StrExt {
    fn is_valid_email(&self) -> bool;
}

impl StrExt for str {
    fn is_valid_email(&self) -> bool {
        self.contains('@')
    }
}

"test@example.com".is_valid_email(); // ← 扩展了 &str
```

### 类型状态模式

```rust
// 编译期保证状态转换正确
struct PendingOrder { items: Vec<Item> }
struct ConfirmedOrder { items: Vec<Item>, payment_id: String }

impl PendingOrder {
    fn confirm(self, payment_id: String) -> ConfirmedOrder {
        ConfirmedOrder { items: self.items, payment_id }
    }
}
// ConfirmedOrder 没有 confirm() 方法 → 编译期防止重复确认
```

---

## 七、Cargo.toml 分析

- 依赖数量是否合理？（Rust 社区倾向于少依赖）
- 是否有 `[features]` 定义？（特性门控是否合理？）
- 是否有 `[workspace]`？（monorepo 组织）
- 是否使用了 cargo 的 `patch` / `replace`？（可能是临时 hack）
