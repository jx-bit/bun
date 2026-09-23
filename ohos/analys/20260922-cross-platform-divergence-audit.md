# 跨平台偏离审计：fork vs 官方 v1.4.0（泄漏项台账）

> **审计对象**：`claude/ohos-windows-cfg-gates` 分支尖（= origin/ohos-aarch64 f21748c2e9 + PR #56）
> **官方基线**：`bun-v1.4.0`（34cbb9a40b，merge-base 干净，fork 未取 1.4.1/1.4.2）
> **口径**：用户要求"修改只影响鸿蒙 PC（OHOS），其他平台编译代码与官方一致"
> **OHOS 目标**：`aarch64-unknown-linux-ohos`（target_os="linux" + target_env="ohos"）——唯一允许偏离的目标
> **方法**：81 文件 226 hunk 逐个提取控制谓词（#[cfg] / C++ #if / 运行时常量），在 OHOS / linux-gnu / linux-musl / windows-msvc / apple-darwin 上求值；机械分诊（脚本）+ 人工逐文件复核
> **建立**：2026-09-22（Windows CI 修复 PR #56 的后续审计）

## 0. 总体结论

门控纪律整体良好：**约 85% hunk 使用精确的 `target_env = "ohos"` 门**（io/sys/bun_core/dns/install 调度/CLI/StandaloneModuleGraph 大面积干净）。但存在 **3 个功能级泄漏 + 4 项有意跨平台修复（需拍板）+ 约 10 处无门控角落回退 + 5 处构建面不一致**。Windows/macOS 受影响面较小；**常规 Linux 受影响面最大**。

平台真值速查：`target_os="linux"` 在 linux-gnu/musl/ohos 均为真（宽门！）；`target_env="ohos"` 仅 OHOS；`not(windows)` 含 macOS；`unix` 含 macOS/freebsd。

## 1. 🔴 功能级泄漏（非 OHOS 平台行为与官方不同，建议必修）

| # | 位置 | 问题 | 影响面 | 修复方向 |
|---|---|---|---|---|
| F1 | `src/jsc/bindings/bun-spawn.cpp` | 官方 clone3/CLONE_INTO_CGROUP cgroup-spawn 路径被整体删除：`join_cgroup_in_child` 永不为 true（声明于 :279，唯一读取点 :327 已死），而 Rust 侧仍传 `cgroup_fd`（spawn_process.rs:698）→ `Bun.spawn` cgroup 参数**静默失效** | **常规 Linux 功能回归** | 把官方 cgroup 块恢复进 `#if OS(LINUX) && !defined(__OHOS__)` 分支（OHOS 继续走 fork） |
| F2 | `src/bundler/transpiler.rs` `reject_unbundleable_entry_point`（:534+，resolve_entry_point 两个调用点接线） | **无门控**：builtin/浏览器映射入口点从"静默空打包"变为报错 "Cannot use ... as an entry point: it resolves to a builtin module" | 全平台 bundler 行为 | 先核官方 1.4.1/1.4.2 是否上游修复（疑似 backport）：是→按"上游窗口修复"处理；否→加 `env="ohos"` 门或书面接受 |
| F3 | `src/install_types/resolver_hooks.rs:813` `OperatingSystem::OPENHARMONY = 1<<9` | 枚举位进 `ALL` 掩码 → **所有平台** lockfile os 掩码/文本与官方不同（bun.lock 互读兼容性）；配套 `lockfile/bun.lockb.rs` legacy 掩码迁移 | 全平台输出格式 | OPENHARMONY 位从 `ALL` 摘出，或 ALL 判定改为 per-platform |

## 2. 🟡 有意的跨平台修复（官方同版本有同样 bug；保留=偏离官方，收紧=放弃修复。**需拍板**）

