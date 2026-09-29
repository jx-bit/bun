# Bun OHOS 适配 vs 官方 v1.4.2 差异分析

> 生成日期：2026-09-29。
> 对比基线：官方 tag `bun-v1.4.2`（744846f844，"Bump to 1.4.2"）→ 交付线 tip `c58f3047`（"Merge bun-v1.4.2 into the OHOS line"，分支 `claude/sync-upstream-1.4.2`）。
> 规模：224 个提交，259 个文件，**+16,266 / −2,135 行**，新增 43 个文件，删除 0 个。
> `ohos-aarch64` 交付线 tip 是该分支的祖先（当前分支即最新交付线）。

## raw/ — 原始材料

`raw/cN.diff` 与 `raw/cN.commits.txt` 是按模块簇切分的完整 diff 与对应提交日志，再生成方式：

```sh
git diff  bun-v1.4.2 HEAD -- <路径...> > raw/cN.diff
git log --no-merges --oneline bun-v1.4.2..HEAD -- <路径...> > raw/cN.commits.txt
```

（`.log` 后缀被仓库 `.gitignore` 忽略，故提交日志用 `.commits.txt`。）

| 簇 | 路径 | diff 行数 |
|---|---|---|
| c1 平台识别 + JS 运行时绑定 | `src/bun_core src/runtime/api.rs src/runtime/api/bun src/runtime/cli src/jsc src/js src/options_types src/sys_jsc src/runtime/dns_jsc src/runtime/node/node_net_binding.rs src/runtime/shell/subproc.rs src/runtime/Cargo.toml` | 2073 |
| c2 syscall / IO / spawn 兼容层 | `src/sys src/io src/spawn_sys src/spawn src/event_loop src/dns src/crash_handler src/resolver src/standalone_graph src/linker.lds src/runtime/node/node_fs.rs src/runtime/socket src/runtime/webcore/blob/read_file.rs src/runtime/napi/napi_body.rs src/runtime/node/path_watcher.rs` | 2711 |
| c3 包管理器 | `src/install src/install_types` | 660 |
| c4 签名 crate | `src/ohos_sign test/internal/source-lints/ohos-sign-call-sites.test.ts` | 1553 |
| c5 构建系统 + shim | `scripts rust-toolchain.toml patches src/codegen/create-hash-table.ts` | 3562 |
| c6 CI / 发布 / ohos 工作区 | `.github ohos c.ohos` | 4931 |
| c7 测试树 | `test` | 9406 |

---

## 0. 总体架构：差异的三条主线

1. **平台身份**：让 `openharmony` 成为与 `linux` / `android` 平级的平台（枚举、用户可见字符串、npm 目标解析、lockfile OS 位、bundle 期常量内联）。
2. **沙箱/内核兼容**：OHOS 应用沙箱与 HongMeng 内核对标准 Linux 的十多处偏离（seccomp SIGSYS 杀 syscall、SELinux 拒绝 link、epoll/pipe/PTY 缺陷、无 /etc/passwd、只读 /tmp、exec 级代码签名），每处一个已验证根因 + 用户态 workaround，几乎全部以 `#[cfg(target_env = "ohos")]` / `__OHOS__` 门控。
3. **交付基础设施**：交叉编译工具链、`.codesign` 签名体系、CI 发布管线、设备测试闭环。

贯穿性设计：**原 LD_PRELOAD 兼容层（ohos-compat-shim）被直接编译进可执行文件**（`scripts/build/shims/ohos_compat_shim.c`，1748 行新文件），其 15 个符号经 `src/linker.lds` 导出，使 `bun build --compile` 产物无需任何 wrapper 即可在沙箱内存活。

---

## 1. 平台识别与 JS 运行时绑定（c1）

### 1.1 平台身份的多层注册

| 层 | 改动 |
|---|---|
| Rust 常量 | `bun_core/env.rs` 新增 `IS_OHOS`；`IS_MUSL` 扩为 `musl \|\| ohos`（OHOS 是 musl 系）；新增 `IS_GLIBC`。`Global.rs`：`os_name = "openharmony"`、`os_display = "OpenHarmony"`（沿用 Android 先例——内核枚举保持 `.linux`，仅用户可见字符串不同，npm user-agent / optional-deps 解析才能拿到对的平台包） |
| 目标三元组 | `options_types/compile_target.rs` 新增 `Libc::Ohos` → npm 目标后缀 `-ohos`、`upgrade_command.rs` 的 `SUFFIX_ABI`、bundle 期 `process.platform` 常量内联为 `"openharmony"` |
| C++ 绑定 | `BunProcess.cpp::constructPlatform`：`__OHOS__` 分支**必须放在 `__linux__` 之前**（OHOS triple 同时定义两者） |
| JS 内置模块 | `node/os.ts`：`type()="Linux"`、`machine()="aarch64"`（uname 语义）；`node/net.ts`：errno 回退表加 `-104`（ECONNRESET 族）、`isLinux` 判断加入 openharmony |
| WebKit fork 差异 | `sys_jsc/signal_code_jsc.rs`：OHOS 的 WebKit fork 以 `is_string()` 为字符串谓词，其余平台 `is_string_literal()` |
| 测试基建 | `test/harness.ts`：`isOHOS` 常量；`isLinux` 覆盖 openharmony；`libcFamily = "musl"` |

### 1.2 spawn 管线的 C++ 层修复（`bun-spawn.cpp`，最重的单文件改动）

- **fork 替代 vfork**：OHOS seccomp 可能阻断 vfork → OHOS 走 macOS/FreeBSD 同款 fork() + self-pipe 检测 exec 失败；Linux 路径也加了 vfork→fork 回退（fork fallback 时 exec 失败检测降级为 best-effort）。
- **`$PWD` 同步**（真实设备专属内核缺陷，CI 容器不可复现）：chdir()+exec 后，被 exec 的二进制调 `getcwd()` 在 EL2 沙箱路径上 EACCES（走父链被拒）。shell 的惯例是 `stat($PWD)==stat(".")` 时信任 `$PWD` 跳过 getcwd——spawn 时 chdir 了却没同步 `$PWD`，子进程必然走到坏 syscall。修在共享漏斗 `posix_spawn_bun`（Rust 侧 `js_bun_spawn_bindings.rs` 与 shell `subproc.rs` 各有对应实现）：chdir 时重建 envp 的 `PWD=`（getenv 返回**首个**匹配，所以先 retain 掉旧 PWD 再追加）；调用方显式传 `env.PWD` 时不干预。
- `rawExit`：先试 `exit_group`，seccomp 拦截时回退 `_exit`。
- close_range 排除 stdio fd；cgroup join 在 OHOS 跳过；`pthread_setcancelstate` 不碰（musl stub）。

