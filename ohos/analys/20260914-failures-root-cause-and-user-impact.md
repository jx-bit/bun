# 2026-09-14 失败深度分析：我方独有失败（32）× A 轮共有失败（161）——根因、用户影响与修复前规避

> **2026-09-17 状态更新**（本文写作后的合并与排查已覆盖三项，勿重复修复）：
> ① **簇③3a（os 门控失效）已修**——`OPENHARMONY` 位集/映射补齐 = PR #44
> （合并 5613067cf0），待设备轮验证转绿；② **簇⑤5a（Bun.write slice 数据
> 损坏）头号嫌疑修复已入库**——PR #37 ReadFile 读循环串行化（合并
> c2459c8442），同样待设备轮验证；③ **簇③3b 的 PDEATHSIG 假设已被源码
> 证伪**（见 3b 节内 09-17 附录：git 只在 ThreadPool worker 线程 spawn，
> `pdeathsig::should_default()` 的 `is_arming_thread()` 守卫使其拿不到
> PDEATHSIG；详见该附录）。3b 主嫌改判 **OOM**（与簇④同签名同压力源），
> 残余低概率嫌疑 = 安装早退触发 exit-time descendant reaper 的竞态。

> **数据基线**：2026-09-14 真机 fulltest 第 3 轮，构建 `14fdf0d56`（官方 v1.4.0 测试树，
> 同树双 binary 对比，Parallel=2 / Timeout=180s / Retries=1）。
> - **A 轮** = social4hyq `1.4.0_80`（源码锚 `61dbc3a9d`，参考基线）
> - **B 轮** = 我方 `14fdf0d56`（含 #29/#30/#31/#32/#33/**#34** 全部已合并修复）
> - 原始数据：[`fulltest-data/archive/round-D-14fdf0d56.tar.gz`](../fulltest-data/archive/round-D-14fdf0d56.tar.gz)（已归档压缩；原 lists/ 三张清单 + 2.4MB 全量逐行报告）
> - 前序：[20260914-round-report.md](20260914-round-report.md)（轮次总览）、
>   [20260911-jxbit-only-55-attribution.md](20260911-jxbit-only-55-attribution.md)（归因方法）、
>   [20260908-overlap-135-classification.md](20260908-overlap-135-classification.md)（重叠分类初版）
>
> **本文回答四个问题**：① 我方独有失败具体坏在哪、为什么坏（syscall/源码级）；
> ② 与 A 共有的失败为什么两家都坏；③ 每类失败映射到真实使用者的什么功能、
> 什么场景会踩、踩了看到什么；④ **修复落地之前，使用者在真机上如何规避**。
>
> 证据类型标注沿用 issues/ 规范：〔源码〕逐字核验 / 〔实测〕真机日志或 binary 行为 /
> 〔推断〕机制反推（显式标记，待取证确认）。

---

## 0. 总体态势

| 指标 | 我方 B（14fdf0d56） | 参考 A（1.4.0_80） |
|---|---:|---:|
| 文件通过 | **1808 / 2001（90.35%）** | 1816 / 2001（90.75%） |
| 失败文件合计 | 193（独有 32 + 共有 161） | 185（独有 24 + 共有 161） |
| 用例通过率差距 | ~0.4pp 落后 A | — |
| 全量时长 | **01:52:46（已反超 A 的 02:00:58）** | 02:00:58 |

- 三轮演进：独有失败 **101（c4323a5d3）→ 39（0e0fd1559）→ 32（14fdf0d56）**。
- **参考锚**：官方 v1.4.0 Linux x64 构建自身也有 **126 个失败文件**
  （[`linux-baseline-fails-official-v140.txt`](fulltest-data/linux-baseline-fails-official-v140.txt)）——
  overlap 161 中有相当一部分连上游 Linux 都挂，追平 A ≠ 清零。
- 方法学（A 锚定法）：同测试树双 binary 消除树漂移 →
  `git diff origin/ohos-aarch64 61dbc3a9d -- <源区>` **空 diff 即排除该区域** →
  剩余唯一差异区即嫌疑集中地。散布失败第一性工具：
  `git log bun-v1.4.0..bun-v1.4.2 -- <源区>`（上游窗口考古）。
- 独有 32 的性质分解：**真代码债 ~20 文件**（簇①②③⑤部分）、**基建噪声 ~8 文件**
  （簇④ Verdaccio SIGKILL）、**资源/边缘 ~4 文件**（expo、挂死对）。

---

## 1. 我方独有失败（32 文件）——六大簇

### 簇 ①：spawn 自进程输出捕获残留（F1 wave2 后未收敛面）——16 文件，最大簇

#### 1a. 逐文件明细

| 文件 | 用例规模 | 失败签名（真机日志原文摘录） |
|---|---|---|
| `cli/run/multi-run.test.ts` | ≈90 挂 | `expectPrefixed(/^a\s+\| .*output-a/m)` → `Received: ""`（子进程 stdout 全空，仅状态行） |
| `cli/run/filter-workspace.test.ts` | ≈72 挂 | `Expected /scripta/ → Received: "pkga present: Exited with code 0\n"`（有退出状态、无脚本输出） |
| `cli/install/bun-run.test.ts` | ≈10 挂 | `exitCode: 227` + `stdout: ""`（期望 `shellscript.sh`）；脚本参数断言收空 |
| `cli/install/bun-run-bunfig.test.ts` | ≈10 挂 | `script "show-env" exited with code 65507`；`Expected "command not found" → Received "error: Failed due to error: bunsh: Illegal seek:"` |
| `cli/run/env.test.ts` | 4 挂 | `bun run`（bun shell 脚本 + .env 组合）`exited with code 65507` |
| `cli/run/workspaces.test.ts` | 2 挂 | `--workspaces` 子包脚本输出丢失：`Expected "package a test" → Received "a test: Exited with code 0"` |
| `cli/run/run-quote.test.ts` | 1 挂 | `--filter` 透传空参数丢失：`Expected ["a","","b"] → 收不到` |
| `cli/run/run-shell.test.ts` | 1 挂 | `bun run script.sh` → `Expected "wah\n" → Received ""` |
| `cli/run/shell-keepalive.test.ts` | 1 挂 | `Bun.$` 外部命令：**`ShellError: Failed with exit code 29`（29 = ESPIPE）**，`stdout: "hi\n"` 却报失败——errno 直接被当退出码上报 |
| `cli/test/test-shard.test.ts` | 2 挂 | `--shard × --parallel` 组合：`RAN fXX` 输出 `[]`（**纯 --shard 用例全过**，27/2——只有并行组合挂） |
| `js/bun/shell/exec.test.ts` | 13 挂 | `bun exec`：`Expected "hi!\n" → ""`；命令不存在时 `Expected "bun: command not found: ..." → "error: Failed due to error: bunsh: Illegal seek: "`（**path 为空**） |
| `js/bun/shell/commands/which.test.ts` | 1 挂 | which-streamed 输出空 |
| `js/bun/shell/env.positionals.test.ts` | 4 挂 | `bun run script.bun.sh a bb` → 脚本内 `$0/$1/$2` **全空**（`Received: [""]`，期望 `[script,"a","bb",""]`）——argv 丢失 |
| `js/bun/spawn/spawn-stdin-destroy.test.ts` | 1 挂 | 子进程退出后写 stdin → **`EPIPE: broken pipe, send, errno -32`** |
| `js/bun/shell/shell-cmdsub-crash.test.ts` | 挂死 | 2×180s 超时（命令替换 `$()` 子 shell 路径） |
| `regression/issue/22650` + `26207` | 4 挂 | `&&` 后接外部命令输出空；`--workspaces/--filter` 下 node symlink 脚本输出空 |

