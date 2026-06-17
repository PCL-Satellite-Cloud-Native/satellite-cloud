#!/usr/bin/env bash
# 大更新后创建文档归档条目（复制模板并打开编辑）
# 用法：bash scripts/archive_docs_snapshot.sh phase1-closure "Phase 1 rs-worker 验收"
set -euo pipefail

SLUG="${1:?用法: archive_docs_snapshot.sh <slug> [标题]}"
TITLE="${2:-$SLUG}"
DATE="$(date +%Y-%m-%d)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_DIR="${REPO_ROOT}/docs/archives"
OUT="${ARCHIVE_DIR}/${DATE}_${SLUG}.md"
TEMPLATE="${ARCHIVE_DIR}/_TEMPLATE.md"
INDEX="${ARCHIVE_DIR}/ARCHIVE_INDEX.md"

if [[ -f "$OUT" ]]; then
  echo "已存在: $OUT"
  exit 1
fi

sed "s/<标题>/${TITLE}/; s/YYYY-MM-DD/${DATE}/; s/Phase N \/ …/${TITLE}/" "$TEMPLATE" > "$OUT"
echo "已创建: $OUT"
echo ""
echo "下一步："
echo "  1. 编辑 $OUT 填写验收数据"
echo "  2. 在 $INDEX 的「归档列表」增加一行"
echo "  3. 在 SSOT Runbook 附录加链接"