### 1.3 其他 C++ 绑定

- `c-bindings.cpp`：**`open(O_EXEC)` 在 OHOS 不检查 x 权限位**（内核 bug，0660 文件误判可执行）→ 改用 `stat + access(X_OK)` 并拒绝目录。
- `BunProcess.cpp::getgroups`：OHOS 上 egid（如 20020101）不在补充组列表 → 按 Node 文档行为追加 egid（**未门控**，全平台对齐 Node 语义）。
- `execve` 路径跳过 `close_range(CLOSE_RANGE_CLOEXEC)`（SIGSYS）。
- `wtf-bindings.cpp`：PTY **master** fd 上 `TCSADRAIN/TCSAFLUSH` 返回 EACCES（沙箱拦 TIOCDRAIN；TCSANOW 同一 fd 成功）→ 回退 `TCSANOW`，`Bun.Terminal.setRawMode` 得以工作。
- `workaround-missing-symbols.cpp`：weak `mi_on_thread_idle`（mimalloc fork 未在所有平台提供该符号）。
- `JSWrappingFunction.h` / `NodeVM.h` / `NodeSqlite.h`：`needsDestruction` 枚举量加 `JSC::DestructionMode::` 限定（clang-cl / windows 交叉编译要求）。
- `BUN_DEFAULT_PATH_FOR_SPAWN`：OHOS 用 `/usr/bin:/bin:/system/bin`（无 `_PATH_DEFPATH`）。

### 1.4 `ohos_node_userinfo.rs`（新文件，548 行）

问题：app-sandbox uid 无 /etc/passwd，bun 自身有内嵌 shim 兜底，但 **exec 出去的真 node 子进程没有** → `os.userInfo()` ENOENT。方案：

- 识别 node-like argv0（`node`/`nodejs`/`nodeNN` 版本后缀/npm/npx/yarn/pnpm/pnpx/corepack；拒绝 nodemon）；
- 通过 `NODE_OPTIONS --require` 注入 content-hash（FNV-1a64）命名的 preload；探测先行：真 `getpwuid_r` 能用就完全 no-op；
- 用户名经 `BUN_OHOS_USERNAME` 传递（bun 侧用 shim 的 getpwuid_r 解析后写入子进程 env，见 `env_var.rs` 注册项）；
- preload 文件物化在 `$BUN_INSTALL/ohos` → `~/.bun/ohos` → `/data/storage/el2/base/.bun-ohos`，tmp+rename 原子写、每次 spawn 复检存在性（外部删除自愈）；
- 逃生口：`BUN_OHOS_NO_NODE_USERINFO`（检查子进程目标 env 而非仅自身进程 env）与 `OHOS_COMPAT_SHIM_DISABLE=getpwuid_r` 联动。

### 1.5 Bun.Terminal（`Terminal.rs`）

- **启动竞态**：`IOReader::read()` 可同步完成（slave 已关闭/读错误）并在 JS wrapper / exit 回调注册**之前**消费掉 one-shot 的 READER_DONE 通知 → 用户 exit 回调永不触发（~50% 复现）。修复：read 移到回调注册之后 + `deferred_exit` Cell 暂存、`init_terminal` 尾部重放。
- PTY master reader 注册进 **epoll rearm 看门狗**（见 §2.2）。
- openpty 的 dlopen 候选加 `libc.so`（musl/OHOS 把 openpty 编在 libc）+ `RTLD_DEFAULT` 回退。

### 1.6 DNS 与 socket

- `dns_jsc/dns.rs`：设备 `/proc/net/if_inet6` 只有 fe80::/10 链路本地 + ::1 → AF_UNSPEC 查询发 AAAA 必超时（EAI_AGAIN → DNS_ETIMEOUT）。`has_global_ipv6()` 检查存在 2000::/3 全球单播（排除 ULA——wlan0/vpn-tun 上常见的 fc00::/7 曾被误判）后决定是否强制 IPv4。
- `socket_body.rs`：`pending_fatal_send_errno` 锁存——5 个 `internal_flush` 调用者大多丢弃返回值，fatal send 的 errno 丢失导致 'drain' 误发、流静默截断（**未门控**，修正通用 errno 传递漏洞）。

### 1.7 诚实的 getcwd（`bun_core/util.rs`）

内嵌 shim 的 `getcwd()` 会把已删除 cwd **静默替换为 $HOME**（给其他调用者兜底）。但 `bun test`/`install` 的顶层目录解析需要真实失败（BUG-01：吞错会在不确定环境里跑 JS）——新增 `getcwd_honest()`：经 `/proc/self/cwd` readlink + stat 复核（缓冲截断视为"未删"避免 >PATH_MAX cwd 误报），真实已删则报 `CurrentWorkingDirectoryUnlinked`。`Arguments.rs`、`resolver/lib.rs`、`run_command.rs`（EPERM/EACCES 时回退 HOME 后解析并告警、且不以 fallback 的 package.json 播种 env）相应改用。

---

## 2. syscall / IO / spawn 兼容层（c2）

这一层是**已验证内核缺陷账本**，每条在代码注释中注明设备实测证据：

### 2.1 seccomp SIGSYS 家族（syscall 被杀而非返回错误）