#### 1b. 机制链（分层：已修 → 残留）

**背景——F1 簇的根源是 HongMeng 内核与标准 Linux 的行为差异**，#32 + #34 已修四项
（全部有 A 树〔源码〕+〔实测〕双重背书）：

1. **epoll `CTL_DEL` dup 孤立 bug**：spawn 管道 fd 对（`dup()` 共营同一 open file
   description）对其中一个 fd `epoll_ctl(DEL)`，HongMeng 会**永久孤立另一个 fd**
   的内核侧注册（标准 Linux 按 epoll(7) 语义隐式移除是等价操作）→ 读端永不再收
   事件 → 管道静默断流。修复 = 注销后立即 close 的路径跳过显式 CTL_DEL
   （`FilePoll::deinit_force_unregister_skip_ctl_del`）。
2. **epoll 静默停摆**：〔实测〕`ADD/MOD` 返回 0（成功）但内核停止投递 →
   `epoll_rearm_watchdog`（后台线程指数退避补发冗余 CTL_MOD；opt-in，
   `BUN_DISABLE_EPOLL_REARM_WATCHDOG=1` 可关）。
3. **memfd 在 HongMeng 损坏**：〔实测注释〕`dup2(memfd,1/2)` 后子进程写入、
   `fstat` size=0 → **stdin/stdout=Buffer 的 spawn 全废**。A 树 2026-06-11 验证
   注释，`cfg(not(target_env="ohos"))` 门控回退 socketpair（#34 wave2 移植）。
4. **pidfd+epoll 异步退出检测静默失效**：〔实测 2026-08-17〕子进程正常退出成
   zombie、父事件循环永不收尾 → `Bun.spawn().exited` 不解析。OHOS 默认启用
   waiter-thread（#34 移植）。#32 还给**同步**路径加了 poll+wait4+pidfd 父死监视。
5. **exec 前 fd 清理 no-op**：OHOS 路径因"seccomp 挡 close_range"的〔推断〕顾虑
   走 fcntl(F_SETFD) 循环——而〔实测〕该循环在 vfork 子进程内被忽略 → **fd>2
   全部泄漏进 exec'd 子进程** → 子进程持有父侧管道读端/stdin 写端 → EOF 永不到来、
   孙进程继承、空捕获与挂死。#34 恢复 `close_range` 直呼（A 设备全绿证伪 SIGSYS 顾虑）。
6. **`bun run` 系 $PWD 失同步**：OHOS EL2 沙箱里 exec'd 二进制 `getcwd()` 对沙箱
   路径报 EACCES，程序转而信任 `$PWD`；A 在绑定层补同步（#34 移植 PWD 半块）。

**残留缺口（本轮 16 文件的真实归属）**：#34 §5 预期转绿 18 文件，实际只收复 5 个
（console-iterator、test-changed、spawn-stdin-readable-stream-integration 等），
**剩余文件失败签名与 wave2 之前逐字节一致** → 说明：

- **`bunsh: Illegal seek`（ESPIPE=29）的确切 syscall 源仍未定位**〔推断〕——
  pr34 §6 预留："memfd 读路径与 fd 泄漏两假设均被本 PR 覆盖，设备复跑若仍现需带
  `BUN_DEBUG` 日志单查"。现在复跑**确认仍现** → 两个假设都被排除或只排除一半。
  佐证：`shell-keepalive` 的 `exit code 29` = 同一 ESPIPE（ShellPromise 把 errno
  当子进程退出码上报）；`bun exec` 报错 path 为空 = 错误结构未填充。
- **异步 spawn-bun-自进程的 stdio 投递还有未覆盖断点**〔推断〕——multi-run 90
  用例全部"exit 0 + 输出空"：子进程跑了、退出检测工作了、唯独管道内容没送达读端，
  指向 #32 修复面之外的又一层（$PWD 同步只搬半块、或 PipeReader 订阅时序在
  OHOS 上还有窗口、或 async Process::watch() 路径仍裸奔——#34 只修了默认
  waiter-thread 开关，未覆盖全部异步组合）。
- **argv/positionals 丢失**独立于输出捕获：`bun run script a bb` 的参数在
  exec/re-exec 链路上被吞（与 ESPIPE 同为 shell 子进程路径，疑似同一根因的
  另一症状）。

#### 1c. 用户影响（场景化）

**谁会踩**：在鸿蒙真机/设备上用 bun 做日常开发的任何人——这是核心工作流。

