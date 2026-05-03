# 可测试性分析规则

> 如果代码难以测试，那就是代码在告诉你：我的设计有问题。

---

## 一、依赖注入与可测试性

### 1.1 可测试 = 可注入

```
不可测试的代码：
class OrderService:
    def __init__(self):
        self.db = MySQLConnection("localhost")  # ← 硬编码依赖
        self.mailer = SmtpMailer("smtp.example.com")  # ← 硬编码依赖

    def place_order(self, order):
        self.db.save(order)           # 测试必须有真实 MySQL
        self.mailer.send(order.email)  # 测试会真的发邮件

可测试的代码：
class OrderService:
    def __init__(self, db: Database, mailer: Mailer):  # ← 依赖注入
        self.db = db
        self.mailer = mailer

    # 测试时：传入 InMemoryDatabase 和 FakeMailer
```

### 1.2 依赖注入程度判断

| 模式 | 可测试性 | 在代码中的表现 |
|------|---------|--------------|
| 构造函数注入 | ✅ 最好 | `__init__(self, dep: Interface)` |
| 方法参数注入 | ✅ 好 | `def do(self, dep: Interface)` |
| 属性/Setter 注入 | ⚠️ 一般 | `service.db = InMemoryDB()` |
| 服务定位器 | ⚠️ 隐式依赖 | `container.resolve(DB)` |
| 硬编码 + 全局变量 | ❌ 差 | `db = MySQL()`, `global config` |
| import 时创建实例 | ❌ 差 | `from db import connection` |

### 1.3 接口隔离与 Mock 成本

> 接口越窄，Mock 成本越低。

```go
// 接口太大 → Mock 需要实现 5 个方法
type UserRepository interface {
    Find(id int) (*User, error)
    Save(u *User) error
    Delete(id int) error
    FindByEmail(email string) (*User, error)
    List(offset, limit int) ([]*User, error)
}

// 对于只需要查询的服务，接口可以更小
type UserFinder interface {
    Find(id int) (*User, error)
}
```

---

## 二、测试金字塔

### 2.1 理想比例

```
         ╱ ╲
        ╱E2E╲          少量（~5%）
       ╱──────╲
      ╱ 集成测试 ╲       一定数量（~15%）
     ╱────────────╲
    ╱   单元测试     ╲    大量（~80%）
   ╱──────────────────╲
```

### 2.2 不同项目类型的合理比例

| 项目类型 | 单元测试 | 集成测试 | E2E |
|----------|---------|---------|-----|
| 库/SDK | 高（80%+） | 中 | 低 |
| Web 后端 | 中～高 | 中 | 中 |
| 前端 UI 重 | 中 | 中～高 | 中～高 |
| CLI 工具 | 高 | 低～中 | 低 |
| 嵌入式/驱动 | 中 | 高 | 中 |

### 2.3 测试反模式

- **冰淇淋甜筒**（反金字塔）：E2E 最多，单元测试最少 → 慢、脆弱
- **沙漏**：单元测试和 E2E 多，集成测试少 → 模块间交互无验证
- **只有 E2E**：任何失败定位成本极高

---

## 三、测试质量深度评估

### 3.1 行为测试 vs 实现测试

```python
# 实现测试（差）— 对着实现写的测试
def test_order_total():
    order = Order()
    order.items = [Item(price=10), Item(price=20)]
    order.discount = 5
    order.tax = 3
    assert order.calculate() == 28  # 如果内部实现变了，测试就得改

# 行为测试（好）— 对着需求写的测试
def test_order_total_reflects_items_and_discounts():
    order = OrderBuilder().with_items(
        Item(price=10), Item(price=20)
    ).with_discount(5).build()
    assert order.total == 25  # 不管内部怎么算，结果对就行
```

### 3.2 测试命名规范

```
好：test_<方法>_<场景>_<预期结果>
    test_withdraw_fails_when_balance_insufficient
    test_login_returns_token_when_credentials_valid

差：test_<方法>_<编号> / test_<方法>_works
    test_withdraw_1
    test_order_works
```

### 3.3 边界条件覆盖

每个测试文件检查是否覆盖：
- [ ] 正常路径（happy path）
- [ ] 边界：空输入、零值、最大值、最小值
- [ ] 错误路径：无效输入、依赖失败、超时
- [ ] 并发场景：同时访问、竞态条件

### 3.4 测试独立性

- 测试能否以任意顺序运行？（不能依赖其他测试的副作用）
- 测试能否并行运行？（不能共享可变状态）
- 测试能否单独运行？（不需要运行全部才能跑一个）

---

## 四、测试基础设施

### 4.1 测试替身选择

| 类型 | 何时用 | 例子 |
|------|--------|------|
| **Fake** | 需要真实行为但不依赖外部 | InMemoryRepository, sqlite :memory: |
| **Stub** | 需要控制返回值 | `stub.send().returns(True)` |
| **Mock** | 需要验证交互 | `expect(mailer.send).toHaveBeenCalledWith(...)` |
| **Spy** | 记录调用但不干预 | 记录被调用的参数 |
| **Dummy** | 只需要填充参数 | 不关心值的任意对象 |

### 4.2 Fixture 质量

```python
# 差：测试数据不清晰
user = User.objects.create(name="test", email="test@test.com", ...)

# 中：工厂函数
user = make_user()

# 好：Builder + 默认值
user = UserBuilder().with_name("Alice").build()  # 只指定你关心的

# 更好：Named parameters with defaults
user = user(name="Alice")  # 其他字段用合理的默认值
```

### 4.3 运行速度

- 单元测试应该在秒级完成（< 500ms per test, < 30s total）
- 集成测试可以在分钟级
- E2E 测试控制在 10 分钟内

---

## 五、GitNexus 辅助命令

```bash
# 测试空白区（没有被测试引入的模块）
gitnexus cypher "
  MATCH (src:Module)
  WHERE NOT src.name CONTAINS 'test' AND NOT src.name CONTAINS 'spec'
  OPTIONAL MATCH (test:Module)-[:IMPORTS]->(src)
  WHERE test.name CONTAINS 'test' OR test.name CONTAINS 'spec'
  WITH src, count(test) AS test_count
  WHERE test_count = 0
  RETURN src.name
  LIMIT 20
" --repo <名称>

# 搜索 DI 容器
gitnexus query "dependency injection container wire fx di" --repo <名称>

# 搜索 mock/stub
gitnexus query "mock stub fake test double" --repo <名称>
```

---

## 六、评分标准

| 维度 | 1分（差） | 2分（可接受） | 3分（好） | 4分（优秀） |
|------|----------|-------------|---------|-----------|
| 依赖注入 | 硬编码依赖，无法测试 | 部分 DI | 构造函数注入为主 | 完美的 DI + 小接口 |
| 测试金字塔 | 只有 E2E，或全无测试 | 有一些测试但形状不对 | 金字塔形 | 金字塔形 + 比例精准 |
| 测试质量 | 测实现不测行为 | 混合 | 行为测试为主 | 命名描述场景 + 边界全覆盖 |
| Mock 便利性 | Mock 一个依赖要 20 行 | 10 行 | 5 行 | 1 行模拟（接口设计优秀） |
| 测试基础设施 | 无 fixture/factory | 有基本 fixture | Builder 模式 | Fixture 库完善 + 测试快 |