| 缺陷 | 修复 |
|---|---|
| `openat2`（437）被 SIGSYS；RESOLVE_IN_ROOT 实际 EINVAL（syscall 本身被接受，探针测不出来） | `linux_syscall.rs`：`openat2_beneath/in_root` 无条件合成 ENOSYS，上层缓存并回退 openat |
| `fchmodat2`（452）被 SIGSYS（新版 glibc 的 fchmodat 内部走它） | `sys/lib.rs::fchmodat` 直接发 `SYS_fchmodat`（aarch64 #53） |
| `close_range` / `fchmodat2` 的 libc 符号层 | shim 拦截（§5.3） |
| `prctl(PR_SET_VMA)` | mimalloc `MI_NO_SET_VMA_NAME=1` |
| 未知被滤 syscall 兜底 | `crash_handler`：**SIGSYS 处理器跳过 SVC 指令、x0 = -ENOSYS**（仿 bionic），把进程杀死变成可恢复错误 |

### 2.2 epoll 缺陷家族（最深的坑）

1. **ADD 报 EEXIST**：已关闭 fd 的注册在内核残留、DEL 落到被复用的 fd 号 → 新 fd ADD EEXIST 且永不收事件 → 对 EEXIST 重发 **CTL_MOD** 重指向（同 poll 自身时也安全，且不会像 DEL+ADD 那样丢活注册）。
2. **注册成功但内核永不投递**（PTY master 实测，raw syscall 层逐字节核对过 ADD/MOD 返回值）：`epoll_rearm_watchdog` 模块——后台线程按 250ms→1s 指数退避对静默 fd 冗余 `CTL_MOD`（A/B 实测 5 次独立试验确认能"戳醒"）。仅 opt-in（`Flags::EpollRearmWatch`，目前只有 Bun.Terminal），带 `BUN_DISABLE_EPOLL_REARM_WATCHDOG` 逃生口；unregister 路径无条件 untrack 防 fd 复用继承 stale 条目。
3. **dup 共享 open file description**：Terminal 的 read_fd/write_fd 是同一 pty master 的两个 dup，对其中一个 `CTL_DEL` 会**永久孤立另一个**的内核注册 → `deinit_force_unregister_skip_ctl_del`：紧接 close(fd) 的 unregister 跳过显式 DEL（close 隐式移除）；仅 Linux/Android，kqueue 无此问题。
4. **CTL_DEL 报成功但事件照发**（PipeWriter 空缓冲唤醒风暴，ONESHOT 不自动 disarm 的内核）：显式 unregister + 风暴检测（同 fd 10ms 窗口 >20 次 → sleep 2ms），实测空闲 CPU 100% → 6–8%（`/proc/<pid>/stat` 为准）。
5. **pipe 就绪状态整体损坏**（数据在缓冲、FIONREAD 可见，但 poll/epoll—even 新建实例—永远报不可读；Node 同样中招）：shim 层注册表 + FIONREAD 合成 EPOLLIN（§5.3）。
6. **异步子进程退出检测挂死**：`Bun.serve` FIFO 场景后 pidfd+epoll 永不唤醒（子进程成僵尸、父事件循环线程 R 态自旋）→ `spawn_sys` **waiter thread 在 OHOS 默认常开**（poll(eventfd) 专用线程，绕开共享 epoll loop），VM init 时 `prewarm()`（顺带修了 fd 表快照把晚出现的 eventfd 当泄漏的测试问题）。
7. **spawnSync no-orphans 的 signalfd+pidfd 路径挂起** → OHOS 改 pidfd 进 poll 集（3 槽）+ 无 pidfd 时 100ms getppid 轮询；仅在确有 fd 要等时才撤 PDEATHSIG（继承 stdio 的 `bun run` 保留内核信号，维持 no-orphans 语义）。

### 2.3 文件系统与管道

- **pwritev2/preadv2 管道返回 ESPIPE** → 折入 RWF 禁用回退集（`read_nonblocking/write_nonblocking`）。
- **fs.linkSync → linkat**：musl 的 `link()` 编译为直达 `SYS_linkat` raw syscall，绕过 shim 的 `linkat` 符号 hook（裸 linkat 被沙箱 EACCES，libc `linkat` 符号经 shim 才成功——实测 strip 掉 shim 后 linkat 同样失败）。
- **statx 对 socket fd 返回 EBADF**（合法 fd 被拒，fstat 正常）→ EBADF 折入 fstat 回退；musl/ohos 无 statx wrapper → 手写内核 ABI 结构 + raw syscall（与 Android 同路径）。
- **inotify 假 IN_ATTRIB**：OHOS 安全标签机制在每次 IN_CREATE 前插入 ATTRIB（raw probe：设备 ATTR→CRE、容器 CRE）→ `attrib_shadowed_by_create` 前瞻抑制（同 read buffer 内 16 事件窗 + 跨读边界 2ms poll 复查的竞态处理），维持 Node "新条目首事件是 rename" 契约。
- **ParentDeathWatchdog**：设备内核无 `CONFIG_PROC_CHILDREN`（文件不存在被误判为"无子进程"，静默瘫痪整个清理）→ /proc 全扫描回退（pgrep/pstree 同法）。
- **tmpdir**：/tmp 是只读 erofs → 运行时 `access(W_OK)` 探测，回退 `/data/local/tmp` → `$HOME/tmp` → /tmp。
- **rlimit**：`ulimit -Sn 256 && exec bun`（设备实测）下 163840 目标 EPERM → 回退"提到硬限允许的最大值"（Node 语义）。
- **resolver**：沙箱对祖先目录（/、/storage）报 EACCES/EPERM 而非 ENOENT → OHOS 上视为 not-found、`'queue_walk` 跳过不可读祖先继续 BFS；tsconfig 读取同口径。
- **ReadFile 读循环并发竞态**（`webcore/blob/read_file.rs`）：IO watcher 线程每次就绪都无条件 `WorkPool::schedule`，多个 worker 可同时进 `do_read_loop` 读同一 fd、无同步地 `recv()` + 追加 buffer → `Bun.stdin.arrayBuffer()` >1MB 随机截断（实测 6 worker 并发；OHOS 的 stdio 是 AF_UNIX socketpair 所以高频暴露，**竞态本身全平台存在**）→ IDLE/RUNNING/RUNNING_PENDING 原子状态机串行化，迟到的唤醒不丢（owner 重排）。
- **SpawnSyncEventLoop**：目标时刻已过时 `wrapping_sub` 下溢成 sec=i64::MAX 的近似无限 epoll 超时（≤15ms 的 signal 超时挂死）→ OHOS 上钳到 EPOCH（其他平台保留合法多日超时）。
- **standalone_graph（`bun build --compile`）**：OHOS 上不用上游 `find_loaded_module`/vaddr 定位 → 手工解析 `/proc/self/exe` section headers 找 `.bun` 段（校验 shentsize=64、shstrndx 边界）+ `/proc/self/maps` 字节级解析（路径可能非 UTF-8、workspace 禁 str::lines/split）取 PIE load base；mmap `MAP_PRIVATE` 携带写权限供 JSC 就地 bytecode 变异；inject 前检测 stub 继承的旧 `.codesign`（描述的是 stub 不是产物）→ strip + 重签。

