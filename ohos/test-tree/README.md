# test-tree/ — 测试树承载类问题档案

> **类别定义**：这类问题**不在 runtime / binary 侧修复** —— 修复面就是我们自己
> fork 树的 `test/`（harness、fixtures、expectations、参数适配）。特征：
> 上游测试树在 OHOS 设备上先天不适配，或平台测试基建缺失；修 binary 是错位的，
> 把适配随我们的测试树交付即可。
>
> 与其他目录的分工：
> - 本目录：**机制级案例档案**（每案一档：根因 → 为什么归测试树承载 → 交付状态），
>   只收"修的是测试文件/测试基建"的独立机制问题；
> - `knowledge/test-tree-changes-vs-v1-4-0.md`：测试树**全部改动**的台账
>   （121 文件，含大量参数适配/skip 门控，不逐案立档）；
> - `issues/`：对应 PR 的交付档案（本目录案例若走了 PR，交叉引用）。

## 案例索引

| 案例 | 机制 | 测试树修复 | 状态 |
|---|---|---|---|
| [a3-11-harness-libcpath-for-dlopen.md](a3-11-harness-libcpath-for-dlopen.md) | 官方树 harness `libcPathForDlopen()` 无 openharmony 分支 → FFI-mkfifo/raise 族 7 文件必挂 | PR #15：返回 musl loader 显式路径 | ✅ 已随我们树交付（2026-09-04） |

## 立档标准（什么进这里）

1. 失败根因在 `test/` 树内（harness/fixture/环境假设），修 binary 无意义；
2. 修复 = 我们测试树里的一处改动（随树交付，无独立 runtime PR）；
3. 机制足够独立、值得后人查（根因可复现于其他平台适配场景）。

同时满足三条 → 本目录一案一档；只是参数适配/skip 门控 → 记
`knowledge/test-tree-changes-vs-v1-4-0.md` 台账即可。

## 对比轮（官方树口径）的处理原则

A/B 对比轮部署官方 v1.4.0 树时，本类修复**天然不随行**（官方树无我们的改动），
两侧共挂属预期。处理顺序：

1. **优先**：若影响面大且可机械注入 → 用 `fulltest/patch-official-harness.sh`
   把同款修复打进官方树（两侧同树打同补丁，公平性不变）；
2. **兜底**：不注入时按"测试树承载类共挂"口径扣减，在轮报告标注归属本目录案例。

---
*目录建立：2026-09-21 | 首案：A3-11（从 R1 修复项重新定性）*
