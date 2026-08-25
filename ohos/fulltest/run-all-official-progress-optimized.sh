#!/bin/bash
# =============================================================================
# run-all-official-progress-optimized.sh — 优化版
#
# 相对原版的改进:
#   1. 移除 pkill 自伤问题（不再用 -f 匹配会命中自身的模式）
#   2. 进度刷新从 1s 降到 5-10s，减少 CPU 开销
#   3. 孤儿清理从"每文件一次"改为"每 30 文件 + 仅当孤儿 > 阈值"
#   4. 超长的 no-orphans test 加独立超时
# =============================================================================

# ── 核心参数（默认值已固化为安全值，调用方仍可 env 覆盖）──
BUN="${BUN:-bun}"
# PARALLEL 必须 2：设备无 swap，3 worker 同时抽中 handle-leak/fetch-leak/websocket 即 OOM 死锁
PARALLEL=${PARALLEL:-2}
# RETRIES=2（含首次共 3 次尝试）。文档与默认统一为 2，跨轮次对比需同值
RETRIES=${RETRIES:-2}
TMOUT=${TMOUT:-300}
TMOUT_BUNDLER=${TMOUT_BUNDLER:-900}
BUN_TIMEOUT=${BUN_TIMEOUT:-300000}

# ── 测试语义 flag（无默认则调用方漏设会导致结果失真，这里兜底）──
# BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING：启用测试用内部 flag，缺失则部分用例行为不同
: "${BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING:=1}"
# BUN_GARBAGE_COLLECTOR_LEVEL=0 解锁 VirtualMachine.rs 嵌套 gate，让 bun:internal-for-testing
# 在 release binary 可解析（顶层 bun test 进程需此 env，harness.ts:94 仅给子进程设）。
# =0 不触发 aggressive GC。详见 launch-fulltest.sh 注释。
: "${BUN_GARBAGE_COLLECTOR_LEVEL:=0}"
# GITHUB_ACTIONS=false：避免触发 GHA 专属断言（CI=1 但非真 GHA 环境）
: "${GITHUB_ACTIONS:=false}"
: "${CI:=1}"
: "${BUN_DEBUG_QUIET_LOGS:=1}"
: "${NO_COLOR:=1}"
# 设备 root 但 /root 不存在 → HOME 指向可写目录（与上游 CI 一致）
# launcher 已设 HOME；此处仅兜底直接跑 runner 的场景（cwd 即测试工作目录）
if [ ! -d "${HOME:-}" ] 2>/dev/null; then
  mkdir -p ./home
  export HOME="$PWD/home"
fi
export BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING GITHUB_ACTIONS CI BUN_DEBUG_QUIET_LOGS NO_COLOR BUN_GARBAGE_COLLECTOR_LEVEL

# 孤儿清理 — 用 PID 白名单避免自伤
# BUN_PROC_PATTERN: pgrep -f 匹配模式，用于孤儿清理。
# media 域 binary 名 bun-aclass；currentUser 域用 bun-github。launcher 可覆盖。
: "${BUN_PROC_PATTERN:=bun-aclass}"
_ohos_kill_orphans() {
  local _pid _my_pids _sig
  _my_pids="$$ $PPID $BASHPID"
  for _sig in TERM KILL; do
    for _pid in $(pgrep -f "$BUN_PROC_PATTERN" 2>/dev/null || true); do
      case " $_my_pids " in *" $_pid "*) continue;; esac
      kill -$_sig "$_pid" 2>/dev/null || true
    done
    sleep 1
  done
}

