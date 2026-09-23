# A3-11：harness `libcPathForDlopen()` 缺 openharmony 分支（测试树承载案）

> **归类：测试树承载（本目录首案）。** 修复面 = 我们 fork 树的
> `test/harness.ts`（PR #15 已交付），runtime 零改动。
> 曾在 20260921 追踪清单列为 R1"修复项"，2026-09-21 重新定性归入本目录。

## 1. 机制

测试通过 `bun:ffi` dlopen libc 调 mkfifo / raise / tcgetattr 等bun 未暴露的
系统函数，libc 路径由 harness 的 `libcPathForDlopen()` 提供。官方 v1.4.0
harness 只有 linux/darwin/android/freebsd 分支，设备上
`process.platform === "openharmony"` 落 `default: throw
"unsupported platform openharmony"` → FFI-mkfifo/raise 族 7 个失败文件段内
该错误出现 81 次（H 轮 615b48e95 口径）。

**为什么 binary 侧无解**：throw 发生在测试树文件里，A/B 两个 binary 跑同一棵
官方树时在同一处同一方式挂 —— 两轮失败签名逐位相同（filesink 34/18、
bun-serve-file 103/2、cp 41/4、streams 174/1、socket 86/4、fetch 357/5），
这正是该问题长期被"与 A 共挂"掩盖、未单独立项的原因。

## 2. 为什么修复在测试树（四方对比）

| 方 | openharmony 分支 | 在其环境的表现 |
|---|---|---|
| 上游 v1.4.0 树 | 无 → throw | —— |
| ljy9812 树 | 裸名 `"libc.so"` | 有效 |
| social4hyq 树 | 裸名（继承） | 有效（Harmonybrew 环境 /usr/lib/libc.so 是好文件，裸名 soname 搜索命中） |
| **我们 fork 树（PR15）** | **musl loader 显式路径** | 有效（消费版设备上裸名会解析到损坏的 /usr/lib/libc.so，必须显式路径） |

musl loader（`/system/lib/ld-musl-aarch64.so.1`）本身就是 libc（导出全部
libc 符号）、全设备存在、任意域可 dlopen，且与我们 binary 的 PT_INTERP 同源。

## 3. 交付状态

- ✅ **随我们测试树交付**：PR #15 已合并（a346ec192a，2026-09-04），真机验证
  通过（loader 路径 dlopen OK + getpid 符号导出 OK）。交付档案：
  [issues/pr15-p1-dlopen-libc-path-openharmony.md](../issues/pr15-p1-dlopen-libc-path-openharmony.md)。
- 正常交付 fulltest（我们 binary + 我们树，指导 §4"树与 binary 同 commit"）：
  **该问题不存在**。

## 4. 对比轮（官方树口径）的残留面

A/B 验收对比部署官方 v1.4.0 树 → 本修复不随行，两侧共挂 7 文件属预期。两个选项
（详见 [本目录 README](README.md) 处理原则）：

1. 可选注入：`fulltest/patch-official-harness.sh`（patch 文件
   `fulltest/patches/official-v140-harness-openharmony.patch`，幂等 + 防错 +
   校验；2026-09-21 就绪，待下次官方树部署启用）—— 两侧同树同补丁，公平性不变；
2. 不注入时：按"测试树承载类共挂"在轮报告标注本案例归属，验收扣减。

## 5. 验证方式（下次官方树部署时）

全量后 `grep -c "unsupported platform openharmony" all-official-report-*.txt`
→ 期望 0（已注入）或与轮报告标注一致（未注入口径）。

---
*立档：2026-09-21（自 20260921-remaining-issues.md R1 重新定性）| 依据：H 轮日志取证 + pr15 档案 + bun-v1.4.0 tag 逐字核对*
