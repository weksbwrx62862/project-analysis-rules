#!/bin/bash
# generate-report-data.sh — 生成分析报告所需的所有结构化数据
# 用法: ./generate-report-data.sh <repo_name> > report-data.txt

set -euo pipefail

REPO="${1:?请指定仓库名}"
echo "=========================================="
echo " 项目分析数据: $REPO"
echo " 生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

echo "### 图谱统计 ###"
gitnexus list --repo "$REPO"
echo ""

echo "### 代码统计 ###"
cloc . 2>/dev/null || echo "  (cloc 未安装，跳过)"
echo ""

echo "### 贡献者分布 ###"
git shortlog -sn --all | head -15
echo ""

echo "### 被依赖排行 Top 10 ###"
gitnexus cypher "
  MATCH (m:Module)<-[:IMPORTS]-(other)
  WHERE NOT m.name CONTAINS 'test'
  RETURN m.name, count(other) AS importers
  ORDER BY importers DESC LIMIT 10
" --repo "$REPO"
echo ""

echo "### 大文件排行 Top 10 ###"
gitnexus cypher "
  MATCH (m:Module)
  RETURN m.name, m.lines
  ORDER BY m.lines DESC LIMIT 10
" --repo "$REPO"
echo ""

echo "### 依赖深度 Top 10 ###"
gitnexus cypher "
  MATCH path = (a:Module)-[:IMPORTS*1..10]->(b:Module)
  WITH a, max(length(path)) AS max_depth
  RETURN a.name, max_depth
  ORDER BY max_depth DESC LIMIT 10
" --repo "$REPO"
echo ""

echo "### 反模式扫描 ###"
echo "--- 循环依赖 ---"
gitnexus cypher "
  MATCH (a:Module)-[:IMPORTS]->(b:Module)
  MATCH (b)-[:IMPORTS*1..5]->(a)
  RETURN DISTINCT a.name, b.name
" --repo "$REPO" || echo "  无"
echo ""

echo "--- 上帝对象 (方法>20) ---"
gitnexus cypher "
  MATCH (c:Class)
  OPTIONAL MATCH (c)-[:HAS_METHOD]->(m:Method)
  WITH c, count(m) AS method_count
  WHERE method_count > 20
  RETURN c.name, method_count
  ORDER BY method_count DESC
" --repo "$REPO" || echo "  无"
echo ""

echo "--- 过度抽象 (0-1实现) ---"
gitnexus cypher "
  MATCH (i:Interface)
  OPTIONAL MATCH (c:Class)-[:IMPLEMENTS]->(i)
  WITH i, count(c) AS impl_count
  WHERE impl_count <= 1
  RETURN i.name, impl_count
" --repo "$REPO" || echo "  无"
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
" --repo "$REPO" || echo "  无"
echo ""

echo "--- 测试空白区 ---"
gitnexus cypher "
  MATCH (src:Module)
  WHERE NOT src.name CONTAINS 'test'
  OPTIONAL MATCH (test:Module)-[:IMPORTS]->(src)
  WHERE test.name CONTAINS 'test' OR test.name CONTAINS 'spec'
  WITH src, count(test) AS test_count
  WHERE test_count = 0
  RETURN src.name
  LIMIT 20
" --repo "$REPO" || echo "  无"
echo ""

echo "=========================================="
echo " 数据生成完成"
echo "=========================================="