# sleep 孤儿扫荡 — sleep 数量超过 并行数×2 时才动手
# 正常情况下每个测试配一个 watchdog sleep，多余的是残留
_ohos_sweep_orphans() {
  local _max_sleep _sleep_count _pid _age _my_pids
  _max_sleep=$((PARALLEL * 2))
  _sleep_count=$(ps -ef 2>/dev/null | grep ' sleep ' | grep -v grep | wc -l)
  # sleep 数在合理范围内 → 跳过
  [ "$_sleep_count" -le "$_max_sleep" ] 2>/dev/null && return 0

  _my_pids="$$ $PPID $BASHPID"
  for _pid in $(pgrep -x "sleep" 2>/dev/null || true); do
    case " $_my_pids " in *" $_pid "*) continue;; esac
    _age=$(ps -o etimes= -p "$_pid" 2>/dev/null || echo 0)
    # 只杀 >30min 的 sleep（正常 watchdog 不会活那么久）
    [ "${_age:-0}" -gt 1800 ] 2>/dev/null && kill -9 "$_pid" 2>/dev/null || true
  done
}

cleanup() {
  local kids
  kids=$(jobs -p 2>/dev/null)
  [ -n "$kids" ] && kill $kids 2>/dev/null
  _ohos_kill_orphans
  [ -n "$PDIR" ] && [ -d "$PDIR" ] && rm -rf "$PDIR"
}
trap cleanup EXIT INT TERM

# ── 前置清理 ──
_ohos_kill_orphans

TS=$(date +%Y%m%d_%H%M%S)
REPORT="all-official-report-${TS}.txt"
_BASE_TMP="${TMPDIR:-/tmp}"
PDIR="${_BASE_TMP}/bun_test_progress_$$"
START_SECONDS=$SECONDS

# ── 依赖检查 ──
{
echo "========== All Official Tests (optimized) =========="
echo "Bun: $($BUN --version 2>/dev/null)"
echo "Date: $(date)"
echo "Parallel: $PARALLEL | Timeout: ${TMOUT}s (bundler: ${TMOUT_BUNDLER}s) | Retries: ${RETRIES}"
echo ""
} | tee "$REPORT" >/dev/null

mkdir -p "$PDIR"

find test/ -type f \
  \( -name "*.test.ts" -o -name "*.test.js" -o -name "*.test.tsx" -o -name "*.test.jsx" \
     -o -name "*.spec.ts" -o -name "*.spec.tsx" -o -name "*.spec.js" -o -name "*.spec.jsx" -o -name "*.spec.cjs" \
     -o -name "*.test.mjs" -o -name "*.test.cjs" -o -name "*.spec.mjs" \
     -o -name "*.test.mts" -o -name "*.spec.mts" -o -name "*.test.cts" -o -name "*.spec.cts" \) \
  ! -path "*/node_modules/*" ! -name "*fuzzy-wuzzy*" \
  ! -path "*/fixtures/*" ! -path "*/snapshots/*" ! -path "*/node-napi-tests/*" \
  | sort > "$PDIR/test_files.txt"

# ── 可选: 测试文件过滤（device-test-from-ci.sh --test-filter 传入）──
# TEST_FILTER 是 grep -E 正则，匹配 test_files.txt 中的路径子串
# 例: TEST_FILTER='test/cli/install/' 只跑 install 类
if [ -n "${TEST_FILTER:-}" ]; then
  grep -E "$TEST_FILTER" "$PDIR/test_files.txt" > "$PDIR/test_files.tmp" || true
  mv "$PDIR/test_files.tmp" "$PDIR/test_files.txt"
  echo "Applied TEST_FILTER='$TEST_FILTER' → $(wc -l < "$PDIR/test_files.txt") files" | tee -a "$REPORT"
fi