| 场景 | 踩到什么 | 看到的现象 |
|---|---|---|
| 跑 `package.json` scripts（`bun run dev/build/test`） | 脚本里外部命令的输出不可见 | 终端只剩 `label: Exited with code 0` 状态行，看不到编译日志/测试输出；CI 日志为空 |
| scripts 带参数（`bun run build --flag`） | 参数传不进脚本 | 脚本行为回退默认值，静默错构建 |
| bun shell 脚本（`.sh` 脚本走内置 shell）+ `.env` | 直接失败 | `script "xxx" exited with code 65507` |
| `Bun.spawn`/`child_process` 拉起 bun 自身读输出 | stdout 空 | 测试框架收 `[]`、worker 结果丢失、`npx` 类工具链静默产出空 |
| `Bun.$` / `shell` 模板串调外部命令 | 伪失败 | `ShellError: exit code 29`（实际命令成功，stdout 都有） |
| `bun exec`（1.4 新 CLI） | 不可用 | 输出空 / `Illegal seek` |
| `bun test --shard --parallel` | 分片结果收集不到 | `RAN fXX` 全空 |
| 命令替换 `$()` 场景 | **挂死** | 调用方卡到外部超时，CI 整卡 |

**严重度：高。**

#### 1d. 修复前的规避方案（按场景）

| 场景 | 规避做法 | 代价/局限 |
|---|---|---|
| scripts 输出不可见 | bunfig.toml 加 `[run] shell = "system"`，让 scripts 走系统 shell（设备自带 toybox/mksh `sh`）而非内置 bun shell〔源码：`bunfig.rs:794-800` 确认该键〕 | 丢失 bun shell 的跨平台一致性与内置命令 |
| `bun run --parallel`/`--filter` 输出丢 | 改串行：`bun run a && bun run b`；filter 场景逐包跑 | 失去并行加速 |
| `Bun.spawn` 读子进程输出 | `stdout: "inherit"`（直写终端，绕过管道捕获）；需要留存输出时改"子进程自己写文件 + 父进程事后读文件"模式 | 拿不到进程内 stdout 流对象；无法实时逐行处理 |
| `spawnSync` + `stdin: Buffer` | 数据经临时文件传递（子进程 `fs.readFileSync`），或参数/环境变量携带 | 不适合大数据量/二进制流 |
| scripts 传参丢失 | 环境变量传参：`MY_ARGS="a bb" bun run script` + 脚本内读 `process.env.MY_ARGS` | 接口改动；含空格参数需自行转义 |
| 向子进程 stdin 写入 EPIPE | 写前 `await proc.exited` 竞速 + `try/catch(EPIPE)`；或改用子进程读文件的握手协议 | 代码侵入 |
| `bun exec` | 暂用 `bun run`（配 `[run] shell="system"`）或直接 `sh -c` 替代 | 1.4 新特性不可用 |
| `$()` 命令替换挂死 | 外部超时兜底 `timeout 30 bun ...`；脚本内避免 `$()`，用两步变量赋值 | 无 |
| `bun test --shard --parallel` | 二者不组合：纯 `--shard` 用例本轮全过（27/2 中挂的 2 个都是 `×--parallel`）→ 分片时去掉 `--parallel` | 分片内失去并行 |
| `Bun.$` exit code 29 伪失败 | 命令可能实际成功（`stdout: "hi\n"` 在场）——以 stdout 内容做业务断言，忽略该退出码 | 错误处理逻辑需放宽 |
| 通用兜底 | 所有 spawn 密集脚本外包 `timeout` + 输出落文件 | 无 |

---

### 簇 ②：serve 目录路由 404（F2 残留）——1 文件 26 用例

**逐用例签名**（三类）：
1. `routes: { "/*": { dir } }` → `fetch(url + "index.html")` 期望 200 **实收 404**；
2. 嵌套目录 `assets/images/logo.svg` 期望 `"<svg></svg>"` **实收 `""`**（空 body）；
3. 自定义前缀 `/static/*` → 404；404 回退 fallback handler 的组合也 404。

**根因**：server 源码两树 `git diff` 为空（排除法已排除 server 代码本身）。
归因 [20260911 §4.1](20260911-jxbit-only-55-attribution.md)：fd 事件投递层症状面
——"空 body" = 响应体投递失败（#32 已缓解的部分），**404 部分** = 目录路由的
文件查找/打开路径在 OHOS 上的差异（〔推断〕hmdfs 目录列举/路径解析语义，
或路由匹配前缀处理与沙箱路径前缀的交互）。**待 junit round C 逐用例区分
两种症状各自的残留量**（round-report §5.4 同判：F2 残留，需日志定性）。

**用户影响**：用 `Bun.serve` 目录路由**托管静态站点/SPA 资源**直接 404——
真机上"静态站/H5 资源服务"不可用。内嵌 HTML import 的全栈应用（`bundler_html`
测试面两轮双过）不受此影响。**严重度：中高。**

**修复前规避**：
- 不用 `routes: {dir}`，改 catch-all handler：
  ```js
  fetch: (req) => {
    const path = new URL(req.url).pathname;
    const file = Bun.file(join(dir, path));
    return new Response(file);   // ⚠️ 依赖 Bun.file 读取路径，见下注
  }
  ```
  ⚠️ **注**：`bun-serve-file.test.ts` 本身也在 overlap（族 7），`Response(Bun.file)`
  路径在真机的可靠性未独立验证——规避后先小流量冒烟。
- 更稳的临时方案：静态资源放 linux/云端，真机只跑 API；或用应用框架自带的
  资源管理（rawfile）替代 HTTP 静态服务。
- 观察 404 是否只发生在**带子目录/前缀**的路由（签名 1/3），单层根路径若可用
  则把资源拍平部署。

---

### 簇 ③：cli/install 真实差异（src/install 未消化块）——3 文件

#### 3a. `architecture-match.test.ts`（4 用例）——os 门控正确性缺陷

**签名**：`isOperatingSystemMatch("openharmony") → false`（期望 true）、
`sunos,openharmony → false`（期望 true）、`any,!openharmony → true`（期望 false）。

**根因**〔源码实锤，本轮新定位〕：我方
`src/install_types/resolver_hooks.rs:863-866` 的 `OPERATING_SYSTEM_NAMES` 映射表
**只有** `aix/linux/sunos/win32/darwin/android/freebsd/openbsd` 八个键——
**没有 `openharmony`**；位集常量（L809-825）也没有 OPENHARMONY 位；
且 OHOS 构建走 `#[cfg(all(target_os="linux", not(target_os="android")))]
CURRENT = LINUX`（L827-828）。于是：
- 包声明 `"os": ["openharmony"]` → 键不识别 → `had_unrecognized_values` → 不匹配 → **可选依赖被静默跳过**；
- 包声明 `"!openharmony"` → 排除键不识别 → **不兼容包照样装上**（A 树的实现
  识别该键，所以 A 过）。这是 `src/install/` 差异块（14 文件 ~500 行，唯一未
  逐 hunk 消化的大块）的组成部分。

