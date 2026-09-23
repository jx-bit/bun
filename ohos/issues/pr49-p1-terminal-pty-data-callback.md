# P1: Bun.Terminal PTY data 回调永不触发 / exit 通知启动期丢失 — 归档文档

> **关联 PR**：[#49](https://github.com/jx-bit/bun/pull/49)（单 commit
> `e6a4f2d7af`，1 文件 `src/runtime/api/bun/Terminal.rs` +90/−13，base
> `ohos-aarch64` tip `615b48e958`）
> **状态**：✅ 合并（3238ce0da1）
> **定位**：delivery line 全量轮 26286 TIMEOUT 根因——上游回归测试
> `test/regression/issue/26286.test.ts`（AsyncLocalStorage 内 Terminal data
> 回调）在设备上 data 永不交付 → 挂到超时；同根因面波及全部
> Terminal / spawn-with-terminal 用例。
> **家族**：OHOS 特有 fd/内核行为差异第四例（前例：#39 waiter 线程预热、
> #37 uSockets epoll_pwait2 禁用、#43 openat2 门控）。

## 0. 证据来源与参照线地位（先说清楚）

**参照线不是官方。** 本文所称"参照线"= 另一条独立的 OHOS 移植线（仓库
`social4hyq/ohos-bun`，非 oven-sh 上游、非本仓交付基、**不构成规范来源**）；
基线锚 `61dbc3a9d`（全 SHA `61dbc3a9d7d02c5c4b78c7f683c0b86aa77b6bf6`，
其全量轮 PASS 的 1.4.0 基参考构建），tip 即其 `ohos-aarch64` 分支头。

上游 **oven-sh/bun `bun/main`** 的 `Terminal.rs` 无任何 OHOS 处理
（`grep -c "OHOS|EPOLL_REARM_WATCH|deferred_exit"` = 0）——本缺陷不存在
"官方实现"可对照。因此本 PR 的正确性立论**不依赖参照线的权威性**，依据是：

1. **根因机制分析**（§2，各层可独立验证）；
2. **设备实测证据**：看门狗机制本身的真机 A/B（§2.2 引
   `posix_event_loop.rs` 文档注释，#32 落库时记录）、openpty 真机
   preflight（§2.4）；
3. **上游排除法**（ohos/README 规则 4：`git diff 我方 61dbc3a9d -- 该簇`
   逐 hunk 归属核对，见 §3.2）。

参照线在本修复中只提供两样东西：**(a) patch 形态候选**（省去从零设计，
但形态正确性仍由 §2 机制独立支撑）；**(b) 真机验证锚点**（其基线探针
09 607ms 可达 = "修好后该路径可在设备上跑通"的可行性证明，非正确性证明）。
证据类型标注沿用台账惯例：〔源码〕逐字核验 / 〔实测〕binary 或真机行为 /
〔推断〕机制反推。

## 1. 现象与影响

`Bun.Terminal`（PTY）+ `Bun.spawn({ terminal })`，设备实测分层观测：

| 观测层 | 结果 | 说明 |
|---|---|---|
| PTY 建立（openpty 三 fd） | ✅ | master/read/write/slave 就绪 |
| 子进程写 slave | ✅ | 数据确实到达 master 侧缓冲 |
| epoll 注册 | ✅"成功" | `register_poll` 返回成功 |
| **data 回调** | ❌ **永不触发** | 内核不交付事件，测试挂到超时 |

全量轮 26286 TIMEOUT。伴生影响：`exit` 回调以条件依赖方式被静默丢弃
（§2.3，参照线在 `BUN_JSC_randomIntegrityAuditRate=1.0` 压力下约 50% 复现）。

## 2. 排查与根因（三层）

### 2.1 排除层

| 层 | 结论 | 证据 |
|---|---|---|
| 上游 oven-sh（bun/main）Terminal.rs vs 我方（修复前） | **零差异**——排除上游实现漂移，我方 = 上游原样 | 〔源码〕逐字节 diff |
| 本仓 `src/io/` 基建 | 看门狗基建已在（#32，commit `7f99b314fd`），非回归源 | 〔源码〕diff 审阅 |
| 探针分层观测 | PTY 建立/写 slave/注册全通过，唯事件交付缺失 → 缺陷在"注册成功但内核不交付"层 | 〔实测〕设备探针 |

### 2.2 根因 A（直接）：PTY master fd 类 OHOS 内核 epoll 缺陷 + 看门狗登记缺失

**内核缺陷表现型**：对该 fd 类，`epoll_ctl(ADD)` 返回成功，但内核永不交付
可读事件。`posix_event_loop.rs:1318-1322`（#32 落库时的真机取证）记录：
"registration calls and their return codes were verified byte-for-byte
correct on a real device that never went on to fire `on_poll`"——与探针
观测逐层吻合。PTY master 在 `Terminal.rs` 中按管道语义注册
（`NONBLOCKING | POLLABLE`，"PTY behaves like a pipe, not a socket"），
与 #32 管道捕获缺陷（CTL_DEL dup 孤立）同属 OHOS 内核 epoll 缺陷家族，
但 fd 类与表现位置不同。

**关键缺口细节**〔源码，grep 全树核验〕：`PosixFlags::EPOLL_REARM_WATCH`
（`PipeReader.rs:220`，bit 1<<11）及看门狗本体随 #32 落库，io 层两处文档
注释都写明消费者是 "`Bun.Terminal`'s PTY-master reader"（`PipeReader.rs:215-220`、
`posix_event_loop.rs:1324-1328`）——但**修复前全树不存在任何
`flags.insert(PosixFlags::EPOLL_REARM_WATCH)` 生产点**（唯一相关触点
`PipeReader.rs:562` 只是把 reader flag 转投到 poll flag）。即：#32 只落了
基建半边，Terminal 侧的登记半行缺失，看门狗自落库以来实际跟踪的 fd 集合
为空。本 PR 的 line 560 是全树第一个也是唯一的登记点。

**看门狗机制**（`posix_event_loop.rs` `mod epoll_rearm_watchdog`，
`#cfg(any(target_os = "linux", target_os = "android"))`）：

- **opt-in 制**：仅 `FilePollFlag::EpollRearmWatch` 标记的 fd 被跟踪
  （"targeted fix for a fd class with confirmed exposure, not a blanket
  tax"，`posix_event_loop.rs:1324-1328`）——非全局兜底税。
- **解除卡死手段**：看门狗线程对该 fd 发一次冗余
  `epoll_ctl(CTL_MOD)`（userdata 逐字节回填，`Entry.userdata` 注释
  `posix_event_loop.rs:1354-1357`）。真机 A/B（原型 3 组配对 + 本实现
  5 组独立试验）证实该冗余 MOD 可靠解除卡死。
- **退避**：`BASE_POKE_INTERVAL=250ms` → 每次 poke 翻倍 →
  `MAX_POKE_INTERVAL=1000ms`，tick 100ms；任何真实注册活动（新 ADD 或
  自然 WouldBlock 驱动的 MOD）重置回基准。健康活跃 fd 永远累积不到
  poke；只有真静默（卡死或合法空闲）的 fd 被触碰，且冗余 MOD 本身无害。
- **Kill switch**：`BUN_DISABLE_EPOLL_REARM_WATCHDOG=1`
  （`posix_event_loop.rs:1368-1373`）。

### 2.3 根因 B（伴生）：启动时序烧掉 one-shot exit 通知

修复前 `init_terminal` 顺序：`IOReader::read()` 在 JS wrapper 与回调注册
**之前**（我方修复前 line 552-555）。`on_reader_finished` 一次性
（`Flags::READER_DONE` 守卫，Terminal.rs:1859-1861）。三个同步驱动者：
`writer.start()`、`reader.start()`、`read()`——任一在启动期同步完成
（slave 已关、读错误）即内联驱动 `on_reader_done/on_reader_error →
on_reader_finished`，此刻 `this_value` 仍为 `JsRef::empty()`、`Exit` 回调
未注册 → 通知在 `try_get` / `gc::get(Exit)` 处静默丢弃，且 `READER_DONE`
已置位 → 用户 `exit` 回调**永不触发**，后续任何调用（含用户自己的
`close()`）都命中守卫直接返回。〔实测〕参照线约 50% 复现（压力条件见
§1）；插桩显示终局 terminal 携 `READER_DONE=true` 进入 `close_internal`
且全程零 dispatch。

### 2.4 根因 C（伴生）：openpty 解析序缺口（musl/OHOS）

修复前 `lib_util::get_handle` 的 dlopen 探测表（我方修复前 line 899-911）：
`libutil.so → libutil.so.1 → libc.so.6`，三点：

1. musl/OHOS 的 openpty 在 **`libc.so`**（glibc 才分 libutil），表内无此条目；
2. `dlsym_with_handle!` 只查 dlopen 句柄内的符号，句柄全部落空时直接
   `None`——无 `RTLD_DEFAULT` 兜底（`RTLD_DEFAULT` 搜全局符号空间，
   覆盖已随进程加载的 libc）；
3. 失败后果：`get_open_pty_fn()` 返回 `None` → PTY 建立即失败（不同于
   根因 A 的"建成功但不交付"）。

平台影响面〔源码〕：macOS/FreeBSD 走直链符号（`#[cfg]` 分支，不经
lib_util）；Windows ConPTY 不经 openpty；受影响的是
`target_os = "linux" | "android"`（含 OHOS——OHOS target 的
`target_os` 即 linux 系）。〔实测〕参照线 ohos-preflight
`i17_openpty_libc`（2026-06-15）验证 libc.so 条目 + RTLD_DEFAULT 兜底
在设备可达。

## 3. 修复（逐 hunk，三方行号锚点）

### 3.1 hunk 清单

移植源 = 参照线**基线** `61dbc3a9d7d02`（非 tip——同基线锚定规避两线
~350 行无关演进漂移，先例 #32 方法论）。行号对照：我方修复前行号 /
我方修复后行号（commit `e6a4f2d7af`）/ 参照 tip 行号：

| hunk | 内容 | 我方修复前 | 我方修复后 | 参照 tip | 证据 |
|---|---|---|---|---|---|
| H1 | `deferred_exit: Cell<Option<i32>>` 字段 + 文档 | —（原无） | :131 | :118 | 〔源码〕逐字同 |
| H2 | init `deferred_exit: Cell::new(None)` | — | :463 | :423 | 〔源码〕逐字同 |
| H3 | reader enroll 块尾 `r.flags.insert(PosixFlags::EPOLL_REARM_WATCH)`（`if let Some(poll)` 块**外**——无论有无 poll 句柄都登记，flag 语义由消费端检查兜住） | — | :560 | :507-508 | 〔源码〕逐字同 |
| H4 | 删除原 `read()` 调用位（原 :552-555，wrapper/回调注册之前） | :552-555 | — | — | 〔源码〕 |
| H5 | `read()` 移到**末位**（wrapper + 三回调注册之后）+ 长注释论证 | — | :589-610 | ~:537-541 | 〔源码〕逐字同（另补回原 SAFETY 行，见 §3.3） |
| H6 | 重放块：`deferred_exit.take()` → `this_value.downgrade()` → `call_exit_callback(code, None)` | — | :614-622 | :544 | 〔源码〕逐字同 |
| H7 | `lib_util` 文档注释 + 探测表 3→4 项（追加 `libc.so`） | :878, :899-904 | :924, :945-953 | :836, :862-870 | 〔源码〕逐字同（注释措辞随基线） |
| H8 | `get_open_pty` RTLD_DEFAULT 兜底 | :914-916 | :966-977 | :877-884 | 〔源码〕语义同、形态适配（§3.3） |
| H9 | `get_open_pty_fn` 注释（linux/android/OHOS 归属） | :942-943 | :977-978 | — | 〔源码〕 |
| H10 | `on_reader_finished`：`this_value.is_empty()` → `deferred_exit.set(Some(exit_code))` 暂存；else 原路径 | :1866-1871 | :1933-1943 | :1834 | 〔源码〕逐字同 |

### 3.2 漂移控制（排除法核对）

- `git diff dev 61dbc3a9d -- src/runtime/api/bun/Terminal.rs` 全量
  166 行 = 恰好 H1-H10（无其他 hunk）——移植完成后我方文件与基线
  **逐字节一致**（`diff` 空输出，已在移植时验证）。
- 基线 vs 参照 tip diff 350 行：三个 patch 区域内仅注释措辞漂移
  （如 tip :507 单行短注释 vs 基线多行长注释），代码零差异 → 从基线取
  即为终版形态；其余 ~350 行为参照线无关演进，**不取**（勿混，规则 4）。
- 我方基建前提核验〔源码〕：`EPOLL_REARM_WATCH` bit 位（1<<11）、
  `PipeReader.rs:561-563` 转投点、看门狗开关名——与参照线一致（#32/#34
  已对齐），无基建缺口。

### 3.3 与参照的形态偏离（lint 适配，零行为差异）

本仓 clippy 以 `-D clippy::undocumented_unsafe_blocks` /
`-D clippy::missing_transmute_annotations` 运行，参照的裸
`transmute` 单行写法不过本地门禁。适配内容：

- RTLD_DEFAULT 兜底改写为
  `core::mem::transmute_copy::<*mut c_void, OpenPtyFn>(&p)` + SAFETY 注释，
  镜像 `dlsym_with_handle!` 宏（`src/sys/lib.rs:6186-6197`）的既有惯用法。
  语义等价论证〔源码〕：`transmute_copy(&p)` 与 `transmute(p)` 同为按尺寸
  reinterpret（`OpenPtyFn` 为 fn 指针，与 `*mut c_void` 同尺寸），非空检查
  路径不变 → 运行时行为逐指令等价；
- H5 移位后的 `read()` 调用补回上游原 SAFETY 两行（原注释随调用点移动）；
- rustfmt 将兜底单行 `if..else` 拆多行。

## 4. 验证记录

### 4.1 本机（构建机无 clang≥21，`bun bd` 不可用——与 #37/#40-#44 同链路，
编译门禁由 CI 容器承担）

| 门禁 | 命令 | 结果 |
|---|---|---|
| host 编译 | `cargo check -p bun_runtime --lib`（`RUSTUP_TOOLCHAIN` 绕过 toml 全量 target 重同步） | ✅ 18.95s |
| **交付 target 编译** | `cargo check -p bun_runtime --lib --target=aarch64-unknown-linux-ohos` | ✅ 1m47s（lint 适配后复跑 ✅ 11.3s） |
| clippy | `cargo clippy -p bun_runtime --lib` | 初跑 4 error（3× undocumented_unsafe_blocks @ :610/:969/:970 + 1× missing_transmute_annotations @ :970）→ §3.3 适配后 ✅ 1m33s |
| rustfmt | `cargo fmt -p bun_runtime --check` | 初跑 1 diff（:970 单行）→ 适配后 ✅ |
| dead-code 账本 | `USE_SYSTEM_BUN=1 bun test test/internal/source-lints/dead-code-escapes.test.ts` | ✅ 24 pass / 0 fail（账本无需再生） |
| 移植完整性 | `diff 我方 61dbc3a9d 版` | ✅ 空输出（逐字节一致，lint 适配前） |

（行号 :610/:969/:970 为适配前位置；适配后见 §3.1。）

### 4.2 CI / 设备（验收标准，PR 合并链路）

- CI 容器构建全绿（编译门禁，全 lane 含 container）。
- **未修复构建上必失败声明**：`test/regression/issue/26286.test.ts` 在
  未修复交付线构建上设备侧 data 回调永不交付 → TIMEOUT（已实锚，
  全量轮 26286 现状）。
- 设备验收：探针 09-pty-terminal.js PASS（参照线基线已证 607ms 可达，
  佐证"修好后该路径一分钟内可验收"）+ `26286.test.ts` PASS + 全量轮
  26286 不再 TIMEOUT。

## 5. 与参照移植线的对比（social4hyq/ohos-bun，非官方）

**结论：三个 patch 的代码形态与参照基线（61dbc3a9d）一致、与参照 tip
零代码差异；唯一形态偏离是本仓 lint 适配（§3.3，语义等价）。参照线的
角色是实现形态候选 + 验证锚点，不是正确性依据——正确性依据见 §0 三条。**

| 项 | 参照线（基线 61dbc3a9d / tip） | 本 PR（e6a4f2d7af） | 证据类型 |
|---|---|---|---|
| EPOLL_REARM_WATCH 登记 | 同一 flag、同一插入位（enroll 块尾、`if let` 外） | 逐字同（:560） | 〔源码〕逐字节核验 |
| deferred_exit 字段/init/重放/on_reader_finished 暂存 | 一致 | 逐字同（:131/:463/:614-622/:1933-1943） | 〔源码〕基线 vs tip 零差异核验 |
| read() 末位启动 | 一致（含论证注释） | 逐字同 + 补回原 SAFETY 行 | 〔源码〕逐字节核验 |
| openpty `libc.so` 条目 | 一致 | 逐字同（:952） | 〔源码〕逐字节核验 |
| RTLD_DEFAULT 兜底 | `transmute` 裸转换（tip :877-884） | `transmute_copy` + SAFETY（宏惯用法） | 〔源码〕语义等价核验；行为不变〔推断〕 |
| 看门狗基建 | 参照线自带并已接线 | 我方 #32 已落基建（7f99b314fd），**接线半行缺失至本 PR 补上**（全树唯一 insert 点） | 〔源码〕grep + git log -S 核验 |
| 上游状态 | — | oven-sh bun/main 无任何 OHOS 处理（grep = 0）：无官方实现可对照，本修复属 OHOS 交付线自有适配 | 〔源码〕grep 核验 |
| 看门狗有效性 | 参照线真机 PASS | 独立证据在我方基建文档：真机 A/B（3 配对 + 5 独立）CTL_MOD unstick | 〔实测〕posix_event_loop.rs:1318-1322 |
| openpty 可达性 | 参照线 preflight i17 | 同一机制面（dlopen 表 + RTLD_DEFAULT），设备 preflight 已证 | 〔实测〕 |
| 移植完整性 | tip 另有 ~350 行无关演进 | **不取**（与本缺陷无关，防混入） | 〔源码〕基线 vs tip diff 逐 hunk 核对 |
| 暴露差异 | tip 注释为单行短式 | 沿基线长注释（含 #32 取证引用）+ lint 适配 | 〔源码〕 |