### 2.4 用户态 shebang 展开（`spawn_sys/shebang.rs` 新文件 + `spawn_process.rs`）

根因：文本脚本无处携带 `.codesign` 段 → 内核**拒绝 exec 任何脚本**，binfmt_script 交接过不了签名检查。方案：spawn 前读目标文件头，解析 `#!` 行（POSIX 单参数语义、CRLF 容忍、绝对路径校验、无 EOF 且缓冲填满时放弃避免截断解释器路径），把 exec 重写为 `[解释器, 可选参数, 脚本, 原参数...]`（脚本降级为只被 open+read 的 argv 项）。细节：

- 4096 字节读缓冲规避内核 binfmt_script 128 字节截断 bug（截断后路径碰巧仍是合法绝对路径时只报迷惑性 EACCES；沙箱 TMPDIR 路径常超 128 字节）；
- `ShebangRewrite` 所有权先行（每个 CString 先入 `_owned` 再取指针）——曾有可选参数 CString 提前 drop 导致 `env: '\310...'` 的回归，rewrite 测试锁定；
- 歧义/相对路径/无 EOF 一律回退原生 spawn（与内核行为一致）。

### 2.5 签名运行时集成（与 §4 联动）

- `spawn_process.rs`：spawn 返回 EACCES/EPERM → `repair_codesign_if_needed` 惰性重签后**重试一次**（取代 eager 检查——eager 对 ~100MB 二进制全文件 merkle 重算，fulltest 墙钟翻倍）。
- `sys/lib.rs`：`Bun__dlopen`——dlopen EPERM（未签 .node/.so；或段 stale——presence-only 检查放任 stale 段到内核被拒且无恢复）→ 惰性重签重试。
- `src/linker.lds`：导出 15 个 shim 符号（`syscall close_range getcwd getpwuid_r tmpfile linkat symlinkat splice getaddrinfo epoll_ctl epoll_wait epoll_pwait poll ppoll close`），使 dlopen 的原生模块也能被 interpose（版本脚本 `local:*` 在 lld 21 实测压过 `--export-dynamic-symbol`，这是唯一有效导出通道；非 OHOS 目标这些是 UND 导入，版本脚本对 UND 无效果——无影响）。

---

## 3. 包管理器（bun install）（c3）

- **OPENHARMONY OS 位**：`install_types/resolver_hooks.rs` 的 `OperatingSystem` 新增 `1 << 9`，`CURRENT = OPENHARMONY`，token `openharmony` 进 negatable_names 解析表。
- **lockfile 自愈迁移**（`lockfile/bun.lockb.rs`）：旧 lockfile 的 `LEGACY_ALL = ALL & !OPENHARMONY` 会让所有无 OS 限制的包被序列化成 `os: !openharmony`（错误排除 OHOS）；`NONE`（写方不认识的 token 全部折叠成 NONE，如 OHOS 支持前的 "openharmony"）会让 `@esbuild/openharmony-arm64` 在 OHOS 上被跳过、esbuild postinstall 失败。两者在加载时升级为 ALL（arch 同理）；理由：无限制包本就是 ALL，装错平台的平台包是惰性无害而缺失是致命。
- **SELinux 链接拒绝回退**：`copy_file_fallback()`（openat 打开 → 拷贝 → fchmod 保权限；目标创建 EACCES/EPERM 时 unlink 重试）接入 `PackageInstall`（File/Symlink 条目）、`Hardlinker`、`Symlinker`（新增 `IgnoreFailure` 策略）的所有 EPERM/EACCES 分支。
- **install 时补签**：`PackageInstaller` 安装成功后扫描包目录内 `.so`/`.node`，`repair_codesign_if_needed`（否则 dlopen 时才会在运行时撞上重签重试）。
- **node-gyp 工具链注入**：SDK 自带 clang 15 缺 C++20 `<source_location>` → 全局安装 env（`PackageManager.rs::configure_env_for_scripts_run`）与 lifecycle env（`PackageManagerLifecycle.rs`）都注入 `OHOS_CC`/`OHOS_CXX`/`OHOS_SYSROOT`（→ `--sysroot=` 进 CFLAGS/CXXFLAGS/LDFLAGS）；lifecycle 侧 OHOS_CC 无条件覆盖（安装 env 默认 CC=clang 同样缺头文件）。
- **bin 的执行位**：`bin.rs` `lchmod`（改符号链接本身，Linux 非标准）在 OHOS ENOSYS → `fchmodat(AT_FDCWD, ..., 0)`（跟随链接改目标文件）。
- **bun-node shim**（`bun run` 提供假 node）：tmp 目录 OHOS 用 `/data/storage/el2/base/tmp`；mkdir 后 chmod 0700（OHOS tmpfs 强制 setgid+组写，EEXIST 复检的 0o022 检查会挂，OHOS 上放行）。
- **npm manifest 缓存**：linkat 两连败后的第三次尝试——tmp_path 写入 + 原子 rename，防 quick_exit 留下 0 字节缓存文件（"manifest is invalid"）。
- **lifecycle cwd**：hmdfs 上 getcwd 不可靠且 cwd 为空/"/" 时 shell 会中止 → 回退 $HOME。

---

## 4. 签名体系：`src/ohos_sign` crate（c4，官方不存在）

### 4.1 背景

OHOS 内核在 **exec 和 dlopen 时校验 ELF 的 `.codesign` 段**（fs-verity 风格）：无段（EACCES）或段失效（文件被改后段仍描述旧内容，同样 EACCES）都拒绝。签名格式：4KB 对齐段内 `ElfSignInfo 8B 头（type=1 + payload len）+ 256B fs-verity descriptor + 32B SHA-256 签名`，后随 merkle 中间层字节。