**用户影响**：**npm `os`/`cpu` 平台门控在鸿蒙上失效**——
- 鸿蒙生态包（发布 `os:["openharmony"]` 原生变体的）**装不上它的原生部分**，
  回退 JS 实现或直接缺依赖；
- 声明"不兼容 openharmony"的包**被错误安装**，装完运行时崩（如 glibc 特化
  原生模块）。**严重度：中高（正确性 > 通过率数字）。**

**修复前规避**：
- 依赖发布了 openharmony 变体但装不上 → 用 `patchedDependencies` 剥掉该包
  package.json 的 `os` 字段（bun patch 机制），或直接 vendor 进仓库（`file:` 依赖）；
- 误装不兼容包 → `overrides` 把该依赖钉到有 linux-musl 变体的版本
  （**OHOS 是 musl 基**，`linux-musl-arm64` prebuild 大概率可加载〔推断，需验证〕；
  且 OHOS 构建 `CURRENT=LINUX`，`os:["linux"]` 的包当前**能**正常命中）；
- 显式交叉安装意图：`bun install --os=linux --libc=musl`〔源码〕
  `CommandLineArguments.rs:1520-1547` 确认两标志存在——在 CI/脚本里固化环境
  假设，避免依赖隐式平台映射。

#### 3b. `bun-pm-licenses.test.ts`（2/79）——git 子进程被 SIGKILL

**签名**：`error: git failed with signal 9` → `InstallFailed checking out
repository for nd@git+file:///...`。

**根因**〔推断，头号嫌疑〕：git clone 子进程收到 SIGKILL。Linux 语义陷阱：
`PR_SET_PDEATHSIG` 在**父线程**（而非父进程）退出时触发——#34 后 OHOS 默认
启用 waiter-thread、spawn 调用若发生在短命 worker/waiter 线程，线程回收即误杀
git。A 树 spawn 实现不同所以不触发。次嫌疑：设备 OOM（与簇④ Verdaccio
SIGKILL 同压力源）。**定性手段**：junit round C 时对 git spawn 路径加
`BUN_DEBUG` + 设备侧 `strace -f -e trace=kill`。

**用户影响**：`bun install` 拉 **git 依赖**（`git+https://`、私有 monorepo、
GitHub 直连）在 license 检查/多分支场景**失败**：`git failed with signal 9`。
**严重度：中高。**

**修复前规避**：
- **tarball 化**：把 git 依赖换成 tarball URL——GitHub 用
  `https://codeload.github.com/<org>/<repo>/tar.gz/refs/heads/<branch>`，
  GitLab/Gitee 同理；**真机已验证 tarball 安装链路可用**
  （〔实测〕`bun-install-tarball-integrity.test.ts` 双轮通过）；
- 私有 git 依赖：CI 上先 clone 到本地再 `file:` 依赖或 pack 成 tarball 安装；
- 降低并发：避免多进程同时 `bun install`（叠加 OOM 嫌疑）。

#### 3b-附录：PDEATHSIG 假设的源码证伪（2026-09-17）

原文的头号嫌疑（PDEATHSIG 线程语义误杀）经源码链路逐点核对**不成立**：

1. **git 的唯一 spawn 路径在 worker 线程**：`repository.rs::exec` →
   `bun_spawn::run` → `process::sync::spawn`；`bun_spawn::run` 注释明载其
   唯一调用方 `repository::exec` 跑在 ThreadPool worker 上
   （`src/spawn/lib.rs`，Windows 分支注释同）。
2. **默认 PDEATHSIG 有 arming-thread 守卫**：`spawn_sys/lib.rs::pdeathsig`
   —— `should_default() = DEFAULT && is_arming_thread()`，且注释点名
   "install's threadpool `git` clones" 属于被排除的 off-thread caller；
   worker 线程 spawn ⇒ `attr.linux_pdeathsig = 0`。
3. **spawnSync 的 no-orphans 同样按线程门控**：`process.rs::spawn_posix` 的
   `no_orphans = is_enabled() && is_arming_thread()`，注释再次点名
   "install's `repository::exec` git clones" 会与进程级 subreaper 竞态，
   故 worker 上不启用。
4. **PDEATHSIG 不跨 fork 继承**：`ParentDeathWatchdog.rs` enable() 注释
   （"cleared on fork, Bun's own children do not inherit it"）——外层 bun
   自身的看门狗不会传给 git。

**改判**：SIGKILL 主嫌回到 **OOM killer**（与簇④ Verdaccio SIGKILL 同签名、
同轮、同 Parallel=2 内存压力，一个解释覆盖两簇）。残余低概率嫌疑：
安装主流程早退触发 exit-time descendant reaper（`on_process_exit` →
killDescendants）时 git 仍在飞——需要"主线程认为任务已完而 worker 的 git
未完成"的时序证据，junit round C 加 `strace -f -e trace=kill` 一并定性。

#### 3c. `bun-install-git-deps.test.ts`（1/7，30s 超时）

**签名**：`installs every git dependency when many branches of one repo appear
directly and transitively` 超时（其余 6 用例过）。

**根因**：多分支传递性 git 安装超预算——git clone/checkout 在 hmdfs 上 I/O 慢
+ 疑似与 3b 同源的 git 子进程异常（同一文件域）。A 通过 → 我方 git spawn 链路
或 install 解析路径有额外开销/缺陷。**待 junit 定性是"慢"还是"死"。**

**用户影响**：复杂 git 依赖树（多分支同名仓库直连+传递）安装**超时失败**。
**严重度：中。** **规避**：同 3b（tarball 化 / vendor）；锁定分支数少的引用形式。

---

### 簇 ④：Verdaccio 基建噪声（披着"回归候选"外衣）——6 文件

**成员**：`bun-publish`（3 用例）、`frozen-lockfile-missing-workspace`、
`frozen-lockfile-pruned`（多用例）、`migration/pnpm-lock-v9`（3+ 用例）、
`bun-update-transitive`（2 用例）。

**签名（高度一致）**：
```
Verdaccio exited with code null and signal SIGKILL
error: ConnectionRefused downloading tarball no-deps@1.0.0
TypeError: Unable to connect ... http://localhost:58396/... code: "ConnectionRefused"
```

