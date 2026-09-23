# jx-bit 修复任务拆解（基于 007d7a07e 轮 29 个独有失败）

> 面向 jx-bit 维护方。本目录是官方 v1.4.0 树（oven-sh/bun `bun-v1.4.0` tag，2001 文件）
> 第五次全量验证轮。对照基线：social4hyq 1.4.0_80（同树 1816/2001，用例率 99.08%）。
> 本轮：1808/2001（98.23%），jx-bit 独有失败 **29 文件**，拆解为 4 个修复任务。

## 任务 1（P0）——子进程输出捕获丢失【修复后回补 ~250 用例】

### ⚠️ 2026-09-14 分层探针实验（根因收窄 + 修正修复方向）

**实验环境**：
- 设备：OHOS aarch64 本机（无 strace/ltrace 可用，故采用 JS 分层探针法）
- 被测 A：jx-bit `1.4.0-canary.1+007d7a07e`（sha256 `b529f7b3…`，ohos-selfsign 签名）
- 被测 B：social4hyq `1.4.0+61dbc3a9d`（harmonybrew `bun-sys-release`，Cellar 1.4.0_80）
- 工作目录：`/storage/Users/currentUser/opencode/probe/`（探针脚本已留存：p1.js ~ p6.js）

---

#### 探针 1（p1.js）：单子进程 `Bun.spawn` pipe 读

```js
// p1.js
const p = Bun.spawn(["sh","-c","echo AAA"], { stdout:"pipe", stderr:"pipe", stdin:"ignore" });
const t = await new Response(p.stdout).text();
console.log("spawn-pipe:", JSON.stringify(t), "exit:", await p.exited);
```

| binary | 输出 |
|---|---|
| sys-release | `spawn-pipe: "AAA\n" exit: 0` |
| jx-bit 007d7a07e | `spawn-pipe: "AAA\n" exit: 0` ← **相同，正常** |

#### 探针 2（p2.js）：并发 2 子进程 pipe 读（multi-run 场景模拟）

```js
// p2.js
const [a, b] = [ ["sh","-c","echo AAA"], ["sh","-c","echo BBB"] ]
  .map(c => Bun.spawn(c, { stdout:"pipe", stdin:"ignore" }));
const [ta, tb] = await Promise.all([new Response(a.stdout).text(), new Response(b.stdout).text()]);
console.log("parallel-pipe:", JSON.stringify(ta), JSON.stringify(tb));
```

| binary | 输出 |
|---|---|
| sys-release | `parallel-pipe: "AAA\n" "BBB\n"` |
| jx-bit 007d7a07e | `parallel-pipe: "AAA\n" "BBB\n"` ← **相同，正常** |

#### 探针 3（p3.js）：`Bun.$` 非 quiet（stdout 直通 inherit）——**首次命中**

```js
// p3.js
const r = await Bun.$`echo AAA`.nothrow();
console.log("shell:", JSON.stringify(r.stdout.toString()), "exit:", r.exitCode);
```

| binary | 输出 |
|---|---|
| sys-release | `AAA`（直通打印到终端）+ `shell: "AAA\n" exit: 0` |
| jx-bit 007d7a07e | **无任何终端输出** + `shell: "" exit: 65507` ← **失败命中** |

#### 探针 4（p4.js）：quiet 捕获 vs 外部命令 vs sh -c（反转实验）

```js
// p4.js
const b = await Bun.$`echo BUILTIN-AAA`.nothrow().quiet();
console.log("builtin-echo:", JSON.stringify(b.stdout.toString()), "stderr:", JSON.stringify(b.stderr.toString().slice(0,120)), "code:", b.exitCode);
const e = await Bun.$`/bin/echo EXT-AAA`.nothrow().quiet();
console.log("ext-echo:", JSON.stringify(e.stdout.toString()), "code:", e.exitCode);
const s = await Bun.$`sh -c "echo SH-AAA"`.nothrow().quiet();
console.log("sh-c:", JSON.stringify(s.stdout.toString()), "code:", s.exitCode);
```

| binary | builtin-echo | ext-echo | sh-c |
|---|---|---|---|
| sys-release | `"BUILTIN-AAA\n"` code 0 | `"EXT-AAA\n"` code 0 | `"SH-AAA\n"` code 0 |
| jx-bit 007d7a07e | `"BUILTIN-AAA\n"` code 0 ← **正常** | `"EXT-AAA\n"` code 0 | `"SH-AAA\n"` code 0 |

