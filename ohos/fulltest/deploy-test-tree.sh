#!/usr/bin/env bash
# deploy-test-tree.sh — 把宿主机打好的测试树 tar 部署到鸿蒙设备
# 用法(宿主机 Git Bash): ./deploy-test-tree.sh <test-tree-<commit>.tar.gz> [DEVROOT]
# 逻辑:发 tar → 备份设备旧树(含 node_modules!)→ 解新树 → 挪回 node_modules → 清备份
# 详见新人指导 §4.2;部署完必须做 §4.4 完整性校验。

set -euo pipefail

TAR=${1:?用法: deploy-test-tree.sh <test-tree-<commit>.tar.gz> [DEVROOT]}
DEVROOT=${2:-/storage/media/100/local/files/Docs/Desktop/Linux}

[ -f "$TAR" ] || { echo "错误: tar 不存在: $TAR"; exit 1; }
BASE=$(basename "$TAR")

echo "[1/2] 发送 $BASE 到 $DEVROOT ..."
hdc file send "$TAR" "$DEVROOT/$BASE"

echo "[2/2] 设备侧解包(备份旧树 + 挪回 node_modules)..."
hdc shell "cd $DEVROOT && \
  if [ -d test ]; then mv test test-old-\$(date +%s) || { echo 'mv failed'; exit 1; }; fi && \
  mkdir -p test && tar xzf $BASE -C test && \
  _nm=\$(ls -d test-old-*/node_modules 2>/dev/null | head -1) && \
  if [ -n \"\$_nm\" ]; then \
    [ -e test/node_modules ] && rm -rf test/node_modules; \
    mv \"\$_nm\" test/node_modules; \
  fi && \
  rm -rf test-old-*"

echo "部署完成。node_modules 若是首次部署(设备无旧树),记得按指导 §4.3 在设备上安装;"
echo "并务必执行 §4.4 完整性校验(find 计数 + isOHOS/OPENHARMONY/esbuild/verdaccio)。"