**根因**：设备上的共享 Verdaccio（本地 npm registry 桩）**被 SIGKILL**——
fulltest 脚本有专门的 infra-retry（重试一次仍挂才记失败），
[`run-all-official-progress-optimized.sh`](../fulltest/run-all-official-progress-optimized.sh)
L176-228；`verify-retest.ts` 把它列为"环境/基建，二进制修复无法保证"。
SIGKILL 来源最可能是 **Parallel=2 时多 Verdaccio 实例 + bun install 并存的设备
内存压力 → OOM killer**。round-report §4 曾把这几个列为"wave2 回归候选"，
但**签名与 wave2 改动（close_range/PWD/waiter）无因果证据**——本轮降级为
"基建噪声为主"，仅保留 junit 复核权利。

**用户影响**：**无直接影响**（测试基建伪影）。真实世界映射：低内存设备上
**并发跑 registry 密集任务可能触发 OOM**——`bun install` 大依赖树时留意内存
预算。**规避**（面向复测/集成方而非终端用户）：降低 Parallel=1、复测前清理
后台应用、对这 6 文件做 infra-retry 白名单。

---

### 簇 ⑤：散点——4 文件

#### 5a. `js/bun/io/bun-write.test.js`（1 用例）——`Bun.write` 切片失效（数据正确性）

**签名**：`Bun.write(Bun.file(src).slice(0, N), dst)` → 目标文件收到**整个
源文件**（29 行差异：期望前半截 `border-rad"` 截止，实收全量 HTML）——
`Bun.file().slice()` 的只读切片被无视。

**根因**〔推断〕：`Bun.file().slice()` 的读路径在 OHOS 上失效/未截断——与
**PR #37 的"ReadFile 读循环竞态串行化（修 stdin 大读随机截断）"高度同源**
（同一读循环），#37（OPEN，2 文件 +166/−5 逐字节 = A）未合入。

**用户影响**：**`Bun.write` + 文件切片**（分块拷贝、断点续传、部分读取类场景）
**静默写错数据**——触发条件窄但属数据损坏类。**严重度：中（正确性）。**

**修复前规避**：切片在 JS 侧完成，不依赖 `.slice()` 的惰性读：
```js
const buf = await Bun.file(src).arrayBuffer();
await Bun.write(dst, new Uint8Array(buf, 0, N));      // 或 buf.subarray 语义
```

#### 5b. `js/node/dns/node-dns.test.js`（1/165）——dns.lookup 失败模式

**签名**：坏域名（随机串）`dns.lookup` → `DNSException: getaddrinfo ETIMEOUT
(errno 12)`（期望快速 ENOTFOUND 类失败，2.08s）。

**根因**：设备 DNS 链路对不存在域名**不返回权威 NXDOMAIN 而是超时**。A 通过
→ A 的 resolver 行为（c-ares 配置 / resolv 语义 / 当轮网络状态）不同。
〔推断〕我方构建的 getaddrinfo 走系统 resolver，上游无响应时 2s 才报错；
A 可能命中了 c-ares 的 NXDOMAIN 快速路径或当时网络差异。

**用户影响**：`dns.lookup()` 失败**慢 2 秒**而非立即报错 → 依赖快速失败做
重试/降级/多地址竞速的应用被拖慢；弱网/离线鸿蒙设备上所有域名解析失败路径
变慢。**严重度：低中。**

**修复前规避**：应用层给 lookup 包超时（`Promise.race` 2s 上限）；关键域名
改用 `dns.resolve4()`（c-ares 路径，失败模式可能不同——需验证）；服务端
地址直连 IP + 自管重试。

#### 5c. `cli/inspect/inspect.test.ts`（2/27）——`--inspect` unix path 错误串台

**签名**：`bun --inspect=/foo` → WS URL 断言收到
`{pathname: " \"EADDRINUSE\"", protocol: "code:", hostname: "", port: ""}`——
inspect 服务端**绑定失败（EADDRINUSE，测试固定端口 6499 + Parallel=2 冲突）**
后，**错误文本被当作 WS URL 下发解析** → 错误路径串台。

**根因**〔推断〕：绑定失败的错误分支把 errno 文本填进了 URL 结构；叠加测试
环境的固定端口竞争。与 **PR #37（uSockets 强制禁用 `epoll_pwait2(441)` 修
inspector WS 1006）** 同属 inspector/uSockets 面——#37 未合入。

**用户影响**：`bun --inspect` 的 **unix path/子路径形式**在端口冲突/绑定失败时
报**误导性乱码 URL**，调试器 attach（VS Code/DevTools）在真机不可靠。
**严重度：中。**

**修复前规避**：每进程唯一显式端口 `bun --inspect=127.0.0.1:<port>`（数字
host:port 形式的用例本轮是过的）；避免并行 attach；unix path 形式暂不用。
**#37 合入后复验。**

#### 5d. `js/bun/shell/shell-seq-condexpr.test.ts`（3/5）——内建 seq 非法参数静默

**签名**：`seq inf/nan/-inf` 期望 stderr 含 `invalid argument` 实收 `""`。

**根因**〔推断〕：内建 `seq` 对非法参数的报错没有送达 stderr——内建报错路径
+ 条件表达式上下文的 stderr 捕获（F1 相邻，shell 源码两树一致 → 捕获层嫌疑）。

**用户影响**：`seq` 传非法参数**静默无输出**而非报错 → `seq inf || fallback`
类错误处理拿不到错误信息；影响面小。**严重度：低。**
**规避**：脚本内自行校验数字参数再调 seq。

#### 5e. `integration/expo-app/expo.test.ts`——超时

超时（−1，360s 双跑）。expo 全家桶 install+build 在设备时长/内存超预算；
round-1 inventory 里 A 也独挂过此文件 → 两家都在边缘。**规避**：expo 类
重型构建留在 x86；真机只验证运行时。

---

## 2. 与 A 共有的失败（161 文件）——OHOS 环境基线，八族

> overlap = 换 binary 也解决不了的公共债——**两个移植实现都没修好或修不了**。
> 它们构成"鸿蒙上跑 bun 的天花板"，其中一部分连上游 Linux 也挂（126 文件基线）。
> 对照并更新 [20260908-overlap-135-classification.md](20260908-overlap-135-classification.md)
> （该文基于轮 1 fork 树口径；本轮按官方树 + 修复后现状重排）。

