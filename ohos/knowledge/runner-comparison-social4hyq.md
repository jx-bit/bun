# Runner 逐块对比 — social4hyq vs 我们（scripts/runner.node.mjs）

> **数据源**：social4hyq/ohos-bun `ohos-aarch64` tip 的 `scripts/runner.node.mjs`
> 副本 × 本仓库 `scripts/runner.node.mjs` @ PR #25（`93691f0a7b`）。
> **关联**：CI workflow 层对比见 [ci-comparison-social4hyq.md](ci-comparison-social4hyq.md)；
> PR #26 工作记录见 [../issues/pr26-p2-runner-env-device-lane.md](../issues/pr26-p2-runner-env-device-lane.md)。

---

## 0. 先读这个：整个对比在讲一件事

### 0.1 runner 是什么

`scripts/runner.node.mjs` 是**跑测试的总调度脚本**（用系统 node 跑，不是被测的
bun）。它做的事：找出几千个测试文件 → 一个个（或一批批）调用被测的 bun 去执行
→ 给每个进程准备环境变量、设超时 → 收集结果写 results.json。
**所有"给测试准备环境"的决定都在这个脚本里。**

### 0.2 为什么 OHOS 需要特殊处理

同一个脚本既跑在开发机/常规 CI（x64 Linux/macOS/Windows）上，也跑在 OHOS
设备/容器上。OHOS（OpenHarmony）有四个和常规 Linux 不一样的现实：

| 现实 | 打破的假设 | 对应对比点 |
|---|---|---|
| 装了**多个版本的 clang**，按名字找会命中老的 | "PATH 里第一个 clang 就是对的"（§1） | napi 全挂 |
| C 头文件不在默认位置，认 `$OHOS_SYSROOT` 变量 | "编译器自己能找到标准库头文件"（§2） | ffi/cc 挂 |
| **源码树内不许放 socket/硬链接**，且 socket 路径上限 108 字节 | "临时目录放哪都行"（§3） | ~34 个 node 测试 EPERM |
| fork/spawn、文件系统调用**慢 2-3 倍** | "Linux 的耗时估算适用"（§4、§5） | 超时冤杀 / 分片失衡 |

runner 层的修复 = 在脚本里把这四个假设补回来。**下面每一节都按同一个模板讲：
这是什么 → 没有它会出什么事 → 怎么修 → 影响多大 → 我们和他们的差异。**

### 0.3 总览表

| # | 对比点 | 一句话影响 | 状态 |
|---|---|---|---|
| 1 | llvm@21 排 PATH 最前 | napi 测试现场编译时别选错编译器 | ✅ 双方一致 |
| 2 | OHOS_SYSROOT 自动补 | ffi 运行时编译找得到 C 头文件 | ✅ 逐字一致 |
| 3 | NODE_TEST_DIR 短路径 | node 测试的临时文件放到允许 socket 的地方 | ✅ 本 PR |
| 4 | 外层超时 ×3 | 慢机器上重测试不被外层闹钟冤杀 | ✅ 本 PR |
| 5 | 装箱用 ohos 耗时列 | 分片均衡（跑得快慢的活分匀），不是测试对错 | ❌ 我们缺 |
| 6 | TERM=dumb 换掉 | 防交互式终端测试因"傻瓜终端"挂 | ⚠️ 层级缺口，暂缓 |
| 7 | styletext 专项 pin | 单个颜色测试的小灶 | 不需要（我们已过） |
| 8 | 每 case 超时不缩放 | 防并发批次总预算爆炸 | ✅ 双方一致 |
| 9 | 环境变量单点组装 | 改一处全生效（架构，非差异） | ✅ 等价 |

---

## 1. llvm@21 排 PATH 最前 —— 编译器选对版本

