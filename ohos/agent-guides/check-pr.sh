#!/bin/bash
# OHOS PR 规则检查器（通用版）——push 前必跑。
#
# 用途：校验当前分支相对 base 的 PR 是否满足 OHOS 交付门禁：
#   规则1   相对 base 恰好一个 commit
#   规则1b  列出 commit 供人工确认主题归属
#   规则3a  commit message 无违禁引用（fork 名 / 内部报告名 / 内部路径，列表可配置）
#   规则3b  diff 不携带 $OHOS_DIR/ 下白名单（可配置）之外的文件
#   规则3c  PR body（若 gh 可用）无违禁引用
#   base 新鲜度：HEAD 的祖先链包含 base 的 tip（防过期基线带走别人的 commit）
#
# 用法：bash ohos/agent-guides/check-pr.sh [<branch> [<base>]]
#   <branch>  待检查分支，默认当前分支
#   <base>    base 分支名（不含 origin/ 前缀），默认 $CHECK_PR_BASE，再默认 main
#
# 环境变量（全部可选）：
#   CHECK_PR_BASE       base 分支名，默认 main（也可用第 2 个位置参数覆盖）
#   CHECK_PR_REPO       GitHub 仓库 "owner/repo"，默认从 remote.origin.url 自动推导
#   CHECK_PR_FORBIDDEN  违禁引用正则（用 | 分隔，如 "internal-repo-name|internal-path"），默认空 = 不检查
#   CHECK_PR_ALLOWLIST  $OHOS_DIR/ 下允许携带的路径正则，默认空 = $OHOS_DIR/ 一律禁止携带
#   OHOS_DIR            内部交付目录名，默认 ohos
set -u

BASE_BRANCH=${2:-${CHECK_PR_BASE:-main}}
BASE="origin/$BASE_BRANCH"
BR=${1:-$(git rev-parse --abbrev-ref HEAD)}
FAIL=0
say() { printf '%s %s\n' "$2" "$1"; }

# GitHub 仓库 owner/repo：优先 CHECK_PR_REPO，否则从 remote.origin.url 推导
# （支持 https://github.com/owner/repo.git 与 git@github.com:owner/repo.git）
URL=$(git config --get remote.origin.url)
REPO=${CHECK_PR_REPO:-$(printf '%s' "$URL" | sed -E 's#^(https?://[^/]+/|git@[^:]+:|[^:/]+:)?([^/]+/[^/]+)(\.git)?$#\2#')}
OWNER=${REPO%%/*}
REPO_NAME=${REPO##*/}

# 违禁引用列表（CHECK_PR_FORBIDDEN，| 分隔；空 = 不检查）
FORBIDDEN=${CHECK_PR_FORBIDDEN:-}
# diff 白名单（CHECK_PR_ALLOWLIST，$OHOS_DIR/ 下允许携带的路径正则；空 = 全部禁止）
OHOS_ALLOW=${CHECK_PR_ALLOWLIST:-}
OHOS_DIR=${OHOS_DIR:-ohos}

git fetch $BASE >/dev/null 2>&1 || say "warn: fetch 失败，base 取本地缓存" "⚠"

# 规则1：单 commit
N=$(git rev-list --count $BASE..$BR 2>/dev/null || echo -1)
[ "$N" = "1" ] && say "单 commit（$N）" OK || { say "commit 数 = $N（须恰好 1）" FAIL; FAIL=1; }

# 规则1b：commit 只属于本 PR 的主题（列出供人工确认）
git log --oneline $BASE..$BR | sed 's/^/    commit: /'

# 规则3a：commit message 无违禁引用
if [ -n "$FORBIDDEN" ] && git log --format=%B $BASE..$BR | grep -qiE "$FORBIDDEN"; then
  say "commit message 含违禁引用" FAIL; FAIL=1
else say "commit message 无违禁引用" OK; fi

# 规则3b：diff 不含 $OHOS_DIR/ 下白名单外的文件
# （白名单随入库批次扩充，用 CHECK_PR_ALLOWLIST 配置；空 = $OHOS_DIR/ 一律禁止携带）
if [ -n "$OHOS_ALLOW" ] && git diff --name-only $BASE..$BR | grep -E "^$OHOS_DIR/" | grep -qvE "$OHOS_ALLOW"; then
  say "diff 含白名单外的 $OHOS_DIR/ 文件" FAIL; FAIL=1
else say "diff $OHOS_DIR/ 均在白名单内" OK; fi

# 规则3c：PR body（若 gh 可用）无违禁引用（已入库白名单文件可被 body 引用，先掩蔽）
if command -v gh >/dev/null 2>&1; then
  BODY=$(gh api "repos/$REPO/pulls?head=$OWNER:$BR&state=open" --jq '.[0].body' 2>/dev/null || true)
  if [ -n "$BODY" ]; then
    BODY_CHECK=$(printf '%s' "$BODY" | sed "s|$OHOS_DIR/README\.md|OHOS_README|g")
    BODY_PATTERN="${FORBIDDEN:+$FORBIDDEN|}$OHOS_DIR/"
    if echo "$BODY_CHECK" | grep -qiE "$BODY_PATTERN"; then
      say "PR body 含违禁引用" FAIL; FAIL=1
    else say "PR body 无违禁引用" OK; fi
  else say "PR body 未取到（未创建或网络）" WARN; fi
fi

# base 新鲜度：HEAD 的祖先链是否包含 $BASE 的 tip（防过期基线带走别人的 commit）
TIP=$(git rev-parse $BASE 2>/dev/null)
if [ -n "$TIP" ] && git merge-base --is-ancestor $TIP $BR 2>/dev/null; then
  say "base 含交付线 tip" OK
else say "base 落后交付线 tip（需 rebase）" WARN; fi

[ $FAIL -eq 0 ] && echo "== PASS ==" || echo "== FAIL（$FAIL 项）=="
exit $FAIL
