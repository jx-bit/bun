#!/usr/bin/env bash
# export-brew-prefix.sh — 把一台 harmonybrew 完好的机器上的整个前缀打成快照并上传，
# 供 GitHub 容器 lane 在 atomgit bottle 断供时恢复使用（20261012 事故的供应链加固）。
#
# 在哪里跑：任何 harmonybrew 前缀完好且已装 gh 的机器 —— 首选自托管 aarch64 runner
# （其前缀随增量 lane 的依赖装好，始终可复现）。
#
# 用法:  bash export-brew-prefix.sh [prefix路径] [tag]
#   prefix 默认 /storage/Users/currentUser/.harmonybrew（与 bottle ELF 的
#   PT_INTERP 一致，恢复进容器后路径不变）。
#   tag 默认 brew-prefix-snapshot（覆盖式更新到 jx-bit/bun 的同名 release）。
#
# 恢复侧（ohos-build-github.yml 的回退步骤）会把 tar 解到容器内同一路径，
# 之后 brew install 变成纯校验（全部已装，零下载）。
set -euo pipefail

PREFIX="${1:-/storage/Users/currentUser/.harmonybrew}"
TAG="${2:-brew-prefix-snapshot}"
REPO="${GITHUB_REPO:-jx-bit/bun}"

[ -d "$PREFIX" ] || { echo "前缀不存在: $PREFIX"; exit 1; }
command -v gh >/dev/null || { echo "需要 gh CLI（登录 jx-bit 账号）"; exit 1; }

OUT="$(mktemp -d)/brew-prefix.tar.zst"
echo "== 打包 $PREFIX ($(du -sh "$PREFIX" | cut -f1)) → zstd tar"
tar --zstd -cf "$OUT" -C "$(dirname "$PREFIX")" "$(basename "$PREFIX")"
echo "== 大小: $(du -sh "$OUT" | cut -f1)"

echo "== 上传到 $REPO 的 $TAG release（覆盖同名资产）=="
if gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  gh release delete-asset "$TAG" brew-prefix.tar.zst -R "$REPO" -y || true
else
  gh release create "$TAG" -R "$REPO" \
    -t "brew prefix snapshot" \
    -n "harmonybrew 前缀快照（Cellar + taps + Homebrew 本体）。容器 lane 在
atomgit bottle 断供时从此 release 恢复。生成时间: $(date -u '+%F %T UTC')" \
    --latest=false
fi
gh release upload "$TAG" "$OUT" -R "$REPO" --clobber
rm -f "$OUT"
echo "OK: 快照已上传。容器 lane 的回退步骤现在可以恢复了。"
