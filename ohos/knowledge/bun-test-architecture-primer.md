# Bun 测试架构入门 — 为什么"有些测试不是静态的"

> 数据源：`test/AGENTS.md`、根 `AGENTS.md`、`.claude/skills/writing-bundler-tests/SKILL.md`、
> `test/bundler/expectBundled.ts`（`itBundled` 实现）、`test/bundler/bundler_edgecase.test.ts`、
> `test/README.md`。结论先行：**这个仓库追求的是"确定性（deterministic）"，不是"静态（static）"** ——
> 凡是可以确定的（输出、行为、退出码），动态构造也必须每次一致；凡是天然变化的
> （端口、临时路径、平台分隔符、被测二进制本身），写死反而是 bug 来源。

---

## 目录

1. [先定义：什么是静态测试、什么是非静态测试](#1-先定义)
2. [全景图：测试围绕"新编译的 bun 二进制"分三层](#2-全景图)
3. [第一层 — bun 既是被测对象也是测试运行器](#3-第一层)
4. [第二层 — bundler 测试：fixture → 打包 →（部分）执行 → 断言行为](#4-第二层)
5. [第三层 — API 测试：不打包任何东西](#5-第三层)
6. [为什么必须动态：五个真实原因](#6-为什么)
7. [仓库的纪律：禁止哪些"动态"，鼓励哪些"静态"](#7-纪律)
8. [实操手册：怎么跑、怎么写、放哪里](#8-实操)
9. [FAQ：常见误解逐条修正](#9-faq)

---

<a name="1-先定义"></a>
## 1. 先定义：什么是静态测试、什么是非静态测试

**静态测试**：输入写死、期望值写死、纯内存计算、结果完全可预测，运行多少次都一样，和机器无关。

```ts
test("adds", () => expect(1 + 1).toBe(2));
```

**非静态（动态）测试**：测试的输入、期望值、甚至测试用例本身是在**运行时**构造、
生成或依赖外部环境的。本仓库里典型的动态手段：

| 动态手段 | 一句话概括 | 典型位置 |
|---|---|---|
| fixture + 子进程执行 | 把 js/ts 源码当输入，产物当程序跑 | `test/bundler/*` |
| 期望值运行时计算 | `join("a","b")` 而非 `"a/b"` | 同上 |
| 快照测试 | 期望值首次运行时记录，之后对比 | `toMatchSnapshot()` |
| 绑定 debug 构建 | 被测对象是刚编译出的二进制 | `bun bd test` 全套 |
| 数据驱动 / 参数化 | 用例是数据对象，由 harness 解释执行 | `itBundled()`、`describe.each()` |

关键认知：**"动态"和"不确定（flaky）"是两回事**。这个仓库大量使用前者、严厉禁止后者（见 §7）。

---

<a name="2-全景图"></a>
## 2. 全景图：测试围绕"新编译的 bun 二进制"分三层

初次接触很容易把"测试用例只是一些 js/ts 源码，要重新编译生成产物运行"当成全部 ——
那只是第二层。完整图景：

```
                    bun bd（编译 bun 自己，一次性）
                            │
                            ▼
                 ./build/debug/bun-debug  ←——————— 第一层：被测对象
                            │                    同时也是测试运行器
          ┌─────────────────┴─────────────────┐
          ▼                                   ▼
   第二层：bundler 测试                  第三层：API 测试
   （test/bundler/）                     （test/js/ 等）
          │                                   │
   fixture js/ts 源码                   普通 TS 测试文件
          │                            （进程内直接调 API）
   ① 写入临时目录                              │
   ② 用新 bun 打包 → 产物 out.js        一部分再 spawn 子进程
   ③ 有 run: 的用例拉起子进程            跑多文件 fixture（不是打包）
   ④ 断言 stdout/stderr/退出码          直接断言返回值/行为
```

一句话总结：**新编译的 bun 二进制是核心**。bundler 测试走"源码 → 产物 → 行为"链路；
更大量的 API 测试不打包任何东西，只是用这个新二进制直接跑代码、调 API、看行为。

---

<a name="3-第一层"></a>
## 3. 第一层 — bun 既是被测对象也是测试运行器

```sh
bun bd        # 编译出 ./build/debug/bun-debug
bun bd test test/bundler/bundler_banner.test.ts   # 用这个 debug 构建跑测试
```

两个身份：

1. **被测对象**：你改的 Rust/C++ 代码编译进了这个二进制，测试证明的就是它的行为。
2. **测试运行器**：`bun bd test` 本身就是用这个二进制在跑测试文件 —— 测试框架
   （`bun test` 的 describe/test/expect）也是被测代码的一部分。

由此推出一条仓库铁律（根 `AGENTS.md`）：

> **永远不要直接 `bun test`** —— 那用的是系统里已装的旧 bun，你的改动根本没参与运行。
> 必须 `bun bd test`。

验证一个测试**有效**的标准做法（test/AGENTS.md）：

```sh
USE_SYSTEM_BUN=1 bun test <file>   # 旧版跑 → 必须失败
bun bd test <file>                 # 新构建跑 → 必须通过
```

一个"静态通过"的测试在这里直接视为无效：它没有证明任何行为差异。

---

<a name="4-第二层"></a>
## 4. 第二层 — bundler 测试：fixture → 打包 →（部分）执行 → 断言行为

### 4.1 测试用例是"数据"，不是"代码"

bundler 测试统一走 `itBundled()`（`test/bundler/expectBundled.ts:1882`），
用例是**声明式对象**，由共享 harness 解释执行：

```ts
itBundled("edgecase/ImportStarFunction", {
  files: {                                  // fixture 源码（运行时写入临时目录）
    "/entry.js": `import * as foo from "./foo.js"; console.log(foo.fn());`,
    "/foo.js": `export function fn() { return "foo"; }`,
  },
  run: { stdout: "foo" },                   // 期望：打包产物执行后输出 foo
});
```

harness 的执行流程（`expectBundled.ts`）：

```
files → 写入临时目录 root → 调用打包器 → 产物
   │                                          │
   │ 有 run: 配置？                            │ 无 run: 的用例到此为止
   ▼                                          ▼
spawn 子进程执行产物                     只验证打包阶段：
   │                                     bundleErrors / bundleWarnings
   ▼                                     capture()（转译结果）
对比 stdout / stderr（trim 后             dce（死代码标记计数）
  精确匹配或正则匹配，1828-1858 行）       onAfterBundle（自定义断言）
   │
   ▼
rmSync(root) 清理临时目录（1874 行）
```

### 4.2 并非所有用例都会"生成产物并运行"

按验证目标分四种，`run:` 只是其中一种：

| 验证目标 | 配置 | 执行产物？ | 例子（bundler_edgecase.test.ts） |
|---|---|---|---|
| 运行时行为 | `run: { stdout: "..." }` | ✅ spawn 执行 | `edgecase/EmptyCommonJSModule`（:18） |
| 只测打包报错 | `bundleErrors: {...}` | ❌ | `edgecase/InvalidLoader` |
| 只测转译结果 | `capture: [...]` | ❌ | `edgecase/TemplateStringIssue622`（:103）：`` `${1+1}` `` 是否折叠成 `"2"` |
| 死代码消除 | `dce: true, dceKeepMarkerCount: N` | ❌ | 源码里放 `// KEEP` / `// REMOVE` 标记数存活数量 |

### 4.3 "测试即数据"换来什么

为什么不让每个用例自己写完整测试代码？`expectBundled.ts:1895-1918` 给出答案 ——
所有横切关注点集中在一处实现，几千个用例免费继承：

- **过滤**：`BUN_BUNDLER_TEST_FILTER="banner/Comment" bun bd test ...` 只跑单个用例（:1895）
- **调度**：backend=api 的用例用了 `process.chdir`，自动降级为 `it.serial` 防串扰（:1908-1911）
- **超时**：sourcemap/compile 类用例自动 30s，普通 5s，可 `timeoutScale` 缩放（:1912-1917）
- **todo**：`todo: true` 自动注册为 `it.todo`（:1905）
- **环境噪音清理**：debug 构建的日志行统一过滤后再对比（:1835，那行
  `// no idea why this logs. ¯\_(ツ)_/¯` 的注释很有代表性）
- **平台适配**：跨平台差异在 harness 一处消化

如果每个用例是独立静态测试，以上任何一处修复都要复制几千次。

---

<a name="5-第三层"></a>
## 5. 第三层 — API 测试：不打包任何东西

`test/js/` 下的多数测试（fetch、Bun.serve、fs、crypto……）**没有"源码 → 产物"的过程**。
它们是普通 TS 测试文件，由新二进制直接执行，**进程内**调用 API 断言行为：

```ts
test("Bun.serve responds", async () => {
  const server = Bun.serve({ port: 0, fetch: () => new Response("hi") });
  expect(await (await fetch(`http://localhost:${server.port}`)).text()).toBe("hi");
});
```

其中一部分需要多文件时，用 `tempDir` 写 fixture、`Bun.spawn` 拉子进程执行 ——
**注意这不是打包**，只是把 js/ts 源文件直接喂给新 bun 跑：

```ts
using dir = tempDir("my-test-prefix", {
  "index.js": `import { foo } from "./foo.ts"; foo();`,
  "foo.ts": `export function foo() { console.log("foo"); }`,
});
await using proc = Bun.spawn({
  cmd: [bunExe(), "index.js"],   // bunExe() = 当前 debug 构建的路径
  env: bunEnv,
  cwd: String(dir),
});
const [stdout, stderr, exitCode] = await Promise.all([
  proc.stdout.text(), proc.stderr.text(), proc.exited,
]);
```

约定：多文件 fixture 所在文件以 `*-fixture.ts` 结尾，以区分"测试文件"和"被测 fixture"。

---

<a name="6-为什么"></a>
## 6. 为什么必须动态：五个真实原因

### 原因 1：正确性契约是"行为"，不是"字节"

打包器的产物格式（空白、变量命名、模块包装方式）会随版本不断变化。
如果静态断言产物文本，每次重构输出格式都要改几百个测试。
断言"产物能不能正确运行"（stdout/退出码）才是稳定的契约。

### 原因 2：期望值天然依赖环境，写死必挂

真实例子（`bundler_edgecase.test.ts:45`）：

```ts
run: { stdout: join("a", "b") },   // 不是写死 "a/b"
```

POSIX 上是 `a/b`，Windows 上是 `a\b` —— 用 `node:path` 的 `join` 运行时算出，
同一个测试在所有平台都能过。同类动态值：

| 动态值 | 为什么不能写死 |
|---|---|
| `bunExe()` | 被测二进制的路径，写死就测不到你的改动 |
| `bunEnv` | 需要静默 debug 日志等环境注入 |
| `port: 0` | OS 分配随机端口；写死端口在 CI 并行时互相冲突 |
| `tempDir()` | 每次运行新临时目录；固定路径会残留脏状态 |
| `join("a","b")` | 平台分隔符不同 |

### 原因 3：巨型输出手写维护不现实 → 快照 + 归一化

打包产物、sourcemap、错误堆栈动辄几百行。`toMatchSnapshot()` 让期望值首次运行时
自动记录，之后对比；产物变化时人工审一眼 diff，确认是预期改进就 `-u` 更新。

配套的 `normalizeBunSnapshot` 说明更深层的问题：原始输出含随机路径、随机端口等
**每次运行都不同的内容**，harness 先把 nondeterministic 部分归一化再对比。
本质是"**用动态归一化换取静态断言的可行性**"。

### 原因 4：被测对象本身是运行时构造的

测试跑的是刚编译出来的 debug 构建（§3）。这意味着：
- 测试结果取决于当前代码库的编译产物，不是某个固定版本；
- "测试有效"的定义本身就要求它在新旧二进制上行为不同（`USE_SYSTEM_BUN=1` 失败 + `bun bd` 通过）。
  一个对新旧二进制结果完全相同的静态断言，在这里等于什么都没测。

### 原因 5：生成代码无法手写静态断言

`src/` 里大量 `.rs`/`.cpp` 是构建时从 `.classes.ts` 等源生成的（codegen）。
对应行为的期望值跟着生成器走，手写静态断言会和生成器漂移。
参数化测试（`describe.each()`）同理：一份逻辑 × N 组数据，静态写法意味着 N 份复制。

---

<a name="7-纪律"></a>
## 7. 仓库的纪律：禁止哪些"动态"，鼓励哪些"静态"

动态性里的**坏成分是不确定性（flaky）**，repo 对此明令禁止（test/AGENTS.md + 根 AGENTS.md）：

| 禁止 | 原因 | 替代做法 |
|---|---|---|
| `setTimeout` / `await sleep(N)` 等条件 | 测的是"时间流逝"不是"条件满足"，CI 慢机器必 flaky | 轮询 + deadline，或 `await` 事件本身 |
| 硬编码端口 | 并行 CI 冲突 | `port: 0` |
| `tmpdirSync` / `fs.mkdtempSync` | 绕过统一清理 | `tempDir("prefix", {...})` from `"harness"` |
| 联公网（registry.npmjs.org、github.com） | CI 环境不可控、非确定性 | `VerdaccioRegistry` 装包；本地 `Bun.serve({port:0})` 当 HTTP 桩 |
| `expect(stdout).toBe(...)` 写在 `expect(exitCode).toBe(0)` 之后 | 失败信息不友好 | 先断言输出、最后断言退出码 |
| 测试里检查"没有 panic"之类输出 | 永远不会失败，等于没测 | 断言具体预期输出 |
| 泄漏测试用统一绝对阈值 | ASAN 隔离区 + GC 抖动会误报 | 按 `isASAN`/`isDebug` 分支设阈值 |

反面理解：**确定性 ≠ 静态**。`port: 0` 是动态的，但每次都能拿到可用端口 —— 它是
确定的（必然成功）；`setTimeout(3000)` 是"静态写了数字"，却是不确定的（机器慢就挂）。

---

<a name="8-实操"></a>
## 8. 实操手册：怎么跑、怎么写、放哪里

### 8.1 跑测试

```sh
bun bd test test/js/bun/http/serve.test.ts        # 单文件
bun bd test http/serve.test.ts                    # 模糊匹配文件名
bun bd test serve.test.ts -t "should handle"      # 按用例名过滤
BUN_BUNDLER_TEST_FILTER="banner/Comment" bun bd test bundler_banner.test.ts   # bundler 单用例
BUN_BUNDLER_TEST_DEBUG=1 bun bd test bundler_minify.test.ts                   # bundler 调试
```

注意：`bun bd` 编译最多约 2.5 分钟；`bun bd <cmd>` 支持把尾参透传给新二进制。

### 8.2 目录约定（新测试放哪）

| 测试对象 | 目录 | 例子 |
|---|---|---|
| Bun 专属 API | `test/js/bun/` | `http/serve.test.ts` |
| Node 兼容层 | `test/js/node/` | `node:fs` 相关 |
| Web API | `test/js/web/` | `fetch/fetch.test.ts` |
| CLI 命令 | `test/cli/` | install/run/test |
| 打包器/转译器 | `test/bundler/` | 用 `itBundled` helper |
| 端到端集成 | `test/integration/` | |
| N-API | `test/napi/` | |
| 回归（仅限真回归） | `test/regression/issue/<真实issue号>.test.ts` | 必须是"曾经对、后来坏"；issue 号必须真实 |

**默认规则：加到你改动代码对应的既有测试文件里，不要新建文件。**
（fetch 的 bug → `test/js/web/fetch/fetch.test.ts`，Bun.serve 的 bug → `serve.test.ts`。）

### 8.3 写测试的骨架

单文件测试优先用 `-e`；多文件用 `tempDir` + `Bun.spawn`：

```ts
import { test, expect } from "bun:test";
import { bunEnv, bunExe, tempDir, normalizeBunSnapshot } from "harness";

test("multi-file test", async () => {
  using dir = tempDir("test-prefix", {
    "index.js": `import { foo } from "./foo.ts"; foo();`,
    "foo.ts": `export function foo() { console.log("foo"); }`,
  });
  await using proc = Bun.spawn({
    cmd: [bunExe(), "index.js"],
    env: bunEnv,
    cwd: String(dir),
    stderr: "pipe",
  });
  const [stdout, stderr, exitCode] = await Promise.all([
    proc.stdout.text(), proc.stderr.text(), proc.exited,
  ]);
  expect(normalizeBunSnapshot(stdout, dir)).toMatchInlineSnapshot(`"foo"`);
  expect(exitCode).toBe(0);   // 退出码放最后断言
});
```

可并发、各自拉子进程的测试用 `test.concurrent`。速度预算：单测 ~1s、单文件 ~10s
（debug/ASAN 构建比 release 慢 10-100 倍）。

---

<a name="9-faq"></a>
## 9. FAQ：常见误解逐条修正

**Q1："测试用例只是一些 js/ts 源码，要用 bun 重新编译生成产物运行，对吧？"**

对一半 —— 那是第二层（bundler 测试）的流程，且有两个修正：
1. 不是所有用例都执行产物：只测打包报错（`bundleErrors`）、只测转译（`capture`）、
   只测 DCE 的用例根本不跑产物（§4.2）。
2. 这里的"编译"是**打包 fixture**，不是重新编译 bun 本身。bun 二进制在
   `bun bd` 阶段已经编好，测试时只是调用它的 `Bun.build` 能力。

完整表述：**新编译的 bun 二进制是核心；bundler 测试的输入确实是 js/ts 源码 fixture，
走"打包 →（部分）执行产物 → 断言行为"链路；但套件里更大量的 API 测试不打包任何东西，
只是用这个新二进制直接跑代码、调 API、看行为。**

**Q2："动态测试 = flaky 测试？"**

不是。本仓库的立场恰相反：动态构造 + 严格去不确定化（§7）= 在任何机器上每次结果
都一致。真正 flaky 的源头是不受控的等待时间、固定端口、外部网络。

**Q3："为什么不全部写成静态断言，一眼能看懂期望值？"**

三笔账：
1. **契约账**：产物字节是实现细节，行为才是契约（§6 原因 1）；
2. **环境账**：平台/端口/路径天然可变，写死必挂（§6 原因 2）；
3. **规模账**：几千个用例共享一份 harness，一处修复全体受益（§4.3）。

**Q4："快照测试的期望值是自动生成的，那不就是自己验证自己？"**

第一次运行是"记录"，之后每次都是"对比记录值"。它验证的是**变化**：
产物意外变化时测试立刻红，人工审 diff 决定接受（`-u` 更新）还是修复。
配套归一化（`normalizeBunSnapshot`）先抹掉随机路径/端口，只留有意义的变化。

**Q5："怎么判断一个测试是不是有效的？"**

两条硬标准（§3）：
1. `USE_SYSTEM_BUN=1 bun test <file>` 必须失败（证明它测的是新行为）；
2. `bun bd test <file>` 必须通过（证明新行为正确）。
两条都过的测试才是有效测试。