| # | 位置 | 内容 | 门 | 备注 |
|---|---|---|---|---|
| C1 | `src/runtime/api/bun/Terminal.rs`（:121 deferred_exit 字段、:586 read() 后置、:1934 stash 分支） | `read()` 启动时序重排 + exit 通知重放——修复同步完成时 exit 回调静默丢失 | **无门（全平台）** | PR #49；官方 v1.4.0 全平台有此 bug（~50% 复现于设备） |
| C2 | `src/runtime/webcore/blob/read_file.rs`（:300 字段、:433-518 三个 fn、:911/:1020 接线） | stdin 大读工作池竞态串行化（多 worker 并发读循环） | `not(windows)`（mac+常规 Linux 激活） | PR #37，文档自认"race 非 OHOS 特有" |
| C3 | `src/io/PipeWriter.rs:147/:166` + `src/io/posix_event_loop.rs`（epoll_rearm_watchdog :1298+）+ `Terminal.rs:946-964`/`PipeReader.rs` 登记 | storm 检测、强制 unregister、epoll rearm 看门狗 | `any(linux, android)`（**常规 Linux 激活**） | **含 PR #56 自己的门**——按一刀切标准应返工为 `all(target_os="linux", target_env="ohos")`；看门狗仅 Terminal PTY 路径登记 |
| C4 | `src/io/PipeReader.rs:341` | 非持有 fd 消费者 close 时注销 poll（EOF 电平触发→double-teardown UAF 修复） | 疑似无门（posix 全平台） | 真 UAF 修复 |

## 3. 🟢 无门控角落回退（健康系统无感；严格口径算偏离，建议统一收紧或书面接受）

| # | 位置 | 内容 | 触发条件 |
|---|---|---|---|
| R1 | `bun-spawn.cpp` rawExit（:126） | exit_group 失败兜底 `_exit`（原 Linux 分支不兜底） | seccomp 拦 exit_group 的系统 |
| R2 | `bun-spawn.cpp`（:262-272） | vfork 失败回落 fork；fork 回落时 exec 失败"假定成功" | vfork 返回 -1 |
| R3 | `bun-spawn.cpp`（closeRangeOrLoop 前） | `current_max_fd` 钳位 ≥2（防 stdio 被关）——**无门全平台** | max_fd<2 的 spawn |
| R4 | `c-bindings.cpp` is_executable_file（:53） | 常规 Linux 分支 x 位判定 owner → **owner/group/other 任一** | group/other-x-only 文件的 which 判定 |
| R5 | `install/isolated_install/Hardlinker.rs` + `install/PackageInstall.rs` | linkat `EPERM/EACCES` → copy_file_fallback（SELinux workaround） | linkat 被拒 |
| R6 | `install/npm.rs:1181` | linkat_tmpfile 重试 + 降级 File 复制 | 首次 link 失败 |
| R7 | `install/bin.rs:1327` | 装好的 bin 显式 `fchmodat` | 每次 bin link（多一次 syscall，模式更正确） |
| R8 | `io/ParentDeathWatchdog.rs`（:736+） | /proc 全扫回退（无 CONFIG_PROC_CHILDREN 内核） | 仅无该配置的内核（OHOS 是其一） |
| R9 | `resolver/lib.rs:1073+` | openat2 ENOSYS → 包装器缓存回退 | pre-5.2 老内核 |
| R10 | `src/js/wasi-runner.js`（:27+） | WASI 根 preopen 改运行时探测 `fs.openSync("/")`——**所有平台多一次探测 syscall**；根不可读的角落行为分叉 | 根目录不可读（OHOS 沙箱 EACCES） |

## 4. ⚪ 编译/构建面（无运行时影响，顺带对齐）

