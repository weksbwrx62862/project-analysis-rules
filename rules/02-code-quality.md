# 代码质量分析规则

> 代码是写给人看的，只是顺便给机器执行而已。

---

## 一、函数设计

### 1.1 函数长度

| 语言 | 绿灯 | 黄灯 | 红灯 |
|------|------|------|------|
| Python/TS/Go | < 30 行 | 30-60 行 | > 60 行 |
| Rust（类型系统多） | < 40 行 | 40-70 行 | > 70 行 |
| Java/C# | < 25 行 | 25-50 行 | > 50 行 |

> 超过红灯线的函数不要急着批判——先看是「长而清晰」还是「长而混乱」。某些算法函数、状态机转换函数天然较长但结构良好。

### 1.2 函数纯度

```
纯函数 = 相同输入 → 相同输出 + 无副作用
```

**判断方法**（挨个打开核心逻辑函数）：
- 能否用同样的输入得到同样的输出？（不能依赖全局状态）
- 是否修改了传入的参数？
- 是否修改了全局变量？
- 是否执行了 I/O（数据库、文件、网络）？

**评分**：核心业务逻辑中纯函数比例：
- > 60% → 优秀（业务逻辑和 I/O 干净分离）
- 30-60% → 可接受
- < 30% → 关注点混合严重

### 1.3 参数设计

| 参数个数 | 评价 |
|----------|------|
| 0-1 | 很好，除非无参函数依赖了隐式状态 |
| 2-3 | 正常 |
| 4-5 | 黄灯：考虑是否能用配置对象/选项模式 |
| > 5 | 红灯：几乎肯定需要重构 |

额外检查：
- 布尔参数：是否用 enum 代替提高可读性？`process(visible=true)` vs `process(Visibility.VISIBLE)`
- 输出参数：是否通过返回值而非修改参数传递结果？
- 可选参数是否有合理默认值？

---

## 二、抽象质量

### 2.1 抽象不泄漏原则

> 好的抽象让你不需要理解底层实现就能用对。

**反面例子**：
```python
# 抽象泄露：需要知道是用 SQL 数据库才能正确使用
user_repo.get_by_id(1)            # 有的实现会抛 SQLException
user_repo.get_by_id(1, lock=True)  # 泄露了 SQL 的 FOR UPDATE 语义
```

**正面例子**：
```python
user = user_repo.find(UserId(1))             # 返回 Optional[User]
user = user_repo.get_or_fail(UserId(1))      # 找不到抛出 DomainError
user = user_repo.get_with_lock(UserId(1))    # 用领域概念而非 SQL 概念
```

### 2.2 抽象层次一致性

> 同一个函数内，所有操作应该在同一抽象层次。

```python
# 差：高层和低层混在一起
def process_order(order):
    validate_order(order)        # 高层
    db.execute("UPDATE ...")     # 低层 ← 突然下沉到 SQL
    send_notification(order)     # 高层

# 好：保持在同一个抽象层次
def process_order(order):
    validate_order(order)
    order_repo.save(order)       # 用 repository 抽象屏蔽 SQL
    notify_service.send(OrderConfirmed(order))
```

### 2.3 过度抽象检测

- 一个 interface/protocol 只有 1 个实现 → 可能是过度抽象
- 一个抽象类只有 1 个子类 → 可能是过度抽象
- 未来可能需要的扩展点 → YAGNI（You Ain't Gonna Need It）

**例外**：测试用的 mock 实现也算一个实现，所以 1 个 prod + 1 个 test = 合理的 2 个实现。

---

## 三、SOLID 原则检查

### 3.1 单一职责（SRP）

**判断方法**：「这个类/模块做什么？」—— 如果回答中有「和 / 以及 / 还有」→ 职责过多。

**检测技巧**：
- 类的方法数 > 20 → 职责过多（上帝对象）
- 类的字段数 > 10 → 可能承载过多状态
- 类的 import 数 > 15 → 可能耦合过多

### 3.2 开闭原则（OCP）

**判断方法**：添加一个新功能（如新的支付方式、新的导出格式）需要：
- 只新增文件 → 好
- 修改 1 个 switch/if-else + 新增文件 → 可接受
- 修改多处 switch/if-else → 差

### 3.3 里氏替换（LSP）

**判断方法**：子类是否能完全替换父类使用？

