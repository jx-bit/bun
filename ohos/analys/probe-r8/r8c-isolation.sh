#!/usr/bin/env bash
# r8c-isolation.sh — 3 轮隔离复跑(G 轮补充节方法),验证确定性
# 用法(设备): bash r8c-isolation.sh "<文件1> <文件2> ..."
#   例: bash r8c-isolation.sh "test/cli/install/isolated-install.test.ts test/cli/install/bun-lock.test.ts"
set -u
FILES=${1:?用法: r8c-isolation.sh \"<空格分隔的文件列表>\"}

export BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1
export BUN_GARBAGE_COLLECTOR_LEVEL=0
export GITHUB_ACTIONS=false

for i in 1 2 3; do
  echo "=== 隔离复跑第 $i 轮 $(date +%H:%M:%S) ==="
  bun test $FILES 2>&1 | grep -E "^ *[0-9]+ (pass|fail)|Ran .* across"
done
echo "判读: 3 轮全绿 = 环境压力类; 稳定同量挂 = binary 内在(对照 r8a 生命体征)"
