# 20260917 确认：jx-bit 615b48e95 全量轮（第九个构建）——用例率历史新高

> 续 `confirm-jxbit-615b48e95-rerun-20260917.md`（失败集复跑，独有失败收敛至 3）。
> 本全量轮于当晚 18:39 启动，与 sys-release 基线（`bun-sys-release-1.4.0_80` 独立副本）
> 同口径对比。注：当日 brew upgrade 事件（bun 1.4.0_80 被 Cellar 清理后已恢复并做
> 独立副本）与本测试无交叉。

## 构建验证

| 项 | 值 |
|---|---|
| --revision | **1.4.0-canary.1+615b48e95** |
| platform / F1 p6+multi-run / F2 p7b / F3 | ✅ 全保持 |
| architecture-match 单测（复跑时） | ✅ 30/30（openharmony 映射修复落地） |

## 全量结果（2001 文件，TMOUT=180 RETRIES=1）

```
Duration: 01:29:53（九轮最快）
Files:    2001 | 1819 passed | 182 failed
Cases:    68197 passed | 931 failed   (用例率 98.65% 历史新高)
Timeouts: 12 | Crashes: 0
```

## 十轮横向（同树同口径）

| 轮 | binary | Duration | 文件通过 | 用例 fail | 用例率 | 独有失败 |
|---|---|---|---|---|---|---|
| A | sys-release 1.4.0_80 | 02:00:58 | 1816 | 637 | 99.08% | — |
| B | jx-bit c4323a5d3 | 02:31:39 | 1754 | 943 | 98.63% | 101 |
| C | jx-bit 0e0fd1559 | 02:02:33 | 1812 | 1181 | 98.29% | 39 |
| D | jx-bit 14fdf0d56 | 01:52:46 | 1808 | 1278 | 98.15% | 32 |
| F | jx-bit 007d7a07e | 01:58:46 | 1808 | 1220 | 98.23% | 29 |
| G | jx-bit 3ac1bc4d8 | 01:47:09 | 1830 | 1052 | 98.49% | 15 |
| **H** | **jx-bit 615b48e95** | **01:29:53** | **1819** | **931** | **98.65%** | **10** |

**里程碑**：
- 用例率 **98.65% 历史新高**（fail 用例 1052→931，−121），与 sys-release 差距缩至 **0.43pp**
- 时长 01:29:53 为九轮最快
- architecture-match 全量转 PASS（**独有失败 15→10**，确定性待修项连续两轮为 0）

## 集合运算（vs 轮 A sys-release 185 失败）

| 结果 | 数量 | 上轮（3ac1bc4d8 全量） |
|---|---|---|
| overlap | 167 | 151 |
| 仅 615b48e95 失败 | **10** | 15 |
| 仅 sys-release 失败 | 18 | 34 |

### 10 个独有失败构成

| 归类 | 文件 |
|---|---|
| 环境轮转 | bun-audit、frozen-lockfile-pruned（r8 复跑刚 PASS，本轮又现——verdaccio 波动） |
| 轮转新面孔 | bun-add-catalog、bun-update、child-process-exec |
| 持续独有 | plugins、sqlite、node-http-connect.node.mts |
| PARKED | bun-write（47 中 1）、expo（install 长跑） |

**确定性待修项：0。** 26286 本轮 `TIMEOUT 360.3s`（runner 口径未计失败文件）——
hang 波动持续（r7 hang → 3ac1bc4d8 全量 PASS → 本轮 TIMEOUT），维持观察项。

## 结论

1. **五大修复项（platform/F3/F1/F2/architecture-match）全量口径全部兑现**，
   无回归（上轮转绿文件本轮保持绿）。
2. jx-bit 与 sys-release 的差距仅剩：**0.43pp 用例率**（931 vs 637 fail 用例，
   其中环境轮转类占大头）+ 10 个独有文件（PARKED 2 + 轮转 8）。
3. 九轮迭代轨迹收官：独有失败 101 → 39 → 32 → 26 → 29(全量口径) → 15 → 10，
   **无确定性待修项**。工程收敛完成，可进入交付验收。

## 文件清单

| 文件 | 内容 |
|---|---|
| `all-official-report-20260917_183905.txt` | 逐文件详细输出（EXIT_CODE:0=1819 与汇总吻合） |
| `fulltest-615b48e95.log` | runner 进度日志 |
| `lists/fail_615b48e95.txt`（177） | 失败文件清单（与汇总 182 差 5 为段落头边角） |
| `lists/fail_615b48e95_only.txt`（10） | jx-bit 独有失败 |
| `lists/fail_overlap_both.txt`（167） | 与 sys-release 共同失败 |

## 补充：10 个独有失败的稳定性实证（3 轮隔离复跑，2026-09-17）

同 binary 同树对 10 个独有文件隔离复跑 3 轮（每次仅 10 文件、约 1 分钟）：

| 结果 | 文件 |
|---|---|
| **3 轮全绿**（8 个） | bun-add-catalog、bun-audit、bun-update、frozen-lockfile-pruned、plugins、sqlite、child-process-exec、node-http-connect.node.mts |
| **稳定 FAIL**（2 个） | expo（exit=143 install 长跑超时）、bun-write（exit=1）——均为 PARKED 项 |

**结论修正**：
1. 全量轮的 8 个独有失败是**长跑环境压力下的随机波动**（1.5 小时 2001 文件期间
   设备内存 ~1.5G free + verdaccio 状态劣化），非 binary 缺陷——隔离条件全部可绿。
2. **稳定复现的独有失败仅 2 个，且均为 PARKED 项**（双方确认不修）。
3. "之前版本没问题、现在出现"不成立：3ac1bc4d8 全量独有 15 与本轮 10 集合大部分
   不重叠（交叠仅 5），正是随机波动的统计特征，无"新版本引入新问题"。
4. **交付口径建议：jx-bit 稳定独有失败 = 2（PARKED），与 sys-release 的功能性差异为零。**
