# 2026-09-14 轮次报告：14fdf0d56（wave2 后）× 官方 v1.4.0 套件

> **已被 [`../20260917-round-report.md`](../20260917-round-report.md)（G/H 轮）取代**，
> 本文为 round D 时点记录。

> 同测试树真机三轮演进（A = social4hyq 1.4.0_80 参考基线；B = 我方）。
> 数据：[`../../fulltest-data/archive/round-D-14fdf0d56.tar.gz`](../../fulltest-data/archive/round-D-14fdf0d56.tar.gz)
> （已归档压缩；lists/ 三张集合清单 + 全量逐行报告）。分析：2026-09-14。

## 1. 演进总览

| 轮 | 我方构建 | 独有失败 | overlap 基线 | 文件通过 | Duration |
|---|---|---:|---|---|---|
| 1（修复前） | c4323a5d3 | 101 | 146 | 1754/2001（87.66%） | 02:31:39 |
| 2（#30/#31/#32） | 0e0fd1559 | 39 | 149 | — | — |
| **3（+wave2 #34）** | **14fdf0d56** | **32** | 161 | **1808/2001（90.35%）** | **01:52:46** |
| 参考 A | 1.4.0+61dbc3a9d | 24 | 161 | 1816/2001（90.75%） | 02:00:58 |

- 用例 pass：68,371（轮 1）→ 本轮全量报告为逐行日志型，用例精确值待 junit round C
- 与参考 A 的差距：独有失败 32 vs 24、用例率差 ~0.4pp、时长已反超（01:52 vs 02:00）

## 2. 各修复的效果（文件级，精确）

| 修复 | 收复（文件） |
|---|---|
| #30 platform 双层 | sql 簇 30 + fs-birthtime 等 platform 门控（~46） |
| #31 bun-node shim | as-node（11 用例） |
| #32 F1 管道第一波 | shell mv/ls/file-io/yield、spawn-pipe-leak/signal、no-orphans、run-crash-handler、glob-on-fuse、run-file-on-fuse |
| #34 wave2（13 文件） | structured-clone ×2、html-rewriter、console-iterator、test-changed、bun-add-catalog、bun-audit、bun-pm-version、bun-update-lockfile-sync、isolated-relink、bun-inspector-protocol、update_interactive_formatting、spawn-stdin-readable-stream-integration |

## 3. 剩余 32 独有失败的分布

| 目录 | 数量 | 备注 |
|---|---:|---|
| `cli/install` | 10 | git-deps(5)、licenses(3)、run-bunfig、run、update-transitive、frozen-lockfile ×2、pnpm-lock-v9、publish 中属 overlap 的未计 |
| `js/bun` | 8 | serve-directory-routes（26 用例，F2 残留）+ shell ×5（exec/which/env.positionals/seq-condexpr/cmdsub-crash）+ io/bun-write + spawn-stdin-destroy |
| `cli/run` | 7 | multi-run、filter-workspace、run-quote、run-shell、shell-keepalive、workspaces、env |
| `regression/issue` | 3 | 22650-shell-crash、26207、26286 |
| `js/web` | 2 | structuredClone-classes、websocket-proxy 等（structured-clone 主文件已收复） |
| `cli/test`、`cli/inspect`、`cli/update_interactive`、`js/node`、`integration/expo` | 各 1 | 散布 |

## 4. 新增回归候选（6，本轮挂 / 上轮过）

`bun-publish`、`frozen-lockfile-missing-workspace`、`frozen-lockfile-pruned`、
`migration/pnpm-lock-v9`、`node-dns`、`inspect`
——疑似 wave2 改动（close_range 直呼 / $PWD 同步 / waiter-thread 默认）的连带，
需 junit 断言日志排查：确认是回归则出修复，是环境/噪音则归档。

## 5. 下一步（按收益）

1. **6 个回归候选排查**（上表）——回归不解决，逐轮缩小会停滞
2. **junit round C**：`ohos/_archive/run-all-official-junit.sh`（本地暂存）跑一轮——用例级从推断
   转精确，剩余 32 的文件内失败用例归位后定位不再靠猜
3. **cli/install 10 簇**：与 A 的 `src/install/` 差异对拍（PackageManager/
   PackageInstaller/npm.rs 等 14 文件 ~500 行，唯一未消化的大块）
4. **F2 残留**：serve-directory-routes 的 404 部分（"空 body" 已随 #32 缓解的
   部分待 junit 区分）——server 代码两树一致，需日志定性
