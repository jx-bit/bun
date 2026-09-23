# P0: pwritev2/preadv2 在管道上返回 ESPIPE 未降级（shell 非 quiet 输出全灭）— 工作记录

> **关联 PR**：[#41](https://github.com/jx-bit/bun/pull/41)（单 commit，1 文件 +8/−2 两处）
> **状态**：🔄 OPEN
> **定位**：设备分层探针实验（`_archive/fix-tasks.md` §任务1）实证的根因——
> shell 非 quiet（stdout 直通）全灭 + multi-run 空输出，约 250 用例。

## 1. 现象（设备探针实验，2026-09-14）

分层探针（p1~p6.js，A/我方双 binary 对照）：

| 层 | sys-release | 我方 007d7a07e |
|---|---|---|
| `Bun.spawn` pipe 单/并发 | ✅ | ✅ |
| `Bun.$` + `.quiet()`（builtin/外部/sh -c） | ✅ ×3 | ✅ ×3 |
| **`Bun.$` 非 quiet（stdout 直通）** | ✅ AAA 直通 | ❌ **exit 65507，stdout/stderr 全空**（3/3 稳定复现）|
| `bun run --parallel` 输出转发 | ✅ | ❌ 空 |

对原假设的推翻（实验矩阵）：ProcessHandle/pipe-watcher 层排除（Bun.spawn
pipe 读完全正常）；wave2 降级（c4323a5d3 时期即挂）。

## 2. 根因（错误码反查，100% 实证）

**65507 = 0xFFE3 = -29（i16 截断）= ESPIPE（Illegal seek）**。

`write_nonblocking`（`src/sys/lib.rs`）用 `pwritev2(fd, iov, 1, -1, RWF_NOWAIT)`
写管道：主线 Linux 对 off=-1 视为非定位写（管道合法）；**HongMeng 内核对
管道上的定位写直接返回 ESPIPE（不看 -1 约定）**。而降级匹配表：

```rust
match e {
    libc::EOPNOTSUPP | libc::ENOSYS | libc::EPERM | libc::EACCES => { disable(); ... }
    _ => return Err(...)   // ← ESPIPE(29) 落这里，错误直传
}
```

**降级集合缺 ESPIPE** → RWF 路径在管道上永远失败且不自愈 → shell 非 quiet
输出写失败 → `ShellErr::Sys(ESPIPE)` → 退出码 -29 → 65507；14fdf0d56 轮
exec.test 的 `bunsh: Illegal seek` 为同一错误的打印形态（一个根因两个症状）。

quiet 捕获与 `Bun.spawn` pipe 不走此路径 → 与探针矩阵完全吻合。

A 树（61dbc3a9d）同位置已修〔源码+实测〕：降级集合加 ESPIPE +
`RWFFlagSupport::disable()`（永久回退 plain write/read），注释自证
"preadv2(RWF_NOWAIT) on pipe/FIFO fd returns Illegal seek"。

## 3. 修复内容（1 文件，2 处）

`src/sys/lib.rs` 的 `read_nonblocking` 与 `write_nonblocking` 降级匹配表
各加 `libc::ESPIPE`（+注释，A 逐字节一致；A 侧注释中的 `sys.zig:NNNN`
行号引用为我方树不适用的溯源标记，未移植）。

## 4. 与 social4hyq 实现的对比（逐字核验）

证据类型：〔源码〕两树 diff 逐字核验；〔实测〕设备探针实验（fix-tasks.md
§任务1，p1~p6 双 binary 对照）。

| 维度 | social4hyq（61dbc3a9d，A 轮） | 我方（f01b1a3f15）→ 本 PR |
|---|---|---|
| RWF 降级集合 | 〔源码〕含 **ESPIPE**（read/write 两处） | 缺 ❌ → 逐字节移植 |
| `Bun.$` 非 quiet | 〔实测〕AAA 直通正常 | exit 65507 全空 ❌ → 预期修复 |
| multi-run 输出转发 | 〔实测〕通过 | 空 ❌ → 预期修复（同一写路径） |
| `Bun.spawn` pipe / quiet 捕获 | 〔实测〕通过 | 通过（本 PR 不触碰） |

## 5. 验证

- `cargo check -p bun_sys -p bun_runtime` ✓
- 冒烟（设备 30 秒判定）：`bun -e 'const r = await Bun.$`echo AAA`.nothrow();
  console.log(r.exitCode, JSON.stringify(r.stdout.toString()))'` →
  期望 `0 "AAA\n"`（终端出现直通 AAA）
- 修复后预期回补 ~250 用例：multi-run(90)、filter-workspace(72)、
  serve-directory-routes 转发面、exec(13)、bun-run(10)、bun-run-bunfig(10)、
  test-shard(2)、22650、seq-condexpr(3)、env.positionals(4)、which(1)、
  run-shell(1)、shell-keepalive(1)、env(4)、workspaces(2) 等

## 6. 关联

- 探针实验全文：`_archive/fix-tasks.md` §任务1（含被推翻假设的记录）
- 同族 syscall 黑名单：fchmodat2(452)、epoll_pwait2(441)〔A 侧已证〕、
  close_range(436) 可用〔pr34/35 实证〕——RWF_NOWAIT 本身在 OHOS 可用
  （rc 成功），问题仅在管道 fd 的定位写语义
- 关联轮次数据：`fulltest-data/archive/round-D-14fdf0d56.tar.gz`（D 轮，已归档）、
  `fulltest-data/007d7a07e/`（F 轮，数据已清理，证据见 pr41 文档本节）
