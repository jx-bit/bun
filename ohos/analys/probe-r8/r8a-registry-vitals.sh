#!/usr/bin/env bash
# r8a-registry-vitals.sh — R8 决定性探针：verdaccio 宿主生命体征监测
# 用法(设备): bash r8a-registry-vitals.sh <test文件路径> [输出前缀]
#   例: bash r8a-registry-vitals.sh test/cli/install/isolated-install.test.ts r8a
# 机制: 后台看门狗每 2s 采样 verdaccio 进程(pid/存活/fd 数/RSS/线程数),
#       测试结束后输出时间线摘要 + dmesg OOM 尾部。
#       verdaccio 宿主 = 被测 binary(harness fork(execPath: bunExe()))——
#       换 binary 对照时切 PATH 即可(r8d)。
set -u

TARGET=${1:?用法: r8a-registry-vitals.sh <test文件> [前缀]}
PREFIX=${2:-r8a}
OUT="${PREFIX}-vitals.log"
VITALS="${PREFIX}-samples.tsv"

: > "$VITALS"

sample_once() {
  local ts=$(date +%H:%M:%S)
  for p in $(pgrep -f verdaccio 2>/dev/null); do
    local fds=$(ls /proc/$p/fd 2>/dev/null | wc -l)
    local rss=$(awk '/VmRSS/{print $2}' /proc/$p/status 2>/dev/null)
    local thr=$(awk '/Threads/{print $2}' /proc/$p/status 2>/dev/null)
    echo -e "$ts\tpid=$p\tfds=$fds\trss_kb=${rss:-DEAD}\tthreads=${thr:-?}" >> "$VITALS"
  done
  # 全部 verdaccio 消失时记录死讯
  [ -z "$(pgrep -f verdaccio 2>/dev/null)" ] && echo -e "$ts\tNO-VERDACCIO-PROCESS" >> "$VITALS"
}

echo "watchdog start $(date)" > "$OUT"
( while :; do sample_once; sleep 2; done ) &
WATCHDOG=$!

# 固化语义 env(同 launch-fulltest.sh 口径)
export BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1
export BUN_GARBAGE_COLLECTOR_LEVEL=0
export GITHUB_ACTIONS=false
export BUN_CONFIG_MAX_HTTP_REQUESTS=${BUN_CONFIG_MAX_HTTP_REQUESTS:-48}

bun test "$TARGET" > "${PREFIX}-test-output.log" 2>&1
RC=$?

kill $WATCHDOG 2>/dev/null
sleep 1

echo "watchdog end $(date), exit=$RC" >> "$OUT"
echo "=== 样本摘要 ===" >> "$OUT"
awk -F'\t' '!seen[$2]++ || $3 != prev {print; prev=$3}' "$VITALS" | tail -30 >> "$OUT"
echo "=== fd 峰值 ===" >> "$OUT"
grep -o 'fds=[0-9]*' "$VITALS" | sort -t= -k2 -rn | head -3 >> "$OUT"
echo "=== verdaccio 死讯 ===" >> "$OUT"
grep -c "NO-VERDACCIO" "$VITALS" >> "$OUT"
echo "=== dmesg OOM 尾部 ===" >> "$OUT"
dmesg 2>/dev/null | grep -iE "out of memory|oom.kill|oom_kill" | tail -10 >> "$OUT"
echo "完成: $OUT / $VITALS / ${PREFIX}-test-output.log (exit=$RC)"
