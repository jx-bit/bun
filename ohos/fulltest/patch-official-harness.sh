#!/usr/bin/env bash
# patch-official-harness.sh — 给官方 v1.4.0 测试树补 openharmony harness 修复(A3-11)
#
# 背景: A/B 对比轮部署官方 v1.4.0 测试树(bun-official-v140),其 harness.ts 的
# libcPathForDlopen() 没有 case "openharmony" → default throw
# "unsupported platform openharmony"(真机 harness.ts:1853),7 个 FFI-mkfifo/
# raise 族文件两轮共挂。fork 树已由 PR #15 修复(musl loader 显式路径),
# 本脚本把同一修复以最小 patch 形式打到官方树。
#
# 用法(宿主机,打包 tar 之前):
#   bash ohos/fulltest/patch-official-harness.sh <官方测试树目录>
#   # 目录 = 官方 clone 的 test/(即打包用 tar czf ... -C test . 的那个目录)
#
# 幂等: 已打过的树直接跳过;非官方 v1.4.0 形态的树拒绝执行。
set -euo pipefail

TREE=${1:?用法: patch-official-harness.sh <官方测试树目录>}
PATCH_DIR="$(cd "$(dirname "$0")" && pwd)/patches"
PATCH="$PATCH_DIR/official-v140-harness-openharmony.patch"
H="$TREE/harness.ts"

[ -f "$H" ] || { echo "错误: $H 不存在 —— 参数应是 test/ 目录(含 harness.ts)"; exit 1; }
[ -f "$PATCH" ] || { echo "错误: patch 文件缺失: $PATCH"; exit 1; }

if grep -q 'case "openharmony"' "$H"; then
  echo "跳过: harness.ts 已含 openharmony case(已打过)。"
  exit 0
fi

# 官方 v1.4.0 形态校验: 必须命中 default throw 行(musl 分支为 /usr/lib/libc.so)
grep -q 'libcPathForDlopen: unsupported platform' "$H" \
  || { echo "错误: 不是官方形态的 harness.ts(无 default throw 行),拒绝打 patch。"; exit 1; }
grep -q 'return "/usr/lib/libc.so"' "$H" \
  || { echo "错误: musl 分支不是 /usr/lib/libc.so,非官方 v1.4.0 harness,拒绝。"; exit 1; }

# git apply(Git Bash 环境无独立 patch 二进制,git 必在)
( cd "$TREE" && git apply --check "$PATCH" ) \
  || { echo "错误: git apply --check 失败 —— 树与官方 v1.4.0 harness.ts 不一致。"; exit 1; }
( cd "$TREE" && git apply "$PATCH" )

# 打包前校验(同指导 §4.1 风格)
n=$(grep -c 'case "openharmony"' "$H")
[ "$n" -ge 1 ] || { echo "错误: patch 后未找到 openharmony case"; exit 1; }
grep -q 'ld-musl-aarch64.so.1' "$H" || { echo "错误: patch 后未找到 musl loader 路径"; exit 1; }
echo "OK: openharmony case 已注入 $H (case 数=$n)。现在按指导 §4.1 打包部署。"