**这是什么**：`test/napi/` 系列测试不是纯 JS —— 它们现场把一小段 C++ 代码
编译成动态库再加载（这叫 native addon，工具叫 node-gyp）。node-gyp 找编译器
的方式很朴素：**在 PATH 里按名字搜 `clang`/`clang++`**，`CC`/`CXX` 变量都不看。

**没有它会出什么事**：OHOS 机器上有两个 clang ——
- ohos-sdk 自带的 **clang 15.0.4**（老，缺 C++20 的 `<source_location>` 头）；
- harmonybrew 装的 **llvm@21**（新，有）。

名字都叫 clang，按 PATH 搜索时老的先被命中。于是编译报：

```
v8-source-location.h:9:10: fatal error: 'source_location' file not found
```

31+ 个 napi 测试全红，且报错看起来像"代码/环境坏了"，实际是**编译器选错**。

**怎么修**：把 llvm@21 自己的 bin 目录塞到 PATH 最前面，按名字搜先命中新的：

```js
// 双方同款（他们 L1882 / 我们 L1760，逐字一致，#23 已移植）
if (process.platform === "openharmony") {
  const brew = spawnSync("brew", ["--prefix", "llvm@21"], ...);
  paths.push(join(brew.stdout.trim(), "bin"));   // 排最前
}
```

**影响**：他们实测 napi 从 0% → **60/60 全过**。

---

## 2. OHOS_SYSROOT 自动补 —— 运行时编译找得到头文件

**这是什么**：`bun:ffi` 内嵌了一个微型 C 编译器（TCC），支持运行时编译小段
C 代码。编译要读 C 标准库头文件（`<stdint.h>` 这种）。在 OHOS 上这些头文件
不在编译器默认位置，**只在 `$OHOS_SYSROOT` 指向的目录里**找——bun 的源码
（ffi_body.rs）就认这个变量。

**没有它会出什么事**：变量没设 → 编译时报
`include file 'bits/alltypes.h' not found` → ffi/cc 类测试红。

**怎么修**：runner 发现变量没设时自动推导补上（CI 层面已设则不动）：

```js
// 双方逐字一致（他们 L1943 / 我们 L1821，#23 已移植）
if (process.platform === "openharmony" && !process.env.OHOS_SYSROOT) {
  const brew = spawnSync("brew", ["--prefix", "ohos-sdk"], ...);
  ohosSysroot = join(brew.stdout.trim(), "native", "sysroot");
}
```

**影响**：ffi/cc 类测试恢复（如 napi-value-ffi 的 sysroot 报错类）。

---

## 3. NODE_TEST_DIR —— 临时文件放到允许 socket 的地方（PR #25）

**这是什么**：从 Node.js 官方仓库搬来的几千个测试（`test/js/node/test/**`）
共用一个临时目录工具 `common/tmpdir.js`，测试里建临时文件、socket、硬链接
都放这里。它第一个读的环境变量就是 `NODE_TEST_DIR`；不设就用默认位置 =
**源码树里的 `test/js/node/`**。

**没有它会出什么事**：OHOS 上"源码树内"这个位置踩两个坑：

1. **不许放 socket 文件/硬链接**（沙箱/文件系统限制）→ `bind()` 报 `EPERM`；
2. **AF_UNIX socket 的地址最长 108 字节**（内核硬限制，`sun_path` 字段）。
   node 测试还会用"相对测试目录的路径"推导 socket 地址 —— 源码树里的深层
   长路径直接超限。

于是 fs/net/watch 系列 ~34 个测试红，报错是 EPERM/地址超长，看起来像
"bun 的 socket 实现坏了"，实际是**临时目录位置不对**。

**怎么修**：OHOS 上把临时根指到 `/tmp` 下一个**刻意取短名**的目录
（`nt-xxxxxx`；短是为了给 socket 相对路径留余量）：

```js
// 双方 3 行代码逐字一致（他们 L1981 / 我们 L1853，PR #25）
...(process.platform === "openharmony"
  ? { NODE_TEST_DIR: mkdtempSync(join(tmpdir(), "nt-")) }
  : {}),
```

