# P2: oven-sh/bun v1.4.0 合入 ohos-aarch64 — 工作记录

> **关联 PR**：[#2](https://github.com/jx-bit/bun/pull/2)
> **状态**：✅ 已合并（2026-08-28）

## 1. 做了什么

将 oven-sh/bun 的 `bun-v1.4.0` tag 合入 ohos-aarch64 分支，作为四方对账与
后续所有 OHOS 私有改动的基线版本。

## 2. 为什么只需简单记录

版本合并类操作，无独立问题行为；合并的逐 commit 对账与丢失文件分析
都有专用文档，本文件仅作 PR↔文档关联锚点。

## 3. 关联文档

- `analys/cherry-pick-tracker-v1.4.0.md` — 逐 commit 对账
- `analys/archive/four-files-lost-and-restored-explained.md` — 合并丢失与恢复的 4 文件
- `pr12-p1-test-tree-upstream-restore-and-reconcile.md` — 测试树对账
