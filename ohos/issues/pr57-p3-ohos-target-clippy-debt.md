# P3: ohos-target clippy 欠账清理(第一批:spawn 路径 5 crate)— 归档文档

> **关联 PR**:[#57](https://github.com/jx-bit/bun/pull/57)（单 commit
> `9cd0eb55e3`，6 文件 +42/−15，base `ohos-aarch64` tip）
> **状态**：✅ 合并（058d8e1de0）
> **来源**：#52 过程发现（pr52 文档 §6）——host lane 从不编译
> `cfg(target_env = "ohos")` 代码,这些欠账对本地/CI host clippy 完全
> 不可见;首次对 ohos target 跑 clippy 才暴露。

## 1. 问题

### 1.1 为什么一直没检查到(三车道盲区)

| 车道 | 为什么看不见这些欠账 |
|---|---|
| host clippy(package.json `rust:clippy`、`rust-lints.yml`、`clippy-loop/`——**全部无 `--target`**) | host triple(x86_64-linux-gnu)上 `cfg(target_env = "ohos")` 代码被 cfg **整体剔除**,位点对 linter 不存在 |
| OHOS 容器构建 | 走 `cargo build`——clippy lint **不参与 cargo build**,rustc 编译这些代码零告警(它们是 clippy lint,非编译错误) |
| 设备 fulltest | 只测运行时行为,与 lint 无关 |

实证〔源码〕:仓库内全部 `cargo clippy` 调用点(grep scripts/ + .github/ + package.json)无一携带 `--target`;`cargo clippy --workspace --lib --target=ohos --keep-going` 在本 PR 之前从未运行过。

**防再发**:后续可在 CI/本地增加一条 `--target=aarch64-unknown-linux-ohos` 的 clippy lane(待 bun_standalone_graph 第二批清完后即可常绿),或并入 `rust:clippy` 的双 target 调用。

### 1.2 欠账明细

`aarch64-unknown-linux-ohos` target 的 clippy 欠账散布在 spawn 关键路径
的 5 个 crate:undocumented unsafe(6 处)、裸指针 `as` 强转(2 处)、
手工 C 字符串(1 处)、禁用类型 `std::fs::File`(1 处)、
`from_utf8_unchecked` 作用在路径上(**非 UTF-8 路径 = UB**,1 处)、
未消费的按值参数(1 处)。

## 2. 修复(11 处,5 crate)

| crate | 位点 | 修法 |
|---|---|---|
| bun_core/util.rs | `b"/proc/self/cwd\0"` → `c""`;`&mut st` → `&raw mut st` | clippy 建议,语义不变 |
| bun_sys/lib.rs | SYS_fchmodat 裸调用(seccomp 绕行)、codesign-repair dlopen 重试 | 补 SAFETY(参数有效性契约) |
| bun_spawn_sys/spawn_process.rs | codesign 修复路径 `from_utf8_unchecked` → **OsStr 构造 Path**(非 UTF-8 从 UB 变为良性跳过);shebang 探针 `std::fs::File` → `openat_a`+`read`+`close`(显式双路径关闭,单次读语义保留——`n < buf.len()` 是短文件信号);argv 遍历补 SAFETY | 去 unsafe + 禁用类型迁移 |
| bun_spawn_sys/shebang.rs | `arg` 按值但 clone 未消费 → 直接消费 | 多余 clone 移除 |
| bun_crash_handler/lib.rs | SIGSYS ucontext `as` 强转 → `.cast()`;补 SAFETY | 同上 |
| bun_spawn/process.rs | `prctl(PDEATHSIG)` 补 SAFETY | 无指针、不可能违反内存安全 |

行为变化仅两处且均为改善:非 UTF-8 路径的 codesign 修复(UB→良性跳过)、
日志 lossy 格式化。

## 3. 有意不取(下一批)

`bun_standalone_graph` 还有 **12 处** ohos-target 错误,需要真正的迁移
而非清理:`std::fs::read_to_string`、`str::lines`/`str::split`、
`std::fs::File` ×2、undocumented unsafe ×2、ptr cast 等——涉及字符串
语义切换(`str::split` → `strings::split` 的类型与语义差异),独立专项,
避免本 PR 膨胀。

## 4. 验证

- 〔本机〕5 个修复 crate ohos-target clippy **全部 0 error**;host
  clippy 0 error;rustfmt clean;dead-code-escapes 24/24。
- 〔方法〕`cargo clippy --workspace --lib --target=ohos --keep-going`
  枚举全局欠账,确认本批之后仅剩 bun_standalone_graph 一处集中面。
- 〔CI〕容器编译门禁;行为变化面在 spawn 路径,设备 fulltest 的
  spawn 用例族天然覆盖。

## 5. 与参照实现的对比（参照线 = social4hyq/ohos-bun，非官方；2026-09-22 复核，改以**其现役分支 `ohos-minimal`** 为准）

> 首轮对比基于 `ohos-aarch64`（2026-09-16 后停更）；复核发现 A 的现役线已
> 移至 `ohos-minimal`（领先 151 commit，2026-09-21 仍在更新，"minimize-
> ohos-implementation" 重构后），shim 膨胀至 2532 行，且**已批量采纳
> "reference ports" 的运行时修复**——其中 "authority" 来源经比对即我方
> 交付线（is_executable_file X_OK、subprocess blob stdin 均为我方 #42 系
> 内容），**流向已反转：A 在移植我们的修复**。

**结论先行：11 处欠账分三类——4 处与参照线同源同欠（#42 时代逐字节移植的
遗留，双方代码一致、双方都未清）、1 处参照线有注释而我方移植时丢失、
6 处是我方自有代码的独有欠账（参照线树中无对应实现）。参照线的 clippy
车道（含最新 ohos-minimal）与修复前我方完全一致（无 `--target`），同样
存在盲区——本 PR 首次补上该检查面。** ohos-minimal 上逐一复核：
`from_utf8_unchecked`/`std::fs::File::open` 欠账**仍在**（1 命中）、
clippy 车道仍 host-only——本 PR 的修复面领先其现役线。

| 位点 | 参照线实测（ohos-minimal 复核，ohos-aarch64 同） | 我方修复前 | 定性 | 证据 |
|---|---|---|---|---|
| util.rs `b"/proc/self/cwd\0"` | **同款欠账**（同源） | 同 | #42 移植代码遗留 | 〔源码〕grep |
| util.rs `&mut st` | **同款欠账** | 同 | 同上 | 〔源码〕 |
| shebang 探针 `std::fs::File::open` | **同款欠账**（minimal 仍 1 命中） | 同 | 同上 | 〔源码〕 |
| spawn `prctl(PDEATHSIG)` 无 SAFETY | **同款欠账**（注释同源） | 同 | 同上 | 〔源码〕 |
| codesign-repair dlopen SAFETY | A 有注释（eager ensure_signed + retry 结构） | 我方缺——惰性 repair 重构时未带上 | 我方 #14 系重构丢失 | 〔源码〕 |
| fchmodat SYS 裸调用 | **A 无此代码**（minimal 走 shim interposer 层，2532 行版含 fchmodat2） | 我方独有 | 本仓自有设计 | 〔源码〕 |
| `from_utf8_unchecked` | **minimal 仍有 1 命中——欠账未清**；其修复路径无我方 OsStr 方案 | 我方独有（已修） | 本仓自有设计 | 〔源码〕 |
| crash_handler SIGSYS cast/SAFETY | A 无此 handler（grep = 0） | 我方独有 | 本仓自有设计 | 〔源码〕 |
| spawn argv 遍历 SAFETY | **A 无 `ohos_expand_shebang`/`build_rewrite`**（grep = 0） | 我方独有 | 本仓 #17（shebang 展开）自有功能 | 〔源码〕 |
| shebang.rs `arg.clone()` | **A 无此文件**（我方来源 = 6bf3e5c494 "#17"） | 我方独有 | 同上 | 〔源码〕git 记录 |
| clippy 车道 | `rust:clippy` 无 `--target`（minimal 与 ohos-aarch64 逐字一致） | 修复前同盲区 | 双方均未建 | 〔源码〕 |

**暴露差异**：①参照线的 fchmodat/fchmodat2 面走 shim 拦截、我方走进程内
裸系统调用——拦截面不同，SAFETY 各自成立；②本批 6 处"我方独有"欠账
恰集中在 #14/#17 自有功能与自有 SIGSYS 恢复设计上——自有代码没有参照
可逐字对齐，质量只能靠本类检查面兜底，这正是补 ohos-target clippy
lane 的价值所在；③**流向反转**：A 的 batch-2 已在采纳我方修复
（"authority" 来源），两线进入双向收敛。

## 6. 复核的额外产出：A 的 batch-2 中我方尚缺的 4 项修复（下一批 PR 候选）

A 的 `ohos-minimal` b7cff72839 "adopt batch-2 runtime fixes" 中，经核验
我方树**均无**对应实现：

| # | 修复 | 来源 | 我方现状 |
|---|---|---|---|
| 1 | `FilePoll::register`:epoll_ctl(CTL_ADD) 遇 EEXIST 重发 CTL_MOD——关闭 fd 的陈旧注册使复用的 fd 号永远收不到事件;**永不 DEL 活注册**（springmin d91b7c5487,skip-CTL_DEL 的缺失半边） | springmin | 我方 posix_event_loop 无 EEXIST 处理(grep=0)——#32 修了 DEL 侧,这半边缺 |
| 2 | `cwd_is_deleted`:readlink 填满缓冲区(无 NUL)为**截断→不可判定**,不得判 deleted(springmin 5061d20345) | springmin | 我方 `if n > 0` 即 stat——**截断路径会误判**,且就在 #57 刚修过 clippy 的同一函数 |
| 3 | Terminal `ttySetMode`:OHOS PTY master 上 TCSADRAIN/TCSAFLUSH 失败的处理 | batch-2 | 我方 Terminal.rs 无 TCSADRAIN(0 命中) |
| 4 | `net.connect`:接受 `AddressInfo{address}` 作为 host 回退(springmin 139c6acda5,upstream-compatible) | springmin | 我方 net 侧无(0 命中) |

**建议**：4 项各立档移植（#2 优先——与 #57 同函数，趁热；#1 与 #32 家族
互补），实施时按惯例与 springmin 原实现逐字对齐后做本仓适配。
