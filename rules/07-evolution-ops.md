# 演进与运维分析规则

> 一个项目是否"活着"，不看 star 数量，看它的交付和运维实践。

---

## 一、可观测性

### 1.1 三大支柱

| 支柱 | 作用 | 检测方法 |
|------|------|----------|
| **Logging** | 调试和审计 | 是否有结构化日志（JSON）？是否包含 trace_id/correlation_id？ |
| **Metrics** | 趋势和告警 | 是否有 RED（Rate/Error/Duration）指标？是否有 USE（Utilization/Saturation/Error）指标？ |
| **Tracing** | 请求全链路追踪 | 是否集成了 OpenTelemetry / Jaeger / Zipkin？ |

### 1.2 日志质量

```python
# 差：无结构化，无上下文
print("Error processing order")

# 可接受：用了 logging 但无结构化
logger.error("Error processing order %s", order_id)

# 好：结构化日志 + 完整上下文
logger.error("order_processing_failed",
    order_id=order_id,
    error_type="PaymentDeclined",
    duration_ms=230,
    trace_id="abc123"
)
```

### 1.3 关键路径可观测性

问自己：生产出问题时，只看日志能否：

- [ ] 确认请求确实到达了系统？
- [ ] 知道这条请求走了哪条路径？
- [ ] 定位在哪个环节失败的？
- [ ] 看到失败时的上下文（输入是什么？依赖服务返回了什么？）？
- [ ] 关联到同一 trace 的其他服务？

---

## 二、版本策略

### 2.1 语义化版本（SemVer）

```
v<MAJOR>.<MINOR>.<PATCH>

MAJOR: 不兼容的 API 修改
MINOR: 向后兼容的新功能
PATCH: 向后兼容的 bug 修复
```

检测：
- 版本号是否遵循 SemVer？（看 tag 历史）
- 是否有 `0.x` 版本？（0.x 不保证稳定性，是快速迭代的信号）
- `1.0` 是否已经发布？（标志着 API 稳定性承诺）

### 2.2 CHANGELOG 质量

好的 CHANGELOG：
```markdown
## [1.2.0] - 2024-06-15

### Added
- `UserService.export_data()` - 用户数据导出功能
- 支持 PostgreSQL 15

### Changed
- `AuthMiddleware` 默认使用 RS256 而非 HS256

### Deprecated
- `legacy_auth` 模块，将在 v2.0 移除，请迁移到 `auth`

### Fixed
- 修复大文件上传时的内存溢出问题 (#234)

### Security
- 修复 CVE-2024-XXXX 认证绕过漏洞
```

差的 CHANGELOG：
```markdown
## v1.2.0
- fix some bugs
- update dependencies
```

### 2.3 发布自动化

- 发布流程是否自动化？（GitHub Actions 自动构建 + 发布）
- Release notes 是否自动生成？
- 是否有发布检查清单？（manual step 可接受，但应该有文档）

---

## 三、迁移策略

### 3.1 数据库 Migration

```bash
# 检测
# - 是否有 migration 目录？（migrations/, alembic/, flyway/）
# - Migration 文件是否可回滚？（up + down / forward + reverse）
# - Migration 是否有编号/时间戳？（保证顺序性）
# - 是否在 CI 中自动运行 migration 测试？
```

好的 migration 实践：
```sql
-- 001_add_user_email.sql
-- Up
ALTER TABLE users ADD COLUMN email VARCHAR(255);
CREATE UNIQUE INDEX idx_users_email ON users(email);

-- Down
DROP INDEX IF EXISTS idx_users_email;
ALTER TABLE users DROP COLUMN email;
```

### 3.2 配置迁移

- 新增配置是否有默认值？（保证升级后立刻可用）
- 废弃的配置是否有过渡期？（先 ignore 再 warning 再 error）
- 配置结构变更是否有迁移脚本？

### 3.3 API 废弃时间表

