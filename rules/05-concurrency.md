# 并发与异步分析规则

> 并发代码的正确性不是测出来的，是推理出来的。

---

## 一、并发模型识别

### 1.1 各语言并发模型

| 语言 | 主要模型 | 辅助模型 | 何时用哪个 |
|------|----------|----------|-----------|
| Python | asyncio 协程 | threading / multiprocessing | I/O → asyncio；CPU → multiprocessing |
| TypeScript | 事件循环 + Promise | Worker Threads | I/O → Promise；CPU → Worker |
| Go | goroutine + channel | sync.Mutex / atomic | CSP 优先，锁在需要时 |
| Rust | tokio/async-std | std::thread + Rayon | I/O → tokio；CPU → Rayon |
| Java | Virtual Threads (21+) | ExecutorService / ForkJoin | I/O → Virtual；CPU → ForkJoin |

### 1.2 模型选择评判

- 项目是否正确选择了并发模型？
  - Python 项目用多线程做大量 I/O → 可接受
  - Python 项目用多线程做 CPU 密集 → GIL 瓶颈，应用 multiprocessing
  - Go 项目全用 Mutex 不用 channel → 可能不 idiomatic，但不一定错

---

## 二、共享状态与同步

### 2.1 共享可变状态检测

> 并发环境下，共享可变状态是万恶之源。

**检测方法**：
1. 搜索全局变量/单例（`global`, `static`, `const` singleton, module-level mutable state）
2. 搜索锁（`Mutex`, `Lock`, `RwLock`, `synchronized`）
3. 检查锁的使用是否正确

### 2.2 锁使用质量

| 检查项 | 好 | 坏 |
|--------|----|----|
| 锁粒度 | 锁保护的范围刚好覆盖临界区 | 整个函数被锁住（锁粒度过大） |
| 持有锁时 I/O | 锁内不做 I/O | 锁内做数据库查询/网络请求 |
| 多锁顺序 | 所有代码以相同顺序获取多锁 | 不同代码的锁获取顺序不同（死锁风险） |
| 锁的类型 | 读多写少用 RwLock | 读多写少用 Mutex |

### 2.3 Go 并发专项

```go
// 检查 goroutine 泄露
// 1. goroutine 是否有明确的退出条件？
// 2. 是否通过 context 控制取消？
// 3. channel 是否由发送方关闭？

// 坏：goroutine 可能永远阻塞（没有用 select 处理取消）
go func() {
    result := <-ch  // 如果 ch 永远不会收到消息，goroutine 泄露
    process(result)
}()

// 好：有取消机制
go func() {
    select {
    case result := <-ch:
        process(result)
    case <-ctx.Done():
        return
    }
}()
```

### 2.4 原子操作 vs 锁

- 简单的计数器/protocol → `atomic` 比 `Mutex` 更好
- 复杂的数据结构 → 锁或 lock-free 数据结构

---

## 三、背压（Backpressure）机制

### 3.1 什么是背压

> 当生产者速度超过消费者速度时，需要有机制让生产者慢下来。

### 3.2 背压检测

| 组件 | 需要检查 | 问题信号 |
|------|----------|----------|
| 消息队列 | Consumer group lag | lag 持续增长 |
| Stream 处理 | 管道中 buffer 是否有限 | 无界 buffer → 内存炸弹 |
| HTTP 请求 | 请求并发控制 | 无限制并发 → 打垮下游 |
| goroutine 池 | goroutine 数量是否有限 | 无限制创建 goroutine |

### 3.3 各语言的背压机制

| 语言 | 机制 | 检测 |
|------|------|------|
| Go | buffered channel 大小 | `make(chan T, N)` 的 N 是多少？ |
| Python | asyncio.Queue(maxsize) | maxsize 是否合理？ |
| TypeScript | Stream API | 是否处理了 pause/resume？ |
| Rust | bounded channels / Stream | `tokio::sync::mpsc::channel(capacity)` 的 capacity？ |

---

## 四、资源生命周期管理

### 4.1 连接池

```python
# 检查连接池配置
# - 最大连接数是否合理？（不能无限，不能太小）
# - 是否有连接健康检查？
# - 空闲连接是否回收？
# - 连接获取是否有超时？
```

### 4.2 资源泄露风险

| 资源 | 泄露表现 | 检测方法 |
|------|----------|----------|
| goroutine | 数量持续增长 | runtime.NumGoroutine() 监控 |
| 数据库连接 | 连接池耗尽 | 看连接池使用率 |
| 文件句柄 | "too many open files" | lsof / Process Explorer |
| 定时器 | 内存增长 | Go: `time.After` 在 select 中 → 泄露 |

### 4.3 优雅关闭

```
好的关闭流程：
1. 停止接收新请求
2. 等待正在处理的请求完成（有超时）
3. 关闭依赖服务（数据库 → 消息队列 → 缓存）
4. 释放所有资源
```

---

## 五、异步模型检查

### 5.1 函数颜色问题

> 同步函数调用异步函数很困难（或不可能），这就是"函数颜色"问题。

| 语言 | 解决方案 | 检测 |
|------|----------|------|
| Go | 全同步（goroutine 对调用者透明） | 没有颜色问题 |
| Python | `asyncio.run()` | 是否混用了 async/sync 代码？ |
| TypeScript | `await` / `.then()` | 是否到处在 await？说明 async 渗透过深 |
| Rust | `block_on` / `spawn_blocking` | 是否在 async 中调用阻塞函数？ |

### 5.2 Python async 专项

```python
# 坏：在 async 函数中调用同步阻塞函数
async def handle_request():
    result = requests.get("https://...")  # ← 阻塞了整个事件循环！
    return result

# 好：用 async HTTP 库或将阻塞调用放入线程池
async def handle_request():
    async with aiohttp.ClientSession() as session:
        async with session.get("https://...") as resp:
            return await resp.json()

# 或
async def handle_request():
    loop = asyncio.get_running_loop()
    result = await loop.run_in_executor(None, requests.get, "https://...")
```

---

## 六、GitNexus 辅助命令

```bash
# 搜索并发相关代码
gitnexus query "goroutine channel mutex async await lock" --repo <名称>

# 搜索共享状态
gitnexus query "global state singleton shared mutable static var" --repo <名称>

# 搜索资源管理
gitnexus query "connection pool close cleanup shutdown dispose" --repo <名称>

# 搜索背压相关
gitnexus query "backpressure buffer limit rate limit throttle" --repo <名称>
```

---

## 七、评分标准

| 维度 | 1分（差） | 2分（可接受） | 3分（好） | 4分（优秀） |
|------|----------|-------------|---------|-----------|
| 并发模型 | 模型错误（GIL 下多线程 CPU 密集） | 基本正确 | 模型正确 + 惯用模式 | 模型精准，优良惯用 |
| 同步 | 共享可变状态无保护 | 有锁但粒度偏大 | 锁粒度合适 | Lock-free + 不可变优先 |
| 背压 | 无界 buffer | 有界但阈值无理由 | 有界 + 合理阈值 | 全链路背压传播 |
| 资源管理 | 资源泄露明显 | 基本正确 | 连接池 + 优雅关闭 | 完善的资源生命周期管理 |
| 异步 | 阻塞混入异步 | 基本分离 | 清晰分离 | 异步-同步边界完美 |
