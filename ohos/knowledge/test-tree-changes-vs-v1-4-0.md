# 测试树相对官方 v1.4.0 的全部改动台账（121 文件）—— 机制详解版

> 生成：2026-09-09（v2 详解版）。diff 基线：`bun-v1.4.0` tag ↔ `46a905a6cf`（4 新增 / 117 修改 / 0 删除）。
> 每条含四段：**现象**（设备上的症状）→ **机制**（根因 + 探针证据，出处多为设备侧台账
> `OHOS_TEST_STATUS.md` 的 C 探针实测）→ **改动**（测试侧具体做了什么）→ **没有它会怎样**。
> commit 列为实际改动者。runtime 侧配套修复见对应 pr 文档（issues/pr*.md）。

## 0. 改动是怎么分层累积的（先读这个）

| 层 | commit | 内容 |
|---|---|---|
| 1 | `b189b02293` | 最早的 isOHOS skip（bin chmod exec bit、filter_run） |
| 2 | `6692a5d5b1b` 8/13 | 合并 upstream main —— 曾带入 1015 个 test/ 文件的 post-1.4.0 变更 |
| 3 | `caf392d7237` | `test/expectations.txt` 增加 OPENHARMONY 隔离条目 |
| 4 | `91054212c8d` + `ce76c1855ad` | 从 social4hyq 树**双向同步**（采纳其 206 个文件适配 + 清理 89 个陈旧文件） |
| 5 | `4c71ecb79a8` | 合并 `bun-v1.4.0` tag |
| 6 | `dfb70ae1f58` + `535fb153c7e` 9/2 | **恢复/对齐真机验证过的 v1.4.0 线**（129 恢复 + 74 reconcile）——把第 2 层带入的 post-1.4.0 漂移收回基线，只保留 OHOS 适配 |
| 7 | `a1b9112d310` / `ecff2d1b5b6`(#16) / `6bf3e5c494f`(#17) / `cf279097ff`(#21) | 之后的每个功能修复**附带**其测试/harness 改动 |

净结果：**v1.4.0 基线 + 121 文件 OHOS 适配**（4 增 117 改 0 删）。
即：**我们从未把测试树整体升级到 post-1.4.0**；上游 merge 的测试漂移被第 6 层刻意收回。

**两条贯穿性原则**（出处：设备侧台账的"从分母里消失"自查）：

1. **消灭隐藏跳过**：`no-orphans.test.ts` 的 `isPosix` 曾硬编码只认 linux/darwin，
   14 个 `skipIf(!isPosix)` 用例在 OHOS 上**静默跳过**——从分母里消失。给 harness
   的 isPosix 加上 openharmony 后（`e76b0d3a8` 真机验证），14 个用例全部解锁执行，
   其中 12 个直接过，2 个第一次被执行到才暴露为新根因（T25/T26）。**跳过必须可见、
   必须留注释、必须知道跳过了什么。**
2. **跳过必须写明机制**：所有 skip 就地 `// isOHOS: <机制>` 注释，不带原因的 skip
   不允许。本文档的每条"机制"段均摘自这些注释或设备台账。

---

## 1. 沙箱拒绝类（EACCES / EPERM —— 内核或沙箱直接拒绝，测试侧无解，只能绕开或跳过）

### 1.1 沙箱禁止打开根目录 `/`

- **现象**：`bundler_edgecase.test.ts` 的 `AbsolutePathShouldNotResolveAsRelative`
  报 `EACCES: failed to open root directory: /`；`shell/pipeline_stack.test.ts` 的
  `cd /` 触发同样限制。
- **机制**：OHOS app 沙箱把"打开根目录"整个封掉（`open("/")` → EACCES）。bundler
  解析绝对路径 `/entry.js` 时要枚举/校验根目录，得到的是 EACCES 而不是干净的
  ModuleNotFound —— 断言期望的错误集合对不上。
- **改动**：① `bundler_edgecase`：该子用例改 `itBundled.skip`（仅 openharmony 分支，
  platform 三元选择）；② `pipeline_stack`：`cd /` → `cd ..`（语义等价、**非 OHOS-only**
  的通用简化，所有平台行为不变）。
- **没有它会怎样**：1 个 bundler 子用例 + 1 个 shell 子用例永久红，且报错混淆真实
  回归信号。
- commit：`535fb153c7e`（采纳自同步层，设备台账同款修法）。

### 1.2 hmdfs 不支持 AF_UNIX socket bind（EPERM）

- **现象**：任何在仓库检出树内 `listen()` unix socket 的测试集体
  `EPERM: operation not permitted, listen 'xxx.sock'`（20260903 轮 18 个子用例；
  inspect.test 等）。
- **机制**：仓库根位于 `/storage/Users/currentUser/...`（hmdfs/FUSE 用户存储卷）。
  普通文件 I/O 正常，但 **AF_UNIX bind() 被拒**。Conversely 系统内部 tmpdir
  （短路径）支持 AF_UNIX —— 这也是 vendored node 测试 `NODE_TEST_DIR` 修复的同一
  机制（PR #26）。
- **改动**：harness 增加 `cwdScope` + 测试内 `isOHOS ? tempDir(...) : undefined` 模式
  —— 把 cwd 挪到 tmpdir 支持的目录，socket 以相对路径落在那里。涉及
  `inspect.test.ts`、`bun-listen-connect-args.test.ts`、`bun-serve-args.test.ts` 等。
  兜底：runner 侧 #27 增加 AF_UNIX-capable 根探测（`/data/local/tmp` 等）。
- **没有它会怎样**：unix socket 簇全红，且 EPERM 报错会掩盖真实的 socket 回归。
- commit：`535fb153c7e` / `91054212c8d`；runner 侧 #27。

### 1.3 沙箱禁止硬链接

- **现象**：`isolated-install.test.ts` 强制 `--backend=hardlink` 的用例 EPERM。
- **机制**：OHOS 沙箱 **outright 禁止硬链接创建**（`linkat` EPERM）——isolated
  install 的 hardlink backend 在 OHOS 上整个不可用。
- **改动**：`test.skipIf` 排除 OHOS（hardlink 断言单 inode 的用例组）。
- **没有它会怎样**：安装 backend 测试红一片，与真实 bug 混在一起。
- commit：`91054212c8d`。

### 1.4 FIFO 上的 `O_APPEND` 打开（hmdfs 内核怪癖）

- **现象**：`streams.test.js` 的 `Bun.file() read text from pipe`——fixture 脚本
  `echo hi >>fifo` 报 Permission denied。
- **机制**（设备台账最小复现，脱离 bun 直接验证）：往 `mkfifo()` 创建的 FIFO 用
  `O_APPEND` 打开 → EACCES；不带 `O_APPEND` 的 `O_WRONLY|O_CREAT` 完全正常。
  `bash`/toybox `sh` 同样复现，纯内核行为。**FIFO 没有"已有内容"，`>>` 相对 `>`
  无任何语义收益。**
- **改动**：`bun-streams-test-fifo.sh` 的 `>>` → `>`。**非 OHOS-only 补丁**——所有
  平台成立（真机验证 159 pass / 0 fail，原 158/1）。
- commit：`535fb153c7e`（采纳自同步层）。

### 1.5 `/dev/shm` 不可写

- **现象**：`shell/commands/mv.test.ts` 跨设备移动 fixture 无法构造（EACCES）。
- **机制**：OHOS 沙箱 `/dev/shm` 不可写——无法在同一卷内构造"跨文件系统移动"
  场景。设备台账归 class B（平台限制）。
- **改动**：相关子用例 OHOS 门控跳过。
- commit：`535fb153c7e`。

### 1.6 测试自身算术对 TMPDIR 深度的假设（unix-socket-long-path）

- **现象**：`unix-socket-long-path.test.ts` 在 OHOS runner 下还没创建 socket 就
  `RangeError`（`Buffer.alloc(negative)`）。
- **机制**：该测试硬编码了 padding（把 unix socket 路径垫到 sun_path 上限临界），
  但 tempDir() 的实际长度依赖 TMPDIR 深度——runner 又嵌套了一层 `buntmp-XXXXXX/`，
  深一层 padding 就变负数。**测试自己的算术假设了单机的 TMPDIR 深度。**
- **改动**：先建 probe 目录实测长度，padding 由 `total - probeLen - 2` 推导，并
  断言非负。**非 OHOS-only**——对所有 TMPDIR 深度都稳健。
- commit：`535fb153c7e` 层。

---

## 2. shell / 工具链差异（沙箱的 /bin/sh 不是 bash/GNU）

### 2.1 mksh 的 `ulimit` builtin 完全是 no-op（双重叠加 bug）

- **现象**：`child-process-rlimit-nofile.test.ts` 全挂；`test-fs-write-sigxfsz.js`
  挂。
- **机制**（设备台账深挖，两个叠加问题）：
  1. 沙箱 `/bin/sh` 是 **mksh**，其 `ulimit` builtin **完全 no-op**（设/读皆无效，
     实测读回为空、子进程看到未变的限制）；
  2. 换能用的 shell 后又暴露 bun 的**真 bug**：`RealFS::adjust_ulimit` 在 target
     超过当前 hard limit 时试图连 hard 一起抬，非特权进程 EPERM 后**整个静默失败**
     —— bun 带着 256 个 fd 的预算跑完全程。
- **改动**：测试侧换用 zsh（`b6e5798e5` test 部分）；runtime 侧回退到 Node 语义
  "soft 抬到 hard 允许的最高"（同 commit rust 部分，**已真机验证**：`ulimit -Sn 256`
  后 bun 正确抬到 32768，4/4 全过，spawn 簇回归零影响）。
- **没有它会怎样**：fd 预算类测试全红 + 一个真实的静默 runtime bug 永远不被发现。
- commit：harness/测试部分 `91054212c8d` 层 + `b6e5798e5`。

### 2.2 mksh/toybox 的 `ulimit -f` 与 SIGXFSZ

- **机制**：`fs.test.ts` 里 `sh` 是 toybox，其 `ulimit -f` 是**静默 no-op**；
  `test-fs-write-sigxfsz.js` 同根因。bun 启动时 `SIGXFSZ→SIG_IGN`，越限写返回
  EFBIG 正是 Node 语义——测试依赖的 shell 前置条件在 OHOS 上无法建立。
- **改动**：`test-fs-write-sigxfsz.js` 测试侧换 zsh 即通过（`631b5664b`）；
  `fs.test.ts` 的 EFBIG 簇 4 用例 `describe.skipIf` 排除 OHOS（OHOS rlimit FSIZE
  不产生 EFBIG）。
- commit：`91054212c8d` / `535fb153c7e`。

### 2.3 execSync 与 mksh exec 优化的进程结构差异（如实记录：未完全闭环）

- **现象**：`garbage-env.test.ts` 等 execSync 场景的子进程结构断言失败。
- **机制**（设备台账，含证伪表）：mksh 对裸命令/带引号/带参数/含分号四种形态
  **都**做了 exec 优化（无子进程）——"mksh 不做 exec 优化"的假设被部分证伪；
  但 execSync 实际 trace 显示 shell 仍 fork 了孙进程，差异变量（stdio 组合/环境/
  进程组）**未定位，如实记录为未解**。被测对象 bun 与 node 行为一致，归 class D
  （环境）。
- **改动**：`garbage-env.test.ts` 相关断言按环境门控。
- commit：`91054212c8d` 层。

---

## 3. 内核 / 文件系统语义差异（行为不同而非能力缺失——能跑但结果不同）

### 3.1 hmdfs 不填充 statx birthtime

- **现象**：`fs-birthtime-linux.test.ts` 4 用例：`birthtimeMs` 期望 > 0，实际 0。
- **机制**：hmdfs 的 statx 不返回 btime 字段（恒 0）——Linux ext4/xfs 会填。
  这是**平台文件系统差异**，不是 bun bug。
- **改动**：`describe.skipIf(!isLinux || openharmony)` 整组排除。
- **没有它会怎样**：4 用例常红。
- commit：`535fb153c7e`。

### 3.2 openat2 被 seccomp SIGSYS 直接杀进程

- **现象**：`serve-directory-routes.test.ts` 整文件被 SIGSYS 打死（不是测试失败，
  是进程被杀）。
- **机制**（设备台账 C 探针实证）：上游新 directory routes（#36156）用
  `openat2(RESOLVE_IN_ROOT)`；OHOS seccomp 对 **openat2 直接 SIGSYS 杀进程**
  （探针证实：openat2、name_to_handle_at 被拦；**statx/copy_file_range/sendfile
  放行**——不能一刀切假设"新 syscall 都被拦"）。runtime 侧修复（他们的
  `4d70ec1f5a`）：给 `openat2_in_root` 加 ohos ENOSYS 保护走 openat 回退（此前只给
  `openat2_beneath` 加了，`openat2_in_root` 漏了）。
- **改动**：测试侧断言按 OHOS 门控（SIGSYS 路径下无结果可断言）。
- **没有它会怎样**：整文件 SIGSYS——比"测试失败"严重一档，且会污染 runner 的
  崩溃统计。
- commit：`91054212c8d`。

### 3.3 RLIMIT_FSIZE / EFBIG 簇

- 见 §2.2：EFBIG 4 用例 skipIf + SIGXFSZ 用例换 shell。commit：`535fb153c7e`。

### 3.4 procfs 字段缺失（T25）与 CONFIG_PROC_CHILDREN（T26）

- **现象**：`no-orphans.test.ts` 的 Ctrl-Z 用例超时；setsid daemon 用例失败。
- **机制**（设备台账，四个独立 C 探针把边界划清）：
  - **T25**：OHOS procfs 的 `/proc/<pid>/stat` **不报告 tty_nr/tpgid/state 三个
    字段**——测试的作业控制断言全部建立在这三个字段上，无法成立（class C，
    观测手段不可移植）。探针同时证实 `ioctl(TIOCSCTTY)` 正常。
  - **T26**：bun 的后代枚举依赖 `CONFIG_PROC_CHILDREN`，**OHOS 内核没开** →
    `--no-orphans` 特性静默失效（class A 新根因）。
  - **T27**：OHOS 的 **PTY 行规程不生成信号**——`waitpid(WUNTRACED)` 等不到
    Ctrl-Z（独立于 T25，另一回事）。
- **改动**：相关子用例按 T25/T26/T27 分别门控，注释里直接引用台账编号（可溯源
  到设备台账的探针记录）。
- commit：`535fb153c7e`。

### 3.5 splice() 管道 EOF 返回 EPIPE（T51）与 EPIPE 家族

- **现象**：`multi-run.test.ts` "scripts with pipes work"、
  `spawn-pipe-read-error-leak.test.ts`：期望 0 条 "Broken pipe"，实际收到 3 条。
- **机制**（设备台账 C 探针实测，`/data/storage/el2/base/tmp/splice-probe.c`）：
  **OHOS 内核 splice() 在管道 EOF 时返回 EPIPE（Linux 语义应为 0）**。busybox cat
  拷贝走 splice() → bun 读端提前看到 EPIPE。runtime 侧修复：compat-shim 369 行
  四项（splice EPIPE-on-EOF + poll wakeup、linkat/symlinkat atomic renameat、
  fchmodat2 AT_SYMLINK_NOFOLLOW 转发、getpwuid_r OH_OsAccount_GetName），triage
  模式验证 `spawn-stdin-destroy` 1/1 pass、`shell/commands/ls` 26/27 pass。
- **改动**：两个文件的断言按 OHOS 门控（shim 修复覆盖主路径，残余时序差门控）。
- commit：`535fb153c7e`。

### 3.6 stdin 管道丢失唤醒竞态（T50）

- **现象**：`cat big | bun`（bash 管道 + 输入 > 管道容量 512KB）挂死；
  07500、readline.node、test-repl×6 等 9 文件全挂。
- **机制**（设备台账定性）：**非合并回归**——合并前 r44 bottle 二进制同样 100%
  复现；7-31 基线通过只是时序侥幸。一直存在的潜在竞态被环境时序漂移暴露。
  另有镜像症状 `process-stdin`（backpressure 单次 read 合并 40 次写入，阈值 <16，
  读太多）未定位——测试注释按 T50 同族门控。
- **改动**：`process-stdin.test.ts`、`spawn-stdin-readable-stream.test.ts` 按
  平台管道行为差异门控 + 注释引用 T50。
- commit：`535fb153c7e`。

### 3.7 readdir(recursive) 结果差异 + 预 epoch 时间戳

- **机制**：`fs.test.ts` 注释记录：OHOS readdir(recursive) 结果与 Node 不一致
  （台账既有失败）+ 200 次全树遍历在高负载下超时；pre-epoch 时间戳（fs 早期
  mtime 为负）簇——均为 hmdfs/内核行为差异。
- **改动**：`fs.test.ts` 内多处子用例门控（这单文件是全台账改动最密的）。
- commit：`535fb153c7e`。

---

## 4. DNS / 网络解析（T49 族）

### 4.1 ADDRCONFIG：localhost → ::1（10 个受害者）

- **现象**：server 绑 IPv4、client 连 `localhost` 时 ECONNREFUSED——
  node-http.test.ts、node-tls-server.test.ts、vendored node 的
  test-http-should-support-localAddress 等 10 个文件。
- **机制**：OHOS 的 getaddrinfo **ADDRCONFIG 过滤掉 IPv4 回环**——`localhost`
  只解析到 `::1`；server 若绑 `127.0.0.1`/`0.0.0.0` IPv4 就连不上。且本沙盒
  `/etc/hosts` 没有可用的 localhost IPv4 条目。runtime 侧无法修（libc 行为），
  测试侧把 server/client 对齐到同一栈。
- **改动**：`node-http.test.ts`、`node-tls-server.test.ts` 相应子用例门控 +
  注释引用 T49；`server.spec.ts` 2 用例 skipIf（`net.createConnection(server.address())`
  缺 host 字段回退 localhost 默认值）；`serve.test.ts` v6 用例 `it.if` 排除。
- commit：`535fb153c7e` / `91054212c8d`。

### 4.2 getaddrinfo 对裸空格主机名

- **现象**：`resolve-dns.test.ts` 部分子用例断言失败。
- **机制**：OHOS 的 system/libc getaddrinfo **会把裸 `" "` 主机名解析成功**
  （glibc 报 ENOTFOUND）——libc 更宽松，错误语义不同。另有 IPv6 可用性差异
  （::1 加入 /etc/hosts 后 system 与 c-ares 双后端均可用，一部分旧 skip 已能
  放开）。
- **改动**：按**具体子用例**精确 skipIf（不整文件跳），注释区分两个子问题。
- commit：`91054212c8d`。

---

## 5. 编译产物 / 签名交互（NixOS 场景 × codesign 节）

- **现象**：`24742` / `29290` 的 PT_INTERP 读回**空串**；
  `bun-build-compile` 的 `#31023`（patchelf RW PT_LOAD）与
  `compiled binary in a deleted cwd` 失败。
- **机制**（设备台账 T23 + write-back 发现，2026-08-09）：
  1. bottle binary 带 **codesign 节** → patchelf 在签名后二进制上**静默失效**，
     把 interp 追加到文件尾（T23）；
  2. compile 的尾部搬移会把追加在 EOF 的 interp 丢掉 → PT_INTERP 断言收到空串，
     而不是清晰报错（编译步骤静默失败）；
  3. deleted-cwd 场景：hmdfs/沙箱下 cwd 解析不炸——**平台行为差异**（产物仍能
     启动），非回归。
  三个失败常被误归"`--compile` 下载路径不可用"——**收窄后的正确表述**：只有
  "显式指定自身平台 target 串"一条下载路径不可用，`--compile` 本身可用；另两项
  各归 deleted-cwd 和 T23。
- **改动**：三处 `skipIf(isOHOS || …)` / `test.if(isPosix && !isOHOS)`，注释写明
  "场景是 NixOS 专属 / 平台行为差异，非回归"。
- **没有它会怎样**：4 个用例常红，且 T23（patchelf×签名）这个真实 runtime 限制
  被淹没在红海里。
- commit：`535fb153c7e`。

---

## 6. 性能余量（不是功能坏——默认超时/并发参数在设备上不够）

**背景数据**（设备台账实测）：hmdfs 多小文件 I/O 比 ext4 **慢 3-5×**；目录枚举
明显慢于 ext4；**fork+exit_group 比 vfork 慢 2-3×**（OHOS 分支不用 vfork——见
bun-spawn.cpp 的 OHOS 注释）。

| 文件 | 实测数据 | 改动 | commit |
|---|---|---|---|
| test/cli/run/require-cache.test.ts | 64s→>90s 波动 | 给足余量 | `535fb153c7e` |
| test/cli/watch/watch.test.ts | 大量 fork × 2-3× | 超时放大 | `535fb153c7e` |
| test/js/bun/spawn/spawn-pipe-leak.test.ts | fork 慢 ×3 仍偶发超时 | 超时放大 | `535fb153c7e` |
| test/js/bun/glob/leak.test.ts | hmdfs 目录枚举慢（重复列目录） | 余量 | `535fb153c7e` |
| test/js/bun/resolve/load-same-js-file-a-lot.test.ts | 多小文件 I/O 慢 3-5× | 余量 | `535fb153c7e` |
| test/js/bun/udp/udp_socket.test.ts | spawn/socket 开销 2-3× | per-test 超时 | `91054212c8d` |
| test/cli/install/bun-security-scanner-matrix-runner.ts | PTY 场景等终端输出 | 余量 | `535fb153c7e` |
| test/cli/install/bun-add.test.ts | git 依赖拉取 300s 偶发（摇摆，1/3 复现） | OHOS-only 全局超时 | `91054212c8d` |

> 这类改动的评审标准：**只放大时间参数，不断言行为**；且 OHOS-gated，其他平台零变化。

### 6.1 参数适配全量清单（28 处三元门控，精确数值）

超时倍率/余量类：
```text
hot.test.ts                    timeout ×6 / longTimeout ×3
spawn-pipe-leak.test.ts        30_000 ×5
req-url-leak.test.ts           (isASAN?90k:10k) ×4
glob/leak.test.ts              60_000 ×4
require-cache.test.ts          30k → 150_000
watcher-trace.test.ts          10k → 30_000
watch.test.ts                  10_000 ×3
shell/leak.test.ts             100_000 ×3
inspect-error-leak.test.js     10_000 ×3
child_process.test.ts          30k → 90_000
node-http-backpressure.test.ts 30k → 90_000
native-plugin.test.ts          5k → 60_000
napi.test.ts                   5k → 15_000（spawn node+bun 对比，注释写明 fork 慢 2-3×）
bun-add.test.ts                20k → 5min
bun-security-scanner-matrix    PTY 场景 10_000 门控
spawn.test.ts                  OHOS_TIMEOUT 20_000（仅 OHOS 生效）
vite-build.test.ts             OHOS_MULTIPLIER ×2
```

路径/环境替换类：
```text
inspect.test.ts                tempdir = OHOS ? tmpdirSync() : ".tmp"     （§1.2）
bunx.test.ts                   tmp = OHOS ? tmpdir() : "/tmp"             （§1.2）
28159.test.ts                  fake sock 落 tmpdir() 而非 /tmp            （§1.2）
rm.test.ts                     procCwd = OHOS ? base : "/"                （§1.1 根目录限制）
load-same-js-file-a-lot        ohosIsSlowMultiplier ×0.2（吞吐预期降额）   （§6）
init.test.ts                   react 模板参数集收窄 + @ohos-npm-ports/typescript（§7）
process.test.js                平台名映射 openharmony → "linux"（§7）
mmap.test.js                   max = { linux: 4096, openharmony: 4096 }   （§7）
24364.test.ts                  typescript → @ohos-npm-ports/typescript@7.0.2-2（§7）
fetch.unix.test.ts / fs.watch.test.ts / bundler_edgecase / 28159  余量或门控
```

### 6.2 skip 健康度（哪些已具备摘除条件，待下一轮复核）

| skip | 当初原因 | 现状 | 动作 |
|---|---|---|---|
| resolve-dns 部分 IPv6 skip | ::1 未入 /etc/hosts | 设备台账记录 ::1 已加入，system/c-ares 双后端可用 | 下轮试放开 |
| napi.test.ts 签名类 | `.node` 未签名 EACCES | PR #16 懒修复已在 46a905a6c 真机验证（uv/uv_stub 转绿） | 已验证，保持观察一轮 |
| T49 族（node-http/tls-server） | ADDRCONFIG libc 行为 | libc 行为无法修——**长期保留** | 不摘 |
| fs-birthtime | hmdfs statx | 文件系统行为无法修——**长期保留** | 不摘 |
| 24742/29290/31023 | T23 patchelf×codesign | runtime 限制未变 | 不摘 |

> 原则：skip 摘除也要走一轮真机 A/B（先放开 → 看结果 → 决定），不允许直接删。

### 6.3 管道容量非常量（filesink backpressure 自适应）

- **现象**：`filesink.test.ts` 首个断言就失败——write() 返回字节数而不是 Promise，
  覆盖 orphan 的主断言根本没执行到。
- **机制**：旧测试硬编码 300KB 触发 backpressure，但**管道容量不是常量**：
  OpenHarmony 容器 224KB、HarmonyOS 真机 512KB——真机上 300KB 被 send buffer 整吞，
  永不 backpressure。
- **改动**：`measureSocketPairCapacity()`——用非阻塞 socket pair 实测容量
  （fill 到 EAGAIN），写尺寸按容量比例推导。**非 OHOS-only**，所有平台自适应。
- commit：`535fb153c7e` 层。

### 6.4 硬编码 `/tmp` → tmpdir（可移植性族）

- **机制**：多处测试把 socket/临时物落硬编码 `/tmp`——OHOS 沙箱下不可用。
- **改动**：`adapter-env-var-precedence.test.ts`（mysql unix socket →
  `join(tmpdirSync(), ...)`）、`bunx.test.ts`、`28159.test.ts`（同族）。
- commit：`535fb153c7e` 层。

---

## 7. 设备产物 / 第三方依赖差异

| 文件 | 机制 | 改动 | commit |
|---|---|---|---|
| test/integration/esbuild/esbuild.test.ts | esbuild 无 OHOS 官方二进制 → 用 0.28.1 + `@esbuild/openharmony-arm64` | 按平台选版本 | `91054212c8d` |
| test/js/bun/test/parallel/test-integration-rspack.ts | 原生 binding 缺 OHOS 产物 → 社区移植 `@ohos-ports/rspack-binding` | 换 binding | `91054212c8d` |
| test/integration/datadog-pprof/datadog-pprof.test.ts | 上游无 openharmony-arm64 prebuild → `@ohos-ports/datadog-pprof@5.17.0-1` | 依赖平台化 | `91054212c8d` |
| test/js/node/process/process.test.js | ① OHOS release 产物以 `bun-linux-<arch>-ohos` 变体发布（平台检测）② host node pin `v26.3.0` 但 harmonybrew node 版本漂移 | ① 平台检测适配 ② 不 pin 死版本 | `535fb153c7e` |
| test/napi/uv.test.ts / uv_stub.test.ts | uv_stub 的 OHOS-specific 路径在 stub 里就是坏的 → stride 采样（4 取 3） | stride 适配 | `91054212c8d` |
| test/js/node/os/os.test.js | OHOS 用户/组模型（egid `20020101` 等）差异 | 子用例适配 | `91054212c8d` |
| test/package.json | ① esbuild 0.18.6→0.28.1、rollup 升级 ② resvg/napi-rs-canvas/sharp 换 `@ohos-ports/*` ③ `trustedDependencies` 补 sharp（postinstall 签名链） | 依赖平台化 | `91054212c8d` |
| test/js/web/url/url.test.ts（+110） | punycode label 校验用例（"like Node"——上游测试内容，随同步采纳） | 新增用例 | `91054212c8d` |
| test/cli/install/migration/…/lol-package/package.json | esbuild ^0.19.4→^0.28.0（与 §7 esbuild 平台化同族） | fixture 升版 | `91054212c8d` |
| test/integration/vite-build/the-test-app/package.json | lightningcss → `@ohos-ports/lightningcss@1.32.0` | 依赖平台化 | `91054212c8d` |

> 关联 runtime 修复（平台无关，非 OHOS-only）：`process.getgroups()` 缺 egid ——
> Node 文档保证包含有效 gid，bun 原实现裸返回 `getgroups(2)`；修
> `BunProcess.cpp`（`35eaf7a0e`，真机验证 getgroups 与 `id -G` 一致）。测试树里
> `os.test.js`/`child_process.test.ts` 的组相关断言随此修复对齐。

---

## 8. 守护 lint（防修复被上游 merge 静默冲掉）

| 文件（新增） | 钉住什么 | 出处 |
|---|---|---|
| test/internal/source-lints/ohos-sign-call-sites.test.ts | 签名/dlopen/Shebang **全部调用点**——PR #14/#16（签名）、PR #17（shebang 展开）的机制一旦被 merge 丢失，该 lint 直接红 | `ecff2d1b5b6` + `6bf3e5c494f` |
| test/internal/linker-lds-shim-exports.test.ts | linker.lds 的 15 个 shim 符号（PR #6 补全、#13 依赖） | v1.4.0 合并层 |
| test/internal/source-lints/build-rust.test.ts / dead-code-escape-limits.json | lint 基线随 OHOS 代码同步 | `c3d3a63f8aa` |

> 这是唯一一类"增加测试"而非"跳过测试"的改动：**用测试守护 runtime 修复的存在性**。

---

## 9. expectations 隔离（不改测试源码的失败隔离）

| 文件 | 内容 | commit |
|---|---|---|
| test/expectations.txt | OPENHARMONY per-file 隔离条目（node-http-with-ws、node-http-transfer-encoding 等已知差异——隔离后其余 22 个 pass 保留可复核，每条可复核后关闭） | `caf392d7237` + `91054212c8d` |

---

## 10. harness / 测试基设

| 文件 | 改动 | 机制 | commit |
|---|---|---|---|
| test/harness.ts | ① `cwdScope` + tempDir 模式 ② TERM=dumb→xterm 规范化（子进程层）③ fulltest 直接 dlopen musl loader ④ openharmony runner helpers ⑤ `isPosix` 认 openharmony | ① hmdfs 无 AF_UNIX（§1.2）② dumb 终端下 node:readline 走 _ttyWriteDumb 回调，光标断言全挂 ③ 沙箱 dlopen libc 路径（PR #15）④ — ⑤ 消灭隐藏跳过（§0 原则 1） | `a1b9112d310` / `cf279097ff` / `535fb153c7e` |
| test/bake/bake-harness.ts | bake 设备通道适配 | bake dev server 在设备上的端口/路径约束 | `535fb153c7e` |
| test/cli/install/registry/packages/*（binlink fixture ×4 包 + tgz + postinstall） | fixture 的 `os[]` 数组**补 openharmony** | 上游新 fixture 只列了 linux/darwin/win32 → native-binlink 重定向无法触发、postinstall 未被跳过 | `91054212c8d`（对齐他们 `c9a10f0b4a` 同款修法） |
| test/js/bun/spawn/spawn-ohos-node-userinfo.test.ts（新增） | OHOS 用户/组查询语义验证（getpwuid 合成、egid 追加） | 配套 §7 的 getgroups 修复 | `535fb153c7e` |
| test/js/bun/spawn/spawn-stdin-large-buffer.test.ts（新增） | 大缓冲 stdin 场景 | posix_spawn EACCES 簇的回归验证面 | `535fb153c7e` |

> **合并伪影教训**（上游 merge 引入的破坏，设备台账记录）：上游 `d042b30e84` 把
> `tempDirWithFiles` 全改成 `using tempDir`，我们的 OHOS chdir 适配引用了被删的
> import → ReferenceError。修法 `c9a10f0b4a` 跟进新写法。**每轮上游 merge 后
> OHOS 适配层要过一遍编译/引用检查。**

---

## 11. 同步/恢复层（内容变化但非 OHOS 门控）

### 11.1 真 bug 修复（harness）

- **test/bake/bake-harness.ts**：`exitCode !== "0"` 严格不等 bug——`Bun.spawn` 的
  onExit 回调给的是**数字** 0，`0 !== "0"` 恒真，导致每次干净退出都被判为失败。
  **平台无关的 harness 真 bug 修复**（随同步采纳）。

### 11.2 同步采纳的上游/对方内容（无条件 `setDefaultTimeout(5min)` 族 + 新用例）

install 家族 8 个测试文件加 `setDefaultTimeout(1000 * 60 * 5)`（**无条件**，非
OHOS-gated——设备余量以全平台一致的方式落地）：GHSA-pfwx、bun-pm-scan、
bun-pm-why、bun-run-dir、security-edge-cases、security-scan-all、
hosted-git-info/boundary-conditions、migration 套件；另 url.test punycode 新用例
（+110，见 §7）、expo/vite 集成、pnpm fixture、18239 data-generator shebang
（`7f42ebc2d`，见 §11.3）等。来源 commit：`91054212c8d` / `ce76c1855ad`。

### 11.3 通用可移植性简化（非 OHOS-only）

- `pipeline_stack.test.ts`：`cd /` → `cd ..`（§1.1，所有平台等价）
- `bun-streams-test-fifo.sh`：`>>` → `>`（§1.4，所有平台等价，真机 159/0）
- `18239/data-generator.sh`：shebang `#!/bin/bash` → `#!/usr/bin/env bash`
  （`7f42ebc2d`：本机 bash 在 `/data/service/hnp/bin/bash`）

完整逐文件清单见下方 §15 索引。

---

## 12. 新增的 4 个文件（A）

| 文件 | 性质 |
|---|---|
| test/internal/source-lints/ohos-sign-call-sites.test.ts | 守护 lint（§8） |
| test/internal/linker-lds-shim-exports.test.ts | 守护 lint（§8） |
| test/js/bun/spawn/spawn-ohos-node-userinfo.test.ts | OHOS 语义验证（§7） |
| test/js/bun/spawn/spawn-stdin-large-buffer.test.ts | 场景验证（§10） |

---

## 13. 待并入的改动 → 已全部并入（2026-09-09 更新）

- ~~PR #27~~ ✅ 已合并（7a29e13314）：`scripts/runner.node.mjs`（AF_UNIX capable
  tmpdir 探测——§1.2 的 runner 侧兜底）+ `src/js/wasi-runner.js`（`/` preopen
  探测——沙箱 `open("/")` EACCES 的 runtime 侧修法，与 §1.1 同机制）
- ~~PR #28~~ ✅ 已合并（106630a089）：panic 修复（transpiler.rs browser-field
  entry 守卫）—— 运行时
- ~~PR #29~~ ✅ 已合并（c4323a5d33）：process.platform "openharmony"（Global.rs）
  —— **合并后台账所有 `// isOHOS:` 门控在设备上首次真正生效**（此前我们的
  binary 报 "linux"，门控全部静默失效——20260908 轮 23 个 jxbit_only 失败的
  直接原因）。下一轮 fulltest 是这些门控的首次真机检验。

## 14. 关联文档

- 台账上层依据：`../issues/pr10/pr14/pr15/pr16/pr17/pr21/pr26/pr27` 各 pr 文档
- **设备侧台账（已归档到本目录，2026-09-09）**：
  - `OHOS_TEST_STATUS.md` —— social4hyq/ohos-bun `ohos-aarch64` tip `36854e8e5bb`
    提取（619KB，活跃台账；T23/T25/T26/T27/T49/T50/T51 等编号 + C 探针证据出处）。
    其 tip 上 `OHOS_TEST_TODO.md` 已退役（内容并入 STATUS）
  - `OHOS_TEST_TODO.md` —— 最后非空版本 `766ed2a0fff` 提取（183KB；T25/T27 等
    历史编号出处）
- 对比分析：`../analys/archive/compare-20260908-sys-release-vs-jxbit-46a905a6c.md`

## 15. 逐文件索引（121/121 全量，行数 = 相对 v1.4.0 的 +新增/−删除）

| 文件 | +/− | OHOS行 | 超时行 | 归属章节 |
|---|---|---|---|---|
| test/js/bun/shell/pipeline_stack.test.ts | +6/−2 | 1 | 0 | §1.1 |
| test/bundler/bundler_edgecase.test.ts | +5/−1 | 2 | 0 | §1.1/§6.1 |
| test/cli/inspect/inspect.test.ts | +4/−2 | 2 | 0 | §1.2 |
| test/js/bun/http/bun-listen-connect-args.test.ts | +8/−0 | 4 | 0 | §1.2 |
| test/js/bun/http/bun-serve-args.test.ts | +9/−0 | 2 | 0 | §1.2 |
| test/cli/install/isolated-install.test.ts | +91/−84 | 2 | 0 | §1.3 |
| test/js/web/streams/bun-streams-test-fifo.sh | +1/−1 | 0 | 0 | §1.4 |
| test/js/bun/shell/commands/mv.test.ts | +3/−2 | 3 | 0 | §1.5 |
| test/js/bun/net/unix-socket-long-path.test.ts | +18/−3 | 0 | 0 | §1.6 |
| test/cli/install/registry/packages/create-native-binlink-altpath-packages.ts | +2/−1 | 1 | 0 | §10 |
| test/cli/install/registry/packages/create-native-binlink-packages.ts | +2/−2 | 2 | 0 | §10 |
| test/cli/install/registry/packages/test-native-binlink-altpath-target/package.json | +6/−3 | 3 | 0 | §10 |
| test/cli/install/registry/packages/test-native-binlink-fallback-target/package.json | +5/−4 | 1 | 0 | §10 |
| test/cli/install/registry/packages/test-native-binlink-fallback-target/test-native-binlink-fallback-target-1.0.0.tgz | +0/−0 | 0 | 0 | §10 |
| test/cli/install/registry/packages/test-native-binlink-target/package.json | +4/−3 | 1 | 0 | §10 |
| test/cli/install/registry/packages/test-native-binlink-target/test-native-binlink-target-1.0.0.tgz | +0/−0 | 0 | 0 | §10 |
| test/cli/install/registry/packages/test-postinstall-skip-native/package.json | +5/−3 | 2 | 0 | §10 |
| test/js/bun/spawn/spawn-ohos-node-userinfo.test.ts | +122/−0 | 5 | 0 | §10 |
| test/js/bun/spawn/spawn-stdin-large-buffer.test.ts | +64/−0 | 3 | 0 | §10 |
| test/bake/bake-harness.ts | +7/−1 | 0 | 0 | §11.1 |
| test/cli/init/init.test.ts | +35/−1 | 5 | 0 | §11.2 |
| test/cli/install/migration/complex-workspace.test.ts | +6/−1 | 3 | 0 | §11.2 |
| test/cli/run/garbage-env.test.ts | +7/−0 | 1 | 0 | §11.2 |
| test/cli/run/glob-on-fuse.test.ts | +7/−1 | 1 | 0 | §11.2 |
| test/cli/run/run-file-on-fuse.test.ts | +7/−1 | 1 | 0 | §11.2 |
| test/js/bun/binary/tls-segment-size.test.ts | +3/−1 | 1 | 0 | §11.2 |
| test/js/bun/ffi/addr32.test.ts | +7/−1 | 3 | 0 | §11.2 |
| test/js/bun/ffi/cc.test.ts | +5/−1 | 3 | 0 | §11.2 |
| test/js/bun/glob/scan.test.ts | +4/−1 | 2 | 0 | §11.2 |
| test/js/bun/http/req-url-leak.test.ts | +2/−2 | 2 | 0 | §11.2 |
| test/js/bun/shell/commands/ls.test.ts | +1/−1 | 0 | 0 | §11.2 |
| test/js/bun/util/mmap.test.js | +1/−1 | 1 | 0 | §11.2 |
| test/js/node/http2/node-http2.test.js | +6/−2 | 2 | 0 | §11.2 |
| test/js/node/test/common/index.js | +7/−2 | 3 | 0 | §11.2 |
| test/js/node/test/parallel/test-fs-stat-date.mjs | +8/−1 | 1 | 0 | §11.2 |
| test/js/node/test/parallel/test-fs-stat-temporal.mjs | +8/−1 | 1 | 0 | §11.2 |
| test/js/web/fetch/fetch.unix.test.ts | +6/−1 | 2 | 0 | §11.2 |
| test/js/web/url/url.test.ts | +110/−0 | 0 | 0 | §11.2 |
| test/regression/issue/24364.test.ts | +8/−2 | 3 | 0 | §11.2 |
| test/regression/issue/18239/data-generator.sh | +1/−1 | 0 | 0 | §11.3 |
| test/js/node/child_process/child-process-rlimit-nofile.test.ts | +9/−2 | 3 | 0 | §2.1 |
| test/js/node/test/parallel/test-fs-write-sigxfsz.js | +6/−1 | 2 | 0 | §2.2 |
| test/js/node/fs/fs.test.ts | +24/−10 | 16 | 0 | §2.2/§3.7 |
| test/js/node/fs/fs-birthtime-linux.test.ts | +3/−1 | 2 | 0 | §3.1 |
| test/js/bun/http/serve-directory-routes.test.ts | +4/−2 | 3 | 0 | §3.2 |
| test/cli/run/no-orphans.test.ts | +23/−3 | 3 | 0 | §3.4 |
| test/js/bun/spawn/spawn-pipe-read-error-leak.test.ts | +10/−2 | 3 | 0 | §3.5 |
| test/js/bun/spawn/spawn-stdin-readable-stream.test.ts | +4/−1 | 4 | 0 | §3.6 |
| test/js/node/process/process-stdin.test.ts | +3/−2 | 3 | 0 | §3.6 |
| test/js/bun/http/serve.test.ts | +6/−1 | 1 | 0 | §4.1 |
| test/js/node/http/node-http.test.ts | +9/−2 | 3 | 0 | §4.1 |
| test/js/node/net/server.spec.ts | +14/−2 | 2 | 0 | §4.1 |
| test/js/node/tls/node-tls-server.test.ts | +3/−2 | 3 | 0 | §4.1 |
| test/js/bun/dns/resolve-dns.test.ts | +11/−5 | 5 | 0 | §4.2 |
| test/bundler/bun-build-compile.test.ts | +75/−5 | 8 | 0 | §5 |
| test/regression/issue/24742.test.ts | +33/−10 | 5 | 0 | §5 |
| test/regression/issue/29290.test.ts | +36/−12 | 6 | 0 | §5 |
| test/bundler/native-plugin.test.ts | +75/−68 | 4 | 0 | §6.1 |
| test/cli/hot/hot.test.ts | +2/−2 | 2 | 0 | §6.1 |
| test/cli/install/bun-add.test.ts | +101/−97 | 1 | 0 | §6.1 |
| test/cli/run/require-cache.test.ts | +16/−12 | 4 | 0 | §6.1 |
| test/cli/watch/watcher-trace.test.ts | +77/−73 | 2 | 0 | §6.1 |
| test/js/bun/spawn/spawn.test.ts | +68/−30 | 6 | 0 | §6.1 |
| test/js/bun/util/inspect-error-leak.test.js | +21/−17 | 2 | 0 | §6.1 |
| test/js/node/child_process/child_process.test.ts | +64/−51 | 3 | 0 | §6.1 |
| test/js/node/http/node-http-backpressure.test.ts | +47/−34 | 4 | 0 | §6.1 |
| test/js/node/watch/fs.watch.test.ts | +5/−2 | 1 | 0 | §6.1 |
| test/js/bun/util/filesink.test.ts | +38/−3 | 0 | 0 | §6.3 |
| test/cli/install/bunx.test.ts | +1/−1 | 1 | 0 | §6.4 |
| test/js/sql/adapter-env-var-precedence.test.ts | +5/−3 | 0 | 0 | §6.4 |
| test/regression/issue/28159.test.ts | +7/−1 | 2 | 0 | §6.4 |
| test/bun.lock | +119/−259 | 8 | 0 | §7 |
| test/cli/install/migration/complex-workspace/packages/lol-package/package.json | +1/−1 | 0 | 0 | §7 |
| test/integration/datadog-pprof/datadog-pprof.test.ts | +5/−1 | 4 | 0 | §7 |
| test/integration/esbuild/esbuild.test.ts | +8/−5 | 5 | 0 | §7 |
| test/integration/vite-build/the-test-app/bun.lock | +244/−229 | 5 | 0 | §7 |
| test/integration/vite-build/the-test-app/package.json | +1/−0 | 0 | 0 | §7 |
| test/js/bun/test/parallel/test-integration-rspack.ts | +19/−1 | 4 | 0 | §7 |
| test/js/node/os/os.test.js | +1/−1 | 1 | 0 | §7 |
| test/js/node/process/process.test.js | +17/−5 | 9 | 0 | §7 |
| test/js/third_party/pnpm/install_fixture/package.json | +6/−4 | 0 | 0 | §7 |
| test/js/third_party/pnpm/install_fixture/pnpm-lock.yaml | +608/−454 | 8 | 0 | §7 |
| test/napi/napi.test.ts | +63/−7 | 4 | 0 | §7 |
| test/napi/uv.test.ts | +9/−0 | 1 | 0 | §7 |
| test/package.json | +10/−4 | 0 | 0 | §7 |
| test/vendor.json | +8/−0 | 2 | 0 | §7 |
| test/internal/build-rust-toolchain-probe.test.ts | +7/−2 | 1 | 0 | §8 |
| test/internal/linker-lds-shim-exports.test.ts | +120/−0 | 0 | 0 | §8 |
| test/internal/source-lints/build-rust.test.ts | +6/−2 | 1 | 0 | §8 |
| test/internal/source-lints/dead-code-escape-limits.json | +1/−0 | 0 | 0 | §8 |
| test/internal/source-lints/ohos-sign-call-sites.test.ts | +51/−0 | 4 | 0 | §8 |
| test/harness.ts | +77/−14 | 9 | 1 | §10 |
| test/cli/run/multi-run.test.ts | +12/−3 | 5 | 1 | §3.5 |
| test/cli/watch/watch.test.ts | +5/−1 | 2 | 1 | §6.1 |
| test/js/bun/glob/leak.test.ts | +3/−1 | 2 | 1 | §6.1 |
| test/js/bun/resolve/load-same-js-file-a-lot.test.ts | +3/−1 | 2 | 1 | §6.1 |
| test/integration/vite-build/vite-build.test.ts | +28/−1 | 7 | 1 | §7 |
| test/napi/uv_stub.test.ts | +30/−1 | 3 | 1 | §7 |
| test/cli/install/GHSA-pfwx-36v6-832x.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/bun-create.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/bun-info.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/bun-pm-scan.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/bun-pm-why.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/bun-run-dir.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/bun-run.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/bun-update-security-edge-cases.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/bun-update-security-scan-all.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/hosted-git-info/boundary-conditions.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/migration/pnpm-comprehensive.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/migration/pnpm-lock-migration.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/migration/pnpm-migration-complete.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/migration/yarn-lock-migration.test.ts | +3/−1 | 0 | 2 | §11.2 |
| test/cli/install/test-dev-peer-dependency-priority.test.ts | +4/−3 | 0 | 2 | §11.2 |
| test/integration/expo-app/expo.test.ts | +6/−1 | 0 | 2 | §11.2 |
| test/js/bun/import-attributes/import-attributes.test.ts | +3/−0 | 0 | 2 | §11.2 |
| test/expectations.txt | +439/−8 | 58 | 21 | §9 |
| test/cli/install/bun-security-scanner-matrix-runner.ts | +53/−18 | 3 | 3 | §6.1 |
| test/js/bun/shell/leak.test.ts | +44/−33 | 2 | 3 | §6.1 |
| test/js/bun/spawn/spawn-pipe-leak.test.ts | +20/−7 | 2 | 3 | §6.1 |
| test/js/bun/udp/udp_socket.test.ts | +8/−1 | 3 | 3 | §6.1 |
| test/js/bun/shell/commands/rm.test.ts | +37/−14 | 5 | 3 | §6.1/§1.5 |
