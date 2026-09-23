# P1: browser-field 禁用入口导致 bun build panic — 工作记录

> **关联 PR**：[#28](https://github.com/jx-bit/bun/pull/28)（claude 分支 → ohos-aarch64，单 commit `ffa13fe522`）
> **状态**：🔄 OPEN
> **定位**：20260908 轮（jxbit binary 46a905a6c）两处 SIGABRT 崩溃的根因修复 —— P1 唯一确认的真回归。

## 1. 现象

20260908 轮两个文件 SIGABRT（exit 134），且 panic 经 `bun build` 子进程扩散：

- `test/bundler/bundler_edgecase.test.ts`
- `test/js/node/crypto/x509.test.ts`（其 fixture 经 `bun build --target=browser` 触发）

```
panic: index out of bounds: the len is 0 but the index is 0
```

复现日志：`20260908_fulltest_jxbit/diagnostics/repro_edgecase.log`（数据集已清理，复现结论见本档 §2）

## 2. 机制

package.json `browser` 字段禁用入口点（`"./entry.js": false`）时：

1. 我们的 `resolve_entry_point` 返回 `Ok(resolved)` 且 `path_const() == None`
   （无守卫）；
2. 无路径 entry 流入 bundler 图（`enqueue_entry_item`）；
3. 下游对空集合 `[0]` 索引 → panic。

同崩溃可达路径：入口解析到 builtin 模块时。

## 3. 与 social4hyq 实现的对比（逐字核验）

### 3.1 结论先行

**守卫函数体与我们移植版逐字一致（实测 diff 为空），调用点拓扑一致，无任何行为差异。**
两边实现同源于官方 upstream——这不是"两家各自发明轮子"，是**同一个上游修复，我们的
合并点没带上**。

### 3.2 逐项对照

| 维度 | social4hyq（ohos-aarch64 @ 36854e8e） | 我们（PR #28） |
|---|---|---|
| 守卫函数 | `transpiler.rs` `reject_unbundleable_entry_point`（L543 起，38 行） | 同函数，**diff 为空（逐字一致）** |
| 调用点 1（fresh resolve） | `Ok(r) => self.reject_unbundleable_entry_point(r, entry_point)`（L467） | 同（我们的 L461，行号差=文件版本漂移） |
| 调用点 2（cache-bust 重试） | `return self.reject_unbundleable_entry_point(result, entry_point)`（L522） | 同（我们的 L518） |
| 错误文本 | `"…" is disabled due to "browser" field in package.json (entry point)` | 同（与其测试树 `bundleErrors` 期望逐字一致） |
| builtin 分支 | `Cannot use "…" as an entry point: it resolves to a builtin module` | 同 |
| 返回值 | `Err(ResolveMessage)` → v2 enqueue `Err(_) => continue`，错误进日志 | 同 |

### 3.3 为什么他们有、我们没有（溯源）

- **守卫是官方 upstream 的代码，不是任何一家的发明**：官方 `bun-v1.4.0` tag 的
  transpiler.rs **没有**该函数；`bun-v1.4.1` tag **有**（grep 实证 4 处引用）——
  它在 v1.4.0 → v1.4.1 之间进入官方 main。
- **我们的线**：8/13 合并过 upstream main（`6692a5d5b1b`），但合并点**早于**
  v1.4.1/该守卫进入官方的时间——实测该 merge commit 的 transpiler.rs 中守卫
  计数 = **0**。此后我们未再同步上游。
- **他们的线**：2026-09-05 合并了官方 `bun-v1.4.1` tag（`d31c395b31`）→ 守卫随之
  进入他们的 fork。他们的测试树按"已修"状态写断言。
- **时间线巧合**：他们合并 v1.4.1 是 9/5，我们的 binary 46a905a6c 是 9/8 构建
  ——但我们的源码线自 8/13 后未再同步上游，所以 9/8 构建依然缺守卫。
  **跟鸿蒙适配无关**：这是纯上游跟进节奏差。

### 3.4 为什么我们的轮次暴露而他们的轮次不暴露

他们的 binary 有守卫 → browser-field 禁用入口走优雅报错路径 → 他们树里的
`bundleErrors` 断言通过。我们的 binary 无守卫 → 同样输入走 panic 路径 → SIGABRT。
他们的树当然没有为我们的 bug 准备 skip —— 互跑必挂。

## 4. 修复内容（src/bundler/transpiler.rs，+40/-2）

移植上游守卫 `reject_unbundleable_entry_point`：

- browser map 禁用 → 报错 `"…" is disabled due to "browser" field in package.json (entry point)`
- 解析到 builtin → `Cannot use "…" as an entry point: it resolves to a builtin module`
- 均返回 `Err(ResolveMessage)`；fresh resolve 与 cache-bust 重试两条路径都过守卫

v2 的三个 enqueue 调用点对 `Err` 已有 `continue`/优雅返回——错误进日志、构建
干净失败，与新版测试树的 `bundleErrors` 期望逐字一致。

## 5. 验证

- 守卫函数体与 social4hyq 版本**逐字一致**（本节 §3.2 的实测结论）；所用 API
  在同文件已有使用；rustfmt 解析通过
- cargo check 由 CI 承担（编写环境无编译工具链）
- 设备复验：下一轮 fulltest 两文件应转绿，崩溃数应为 0

## 6. 关联

- 同轮分析：`../analys/archive/compare-20260908-sys-release-vs-jxbit-46a905a6c.md` §3
- 平台字符串修复：[pr29-p1-process-platform-openharmony.md](pr29-p1-process-platform-openharmony.md)（同轮另一 P0，与 social4hyq 的关系性质不同——见其 §3）
