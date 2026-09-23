# P1: EPOLLONESHOT 禁用导致 spawn-stdin + 26286 回归 — ✅ 已修复（PR #10）
> **关联 PR**：[#10](https://github.com/jx-bit/bun/pull/10)

> OHOS 上禁用 EPOLLONESHOT 后所有 epoll 变成 level-triggered，
> 可能导致 stdin 管道可读事件时序变化和特定 I/O 模式超时。
>
> **状态：已修复。** 方案 A 已执行，PR #10 合并于 2026-09-02（merge commit `add5d81289`），
> CI 全绿（OHOS Build / clippy / miri / mordant / Format / source-lints）。
> 设备侧验证（spawn-stdin + 26286 真机复测）待自托管 runner 上线后执行。

---

## 1. 什么是 EPOLLONESHOT

### 通俗比喻

epoll 是 Linux 的"事件监听器"——告诉内核"这个文件描述符有数据可读时通知我"。

`EPOLLONESHOT` 是一个标志：告诉内核"只通知我一次，通知完就停，直到我重新注册"。

不设这个标志就是 **level-triggered**（水平触发）：只要有数据就一直通知。

### 技术含义

| 模式 | 行为 | 优点 | 缺点 |
|---|---|---|---|
| **EPOLLONESHOT**（one-shot） | 触发一次后自动禁用，需要重新 `EPOLL_CTL_MOD` 恢复 | 避免事件风暴，安全 | 需要 re-arm |
| **level-triggered**（LT） | 只要有数据就持续通知 | 简单，不需要 re-arm | 可能事件风暴 |

---

## 2. 问题是什么

### 2.1 我们做了什么

commit `ee6251b171` 在 `posix_event_loop.rs` 里禁用了 EPOLLONESHOT：

```rust
// 之前（v1.4.0 原版）
fn register_with_fd_impl(&mut self, loop_: &mut Loop, flag: Flags,
    _one_shot: OneShotFlag, fd: Fd) -> sys::Result<()> {

// 我们改的
fn register_with_fd_impl(&mut self, loop_: &mut Loop, flag: Flags,
    one_shot: OneShotFlag, fd: Fd) -> sys::Result<()> {
    // OHOS kernel (HongMeng 1.12) does not disarm EPOLLONESHOT interests
    // after they fire...
    #[cfg(target_env = "ohos")]
    let one_shot = OneShotFlag::None;  // ← 强制 level-triggered
    #[cfg(not(target_env = "ohos"))]
    let one_shot = _one_shot;
```

在 OHOS 上，所有 epoll 注册都变成 level-triggered。

### 2.2 为什么要禁用

commit `ee6251b171` 的注释说：
> "OHOS kernel (HongMeng 1.12) does not disarm EPOLLONESHOT interests
> after they fire (verified 2026-08-08: an OUT|ONESHOT poll on a pty
> master re-fires on every wait without re-arm)"

即 HongMeng 内核的 EPOLLONESHOT 实现有 bug：触发后不自动解除，
导致事件重复触发。禁用后改用 level-triggered 绕过这个问题。

### 2.3 禁用后的影响

- **所有** epoll 事件变成 level-triggered
- 可能导致事件风暴（持续通知）
- stdin 管道的可读事件时序变化 → spawn-stdin 测试失败
- 特定 I/O 模式下死等 → 26286 超时

### 2.4 回归数据

| 测试 | 用例数 | 早期版 | 新版 | social4hyq |
|---|---:|---|---|---|
| `spawn-stdin-readable-stream-integration` | 1 | ✅ PASS | ❌ FAIL | ✅ PASS |
| `regression/issue/26286` | 超时 | ✅ PASS | ⏰ TIMEOUT | ✅ PASS |
| **合计** | **1 + 1 超时** | ✅ | ❌ | ✅ |

---

## 3. social4hyq 怎么做的

social4hyq **不禁用 EPOLLONESHOT**，保持标准行为：

```rust
// social4hyq — 不禁用
fn register_with_fd_impl(&mut self, loop_: &mut Loop, flag: Flags,
    one_shot: OneShotFlag, fd: Fd) -> sys::Result<()> {
    // 没有任何 OHOS cfg gate
    // 只有一段注释说明 bidirectional one-shot 不支持：
    // "EPOLLONESHOT disarms the whole fd after the first event in
    //  either direction, so bidirectional one-shot is not supported."
```

social4hyq 不认为 EPOLLONESHOT 在 HongMeng 上有问题，
或者他们的设备/内核版本不同。

---

## 4. ljy9812 的做法

和我们相同 — 同样禁用 EPOLLONESHOT（commit `ee6251b171` 标注
"Cherry-picked from social4hyq/ohos-bun baea48bbb"）。

但 `ee6251b171` 的 commit message 说 cherry-pick 自 social4hyq，
而 social4hyq 当前代码并没有这段禁用。可能 social4hyq 后来移除了。

---

## 5. 后续修复（不在 dev 上）

commit `9d5d706c97`（"fix(io): emulate EPOLLONESHOT with DEL + ADD"）
是对 `ee6251b171` 的后续修复：用 `EPOLL_CTL_DEL` + `EPOLL_CTL_ADD`
模拟 one-shot 行为，而不是完全禁用。

但这个 commit 不在 dev 上（在 stash 里）。

---

## 6. 修复方案（已执行：方案 A）

### 方案 A：移除禁用，恢复 v1.4.0 原版（对齐 social4hyq）— ✅ 已执行

直接删掉 `ee6251b171` 添加的 OHOS cfg gate，恢复 v1.4.0 原版。

```rust
// 修复后（v1.4.0 原版）
fn register_with_fd_impl(&mut self, loop_: &mut Loop, flag: Flags,
    _one_shot: OneShotFlag, fd: Fd) -> sys::Result<()> {
    // 无 OHOS cfg gate，所有平台统一行为
```

**风险**：如果 HongMeng 内核真的有 EPOLLONESHOT bug，可能会在特定
设备/内核版本上出现事件重复触发。但 social4hyq 不禁用且测试通过，
说明至少 social4hyq 的设备上没问题。

### 方案 B：用 9d5d706c97 的 DEL+ADD 模拟

从 stash 取出 `9d5d706c97`，用 DEL+ADD 模拟 one-shot 行为。

**优点**：不完全禁用，保留 one-shot 语义
**缺点**：复杂，且 `9d5d706c97` 还没有在 v1.4.0 上验证

### 推荐：方案 A（对齐 social4hyq，最简单）— 已采用

---

## 6.5 修复结果（PR #10，2026-09-02）

### 实际改动

| 文件 | 改动 |
|---|---|
| `src/io/posix_event_loop.rs` | 删除 11 行 OHOS gate + 恢复参数名 `_one_shot` → `one_shot`（1 insertion, 12 deletions），文件恢复为与 `bun-v1.4.0` **逐字节一致**（`git diff bun-v1.4.0` = 0 行） |

### CI 验证结果（commit `b11d63bbcb`）

| Check | 结果 | 说明 |
|---|---|---|
| **OHOS Build**（social4hyq container） | ✅ SUCCESS | OHOS cfg 路径编译链接通过（~30 分钟） |
| cargo clippy（-D warnings） | ✅ SUCCESS | |
| cargo miri test | ✅ SUCCESS | |
| mordant | ✅ SUCCESS | |
| Format（autofix.ci） | ✅ SUCCESS | 文件与上游一致，无 diff |
| source-lints / Lint JS | ✅ SUCCESS | |
| OHOS Rust Build（自托管） | ⏸️ QUEUED | runner 离线，非阻断 |

### 挑战

| # | 问题 | 原因 | 解决方案 |
|---|---|---|---|
| 1 | 本地无法 `cargo check` OHOS cfg 路径 | 本地缺 `vendor/`（bootstrap 未跑），workspace 解析不了 | 隔离验证非 cfg 部分（diff = v1.4.0 + rustfmt），OHOS 编译交给 CI 验证 |
| 2 | git fetch 间歇性超时 | WSL 到 github.com:443 网络抖动 | 重试即可；gh api 通道通常可用 |
| 3 | push 到 dev 会捎带进未合并的 PR | dev 同时是 PR head | 等 PR #9 合并后再推新 commit，使其独立成 PR #10 |
| 4 | `Claude Find Issues for PR` check 失败 | runner 上安装 Claude Code CLI 网络失败 | 基础设施噪音，非必需检查，忽略 |

### 待办（设备侧）

- [ ] 自托管 runner 上线后，跑 `ohos/fulltest/` 全量测试
- [ ] 确认 `spawn-stdin-readable-stream-integration` PASS
- [ ] 确认 `test/regression/issue/26286` 不再超时
- [ ] 若真机出现 one-shot 重触发（HongMeng 1.12 的原始观察），回退评估方案 B（DEL+ADD 模拟，stash 里有 WIP）

---

## 7. 涉及的文件

| 文件 | 改动 |
|---|---|
| `src/io/posix_event_loop.rs` | 移除 OHOS EPOLLONESHOT 禁用（13 行），恢复 v1.4.0 原版 |

---

## 8. 验证方法

1. OHOS build 编译通过
2. 设备上运行 `spawn-stdin-readable-stream-integration` 测试
3. 设备上运行 `regression/issue/26286` 测试

---

## 9. 术语速查

| 术语 | 解释 |
|---|---|
| **epoll** | Linux 的事件监听机制，告诉内核"哪个 fd 有事件通知我" |
| **EPOLLONESHOT** | epoll 标志：只通知一次，触发后自动禁用 |
| **level-triggered (LT)** | 不设 ONESHOT，只要有数据就持续通知 |
| **OneShotFlag::None** | 禁用 one-shot，改为 level-triggered |
| **EPOLL_CTL_MOD** | 重新注册（re-arm）一个被 ONESHOT 禁用的 fd |
| **EPOLL_CTL_DEL + ADD** | 先删除再添加，模拟 ONESHOT 的 disarm + re-arm |

---

*文档日期：2026-08-31 | 分析者：Sisyphus*
*修复：2026-09-02，PR #10（方案 A），merge commit `add5d81289`*
*关联文件：`src/io/posix_event_loop.rs`*
*关联回归：spawn-stdin(1) + 26286(超时) → 待设备复测确认*

---

## 修复时间线

```
2026-08-08  真机观察：HongMeng 1.12 OUT|ONESHOT 不解除（ee6251b171 的依据）
2026-08-31  写入 issue 文档，推荐方案 A（social4hyq 不禁用且测试全过）
2026-09-02 02:57  PR #10 创建（commit b11d63bbcb，diff vs v1.4.0 = 0）
2026-09-02 03:0x  Rust lints ✅ / autofix ✅ / source-lints ✅ / Lint ✅
2026-09-02 03:4x  OHOS Build ✅（~30 分钟，OHOS cfg 路径编译链接通过）
2026-09-02 03:45  PR #10 合并（add5d81289），ohos-aarch64 已含修复
2026-09-02 03:5x  本地 dev 同步至 add5d81289；posix_event_loop.rs 验证无 OHOS gate
待办        设备侧复测 spawn-stdin + 26286（等自托管 runner 上线）
```