### 4.2 crate 结构（纯 Rust、零外部依赖、std only）

| 文件 | 职责 |
|---|---|
| `sha256.rs` | 手写 FIPS 180-4（直接移植自 self-sign.c，无依赖） |
| `merkle.rs` | fs-verity merkle 树：4KB 叶子页哈希、`.codesign` 段所在页取零哈希、128 哈希/页向上构建、单页即根。与上游 binary-sign-tool `merkle_tree_builder.cpp::RunHashTask` 逐层对齐；返回 (root, 中间层字节)。内核对自签不校验树，但仍按上游布局写入段内（超 4KB 截断无害） |
| `descriptor.rs` | 256B fs-verity descriptor：v1/SHA-256/log2blocksize=12；`sign_size` 计算摘要时传 0、落盘传 32；`FLAG_SELF_SIGN=0x10`、`csVersion=3` |
| `elf.rs` | `parse_header`（SectionHeaderTable 结构体，校验 shentsize=64、SHT 边界）；shstrtab 按名找段；`has_codesign_section`（presence）；`has_valid_codesign`（**有效性**：descriptor.file_size == 实际文件长度 + 跳过 cs 段重算 merkle root 比对——存在 ≠ 有效，`--compile` 用运行中二进制做 stub，产物继承的段描述的是 stub）；`strip`（重建 SHT + shstrtab，处理 shstrndx 索引偏移与名字偏移平移）；`inject_codesign_section`（全部段尾 4KB 对齐插入，新 shstrtab/SHT 搬文件尾）；`sign(force)` |
| `lib.rs` | `sign_selfsign` / `sign_selfsign_with_strip` / `strip_codesign` / **`repair_codesign_if_needed`**（惰性修复入口：只在内核拒绝后调用——验证重算是全文件 hash；只处理常规文件，防 argv0=/dev/zero 这类 exec 拒绝后落进来无限读） |
| `bin/ohos_selfsign.rs` | CLI：`sign/check/verify/strip`（`--force`/`--output`）。`check` 仅查存在；`verify` 重算内核在 exec 时做的两项比对——**release 门禁必须用 verify** |
| `tests/` | sha256 KAT、merkle、elf_sign、descriptor_layout 四个集成测试 |

### 4.3 调用点全景（6 处）

1. spawn 拒绝重试（`spawn_process.rs`，§2.5）
2. dlopen 拒绝重试（`sys/lib.rs::Bun__dlopen`）
3. `bun build --compile` inject（`standalone_graph`：stub 带段则 strip+重签）
4. install 后扫 `.so`/`.node` 补签（`PackageInstaller`）
5. CI 发布预签（`ohos-build-github.yml` + `source.ts` host tool 链接后 `binary-sign-tool` 签名）
6. Rust 链接时 `-Clink-arg=--code-sign`（SDK 的 signing linker，`rust.ts`）

约束：`test/internal/source-lints/ohos-sign-call-sites.test.ts` 保证所有调用点都在 `target_env = "ohos"` cfg 内。依赖方（`runtime`/`spawn_sys`/`install`/`sys`/`standalone_graph` 的 Cargo.toml）全部是 `[target.'cfg(target_env = "ohos")'.dependencies]`。

---

## 5. 构建系统与工具链（c5）

### 5.1 OHOS 交叉编译支持

- **工具链**：`rust-toolchain.toml` + `aarch64-unknown-linux-ohos`（已升 Rust Tier 2，有预编译 std，不再是 `-Zbuild-std`）；LLVM 版本范围放宽为 `>=21.1.0 <23.0.0`（OHOS 需 LLVM 22 的 musl 兼容 libc++；`/opt/llvm-22.1.4` 加入搜索路径）。
- **编译 flag**（`flags.ts`）：`--target=aarch64-linux-ohos --sysroot=<ohosSysroot> -D__MUSL__ -D__OHOS__`；ARMv8.0 基线（`-march=armv8-a -mtune=cortex-a53`，无 LSE/dotprod/crypto——设备兼容）；`-fPIE` + 链接 `-pie -Wl,-dynamic-linker=/system/lib/ld-musl-aarch64.so.1`（**动态链接是刻意的：保 fork/clone 过 seccomp**）；`-nostartfiles` + 显式 musl `Scrt1.o/crti.o/crtn.o`（sysroot 无 GCC crt；**不是** `-nodefaultlibs`——会丢自编译的 compiler-rt）；`-nostdinc++` + 交叉 libc++(-abi)/libunwind（`-D_LIBCPP_PROVIDES_DEFAULT_RUNE_TABLE -D_LIBCPP_HAS_NO_LOCALIZATION`）；`-fno-c++-static-destructors`；`-std=gnu++23`；8MB 栈；`--allow-multiple-definition`（iostream stub 重复）；调试信息不压缩（host LLVM 无 zstd）。
- **config**（`config.ts`）：`os = "ohos"`、`unix` 覆盖 ohos、abi 固定 musl；SDK 探测链 `OHOS_SDK_ROOT → ~/setup-ohos-sdk → ~/ohos-sdk → /opt/ohos-sdk`（校验 `ohos/native/sysroot` 存在）；交叉 libc++/ICU 目录约定在 `build/ohos-cross-libs`、`build/ohos-icu/target`；`hostCc` 强制系统 GCC（build-time codegen 需要 GCC 的 crt 行为）；新增 `--ohos-sysroot/--ohos-sdk-root/--ohos-cross-libs/--ohos-icu-dir` 参数。
- **WebKit**（`deps/webkit.ts`）：OHOS prebuilt 走本地 bottle（`OHOS_WEBKIT_ROOT`，`brew install bun-webkit`，identity 校验）或 `--webkit=local` cmake（CMAKE_SYSTEM_NAME=Linux、`-lpthread` FindThreads 修正、ICU 工具指向 `ohos-icu/host/bin`）；ICU 静态库来自交叉 icu4c@78。
- **其他 deps**：mimalloc `MI_NO_SET_VMA_NAME`；c-ares config.h（无 `HAVE_MEMMEM`、无 `*_r` 变体——同 bionic 口径）；`patches/zstd/ohos-qsort-r.patch`（musl 无 `qsort_r` → 选择排序替代）；`patches/lolhtml/crate-type.patch`（去 cdylib）。
- **签名进构建图**（`source.ts`/`rust.ts`）：host tool 链接后 `binary-sign-tool sign -selfSign`（仅 OHOS host，Linux/Windows 该分支不生成）；cargo linker 可用 `OHOS_BUN_SIGNING_LINKER`（构建脚本产物也必须签名才能 exec）；`-Clink-arg=--code-sign`。

