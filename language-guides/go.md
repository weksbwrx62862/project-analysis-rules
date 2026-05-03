# Go 项目分析专项指南

> Go 的哲学是「少即是多」，分析 Go 项目的核心是判断它是否做到了简洁而不过度简化。

---

## 一、接口设计

### 1.1 小接口原则

```go
// Go 社区金律：接口应该小而精（1-3 个方法）
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

type ReadWriter interface {
    Reader
    Writer
}

// 坏：大接口
type UserRepository interface {
    Get(id int) (*User, error)
    Save(u *User) error
    Delete(id int) error
    List() ([]*User, error)
    FindByEmail(email string) (*User, error)
    // ... 方法太多
}
```

> **检测**：项目中是否有超过 5 个方法的 interface？如果有，是否有更好的拆分方案？

### 1.2 接口位置

```go
// Go 的惯例：接口定义在使用方（consumer），而非实现方（producer）
// consumer/user.go
type UserStore interface {
    Find(id int) (*User, error)
}
func GetUser(store UserStore, id int) (*User, error) { ... }

// 好：接口在使用方定义，实现方不需要知道接口的存在
// 坏：接口 + 实现都在同一个包（Java 式的过度设计）
```

### 1.3 Accept interfaces, return structs

```go
// ✅ 好
func NewClient(config Config) *Client { return &Client{...} }  // 返回 struct
func Process(r io.Reader) error { ... }                         // 接受 interface

// ❌ 差（罕见）—— 返回 interface 限制了调用方
func NewClient(config Config) ClientInterface { ... }
```

---

## 二、错误处理

### 2.1 错误包装

```go
// 坏：丢失错误上下文
if err != nil {
    return err  // 调用方不知道这个错误从哪里来
}

// 好：包装错误保留调用链
if err != nil {
    return fmt.Errorf("processOrder: %w", err)  // %w 使得 errors.Is 和 errors.As 可用
}
```

**检测**：搜索 `return err`，看是否有未包装的错误返回。

### 2.2 自定义错误类型

```go
// 好的自定义错误：调用方可以用 errors.Is / errors.As 判断
var ErrNotFound = errors.New("not found")
var ErrInvalidInput = errors.New("invalid input")

type ValidationError struct {
    Field string
    Value interface{}
    Msg   string
}
func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation error on field %s: %s", e.Field, e.Msg)
}
```

### 2.3 错误检查完整性

```bash
# 搜索可能忽略 error 的代码
grep -rn "_, err" --include="*.go" | grep -v "if err"
grep -rn "\.\.\.\)$" --include="*.go" | head  # 检查函数调用是否检查了所有返回值
```

---

## 三、并发

### 3.1 goroutine 生命周期

```go
// 坏：goroutine 可能泄露
func process() {
    ch := make(chan int)
    go func() {
        ch <- compute() // 如果没有人从 ch 读取，goroutine 永远阻塞
    }()
}

// 好：goroutine 有明确的退出条件
func process(ctx context.Context) {
    ch := make(chan int, 1) // 缓冲避免 goroutine 阻塞
    go func() {
        defer close(ch)
        select {
        case ch <- compute():
        case <-ctx.Done():
            return
        }
    }()
}
```

### 3.2 Channel 使用惯例

```go
// Go 惯例：发送方关闭 channel
func producer(out chan<- int) {
    defer close(out)  // ← 发送方关闭
    for _, v := range data {
        out <- v
    }
}

// 坏：接收方关闭（可能引起发送方 panic）
// 坏：不关闭 channel（goroutine 泄露）
```

### 3.3 Context 传播

```go
// 好：context 贯穿整个调用链
func HandleRequest(ctx context.Context, req *Request) error {
    user, err := getUser(ctx, req.UserID)    // ctx 传递给下游
    if err != nil {
        return err
    }
    return processUser(ctx, user)              // ctx 继续传递
}

// 坏：接收了 context 但没有使用或没有传递
func HandleRequest(ctx context.Context, req *Request) error {
    result := db.Query("SELECT ...")  // 没有 context → 没有超时/取消
}
```

### 3.4 并发原语选择

| 场景 | 推荐 | 理由 |
|------|------|------|
| goroutine 间通信 | channel | CSP 模型，Go 惯用法 |
| 保护共享状态 | sync.Mutex / sync.RWMutex | 锁更直接 |
| 等待多个 goroutine | sync.WaitGroup / errgroup | |
| 简单计数器 | atomic | 比 Mutex 高效 |
| 只运行一次 | sync.Once | |

---

## 四、包组织

### 4.1 包命名

```go
// 好：包名即职责
package auth      // 身份验证相关
package storage   // 存储抽象

// 坏：万能包名
package util      // 什么都能往里放
package common    // 说不清是什么
package helper    // 同上
```

### 4.2 internal 包的使用

```go
// internal/ 包只能被祖先目录的包导入
myproject/
  internal/
    db/        // 只能被 myproject 下的包导入
    config/    // 外部包无法导入
  cmd/
    server/    // 可以导入 internal/db
  pkg/
    api/       // 可以导入 internal/db
```

检测：是否用 `internal/` 保护了不希望外部使用的实现细节？

### 4.3 按功能 vs 按层次

```go
// 按功能组织（推荐）
/user/
  handler.go
  service.go
  repository.go
  model.go

// 按层次组织（传统，可接受）
/handler/
  user.go
/service/
  user.go
/repository/
  user.go
/model/
  user.go
```

---

## 五、测试

### 5.1 Table-driven tests

```go
// Go 惯用法：table-driven tests
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive", 1, 2, 3},
        {"negative", -1, -2, -3},
        {"zero", 0, 0, 0},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            if got := Add(tt.a, tt.b); got != tt.expected {
                t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, got, tt.expected)
            }
        })
    }
}
```

### 5.2 测试辅助

```go
// t.Helper(): 标记函数为测试辅助函数，错误信息会指向调用方
func assertEqual(t *testing.T, got, want interface{}) {
    t.Helper()
    if got != want {
        t.Errorf("got %v, want %v", got, want)
    }
}

// t.Cleanup(): 注册测试后的清理函数
func TestWithDB(t *testing.T) {
    db := setupDB(t)
    t.Cleanup(func() { db.Close() })  // 不管测试成功失败，都会执行
}
```

---

## 六、常见 Go 项目分析

### 标准库项目

- 是否优先使用标准库而非第三方库？（Go 的重要哲学）
- `net/http` vs `gin`/`echo`/`chi` 的选择是否合理？

### 微服务项目

- 是否过度使用了框架？（Go 微服务通常倾向于轻框架）
- `Wire` / `Fx` 做 DI — 是否必要？
- 配置管理：`viper` + `cobra` 的使用是否恰当？

### CLI 工具

- 是否使用 `cobra` + `viper`？
- 是否提供了清晰的帮助信息？
- 是否符合 Unix 哲学（小、专注、可组合）？
