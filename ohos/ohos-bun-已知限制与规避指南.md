# ohos-bun —— 已知限制与规避指南（使用者版）

> **适用对象**：在 OpenHarmony / HarmonyOS 设备上使用 Bun 的开发者与集成方。
> **适用版本**：Bun v1.4.0 OpenHarmony 移植版（构建标识 `615b48e95`），
> aarch64，基于官方 v1.4.0 源码基线。
> **依据**：本版本在 OpenHarmony 真机上完整运行了 Bun 测试套件
> （2001 个测试文件、68,000+ 用例），本文是其中**所有失败项对应到使用者功能**
> 的完整说明。通过率：文件级 90.9%（1819/2001）、用例级 98.65%。
> 相对上一版指南（`14fdf0d56` 口径），本版本修复了 bun run/shell 输出链路、
> npm os 字段门控、目录路由静态托管等面（下文各节已标注）。
>
> **状态标记**：
> - ⚠️ **部分受限** —— 功能主体可用，特定场景有问题（见"当前表现"）
> - ❌ **不可用** —— 该功能/形式当前无法使用
> - 🚧 **平台限制** —— OpenHarmony 平台能力边界，Bun 侧无法单方面修复
>
> **规避验证标注**：
> - ✅ 已验证 —— 该方案在真机上验证过效果
> - 🔧 已核实 —— 配置项/标志/API 确认存在，机制成立，但组合效果建议先小规模验证
> - 💡 建议尝试 —— 机制合理但未逐项验证
>
> **如何优雅降级**：所有规避方案都建议配合平台检测使用：
>
> ```js
> const IS_OHOS = process.platform === "openharmony";
> // 本版本中 process.platform 已正确返回 "openharmony"
> ```

---

## 目录

