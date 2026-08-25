#!/bin/sh
# Minimal launcher for OHOS bun test — sh-compatible (no bash required)
# Equivalent to launch-fulltest.sh but avoids bash-only features
set -e

DEVROOT="/storage/media/100/local/files/Docs/Desktop/Linux"
export BUN="$DEVROOT/bun-aclass"
export PARALLEL=2
export RETRIES=2
export TMOUT=300
export TMOUT_BUNDLER=900
export BUN_TIMEOUT=300000
export BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1
# BUN_GARBAGE_COLLECTOR_LEVEL=0 解锁 VirtualMachine.rs 中嵌套在 GARBAGE_COLLECTOR_LEVEL
# 块内的 INTERNAL_FOR_TESTING gate（与 harness.ts:94 `|| "0"` + 上游 ci.ts 一致）。
# =0 不触发 aggressive GC（仅 "1"/"2" 才触发），只让 bun:internal-for-testing 可解析。
export BUN_GARBAGE_COLLECTOR_LEVEL=0
export BUN_DEBUG_QUIET_LOGS=1
export NO_COLOR=1
export CI=1
export GITHUB_ACTIONS=false
# 设备 root 用户但 /root 不存在 → 任何写 $HOME（缓存/.bun/配置）必失败。
# 设到可写目录（与上游 CI 一致用临时 HOME）。
mkdir -p "$DEVROOT/home"
export HOME="$DEVROOT/home"

# Pre-flight checks
[ -x "$BUN" ] || { echo "ERROR: binary $BUN not found or not executable"; exit 1; }
[ -d "$DEVROOT/test" ] || { echo "ERROR: test tree not found at $DEVROOT/test"; exit 1; }
[ -f "$DEVROOT/run-all-official-progress-optimized.sh" ] || { echo "ERROR: runner not found"; exit 1; }

echo "=== OHOS Full Test (sh launcher) ==="
echo "Binary:  $($BUN --version 2>/dev/null)"
echo "Tree:    $(find $DEVROOT/test/ -type f -name '*.test.ts' ! -path '*/node_modules/*' 2>/dev/null | wc -l) test files"
echo "Env:     PARALLEL=$PARALLEL RETRIES=$RETRIES CI=$CI"
echo "===================================="

cd "$DEVROOT"
exec sh run-all-official-progress-optimized.sh
