#!/usr/bin/env bash
# archive-round.sh — 历史轮数据归档
# 保留策略：fulltest-data/ 仅最新轮原目录存活；新轮台账再生后，旧轮一律归档到
# archive/round-<代号>-<commit>.tar.gz（证据链永续，分析结论已蒸馏进活跃文档）。
# 用法: ./archive-round.sh <轮目录名> <轮代号>
#   例: ./archive-round.sh 3ac1bc4d8 G
set -euo pipefail

DIR=${1:?用法: archive-round.sh <轮目录名> <轮代号>}
CODE=${2:?缺轮代号（如 B/C/D/G/H）}
[ -d "$DIR" ] || { echo "错误: $DIR 不存在"; exit 1; }
[ -d "$DIR" ] && [ "$DIR" = "archive" ] && { echo "错误: 不能归档 archive 自身"; exit 1; }

mkdir -p archive
OUT="archive/round-${CODE}-${DIR}.tar.gz"
tar czf "$OUT" "$DIR"

SRC_N=$(find "$DIR" ! -type d | wc -l)
TAR_N=$(tar -tzf "$OUT" | grep -v '/$' | wc -l)
[ "$SRC_N" -eq "$TAR_N" ] || { echo "错误: 条目数不符 src=$SRC_N tar=$TAR_N —— 保留原目录，检查 $OUT"; exit 1; }

rm -rf "$DIR"
echo "OK: $DIR → $OUT（$TAR_N 个文件，校验一致）。"
echo "后续: 更新 fulltest-data/README.md 轮次表该行为归档路径。"