### 5.2 官方行为变更（非 OHOS 门控——对上游合并最重要）

| 变更 | 动机 |
|---|---|
| x64 基线 nehalem → **haswell**（`--baseline` 显式回退） | 官方后来也改 haswell（版本漂移，非 OHOS 需求） |
| linux ThinLTO → **full LTO**（darwin 保持 ThinLTO） | LLVM 22 的 ThinLTO 后端在 linux 上 miscompile JSC——DFG tier 正确性 bug + bundler hang（复现：`bun -e 'require("axobject-query")'`），跨模块导入/ICF/WPD 均已排除；代价：链接 14min vs 1.5min |
| PCH 无条件开启 | 交叉 lane 的 TU 依赖 PCH force-include 的 JSC 声明 |
| git revision pin 机制移除 | 简化（CI env 优先已足够） |
| 全 cross-compile `-Wno-undefined-var-template` | WebKit 模板静态成员在链接期解析，clang 严格告警 + `-Werror` |
| `rust-lld` 判定改为全版本比较 | clang 22.1.4 vs rustc 22.1.8 同主版本仍读不了对方 bitcode |
| `getgroups` 追加 egid、`is_executable_file` 三分支重写、statx EBADF 回退、ReadFile 读循环串行化、`pending_fatal_send_errno` | 见 §1/§2，均为通用正确性修复 |

### 5.3 `ohos_compat_shim.c`（1748 行新文件，编译进可执行文件）

原为 harmonybrew formula 的 LD_PRELOAD wrapper，现由 `shims.ts` 以 `shim_cc` 规则编译为普通 `.o` 直接进链接行（普通 .o 全量链接保证 interpose 生效），符号经 `linker.lds` 导出。每个拦截符号都是"探测先行、真实现优先、仅在 OHOS 特征性失败时回退"，`OHOS_COMPAT_SHIM_DISABLE=逗号列表` 按符号关闭（一次性解析成 bitmask）：

| 符号 | 根因 → 回退 |
|---|---|
| `close_range` / `syscall(SYS_close_range)` | 设备内核对**任意参数组合**无条件 SIGSYS → 上提 EINVAL 校验（设备内核不查 first>last）→ probe + 每次 SIGSYS-guarded 尝试（`CLOSE_RANGE_UNSHARE` 在 flags=0 探测通过后仍会独立 SIGSYS）→ `/proc/self/fd` 枚举（避免对 RLIMIT_NOFILE 线性扫）→ /proc 不可见时线性扫 |
| `fchmodat2` | SIGSYS → `fchmodat` 转发 `AT_SYMLINK_NOFOLLOW`（实测 musl 尊重；**曾因丢 flag 把 symlink chmod 逃逸成跟随**，bun 安装器的 symlink-path-traversal 防护依赖拒绝语义） |
| `getpwuid_r` | HAP uid（2002xxxx）无 /etc/passwd → `libos_account_ndk.so` `OH_OsAccount_GetName`（API 12+）→ env → `u<uid>` 合成 passwd；仅对自身 uid 合成（任意 uid 保持 ENOENT，Node initgroups 语义依赖） |
| `getaddrinfo` | ① 非法字符主机名被转发网络挂 ~4s（glibc 本地 EAI_NONAME）→ 快速本地拒绝（udp bind 失败测试跑 200 次）；② AI_ADDRCONFIG 滤掉 IPv4 loopback → 全 v6-loopback 结果时去 ADDRCONFIG 重查 AF_INET 并合并（Happy-Eyeballs 需要 v4 回退） |
| `tmpfile` | P_tmpdir 只读 → `$TMPDIR`/`$HOME` mkstemp + unlink；constructor 默认 `TMPDIR=/data/storage/el2/base/cache` |
| `getcwd` | 用户态父目录遍历在 hmdfs/tmpfs/已删 cwd 上 EACCES/ENOENT → `/proc/self/cwd` readlink（内核 d_path 无权限检查，**给真实 cwd 而非 $HOME 猜测**）→ stat ENOENT（真删）→ HOME 末选 |
| `linkat` / `symlinkat` | 沙箱 EPERM/EACCES → 同目录隐藏 tmp + renameat 原子字节拷贝（修复过 0 字节目标可见窗口）；symlinkat 的 target 按 **newdirfd** 解析（包管理器的相对符号链接语义） |
| `splice` | ① 源 EOF 报 EPIPE（coreutils cat 报 "Broken pipe" 退出 1）→ poll 区分：目的 POLLERR = 真 EPIPE，源 POLLHUP = 返回 0；② **写入 pipe 的字节不唤醒已阻塞的 poll/epoll**（`cat big | bun` 死锁）→ 目的为 FIFO 时 64KB 用户态缓冲中转（放弃零拷贝保正确性） |
| `epoll_ctl`/`epoll_wait`/`epoll_pwait`/`poll`/`ppoll`/`close` | pipe 就绪状态损坏（§2.2-5）→ FIFO+EPOLLIN 注册表（libc 符号与 raw `syscall(SYS_epoll_ctl)` 双入口，bun 的 Rust 事件循环走后者）；epoll_wait 250ms 切片 + FIONREAD 合成 EPOLLIN（切片对调用者隐藏：空 0 返回会 assert 崩 libuv/pnpm SIGABRT；ONESHOT 合成后标 disarmed；数据排空时补发一次 EOF 唤醒）；poll/ppoll 事后修 revents；close 清注册表防 fd 复用 |
| （注意）inline asm 直达 syscall 的代码**不经过** shim | bun 自己的 rustix `linux_raw` 路径（openat2/epoll_ctl 等）必须在源码层修——这就是 §2 存在的原因 |