- [一、核心开发流程](#一核心开发流程)
  - [1.1 bun run —— 运行 package.json scripts](#11-bun-run--运行-packagejson-scripts)
  - [1.2 子进程：Bun.spawn / Bun.spawnSync / node:child_process](#12-子进程bunspawn--bunspawnsync--nodechild_process)
  - [1.3 Bun.$ Shell 与 bun exec](#13-bun-shell-与-bun-exec)
  - [1.4 bun test 的分片与并行](#14-bun-test-的分片与并行)
- [二、包管理](#二包管理)
  - [2.1 bun install 总体状态](#21-bun-install-总体状态)
  - [2.2 git 依赖安装](#22-git-依赖安装)
  - [2.3 原生包平台门控（npm os 字段）](#23-原生包平台门控npm-os-字段)
  - [2.4 npm 预编译原生模块（sharp / canvas / resvg 等）](#24-npm-预编译原生模块sharp--canvas--resvg-等)
  - [2.5 bunx](#25-bunx)
- [三、服务器与网络](#三服务器与网络)
  - [3.1 Bun.serve 基础 HTTP 服务](#31-bunserve-基础-http-服务)
  - [3.2 静态文件 / 目录路由托管](#32-静态文件--目录路由托管)
  - [3.3 WebSocket 长连接](#33-websocket-长连接)
  - [3.4 Unix domain socket 与本地 IPC](#34-unix-domain-socket-与本地-ipc)
  - [3.5 DNS 解析](#35-dns-解析)
- [四、文件系统](#四文件系统)
  - [4.1 Bun.file().slice() 与 Bun.write](#41-bunfile-slice-与-bunwrite)
  - [4.2 fs.watch / 文件变更监听](#42-fswatch--文件变更监听)
  - [4.3 长路径](#43-长路径)
- [五、终端与调试](#五终端与调试)
  - [5.1 Bun.Terminal 与 raw mode](#51-bunterminal-与-raw-mode)
  - [5.2 作业控制信号（Ctrl-Z / SIGWINCH）](#52-作业控制信号ctrl-z--sigwinch)
  - [5.3 调试器 bun --inspect](#53-调试器-bun---inspect)
- [六、沙盒能力边界（EL2 沙箱对运行时的硬约束）](#六沙盒能力边界el2-沙箱对运行时的硬约束)
  - [6.1 硬链接被禁止（EPERM）](#61-硬链接被禁止eperm)
  - [6.2 特权端口绑定（<1024）](#62-特权端口绑定1024)
  - [6.3 根目录 open 全模式 EACCES 与 WASI preopen](#63-根目录-open-全模式-eacces-与-wasi-preopen)
  - [6.4 直接 exec 未签名脚本（EACCES）](#64-直接-exec-未签名脚本eacces)
- [七、框架生态](#七框架生态)
  - [7.1 bake dev / HMR 全栈开发服务器](#71-bake-dev--hmr-全栈开发服务器)
  - [7.2 Next.js / Vite / Astro / expo 等构建工具链](#72-nextjs--vite--astro--expo-等构建工具链)
  - [7.3 第三方客户端库（数据库/消息队列等）](#73-第三方客户端库数据库消息队列等)
- [八、已验证可正常使用的能力](#八已验证可正常使用的能力)
- [九、平台行为差异速览（不构成故障，但与 Linux 不同）](#九平台行为差异速览不构成故障但与-linux-不同)
- [十、限制总览速查表](#十限制总览速查表)
- [十一、最佳实践清单](#十一最佳实践清单)
- [十二、报告问题](#十二报告问题)

---

# 一、核心开发流程

## 1.1 bun run —— 运行 package.json scripts

**状态**：✅ 主体可用（下述四类症状**已在本版本修复**，对应 shell/run 全量
用例转绿——multi-run 121 用例、bunshell 422 用例仅余 1 个 sharp 原生模块
相关用例；历史内容保留供旧版本排查参考）

**正常行为**：`bun run <script>` 读取 package.json 的 `scripts` 字段执行脚本；
默认使用 Bun 内置 shell（bun shell）解释，支持跨平台语法、`.env` 文件自动加载、
`--parallel` 并行执行多个脚本、`--filter` 按工作区过滤执行。

**历史表现**（`14fdf0d56` 及更早构建存在，均已复现并修复）：

1. **脚本中外部命令的输出不可见**
   ```text
   # 期望输出：
   a | output-a
   b | output-b
   # 实际输出（只剩状态行）：
   a: Exited with code 0
   b: Exited with code 0
   ```
   脚本**确实执行了**（退出码正确、文件副作用发生），只是 stdout/stderr 内容
   没有送达终端。最隐蔽的一种：CI/终端里"看起来跑完了"，日志却是空的。

2. **脚本参数丢失**
   ```bash
   bun run script.bun.sh a bb
   # 脚本内 $0/$1/$2 全部为空
   ```

3. **bun shell 脚本 + .env 组合直接失败**
   ```text
   $ echo ENV_FILE_NAME=$ENV_FILE_NAME, NODE_ENV=$NODE_ENV
   error: script "show-env" exited with code 65507
   ```

4. **命令不存在的报错信息损坏**
   ```text
   # 期望：bun: command not found: xxx
   # 实际：error: Failed due to error: bunsh: Illegal seek:
   ```

**原因**（使用者视角的概括）：OpenHarmony 内核对**父子进程之间的管道**
（epoll 事件投递、内存文件 memfd、exec 时的 fd 清理）与标准 Linux 存在多处
行为差异。Bun 内置 shell 与 `bun run` 的输出链路大量依赖这些机制，导致
"子进程跑了、退出码也拿到了，但管道里的内容没送达"。内置 shell 在特定路径上
还会把系统错误码 29（Illegal seek）误当成命令退出码或错误信息展示。

**影响**：

| 场景 | 后果 |
|---|---|
| `bun run dev/build/start` 等日常 scripts | 构建日志、测试输出在终端/CI 中缺失 |
| `bun run build --flag` 带参脚本 | 参数传不进去，脚本按默认值执行——**静默错误构建** |
| 使用 `.env` + bun shell 语法糖的脚本 | 直接报 65507 退出 |
| 依赖脚本输出做断言的 CI 流程 | 断言拿到空字符串而失败 |
| `bun run --parallel a b` | 输出前缀聚合为空 |
| monorepo `bun run --filter` | 各子包输出丢失 |

**规避方案**（按推荐顺序）：

**方案 A（推荐，一处配置解决输出与 .env 两类问题）：改用系统 shell 执行 scripts**

项目根目录 `bunfig.toml`：

```toml
[run]
shell = "system"
```

- 效果：scripts 改由系统 shell（OpenHarmony 自带的 `sh`，toybox/mksh）解释执行，
  输出走系统 shell 的原生管道，不经过有问题的 bun shell 捕获路径。🔧 已核实
  （该配置项存在于本版本，接受值仅 `"bun"` / `"system"`）。
- 局限：
  - scripts 里用的 bun shell 专属语法（如跨平台 `cp`/`rm` 语义差异、bun shell
    的 JS 表达式插值）不再可用——需要脚本写法兼容 POSIX sh；
  - OpenHarmony 设备的 `sh` 是 toybox 精简实现，复杂脚本（`local` 变量、数组、
    进程替换）可能不被支持，建议 scripts 保持简单命令序列；
  - Windows 开发者混用同一 bunfig 时注意：`"system"` 在 Windows 上行为不同，
    建议只在此平台的部署配置里启用。
- ⚠️ 注意：方案 A 主要解决**输出可见性**与 **.env/报错信息**问题；
  **参数丢失**（症状 2）发生在 bun run 的参数解析/再执行链路，建议直接用方案 B。

**方案 B（参数丢失）：环境变量传参**

```bash
# 不依赖位置参数：
BUILD_MODE=production bun run build
```

```json
// package.json
{ "scripts": { "build": "bun run ./build.ts" } }
```

```ts
// build.ts
const mode = process.env.BUILD_MODE ?? "development";
```

- 效果：完全绕开 argv 链路。💡 建议尝试（机制明确，与失败路径无交集）。
- 局限：脚本接口约定变化；含空格/特殊字符的值需自行转义。

**方案 C（并行/过滤输出丢失）：串行化**

```bash
# 不用：
bun run --parallel a b
bun run --filter './pkg/*' test

# 改用：
bun run a && bun run b
for p in pkg1 pkg2; do (cd $p && bun run test); done
```

- 效果：单进程单脚本路径本轮测试表现正常。💡 建议尝试。
- 局限：失去并行加速。

**方案 D（输出留存）：输出重定向到文件**

```bash
bun run build > build.log 2>&1
```

- 效果：即使终端聚合路径有问题，shell 级重定向由系统 shell 完成，日志可落盘。💡
- 局限：与方案 A 二选一即可（A 已走系统 shell 时重定向本来就正常）。

**方案 E（防挂死兜底）：外部超时**

```bash
timeout 300 bun run build
```

- 效果：任何上文问题的最坏表现（挂死）被限制在可控时长。💡
- 局限：无；建议对所有关键 scripts 统一加。

**组合建议**：症状已修复，方案 A + E 可保留为稳妥配置（不强制）。

---

## 1.2 子进程：Bun.spawn / Bun.spawnSync / node:child_process

**状态**：✅ 主体可用（输出捕获残留面已在本版本修复；残余仅个别单用例级
波动——spawnSync / spawn-pipe-leak / child-process-exec 各 1 用例，见全量
测试报告）

**正常行为**：`Bun.spawn()` / `Bun.spawnSync()` / `node:child_process` 的
spawn/exec/execSync 家族，通过 `stdout/stderr: "pipe"` 捕获子进程输出、
`stdin` 传入 Buffer/流、`proc.exited` 等待退出码。

**历史表现**（已修复的四类症状）：

1. **spawn bun 自身作子进程时输出为空**：`Bun.spawn([bunExe, "script.ts"], { stdout: "pipe" })`
   → `stdout.text()` 返回 `""`，退出码正常（0）。spawn **其他**二进制（如 `ls`、
   `cat`）的多数场景正常；spawn **bun 自己**并读其输出是最容易踩的路径
   （测试 runner 拉起 worker、工具链套娃调用）。
2. **`spawnSync` + `stdin: Buffer` 读空**：传给子进程的 stdin 数据丢失，
   子进程读到 EOF。
3. **向已退出子进程的 stdin 写入报 EPIPE**：
   ```text
   EPIPE: broken pipe, send
     syscall: "send", errno: -32
   ```
4. **特定 shell/命令替换场景挂死**：见 1.3。

**原因**：OpenHarmony 上三种底层机制异常：① 用 memfd（内存文件）承载
stdin/stdout=Buffer 的管道时，子进程写入后父进程读到的长度为 0；② 管道 fd 的
epoll 事件在特定注销时序下不再投递（内核对 dup 出的 fd 对做 epoll_ctl(DEL)
会孤立另一个 fd）；③ exec 前的 fd 清理循环在 vfork 子进程内被忽略，导致
fd 泄漏、EOF 永不到达。**本版本已修复上述全部路径**；文件中转/inherit 等
模式保留为跨平台稳妥实践。

**影响**：

| 场景 | 后果 |
|---|---|
| 测试框架用 spawn 拉起 bun 子进程收集结果 | 收到空数组/空串，断言失败 |
| 工具链套娃（bun 调 bun 调 bun） | 中间层输出丢失 |
| `spawnSync` 向子进程喂数据（编译器 stdin 输入、交互式工具自动化） | 子进程读不到数据 |
| 未处理子进程提前退出的写入逻辑 | EPIPE 异常冒出 |

**规避方案**：

**方案 A（输出捕获问题）：让子进程直接写文件，父进程事后读**

```ts
import * as fs from "node:fs";

const out = fs.openSync("/data/local/tmp/child-out.log", "w");
const err = fs.openSync("/data/local/tmp/child-err.log", "w");
const proc = Bun.spawn([bunExe, "worker.ts"], { stdout: out, stderr: err });
await proc.exited;
fs.closeSync(out); fs.closeSync(err);
const result = fs.readFileSync("/data/local/tmp/child-out.log", "utf8");
```

- 效果：fd 直传（数字 fd 形式是 spawn 的标准能力），完全绕开管道捕获路径。💡
  建议尝试（与失败机制无交集）。
- 局限：无实时性；文件需落在可写卷（应用沙箱目录）。

**方案 B（输出捕获问题）：`stdout: "inherit"`**

```ts
const proc = Bun.spawn([bunExe, "worker.ts"], { stdout: "inherit", stderr: "inherit" });
```

- 效果：子进程直写终端，不建管道。🔧（标准能力）
- 局限：父进程无法在进程内读取输出；只适合"看输出"场景，不适合"收集输出"场景。

**方案 C（stdin 传数据问题）：临时文件 / 参数 / 环境变量中转**

```ts
// 不用 stdin: Buffer，改为：
const proc = Bun.spawn([bunExe, "worker.ts", "--input", tmpFilePath]);
// worker.ts 内: const data = await Bun.file(process.argv[4]).text();
```

- 效果：绕开 memfd/管道 stdin 路径。💡
- 局限：不适合大数据量与二进制流；临时文件需手动清理。

**方案 D（EPIPE）：写入前探测退出 + 捕获异常**

```ts
const proc = Bun.spawn(cmd, { stdin: "pipe" });
try {
  await proc.stdin.write("data\n");
  await proc.stdin.flush();
} catch (e) {
  if ((e as any)?.code === "EPIPE") {
    // 子进程已退出：先 await proc.exited 拿退出码与 stderr 再决策
  }
}
```

- 效果：把平台异常转成可处理分支。🔧（标准异常处理）
- 局限：属于容错而非修复；本质上应避免向可能已退出的子进程写入。

**方案 E（防挂死兜底）**：所有 spawn 外包 `timeout`（同 1.1 方案 E）。

---

## 1.3 Bun.$ Shell 与 bun exec

**状态**：✅ 已修复（exit 29 伪失败与 Illegal seek 报错同源于 ESPIPE 错误码
未降级，本版本已在错误码降级集合中修复；`Bun.$` 全量用例转绿。`bun exec`
无独立用例覆盖，建议首次使用时冒烟）

**正常行为**：`Bun.$`（shell 模板串）在 JS 里跑 shell 命令并捕获输出；
`bun exec <script>`（v1.4 新 CLI）直接执行 shell 脚本文件。

**历史表现**（已修复）：

```text
// Bun.$ 调外部命令，输出都拿到了却报失败：
ShellError: Failed with exit code 29
  exitCode: 29,      ← 29 是系统错误码 ESPIPE（Illegal seek），不是真实退出码
  stdout: "hi\n",    ← 命令实际成功
  stderr: ""

// bun exec：
bun exec script.sh
error: Failed due to error: bunsh: Illegal seek:    ← 且 path 为空
// 多数用例 stdout 为空
```

**原因**：与 1.1/1.2 同源（管道捕获 + 错误码串台）。内置 shell 把 errno 29
当成了子进程退出码上报，`bun exec` 的错误路径把错误结构未填充就抛出。

**影响**：

| 场景 | 后果 |
|---|---|
| 脚本里用 `await Bun.$\`cmd\`` | 成功的命令被误判失败（exit 29），try/catch 误触发 |
| `bun exec` | 基本不可用 |
| 依赖 `$` 输出捕获的构建脚本 | 输出空 |

**规避方案**：

**方案 A（`Bun.$` exit 29 伪失败）**：以 stdout 内容为准做业务判断

```ts
try {
  const r = await Bun.$`cat foo.txt`;
} catch (e) {
  if (e?.exitCode === 29 && e?.stdout) {
    // 本平台已知伪失败：命令实际成功，继续用 e.stdout
  } else throw e;
}
```

- 效果：短期容错。💡
- 局限：无法区分"真的 ESPIPE 失败"与伪失败——若命令确实产生空 stdout，
  仍按失败处理即可。

**方案 B（替代 `bun exec`）**：

```bash
# 用 bun run + 系统 shell（见 1.1 方案 A 的 bunfig 配置）：
bun run ./script.sh
# 或直接：
sh ./script.sh
```

- 效果：绕开 `bun exec` 整条链路。💡
- 局限：`bun exec` 的"单命令直达"便利性暂缺。

**方案 C（替代 `Bun.$` 捕获输出）**：用 1.2 方案 A 的文件中转 spawn 模式。

**修复说明**：ESPIPE（errno 29）已加入管道错误码降级集合，`Bun.$` 伪失败与
`bun exec` 的 Illegal seek 报错同源消失。

---

## 1.4 bun test 的分片与并行

**状态**：✅ 已修复（并行拉起子进程的输出捕获随 F1 修复覆盖；`bun run
--parallel` 121 用例全量通过；纯 shard 持续验证通过）

**正常行为**：`bun test --shard=k/n` 把测试文件分片；`--parallel` 并行执行。

**历史表现**（已修复）：

- `bun test --shard=1/2 --parallel`（组合）曾出现分片内子进程输出收集为空
  （`RAN fXX` 标记收不到）、结果聚合失败。

**现行建议**：

- 分片与并行可正常组合；CI 上大套件仍推荐"**CI 层并行**"（多个 runner 各领
  一个 shard，runner 内部串行）——提速效果等价且不依赖端侧多进程。

---

# 二、包管理

## 2.1 bun install 总体状态

**状态**：⚠️ 主体可用，两类场景受限

**正常行为**：registry 安装、lockfile、workspaces、catalogs、overrides、
audit 等主体功能在本版本真机测试中大面积通过。

**当前表现**：

1. **git 依赖**：✅ 已在本版本修复（git 依赖安装用例全量通过）；tarball 化
   （见 2.2）仍推荐为离线/弱网环境的稳妥实践。
2. **平台门控**：✅ 已在本版本修复（见 2.3）。
3. **资源压力**：大型依赖树 + 多进程并发安装时，设备可能因内存压力杀掉
   下载/解压进程（表现为安装进程被 SIGKILL、或对 registry 的连接被拒）。
   真机测试中 registry 密集型用例的批量失败均源于此。

**影响与规避**（资源压力面）：

- 大项目安装**串行执行**，避免多进程同时 `bun install`；
- 复用全局缓存减少下载与解压峰值：

  ```toml
  # bunfig.toml —— 缓存指向持久卷
  [install.cache]
  dir = "/data/local/tmp/bun-cache"
  ```

  🔧 已核实（配置项存在）。
- 安装报 `ConnectionRefused` / 进程被杀时，先降低并发再怀疑网络。

---

## 2.2 git 依赖安装

**状态**：✅ 已在本版本修复（git 依赖安装用例全量通过；signal 9 与超时两类
症状均未复现）。tarball 化 / vendor 等方案保留为离线与弱网环境的稳妥实践。

**历史表现**（已修复）：

```text
# 类型一：git 子进程被杀
error: git failed with signal 9
error: "git clone" for "pkg" failed

# 类型二：多分支复杂依赖树超时
this test timed out after 30000ms   （"many branches ... directly and transitively"）
```

**历史原因**：类型一——`bun install` 拉起的 git 子进程收到 SIGKILL（曾怀疑
"父进程死亡信号"（PR_SET_PDEATHSIG）在 OpenHarmony 线程模型下的语义差异，
后经源码级排查证伪）。类型二——git clone/checkout 在 hmdfs（用户存储卷）上
I/O 慢，叠加间歇性异常后超出超时预算。

**影响**：

| 场景 | 后果 |
|---|---|
| `bun add git+https://github.com/...` | 安装失败（signal 9） |
| 私有 monorepo git 依赖 | 安装失败或超时 |
| 同一仓库多分支直连+传递引用 | 30s 超时 |

**规避方案**（推荐度从高到低）：

**方案 A（推荐）：git 依赖 tarball 化** —— ✅ 已验证（tarball 安装链路在本版本
真机测试中完整通过）

```bash
# GitHub：用 codeload 归档 URL 代替 git+https
bun add https://codeload.github.com/<org>/<repo>/tar.gz/refs/heads/<branch>
bun add https://codeload.github.com/<org>/<repo>/tar.gz/refs/tags/v1.2.3

# GitLab：
bun add https://gitlab.com/<org>/<repo>/-/archive/<ref>/<repo>-<ref>.tar.gz

# Gitee：
bun add https://gitee.com/<org>/<repo>/repository/archive/<ref>.zip
```

- 局限：失去 git 协议的增量拉取（每次全量 tarball）；URL 固定了 ref，更新需改 URL。

**方案 B：预下载 + 本地安装**

```bash
# CI/开发机上：
git clone --depth 1 https://github.com/org/repo && tar czf repo.tgz repo
# 设备上：
bun add ./repo.tgz          # 本地 tarball
bun add ./repo/             # 本地目录
```

- 效果：设备上完全不跑 git。✅ 链路已验证（本地 tarball/目录安装正常）。
- 局限：多一步预下载流程。

**方案 C：vendor 进仓库（`file:` 依赖）**

```json
{ "dependencies": { "my-pkg": "file:./vendor/my-pkg" } }
```

- 效果：彻底离线化，最稳。💡
- 局限：仓库体积；更新手动。

**方案 D（缓解超时型）**：减少引用形式——同一仓库固定单一 ref；必要时
`overrides` 把传递的 git 依赖钉到 tarball/版本号。

---

## 2.3 原生包平台门控（npm os 字段）

**状态**：✅ 已在本版本修复（平台名匹配表已收录 `openharmony`，含
`"!openharmony"` 排除语义；os/cpu 门控按 npm 规范工作，真机验证
architecture-match 30/30 通过）

**当前行为**：

- 包声明 `"os": ["openharmony"]` → 正常命中（鸿蒙原生变体可直接安装）；
- 包声明 `"os": ["!openharmony"]` → 正确排除；
- 包声明 `"os": ["linux"]` → **不命中**（修复后按 `process.platform` 的实际值
  `openharmony` 严格匹配）。

**⚠️ 行为变化提醒**：修复前的构建缺失 `openharmony` 键，平台匹配曾退化为
"按 linux 处理"，linux 系变体因此"碰巧装得上"。修复后匹配变**严格**——
发布 `"os": ["linux"]` 门控的包（常见于 linux 预编译原生模块）**不会再被
隐式安装**。

**现行建议**：

**方案 A（装 linux 系预编译变体，如 musl prebuilds）**：显式指定安装目标

```bash
bun install --os=linux --libc=musl
```

- 🔧 已核实（`--os`/`--libc` 标志存在）。把"能不能加载"交给 musl 兼容层控制
  （OpenHarmony 用户态是 musl 基，musl 变体兼容性远好于 glibc）。
- 局限：对本次安装全局生效；建议只用于依赖原生模块的项目安装。

**方案 B（不兼容包误装防护）**：`overrides` 钉版本 + 优先选择发布了
linux-musl-arm64 预编译的版本（见 2.4）。

**方案 C：vendor（`file:` 依赖）**，绕过整套门控。

---

## 2.4 npm 预编译原生模块（sharp / canvas / resvg 等）

**状态**：⚠️ 生态缺口（非 Bun 缺陷，但影响真实）

**正常行为**：此类包通过 `optionalDependencies` 按平台/ABI 下载预编译
`.node` 文件。

**当前表现**：npm 生态**没有 openharmony 目标的预编译产物**。安装时命中的是
linux-arm64 变体；其中 glibc 链接的 `.node` 在 OpenHarmony（musl 基）加载失败，
musl 链接的部分可用。

**影响**：图像处理（sharp）、Canvas 绘制（napi-rs-canvas）、SVG 渲染（resvg）
等**装上即崩**或功能缺失。

**规避方案**：

1. **优先选择发布 linux-musl-arm64 prebuild 的版本**（如 sharp 的
   `@img/sharp-linuxmusl-arm64`）。⚠️ 修复后平台匹配变严格，这类 `os:["linux"]`
   变体**默认不再命中**——安装时显式指定目标（见 2.3 方案 A）：

   ```bash
   bun install --os=linux --libc=musl
   ```

   安装后先跑一次最小用例验证加载：

   ```js
   import sharp from "sharp";
   await sharp(Buffer.from(`<svg width="8" height="8"/>`)).png().toBuffer();
   ```

   💡（musl-on-OHOS 兼容性逐包验证）
2. **发布鸿蒙变体的包**：`"os": ["openharmony"]` 门控现在可直接安装，无需 patch。
3. **架构性规避**：图像/SVG 处理放到服务端或 x86 侧，设备端只消费结果。
4. 长期：等鸿蒙原生 prebuilds 生态补齐。

---

## 2.5 bunx

**状态**：⚠️ 缓存目录所有权误拒

**当前表现**：

```text
refusing to use bunx cache directory … not a directory owned by the current user
```

**原因**：OpenHarmony 用户存储卷（hmdfs）上 `stat` 返回的 uid 语义与
`getuid()` 不一致，bunx 的"缓存目录必须属于当前用户"安全检查被误触发。

**影响**：`bunx <pkg>` / `bun x <pkg>` 在缓存目录落在 hmdfs 时拒绝执行。

**规避方案**：💡（机制合理，效果取决于设备 uid 映射，逐环境验证）

```bash
export BUN_INSTALL_CACHE_DIR=/data/local/tmp/bunx-cache
mkdir -p $BUN_INSTALL_CACHE_DIR
bunx cowsay hi
```

把缓存目录指到应用沙箱/`/data/local/tmp` 卷。若该卷的 stat uid 仍有同样的
映射问题，则暂无干净规避，等待修复。

---

# 三、服务器与网络

## 3.1 Bun.serve 基础 HTTP 服务

**状态**：⚠️ 部分受限

**正常行为**：`Bun.serve()` 提供高性能 HTTP/1.1 服务，支持 keep-alive 连接
复用、文件流式响应、路由。

**当前表现**：基础请求-响应、路由分发整体可用；**部分场景不可靠**——
连接复用（keep-alive）下的响应投递、`Response(Bun.file)` 流式文件响应、
大响应体，在真机测试中存在失败/超时样本。HTTP/3（QUIC）面未验证可靠。

**原因**：`Bun.serve` 的底层网络栈（uSockets）启用了 `epoll_pwait2` 系统调用，
OpenHarmony 内核对它的支持存在缺陷，导致特定事件投递路径丢事件。

**影响**：

| 场景 | 后果 |
|---|---|
| 高并发长连接服务 | 个别连接响应滞留/超时 |
| `new Response(Bun.file(...))` 大文件流式返回 | 响应体为空或截断（部分场景） |
| HTTP/3 客户端 | 不可依赖 |

**规避方案**：

**方案 A：短连接模式**

服务端响应加 `Connection: close` 头（HTTP/1.1 服务端有权声明关闭连接）：

```ts
Bun.serve({
  fetch(req) {
    return new Response(body, {
      headers: { "Connection": "close" },
    });
  },
});
```

- 效果：绕开 keep-alive 连接复用下的事件投递问题。💡（机制成立，建议压测验证）
- 局限：每请求建连，高 QPS 下开销上升——用**短连接 + 应用层幂等重试**组合。

**方案 B：响应体落内存再返回**

```ts
// 不用流式：
fetch: () => new Response(Bun.file("big.html"));
// 改为整读后返回：
fetch: async () => new Response(await Bun.file("big.html").arrayBuffer());
```

- 效果：避开流式读路径（与 4.1 同一读循环域）。💡
- 局限：大文件占内存；中小文件（< 几 MB）无感。

**方案 C：应用层兜底**：客户端超时 + 重试 + 幂等设计（对该类服务本来就是标配）。

---

## 3.2 静态文件 / 目录路由托管

**状态**：✅ 已在本版本修复（目录路由 28 用例全量通过，连续两轮保持）

**正常行为**：`Bun.serve({ routes: { "/*": { dir: "./public" } } })` 把目录
挂成静态站点，自动解析 index.html、嵌套路径、自定义前缀。

**历史表现**（已修复）：曾出现 `GET /index.html → 404`、嵌套路径响应体为空、
自定义前缀 404 等（目录路由的文件查找路径异常，与平台文件语义/事件投递层
相关）；真机上静态站点/SPA 资源托管曾不可用。

**备注**：旧版指南的"catch-all handler 手写静态服务"方案仍是一种有效的
自定义模式（需要自控 MIME/缓存/HEAD/Range 时可用），但已不再必要。

---

## 3.3 WebSocket 长连接

**状态**：✅ 主体可用（WebSocket 收发/服务端用例全量通过；unix socket 形式
的 WS 受 3.4 落点限制）

**当前表现**：`Bun.serve` 的 WebSocket（`websocket` 处理器）基础收发、长连接
用例在本版本全量测试中通过；早期构建的"连接建立后事件不再投递"样本未再现。
调试器通道见 5.3。

**建议**（长连接应用的本职实践，本平台上照常适用）：

- **应用层心跳 + 断线重连**：
  ```js
  // 客户端每 15s ping；连续 2 次无 pong 即重连，指数退避
  ```
- 服务端对 `close`/`drain` 回调不要假设时序，状态以心跳为准。
- 推送消息带序号，客户端重连后按序补拉（HTTP 兜底接口）。

---

## 3.4 Unix domain socket 与本地 IPC

**状态**：⚠️ 路径敏感

**正常行为**：`Bun.listen({ unix: path })` / `net.Socket` path 连接 /
`fetch(url, { unix: path })` 走本地 socket。

**当前表现**：socket 文件落在**用户存储卷（hmdfs）**时 `bind` 报
`EPERM`——OpenHarmony 的 hmdfs 不支持 AF_UNIX。落在支持 AF_UNIX 的卷
（如 `/data/local/tmp`）时正常。

**原因**：文件系统能力差异，非 Bun 缺陷；Bun 已内置 tmpdir 探测缓解测试类
场景。

**影响**：本地 IPC（进程间通信、unix socket 上的 HTTP/WS）依赖 socket 文件
落点。

**规避方案**：✅（探测顺序已验证）

```bash
# 把所有本地 IPC 的 socket 文件建到 AF_UNIX 可用卷：
export TMPDIR=/data/local/tmp
```

```ts
// 代码中显式指定，不依赖默认 tmpdir：
Bun.listen({ unix: "/data/local/tmp/myapp.sock", socket: {...} });
```

- 原则：**socket 文件一律显式指到 `/data/local/tmp`（或应用沙箱内确认支持
  AF_UNIX 的目录）**，不要落在 `os.tmpdir()` 的默认值（可能解析到 hmdfs）。
- 附带影响：`fetch(unix:)`、`websocket-unix` 形式在 socket 文件落点正确时可用。

---

## 3.5 DNS 解析

**状态**：⚠️ 失败模式退化

**正常行为**：`dns.lookup()` 对不存在的域名快速返回 ENOTFOUND 类错误
（毫秒级）。

**当前表现**：不存在的域名**约 2 秒后**才报 `getaddrinfo ETIMEOUT`——设备
DNS 链路对无效域名不返回权威 NXDOMAIN，而是等超时。

**原因**：系统 resolver 语义差异（上游 DNS 不回权威应答时只能等超时）。

**影响**：依赖"快速失败"逻辑的场景被拖慢——多地址竞速、降级重试、健康检查；
离线/弱网设备上所有解析失败路径统一变慢 2 秒。

**规避方案**：

**方案 A：应用层超时包装**（通用、必配）

```ts
function lookupWithTimeout(host: string, ms = 1500) {
  return Promise.race([
    Bun.dnsLookup?.(host) ?? import("node:dns").then(d => d.promises.lookup(host)),
    new Promise((_, rej) => setTimeout(() => rej(new Error("dns-timeout")), ms)),
  ]);
}
```

- 局限：治标（错误的**种类**仍是超时而非 NXDOMAIN），但把拖慢的上限收回应用控制。

**方案 B：改用 c-ares 路径**

```ts
import dns from "node:dns";
dns.resolve4(host)   // 走 c-ares，与 getaddrinfo 是不同实现，失败模式可能不同
```

- 💡 需逐场景验证（本平台 c-ares 对 NXDOMAIN 的行为未系统验证）。

**方案 C：关键服务直连 IP + 自管解析**（内网/固定服务场景最稳）。

---

# 四、文件系统

## 4.1 Bun.file().slice() 与 Bun.write

**状态**：⚠️ 数据正确性缺陷（触发面窄；**短期不修**——修复方与集成方共识
PARKED，以规避为主）

**正常行为**：`Bun.file(path).slice(start, end)` 创建只读切片视图；
`Bun.write(dest, fileSlice)` 将切片内容写入目标——只写 start..end 范围。

**当前表现**：**切片被无视，写入了整个源文件**（本版本全量测试中仍有 1 用例
复现）：

```ts
await Bun.write(dst, Bun.file(src).slice(0, half));
// 期望：dst 有前一半内容
// 实际：dst 是完整文件
```

**原因**：文件只读切片的读取路径在 OpenHarmony 上未截断。

**影响**：分块拷贝、断点续传、部分文件读取后转存等场景**静默写错数据**。

**规避方案**：🔧（JS 侧切片，语义完全等价）

```ts
const buf = await Bun.file(src).arrayBuffer();
await Bun.write(dst, new Uint8Array(buf, 0, N));      // 前 N 字节
await Bun.write(dst, new Uint8Array(buf, start, end - start)); // 任意区间
// 或对 Buffer：
await Bun.write(dst, Buffer.from(buf).subarray(start, end));
```

- 效果：切片逻辑由 JS 完成，不依赖平台 read 路径的截断行为。
- 局限：整文件先入内存——大文件请分块读（`File.prototype.slice` 之外，
  可用 `file.stream()` 自行截断，或固定块长循环 `pread`——`node:fs` 的
  `read(fd, buffer, offset, length, position)` 定位读在本平台测试中未见异常）。

---

## 4.2 fs.watch / 文件变更监听

**状态**：⚠️ 不可靠

**当前表现**：`fs.watch()` / `Bun.file` watcher 在部分目录（尤其 hmdfs 卷）
上收不到变更事件或事件不完整。

**原因**：inotify 在 hmdfs/沙箱卷上的支持与语义差异。

**影响**：热重载（`--watch`/`--hot`）、配置热更新、dev server 文件监听失效
或迟滞。

**规避方案**：🔧

**方案 A：轮询替代事件**

```ts
import * as fs from "node:fs";

function watchByPolling(path: string, onChange: () => void, intervalMs = 1000) {
  let last = 0;
  const timer = setInterval(() => {
    try {
      const m = fs.statSync(path).mtimeMs;
      if (last && m !== last) onChange();
      last = m;
    } catch { /* 文件暂不可见：保持轮询 */ }
  }, intervalMs);
  return () => clearInterval(timer);
}
```

- 目录监听：对目录 stat + 比较条目数/mtime，或对关键文件逐个轮询。
- 局限：CPU 换实时性；interval 建议 ≥1s（设备端功耗）。

**方案 B：Vite 等工具的内置轮询开关**

```ts
// vite.config.ts
export default { server: { watch: { usePolling: true, interval: 1000 } } };
```

- 💡（vite 的 usePolling 是标准能力；配合 7.2 的"构建留 x86"原则，端侧监听
  场景本身应尽量少）

---

## 4.3 长路径

**状态**：⚠️ 边缘限制

**当前表现**：EL2 应用沙箱路径前缀很长（`/storage/Users/currentUser/...`），
叠加深层 `node_modules` 嵌套后可能触及路径长度上限（glob 大深度扫描用例在真机
失败）。

**规避方案**：

- 项目部署到**浅目录**（如 `/data/local/tmp/app`）；
- 安装用 isolated linker 减少嵌套深度（若 isolated 安装本身可用——注意其
  registry 场景受 2.1 资源面影响）；
- 依赖树尽量扁平（减少重复嵌套依赖）。

---

# 五、终端与调试

## 5.1 Bun.Terminal 与 raw mode

**状态**：✅ 基本可用（历史问题已在本版本修复）

**说明**：早期版本在 PTY 上 `setRawMode()` 必抛 `Failed to set raw mode`
（OpenHarmony 拒绝在 PTY master 上做排空型 tcsetattr）。**本版本已修复**
（EACCES 时自动回退 `TCSANOW`）：raw mode 开/关/切换、行编辑、CRLF 转换、
写满回压等真机验证通过。

**残余限制**：见 5.2。

## 5.2 作业控制信号（Ctrl-Z / SIGWINCH）

**状态**：🚧 平台限制

**当前表现**：在 PTY 上，控制字符被**回显成字面字符但不生成信号**——
`Ctrl-Z` 后子进程不会收到 SIGTSTP、终端窗口尺寸变化不产生 SIGWINCH
（内核行规程限制，已用独立 C 探针确证）。

**影响**：

| 场景 | 后果 |
|---|---|
| TUI 应用挂起/恢复（Ctrl-Z → fg） | 不可用 |
| 全屏应用自适应终端尺寸 | 收不到 resize 事件 |
| 依赖 SIGTSTP/SIGCONT 的进程管理 | 不可用 |

**规避方案**（应用侧降级，无法根治）：

```js
if (process.platform === "openharmony") {
  // 1) resize：改轮询终端尺寸
  setInterval(() => {
    const { columns, rows } = process.stdout;   // 每次读取当前值
    if (columns !== lastCols || rows !== lastRows) relayout(columns, rows);
  }, 500);

  // 2) "挂起"改用应用级语义（如自制暂停快捷键），不依赖 Ctrl-Z；
  // 3) UI 上隐藏不支持的能力（挂起/作业控制提示）。
}
```

- 这属于 OpenHarmony PTY 行规程的能力边界（与 Linux 行为差异永久存在，
  除非平台侧补齐信号生成）。

## 5.3 调试器 bun --inspect

**状态**：⚠️ host:port 形式可用，unix path 形式受限

**当前表现**：

- `bun --inspect=127.0.0.1:<port>`（数字形式）：✅ 正常。
- `bun --inspect=/path`（unix path / 子路径形式）：绑定失败时**错误文本被
  当成 WS URL 返回**，客户端收到 `{"protocol":"code:","pathname":" \"EADDRINUSE\""}` 
  这样的乱码 URL；叠加多进程同端口时的 EADDRINUSE 竞争。

**原因**：inspect 的服务端绑定失败分支未正确格式化错误；底层与 3.1 同源
（uSockets 事件栈）。

**影响**：VS Code / Chrome DevTools attach 在 unix path 形式与端口冲突场景
不可用。

**规避方案**：

- **每个被调试进程用唯一显式端口**，串行 attach：
  ```bash
  bun --inspect=127.0.0.1:9231 app1.ts
  bun --inspect=127.0.0.1:9232 app2.ts
  ```
  ✅（数字形式用例全过）
- 避免固定端口号的多进程同时启动（脚本里用 `$((9300 + RANDOM % 100))` 分配）；
- unix path 形式暂不使用。
- 修复预期：与 3.1 的底层网络栈修复同批。

---

# 六、沙盒能力边界（EL2 沙箱对运行时的硬约束）

> 本节的四个限制**与 Bun 实现无关**，源于 OpenHarmony 应用的 EL2 沙箱模型
> （路径白名单 + 能力裁剪 + 代码签名强制）。任何运行时（node、python、任何
> 原生程序）在沙箱内都会遇到同样的边界。它们**无法由 Bun 单方面修复**，
> 这里给出的是"沙箱允许的做法"范围内的规避。用一句话概括沙箱授予了什么：
> **应用只拥有自己沙箱目录（`/data/storage/el2/base/` 与 `/data/local/tmp`
> 一类临时卷）的完整文件权限、非特权网络能力、以及"已签名二进制才能 exec"
> 的进程模型**——其余一律拒绝。

## 6.1 硬链接被禁止（EPERM）

**状态**：🚧 平台限制

**正常行为**：POSIX 上 `fs.link()` 在同一文件系统内创建硬链接（多个目录项
指向同一 inode），零拷贝、零额外空间。Bun 的包安装器在 Linux 上默认用
**硬链接**把全局缓存里的包物化到项目 `node_modules`（`--backend hardlink`
是默认值），速度最快、多项目共享缓存时磁盘占用最小。

**当前表现**：

```text
fs.linkSync(a, b)
→ Error: EPERM: Operation not permitted, link '...' -> '...'

bun install
→ 与 linker/backend 相关的安装失败（物化阶段 EPERM）
```

**关键事实**：**任何路径、任何目录都会失败**——不是权限位或属主问题，
沙箱在系统调用层面直接拒绝了 `link()`。同时被禁的还有 `linkat()`。

**原因**：EL2 沙箱策略。硬链接可以用来绕过目录级配额与隔离（链接到别的
应用可见但计费/配额之外的文件），平台选择整体禁止。

**影响**：

| 场景 | 后果 |
|---|---|
| `bun install` 默认安装 | 物化 `node_modules` 阶段失败 |
| 应用代码使用 `fs.link` / `fs.linkSync` / `fs.promises.link` | EPERM |
| 依赖硬链接去重的工具（pnpm-style store、硬链接缓存） | 无法工作 |
| 个别包的 postinstall 脚本创建硬链接 | 安装脚本失败 |

**规避方案**：

**方案 A（安装场景，推荐）：显式换安装后端** —— 🔧 已核实（三种后端均存在）

```bash
# copyfile：从缓存全量拷贝，最稳
bun install --backend=copyfile

# 或固化到项目 bunfig.toml：
```

```toml
[install]
backend = "copyfile"
```

- 后端对照：
  | 后端 | 机制 | 本平台适用性 |
  |---|---|---|
  | `hardlink`（Linux 默认） | 缓存 → node_modules 硬链接 | ❌ 沙箱禁止 |
  | `copyfile` | 全量拷贝 | ✅ 推荐（代价：磁盘占用变大、安装变慢） |
  | `symlink` | 符号链接进全局缓存 | ✅ 可用（代价：缓存目录必须持久且与项目同生命周期；删除缓存会损坏 node_modules） |
- 空间预估：copyfile 下每个项目完整复制依赖树——依赖大的项目注意设备存储
  预算；可将全局缓存放到大容量卷（`[install.cache] dir`）。

**方案 B（应用代码）：链接失败回退拷贝**

```ts
import * as fs from "node:fs";

function linkOrCopy(src: string, dest: string) {
  try {
    fs.linkSync(src, dest);
  } catch (e: any) {
    if (e?.code === "EPERM" || e?.code === "EOPNOTSUPP") {
      fs.copyFileSync(src, dest);
    } else throw e;
  }
}
```

- 效果：跨平台健壮（其他平台仍享受硬链接零拷贝）。💡
- 局限：放弃去重收益；大量小文件时 hmdfs 拷贝慢。

**方案 C（postinstall 类包）**：用 `patchedDependencies` 把包内创建硬链接的
脚本改为拷贝，或把该包加入 vendor。

---

## 6.2 特权端口绑定（<1024）

**状态**：🚧 平台限制

**正常行为**：Linux 上 root 进程或持有 `CAP_NET_BIND_SERVICE` 能力的进程
可以绑定 0–1023 的知名端口（HTTP 80、HTTPS 443、DNS 53 等）。

**当前表现**：

```ts
Bun.listen({ port: 80, ... });
// 或 node:net / node:http 的 server.listen(80)
// → Error: EACCES（errno 13）—— bind 被拒
```

**原因**：EL2 沙箱启动应用进程时**不授予** `CAP_NET_BIND_SERVICE`，且平台
不提供应用级提权途径（无 root、`setcap` 不可用）。

**影响**：

| 场景 | 后果 |
|---|---|
| 设备上跑 HTTP 服务直绑 80 / TLS 直绑 443 | EACCES 启动失败 |
| 依赖知名端口的协议工具（本地 DNS 53、常用调试端口类） | 失败 |
| **端口 ≥1024 的全部场景** | ✅ 不受影响（8080、3000 等正常） |

**规避方案**：

**方案 A（推荐）：一律用高位端口** —— 端口配置化：

```ts
const PORT = Number(process.env.APP_PORT ?? 3000);   // 默认落在非特权区间
Bun.serve({ port: PORT, ... });
```

并在文档/配置里明确"本平台不支持 <1024"。

**方案 B（必须对外呈现 80/443 的场景）：网关侧映射** —— 设备上无 root，
iptables/NAT 重定向不可用，端口映射只能放在设备之外：

```text
局域网主机 nginx：listen 80 → proxy_pass http://<设备IP>:3000
```

- 适用：设备作为服务端被局域网访问的形态（智能家居网关、调试面板）。
- 局限：需要一台网关角色设备；纯端侧独立运行无法伪装知名端口。

**方案 C：启动失败自动降级**

```ts
try {
  server = Bun.serve({ port: desiredPort, ... });
} catch (e: any) {
  if (e?.code === "EACCES" && desiredPort < 1024) {
    server = Bun.serve({ port: desiredPort + 8000, ... });   // 80 → 8080
  } else throw e;
}
```

- 💡 与方案 A 组合，兼容"配置误填特权端口"的用户。

---

## 6.3 根目录 open 全模式 EACCES 与 WASI preopen

**状态**：🚧 平台限制

**正常行为**：POSIX 上任何进程都能 `open("/", O_RDONLY)`（列目录、探测文件
系统根）；WASM/WASI 模块通过 `preopens` 把宿主目录挂进沙箱化的 wasm 文件
系统——生态里大量由 napi-rs 工具链生成的 WASM 兜底模块**硬编码
`preopens: { "/": "/" }`**（把宿主根目录整个预打开）。

**当前表现**：

```js
fs.openSync("/", "r")
// → Error: EACCES: Operation not permitted, open '/'
// 注意：只读也一样失败——这是策略拒绝，不是权限位问题
```

**原因**：EL2 的路径白名单模型。应用被授予的只有自己的沙箱目录与指定临时卷；
`/` 不在授权表里，**任何模式**的 open 都在沙箱层被拒。WASI preopen 指向 `/`
等价于请求整个文件系统 → 同样被拒。

**影响**：

| 场景 | 后果 |
|---|---|
| 应用代码 `open`/`stat`/`readdir` 根目录 | EACCES |
| 以 `path.parse(cwd).root`（恒为 `"/"`）做起点扫描/探测的代码（glob 根扫描、向上查找边界判断） | 失败或行为异常 |
| **WASM/WASI 兜底路径**（napi-rs 生成的 `*.wasi.cjs`，rspack/oxide 类包的 wasm fallback） | **启动即失败——此路不通** |
| 启动时探测 `/` 判断环境的库 | 拿到错误结论 |

**规避方案**：

**方案 A（文件系统根概念）：用沙箱根替代 `/`**

```ts
// ❌ 不可用：
const root = "/";
// ✅ 平台沙箱根：
const IS_OHOS = process.platform === "openharmony";
const FS_ROOT = IS_OHOS ? "/data/storage/el2/base" : "/";
// 向上查找（如找最近的 package.json）以 FS_ROOT 为边界，而不是 "/"
```

- 💡 机制明确；同时让代码在其他平台保持原语义。

**方案 B（WASM/WASI 兜底包）：不要依赖 wasm32 fallback** —— 此为死路：

1. **优先提供/选择原生绑定**（OHOS 原生 `.node` 或纯 JS 实现），跳过
   `*.wasi.cjs` 路径；
2. 若必须走 WASI：patch 生成的胶水文件，把 preopen 从 `/` 改到沙箱目录：

   ```bash
   bun patch some-wasm-pkg
   # 在生成的 *.wasi.cjs 中：
   #   preopens: { "/": "/" }
   # 改为：
   #   preopens: { "/sandbox": "/data/storage/el2/base/files" }
   # 注意 wasm 模块内部的路径引用也要同步改前缀
   ```

   - 局限：⚠️ 改的是工具链生成物，重装/升级包会还原；且 wasm 内部若硬编码
     绝对路径 `/`，仅改 preopen 不够——逐包验证。💡
3. **连带注意**：包若用 `"cpu": ["wasm32"]` 声明 wasm 变体，安装器会按架构
   门控拒装（本平台匹配不到 wasm32）——这反而省去了运行时踩坑，属预期行为。

**方案 C（探测类代码）：探测降级模式**

```ts
function canReadRoot() {
  try { fs.readdirSync("/"); return true; }
  catch { return false; }   // 本平台：false → 改用沙箱根
}
```

---

## 6.4 直接 exec 未签名脚本（EACCES）

**状态**：🚧 平台限制（Bun 侧已内置大部分缓解）

**正常行为**：Linux 上 `#!` 脚本文件可以直接 `execve`——内核认 shebang 行，
转交解释器执行。脚本无须任何"可执行元数据"。

**当前表现**：

```text
execve("./script.sh")   → EACCES / EPERM
```

OpenHarmony 强制**代码签名**：可执行映像必须带平台签名（由签名工具处理，
且只认 ELF 格式）。文本脚本无法携带签名段 → 内核 exec 关卡直接拒绝。

**Bun 已内置的缓解（无需用户操作）**：本版本 Bun 在 spawn 前**用户态展开
shebang**——解析脚本首行 `#!`，改为直接 exec（已签名的）解释器、脚本降级为
普通参数传入。因此**由 Bun 发起的脚本执行**（`bun run`、`Bun.spawn`/
`Bun.spawnSync`、`node:child_process` 中由 bun 进程发起的部分）绝大多数场景
已经绕开签名关卡。✅（此路径在真机测试中验证）

**仍会踩的残余面**：

| 场景 | 是否受影响 | 说明 |
|---|---|---|
| `Bun.spawn(["./script.sh"])`（bun 发起） | ✅ 已缓解 | shebang 展开接管 |
| 脚本**没有** shebang 行且被直接 exec | ❌ | 无法识别解释器，bun 也无从展开 |
| `sh -c './script.sh'`（shell 再 exec 脚本） | ❌ | exec 由 `sh` 发起，绕过 bun 的展开；内核仍拒文本脚本 |
| 脚本 A 内部再 exec 脚本 B（`exec ./b.sh`） | ❌ | 同上——孙进程的 exec 不经过 bun |
| 设备上其他组件/进程 exec bun 创建的脚本 | ❌ | 与 bun 无关，签名关卡必然拒绝 |

**规避方案**：

**方案 A（最简）：让解释器"读"脚本而不是"exec"脚本**

```bash
# ❌ 这些写法最终会 exec 脚本文件本身：
sh -c ./script.sh
./script.sh

# ✅ 解释器读入脚本内容解释执行，不 exec 脚本映像：
sh ./script.sh
bash ./script.sh
bun ./script.ts
node ./script.js
```

- 区别一句话：`sh ./x.sh` = 解释器打开文件读内容（文件只需可读）；
  `sh -c ./x.sh` = 解释器请求内核执行该文件（文件必须可执行且已签名）。💡
- 生成子命令时注意：`child_process.exec("sh ./x.sh")` 安全，
  `exec("./x.sh")` 会踩。

**方案 B：保证脚本带 shebang 行**

```sh
#!/bin/sh
# 有这一行，bun 发起的执行才能自动展开；没有则无解
```

- 🔧（bun 的展开逻辑以 `#!` 识别为前提）。

**方案 C（动态生成可执行逻辑的场景）**：改"生成脚本 + exec"为
"生成数据 + 固定解释器读"：

```ts
// ❌ 运行时生成 script.sh 再 spawn 它
// ✅ 运行时生成 params.json，用固定的、已存在的解释器消费：
await Bun.write("/data/local/tmp/params.json", JSON.stringify(args));
Bun.spawn(["sh", "/app/scripts/worker.sh", "/data/local/tmp/params.json"]);
```

- 效果：被 exec 的只有**安装时就签名好的**解释器，运行时产物永远是数据。💡
- 这也是把此限制转化为稳定架构的一般模式：**运行时只生产数据，不生产可执行映像**。

**方案 D（多层脚本链）**：链中每一层都用"解释器读"形式衔接
（`sh a.sh` → a.sh 里写 `sh ./b.sh` 而非 `exec ./b.sh`）。

---

# 七、框架生态

## 7.1 bake dev / HMR 全栈开发服务器

**状态**：⚠️ 受限严重

**当前表现**：`bun --hot` / bake dev server（HMR、增量重建、dev 静态服务）
在真机测试中大面积失败（13 个相关测试文件）。它是 HTTP + WebSocket + fs.watch
+ 子进程的组合体，叠加了 3.1/3.3/4.2 多个受限面的影响。

**影响**：**端侧"边改边看"的开发体验不可用**；生产构建（`bake build`）不受影响。

**规避方案**（架构性，当前最稳路径）：

1. **开发在 x86**：代码在 Linux/macOS/Windows 上用标准 Bun 开发调试；
2. **端侧跑产物**：构建产物（JS/静态资源）部署到设备，用本版本 Bun 运行；
3. 端侧改代码 → 手动重启进程（写个重启脚本），不依赖 HMR。

## 7.2 Next.js / Vite / Astro / expo 等构建工具链

**状态**：⚠️ 资源预算 + 生态双重约束

**当前表现**：完整构建链（`next build`、`vite build`、expo 全家桶）在手机
SoC 上超出时长/内存预算（测试 180s/360s 双超时）；部分工具依赖的原生二进制
见 2.4。

**影响**：端侧完整构建不现实。

**规避方案**（标准工作流）：

```bash
# 1) x86 开发机构建（可用任意工具链）：
next build / vite build / bun build ./src/index.ts --outdir ./dist

# 2) 产物同步到设备（hdc file send / 应用资源打包）

# 3) 设备端只运行：
bun run ./dist/server.js
```

- 原则：**端侧只做运行时，不做构建时**。
- 端侧轻量改动验证可用 `bun build`（纯 JS 打包在本平台测试面表现良好），
  但 framework 级 dev server 不要在端上起。

## 7.3 第三方客户端库（数据库/消息队列等）

**状态**：✅ 客户端协议面可用（连接目标需自备）

**说明**：真机测试中 postgres/mongodb/valkey/stripe 等第三方库的用例失败，
**全部源于测试需要 Docker 服务端**（设备上无法起容器），而非客户端协议实现
问题。应用代码连接**真实部署**的服务端（局域网/云端）不受此影响；`bun:sqlite`
（内嵌，无需服务端）在本平台测试中全量通过。

**建议**：做端到端联调时，把服务端部署到局域网主机，连接串指向它。

---

# 八、已验证可正常使用的能力

以下面经真机全量测试验证**正常**，可放心使用（与上文的受限面互补）：

- **运行时主体**：JS/TS 执行、转译（TS/JSX）、模块解析、react-compiler 类
  大规模转译（2467 用例通过）
- **打包器 Bun.build 主体**：JS/CSS/HTML 打包、minify、code splitting、
  compile 单文件可执行（compile 面与 sourcemap 正常）
- **bun run / 内置 shell 主体**：scripts 执行、输出捕获、`--parallel`、
  bun shell 语法（本版本修复输出链路后全量转绿，见 1.1–1.4）
- **bun test 基础功能**：断言、mock、snapshot、分片与并行
- **bun:sqlite**：全量通过（248+176 用例）
- **HTTP 客户端（fetch）主体**、gzip/zstd 压缩解压
- **Bun.serve 基础请求-响应**（见 3.1 的受限边界）与**目录路由静态托管**
  （见 3.2，本版本修复）
- **包管理主体**：registry 安装、lockfile、workspaces、catalogs、audit、
  git 依赖、本地 tarball/目录安装
- **npm os/cpu 门控**：openharmony 变体安装与排除语义（本版本修复，见 2.3）
- **crypto/hash**（CryptoHasher、Bun.password 等）
- **Bun.write 常规读写**（除 4.1 切片场景）、Bun.file 读取
- **FFI（bun:ffi）**：基础 FFI 可用（dlopen 加载 .so、函数调用、指针/内存
  管理全量通过）；受限面：libc 定位的特化路径（FIFO/mkfifo 场景报
  "unsupported platform openharmony"，待修复）与内置 C 编译器（cc）
- **Bun.Terminal raw mode**（见 5.1）
- **`process.platform === "openharmony"`** 正确返回（平台检测可靠）

---

# 九、平台行为差异速览（不构成故障，但与 Linux 不同）

这些差异在测试中表现为边缘断言失败，使用者应知悉并在代码中留出余量：

| 差异点 | 表现 | 使用建议 |
|---|---|---|
| hmdfs 文件 birthtime | `stat().birthtime` 可能为 0 | 不要依赖 birthtime 做逻辑 |
| memfd + readFileSync 交互 | 预期 ENOMEM 的场景报 EACCES | 错误处理按 errno 分支时两种都接 |
| waiter 线程 CPU 统计 | `resourceUsage().cpuTime` 比阈值预期高 ~83% | 不要用 cpuTime 做严格断言 |
| PTY 信号 | 控制字符不生成信号（见 5.2） | 应用降级 |
| tmpdir 落点 | 默认可能解析到 hmdfs（AF_UNIX 不可用） | socket 文件显式指路径（见 3.4） |
| DNS 失败模式 | NXDOMAIN 变 2s 超时（见 3.5） | 加超时包装 |
| hmdfs stat uid | 与 getuid() 映射不一致 | 不要依赖 uid 做权限判断 |

---

# 十、限制总览速查表

| # | 功能 | 状态 | 一句话症状 | 快速规避 |
|---|---|---|---|---|
| 1 | bun run 输出 | ✅ | ~~scripts 输出不可见~~ 本版本已修复 | （可选）`[run] shell = "system"` |
| 2 | bun run 参数 | ✅ | ~~位置参数丢失~~ 本版本已修复 | 环境变量传参（稳妥实践） |
| 3 | bun shell 脚本+.env | ✅ | ~~exit 65507~~ 本版本已修复 | — |
| 4 | `--parallel`/`--filter` | ✅ | ~~聚合输出为空~~ 本版本已修复 | — |
| 5 | spawn bun 自身读输出 | ✅ | ~~stdout 空~~ 本版本已修复 | 文件中转 / inherit（稳妥实践） |
| 6 | spawnSync stdin=Buffer | ✅ | ~~子进程读空~~ 本版本已修复 | — |
| 7 | stdin 写入 | ⚠️ | 向已退出进程写入报 EPIPE | try/catch + exited 探测 |
| 8 | Bun.$ | ✅ | ~~伪失败 exit 29~~ 本版本已修复 | — |
| 9 | bun exec | ✅ | ~~Illegal seek~~ 同源已修复 | 首次使用建议冒烟 |
| 10 | test shard×parallel | ✅ | ~~结果聚合为空~~ 本版本已修复 | CI 层并行仍推荐 |
| 11 | git 依赖 | ✅ | ~~signal 9 / 超时~~ 本版本已修复 | tarball 化（离线/弱网稳妥实践） |
| 12 | os 字段门控 | ✅ | ~~openharmony 键不识别~~ 本版本已修复 | 匹配变严格：linux 变体用 `--os=linux --libc=musl` |
| 13 | 原生模块 prebuilds | ⚠️ | 无 openharmony 产物 | musl 变体 + `--os=linux --libc=musl` / x86 处理 |
| 14 | bunx 缓存 | ⚠️ | 所有权误拒 | 缓存目录指 /data/local/tmp |
| 15 | serve keep-alive | ⚠️ | 连接复用下个别响应滞留 | Connection: close / 幂等重试 |
| 16 | 目录路由静态托管 | ✅ | ~~404 / 空 body~~ 本版本已修复 | — |
| 17 | WS 长连接 | ✅ | 主体用例全量通过 | unix 形式见 #18；心跳仍为标配 |
| 18 | Unix socket | ⚠️ | hmdfs 上 EPERM | 显式 /data/local/tmp |
| 19 | DNS 失败 | ⚠️ | 2s 超时代替快速失败 | 超时包装 / resolve4 |
| 20 | file.slice+write | ⚠️ | 切片被无视写全量（PARKED 短期不修） | JS 侧切片 |
| 21 | fs.watch | ⚠️ | 事件缺失 | 轮询 / usePolling |
| 22 | 长路径 | ⚠️ | 深层嵌套触限 | 浅目录部署 |
| 23 | 作业控制信号 | 🚧 | Ctrl-Z/SIGWINCH 无效 | 应用降级 |
| 24 | --inspect | ✅ | ~~unix path 乱码 URL~~ 本版本已修复 | 多进程仍建议显式唯一端口 |
| 25 | bake dev / HMR | ⚠️ | 大面积不可用 | x86 开发+端侧产物 |
| 26 | 端侧框架构建 | ⚠️ | 超时 | x86 构建+产物部署 |
| 27 | HTTP/3 | ⚠️ | 未验证可靠 | 用 HTTP/1.1 |
| 28 | 硬链接 | 🚧 | `fs.link`/安装物化 EPERM | `--backend=copyfile`；代码回退 copyFile |
| 29 | 特权端口 <1024 | 🚧 | bind EACCES | 高位端口；网关侧做 80/443 映射 |
| 30 | 根目录 `/` 访问 | 🚧 | open 全模式 EACCES；WASI preopen `/` 死路 | 沙箱根替代；wasm 兜底绕开 |
| 31 | exec 未签名脚本 | 🚧 | execve 文本脚本 EACCES | `sh ./x.sh`（读）而非 `exec`；脚本带 shebang |
| 32 | libc dlopen 特化路径 | ⚠️ | FIFO/mkfifo 场景 libc 定位失败 | 常规文件/网络操作不受影响；待修复 |

---

# 十一、最佳实践清单

面向真机部署的推荐姿势（综合上文所有规避项）：

1. **平台检测先行**：`const IS_OHOS = process.platform === "openharmony"`，
   所有降级逻辑用它分支。
2. **bunfig 基线**：
   ```toml
   [run]
   shell = "system"          # scripts 走系统 shell（见 1.1）
   [install.cache]
   dir = "/data/local/tmp/bun-cache"   # 缓存落 AF_UNIX 可用、I/O 更好的卷
   ```
3. **进程模型**：spawn 输出走文件中转或 inherit；所有外部进程包 `timeout`；
   不向已退出进程写 stdin。
4. **参数传递**：跨脚本一律环境变量，不用位置参数。
5. **依赖**：git 依赖 tarball 化；原生依赖优先 musl 变体；必要时 patch 剥 os
   字段。
6. **网络服务**：短连接（`Connection: close`）+ 幂等重试；WS 心跳；响应体
   落内存；静态资源 catch-all handler + 冒烟。
7. **本地 IPC**：socket 文件显式放 `/data/local/tmp`。
8. **文件**：切片用 JS 侧完成；watch 用轮询。
9. **工作流**：x86 构建、端侧运行；端侧不开 dev server、不做完整框架构建。
10. **沙盒边界内编程**（见第六节）：不用硬链接（安装 `--backend=copyfile`）、
    不绑 <1024 端口、不 open `/`（用沙箱根）、运行时只生产数据不生产可执行
    映像；WASM 兜底路径默认视为不可用。
11. **超时预算**：端侧任何长任务（安装/构建/测试）外部包 timeout，
    默认按 x86 时长 ×5 预估。

---

# 十二、报告问题

反馈问题时请附：

1. 构建标识（`bun --version` 输出）与设备型号 / OpenHarmony 版本；
2. 最小复现脚本（能用 `bun -e '...'` 单行表达最好）；
3. 完整错误输出（`BUN_DEBUG_QUIET_LOGS=1` 关闭调试日志后重跑可减少噪音；
   需要详细日志时 `BUN_DEBUG_<SCOPE>=1` 按 scoped logger 开启）；
4. 期望行为与实际行为。

> 本文档随构建更新。各受限项的修复进度以新版本发布说明为准。
