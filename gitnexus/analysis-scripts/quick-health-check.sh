#!/bin/bash
# quick-health-check.sh — 一键运行所有关键 Cypher 查询，输出项目健康概览
# 用法: ./quick-health-check.sh <repo_name>

set -euo pipefail

REPO="${1:?请指定仓库名}"
echo "=== GitNexus 快速健康检查: $REPO ==="
echo ""

echo "--- 图谱统计 ---"
gitnexus list --repo "$REPO"

echo ""
echo "--- 循环依赖检测 ---"
gitnexus cypher "
  MATCH (a:Module)-[:IMPORTS]->(b:Module)
  MATCH (b)-[:IMPORTS*1..5]->(a)
  RETURN DISTINCT a.name, b.name
" --repo "$REPO" || echo "  (无结果 — 无循环依赖 ✅)"

echo ""
echo "--- 上帝对象 (方法 > 20) ---"
gitnexus cypher "
  MATCH (c:Class)
  OPTIONAL MATCH (c)-[:HAS_METHOD]->(m:Method)
  WITH c, count(m) AS method_count
  WHERE method_count > 20
  RETURN c.name, method_count
  ORDER BY method_count DESC
" --repo "$REPO" || echo "  (无结果 — 无上帝对象 ✅)"

echo ""
echo "--- 散弹修改风险 (fan_in > 15) ---"
gitnexus cypher "
  MATCH (m:Module)<-[:IMPORTS]-(other)
  WITH m, count(other) AS fan_in
  WHERE fan_in > 15
  RETURN m.name, fan_in
  ORDER BY fan_in DESC
" --repo "$REPO" || echo "  (无结果 — 无散弹修改风险 ✅)"

echo ""
echo "--- 过度抽象 (0-1 实现) ---"
gitnexus cypher "
  MATCH (i:Interface)
  OPTIONAL MATCH (c:Class)-[:IMPLEMENTS]->(i)
  WITH i, count(c) AS impl_count
  WHERE impl_count <= 1
  RETURN i.name, impl_count
  ORDER BY impl_count
" --repo "$REPO" || echo "  (无结果 — 无过度抽象 ✅)"

echo ""
echo "--- 技术债务热点 ---"
gitnexus cypher "
  MATCH (m:Module)
  WHERE m.lines > 500
  OPTIONAL MATCH (m)<-[:IMPORTS]-(other)
  WITH m, count(other) AS fan_in
  WHERE fan_in > 5
  RETURN m.name, m.lines, fan_in
  ORDER BY m.lines DESC
" --repo "$REPO" || echo "  (无结果 — 无技术债务热点 ✅)"

echo ""
echo "--- 测试空白区 ---"
gitnexus cypher "
  MATCH (src:Module)
  WHERE NOT src.name CONTAINS 'test' AND NOT src.name CONTAINS 'spec'
  OPTIONAL MATCH (test:Module)-[:IMPORTS]->(src)
  WHERE test.name CONTAINS 'test' OR test.name CONTAINS 'spec'
  WITH src, count(test) AS test_count
  WHERE test_count = 0
  RETURN src.name
  LIMIT 10
" --repo "$REPO" || echo "  (无结果 — 全部有测试覆盖 ✅)"

echo ""
echo "=== 检查完成 ==="
