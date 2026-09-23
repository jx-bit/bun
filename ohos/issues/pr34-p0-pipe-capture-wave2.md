# P0: 管道捕获 wave-2（memfd 禁用 + waiter-thread 默认 + close_range 直呼 + $PWD 同步）— 工作记录

> **关联 PR**：[#34](https://github.com/jx-bit/bun/pull/34)（claude 分支 → ohos-aarch64，
> 单 commit；PR #32 的后续 wave）
> **状态**：🔄 OPEN
> **定位**：0e0fd1559 全量实测（`20260911_fulltest_official-v140-jxbit-0e0fd1559`）
> 中 39 个 jxbit-only 失败的剩余主体 —— PR #32 修好的是 F1 簇中"内建命令捕获 +
> 同步 spawn 非 bun 二进制"面（mv/ls/file-io/yield/no-orphans/spawn-signal 等 8 文件
> 转绿），但 **spawn bun 自身为子进程并读其输出**、**spawnSync stdin=Buffer**、
> **异步退出检测** 三条路径仍断（~20 文件 / ~221 用例 + 2 挂死）。

## 1. 现象（设备日志取证，报告 zip 内 all-official-report 逐文件核对）

| 症状类 | 证据 | 文件 |
|---|---|---|
| spawnSync + `stdin: Buffer` → 子进程 stdout 空 | `console-iterator`：stdin "hello world" 原样回显，实收 `""` | console-iterator、spawn-stdin-* |
| 异步 `Bun.spawn(bunExe(), stdout:"pipe")` → stdout/stderr 双空（exit 常为 0） | `test-shard` 期望 `RAN fX` 收 `[]`；`which-streamed`、multi-run(90)、filter-workspace(72)、run-shell、bun-run(10) | ~10 文件 |
| `bun exec`（1.4 新 CLI）报 `bunsh: Illegal seek: `（ShellErr::Sys ESPIPE，path 空） | `exec.test` 期望 `bun: command not found` 实收 Illegal seek；`it works` stdout 空 | exec(13)、which(1) |
| argv/positionals 丢失 | `env.positionals`：`bun run script.bun.sh a bb` → 脚本看不到参数 | env.positionals(4)、bun-run.test |
| 挂死 ×2 | 双跑 360s 超时（2×180s RETRIES=1） | shell-cmdsub-crash、regression 26286 |

**fixed-vs-broken 判别式**（与 0910 轮 101 清单对照）：转绿的全部不踩上述四条路径；
仍挂的几乎全部 spawn `bunExe()` 作子进程——指向子进程侧 stdio 载体与退出检测，而非
PR #32 已覆盖的 epoll 事件投递层。

## 2. 机制（四项，全部有 A 树设备实证注释背书）

1. **memfd 在 HongMeng 上损坏 → stdin/stdout=Buffer 的 spawn 全废**。A 树
   `spawn_process.rs` + `stdio.rs` 双处 cfg 门控（`not(target_env = "ohos")`），
   注释〔实测〕："verified 2026-06-11: dup2(memfd,1/2) → child writes → fstat
   size=0. Fall through to socketpair on OHOS."。我方树两处都未门控 →
   stdin=Buffer 经 memfd 交给子进程后子进程读空 → console-iterator 症状；
   spawn_sys 侧（`bun run`/lifecycle 走的 Rust spawn）同样漏。
2. **pidfd+epoll 异步退出检测在 OHOS 静默失效**。A 树 `spawn_sys/lib.rs`
   `SHOULD_USE_WAITER_THREAD` 默认 `cfg!(target_env = "ohos")`，注释〔实测〕
   （2026-08-17，OHOS_TEST_STATUS.md）：子进程正常退出成 zombie，父进程事件循环
   永不收尾 → `Bun.spawn().exited` 不解析。PR #32 只给**同步**路径加了 carve-out
   （process.rs poll+wait4），异步 `Process::watch()` 路径仍裸奔。
3. **exec 前 fd 清理在 OHOS 实际是 no-op → 全部 fd>2 泄漏进 exec'd 子进程**。
   `bun-spawn.cpp` 的 OHOS 路径因"seccomp blocks close_range (436) with SIGSYS"
   的〔推断〕顾虑跳过直呼，落到 `closeRangeLoop` 的 fcntl(F_SETFD) 循环——而
   同函数上方注释〔实测〕自认 "On OHOS, fcntl(F_SETFD) is ignored in vfork
   children"。A 树 `#if OS(LINUX)` 直呼 close_range 且设备全绿（若 SIGSYS 属实，
   A 每次 spawn 即死）→ 该顾虑被 A 的设备结果证伪（疑为 CI 容器 seccomp 的
   误移植）。fd 泄漏的直接后果：子进程持有父侧管道读端/stdin 写端 → EOF 永不
   到来、孙进程继承、空捕获与挂死。
4. **`bun run` 系子进程的 $PWD 失同步**。OHOS EL2 沙箱里 exec'd 二进制的
   `getcwd()` 对沙箱路径报 EACCES，shell/程序转而信任 $PWD；我方的 C++ funnel
   PWD 修复（newEnvp）只罩 Bun.spawn，`bun run`/run_command 走 Rust spawn_sys
   **不过 C++ funnel**。A 树在 `js_bun_spawn_bindings.rs` 补了绑定层 PWD 同步。

## 3. 与 social4hyq 实现的对比（逐字核验）

证据类型：〔源码〕两树 diff 逐字核验；〔实测〕A 树设备行为/注释；〔推断〕机制反推。

| 维度 | social4hyq（61dbc3a9d，A 轮） | 我方（0e0fd1559，PR #32 后）→ 本 PR |
|---|---|---|
| spawn_sys memfd（`PosixStdio::Buffer`） | 〔源码〕`cfg(all(linux, not(ohos)))` 门控 + 注释 | 无门控 ❌ → 逐字节移植 |
| 运行时 Stdio memfd（`can_use_memfd`/`use_memfd`） | 〔源码〕同上门控 ×2 函数 | 无 ❌ → 逐字节移植 |
| waiter_thread_flag 默认值 | 〔源码+实测〕OHOS 默认 on（2026-08-17 真机取证注释） | `AtomicBool::new(false)` ❌ → 同 |
| `closeRangeOrLoop` | 〔源码+实测〕`#if OS(LINUX)` 直呼（设备全绿） | OHOS 跳过 → fcntl 循环 ❌ → 同 |
| 绑定层 $PWD 同步（`user_specified_cwd`） | 〔源码+实测〕spawn_maybe_sync 内 retain+push | 仅 C++ funnel（罩不到 spawn_sys 调用方）❌ → 逐字节移植 |

**本 PR 不包含的同区域差异**（沿用 PR #32 §3.4 口径）：

- A 内联版 shebang 展开（我方为 PR #17 `shebang.rs` + `ohos_expand_shebang` 调用，
  语义等价、所有权模型不同——不搬；A 侧 `#[cfg_attr(not(target_env="ohos"),
  allow(unused_mut))]` 属该区域）
- `ohos_node_userinfo` 模块及 subproc.rs node-env 注入（特性非修复，依赖模块
  我方不存在——不搬，与 PR #32 §3.4 同判）
- bun-spawn.cpp 非 OHOS Linux 的 clone3/cgroup 漂移（上游窗口，无关）

## 4. 修复内容（4 文件，逐字节 = A）

- `src/spawn_sys/spawn_process.rs`：`'stdio` 标签 cfg_attr + `'use_memfd` 块门控
- `src/runtime/api/bun/spawn/stdio.rs`：`can_use_memfd`/`use_memfd` 门控
- `src/spawn_sys/lib.rs`：waiter_thread_flag 默认值 + 取证注释
- `src/jsc/bindings/bun-spawn.cpp`：`closeRangeOrLoop` 去 `!__OHOS__`（仅此 hunk）
- `src/runtime/api/bun/js_bun_spawn_bindings.rs`：PWD 同步块（仅 PWD 半块，
  userinfo 半块不搬）

**本地核对**：四个移植区 `git diff 61dbc3a9d -- <file>` 零差异（残留仅为上述
"不搬"清单）✅；`cargo check -p bun_spawn_sys --target aarch64-unknown-linux-ohos` ✅。

## 5. 验证

- CI：Rust lints（host clippy + mordant）+ source-lints + OHOS container 构建
  （bun_runtime 的 OHOS cfg 编译验证在此——本地 codegen 链不全，按 PR #32 同口径
  交 CI）
- 设备复验随下一轮 fulltest，最小复现先行：
  ```bash
  # ① spawnSync stdin=Buffer（memfd 面）
  bun -e 'const r=Bun.spawnSync(["<bun>","-e","const s=await Bun.stdin.text();console.log(s)"],{stdin:Buffer.from("hello")});console.log(JSON.stringify(r.stdout.toString()))'  # 期望 "hello\n"
  # ② 异步退出检测（waiter-thread 面）
  bun -e 'const p=Bun.spawn(["sleep","0.2"]);const t=Date.now();await p.exited;console.log("exited in",Date.now()-t,"ms")'  # 期望 ~200ms 而非挂死
  # ③ fd 泄漏（close_range 面）：孙进程存活时父读端不应提前 EOF/挂死
  bun -e 'const p=Bun.spawn(["sh","-c","sleep 0.3 & echo done"]);console.log(await new Response(p.stdout).text())'
  # ④ PWD 同步（bun run 面带 cwd 的子进程 argv/getcwd）
  ```
- fulltest 预期转绿：console-iterator、spawn-stdin-destroy、spawn-stdin-readable-
  stream-integration、multi-run、filter-workspace、run-shell、run-quote、
  shell-keepalive、workspaces、env、test-changed、test-shard、which、exec、
  env.positionals、bun-run、bun-run-bunfig、shell-cmdsub-crash（超时→）、26286（超时→）
  ——observe 项：serve-directory-routes（PR #32 症状面，可能与 ①③ 同根）

## 6. 已知未决（不阻塞本 PR）

- `bunsh: Illegal seek`（ESPIPE）的确切 syscall 源未静态定位——memfd 读路径与
  fd 泄漏两假设均被本 PR 覆盖，设备复跑若仍现需带 BUN_DEBUG 日志单查
- 既有 OHOS-target clippy 欠账（bun_sys fchmodat/dlopen 两处
  `undocumented_unsafe_blocks`、spawn_sys shebang 两处 disallowed-type/by-value，
  均 PR #16/#17 时代引入，host CI clippy 编不到）——建议另立 P3 清理 PR
- structured-clone null（2 文件 6 用例）= e3bd3e44ed9 cherry-pick，独立项

## 7. 关联

- 前序：[pr32](pr32-p0-epoll-pipe-capture.md)（F1 wave-1，本 PR 为其 wave-2）
- 实测数据：C 轮 lists（现 `fulltest-data/archive/round-C-0e0fd1559.tar.gz`，原引用路径 `analys/fulltest-data/0e0fd1559.zip` 为旧布局已失效）
- 簇归因：`../analys/20260911-jxbit-only-55-attribution.md` §3（F1 面修正后余量）
- 方法学：同基线树锚定（61dbc3a9d）+ 空 diff 排除法，沿用 PR #32 §3