### 族 1：设备基建/资源族（~30 文件，最大族，binary 不可修）

**成员**：`cli/install/` registry 密集全家（bun-install、bun-install-registry、
bun-add-filter、bun-create、bun-pack、bun-prune、bun-upgrade、bunx、
isolated-install、bun-lock、bun-lockb、bun-pm-diff、complex-workspace、
symlink-path-traversal、security-scanner ×2…）+ `bun-install-lifecycle-scripts`。

**根因**：同簇 ④——共享 Verdaccio 被 SIGKILL（设备 OOM/看门狗）+ ConnectionRefused
级联；lifecycle-scripts 叠加重型子进程风暴（postinstall）。infra-retry 后仍挂
说明 SIGKILL 是持续性资源压力。

**用户影响**：直接 0（测试伪影）。间接信号：真机并发安装大依赖树的**内存压力
可观**。**规避**：安装大项目时串行、复用全局缓存（`bun install --cache-dir`
指向持久卷减少下载与解压峰值内存）。

### 族 2：TTY/PTY 平台限制族（~8 文件，class B——平台能力边界）

**成员**：`terminal/terminal.test.ts`、`terminal-spawn`、`terminal-platform-gaps`、
`node/tty.test.ts`、`regression/issue/18239`、`ctrl-c.test.ts`、`repl`（部分）。

**根因**（[OHOS_TEST_STATUS T03/T25/T27](../knowledge/OHOS_TEST_STATUS.md) 实证）：
- T03a（**已修**）：`ttySetMode()` 硬编码 `TCSADRAIN`，OHOS 拒绝在 PTY master 上
  排空型 `tcsetattr`（EACCES）→ raw mode 必抛。已改 EACCES 回退 `TCSANOW`，
  `Failed to set raw mode` 7 次→0 次〔实测〕。
- T25/T27（**平台限制**）：OHOS PTY **行规程认控制字符但不生成信号**——`^Z` 被
  回显成字面字符、`BUN_STOPPED` 永不出现〔实测探针〕；作业控制信号族
  （Ctrl-Z/SIGWINCH/SIGTSTP）在 PTY 上**结构性不可用**。

**用户影响**：`Bun.Terminal` **raw mode 基本功能可用**（T03 已修）；**TUI 应用的
作业控制**（Ctrl-Z 挂起恢复、窗口 resize 信号）在真机失效——全屏 TUI 的暂停/
自适应异常。**无法规避（平台边界）**：应用侧检测
`process.platform === "openharmony"` 降级（禁用作业控制功能、改轮询终端尺寸）。
注意：**本轮 A 与我方在同一组文件上共同挂** → 平台限制口径一致。

### 族 3：AF_UNIX / hmdfs / 沙箱文件系统族（~15 文件残留）

**成员**：`node/net/`（node-net、node-net-server、allowHalfOpen、handle-leak、
server.spec）、`bun/net/socket.test.ts`、`unix-socket-unlink`、`websocket-unix`、
`fetch.unix`、`cluster.test.ts`、`node/fs/fs-mkdir`、`fs.watch`、`node/os`、
`glob/path-length`。

**根因**：`os.tmpdir()` 落 hmdfs → AF_UNIX bind EPERM（#27 已修：runner 探测
候选根 `$TMPDIR` → `/data/local/tmp` → `os.tmpdir()` → `/tmp`，真实 socket
bind 取第一个可用）。**#27 后 node-net ×39 的预测收敛未完全兑现**——本轮仍
有 5+ 文件残留 → 该族不止 tmpdir 一个断点：hmdfs `stat` uid 语义（bunx 缓存
所有权误拒，`bunx_command.rs` ownership check）、`fs.watch`（inotify 语义/支持度）、
EL2 沙箱长路径（`glob/path-length`）、`getcwd()` EACCES 各自独立。**逐文件
junit 归位是下一步。**

**用户影响与规避**：

| 受影响功能 | 影响 | 修复前规避 |
|---|---|---|
| Unix domain socket 本地 IPC | 非常规路径 EPERM | **`export TMPDIR=/data/local/tmp`**（#27 探测第一候选，〔实测〕该路径 AF_UNIX 可用）；unix socket 文件建到 `/data/local/tmp` 下 |
| `bunx` 缓存所有权误拒 | `refusing to use bunx cache directory … not owned by current user` | 暂无干净规避（hmdfs stat uid 语义是根因）；`BUN_INSTALL_CACHE_DIR` 指向应用沙箱私有目录可一试〔推断，未必生效〕 |
| `fs.watch` / `--watch` / 热重载 | 变更监听不可靠 | 应用层轮询（`setInterval` + `stat().mtime`）；vite 场景 `server.watch.usePolling: true` |
| 长路径（深层 node_modules） | 路径长度限制 | 缩短项目根路径（部署到浅目录）；减少嵌套依赖 |

### 族 4：外部服务依赖族（~18 文件，测试设计如此，非缺陷）

**成员**：`third_party/mongodb`、`pg`、`postgres`、`valkey ×2`、`stripe`、
`azure-service-bus`、`nodemailer`、`grpc-js ×2`、`prisma`、`pnpm`、
`js/bun/s3 ×3`、`sql/adapter-env-var-precedence` 等。

**根因**：测试需要 Docker 化服务（数据库/消息队列/mock server）或公网；真机
沙箱无 Docker 无公网。两家都挂是预期行为。

**用户影响**：无（应用运行时**连**这些服务是网络面的事，测试只是没法**起**
服务端桩）。**规避**：不需要规避；若要在真机做集成验证，把服务端部署到局域网
主机、连接串指向它。

### 族 5：重型第三方/构建工具族（~15 文件，资源+原生二进制双重约束）

**成员**：`integration/next-pages ×3`、`vite-build`、`esbuild`、`datadog-pprof`、
`third_party/astro`、`rollup-v4`、`vitest`、`sharp`、`napi-rs-canvas`、`resvg`、
`bun-types ×2`、`third_party/esbuild-child_process`。

**根因分两层**：
1. **资源**：Next/Vite 全量 build 在手机 SoC 上超 180s 预算/内存超限
   （dev-server-ssr-100 在 Linux 基线同样存在）；