```
发布 v1: API v1 上线
发布 v1.1: API v2 上线，v1 标记 @deprecated，触发 warning
发布 v2.0: v1 正式移除
          ^-------- 至少一个 minor 版本的过渡期 --------^
```

---

## 四、Feature Flag

### 4.1 合理的 Feature Flag 使用

```python
if feature_flag.is_enabled("new_checkout_flow", user_id=user.id):
    return new_checkout_service.checkout(cart)
else:
    return legacy_checkout_service.checkout(cart)
```

检测项：
- flag 的粒度：全局 / 按用户 / 按百分比 → 越精细越好
- flag 是否有清理机制？→ 没有清理 = 技术债务积累
- flag 默认值是什么？→ 新功能默认关（dark launch）
- 是否支持动态切换？→ 重启生效 vs 实时生效

### 4.2 Flag 债务警告

- 代码中是否有超过 3 个月的 feature flag？ → 可能已经可以清理
- 是否有嵌套 flag？（flag A 生效时 flag B 才检查）→ 复杂度爆炸

---

## 五、安全实践

### 5.1 依赖安全

- 是否有自动化依赖扫描？（Dependabot / Renovate / Snyk / pip-audit / npm audit）
- 依赖更新频率：每月 / 每季度 / 从不？
- 是否锁定了依赖版本？（lock 文件）
- 是否有已知 CVE 未修复？

### 5.2 敏感信息管理

- `.env` / `credentials.json` 是否在 `.gitignore` 中？
- 是否提供 `.env.example`（不含真实密钥）？
- CI/CD 中是否用 Secret 管理而不是硬编码？
- 日志是否可能泄露敏感信息？（密码、token、信用卡号）

### 5.3 安全披露

- 是否有 `SECURITY.md` 文件？
- 是否有安全漏洞报告渠道？（邮箱 / 私密 Issue）
- 是否有 CVE 发布历史？

### 5.4 输入校验

- 所有外部输入是否有校验？
  - HTTP 请求参数
  - 文件上传
  - WebSocket 消息
  - 环境变量
- 校验是在最外层（尽早）做的吗？

---

## 六、社区健康度

### 6.1 活跃度指标

```bash
# Issue 响应时间
# PR 合并速度
# 最近 commit 日期
# 贡献者数量变化趋势
git shortlog -sn --since="6 months ago"
```

### 6.2 贡献友好度

- 是否有 `CONTRIBUTING.md`？
- 是否有 `good first issue` 标签？
- 是否有开发环境搭建指南？
- PR 模板是否包含检查清单？
- 是否有 CODEOWNERS 文件？

---

## 七、GitNexus 辅助命令

```bash
# 搜索可观测性相关
gitnexus query "logging structured metrics tracing opentelemetry" --repo <名称>

# 搜索 migration
gitnexus query "migration schema change alter table" --repo <名称>

# 搜索敏感信息暴露风险
gitnexus query "password secret token api_key private_key" --repo <名称>

# 搜索 feature flag
gitnexus query "feature flag toggle experiment rollout" --repo <名称>
```

---

## 八、评分标准

| 维度 | 1分（差） | 2分（可接受） | 3分（好） | 4分（优秀） |
|------|----------|-------------|---------|-----------|
| 可观测性 | print 调试 | 基本 logging | 结构化日志 + Metrics | 全链路 Tracing + 告警联动 |
| 版本策略 | 版本号随意 | 有 tag 但无 CHANGELOG | SemVer + CHANGELOG | 全套 + 自动化发布 + 迁移指南 |
| Migration | 无 migration | 有 migration 但不可回滚 | 可回滚 migration | 自动化 migration + 回滚测试 |
| Feature Flag | 无 | 有但不清理 | flag + 清理机制 | 运行时动态 flag + 灰度 |
| 安全 | 无任何安全措施 | 基本防范 | 依赖扫描 + 输入校验 | CVE 响应 + SECURITY.md + 密钥管理 |
| 社区健康 | 无维护 | 偶有更新 | 活跃维护 | PR 快速, issue 有响应, 贡献者增长 |
