#!/usr/bin/env bash
# r8b-lightload.sh — 负载塑形对照: BUN_CONFIG_MAX_HTTP_REQUESTS=4 vs 默认 48
# 假设: install 并发连接压垮 verdaccio 宿主(accept 队列/fd)。若 4 并发转绿/大幅
# 缓解 → 坐实负载机制,修复方向 = 并发上限适配或宿主 accept 加固。
# 用法(设备): bash r8b-lightload.sh <test文件>
set -u
TARGET=${1:?用法: r8b-lightload.sh <test文件>}

export BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1
export BUN_GARBAGE_COLLECTOR_LEVEL=0
export GITHUB_ACTIONS=false

echo "=== 默认并发(max_http_requests=${BUN_CONFIG_MAX_HTTP_REQUESTS:-48}) ==="
bun test "$TARGET" 2>&1 | grep -E "^ *[0-9]+ (pass|fail)"
echo "=== 低并发 BUN_CONFIG_MAX_HTTP_REQUESTS=4 ==="
BUN_CONFIG_MAX_HTTP_REQUESTS=4 bun test "$TARGET" 2>&1 | grep -E "^ *[0-9]+ (pass|fail)"
echo "判读: 低并发显著转绿 → 连接并发压垮宿主; 无差异 → 看r8a生命体征(死亡/OOM方向)"