（`.quiet()` 捕获模式下 jx-bit 三种形态全部正常——反转：问题只存在于非 quiet 路径）

#### 探针 6（p6.js）：非 quiet 失败的稳定性复验（3 次）+ 对照

```js
// p6.js
const r = await Bun.$`echo AAA`.nothrow();
console.log("code:", r.exitCode, "stdout:", JSON.stringify(r.stdout.toString()),
            "stderr:", JSON.stringify(r.stderr.toString().slice(0,200)));
```

jx-bit 007d7a07e 连续 3 次（100% 稳定复现）：
```
code: 65507 stdout: "" stderr: ""
code: 65507 stdout: "" stderr: ""
code: 65507 stdout: "" stderr: ""
```
sys-release：
```
AAA                                    ← 直通打印到终端
code: 0 stdout: "AAA\n" stderr: ""
```

（探针 5 空缺：原计划 strace 对照，设备无 strace/ltrace，被 p6 最小复现取代）

---

#### 实验矩阵总结

| 层 | sys-release 1.4.0_80 | jx-bit 007d7a07e |
|---|---|---|
| `Bun.spawn` stdout:"pipe"，单子进程 | ✅ "AAA\n" | ✅ "AAA\n" |
| `Bun.spawn` pipe，**并发 2 进程** | ✅ | ✅ |
| `Bun.$` + `.quiet()`（pipe 捕获），builtin/外部/sh -c | ✅ ×3 | ✅ ×3 |
| **`Bun.$` 非 quiet（stdout 直通 inherit）** | ✅ AAA 直通 | ❌ **exit 65507，stdout/stderr 全空** |
| multi-run 输出转发（`bun run --parallel`） | ✅ | ❌ 空 |
| `bun run a` 单脚本（shell 直通） | ✅ | ✅（与 Bun.$ 直通挂形成可调试差异） |

#### 对原假设的推翻

1. **ProcessHandle/pipe-watcher 层排除**：`Bun.spawn` pipe 读（单/并发）在 jx-bit 上完全正常；且 social4hyq 1.4.0_80（`61dbc3a9d`，无 ProcessHandle 重构的旧 `to_process` API）multi-run 同样通过。
2. **wave2（PR #34 memfd/waiter/close_range/PWD）降级**：`Bun.$` 非 quiet 失败在 wave2 之前的构建上已成立（c4323a5d3 时期 multi-run 即挂），除非 p6 复现也在 wave2 前 commit 成立（它成立——c4323a5d3 同样挂）。
3. **根因收窄**：`src/shell/` 解释器的 **stdout 直通（non-quiet / inherit 装配）路径**在 jx-bit 构建上失败，且产生异常退出码 **65507（0xFFE3）**——从该错误码生成处反查是最短调试路径。

#### 修复方向（修正版）

- 定位 `src/shell/` 中 non-quiet 模式的 stdout 装配与退出码逻辑（`65507`/`0xFFE3` 锚点）
- 调试入口：`p6.js`（6 行）——任何构建上 30 秒内可判定修复与否
- 修复后预期：multi-run/filter-workspace/shell 簇 ~250 用例回补，用例率追平 99%

**原分析保留（供对照，已被实验推翻的部分见上）**：

**现象（设备可复现）**：
```bash
mkdir -p /tmp/mrt && cd /tmp/mrt   # 若 /tmp 不可读，换任意可写目录
printf '{ "scripts": { "a": "echo AAA", "b": "echo BBB" } }' > package.json
bun run a                   # ✅ 正常输出 "$ echo AAA" + "AAA"
bun run --parallel a b      # ❌ 只有 "a | Done in 51ms"，AAA/BBB 丢失
bun run --sequential a b    # ❌ 同样丢失
bun -e 'await Bun.$`echo AAA`'   # ❌ shell 输出为空
```
14 秒后 harness 超时是测试等待带前缀输出；"Done in" 由 exit 回调打印（不依赖 pipe）。

**影响文件（11）**：
`cli/run/multi-run.test.ts`(90用例) `filter-workspace`(72) `cli/test/test-shard`(2)
`cli/install/bun-run-bunfig`(10) `bun-run`(10) `js/bun/shell/exec`(13) `env.positionals`(4)
`shell-seq-condexpr`(3) `commands/which`(1) `22650-shell-crash`(1) `run-shell`(1) 等。

