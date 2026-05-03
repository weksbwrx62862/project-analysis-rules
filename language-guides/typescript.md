# TypeScript 项目分析专项指南

> TypeScript 分析的核心不是看类型用得多花哨，而是看类型是否真的降低了 bug 率。

---

## 一、类型系统分析

### 1.1 `any` 使用频率

```bash
grep -rn ": any" --include="*.ts" --include="*.tsx" | wc -l
grep -rn "as any" --include="*.ts" --include="*.tsx" | wc -l
```

| any 占比 | 评价 |
|----------|------|
| < 1% of type annotations | 优秀 |
| 1-5% | 可接受（与第三方库交互时偶尔需要） |
| > 5% | 类型系统形同虚设 |

### 1.2 类型体操程度

好的类型体操 = 简单直观；过度的类型体操 = 理解成本高。

```typescript
// 好的类型体操（简单直观）
type Status = "pending" | "active" | "suspended";

// 过度的类型体操（理解成本过高）
type DeepPath<T, K extends keyof T> = K extends string
  ? T[K] extends object
    ? `${K}.${DeepPath<T[K], keyof T[K]>}`
    : K
  : never;
// 如果项目中充满这类类型而收益不高 → "类型体操爱好者"警告
```

### 1.3 类型守卫使用

```typescript
// 无类型守卫：类型收窄不够精确
function process(input: string | number) {
    if (typeof input === "string") {
        // 这里 TS 知道 input 是 string
    }
}

// 自定义类型守卫：更强
function isUser(obj: unknown): obj is User {
    return typeof obj === "object" && obj !== null && "id" in obj;
}

if (isUser(data)) {
    data.id; // TS 知道 data 是 User
}
```

### 1.4 TypeScript 4.9+ 新特性使用

- `satisfies` 关键字：是否使用了？（比 `as` 更安全）
- `const` 类型参数：`function foo<const T>(x: T)` 
- 新增内置工具类型：`Awaited`, `NonNullable`

---

## 二、运行时校验

### 2.1 类型系统的边界

> TypeScript 只在编译期有效，运行时完全是 JavaScript。API 边界必须做运行时校验。

```typescript
// ❌ 危险：假设 API 返回的类型是正确的
const data: User = await fetch("/api/user").then(r => r.json());
data.name.toUpperCase(); // 可能崩溃！

// ✅ 安全：运行时校验
const raw = await fetch("/api/user").then(r => r.json());
const data = UserSchema.parse(raw); // Zod / io-ts / yup
```

### 2.2 运行时校验库评估

| 库 | 何时用 |
|-----|--------|
| Zod | 最流行，和 TS 集成好，适合新项目 |
| io-ts | FP 风格，适合已有 fp-ts 的项目 |
| yup | 表单校验场景（和 Formik 配合好） |
| 无 | ❌ API 边界无校验 → 危险 |

---

## 三、模块系统

### 3.1 ESM vs CJS

```typescript
// ESM（推荐）
import { foo } from "./foo.js";

// CJS（老项目或需要兼容）
const { foo } = require("./foo");
```

判断：`package.json` 中是否有 `"type": "module"`？

### 3.2 Barrel Export 问题

```typescript
// index.ts — barrel export
export * from "./user";
export * from "./order";
export * from "./payment";

// ⚠️ 警告：
// 1. 是否导致了循环依赖？
// 2. 是否导致打包时 tree shaking 失效？
// 3. 是否导致了过大的模块图？
```

### 3.3 动态 Import

```typescript
// 好的使用：懒加载重型模块
const heavy = await import("./heavy-module");

// 过度使用：到处动态 import 让依赖变得不可追踪
```

---

## 四、React 专项

### 4.1 组件拆分

| 指标 | 好 | 可 | 差 |
|------|----|-----|----|
| 组件行数 | < 150 | 150-300 | > 300 |
| Props 数量 | < 5 | 5-8 | > 8 |
| 组件职责 | 一个职责 | 2 个 | 3+ 个 |

### 4.2 Hooks 设计

```typescript
// 好的自定义 Hook：抽象可复用逻辑
function useDebounce<T>(value: T, delay: number): T {
    const [debounced, setDebounced] = useState(value);
    useEffect(() => {
        const timer = setTimeout(() => setDebounced(value), delay);
        return () => clearTimeout(timer);
    }, [value, delay]);
    return debounced;
}

// 坏：Hook 只是一个函数的包装，没有封装任何状态
function useAdd(a: number, b: number) {
    return a + b; // 这只是 add() 函数，不需要是 Hook
}
```

### 4.3 useEffect 滥用检测

```typescript
// 坏：用 useEffect 做数据变换
function Component({ items }: Props) {
    const [filtered, setFiltered] = useState<Item[]>([]);
    useEffect(() => {
        setFiltered(items.filter(i => i.active));
    }, [items]);
    // 应该直接用 useMemo！
}

// 好：同步状态
const filtered = useMemo(() => items.filter(i => i.active), [items]);
```

### 4.4 状态管理选择

| 复杂度 | 推荐方案 |
|--------|----------|
| 组件内状态 | `useState` / `useReducer` |
| 子树内共享 | `Context` + `useReducer` |
| 服务端状态 | TanStack Query (React Query) / SWR |
| 全局客户端状态 | Zustand / Jotai |
| 复杂全局状态 | Redux Toolkit |

---

## 五、Node.js 专项

### 5.1 Stream 与背压

```typescript
// 坏：不处理背压
readable.on("data", (chunk) => {
    writable.write(chunk); // 如果 writable 满了，数据会堆积在内存
});

// 好：pipe 自动处理背压
readable.pipe(writable);
```

### 5.2 错误处理

```typescript
// 坏：忘记处理 Promise rejection
app.get("/api", async (req, res) => {
    const data = await fetchData(); // 如果抛异常，Express 不会自动捕获！
});

// 好：错误处理中间件或 wrapper
const asyncHandler = (fn: Function) => (req, res, next) =>
    Promise.resolve(fn(req, res, next)).catch(next);

app.get("/api", asyncHandler(async (req, res) => {
    const data = await fetchData();
}));
```

---

## 六、构建工具

### 6.1 构建选择评估

| 场景 | 推荐 | 检测 |
|------|------|------|
| 纯 TS 库 | tsup / unbuild | 构建速度是否合理？ |
| 前端应用 | Vite / Next.js | 开发体验是否良好？ |
| Monorepo | turborepo / nx / pnpm workspace | 是否有清晰的包依赖图？ |

---

## 七、常见 TypeScript 项目分析

### NestJS 项目

- Module 拆分是否合理？（一个 feature 一个 module）
- Provider 的注入层级是否过于嵌套？
- 是否区分了 DTO、Entity、Response 类型？

### Next.js 项目

- 是否合理使用了 Server Component vs Client Component？
- 数据获取是否正确（Server Component 中直接获取 vs Client 中 useEffect）？
- Route Handler 是否有运行时校验？