# ── 排除 expectations.txt 中标记为 [ OPENHARMONY ] [ Skip ] 的测试 ──
# 与 social4hyq 的 runner.node.mjs getRelevantTests() 行为一致：
# skip 类的测试在运行前直接移除；flaky/failure 类保留运行（计入结果）
if [ -z "${SKIP_EXPECTATIONS:-}" ] && [ -f test/expectations.txt ]; then
  _excluded=0
  while IFS= read -r _line; do
    case "$_line" in
      *"[ OPENHARMONY ]"*"[ Skip ]"*)
        _skip_file=$(echo "$_line" | awk '{print $4}')
        if [ -n "$_skip_file" ]; then
          if grep -qxF "$_skip_file" "$PDIR/test_files.txt" 2>/dev/null; then
            grep -vxF "$_skip_file" "$PDIR/test_files.txt" > "$PDIR/test_files.tmp"
            mv "$PDIR/test_files.tmp" "$PDIR/test_files.txt"
            _excluded=$((_excluded + 1))
          fi
        fi
        ;;
    esac
  done < test/expectations.txt
  if [ "$_excluded" -gt 0 ]; then
    echo "Excluded $_excluded [OPENHARMONY] skip files → $(wc -l < "$PDIR/test_files.txt") files remain" | tee -a "$REPORT"
  fi
fi

TOTAL_FILES=$(wc -l < "$PDIR/test_files.txt")
echo "Found $TOTAL_FILES test files, running $PARALLEL parallel workers (TIMEOUT=${TMOUT}s, RETRIES=${RETRIES})"
echo "Found $TOTAL_FILES test files" >> "$REPORT"
echo "" >> "$REPORT"