### 5.4 测试 runner 基建（`utils.mjs` / `runner.node.mjs`）

`tmpdir()` TMPDIR 优先；`getUsername()` 对 ENOENT 回退 env/uid（OHOS 沙箱 uid 无 passwd，原来在跑任何测试前就崩）；`getCombinedPath` 在 OHOS 把 `brew --prefix llvm@21/bin` 排到 PATH 前（node-gyp 按 PATH 找 clang 不看 CC，ohos-sdk 的 clang 15 缺 C++20 头）；AF_UNIX 能力探测选 tmp root（hmdfs 上 `bind()` EPERM，unix-socket 测试全挂）；`NODE_TEST_DIR` 短路径（`sockaddr_un.sun_path` 108 字节上限）；OHOS 外层墙钟 ×3（fork/fs 慢 2–3 倍且墙钟无视文件级 timeout）；vendor 构建失败记为该套件失败而不炸整个 run（保住已跑结果与 results.json）；`getFileUrl` git 缺失 fail-soft。

---

## 6. CI / 发布 / 设备测试（c6）

### 6.1 CI 地图（新增 `.github/workflows/README.md` 一页索引）

| Workflow | 职责 | 触发 |
|---|---|---|
| `ohos-build-github.yml` | **权威构建 + 发布**：GitHub 托管 ARM（ubuntu-24.04-arm）+ social4hyq ci-runner 容器全量构建 + ohos-selfsign 预签 + verify 门禁 | push/PR 到交付分支；tag push → 版本化 release |
| `ohos-build-rust.yml` | 快速反馈：自托管 runner 增量 Rust 构建（sccache） | Rust 路径 push/PR |
| `ohos-brew-deps-canary.yml` | 漂移哨兵：浮动 tap tip 每日验收（绿+warning = tip 不可消费保持 pin；红 = 评估本身失败） | 每日 cron |
| `ohos-container-test.yml` | 容器内 JS 测试集（复用 build lane 的 artifact，无需设备） | 手动 / 本文件变更 |
| `ohos-full-test.yml` | 两段式：自托管构建 → 容器测试 | 手动（曾因 cron 在无 runner 时排队 24h 而移除 schedule） |
| `build-x86.yml` / `cross-x86.yml` | 官方 Buildkite 之外的 GitHub 托管补充矩阵：linux-x64/windows-x64/linux-arm64 native；aarch64 host 交叉（linux-x64 需 skopeo 现配 ubuntu:20.04 glibc 2.31 sysroot；windows-x64 走 xwin；**darwin-arm64 走 xmac 从 Apple CDN 拉 SDK + ld64.lld**） | 手动/workflow_call |

已删除 4 个从未运行的 lane（自托管 ohos-release 等，"run 永远排队"）；上游 oven-sh workflow **文件保持原样**（减少合并冲突），在 repo 设置层禁用。`rust-lints.yml` 增加 ohos-target clippy lane。

### 6.2 容器构建要点（`build-ohos-container.sh`，404 行）

- 容器是 musl 用户空间（跑不了 GHA 的 glibc node）→ `docker run -d` + `docker exec`，镜像 **digest pin**。
- **双 pin**：harmonybrew/core 与 bun formula tap 各 pin 到验证过的 commit（教训：浮动 core 一夜把 ohos-sdk 改名为无 sysroot 的 ohos-sdk-native，所有 PR 全红；bun formula 加了不存在的 gcc 依赖）。
- `brew trust` 时序：`safe.directory` → `brew trust` → `--only-dependencies`（trust 决定**传递依赖**能否加载，顺序错了 = 零依赖安装）。
- **自编译 `__n1` ABI libc++**：设备 `libc++_shared.so` 用 `_LIBCPP_ABI_NAMESPACE=__n1`，预编译交叉库是 `__1` → 从 LLVM 21.1.8 源码三段构建 libunwind → libcxx+libcxxabi（`-DLIBCXX_ABI_NAMESPACE=__n1`）+ musl patch（strtoll_l）+ `__config_site` 追加，llvm-nm 自检 `__n1` 符号。
- esbuild：OHOS node 报 `openharmony` 被 esbuild 平台表拒绝 → `ESBUILD_BINARY_PATH` 强制指向静态链接的 `@esbuild/linux-arm64`（bun 按平台过滤 optional dep，强制安装/直接解 tarball）。
- `GITHUB_SHA → GIT_SHA`：容器无 git，SHA 变 "unknown" 会让 `build_options` 的 `const_str_slice` 编译期 panic（E0080）。
- 设备路径模拟：`/system/bin/sh`、`/system/lib/ld-musl-aarch64.so.1` 符号链接。

### 6.3 发布管线（ohos-build-github 的 tag 路径）

- 产物：**签名 tar.gz（canonical）+ unsigned 变体**并排发布；push → `ohos-latest` 滚动 release + 5 平台 `latest`；tag push → 版本化 release（6 产物，页面自动生成）。
- 发布页约定：双语 Disclaimer/Known Limitations 置顶、tarball 一行安装（预签 = 解压即用，无安装脚本）、`release-docs` 分支自动播种占位 README、**资产存在性校验作为发布门禁**。
- 网络受限环境的代理：checkout/clone 走 `ghfast.top`。

### 6.4 设备全量测试闭环（`ohos/fulltest/`）

- `launch-fulltest.sh` 固化测试 env（单一事实源）：`PARALLEL=2`（设备无 swap，3 worker 并发抽中 leak 测试即 OOM 死锁）、`RETRIES=2`、`BUN_GARBAGE_COLLECTOR_LEVEL=0`（缺失时顶层 `bun test` import `bun:internal-for-testing` ENOENT → ~181 fail）、`GITHUB_ACTIONS=false`（避免 GHA 专属断言）。
- `deploy-test-tree.sh` 部署测试树到设备；`run-all-official-progress-optimized.sh`（435 行）为 runner；经 `hdc shell` + `setsid` 后台执行；`bun-test-report-latest.md` 为最近一轮设备报告样例；`OHOS-Bun-全量测试指导.md` 为完整操作手册。
- `ohos/` 工作区本体（issues/knowledge/analys/skills）见 `ohos/README.md` 的任务路由。

