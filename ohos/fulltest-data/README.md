# fulltest-data/ — 设备 fulltest 数据中心

> OHOS 真机 fulltest 的全部轮次数据、文件级台账与验收工具。

## 核心资产：文件级台账（持续更新）

| 文件 | 内容 |
|---|---|
| **[ohos-bun全量测试报告.md](ohos-bun全量测试报告.md)** | **2001 个测试文件 × A（brew bun 1.4.0_80 固定基线）/ B（最新轮）双轮结果 + 根因簇**（人类可读，按 14 个模块分类，每类内按 B 独有失败→两轮都失败→A 独有失败→通过 排序）。**看最新轮现状从这里开始** |
| **[ohos-bun全量测试报告.csv](ohos-bun全量测试报告.csv)** | 同上机器可读版（17 列，含类别/改动/skip/A/B 两轮用例数/失败集合/根因簇），**同时作为下一轮的谱系输入**（A 列自动携带） |
| [update-inventory.sh](update-inventory.sh) | **台账再生脚本**：新轮 log 回来后一条命令滚动更新台账，并同步产出 **log 口径三张清单**到 `<轮目录>/lists-log/`（fail_B / fail_B_only / fail_overlap_both，与 runner log 严格同源）。用法见文件头注释 |
| [archive/round-B-file-inventory-c4323a5d3.tar.gz](archive/round-B-file-inventory-c4323a5d3.tar.gz) | round B（c4323a5d3）22 列台账快照（**该轮唯一存活的逐文件记录**——原始数据目录已清理；含 A 列 2026-09-10 快照 + 根因簇谱系根，谱系已由现台账全量继承）。2026-09-21 归档 |

## 轮次数据

> **逐文件地面真相 = 各轮数据目录里的 runner log**（✅/❌/⏰ 2001 行）；
> 设备侧 `lists/` 三张清单系段落头提取，有超时漏报 + 嵌套 EXIT_CODE 假阳性，仅供对照
> （缺陷分析见 [../analys/20260917-round-report.md §2](../analys/20260917-round-report.md)）；
> **集合验收用 `lists-log/`**（update-inventory.sh 从 log 再生，2026-09-21 起提供）。

| 轮 | 数据/文档 | 说明 |
|---|---|---|
| **2026-09-17（最新）** | [615b48e95/](615b48e95/) | 615b48e95（#48）全量：log + 全量逐行报告 + 设备确认文档（含 3 轮隔离复跑补充节）+ lists/。1819/2001，fail 用例 931（98.65% 历史新高），独有 15（log 口径）= 8 慢性超时 + 3 verdaccio 轮转 + PARKED 1 + 待定性 2。**当前验收基准**。分析见 [../analys/20260917-round-report.md](../analys/20260917-round-report.md) |
| 2026-09-15 | [archive/round-G-3ac1bc4d8.tar.gz](archive/round-G-3ac1bc4d8.tar.gz) | 3ac1bc4d8（#43）全量 + rerun（**已归档**，原含两份确认文档、lists/、repro-logs；log = 该轮地面真相）。1830/2001，fail 用例 1052 |
| 2026-09-14 | [archive/round-D-14fdf0d56.tar.gz](archive/round-D-14fdf0d56.tar.gz) | 14fdf0d56（含 wave2 #34）复跑（**已归档压缩**，原 lists/：only 32 / overlap 160 / sys-only 23 + 全量报告）。分析：[../analys/archive/20260914-round-report.md](../analys/archive/20260914-round-report.md) |
| 2026-09-11 | [archive/round-C-0e0fd1559.tar.gz](archive/round-C-0e0fd1559.tar.gz) | 0e0fd1559（含 #30/#31/#32）复跑（**已归档压缩**，原 lists/：only 39 / overlap 149 / sys-only 34；大报告当时已删，lists 留档 修复演进中间点 101→39） |
| 2026-09-10 对比 | [compare-20260910-official-v140-sys-release-vs-jxbit-c4323a5d3.md](compare-20260910-official-v140-sys-release-vs-jxbit-c4323a5d3.md) | 官方树同测试树双 binary 对比（101 独有失败的定位轮） |
| 2026-09-08 对比 | [../analys/archive/compare-20260908-sys-release-vs-jxbit-46a905a6c.md](../analys/archive/compare-20260908-sys-release-vs-jxbit-46a905a6c.md) | fork 树口径（测试树双向漂移，结论仅部分适用；已归档） |
| 2026-09-07 容器验证 | [../analys/archive/container-verify-pr14-15-17-20260907.md](../analys/archive/container-verify-pr14-15-17-20260907.md) | pr14/15/17 的容器构建验证（已被 #45/#46 sysroot 治本取代；已归档） |

## 验收口径（2026-09-17 修订）

- **A 基线固定**：A 列永远是 brew `bun-sys-release 1.4.0_80` 的 2026-09-10 真机
  全量快照（185 失败），不随轮滚动；B 列 = 最新轮（当前 615b48e95，182 失败）。
- **收敛对象 = B-only-fail（当前 8 个）**：4 verdaccio 轮转（bun-audit/bun-update/
  frozen-lockfile-pruned/bun-add-catalog，隔离复跑全绿 = 环境压力）+ 2 慢性超时
  （26286/expo，见 chronic-timeout-registry）+ PARKED 1（bun-write）+
  轮转波动 1（child-process-exec，隔离复跑全绿已结案 2026-09-21）。
- **主口径**：runner log 逐文件行（✅/❌/⏰）。失败文件 = ❌ + ⏰（超时文件计入
  失败文件数，但其用例数不计量）；失败用例 = ❌ 文件的 `-N` 合计。
- 慢性固定集：12 个超时文件 G↔H 轮 11/12 相同，其中大部分与 A 基线共挂
  （both-fail，平台/环境边界），验收按"固定重灾清单"立册，不逐轮计回归。
- 参考基线：A 轮 sys-release 185 失败（device）；Linux x64 基线
  [linux-baseline-fails-official-v140.txt](linux-baseline-fails-official-v140.txt)
  （126 文件，区分「上游也有」vs「OHOS 特有」）。

## 数据保留策略（2026-09-21 定型）

> **fulltest-data/ 仅最新轮原目录存活；新轮数据解包回来、台账再生完成后，更早轮次一律归档。**

- **活资产（永不清理）**：`ohos-bun全量测试报告.csv/md`（A 基线列随台账滚动携带，
  历史轮目录的清理不影响 A 基线）、`lists-log/`、本 README、脚本。
- **轮目录生命周期**：解包 → 活跃（当前轮）→ 新轮到来后
  `./archive-round.sh <轮目录> <代号>` 归档。每轮分析结论必须先蒸馏进
  `analys/` 活跃文档再归档——归档丢的是原始明细，不是结论。
- **archive/ 命名**：`round-<代号>-<commit>.tar.gz`（B/C/D/G 已归档；F 轮
  007d7a07e 早于本策略且数据未留存，仅分析文档在案）。
- **流程挂钩**：新轮台账再生（update-inventory.sh）完成后立即执行归档一步。

## 工具

- [update-inventory.sh](update-inventory.sh) — 全量测试报告滚动更新（新轮 log 回来后一条命令再生，A 列自动携带）
- [verify-retest.ts](verify-retest.ts) — 新复跑结果 × 上一轮基线 lists 的自动对账：
  推导预期转绿集（基线独有 − PARKED）、标记未收敛项。用法见文件头注释
  （注意：基线文件名当前硬编码 `fail_0e0fd1559.txt`，换基线轮时需同步改）
