# P1: uSockets epoll_pwait2 强制回退 + ReadFile 读循环竞态串行化 — 工作记录

> **关联 PR**：[#37](https://github.com/jx-bit/bun/pull/37)（claude 分支 → ohos-aarch64，
> 单 commit；2 文件 +166/−5，与 A 逐字节一致）
> **状态**：🔄 OPEN
> **定位**：0e0fd1559 全量实测 39 个 jxbit-only 失败中、与 F1/管道家族无关的两个
> 独立根因——inspector WS 1006（调试器特性整条链路）与 stdin 大读随机截断竞态。
> **14fdf0d56 轮注**：bun-inspector-protocol 未经本 PR 已随 wave2 转绿（wave2
> 连带或 flaky）——但 seccomp 对 syscall 441 的 SIGSYS 根因真实存在（进程会
> 死在探测路径上，属隐患级），本 PR 的价值 = 消除该隐患 + mimalloc 烧核修复
> + ReadFile 竞态修复，三项独立成立。

## 1. 现象与机制

### 1.1 inspector WebSocket 1006（`test/cli/inspect/bun-inspector-protocol.test.ts`）

```
error: WebSocket closed (1006) (inspectee exit: 1)
```

inspectee 正常启动（inspector banner、脚本执行、reportError 输出全有），
但调试客户端的 WS 连接建立后异常断开，协议消息一条未达。inspector 的
HTTP/WS 服务器运行在 **uSockets**（bun-usockets）事件循环上。

**A 树差量**（`packages/bun-usockets/src/eventing/epoll_kqueue.c`）：A 强制

```c
#if defined(__OHOS__)
static int has_epoll_pwait2 = 0;   // 跳过运行时探测
#else
static int has_epoll_pwait2 = -1;  // 我方：探测并使用 epoll_pwait2(441)
#endif
```

A 注释〔实测〕：OHOS seccomp 对 441 为 SECCOMP_RET_TRAP→SIGSYS，进程活不到
本文件自身的 ENOSYS/EPERM/EACCES 回退。与 `src/sys` fchmodat2(452) 的既有
结论同族——该 seccomp 黑名单拦新 syscall（452/441），不拦 436(close_range，
PR #35 已按 A 实证恢复直呼)。我方探测路径在 HongMeng 上行为异常 →
uSockets 循环对 inspector 服务器 socket 的事件投递失效 → WS 死。
其余 JS 事件循环走 Rust posix_event_loop（PR #32 已对齐）不受影响——
与"仅 inspector 挂"的实测完全吻合。

附带：同文件 A 还有 mimalloc park 交接限频补丁（OHOS 实测 ~30k FUTEX_WAKE/s
空转烧核，PR 级性能修复）——随本文件一并移植。

### 1.2 ReadFile 读循环竞态（stdin 大读随机截断）

A 树 `src/runtime/webcore/blob/read_file.rs` 修复〔实测〕：`on_ready()` 每次
fd 可读都无条件 `WorkPool::schedule` 新的 `do_read_loop` 任务，**多个 worker
并发跑同一 fd 的读循环**——OHOS 上 stdio 是 AF_UNIX SOCK_STREAM socketpair，
>1MB `Bun.stdin.arrayBuffer()` 随机截断（实测最多 6 个 worker 同时在循环内）。
修复 = `read_loop_state`（IDLE/RUNNING/RUNNING_PENDING）串行化：运行中的
可读唤醒不丢弃，置 RUNNING_PENDING 由 owner 退出时重排。

影响面：一切大 stdin/管道读（html-rewriter 的 stdin 用例、exec 128KB 管道、
spawn-stdin 系）的随机截断类失败——与 F1（输出捕获丢失）不同根因。

## 2. 与 social4hyq 实现的对比（逐字核验）

| 维度 | social4hyq（61dbc3a9d，A 轮） | 我方（14fdf0d566）→ 本 PR |
|---|---|---|
| uSockets epoll_pwait2 | 〔源码+实测〕OHOS 强制 `=0` 走毫秒回退 | 运行时探测 `-1` ❌ → 逐字节移植 |
| mimalloc park 限频 | 〔源码+实测〕`will_idle_inside_event_loop` 门控 + 1ms 限频 | 无 ❌ → 随文件移植 |
| ReadFile 读循环 | 〔源码+实测〕`read_loop_state` 三态串行化 | 无（并发竞态裸奔）❌ → 逐字节移植 |

两文件 whole-file diff 即上述 hunk（双向无其他差异）→ whole-file checkout
= 忠实移植，无版本漂移混入。

## 3. 排除项（本轮不投入）

- `bun-write` slice 目的地截断失效（1 用例）：blob/Body 区域与 A 零差异，
  无锚点；写路径疑似 hmdfs ftruncate/pwrite 语义面——待设备日志或窗口反查
- `26207`（3 用例）/ `html-rewriter`（1 用例）：子进程 stdout 空捕获形态 =
  F1 家族症状，随 PR #34 复测大概率转绿，不重复投入
- `test-changed`（0 用例文件级失败）：复测数据先行

## 4. 验证

- 本地：`cargo check -p bun_runtime` ✓（host 工具链，read_file.rs 全编译）；
  epoll_kqueue.c 为 C、仅 OHOS/usockets 构建面 → CI container 编译验证
- 设备复验预期：stdin 大读类随机截断消失（html-rewriter、exec 大管道等）；
  bun-inspector-protocol 在 14fdf0d56 轮已转绿（未经本 PR，见头部注）——
  本 PR 对它是隐患消除而非转绿依赖；canary 每日哨兵确认无回归

## 5. 关联

- 前序：[pr34](pr34-p0-pipe-capture-wave2.md)（F1 wave-2）、
  [pr35](pr35-p0-ci-container-gate-align.md)（门禁对齐 + canary 哨兵）
- 方法论：同基线树锚定（61dbc3a9d）whole-file diff，确认差量纯度后 whole-file
  checkout 移植
- seccomp 黑名单族证据：src/sys fchmodat2(452)〔既有〕、本 PR epoll_pwait2(441)〔A 树〕、
  close_range(436) 不在黑名单〔PR #35 实证〕