**根因（源码级）**：`src/runtime/cli/multi_run.rs` 两树逻辑一致（仅 114 行
ProcessHandle 内存管理差异），但 jx-bit 用旧 `spawned.to_process()`（裸指针 +
intrusive refcount）——pipe reader 挂在 mini event loop 上不生效，数据进 pipe 无人读。
同 `Bun.$` shell 的子命令输出（独立实现、同一模式失效）。

**修复步骤**：从 social4hyq `ohos-aarch64`（HEAD `36854e8e`）搬运：
```bash
cp $REF/src/spawn/process.rs              $JX/src/spawn/process.rs     # ProcessHandle 重构（核心）
cp $REF/src/runtime/cli/multi_run.rs      $JX/src/runtime/cli/multi_run.rs
cp $REF/src/event_loop/SpawnSyncEventLoop.rs $JX/src/event_loop/SpawnSyncEventLoop.rs
# 核对（逐文件 diff 选择性 port，含 OHOS pipe/epoll 适配）：
diff -u $JX/src/sys/sys_uv.rs $REF/src/sys/sys_uv.rs
```
冲突点预期：`ProcessHandle` 是 API 破坏性重构，需同步改动 `to_process` 的全部调用方
（`grep -rn "to_process(" src/`）。

**验收**：
1. 冒烟：`bun run --parallel a b` 输出 `a | AAA` / `b | BBB`；`Bun.$` 输出 AAA
2. 本轮 11 个文件复跑全 PASS（复跑脚本见 §5）
3. 全量用例 fail 数从 1220 降到 <1000，用例率 ≥99%

## 任务 2（P1）——install 簇输出/行为差异（9 文件，逐例归因）

| 文件 | 错误模式（复跑实测） |
|---|---|
| `architecture-match` | 期望/实际 npm 平台三元组不匹配 |
| `bun-audit` | audit 输出结构差异 |
| `bun-dedupe` | "no-op prints one summary line"——摘要行数/格式 |
| `bun-pm-licenses` | 许可证列表输出内容 |
| `bun-run-bunfig` / `bun-run` | bunfig 加载后 run 行为（各 10 用例） |
| `bun-workspaces` / `config-precedence` / `frozen-lockfile-pruned` / `nested-overrides` | workspace/配置优先级行为 |

共性：`expect(...).toContain/toEqual` 输出内容差异（1.4.0-canary 与 1.4.2 的 install
行为演进）。**逐例处理**：对每个文件 diff 两树 `src/install/`（重点 `PackageManager.rs`、
`lifecycle_script_runner.rs`），或直接 merge 上游 bun-v1.4.0 tag 的 install 实现。

## 任务 3（P2）——fixture server 不退出 + 忙循环（F4，不影响用例但摧毁长跑）

现象：install 测试启动的 verdaccio 在测试进程组被杀后**永久存活且 153% CPU 忙旋转**
（实测 3 个孤儿累计 CPU 28/32/3 小时；social4hyq 构建同场景下子进程数秒内自行退出——
对照实验 2026-09-10）。
**与任务 1 同源**（spawn/事件循环 shutdown 路径）。验收：跑完
`bun-install-registry.test.ts` 后 `pgrep -f verdaccio` 为空。

## 任务 4（P3）——残余散布（9 文件，逐例）

`cli/run/env`(4) `run-quote`(1) `shell-keepalive`(1) `workspaces`(2) `cli/inspect/bun-inspector-protocol`
`js/bun/http/serve-directory-routes`(24用例，**merge 上游 1.4.0 的 serve 目录路由**)
`js/bun/io/bun-write` `js/web/workers/structured-clone`×2 `regression/26207/26286`
`integration/expo-app`。多为单用例级，逐例看 report
（`all-official-report-*.txt` 对应 FILE= 段）。

## 已修复确认（无需再动）

- ✅ `process.platform`/`os.platform()` = `openharmony`（C++ `BunProcess.cpp::constructPlatform`
  的 `#elif defined(__OHOS__)` 分支——009d… 轮已修，保持勿回退）
- ✅ F3 `bun run node` PATH bin（`which/lib.rs`——`FAKE-NODE` 冒烟通过）

## 验证流程

1. 构建后冒烟（任务 1/3 各一条命令，见上）
2. 失败集复跑：`fail_007d7a07e.txt`（29 文件）用复跑脚本逐文件验证
3. 全量确认：同口径（`TMOUT=180 RETRIES=1`，2001 文件）出报告，与
   `fail_official-v140-sys-release.txt`（185）对比，jxbit_only 应 ≤10