**影响**：EPERM 类 ~22 个失败文件收敛（fs.test、node-net、fs.watch 等）。

**我们和他们的差异**：代码逐字一致；只有注释措辞微调（无语义差别）。

---

## 4. 外层超时 ×3 —— 慢机器上重测试不被冤杀（PR #25）

**这是什么**：runner 给每个测试文件设了**两层闹钟**：

- **内层**：`bun test --timeout=…`，管每个 test case；测试文件可以用
  `setDefaultTimeout()` 自己调大 —— 这是测试"知道自己重"的正常方式；
- **外层**：runner 自己的 wall-clock kill —— "这个文件最多跑 N 秒，到点
  整个进程杀掉"。**外层不知道、也不管内层被调到多大。**

**没有它会出什么事**：OHOS 上 fork/spawn（创建进程）和文件系统调用比
Linux **慢 2-3 倍**。install/migration 类重测试（一次 spawn 几百个子进程），
内部超时已经自觉调到 5 分钟，但外层闹钟还是按 Linux 速度定的 → **外层先响，
整个文件被杀**。现象：16 个 TIMEOUT，且文件自己的超时调整全部无效。

**怎么修**：OHOS 上外层闹钟 ×3（和 ASAN 的 ×2 叠乘）：

```js
// 双方表达式逐字一致（他们 L2219 / 我们 L2088，PR #25）
timeout: isReallyTest
  ? Math.ceil(timeout * (isAsan ? 2 : 1) * (process.platform === "openharmony" ? 3 : 1))
  : 30_000,
```

**影响**：超时类 5-11 文件（multi-run、no-orphans、run-crash-handler、
watch/shell-leak 系）不再被外层冤杀。

**注意不是全部超时都放大**：每个 test case 的内层 `--timeout`（他们 L2157/L1032、
我们 L2017/L977）双方都**不**缩放（§7）—— 否则慢机器上并发批次整体变慢，
总预算爆掉。

---

## 5. 装箱用 ohos 耗时列 —— 分片均衡（❌ 我们缺，后续项）

**这是什么**：几千个文件分给 4 个 shard 并行跑，怎么分才均衡？按**每个文件
历史上实际跑了多久**做装箱（最长优先、往最空的箱里放，即 LPT 算法）。历史
数据存在 `expected-durations.json`，里面按机器类型分列（x64/asan/musl/
windows…），加载函数按当前机器选列。

**没有它会出什么事**：OHOS 的耗时分布和 x64 **完全不成比例**。最极端例子
（他们注释原话）：run-crash-handler 在 x64 列 **2268ms**，OHOS 实测 **519s**
—— 差 200 多倍。按 x64 列装箱：纸面上四箱均衡，实际 OHOS 上某个 shard
被几个 519s 级的文件拖死，其他 shard 早跑完**空等几十分钟**。

**量化影响**（他们 workflow 注释）：按 default 列装箱最重 shard **30.1 min**，
按 ohos 列 **16.0 min** —— 接近 2 倍总时长差。

**他们的做法**（L2748，我们没有）：

```js
// OHOS 不跑 Buildkite 没有 step 名，所以按平台选列，并有独立数据列
const columns =
  process.platform === "openharmony"
    ? ["ohos"]          // ← 我们缺这个分支和数据列
    : step.includes("asan") ? ["asan"] : ...
```

**为什么本 PR 不做**：修复分两半 —— (a) 选列逻辑（几行），(b) **我们自己的
ohos 耗时数据**（现在没有）。先跑一轮带时长采集的设备轮回填数据，再补 (a)。
没有 (b) 就补 (a) 等于拿 x64 数据继续瞎分。

**注意**：这影响的是"跑多快"，不是"测试对不对"——缺了它不会有测试红，
只是总时长翻倍、机器空转。

---

## 6. TERM=dumb 换掉 —— 防交互式终端测试挂（⚠️ 层级缺口，暂缓）