- `standalone_graph/Cargo.toml`、`spawn_sys/Cargo.toml` **无条件**依赖 `ohos_sign`——另三个 crate（install/sys/runtime）用了精确的 `[target.'cfg(target_env = "ohos")'.dependencies]`，**不一致，建议对齐**
- `runtime/api.rs:113` `pub mod ohos_node_userinfo;` 无门（调用点 js_bun_spawn_bindings.rs:1098 / subproc.rs:738 均精确门）→ 非 OHOS 死码
- `install/isolated_install/Symlinker.rs` `Strategy::IgnoreFailure` 枚举位**无任何调用方**（死代码）
- `options_types/compile_target.rs` `Libc::Ohos`：加性枚举（非 OHOS 走原分支；仅新增 `--target=...-ohos` 可解析 token）
- `Terminal.rs` openpty 查找表追加 `libc.so` + RTLD_DEFAULT 回退：加性失败路径，glibc 正常路径不经过
- 零行为差异 ✅：NodeSqlite.h / NodeVM.h / JSWrappingFunction.h（限定名重命名，clang-cl 兼容）、stdio.rs pub(crate)→pub、posix_event_loop DeinitWhy 重构、js/node/net.ts / os.ts（`process.platform === "openharmony"` 加性析取，非 OHOS 平台恒假）、create-hash-table.ts、Global.rs os_name（ohos 首位判定，非 OHOS 分支不变）、env.rs IS_MUSL 加宽（常规 musl 原本为真，不变）、linker.lds（flags.ts:1334 已处理 Linux UND 情形）

## 5. E 项定论（2026-09-22 关闭）

| 项 | 定论 |
|---|---|
| `resolver/lib.rs:282` getcwd→getcwd_honest | **A**：getcwd_honest 的差异体是 `#[cfg(target_env="ohos")]` 内部块，非 OHOS 逐字节同语义 |
| `bun_core/env_var.rs` BUN_OHOS_USERNAME 注册 | **B2**：注释明示 bun 不读、写入方（ohos_node_userinfo）有精确门，零运行时效果 |
| `io/pipes.rs` close 前跳过 CTL_DEL | **B2-等价**：epoll(7) 语义等价（close 隐式移除注册），常规 Linux 少一次 syscall，行为不变 |
| `js/wasi-runner.js` WASI preopen 探测 | **B1-轻微**：见 R10 |

## 6. 干净面（A 类代表，抽查全部通过）

io 家族精确门（dlopen ohos/not-ohos 对、time_t musl+ohos、linux_syscall ohos 对、SpawnSyncEventLoop cfg! 常量）、sys/lib.rs 掩码改写（`not(any(musl,ohos))` 等价类）、spawn/process.rs ohos/not-ohos 对 + prewarm（VirtualMachine.rs:3625 精确门）、stdio.rs memfd→socketpair（`all(any(linux,android), not(ohos))` 精确）、dns×2 / subproc / napi_body / crash_handler / PackageManager×2 / lifecycle_script_runner / run_command / upgrade_command（IS_OHOS 首位）/ bun_core util+env（ohos 内部门）、StandaloneModuleGraph（150 行全精确门）、resolver.rs（cfg! 常量）、bun-spawn.cpp PWD 同步块（`__OHOS__`）、wtf-bindings TCSANOW 回退（`__OHOS__`）、ohos_sign 5 个调用点（全部精确门）、shebang（`any(ohos, test)`）。

## 7. 决策点（待拍板）

1. **C 类 4 项**：保留跨平台修复（=书面接受偏离官方）还是收紧到 `all(target_os="linux", target_env="ohos")`？——含 PR #56 是否返工
2. **F2 transpiler**：先对官方 1.4.1/1.4.2 diff 核实是否上游修复
3. **🟢 R 组**：统一加 `env="ohos"` 门，或按"健康内核无感"书面接受（R3/R4/R10 建议优先处理——R3 无门全平台、R4 改变 which 语义、R10 全平台加 syscall）
4. 修复按仓库规范逐项出 PR（单 commit + 台账 + check-pr.sh）

## 8. 复现

```bash
git diff --stat bun-v1.4.0..claude/ohos-windows-cfg-gates -- src/   # 81 文件 +4573/−275
bash ohos/analys/audit-triage.sh                                      # 分诊脚本（hunk → 谓词线索 TSV）
```

---

*审计：Sisyphus，2026-09-22。后台 explore agent 因环境故障（模型 opencode/gpt-5-nano 不存在）全部改为主会话人工完成。*