```python
# LSP 违反：子类强化了前置条件
class Rectangle:
    def set_size(self, w, h): pass

class Square(Rectangle):
    def set_size(self, w, h):
        assert w == h  # ← 父类没有这个约束！
        super().set_size(w, h)
```

### 3.4 接口隔离（ISP）

**判断方法**：接口的方法数是否 > 5？→ 考虑拆分。
Go 语言天然倾向小接口（1-3 个方法），其他语言应学习这种设计。

### 3.5 依赖倒置（DIP）

**判断方法**：
- 高层模块是否依赖了低层具体实现？
- 抽象是否定义在高层模块中？（应该如此）

---

## 四、命名质量

### 4.1 命名层级

| 命名 | 评价 | 例子 |
|------|------|------|
| 领域驱动 | 好 | `calculateRefund()`, `PaymentGateway` |
| 技术术语 | 可 | `handleClick()`, `HttpClient` |
| 缩写/模糊 | 差 | `proc()`, `mgr`, `data` |
| 单字母 | 差（除循环变量外） | `f()`, `d`, `x` |
| 误导 | 差 | 叫 `getXxx()` 但有副作用 |

### 4.2 一致性检查

- 同一个概念在项目中是否只有一个名字？
  - 反例：`remove`, `delete`, `destroy` 做同样的事
- 动词-名词结构是否一致？
  - 好：`createUser`, `updateUser`, `deleteUser`
  - 差：`createUser`, `userUpdate`, `delete_user`

---

## 五、错误处理

### 5.1 错误信息质量

好的错误信息 = 什么操作 + 什么输入 + 为什么失败 + 怎么修正

```python
# 差
raise ValueError("Invalid input")

# 好
raise ValueError(
    f"Cannot create user with email '{email}': "
    f"email format is invalid. Expected format: user@domain.com"
)
```

### 5.2 错误分类

| 错误类型 | 策略 | 例子 |
|----------|------|------|
| 可恢复 | 返回 Result/Error 让调用方决策 | 表单校验失败、余额不足 |
| 不可恢复 | 日志 + 抛异常/panic 让上层处理 | 数据库连接失败、配置缺失 |
| 可重试 | 重试 + 退避 + 最终失败 | 网络超时、临时服务不可用 |

### 5.3 常见的错误处理反模式

- **吞异常**：`try: ... except: pass` 或 `try: ... except Exception: ...` 而不处理
- **日志后继续**：`catch (e) { log.error(e); }` 然后假装没发生
- **错误信息无上下文**：`Error: failed` 没有告诉用户失败的是什么
- **Go 专项**：不检查 error 返回值；不用 `%w` 包装错误丢失调用链

---

## 六、GitNexus 辅助命令

```bash
# 大文件检测
gitnexus cypher "
  MATCH (m:Module)
  RETURN m.name, m.lines AS line_count
  ORDER BY line_count DESC LIMIT 10
" --repo <名称>

# 上帝对象（方法数 > 20）
gitnexus cypher "
  MATCH (c:Class)
  OPTIONAL MATCH (c)-[:HAS_METHOD]->(m:Method)
  WITH c, count(m) AS method_count
  WHERE method_count > 20
  RETURN c.name, method_count
  ORDER BY method_count DESC
" --repo <名称>

# 过度抽象（只有 0-1 个实现的接口）
gitnexus cypher "
  MATCH (i:Interface)
  OPTIONAL MATCH (c:Class)-[:IMPLEMENTS]->(i)
  WITH i, count(c) AS impl_count
  WHERE impl_count <= 1
  RETURN i.name, impl_count
" --repo <名称>
```

---

## 七、评分标准

| 维度 | 1分（差） | 2分（可接受） | 3分（好） | 4分（优秀） |
|------|----------|-------------|---------|-----------|
| 函数设计 | 大量 100+ 行函数 | 大部分 < 60 行 | < 30 行为主，纯函数多 | 函数短小精悍，纯函数 > 60% |
| 抽象层次 | 抽象泄漏严重 | 偶有泄漏 | 抽象干净 | 抽象即文档，完美层次一致 |
| 命名 | 大量缩写和单字母 | 基本可读 | 领域驱动命名 | 领域语言优美，自解释 |
| 错误处理 | 吞异常，无上下文 | 有错误处理但不一致 | 错误信息有上下文 | 细粒度错误类型，可操作性强 |
| 重复代码 | 大量复制粘贴 | 偶有重复 | 基本无重复 | DRY 原则贯彻 |