---

## 7. 测试树与质量保障（c7）

**规模**：127 文件，+3,942 / −1,709。分布：test/js/bun 30、test/cli/install 29、test/js/node 18、test/internal/source-lints 8、test/cli/run 6、test/regression 5、其余零散。

### 7.1 harness 基建（`test/harness.ts`）

`isOHOS` 常量；`isLinux` 覆盖 openharmony（"Linux-like enough"）；`libcFamily` OHOS=musl；`TERM=dumb` 修复（触发 node:readline `_ttyWriteDumb` 降级路径，readline/REPL 系全挂）；`GITHUB_API_URL` OHOS 默认走 gh-proxy（GitHub 不可达）；ABI 匹配 node 时 OHOS 优先 `node-ohos`（brew 的 GCC 工具链 node 装不了 `__n1` addon，NODE_MODULE_VERSION 相同但符号 mangling 不同）；docker arm64 禁用判断**前移到健康探测之前**（CI 硬错误会炸整个文件而非跳过套件）。

### 7.2 skip 账本机制（核心质量控制）

`test/internal/source-lints/ohos-skip-inventory.json`（102 行）+ `ohos-skip-inventory.test.ts` lint：

- **双向登记**：`skipped-on-device`（skip 在设备报告里不可见——曾发生同步了参考树的 node-userinfo 测试但没移植运行时功能，skip 完全遮住了缺口）与 `device-only`（CI 永远跳过，必须记录设备上真正跑起来需要什么）。
- 规则：每个条件含 `isOHOS` 的 `skip*()` 必须登记；条目需非空 `reason` + `device_plan`；rename/删除导致的 stale 条目也 fail；"untriaged" 是合法 reason，"没登记"不是。
- 典型条目：esbuild 二进制可用性（等 corpus 升版本）、openat2 路由错误面（永久豁免候选——内核限制）、fs 负时间戳、TLS SNI/http proxy（untriaged）。

### 7.3 device-only 新测试

- `os-ohos.test.ts`：平台语义**精确值**（`platform==="openharmony"`、`machine()==="aarch64"`——上游宽松成员断言抓不住 machine 误报、`type()==="Linux"`、userInfo 不抛）。
- `spawn-ohos-node-userinfo.test.ts`：设备 PATH 必须有**真 node**（bun-as-node shim 内嵌 shim 会让 preload 探测 no-op 假通过）。

### 7.4 回归新测试

- `spawn-stdin-large-buffer.test.ts`：>1MB 管道写截断（write 返回 0 被当 EOF 提前关管道、子进程收到垃圾——HongMeng，阈值 1–2MB，2/4/8KB×N 规格锁定）。
- `linker-lds-shim-exports.test.ts`：shim 符号必须在 linker.lds 全局导出表内。
- source-lints：`ohos-libc-detection`（IS_OHOS/IS_MUSL 用法）、`ohos-platform-reporting`（openharmony 分支语义）、`ohos-sign-call-sites`（§4.3）、`ohos-skip-inventory`（§7.2）。

### 7.5 既有测试修改模式

平台假设修正（`isLinux`/`-ohos` target 字符串/`openharmony` platform 值）、install 系路径与符号链接语义（依赖 fchmodat2 NOFOLLOW 拒绝等）、fs pre-epoch 负时间戳表现、超时/并发参数。配套：`expectations.txt`、`vendor.json`、`package.json`、`bun.lock`。

---

## 8. 总结

### 8.1 模块对照总表

| 模块 | 文件数 | 新增文件 | 核心主题 |
|---|---|---|---|
| 1 平台识别 + JS 绑定 | ~28 | `ohos_node_userinfo.rs` | openharmony 平台注册、spawn $PWD、PTY tcsetattr、node 子进程 os.userInfo、诚实的 getcwd |
| 2 syscall/IO/spawn | ~25 | `shebang.rs` | SIGSYS 家族、epoll 五连缺陷 + 看门狗、shebang 用户态展开、签名运行时集成、`--compile` OHOS ELF 定位 |
| 3 包管理器 | 13 | — | OPENHARMONY OS 位、lockfile 自愈、SELinux 拷贝回退、install 补签、node-gyp 工具链 |
| 4 签名 crate | 11（全新增） | `src/ohos_sign/**` | fs-verity 自签：SHA-256/merkle/ELF 段操作/惰性修复/CLI |
| 5 构建系统 | ~20 | `ohos_compat_shim.c`、2 个 vendor patch | 交叉工具链、10 符号 interposer 内嵌、LTO/PCH/x64 基线变更 |
| 6 CI/发布 | ~20 | 8 workflows + 容器脚本 + fulltest | 容器构建 + 双 pin + 预签发布 + 设备 fulltest 闭环 |
| 7 测试树 | 127 | ~15 | skip 账本、device-only 语义测试、平台假设修正 |

### 8.2 对官方行为的非门控变更清单（上游合并时需重点核对）

1. `getgroups` 追加 egid（对齐 Node 文档）
2. `is_executable_file`：Linux 无 O_EXEC 分支改为检查**任意** x 位（原来只查 user x）
3. statx 对 EBADF 回退 fstat（Linux 路径）
4. `ReadFile` 读循环并发串行化（全平台正确性修复）
5. socket `pending_fatal_send_errno` 锁存
6. x64 基线 haswell、linux full LTO、PCH 常开、全 cross `-Wno-undefined-var-template`
7. git revision pin 机制移除
8. `getcwd_or_exe_dir` 的 OHOS 分支之外，`getcwd_honest` 是纯新增函数（无行为影响）

其余差异均在 `target_env = "ohos"` / `__OHOS__` / `cfg.ohos` / `isOHOS` 门控之内，对官方平台无行为影响。

### 8.3 复现/更新方式

按 §raw 的命令重新生成分簇 diff；整体校验用 `git diff bun-v1.4.2 HEAD --stat`。跨树移植前的排除法（空 diff 排除区域）沿用 `ohos/README.md` 硬性规则 4（参考构建 61dbc3a9d）。
