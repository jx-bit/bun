# 20260914 确认：jx-bit 541794f8d 失败集复跑（第六次迭代）——F1 修复验证通过

> 续 `confirm-jxbit-007d7a07e-fullrun-20260914.md`。第七次构建，**任务 1（F1 子进程
> 输出捕获）修复落地并验证通过**。

## 构建验证

| 项 | 值 |
|---|---|
| --revision | **1.4.0-canary.1+541794f8d** |
| sha256 | `0f69b039190786b7ac4342f52ae8544d809a8daf892be304f6d556adeacd265a` |
| p6 非 quiet 冒烟 | ✅ **`AAA` 直通 + code 0**（前四轮 65507/空，本轮修复） |
| multi-run 冒烟 | ✅ **`a | AAA` / `b | BBB` 前缀转发恢复**（前四轮只有 Done 行） |
| platform / F3 | ✅ 保持 |

## 复跑结果（14fdf0d56 轮 193 个失败文件，单次口径）

| 结果 | 数量 |
|---|---|
| **转 PASS** | **33**（install 8、shell 7、cli/run 7 含 multi-run、regression 3、cli/test 2 等） |
| 仍 FAIL | 150 |
| 超时 | 10 |
| 崩溃 / OOM | 0 / 0 |

## jx-bit 独有失败收敛轨迹（vs sys-release 1.4.0_80）

| 迭代 | jxbit_only | 主要残留 |
|---|---|---|
| c4323a5d3 | 101 | platform/sql/F1 全部 |
| 0e0fd1559 | 39 | F1 + install |
| 14fdf0d56 | 32 | F1 + install |
| c2459c844 | 26（复跑） | F1 + install |
| **541794f8d** | **5** | 见下 |

## 剩余 5 个独有失败（全部非 F1）

| 文件 | 归因 |
|---|---|
| `js/bun/http/serve-directory-routes.test.ts` | **F2（serve 目录路由）仍未修**——merge 上游 1.4.0 的 serve 实现 |
| `cli/install/architecture-match.test.ts` | install 平台三元组细节 |
| `js/bun/io/bun-write.test.js` | io 细节 |
| `integration/expo-app/expo.test.ts` | 集成环境 |
| `regression/issue/26286.test.ts` | 单例回归 |

## 结论

1. **F1 修复验证通过**：`Bun.$` 非 quiet 直通、multi-run 前缀转发全部恢复（冒烟 + 33 文件复跑双重确认），65507 消失。
2. **jx-bit 独有失败收敛至 5 个**，与 sys-release 的差距只剩：F2（1 文件）+ 4 个散布例。
3. 剩余行动项：**F2（merge 上游 serve 目录路由）** 为最后一个成簇项；其余 4 个逐例归因。
4. 建议：跑一次全量轮获取精确用例率（预期 fail 用例从 1278 大幅回落、追平 99%+）。

## 数据

复跑日志：`/storage/Users/currentUser/opencode/repro-jxbit-r6/`；状态 `repro-status.txt`；
转 PASS 清单 `r6-pass.txt`（33）；修复后仍失败 `r6-still.txt`（160）、独有 `still_jxbit_only.txt`（5）。
