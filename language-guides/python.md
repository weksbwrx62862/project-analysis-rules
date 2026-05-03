# Python 项目分析专项指南

> Python 的灵活性是它的双刃剑——灵活意味着同一个问题有 10 种解法，需要判断哪种是「好的」Python 写法。

---

## 一、类型系统分析

### 1.1 类型注解覆盖率

```bash
mypy --strict <项目路径>
```

| 覆盖率 | 评价 |
|--------|------|
| > 80% | 优秀 — 项目成熟度高的标志 |
| 40-80% | 可接受 — 渐进式类型化的正常阶段 |
| < 40% | 有待改善 — 但老项目可能刻意选择了动态风格 |

### 1.2 类型注解深度评估

不只看覆盖率，还要看质量：

```python
# 敷衍的类型注解
def process(data: Any) -> Any: ...

# 合格的类型注解
def process(data: dict[str, Any]) -> dict[str, Any]: ...

# 优秀的类型注解
from typing import TypedDict

class ProcessedResult(TypedDict):
    status: str
    count: int

def process(data: Mapping[str, object]) -> ProcessedResult: ...
```

### 1.3 Protocol vs ABC vs duck typing

| 方式 | 何时用 | Python 著名项目中的例子 |
|------|--------|------------------------|
| Protocol (PEP 544) | 静态鸭子类型，不需显式继承 | `typing.SupportsInt` |
| ABC | 需要运行时检查 + 默认实现 | `collections.abc.Sequence` |
| duck typing | 简单场景，或需要最大灵活性 | 标准库大量使用 |

检测：是否滥用 `isinstance` 检查 `ABC` 破坏了 duck typing？

---

## 二、包组织分析

### 2.1 src-layout vs flat-layout

```
src-layout（推荐用于库）:
  project/
    src/
      mypackage/
        __init__.py
        core.py

flat-layout（常用于应用）:
  project/
    mypackage/
      __init__.py
      core.py
```

### 2.2 `__init__.py` 的使用

| 用法 | 评价 | 例子 |
|------|------|------|
| 空文件 | 可（只用来标记包） | 很多内部包 |
| Re-export 公共 API | ✅ 好 | `from .core import Engine, Config` |
| 包含业务逻辑 | ❌ 差 | 业务逻辑不应放在 `__init__.py` |

### 2.3 `__all__` 定义

```python
# 差：没有 __all__，from pkg import * 不可预期
# 好：明确定义公共 API
__all__ = ["Engine", "Config", "run"]
```

### 2.4 循环导入检测

```bash
# 启动时检查
python -c "import mypackage"  # 如果报 ImportError 且信息含 'circular' → 有循环导入
```

---

## 三、Pythonic 程度评估

### 3.1 上下文管理器

```python
# 不 Pythonic
f = open("file.txt")
try:
    data = f.read()
finally:
    f.close()

# Pythonic
with open("file.txt") as f:
    data = f.read()
```

检测：资源管理（文件、锁、数据库连接）是否都用了上下文管理器？

### 3.2 迭代器/生成器

```python
# 不 Pythonic (内存中构建整个列表)
result = [x * 2 for x in range(1000000)]

# Pythonic (惰性计算)
result = (x * 2 for x in range(1000000))
```

检测：是否有可以改用生成器减少内存的列表推导？

### 3.3 装饰器使用

检测点：
- 是否过度装饰了一个函数？（5 层装饰器 → 难以调试）
- 是否用 `functools.wraps` 保持了原始函数的元数据？
- 装饰器是否有良好的文档？

### 3.4 数据类选择

| 库 | 何时用 |
|----|--------|
| `dataclass` | 简单的数据容器 |
| `NamedTuple` | 不可变数据 + 序列化 |
| `pydantic` | 需要运行时校验 + JSON Schema |
| `attrs` | 需要更多灵活性和性能 |

---

## 四、async/await 分析

### 4.1 异步使用检测

```bash
# 搜索可能的阻塞调用
grep -rn "time.sleep" --include="*.py"       # 在 async 上下文中 = 问题
grep -rn "requests\." --include="*.py"       # 应该用 aiohttp
grep -rn "def .*" --include="*.py" | grep "open\|read\|write"  # 同步 I/O
```

### 4.2 函数颜色问题

```python
# 坏：混用 sync 和 async，导致调用链断裂
async def handler():
    result = sync_db_query()  # ← 阻塞了整个事件循环！

# 好：全链路 async
async def handler():
    result = await async_db_query()
```

### 4.3 异步任务的正确使用

```python
# 坏: 没有 await 的 task → 异常被吞
async def bad():
    asyncio.create_task(do_something())  # task 可能挂掉而无人知道

# 好: task 有异常处理
async def good():
    task = asyncio.create_task(do_something())
    task.add_done_callback(handle_exception)
```

---

## 五、依赖管理

### 5.1 依赖文件

| 方式 | 评价 |
|------|------|
| `requirements.txt` | 基本可用，但缺少精确锁定 |
| `requirements.in` + `requirements.txt` (pip-tools) | ✅ 好 |
| `pyproject.toml` | ✅ 好（PEP 621） |
| `poetry.lock` | ✅ 好（Poetry 用户） |
| 无任何依赖文件 | ❌ 差 |

### 5.2 依赖版本

```txt
# 差：无版本约束
requests

# 可：最小版本
requests>=2.28

# 好：兼容版本范围
requests>=2.28,<3.0

# 最好：有 lock 文件确保精确复现
# (requirements.lock / poetry.lock / Pipfile.lock)
```

---

## 六、著名 Python 项目分析模式

### Django 项目

| 检测项 | 工具 |
|--------|------|
| App 拆分粒度 | 一个 app 是否职责单一？model 数量 > 10 应拆分 |
| Settings 模块化 | 是否有 `local.py` / `production.py` / `test.py`？ |
| ORM 查询效率 | `select_related` / `prefetch_related` 是否使用？N+1 问题？ |
| Middleware 链 | 顺序是否合理？是否过度使用？ |

### FastAPI 项目

| 检测项 | 工具 |
|--------|------|
| 依赖注入链 | `Depends()` 的使用是否清晰？是否有过长的注入链？ |
| Pydantic 模型 | 是否区分了 Request Schema 和 Response Schema？ |
| 路由组织 | 是否使用 `APIRouter` 拆分路由？ |
| 后台任务 | `BackgroundTasks` vs Celery 的选择是否合理？ |

### Python 库/CLI

| 检测项 | 工具 |
|--------|------|
| 入口点 | 是否定义了 `console_scripts` / `entry_points`？ |
| CLI 框架 | `click` / `typer` / `argparse` — 选择是否合理？ |
| `__main__.py` | 是否支持 `python -m mypackage`？ |