**这是什么**：`TERM` 环境变量告诉程序"你连的终端是什么型号"。readline
（交互式行编辑库，REPL/命令行补全用它）按它决定启用哪些按键处理；
`TERM=dumb` 意思是"傻瓜终端，什么键都别指望" → readline 退化为不处理
方向键 → 测试里"按上箭头光标上移"这类断言全挂。

**没有它会出什么事**：如果用 TERM=dumb 的 shell（agent、某些容器）启动
runner，dumb 一路传进测试进程 → readline/REPL 系光标断言批量红。

**双方现状（层级不同）**：

| 层 | 覆盖谁 | 他们 | 我们 |
|---|---|---|---|
| runner 层（他们 L1955） | **`bun test` 进程本身** | ✅ dumb→xterm-256color | ❌ 原值透传 |
| harness 层（我们 harness.ts:86） | 测试自己 spawn 的**子进程** | 未查 | ✅ dumb→xterm |

**我们的缺口**：bun test 进程本身如果继承了 dumb，进程内的 readline 断言
暴露。**暂缓理由**（三条，按分量排序）：

1. 我们 200 个失败里**没有一例实锤是这个原因**（repl/terminal 在他们台账的
   归因是 flake 与并发假象）；
2. 他们改法**不分平台**，照搬会同时改掉非 OHOS 通道（Buildkite 继承 lane）
   的 TERM 语义 —— 超出 ohos 修复范畴；
3. 真出现时按 openharmony 门控补 1 行即可，先欠着。

**styletext 专项（他们 L946）**：单独一个测试（test-util-styletext）断言
颜色输出，需要像样的终端 + 清掉强制无色变量，他们给它开小灶。
**我们不需要**：这个测试在我们 20260903 轮**已通过**（不在 200 失败清单）。

---

## 7. 每 case 超时不缩放 —— 双方一致（是共识，不是缺口）

容易误读成"他们没做所以我们也漏了"。实际是**双方都故意不做**：内层每 case
超时若在 OHOS 上放大，并发批次里每个 case 都变长，shard 总预算（workflow
的 timeout-minutes）爆掉。策略是**只放大外层兜底闹钟（§4），内层保持诚实**——
内层超时该红的还是红，说明测试本身在这台机器上真的跑不动，值得人工看。

---

## 8. 环境变量单点组装 —— 架构等价（为什么 PR #25 只改一处）

runner 里所有"启动一个 bun 进程"的调用点（napi 预编译、并行桶、build、
测试执行、非 test exec —— 我们 L779/918/999/1196/2075/2277 共 6 处）都走
**同一个函数 `spawnBun()`**，bunEnv 在函数体内一次性组装。这就是"漏斗"：
**PR #25 在漏斗口注入 NODE_TEST_DIR，串行和并行两条测试路径同时生效**，
不需要第二处改动。双方架构在此等价。

---

## 9. 门控点对账（原始行号版）

他们 runner 内 `openharmony` 共 5 处；我们 4 处，一一对应、无自创门控：

| 他们 | 我们 | 内容 | 状态 |
|---|---|---|---|
| L1883 | L1761 | getCombinedPath llvm@21 | ✅ #23 移植 |
| L1943 | L1821 | OHOS_SYSROOT fallback | ✅ #23 移植，逐字 |
| L1981 | L1853 | NODE_TEST_DIR | ✅ PR #25，逐字 |
| L2219 | L2088 | 外层 wall-clock ×3 | ✅ PR #25，逐字 |
| L2748 | — | durations ohos 装箱列 | ❌ §5 后续项 |

验证：`node --check` 通过；系统 bun 冒烟（empty-file，`ok=true`）漏斗无回归；
非 OHOS 平台所有改动按门控惰性，零行为变化。

---

*对比执行：Sisyphus，2026-09-08，PR #25 review 期间。基准为对方 tip 副本快照，对方后续提交不自动反映。*
