# P0: OHOS 管道输出捕获丢失（epoll CTL_DEL dup bug + 看门狗 + sync wait）— 工作记录

> **关联 PR**：[#32](https://github.com/jx-bit/bun/pull/32)（claude 分支 → ohos-aarch64，单 commit `7f99b314fd`，10 文件 +463/−49；rebase 至 #33 合并点并吸收仓库 lint 规范适配）
> **状态**：✅ 合并（2026-09-14，merge commit `0e0fd1559`；复跑验证：独有失败 101→39，F1 目标簇 cli/run/shell/console-iterator 大半转绿）
> **定位**：jxbit-fix-guide F1 根因簇（`bun run --parallel`/`Bun.$`/spawnSync 输出丢失，
> ~20 文件 / 300+ 用例）——**指南 §2 的归因与 port 清单有误**，真实修复面见 §3.1。

## 1. 现象

设备官方 v1.4.0 套件（同测试树双 binary）：

```bash
bun run a                  # ✅
bun run --parallel a b     # ❌ 只有 "a | Done in"，AAA/BBB 丢失
bun -e 'await Bun.$`echo AAA`'  # ❌ 输出为空
```

A 轮（1.4.0_80）通过、B 轮（我方）失败的 shell/cli-run/spawn/console-iterator 全族。

## 2. 机制（三处 OHOS 内核行为差异，均在 spawn/pipe 链路）

1. **epoll CTL_DEL dup 孤立 bug（管道丢失主因）**：spawn stdio 管道 fds 是
   `dup()` 共营同一 open file description 的 fd 对。HongMeng 内核对其中一个 fd
   `epoll_ctl(CTL_DEL)` 会永久孤立**另一个** fd 的内核侧注册（标准 Linux 无此行为）
   → 读端永不再收到事件。
   修复 = `FilePoll::deinit_force_unregister_skip_ctl_del`：注销后立即 close 的路径
   跳过显式 CTL_DEL（close 按 epoll(7) 隐式移除）。PipeReader/PipeWriter/pipes 采纳。
2. **epoll 静默停摆**：真机 syscall 级取证，`ADD/MOD` 返回成功但内核停止投递。
   `epoll_rearm_watchdog`（opt-in `Flags::EpollRearmWatch`，当前仅 Bun.Terminal PTY
   读端）后台线程指数退避补发冗余 CTL_MOD；`BUN_DISABLE_EPOLL_REARM_WATCHDOG=1` 关闭。
3. **sync spawn**：no_orphans 等待循环从 stub `None` 改为真实 poll+wait4+pidfd 父死
   监视（signalfd 在 OHOS 挂起）；`SpawnSyncEventLoop` 的 epoll_wait 超时
   wrapped-underflow（sec=i64::MAX → 等效无限）在 OHOS 上钳制，修复 spawnSync
   信号超时 ≤ ~15ms 必挂。

## 3. 与 social4hyq 实现的对比（逐字核验）

### 3.1 指南归因修正（先说结论）

指南 §2.2 让 port `spawn/process.rs`（to_process_handle/RefPtr 重构）+
`multi_run.rs`（114 行）+ `SpawnSyncEventLoop.rs`，并把 `src/sys/` 16 文件列为嫌疑。
**以 A 轮源码（61dbc3a9d，1.4.0_80，通过全部管道测试）锚定后该清单不成立**：

| 指南项 | A 树实况 | 结论 |
|---|---|---|
| `multi_run.rs` 114 行 | 两树（我方 vs 61dbc3a9d）**零差异** | 36854e8e 的 diff 是 1.4.2 版本漂移，勿搬 |
| `process.rs` RefPtr 重构 | A 树**无 RefPtr**（`49ff888ffe3`/`82123d3a61a` 均 not-ancestor）——A 用自有 poll+pidfd 实现修复且通过 | RefPtr 大迁移（111+90 文件）对 F1 **非必需** |
| `src/sys/` 16 文件嫌疑 | 本轮真实修复在 `src/io/`（posix_event_loop 等 6 文件），sys/ 无涉 | 勿动 |

### 3.2 逐项对照（真实修复面）

证据类型：〔源码〕两树 diff 逐字核验；〔实测〕设备 binary 行为。

| 维度 | social4hyq（61dbc3a9d，A 轮） | 我方（62960fd817）→ 本 PR |
|---|---|---|
| `posix_event_loop.rs` CTL_DEL | 〔源码〕`skip_ctl_del` 路径 + rearm watchdog（222 行） | 无（标准 CTL_DEL）❌ → 逐字节移植 |
| PipeReader/PipeWriter 关闭路径 | 〔源码〕采纳 skip_ctl_del + UAF 修复 + HongMeng ONESHOT 常亮卸载 | 无 ❌ → 同 |
| sync spawn no_orphans | 〔源码〕真实 poll+wait4+pidfd 父死监视 | stub `None` ❌ → 同 |
| SpawnSyncEventLoop 超时 | 〔源码〕OHOS 下溢钳制 | 无 ❌ → 同 |
| 管道测试 | 〔实测〕全部通过 | 失败 → 修后预期转绿 |

### 3.3 为什么 A 轮通过而 RefPtr 无关

A 与我方同为 v1.4.0 基；A 的修复 = **原创 OHOS 内核行为 workaround**（上游
v1.4.0→1.4.2 窗口亦无对应 commit，`git log bun-v1.4.0..bun-v1.4.2 -- src/io/`
核验），随其 1.4.0_80 构建已在设备验证。36854e8e（1.4.2 基）叠加了上游 RefPtr
重构，属版本演进而非本修复的组成部分。

### 3.4 本 PR 未包含的同区域差异

- `bun-spawn.cpp`（92 行）：A 恢复 close_range 直呼、OHOS 改 fork()（弃 vfork）——
  行为回退风险，与管道无关，**不搬**，单独评估
- `shell/subproc.rs`（35 行）：其自有的 node-env 注入特性（依赖 `api/ohos_node_userinfo`
  模块），非修复，**不搬**
- `echo.rs` errno unsigned_abs（1 行，无关）

## 4. 修复内容（10 文件，+463/−49）

9 个 port 文件与 A 逐字节一致，另加 1 个账本文件；随后做仓库规范适配（§4.1）。

`src/io/{posix_event_loop,PipeReader,PipeWriter,pipes,ParentDeathWatchdog,lib,windows_event_loop}.rs`
+ `src/spawn/process.rs` + `src/event_loop/SpawnSyncEventLoop.rs`。
我方 `src/io/` 相对 v1.4.0 零自有改动 → 整文件取用零冲突；`process.rs` 用 A 的
"修好并启用"替换我方"cfg 压制 + stub"（同一批问题的两种处理，A 已真机验证）。

### 4.1 仓库规范适配（port 后追加，行为不变）

参考树不执行我方的 lint 规矩，逐字节 port 会被 CI 拒绝，三处等价改写：

1. **clippy 禁用类型**：看门狗的 `std::collections::HashMap`/`std::sync::Mutex`/
   `std::env::var_os` → `bun_collections::HashMap`（wyhash）/`bun_threading::Guarded`
   （RAII，顺带消掉 std 版 poisoning unwrap）/`bun_core::getenv_z`；PipeWriter
   风暴检测器的 `Mutex<Option<Instant>>` 同改。
2. **mordant 裸布尔**：`deinit_possibly_defer(.., force_unregister, skip_ctl_del)`
   → `DeinitWhy` 结构体 + 命名常量 `PLAIN`/`FORCE_UNREGISTER`/
   `FORCE_UNREGISTER_SKIP_CTL_DEL`（"nothing says which is which" 正是 mordant 的
   指控点）。
3. **dead-code ratchet 精确匹配语义**：账本要求"条目数 == 实际数"（不是 ≤）。port
   用真实实现替换了 process.rs 的 5 处 `allow(dead_code)` 压制 → 实际数 0 ≠ 账本 5
   → 失败。修法 = 删除过期条目 `test/internal/source-lints/dead-code-escape-limits.json`
   的 `"src/spawn/process.rs": 5`（工作流：改代码后跑脚本再生账本）。

## 5. 验证

- port 步骤后与 A 逐字节一致（§4.1 规范适配除外，均行为不变）
- **CI 实测全绿**（commit `7f99b314fd`）：Rust lints（clippy + mordant）✓、
  source-lints ✓、Lint ✓、autofix ✓、OHOS container 构建（编译验证）✓；
  自托管 OHOS Rust Build 排队中（设备 runner 接活即跑）
- 非 OHOS 影响面：skip_ctl_del 仅少一次冗余 epoll_ctl（epoll(7) 等价）；看门狗
  opt-in + 环境变量可关；Windows 同名 no-op
- 设备验收随下一轮 fulltest：`bun run --parallel a b` 输出 AAA/BBB、`Bun.$` exec 恢复、§1 文件清单转绿

## 6. 关联

- 指南：`../knowledge/jxbit-fix-guide-20260910.md` §2（归因修正已回写）
- 前序：[pr31](pr31-p1-bun-node-dir-app-tmp.md)（F3）、[pr30](pr30-p1-process-platform-cpp-getter-and-bundled-inlining.md)（platform）
- 簇归因总表：[../analys/20260911-jxbit-only-55-attribution.md](../analys/20260911-jxbit-only-55-attribution.md) §3
- 方法论：跨树 port 以**同基线树**（A 轮 61dbc3a9d）锚定，而非 HEAD 对 HEAD
  （36854e8e 混入 1.4.2 窗口漂移）