2. **原生二进制**：sharp/canvas/resvg 依赖 npm 预编译原生模块——**npm 上没有
   `openharmony` 目标的 prebuilds**，下载到的 linux-arm64 glibc `.node` 在
   鸿蒙 musl 环境加载失败。真实生态缺口（非 bun 缺陷）。

**用户影响与规避**：

| 受影响功能 | 规避 |
|---|---|
| Next.js/Vite/Astro 完整构建 | **x86 侧构建 + 产物部署真机**（开发期构建不放在端侧）；真机只验证运行时 |
| sharp/canvas/resvg 类图像原生包 | 优先找有 `linux-musl-arm64` prebuild 的版本（OHOS musl 基，大概率可加载〔推断，需逐包验证〕）；或等鸿蒙 prebuilds 生态 + 簇③ os 门控修复后装 openharmony 变体 |
| prisma/pnpm 自检类 | CLI 重流程留在 x86，端侧只跑生成产物 |

### 族 6：bake/dev 服务器族（13 文件，单一根因面）

**成员**：`bake/dev/` bundle、css、hot、ecosystem、esm、html、
import-meta-inline、incremental-graph、react-spa、sourcemap、ssg-pages-router、
stress + `dev-and-prod`。

**根因**：bake dev server = HTTP + WebSocket(HMR) + fs.watch + 子进程 组合体，
叠在族 2（fs.watch）+ 族 3（socket/端口面）+ F1 相邻（HMR 长连会话）上。
round-1 时 A 曾独挂 `bake/dev-and-prod`（后 B 过了）→ 该族在两家都是边缘
稳定态。**round C junit 后按签名二次分类**（区分：WS 断连 / watch 不触发 /
增量重建停摆三类）。

**用户影响**：**bake dev（HMR 全栈开发服务器）在真机不可用或严重降级**；
不影响生产（`bake build` 产物）。**规避**：真机不开 dev server——x86 开发 +
产物部署；`--hot` 热重载场景改手动重启进程。

### 族 7：HTTP/网络投递残留族（~12 文件，uSockets 面，PR #37 关联）

**成员**：`bun/http/serve.test.ts`、`serve-listen`、`serve-http3`、
`bun-serve-file`、`bun-serve-args`、`bun-listen-connect-args`、
`server-url-invalid`、`web/fetch/fetch.test.ts`、`streams.test.js`、
`websocket-server`、`node/http ×2`（部分）。

**根因**：uSockets（`Bun.serve` 底层）**强制启用 `epoll_pwait2(441)`**，OHOS
内核该 syscall 行为异常 → 事件投递缺陷（PR #37 定位：inspector WS 1006 同源；
修复已备好未合入，"2 文件 +166/−5 逐字节 = A"）。HTTP3/QUIC 面（lsquic/lsqpack）
另有独立变量。

**用户影响**：`Bun.serve` 基础 HTTP 服务在真机**部分场景不可靠**（keep-alive
连接复用、文件响应、大响应体、WS 长连）。**规避**：
- 客户端/服务端都发 `Connection: close`（短连接模式绕开 keep-alive 投递问题）；
- 响应体先落内存再返回（`new Response(await file.arrayBuffer())` 代替
  `new Response(file)` 的流式路径）〔推断，需验证〕；
- WS 重连兜底（应用层心跳 + 断线重连本来就该有）；
- **#37 合入是本族最大杠杆**——inspector 与 serve 共用 uSockets 事件层，
  一次修复双收益。

### 族 8：构建机专属 + 断言差异 + 挂死尾（~50 文件散布）

- **构建机专属（9 文件，零用户影响，应加设备门控）**：`test/internal/*`
  （build-codegen、rust-toolchain-probe、macos-cross-config、oxlint-plugin、
  source-lints ×3…）——测的是 bun 仓库自己的构建脚本，在设备上跑本身没意义。
- **断言/行为差异散点（~25 文件）**：`process.test.js`、`os.test.js`、
  `fs.test.ts`、`fs-mkdir`、`mmap` 等 toBe/toEqual 小差异 + 平台数值
  （T21 waiter 线程 CPU 统计口径超阈值 83%、T22 `memfd_create`+`readFileSync`
  EACCES vs ENOMEM 等，OHOS_TEST_STATUS 已有 T 编号）。逐条 triage
  "行为差异 vs 测试过期"。
- **超时/挂死尾（~13 文件）**：无 `(fail)` 签名的 360s 双跑超时（`shell-hang`、
  `pipeline_stack`、`spawn-streaming-stdin`、`worker-late-completion`、
  `process-stdin`、`message-port-context-destroy-leak` 等）——多为事件循环
  长会话/流式管道在 OHOS 上的停摆变体，与族 7 同源概率高。
  **规避（应用侧通用）**：长连/流式场景加应用层心跳与超时；worker 收发大消息
  改分片。

---

## 3. 反向差集：A 独有失败 24 文件（我方领先的证据）

`fail_sys-release_only.txt`（A 挂 B 过）：`bake/dev/production`、`react-response`、
`request-cookies`、`server-sourcemap`、`bundler_npm`、`native-plugin`、
`cli/hot/hot`、`bun-add`、`bun-install-patch`、`bun-patch`、`migrate ×2`、
`spawn-pipe-leak`、`spawnSync`、`sleep`、`sourcemap-simd`、`fetch.tls`、
`napi/uv ×2`、regression `02499/10132/26225/26657/32492`。

**解读**：这批是我方树**领先 A 的修复/行为**——最醒目的是
**`spawnSync`、`spawn-pipe-leak`、`sleep` 三个 F1 近邻 A 挂我方过**（我方对
spawn/管道层的部分处理比 A 更稳），以及 install/patch/migrate 族（A 的
src/install 版本差异）。两向相抵：**文件级净差距 = 32 − 24 = 8 文件**，
用例级 ~0.4pp，时长已反超。剩余差距集中在簇 ① 与 `src/install` 消化块。

---

## 4. 用户影响总表 + 规避速查

### 4a. 功能面 × 状态

