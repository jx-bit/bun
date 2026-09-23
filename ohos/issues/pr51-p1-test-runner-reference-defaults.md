# P1: bun test 默认超时 30s 偏离上游契约 + honest-cwd 调用点丢失
> **关联 PR**：[#51](https://github.com/jx-bit/bun/pull/51)（commit ada3dfd10e，含 Cargo.lock 归位）

> R8 第三成员 `bun-test.test.ts`（官方树口径 1/0 文件级失败，G/H 稳定）归因命中
> 两处确定差异，均恢复为与参考树逐字节一致：

## 0. 失败证据（H 轮日志逐行）

**用例 1**：`--timeout > timeout should default to 5000ms`

```
error: expect(received).toHaveTestTimedOutAfter(expected)
Expected to contain "timed out after "
Received: "bun-test-....test.ts:
(pass) timeout [5502.69ms]
 1 pass / 0 fail / Ran 1 test across 1 file. [5.54s]"
```

sleep 型子测试 5.5s **完成并通过**而未被 5s 默认超时击杀 → 实际默认值不是 5s。

**用例 2**：`test file discovery (scanner) > entries whose absolute path exceeds
MAX_PATH_BYTES are skipped`

```
Expected to contain: "Ran 1 test across 1 file."
Received: "... Ran 1 test across 3 files."
```

两个超限 fixture 未被 walk 跳过而是被发现执行。
> 1. `TestOptions::default()` 默认每用例超时 **30s**（`target_env="ohos"` 门控）
>    —— 早期落地提交 d576713d37c 的 ASan 慢构建时代产物。前提已失效（现构建非
>    插桩），且偏离上游**文档化契约 5000ms**：官方树 `--timeout > timeout should
>    default to 5000ms` 确定性失败（子测试 5.5s 完成而未被 5s 击杀，H 轮日志实证）。
> 2. `Arguments.rs` 的 `absolute_working_dir` 预解析丢失 `getcwd_honest()` 调用点
>    （上游 merge 6692a5d5b1b 冲掉了 pr42 家族的 BUG-01 修复；resolver 处调用点
>    尚存）—— shim 的 getcwd() 拦截器会把已删除 cwd 静默替换为 $HOME，
>    `bun test` 会扫真实 $HOME，并使 file discovery 基路径漂移
>    （scanner MAX_PATH 跳过用例 3-files-vs-1 失败的候选解释，待真机复核）。

---

## 1. 与参考实现（61dbc3a9d 交付树）的对比

**结论先行：两处均逐字节恢复，无实现差异。**

| 项 | 参考树 | 我方树（修复前） | 修复后 |
|---|---|---|---|
| 默认每用例超时 | `5 * 1000`（无门控） | `#[cfg(target_env="ohos")] 30 * 1000` | `5 * 1000`（逐字节） |
| absolute_working_dir | `getcwd_honest` + 说明注释 | plain `getcwd` | `getcwd_honest`（逐字节） |

溯源：30s 门 = d576713d37c（2026-07-27 早期落地 4/7，动机为 ASan 插桩慢构建——
前提已过时）；honest-cwd 丢失 = 上游 merge 6692a5d5b1b 冲掉 61dbc3a9d7d 交付的
hunk（resolver 侧同家族调用点未丢，仅 Arguments 处丢失）。
证据类型：〔源码〕`git diff 61dbc3a9d -- <file>` 修复后 = 0 行。

## 2. 30s 门为何必须退场（分类讨论）

- **用户可见契约**：`bun test` 默认超时 5000ms 是文档化行为；平台门控让 OHOS
  构建对外行为与其他平台不同 —— 这不是"测试树承载"，而是 binary 公开行为偏离，
  官方树一致性测试正抓此类偏离。
- **原动机失效**：ASan 插桩构建已是历史；当前交付构建无插桩。
- **若慢设备抖动复现**：正确机制是我们自己测试树的显式 per-test/per-file 超时
  （台账参数适配既有做法），不是改 runner 全局默认。

## 3. 验证

- 静态：`cargo check -p bun_runtime -p bun_options_types` / clippy / fmt 全过；
  两文件与参考树 diff = 0。
- 真机（下轮 fulltest）：`bun-test.test.ts` 的 timeout 契约用例应转绿；
  **未修复构建上确定性失败**（5.5s 子测试必然通过 5s 边界而不被击杀）。
- scanner MAX_PATH 用例为候选解释修复（honest-cwd 恢复），若下轮仍挂则单独立案。

## 3.1 Cargo.lock 随本 PR 携带（2026-09-21 策略变更）

- 内容：`ohos_sign` 依赖条目按字母序归位（bun_install/bun_runtime 依赖表内
  移动 + 包块位置），**无版本变化、无依赖集合变化**——纯本地 cargo 运行的
  规范化产物。
- 动机：本地 cargo check/clippy 每次运行都会重新归位并弄脏工作区（"老产生
  影响"）；随交付 PR 提交一次后树保持干净。
- 守卫同步：check-pr.sh 规则 3b 的 Cargo.lock FAIL 分支移除（本目录 README
  "新增 issue 操作要点"第 1 条涉及 Cargo.lock 的旧口径随之作废）。

## 4. 关联

- 归因全景：[`../analys/20260921-remaining-issues.md`](../analys/20260921-remaining-issues.md) §10.4（R8）
- 同族先例：pr42（cwd/rlimit/tmpdir 加固）、pr49（同基线逐字移植方法论）

---
*立档：2026-09-21 | 分析者：Sisyphus | 依据：H 轮日志取证 + 排除法 diff + d576713d37c/6692a5d5b1b 溯源*
