# P2: waiter 线程 OHOS 预热（VM init）— 工作记录

> **关联 PR**：[#39](https://github.com/jx-bit/bun/pull/39)（单 commit，2 文件 +18）
> **状态**：🔄 OPEN
> **定位**：20260914 轮（14fdf0d56）新回归 `spawn-streaming-stdin`
> （fd 断言 22 vs 23）——waiter 线程 eventfd 惰性创建所致。

## 1. 机制

OHOS 构建 waiter 线程常开（spawn_sys/lib.rs 默认 flag），但 `init()` 在
**首个被 watch 的 spawn** 时才跑（process.rs `append()` → `init()`）：
eventfd(EFD_CLOEXEC) + poll 线程彼时才创建。`spawn-streaming-stdin` 在
spawn 前后各取一次 `getMaxFD()` 断言不变 → 首个异步 spawn 触发 init →
maxFD +1 → 断言失败（22 vs 23）。

A 轮同样挂（fail_overlap_both 含该文件）——waiter ON 的固有惰性行为，
overlap 口径；但运行时行为可对齐修正而非接受。

## 2. 修复（2 文件 +18）

- `src/spawn/process.rs`：新增 `WaiterThread::prewarm()`（调既有 `init()`，
  fetch_max 幂等）
- `src/jsc/VirtualMachine.rs`：`load_extra_env_and_source_code_printer` 的
  feature-flag 块之后无条件调用（`#[cfg(target_env = "ohos")]`）

代价：OHOS 每个 bun 进程常驻一个 parked 线程（INFTIM 空闲 poll）+1 个
CLOEXEC fd；非 OHOS 平台保持惰性（FORCE_WAITER_THREAD 测试钩子不动）。

### 2.1 实现选型：为什么是「VM init 预热」

**问题边界**：`spawn-streaming-stdin` 的 fd 基线在**用户代码执行前**取快照
（`getMaxFD()`），断言 spawn 前后不变。因此任何在首个被 watch 的 spawn 时
才发生的 fd 创建，都必然读作 +1——修复必须让 eventfd **早于任何用户代码
存在**，落在进程早期是唯一可行位置。

候选方案与拒绝理由：

| 候选 | 结论 | 理由 |
|---|---|---|
| **预热 @ VM init** | ✅ 采用 | eventfd 在基线前存在；一个守卫函数调用，成本见下 |
| 维持惰性、接受假失败 | ❌ | 每轮复测一个固定红；更糟的是该文件的 fd 断言从此失效——它存在的意义是抓 spawn 泄漏，永久红会让真泄漏被淹没 |
| 只建 eventfd、线程仍惰性 | ❌ | 两阶段状态机：SIGCHLD `wakeup()` 写 eventfd 时若线程未启动，EFD_NONBLOCK 缓冲仅 8 字节，写失败即**丢子进程退出信号**；为一个 parked 线程的延迟启动引入丢报风险，复杂度不成比例 |
| 每-spawn 开关 eventfd | ❌ | waiter 线程 `poll()` 的是**常驻 fd**——按 spawn 重建与轮询线程直接竞态，设计上不成立 |
| 更早（进程 main，VM init 之前） | ❌ | 与 VM init 等效；需穿透 CLI 入口层传递，无任何额外收益 |
| 改测试树 | ❌ | 官方 v1.4.0 测试源码不做适配性修改（项目裁决）；该断言语义本身是对的 |

**落点与作用域**：预热调用放在 `load_extra_env_and_source_code_printer`
的 feature-flag 块之后——该函数覆盖 `run_command`（×2 处）、`test_command`、
`repl_command`、`bake/production` 全部 JS 执行路径，即**所有会跑 fd 快照类
测试的入口都被覆盖**；`bun install` 等 non-JS-VM 路径不预热（无 fd 快照
诉求，不付成本）。`BUN_FEATURE_FLAG_FORCE_WAITER_THREAD`（非 OHOS 平台的
测试钩子）行为不变；OHOS 上 cfg 无条件预热（flag 本就编译期恒真）。

**成本量化**：waiter 线程栈 512 KiB（`STACK_SIZE`，虚拟内存；parked 线程
实际触页极少）+ 1 个 CLOEXEC eventfd；无子进程可 watch 时线程阻塞在
`poll(eventfd, POLLIN, INFTIM)`——零 CPU。OHOS 每个 bun 进程（含一次性
CLI 命令）承担同一成本，评估为可接受；非 OHOS 平台保持惰性，零影响。

**幂等性**：`init()` 以 `started.fetch_max(1)` 守卫，预热后的后续 `append()`
调用 `init()` 直接返回——不产生第二个线程或 fd。

## 3. 与 social4hyq 实现的对比（逐字核验）

证据类型：〔源码〕两树 diff 逐字核验；〔实测〕设备 binary 行为。

| 维度 | social4hyq（61dbc3a9d，A 轮） | 我方（14fdf0d56）→ 本 PR |
|---|---|---|
| waiter flag 默认值 | 〔源码〕OHOS 默认 ON（spawn_sys/lib.rs，2026-08-17 取证注释） | ON（#34 已移植，一致） |
| eventfd 创建时机 | 〔源码〕惰性——`init()` 由 `append()`（首个被 watch 的 spawn）触发，无预热调用 | 惰性 ❌ → VM init 预热（本 PR） |
| `spawn-streaming-stdin` | 〔实测〕**挂**——`fail_overlap_both.txt` 含该文件（14fdf0d56 轮双方都挂），fd 断言 22 vs 23 | 挂 ❌ → 预期转绿 |

### 暴露差异声明

- **本 PR 是"优于参考线"的有意偏离**：A 无预热、该测试在 A 同样失败并落在
  overlap 基线；我方预热后预期转绿，两树在此处不再逐字节等价（多一个
  `#[cfg(target_env = "ohos")]` 的 VM init 调用点）。
- 上游 Linux 无此问题：非 OHOS 平台 waiter 默认 OFF（pidfd 路径，无 eventfd），
  故该惰性行为从未在上游 CI 暴露——这也解释了为何上游测试的 fd 断言
  一直没被收紧。
- 预热代价：OHOS 每个 bun 进程常驻一个 parked waiter 线程（INFTIM 空闲
  poll，零 CPU）+1 个 CLOEXEC eventfd；CLI 一次性命令同样承担，评估为
  可接受（与 A 的常驻行为对齐后仅创建时机提前）。

## 4. 验证

- `cargo check -p bun_spawn -p bun_runtime` ✓
- 设备复测预期：`spawn-streaming-stdin` 转绿（基线快照前 eventfd 已存在）

## 5. 同轮 runner 韧性（非 PR，ohos/ 不入 git）

`ohos/fulltest/run-all-official-progress-optimized.sh` 增加 infra-retry：
文件输出含 `Verdaccio exited with code null and signal SIGKILL` 签名时
额外重试一次（本轮 frozen×2/pnpm-lock-v9/bun-publish 4 文件受害；上轮
受害者不重叠 = 随机毒化）。改动随设备侧脚本部署生效，REPORT 中
`[infra-retry #n]` 标记可观测触发频率。

## 6. 关联

- 前序：pr34（wave2）/ pr35（门禁+canary）/ pr37（epoll_pwait2 + ReadFile 竞态）
- 数据：20260914-round-report.md（三轮 101→39→32；本轮 18 新回归的
  五分类归因见其中）