| # | 用户可见功能 | 涉及 API/命令 | 归属 | 状态 | 严重度 |
|---|---|---|---|---|---|
| 1 | 跑 package.json scripts（输出/参数/.env） | `bun run`、bun shell | ① | ESPIPE 源头未定位 | **高** |
| 2 | 子进程输出捕获 | `Bun.spawn/spawnSync`、`child_process`、`Bun.$` | ① | spawn-bun-自进程路径残余 | **高** |
| 3 | `bun exec`（1.4 新 CLI） | `bun exec` | ① | ESPIPE 未定位 | 高（新功能） |
| 4 | 测试分片/并行 | `bun test --shard/--parallel` | ① | 组合路径 | 中高 |
| 5 | 静态文件托管 | `Bun.serve({routes:{dir}})` | ② | 404 部分待 junit 定性 | **中高** |
| 6 | git 依赖安装 | `bun install git+...` | ③ | git 子进程 SIGKILL | **中高** |
| 7 | 原生包平台门控 | `optionalDependencies` os 字段 | ③ | **`openharmony` 键缺失（源码实锤）** | **中高** |
| 8 | 调试器附加 | `bun --inspect` | ⑤+#37 | 修复已备未合 | 中 |
| 9 | HTTP 服务器可靠性 | `Bun.serve`/`node:http` | 族 7 | **#37 是最大杠杆** | 中 |
| 10 | 文件切片写入 | `Bun.write(file.slice)` | ⑤ | 疑 #37 同源 | 中（数据正确性） |
| 11 | DNS 快速失败 | `node:dns.lookup` | ⑤ | 设备 resolver 语义 | 低中 |
| 12 | TUI 作业控制 | `Bun.Terminal`、SIGWINCH/Ctrl-Z | 族 2 | **平台限制（T27）** | 平台边界 |
| 13 | fs.watch / HMR | `fs.watch`、bake dev | 族 3+6 | 待 junit 分桶 | 中 |
| 14 | Unix socket 本地 IPC | `net`/`fetch(unix:)` | 族 3 | #27 后残留 | 低中 |
| 15 | 原生 npm 包（sharp/canvas…） | N-API prebuilds | 族 5 | **生态缺口** | 生态问题 |
| 16 | Next/Vite 完整构建 | 集成工具链 | 族 5 | 设备资源预算 | 环境现实 |
| 17 | bunx 缓存可用性 | `bunx` | 族 3 | uid 语义待修 | 低中 |

### 4b. 规避速查（症状 → 立即可做）

| 症状 | 秒级规避 |
|---|---|
| `bun run` 脚本看不到输出 / 失败 | bunfig 加 `[run] shell = "system"`；或 `sh -c` 代替 |
| `bun run --parallel`/`--filter` 输出空 | 改串行 `&&` 连接 |
| 脚本收不到参数 | 环境变量传参 |
| `Bun.spawn` stdout 空 | `stdout: "inherit"`，或子进程写文件+父读文件 |
| `spawnSync stdin=Buffer` 读空 | 数据走临时文件/argv/env |
| `Bun.$` 报 exit code 29 | 命令实际可能已成功——以 stdout 内容为准做断言；改 spawn+inherit |
| `$()` 挂死 | 外部 `timeout`；脚本避免 `$()` |
| 静态托管 404 | catch-all handler + `Response(Bun.file)`（先冒烟）；资源拍平 |
| openharmony 包装不上 | `patchedDependencies` 剥 os 字段 / vendor / `file:` 依赖 |
| 误装不兼容原生包 | `overrides` 钉 musl 变体；`bun install --os=linux --libc=musl` |
| git 依赖失败/超时 | tarball URL（codeload）/ vendor / 降并发 |
| `Bun.write(file.slice)` 写错 | JS 侧切片：`new Uint8Array(await file.arrayBuffer(), 0, N)` |
| DNS 失败慢 2s | 应用层超时包装；`dns.resolve4()`；IP 直连 |
| `--inspect` 乱码 URL | 显式唯一端口 `--inspect=127.0.0.1:<port>`；避免并行 attach |
| Unix socket EPERM | `export TMPDIR=/data/local/tmp` |
| fs.watch 不触发 | 轮询 mtime；vite `usePolling` |
| TUI 作业控制失效 | 无规避——检测 `platform === "openharmony"` 降级 |
| 原生包加载崩 | 找 musl prebuild 版本；图像处理留 x86 |
| dev server/HMR 失常 | x86 开发 + 产物部署；`--hot` 改手动重启 |
| HTTP keep-alive 断连 | `Connection: close` 短连接；响应体落内存再返回 |

---

## 5. 结论与行动映射

1. **独有 32 中"真代码债"约 20 文件**（①16 + ②1 + ③3），**基建噪声约 8 文件**
   （④6 + expo + 部分级联）——逐轮缩小的正确姿势是先把 ④ 从验收口径分离
   （junit round C per-case 精确化是前提）。
2. **最高杠杆的两个外部动作**：
   - **PR #37 合入**（uSockets `epoll_pwait2` + ReadFile 读循环竞态）→ 预期
     同时改善簇 ⑤ 两个散点 + overlap 族 7（~12 文件）；
   - **junit round C** → 剩余 32 的文件内用例归位，簇 ① 三种签名分桶，
     `bunsh: Illegal seek` 带 `BUN_DEBUG` 真机取证定位确切 syscall。
3. **两个正确性缺陷独立于通过率数字**，优先级应高于"缩数字"：
   - `src/install` 的 `openharmony` os 键缺失（〔源码〕resolver_hooks.rs L809-866
     实锤）——消化 `src/install/` 14 文件差异块时的第一目标；修复方向：
     `OPERATING_SYSTEM_NAMES` 增 `b"openharmony"` + ohos target 的
     `CURRENT` 并入新位；
   - `Bun.write(file.slice)` 全量写入——随 #37 验证是否同源消解。
4. **overlap 161 是"平台边界图"不是"欠账清单"**：族 1/4/5/8a（约 70 文件）
   不可修或不必修；族 2 平台限制（对齐门控口径）；族 3/6/7/8b（约 50 文件）
   是真正还能推进的部分——族 7 等 #37、族 3/6 等 junit 分桶。

> 维护：Sisyphus | 2026-09-14 | 数据：fulltest-data/archive/round-D-14fdf0d56.tar.gz（全量报告逐行核验；2026-09-21 归档）
> 签名引用均为真机日志原文；规避方案均标注验证状态——〔实测〕真机已验证 /
> 〔源码〕配置项或标志已核实存在 / 〔推断〕机制合理但效果待验证。
> 用例规模列：✓=本轮实测值，≈=轮 1 口径（签名模式一致视为同规模）。
