# P0: OHOS epoll workaround 无门控代码阻断 Windows 构建 — 工作记录

> **关联 PR**：[#56](https://github.com/jx-bit/bun/pull/56)（claude/ohos-windows-cfg-gates → ohos-aarch64，
> 单 commit 99e910b369；2 文件 +6/−1，门内代码逐字节不动只加门）
> **状态**：🔄 OPEN
> **定位**：#32（7f99b314fd）与 #37（0b280893451）两个 OHOS 修复把平台专属代码写进
> 跨平台编译面（trait 方法、共享结构体字段）且未加 cfg 门。该 workflow
> （Build Bun x86/arm64, github-hosted）最后一次绿 = 09-03 run 33754809282
> （443bbb0aaf）；#32 09-11 合入后首次触发（09-21 run 35611960605，f21748c2e9）
> 即红，windows-x64 job 挂在 `Configure + build Bun`。#37 引入的第三处错误
> （read_loop_state 死码）被 bun_io 的两个 E0308 挡在后面从未暴露——本 PR
> 一次修齐三处。

## 1. 现象与机制（三处错误，全在 Windows 侧）

```
error[E0308]: mismatched types        → src\io\PipeWriter.rs:147
error[E0308]: mismatched types        → src\io\PipeWriter.rs:174
error: could not compile `bun_io` (lib) due to 2 previous errors
（修复后暴露第三处）error: field `read_loop_state` is never read
                                     → src\runtime\webcore\blob\read_file.rs:300
```

1. **`PipeWriter.rs:147`** `poll.unregister(crate::Loop::get(), true)`：
   POSIX 上 `crate::Loop` 与 `bun_uws_sys::Loop` 名义同一（lib.rs:281 注释），
   Linux 全绿；Windows 上 `crate::Loop::get()` 返回裸 `uv_loop_t*`
   （bun_libuv_sys::Loop），而 `unregister`（lib.rs:1854）要 uWS 包装器
   `*mut WindowsLoop` → E0308。
2. **`PipeWriter.rs:174`** `let fd: i32 = self.get_fd().native()`（风暴检测块）：
   POSIX `Fd::native() -> i32`；Windows 返回 HANDLE `*mut c_void`
   （bun_core/util.rs:917-924，经 `uv_get_osfhandle`）→ E0308。
3. **`read_file.rs:300`** `read_loop_state: AtomicU8` 字段：读取方
   （`try_begin_read_loop`/`end_read_loop`/`schedule_read_loop`）全部
   `#[cfg(not(windows))]`，Windows 上 `-D dead_code` 拒绝。#37 作者给常量
   mod 加了 `allow(dead_code)`（注释明说 Windows 走 ReadFileUV），但漏了
   字段本身。

## 2. 根因

#32/#37 自 social4hyq ohos 线移植时，该参考线**没有 Windows 构建通道**，
其上的平台专属代码从未被非 Linux 目标编译过；跨平台编译面（`on_poll` 是
所有平台都编的 trait default 方法、`ReadFile` 结构体在 Windows 侧由
FileOpener impl 保活）拿到平台专属调用而无门。Linux/容器 CI 全绿掩盖
问题，直到 09-21 手动触发 x86/arm64 workflow 才暴露。属 AGENTS.md 规则 9
（`rust:check-all`）与 landing-prs Cross-platform 节（平台门控代码必须全
目标核对）所防的标准案例。

## 3. 修复（只加门，门内代码不动）

- **`src/io/PipeWriter.rs`**（两处）：`#[cfg(any(target_os = "linux",
  target_os = "android"))]`——同文件 `write_to_blocking_pipe` RWF 探测与
  `src/io/lib.rs` `unregister_with_fd`（:1596）对 epoll 专属代码的既有
  谓词。两段 workaround（EPOLLONESHOT 自动解除失效的强制 unregister、
  epoll_pwait 风暴检测）均为 HongMeng 内核 epoll 行为，epoll-less 平台
  （kqueue/libuv）不可能复现。
- **`src/runtime/webcore/blob/read_file.rs:300`**：`#[cfg(not(windows))]`——
  与同结构体相邻 `io_parking`/`could_block` 字段（:293-296）同款。该处是
  线程池竞态修复非 epoll 专属，macOS 保留。
- OHOS 目标（aarch64-unknown-linux-ohos，target_os="linux" + env="ohos"）
  上两谓词恒真 → 编译产物与修复前逐 token 一致，交付目标行为零变化。

## 4. 验证

- **未修复构建必失败**：run 35611960605 job 106373038107（PR body 已引用）。
- **跨目标 cargo check 矩阵**（nightly-2026-07-20，镜像通道）：
  - `--workspace --target x86_64-pc-windows-msvc`：dev + release 双 profile
    全绿（release 口径 = CI 的 cfg 面，无 debug_assertions）
  - `-p bun_bin --lib --target aarch64-unknown-linux-ohos`：全绿（交付目标）
  - `-p bun_bin --lib --target aarch64-apple-darwin`：全绿（门控"关"路径）
  - host `-p bun_io`：全绿
  - workspace 全量覆盖 443bbb0aaf→f21748c2e9 之间全部 20 个 OHOS commit、
    41 个 Rust 文件的 Windows 编译面（强于逐 commit 溯源）
- **lint**：rustfmt ✓；dead-code-escape 账本 24 pass 无需再生 ✓；clippy/
  mordant 无本地环境，CI 侧覆盖（改动仅 cfg 属性，不引入禁用类型/裸布尔）。
- **设备复测**：不需要——cfg 门在交付目标上恒真，无任何运行时行为变化
  （规则 6 验证链针对行为变更；本 PR 为纯编译面修复）。
- **本机限制**：`bun bd` 需 clang≥21 本机仅有 SDK clang 15，原生 debug
  构建不可用——以 CI 为端到端口径。
- **CI 备注**：`claude-find-issues` check 因仓库缺 `ANTHROPIC_API_KEY`
  secret 失败（35s 即挂，anthropics/claude-code-action 通用问题），与本 PR
  无关、每 PR 必挂、非合并阻塞（#48-#55 同样挂着合并）。

## 5. 与参考线实现的对比

| 项 | 参考线（social4hyq/ohos-bun ohos-aarch64 及 spring 线） | 本仓 #56 |
|---|---|---|
| PipeWriter storm 块 | 存在，**同样无门控**（〔源码〕`git show hyq/ohos-aarch64:src/io/PipeWriter.rs` :147/:174 同款） | 加 `linux/android` 门 |
| read_loop_state 字段 | 未引入该字段（#37 是本仓独立修复） | 加 `not(windows)` 门 |
| Windows 构建通道 | 无——故从未暴露 | github-hosted x86/arm64 workflow |
| 门控谓词来源 | —（无先例） | 官方同文件 `write_to_blocking_pipe` RWF 探测 + `io/lib.rs` `unregister_with_fd` 的既有惯例 |

- **官方 oven-sh/bun**：无这段 OHOS 代码（其 `on_poll` 空缓冲分支即 #32
  之前的原状）；其对本文件 Linux 专属代码的门控惯例正是 `linux/android`
  谓词——本 PR 直接循此。
- **结论**：非移植偏差，是参考线盲区（无 Windows 通道）。补门不改变参考线
  语义；Linux/Android/OHOS 编译代码逐 token 一致。

---

*2026-09-22 立档（Sisyphus）。溯源：CI 失败诊断 → 7f99b314fdc/0b280893451
定位 → 4 目标交叉验证（含 bun_io 修复后挖出 read_file.rs 第三处）→ 规范
提交（check-pr.sh PASS → PR #56）。*
