#!/bin/bash
# OHOS PR 规则检查器——push 前必跑。用法：bash ohos/check-pr.sh [<branch>]
# 覆盖 ohos/README.md 硬性规则 1/3 与公开 PR 内容红线。
set -u
BASE=origin/ohos-aarch64
BR=${1:-$(git rev-parse --abbrev-ref HEAD)}
FAIL=0
say() { printf '%s %s\n' "$2" "$1"; }

git fetch $BASE >/dev/null 2>&1 || say "warn: fetch 失败，base 取本地缓存" "⚠"

# 规则1：单 commit
N=$(git rev-list --count $BASE..$BR 2>/dev/null || echo -1)
[ "$N" = "1" ] && say "单 commit（$N）" OK || { say "commit 数 = $N（须恰好 1）" FAIL; FAIL=1; }

# 规则1b：commit 只属于本 PR 的主题（列出供人工确认）
git log --oneline $BASE..$BR | sed 's/^/    commit: /'

# 规则3a：commit message 无 fork 名 / 内部报告名 / ohos 路径
if git log --format=%B $BASE..$BR | grep -qiE "social4hyq|harmonybrew|ohos/issues|_archive/|fulltest-data/|probes\.zip"; then
  say "commit message 含违禁引用" FAIL; FAIL=1
else say "commit message 无违禁引用" OK; fi

# 规则3b：diff 不含白名单外的 ohos/ 文件
# （ohos/ 自 2026-09-17 起分批入库——白名单随入库批次扩充：
#   README.md 首批（#47）、fulltest/ 第二批（#38）；
#   Cargo.lock 自 2026-09-21 起允许随交付 PR 携带）
OHOS_ALLOW='^ohos/(README\.md|fulltest/.*)$'
if git diff --name-only $BASE..$BR | grep -E "^ohos/" | grep -qvE "$OHOS_ALLOW"; then
  say "diff 含白名单外的 ohos/ 文件" FAIL; FAIL=1
else say "diff ohos/ 仅白名单（Cargo.lock 允许携带）" OK; fi

# 规则3c：PR body（若 gh 可用）无 fork 名 / ohos 引用
if command -v gh >/dev/null 2>&1; then
  BODY=$(gh api "repos/jx-bit/bun/pulls?head=jx-bit:$BR&state=open" --jq '.[0].body' 2>/dev/null || true)
  if [ -n "$BODY" ]; then
    # 已入库白名单文件可被 body 引用（先掩蔽再查剩余 ohos/ 引用）
    BODY_CHECK=$(printf '%s' "$BODY" | sed 's|ohos/README\.md|OHOS_README|g')
    if echo "$BODY_CHECK" | grep -qiE "social4hyq|ohos/|_archive/|fulltest-data/|probes\.zip"; then
      say "PR body 含违禁引用" FAIL; FAIL=1
    else say "PR body 无违禁引用" OK; fi
  else say "PR body 未取到（未创建或网络）" WARN; fi
fi

# base 新鲜度：HEAD 的 parent 是否包含 $BASE 的 tip（防过期基线带走别人的 commit）
TIP=$(git rev-parse $BASE)
git merge-base --is-ancestor $TIP $BR 2>/dev/null && say "base 含交付线 tip" OK || { say "base 落后交付线 tip（需 rebase）" WARN; }

[ $FAIL -eq 0 ] && echo "== PASS ==" || echo "== FAIL（$FAIL 项）=="
exit $FAIL