# ── 运行单个测试 ──
run_test() {
  idx=$1
  f=$2
  case "$f" in
    */bundler/*)
      WT=${TMOUT_BUNDLER}
      BT="--timeout ${BUN_TIMEOUT}"
      ;;
    *bake/dev/*)
      WT=60
      BT="--timeout 60000"
      ;;
    *)
      WT=${TMOUT}
      BT="--timeout ${BUN_TIMEOUT}"
      ;;
  esac

  echo "$f" > "$PDIR/running_${idx}"
  START_TS=$(date +%s%N)

  attempt=1
  max_attempts=$((RETRIES + 1))
  while [ $attempt -le $max_attempts ]; do
    out="$PDIR/out_${idx}_a${attempt}.tmp"
    # Run bun in its own process group (setsid) so we can kill the whole
    # tree (bun + verdaccio + fixture servers + child shells) on timeout.
    # Manual PGID kill is more reliable than `timeout` which only kills the
    # direct child and leaks grandchildren (caused 27 leaked procs at file 152).
    setsid $BUN test $BT "./$f" > "$out" 2>&1 &
    BUNPID=$!
    PGID=$BUNPID
    # Watchdog: kill the entire process group after $WT seconds
    (
      sleep $WT
      kill -TERM -$PGID 2>/dev/null
      sleep 3
      kill -KILL -$PGID 2>/dev/null
    ) &
    WDOG=$!
    wait $BUNPID 2>/dev/null
    EXIT=$?
    # Kill watchdog + entire bun process group (cleanup grandchildren)
    pkill -P $WDOG 2>/dev/null
    kill -KILL $WDOG 2>/dev/null
    kill -KILL -$PGID 2>/dev/null
    # 注：不再用全局 `pkill -f "bun-aclass test"`——它会杀掉并行的兄弟 worker
    # （其命令行同样含 "bun-aclass test"），导致兄弟 worker 被误判超时。
    # PGID kill 已清理本进程组的所有子孙，无需全局清理。
    wait $WDOG 2>/dev/null

    # 区分超时与崩溃（原版把所有非 0/1 都当超时，掩盖了 SIGABRT/SIGSEGV 等崩溃）
    # 124=GNU timeout, 137=SIGKILL, 143=SIGTERM（watchdog 用 kill -TERM/-KILL 触发→真超时）
    # 134=SIGABRT, 139=SIGSEGV, 其他非 0/1 → 崩溃（crash），保留已采集的 pass/fail
    TIMEOUT=0
    CRASH=0
    if [ $EXIT -eq 124 ] || [ $EXIT -eq 137 ] || [ $EXIT -eq 143 ]; then
      TIMEOUT=1
    elif [ $EXIT -ne 0 ] && [ $EXIT -ne 1 ]; then
      CRASH=1
    fi

    if [ $EXIT -eq 0 ] || [ $EXIT -eq 1 ]; then
      LAST_OUT="$out"
      break
    fi

    if [ $attempt -lt $max_attempts ]; then
      { echo "[$idx/$TOTAL_FILES] $f [attempt #$((attempt+1))]"; cat "$out"; } >> "$REPORT"
      rm -f "$out"
      attempt=$((attempt + 1))
    else
      LAST_OUT="$out"
      break
    fi
  done

  [ $EXIT -eq 0 ] && FILE_RESULT="PASS" || FILE_RESULT="FAIL"

  CASE_PASS=0; CASE_FAIL=0
  if [ -f "$LAST_OUT" ]; then
    pass_line=$(grep -a -E '^ +[0-9]+ pass' "$LAST_OUT" | head -1)
    [ -n "$pass_line" ] && CASE_PASS=$(echo "$pass_line" | awk '{print $1+0}')
    fail_line=$(grep -a -E '^ +[0-9]+ fail' "$LAST_OUT" | head -1)
    [ -n "$fail_line" ] && CASE_FAIL=$(echo "$fail_line" | awk '{print $1+0}')
  fi

  # 仅超时文件丢弃用例数（-1）；崩溃文件保留已采集的 partial pass/fail，
  # 否则 SIGABRT/SIGSEGV 的用例被剔出分母会人为抬高用例率
  [ $TIMEOUT -eq 1 ] && CASE_PASS=-1 && CASE_FAIL=-1

  cat "$LAST_OUT" > "$PDIR/out_${idx}.txt"
  echo "EXIT_CODE:$EXIT" >> "$PDIR/out_${idx}.txt"
  rm -f "$LAST_OUT"

  END_TS=$(date +%s%N)
  DURATION_MS=$(( (END_TS - START_TS) / 1000000 ))
  {
    echo "FILE=$f"
    echo "RESULT=$FILE_RESULT"
    echo "EXIT_CODE=$EXIT"
    echo "CASE_PASS=$CASE_PASS"
    echo "CASE_FAIL=$CASE_FAIL"
    echo "DURATION_MS=$DURATION_MS"
    echo "TIMEOUT=$TIMEOUT"
    echo "CRASH=$CRASH"
  } > "$PDIR/result_${idx}.tmp"
  mv "$PDIR/result_${idx}.tmp" "$PDIR/result_${idx}"
  rm -f "$PDIR/running_${idx}"
}

# ── 进度显示（5-10s 刷新，减少 CPU） ──
show_progress() {
  local completed passed failed case_pass case_fail elapsed pct
  local running_list last_completed no_progress_start

  no_progress_start=0; last_completed=0
  while true; do
    completed=0; passed=0; failed=0; case_pass=0; case_fail=0
    running_list=""

    for res_file in "$PDIR"/result_*; do
      [ -f "$res_file" ] || continue
      # 跳过半写的 .tmp（mv 前的窗口期可能被 glob 命中）
      case "$res_file" in *.tmp) continue;; esac
      completed=$((completed + 1))
      file_result=; file_case_pass=; file_case_fail=; file_timeout=
      while IFS='=' read -r key val; do
        case "$key" in
          RESULT)   file_result=$val ;;
          CASE_PASS) file_case_pass=$val ;;
          CASE_FAIL) file_case_fail=$val ;;
          TIMEOUT)  file_timeout=$val ;;
        esac
      done < "$res_file"
      [ "$file_result" = "PASS" ] && passed=$((passed + 1)) || failed=$((failed + 1))
      if [ "$file_timeout" != "1" ]; then
        # 崩溃文件 case 可能为 -1（旧字段兼容）/0/partial，跳过负值
        [ -n "$file_case_pass" ] && [ "$file_case_pass" -ge 0 ] 2>/dev/null && case_pass=$((case_pass + file_case_pass))
        [ -n "$file_case_fail" ] && [ "$file_case_fail" -ge 0 ] 2>/dev/null && case_fail=$((case_fail + file_case_fail))
      fi
    done

    first=1
    for run_file in "$PDIR"/running_*; do
      [ -f "$run_file" ] || continue
      read -r rl < "$run_file"
      if [ $first -eq 1 ]; then running_list="$rl"; first=0; else running_list="$running_list | $rl"; fi
    done
    [ ${#running_list} -gt 80 ] && running_list="${running_list:0:77}..."

    elapsed=$(( SECONDS - START_SECONDS ))
    elapsed_fmt=$(printf '%02d:%02d:%02d' $((elapsed/3600)) $(( (elapsed%3600)/60 )) $((elapsed%60)))
    pct=0; [ $TOTAL_FILES -gt 0 ] && pct=$(( completed * 100 / TOTAL_FILES ))

    printf "\r\033[K[%s] Files: %d/%d (%d%%) | ✅ %d | ❌ %d | Cases: +%d/-%d | ▶ %s" \
      "$elapsed_fmt" "$completed" "$TOTAL_FILES" "$pct" \
      "$passed" "$failed" "$case_pass" "$case_fail" "$running_list"

    [ "$completed" -ge "$TOTAL_FILES" ] && break

    if [ "$completed" -eq "$last_completed" ]; then
      [ "$no_progress_start" -eq 0 ] && no_progress_start=$SECONDS
    else
      no_progress_start=0
    fi
    last_completed=$completed
    if [ "$no_progress_start" -ne 0 ] && [ $((SECONDS - no_progress_start)) -gt 900 ]; then
      echo ""; echo "[WARN] show_progress: no new results for 15 minutes, exiting"; break
    fi

    # 自适应刷新: 前100个文件 5s, 之后 10s
    if [ "$completed" -gt 500 ]; then sleep 10
    elif [ "$completed" -gt 100 ]; then sleep 7
    else sleep 5
    fi
  done

  echo
  echo ""
  echo "── Per-file results ──"
  for i in $(seq 1 $TOTAL_FILES); do
    res_file="$PDIR/result_${i}"
    [ -f "$res_file" ] || continue
    file_result=$(grep -a '^RESULT=' "$res_file" | cut -d= -f2)
    file_duration=$(grep -a '^DURATION_MS=' "$res_file" | cut -d= -f2)
    file_timeout=$(grep -a '^TIMEOUT=' "$res_file" | cut -d= -f2)
    file_crash=$(grep -a '^CRASH=' "$res_file" | cut -d= -f2)
    file_case_pass=$(grep -a '^CASE_PASS=' "$res_file" | cut -d= -f2)
    file_case_fail=$(grep -a '^CASE_FAIL=' "$res_file" | cut -d= -f2)
    file_path=$(grep -a '^FILE=' "$res_file" | cut -d= -f2-)

    if [ -n "$file_duration" ] && [ "$file_duration" -gt 0 ]; then
      dur_fmt="$((file_duration / 1000)).$(( (file_duration % 1000) / 100 ))s"
    else
      dur_fmt="?"
    fi

    if [ "$file_timeout" = "1" ]; then icon="⏰"; result_str="TIMEOUT"
    elif [ "$file_crash" = "1" ]; then icon="💥"; result_str="CRASH"
    elif [ "$file_result" = "PASS" ]; then icon="✅"; result_str="PASS"
    else icon="❌"; result_str="FAIL"; fi

    echo "  $icon [$i/$TOTAL_FILES] $result_str ${dur_fmt} $file_path (cases: +${file_case_pass}/-${file_case_fail})"
  done
}

echo "Progress updates every 5-10s."
echo ""

show_progress &
STATUS_PID=$!

# 孤儿扫荡 — 每 30 个文件跑一次
_ohos_orphan_count=0
i=1
while IFS= read -r f; do
  run_test "$i" "$f" &
  i=$((i+1))

  _ohos_orphan_count=$((_ohos_orphan_count + 1))
  if [ "$_ohos_orphan_count" -ge 30 ]; then
    _ohos_sweep_orphans
    _ohos_orphan_count=0
  fi

  while true; do
    running_count=0
    for _f in "$PDIR"/running_*; do [ -f "$_f" ] && running_count=$((running_count + 1)); done
    [ "$running_count" -lt "$PARALLEL" ] && break
    sleep 0.5
  done
done < "$PDIR/test_files.txt"

wait
wait $STATUS_PID 2>/dev/null
kill $STATUS_PID 2>/dev/null

# ── 汇总 ──
PASS=0; FAIL=0; TOTAL=0; CASE_PASS=0; CASE_FAIL=0; TIMEOUT_COUNT=0; CRASH_COUNT=0
i=1
while [ "$i" -le "$TOTAL_FILES" ]; do
  res_file="$PDIR/result_${i}"
  out_file="$PDIR/out_${i}.txt"
  if [ -f "$res_file" ] && [ -f "$out_file" ]; then
    TOTAL=$((TOTAL+1))
    ec=$(tail -1 "$out_file" | grep -o 'EXIT_CODE:[0-9]*' | cut -d: -f2)
    # 保留 EXIT_CODE 行写入 REPORT（不用 sed '$d' 删除）—— §7.4 崩溃诊断依赖它
    # grep EXIT_CODE:134/139 才能在 REPORT 中匹配到。ec 提取用 tail -1 不受保留影响。
    cat "$out_file" >> "$REPORT"
    file_result=$(grep '^RESULT=' "$res_file" | cut -d= -f2)
    file_case_pass=$(grep '^CASE_PASS=' "$res_file" | cut -d= -f2)
    file_case_fail=$(grep '^CASE_FAIL=' "$res_file" | cut -d= -f2)
    file_timeout=$(grep '^TIMEOUT=' "$res_file" | cut -d= -f2)
    file_crash=$(grep '^CRASH=' "$res_file" | cut -d= -f2)
    [ "$ec" = "0" ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
    [ "$file_timeout" = "1" ] && TIMEOUT_COUNT=$((TIMEOUT_COUNT+1))
    [ "$file_crash" = "1" ] && CRASH_COUNT=$((CRASH_COUNT+1))
    [ -n "$file_case_pass" ] && [ "$file_case_pass" -ge 0 ] && CASE_PASS=$((CASE_PASS + file_case_pass))
    [ -n "$file_case_fail" ] && [ "$file_case_fail" -ge 0 ] && CASE_FAIL=$((CASE_FAIL + file_case_fail))
  fi
  i=$((i+1))
done

elapsed=$(( SECONDS - START_SECONDS ))
elapsed_fmt=$(printf '%02d:%02d:%02d' $((elapsed/3600)) $(( (elapsed%3600)/60 )) $((elapsed%60)))
{
echo ""
echo "════════════════════════════════════════════════════"
echo "  Duration: $elapsed_fmt"
echo "  Files:    $TOTAL total | $PASS passed | $FAIL failed"
echo "  Cases:    $CASE_PASS passed | $CASE_FAIL failed"
echo "  Timeouts: $TIMEOUT_COUNT | Crashes: $CRASH_COUNT"
echo "════════════════════════════════════════════════════"
echo "Report: $REPORT"
} | tee -a "$REPORT"

echo ""
echo "════════════════════════════════════════════════════"
echo "  Duration: $elapsed_fmt  Files: $TOTAL  ✅ $PASS  ❌ $FAIL  Cases: +$CASE_PASS/-$CASE_FAIL  ⏰ $TIMEOUT_COUNT  💥 $CRASH_COUNT"
echo "════════════════════════════════════════════════════"

[ "$FAIL" -eq 0 ] || exit 1
