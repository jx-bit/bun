#!/bin/bash
# =============================================================================
# launch-fulltest.sh — OHOS Bun 全量测试启动器
#
# 作用：固化测试 env（PARALLEL/RETRIES/语义 flag），避免调用方漏设导致结果失真。
# 对应 SKILL.md §6.1/§6.2。runner 脚本内部也有相同默认值兜底，本文件为单一事实源。
#
# 用法（设备 media 域，宿主机 run_in_background 跑 hdc shell）：
#   setsid bash launch-fulltest.sh > result_fulltest_<ts>.txt 2>&1 &
#
# 注意：必须用 bash（runner 用 $BASHPID / ${var:offset:len} 等 bash 语法，sh 会崩）。
#       OHOS 上 bash 通常在 /data/service/hnp/bin，若 PATH 不含需先用绝对路径。
# =============================================================================

set -euo pipefail

DEVROOT=/storage/media/100/local/files/Docs/Desktop/Linux
cd "$DEVROOT" || { echo "ERROR: DEVROOT $DEVROOT not found"; exit 1; }

# ── 被测 binary ──
# 默认 bun-aclass；允许 env 覆盖（A/B 测试可指向 bun-aclass-github / bun-aclass-self 等）
# 注意：若改用非 bun-aclass 名，runner 的 pgrep -f "bun-aclass" 孤儿清理需同步调整匹配模式
export BUN="${BUN:-$DEVROOT/bun-aclass}"

# ── 并发 / 重试 / 超时（与 SKILL.md §6.1 一致，勿随意改）──
# PARALLEL=2：设备无 swap，3 worker 同时抽中 handle-leak/fetch-leak/websocket 即 OOM 死锁
export PARALLEL=2
# RETRIES=2（含首次共 3 次）。跨轮次对比需同值
export RETRIES=2
export TMOUT=300
export TMOUT_BUNDLER=900
export BUN_TIMEOUT=300000

# ── 测试语义 flag（漏设会导致结果失真）──
# 启用测试用内部 flag，缺失则部分用例行为不同
export BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1
# BUN_GARBAGE_COLLECTOR_LEVEL=0 解锁 VirtualMachine.rs 中嵌套在 GARBAGE_COLLECTOR_LEVEL
# 块内的 INTERNAL_FOR_TESTING gate（与 harness.ts:94 `|| "0"` + 上游 ci.ts 一致）。
# =0 不触发 aggressive GC（仅 "1"/"2" 才触发），只让 bun:internal-for-testing 可解析。
# 缺失时顶层 `bun test` 进程 import "bun:internal-for-testing" 报 ENOENT（~181 fail）。
export BUN_GARBAGE_COLLECTOR_LEVEL=0
# 避免 GHA 专属断言（CI=1 但非真 GHA 环境）
export GITHUB_ACTIONS=false
export CI=1
export BUN_DEBUG_QUIET_LOGS=1
export NO_COLOR=1

# 设备 root 用户但 /root 不存在 → 写 $HOME 的操作（缓存/.bun/配置）必失败。
# 设到可写目录（与上游 CI 一致用临时 HOME）。
mkdir -p "$DEVROOT/home"
export HOME="$DEVROOT/home"

# ── 前置校验 ──
[ -x "$BUN" ] || { echo "ERROR: binary $BUN 不存在或不可执行（先 chmod 755 / 部署）"; exit 1; }
[ -f run-all-official-progress-optimized.sh ] || { echo "ERROR: runner 脚本不在 $DEVROOT"; exit 1; }
[ -f test/harness.ts ] || { echo "ERROR: 测试树 test/ 不存在（先部署，见 SKILL.md §4）"; exit 1; }
if ! ls test/node_modules/esbuild >/dev/null 2>&1; then
  echo "WARN: test/node_modules/esbuild 缺失 — bundler/bake/dev 整段会假回归（见 SKILL.md §4.3）"
fi

echo "=== OHOS Bun full test suite ==="
echo "Bun:     $($BUN --version 2>/dev/null)"
echo "Date:    $(date)"
echo "Tree:    $(find test/ -type f \( -name '*.test.ts' -o -name '*.test.js' -o -name '*.test.tsx' -o -name '*.test.jsx' -o -name '*.spec.ts' -o -name '*.spec.tsx' -o -name '*.spec.js' -o -name '*.spec.jsx' -o -name '*.spec.cjs' -o -name '*.test.mjs' -o -name '*.test.cjs' -o -name '*.spec.mjs' -o -name '*.test.mts' -o -name '*.spec.mts' -o -name '*.test.cts' -o -name '*.spec.cts' \) ! -path '*/node_modules/*' 2>/dev/null | wc -l) test files (pre-exclude)"
echo "Env:     PARALLEL=$PARALLEL RETRIES=$RETRIES GITHUB_ACTIONS=$GITHUB_ACTIONS BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=$BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING"
echo ""

# exec 让 runner 直接接管本进程（减少一层，stdout/stderr 由调用方重定向捕获）
exec bash run-all-official-progress-optimized.sh
