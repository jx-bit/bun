# P2: 容器测试通道搭建 — 触发器 / 并行 / 容错 / brew 漂移 / openharmony — 详解

> **关联 PR**：[#21](https://github.com/jx-bit/bun/pull/21)（单 commit `5b4e3a862f`，5 文件 +89/-13）
> **状态**：🔄 OPEN（checks 验证中）
> **取代**：[#19](https://github.com/jx-bit/bun/pull/19)（构建修复，内容已并入本 PR）
> **撤回**：[#18](https://github.com/jx-bit/bun/pull/18)（fulltest 通道缓行，文件已移出本 PR）
> 机制背景见 [`../knowledge/codesign-and-spawn-primer.md`](../knowledge/codesign-and-spawn-primer.md)，
> 参考通道对比见 [`../knowledge/ci-comparison-social4hyq.md`](../knowledge/ci-comparison-social4hyq.md) 与
> [`ci-comparison-springmin.md`](../knowledge/ci-comparison-springmin.md)。

---

## 0. 修复总览与依赖链

本 PR 的 7 项修复不是并列关系 —— 是把容器测试通道从"每次跑法都不一样、
跑完必丢结果"修成"PR 自动触发、4 小时内全量、结果必然可回收"的一条依赖链：

```
① PR 触发器 ──▶ ② --parallel（跑得完）──▶ ③ vendor 容错（结果不丢）
                                  ④⑤⑥⑦ 环境三修（node 装上 / napi 工具链 / 平台识别）
```

| # | 修复 | 文件 | 解决的症状 |
|---|---|---|---|
| ① | pull_request 触发器 + concurrency 按 PR 号 | ohos-container-test.yml | PR 更新通道文件不触发；新通道的 dispatch 鸡生蛋 |
| ② | `--parallel` | ohos-container-test.yml | 串行 8.1s/文件 × 5969 = 12.3h > 4h 上限 |
| ③ | vendor 构建失败容错 | scripts/runner.node.mjs | vendor build throw 杀死 runner，5841/5969 文件结果全丢 |
| ④ | zlib + lld@21 显式安装 + 校验清单 + PATH | ohos-build-github.yml, build-ohos-container.sh | cargo 丢 libz 符号 / ld.lld 探测只剩 15.0.4 |
| ⑤ | 外科手术式 brew update | ohos-container-test.yml | baked 索引引用 CDN-pruned node bottle → 404 → 回退 SELF |
| ⑥ | llvm@21 bottle（napi 工具链） | ohos-container-test.yml | node-gyp 需要 C++20 libc++ 头，31 napi 文件失败 |
| ⑦ | openharmony 平台支持 | scripts/utils.mjs（4 处） | harmonybrew node 上报 platform="openharmony"，runner 秒死 |

依赖说明：②③④⑤⑥ 都依赖 ①（没有 PR 触发，修复本身无法被 PR 验证）；
⑦ 依赖 ⑤（node 装上后才暴露 openharmony 平台问题）；④ 依赖 brew update
保留在构建通道（漂移经 update 进入，显式安装 + 校验把暴露点前移）。

---

## 1. 修复①：pull_request 触发器 + concurrency

### 1.1 原触发器的两个洞

```yaml
on:
  push:
    branches: [ohos-aarch64]          # 只认 ohos-aarch64 分支的推送
    paths: ['.github/workflows/ohos-container-test.yml']
  workflow_dispatch:                   # 手动触发
```

- **push 分支过滤不含 dev**：我们的流程是 dev 上提交 → PR 到 ohos-aarch64。
  push 到 dev 不满足 `branches: [ohos-aarch64]` → 不触发。
- **workflow_dispatch 的鸡生蛋**（15-ci-artifact-dispatch 记录过的坑）：dispatch 要求 workflow
  文件**存在于仓库默认分支**（ohos-aarch64）。新加的工作流文件在合入默认分支
  之前无法 dispatch —— 而它恰恰需要先跑一次来验证自己。

### 1.2 修复

```yaml
  pull_request:
    branches: [ohos-aarch64]           # PR 目标分支
    paths: ['.github/workflows/ohos-container-test.yml']   # 且改了本文件
```

机制要点：

- **pull_request 事件使用 merge ref**（`refs/pull/<N>/merge`）上的工作流文件 ——
  PR 里新增/修改的工作流文件在该 PR 上**立即生效**，鸡生蛋解开。
- `paths` 对比 base↔head 的变更文件：只有 PR 改了本工作流文件才触发。
- 生产验证：PR #21 自身的三条容器通道 + build 在 PR 上自动触发 ✓。

### 1.3 语义边界

| PR 类型 | 是否触发 | 原因 |
|---|---|---|
| 修改工作流文件本身 | ✅ | paths 命中 —— 测试的就是流水线改动 |
| 普通代码 PR | ❌ | paths 不命中；且回退 binary 会让结果失真 |
| push 到 ohos-aarch64 改工作流文件 | ✅ | push 触发保留 |

---

## 2. 修复②：`--parallel`（串行 12h → 并行 37 分钟）

### 2.1 runner 的并行开关

`scripts/runner.node.mjs:629`：

```js
const parallelism = options["parallel"] ? availableParallelism() : 1;
```

flag 定义（`:193`）：

```js
["parallel"]: { type: "boolean", default: false }   // 所有平台默认串行！
```

上游的 BuildKite 管线（`.buildkite/ci.mjs`）是**显式传参**开启并行的；
我们的 GitHub workflow 派生时漏传了这个参数 → 串行。

### 2.2 串行有多慢（实测）

| 项 | 值 |
|---|---|
| 实测速率（run 34074150484，已取消） | **8.1s/文件**（494 文件 / 66 分钟）|
| 发现文件数 | 5969 |
| 串行总时长 | **~12.3 小时** |
| job 超时上限 | 4 小时（`timeout-minutes: 240`）|

### 2.3 修复与实测

```diff
   '"$RUNNER"' scripts/runner.node.mjs \
     --exec-path=/workspace/bun/bun-ohos \
     --quiet \
+    --parallel \
     --retries=1 \
```

`--parallel` 后 `availableParallelism()` = ARM runner 核数（4）。runner 内部
的并行结构（三层，各有安全边界）：

1. **modified serial**：本次改动过的测试 → `limit(parallelism)` 并行
2. **rest serial + parallel bucket**：`test/parallel-allowlist.json` 声明的目录
   进"桶"—— 一个 `bun test --parallel --reporter=junit` 子进程批量跑
3. **parallel-safe tests**：命名符合并行安全的 → parallelSafeLimit 并行

### 2.4 实测结果

验证 run 34090874324：**5967 文件 / ~37 分钟**（约 0.37s/文件有效吞吐，10× 提速）。

**注意**（继承参考通道方法论）：并行会引入并发假阳/假阴 —— 可疑失败按
"低并发复测 → 隔离单跑"复核，不要直接当回归（`multi-run.test.ts`、`32492`
在参考通道也是并发敏感文件）。

---

## 3. 修复③：vendor 构建失败容错（结果不再全丢）

### 3.1 崩溃链条

vendor 阶段在 runner 的阶段序列**末尾**（test/ 树全部跑完之后）：

```
runTests():
  ① modified serial → ② rest serial → ③ parallel bucket → ④ parallel-safe
  ⑤ vendor 套件（vendor/elysia 等，按 manifest：install → build → 逐文件跑）
  ⑥ 写 results.json（writeFileSync）
  ⑦ 汇总 + 退出码
```

vendor 阶段的代码（`runner.node.mjs:1189-1200`）：

```js
const buildResult = await spawnBun(execPath, {
  cwd: vendorPath,
  args: ["run", "build"],
  timeout: 60_000,
});
if (!buildResult.ok) {
  throw new Error(`Failed to build vendor: ${buildResult.error}`);   // ← 病灶
}
```

`runTests` 没有外层 try/catch —— 这个 throw 直接**杀死整个 runner 进程**，
⑥ 的 results.json 写盘永远不会执行。

### 3.2 事故链条（两次 run 同一死法）

```
2026-09-05 run：5841/5969 文件跑完（37 分钟）→ vendor/elysia build 退出 1
  → throw → 进程死 → results.json 未写 → docker cp 空
  → "No files were found with the provided path: results.json" → 2h17m 全丢
2026-09-07 run：5841/5969 又跑完 → 同一位置同一死法 → 同样全丢
```

vendor/elysia 的 `bun run build` 在容器内打印 "Build success" 却退出 1
（环境相关，根因未查 —— 修复不依赖它）。

### 3.3 修复：记录失败并继续

```js
if (!buildResult.ok) {
  // vendor build 失败 → 该套件的每个测试文件记为失败条目
  for (const testPath of testPaths) {
    const title = join(relative(cwd, vendorPath), testPath).replace(/\\/g, "/");
    failedResultsTitles.push(title);
    failedResults.push({
      testPath: title, ok: false, status: "fail",
      tests: [], errors: [], stdout: "",
      stdoutPreview: `vendor build failed: ${buildResult.error}`,
    });
  }
  continue;   // 继续下一个 vendor，不再 throw
}
```

设计要点：

- 条目结构与 results.json 的其他失败条目**同构**（消费方
  `formatTestToMarkdown` / results-json 均兼容）；
- vendor 失败在报告里**可见**（而不是静默吞掉）—— 20260907 轮的 ~170 个
  vendor/elysia 失败条目即由此产生；
- install 失败原本就是 `continue`（`:1186`），本次把 build 对齐到同样的容错语义。

---

## 4. 修复④：brew bottle 漂移（zlib + lld@21 消失）

### 4.1 事故现象（09-07 两次构建）

```
第一次：cargo（OHOS-host rust nightly）报
  "Error relocating cargo: deflate/inflate: symbol not found" → exit 127
第二次（装上 zlib 后）：cargo 通过 ✅ → 死于
  "Could not find ld.lld (version >=21.1.0 <23.0.0)"
  Found but rejected: 仅 15.0.4 候选（ohos-sdk shim + Ubuntu 系统）
```

### 4.2 根因：tap 重构 llvm@21 + 公式索引是活水

构建通道每次 run 都执行 `brew update --quiet` 刷新公式索引（不刷新会踩
CDN-pruned bottle 404 —— 工作流注释记录的权衡）→ **依赖树跟随 tap 的 HEAD 漂移**。

tap（social4hyq/homebrew-core）在 **09-07 重构 llvm@21**（"sync content from
Harmonybrew upstream"，revision 7→8）：

1. **lld 拆分**：lld 从 llvm@21 移入独立的 `lld@21` 配方
   → 新浇注的 llvm@21 keg 不再含 `ld.lld` 21.1.8
2. **zlib 掉出 bun 公式的依赖浇注集**
   → cargo（链接 libz）的 deflate/inflate 符号无法重定位

浇注集实测漂移：09-05 = libedit+libffi → 09-07 = bzip2+libxml2-2.15.4。

**掩盖关系**：症状 2（ld.lld）被症状 1（cargo zlib）掩盖 —— cargo 在 ld.lld
探测之前就死了；zlib 装好后症状 2 才暴露。这也是为什么"修一个冒一个"。

**排除法**：镜像 digest 两次完全相同（`sha256:38e740c8...`）—— 排除镜像漂移；
我们的 PR 改动无一在构建路径上 —— 排除代码问题；唯一同时日命中 = tap 的
llvm@21 重构提交。

### 4.3 修复（显式安装 + 安装时校验 + PATH）

```yaml
# 依赖浇注后：
docker exec "$CONTAINER" bash -lc \
  "$BREW_ENV brew install $TAP/zlib 2>/dev/null || $BREW_ENV brew install zlib" ...
docker exec "$CONTAINER" bash -lc "$BREW_ENV brew install $TAP/lld@21" ...
```

安装后校验清单加入 `zlib`、`lld@21` —— 缺失在安装步骤**大声报错**
（`::error::... NOT installed`），不再以构建深处的神秘 127 出现。

`build-ohos-container.sh` 的 PATH 前置 lld@21 的 bin（ld.lld 探测
>=21.1.0 在 ohos-sdk 的 15.0.4 之前命中 21.1.8）。

### 4.4 为什么不 pin brew 环境

pin（不刷新索引）会踩 CDN-pruned bottle 的 404（工作流注释记录的另一个坑）。
选择的路线是**把漂移暴露点前移**：显式安装关键公式 + 安装时校验清单 ——
漂移发生时在安装步骤大声、明确地失败，而不是构建深处的神秘退出码。

---

## 5. 修复⑤⑥⑦：外科手术式 brew update / llvm@21 bottle / openharmony 支持

### 5.1 外科手术式 brew update（测试通道）

镜像的 baked 索引可能引用已被 CDN 淘汰的 node bottle（实锤：baked 26.4.0
vs live 26.5.0 → 404 → runner 回退到被测 binary）。修复：node 安装前先
`brew update`（刷新默认 tap 索引）再 `brew install node` —— 与参考通道的
做法逐字一致（其注释记录了同一实锤案例）。

### 5.2 llvm@21 bottle（napi 工具链）

node-gyp 测试（test/napi/*）需要 C++20 工具链：node-26 头文件包含
`<source_location>`，容器的旧 g++/头文件编不过 → 31 个 napi 文件失败
（run 34079587941）。修复：显式安装 llvm@21 bottle（keg 自带该头文件，
arm64_ohos bottle 秒级浇注）—— 参考通道同款方案。

### 5.3 openharmony 平台支持（scripts/utils.mjs，4 处）

harmonybrew 的 node 上报 `process.platform = "openharmony"`，而
`parseOs` 不认识 → runner 在启动时秒死（"Unsupported operating system"，
run 34179941938）。从参考通道移植 4 个平台 handler：

| 函数 | 修复 | 解决的症状 |
|---|---|---|
| `parseOs` | `/linux\|openharmony\|android/` → linux | runner 启动秒死（本次崩溃点）|
| `getTmpDir` | TMPDIR/TEMP/TMP 用户覆盖优先（OHOS /tmp 只读） | AF_UNIX/硬链接 EPERM 类 |
| `getUsername` | uv_os_get_passwd ENOENT 兜底（OHOS app-sandbox uid 无 /etc/passwd 条目） | runner 启动崩溃类 |
| `getDistro` | openharmony → "openharmony" | 环境报告/分发判断 |
| `getHomedir` | utils 的 `homedir`（node:os 兜底）别名导入 | runner 启动（导入名对不上 → 模块加载即失败）|

（参考通道的对应实现在其 utils.mjs:1433/1350/1624/1671，本次逐 hunk 对齐。

**补充（2026-09-08，PR #21 合并后的跟进修复 `a62cc31a68`）**：上表前 4 项落地
后，runner 的导入名 `getHomedir` 与 utils 的导出名 `homedir` 不匹配 →
模块加载即失败（run 34202615606 秒死）→ 导入别名修正（1 行）。这是
"对齐后暴露的下一个断点"模式的延续：每修一个，下一个才可见。）

---

## 5.4 与参考通道（social4hyq）的对齐映射

本 PR 的 ⑤⑥ + 变量化路由即与参考 OHOS CI 通道的**对齐项**（其设计与实现
详见 [`../knowledge/ci-comparison-social4hyq.md`](../knowledge/ci-comparison-social4hyq.md) §4 实施状态表）：

| 对齐项 | 参考通道做法 | 本 PR 落点 | 状态 |
|---|---|---|---|
| 镜像 digest pin | SWR mirror @digest（anon-pullable） | `vars.OHOS_CI_IMAGE`（digest 38e740c8...） | ✅ |
| node bottle 404 | 先 `brew update`（默认 tap）再 install | 同款外科手术式 update | ✅ |
| napi 工具链 | llvm@21 bottle（C++20 头） | 同款安装 | ✅ |
| vendor 套件失败 | ——（其环境 build 成功，未暴露） | 记录失败 + continue（我们环境必失败，容错是必需） | ✅ 超越 |
| `--parallel` | 机器级分片，片内串行（明确拒绝进程并行） | 保留 `--parallel`（我们串行实测 8.1s/文件 vs 他们 0.53s——15× 差异待查） | ⚠️ 有依据的偏差 |
| 环境来源 | harmonybrew 预装（手动固化） | repo 变量 + 显式安装 | ✅ 等价（变量化 + 校验前移）|

## 6. 验证

| run | 内容 | 结果 |
|---|---|---|
| 33955739117 | 6021 发现，串行 999 后 bucket 崩溃 | 定位 vendor throw + 串行问题 |
| 34074150484 | 串行 8.1s/文件实测 | 12.3h 必超时 → 取消 |
| 34079587941 | --parallel 生效：5841/5969 / 35 分钟 | vendor throw 再现 → 定位修复三 |
| 34090874324 | vendor 容错生效：**5967 文件 / 95.31% / results.json 226KB** | PR #14/#15/#17 修复路径容器实证 ✅ |
| 34179941938 | 对齐后首次运行：RUNNER=node 确认（node 装上）| 暴露 openharmony parseOs 崩溃 → 修复⑦ |

**PR #14/#15/#17 修复路径的容器实证**（run 34090874324）：

| PR | 验证点 | 结果 |
|---|---|---|
| #15 dlopen musl loader | process.test.js 172 用例 165 过（上轮 dlopen/signal 类失败消失）；intl 32/33；serve-file 103/109 | ✅ |
| #17 shebang 展开 | 脚本 spawn 全链路工作，shell 27/29、spawn-path 3/4，无改写回归 | ✅ |
| #14 compile/codesign | compile 家族容器内生成并执行（13/16） | ✅（容器可测部分）|

残余失败全部为环境类（node-gyp 工具链、node PATH、stdin/TTY、locale、
docker 服务）—— 与已知分类吻合，无新增回归。
完整报告：[`../analys/archive/container-verify-pr14-15-17-20260907.md`](../analys/archive/container-verify-pr14-15-17-20260907.md)。

---

## 7. 调试时间线（四次 run 的排障历程，供复用）

| run | 现象 | 定位 | 修复 |
|---|---|---|---|
| 33840115661 | 只跑了 146 文件（旧 binary `2c34d21ce` 的 fs 遍历缺陷）| 计数器分母 `[N/148]` | 升级 binary 后 6021 正常，关闭疑点 |
| 33955739117 | 6021 发现但无 results.json | 日志尾：vendor build throw | 本次修复三 |
| 34074150484 | 8.1s/文件串行，12.3h 必超时 | 实测速率计算 | 本次修复二（--parallel）|
| 34090874324 | ✅ 完整产出 | — | — |

方法论要点：**GitHub log API 对 in-progress job 有截断**（gh --log 只给部分），
完整日志用 `curl -L .../actions/jobs/<job_id>/logs` 直取（9MB 级）；速率用
日志时间戳差 ÷ 完成文件数实测，不要估。

---

## 8. 涉及文件与提交

| 文件 | 改动 |
|---|---|
| `.github/workflows/ohos-container-test.yml` | +pull_request 触发器、concurrency 按 PR 号、`--parallel`、外科手术式 brew update、llvm@21 bottle |
| `.github/workflows/ohos-container-fulltest.yml` | （已移出本 PR——fulltest 通道缓行，文件保留在 dev 历史）|
| `.github/scripts/build-ohos-container.sh` | lld@21 bin 前置 PATH |
| `.github/workflows/ohos-build-github.yml` | zlib + lld@21 显式安装 + 校验清单 + 镜像 digest pin |
| `scripts/runner.node.mjs` | vendor 容错（记录失败 + continue）|
| `scripts/utils.mjs` | openharmony 平台支持 ×4 |

---

*文档：Sisyphus | 2026-09-07 | 依据 run 33840115661/33955739117/34074150484/34079587941/34090874324/34179941938 六次 run 的日志取证*


---

## 9. 合并后的后续修复（dev 上，PR #22/#24 之外的部分）

PR #21 合并后，dev 上继续落了三批修复——本节记录它们的机制与对齐结论。

### 9.1 nobody/nogroup 组缺失（容器 setup 补组）

**现象**：vendored Node 测试（test-process-euid-egid / test-process-uid-gid）
`setgid("nobody")`/`setegid("nogroup")` → `ERR_UNKNOWN_CREDENTIAL`（2 文件）。

**根因**：测试按**名字**切换组身份 → 第一步在 `/etc/group` 里查名字 →
OHOS 用户态的 `/etc/group` 不发行 Linux 的 `nobody`/`nogroup` 约定
（gid 65534，Debian/Ubuntu 的叫法）→ 两个名字都查不到 → 测试的
nobody→nogroup 兜底也无济于事（**缺的是数据库条目，不是代码逻辑**）。

**修复**：容器 setup 幂等补组（`grep -q || echo >> /etc/group`）。

### 9.2 与 social4hyq 的凭据类处理对比

他们的文档（OHOS_TEST_STATUS.md）记录了**同一测试文件（process.test.js）
的凭据用例**的完整解决链——深度远超我们：

| 层 | 他们的做法 | 我们的做法 |
|---|---|---|
| ** symptom** | `process.test.js` initgroups 用例：`getpwuid_r` 兜底对任意 uid 合成当前账户记录，掩盖 ENOENT，预解析通过后走到 initgroups(3) 吃 EPERM | `setgid("nobody"/"nogroup")` 名字查询失败 |
| **修复层 1（shim）** | **ohos-compat-shim**：LD_PRELOAD shim 拦截 `getpwuid_r`——兜底仅限 `uid == getuid()/geteuid()`，其余 uid 透传 ENOENT（ohos-compat-shim `098a75a`） | 无（我们的失败在 GROUP 数据库，不在 USER 查询）|
| **修复层 2（验证链）** | smoke / functional 38/38 / real-vs-fallback 全绿 → LD_PRELOAD 对 bun 无效（shim 内嵌编译进二进制，可执行文件自身符号优先）→ 走 CI bottle r53 | 无 |
| **修复层 3（真机确认）** | 真机 `bun 1.4.0+e8e90fcea`：`process.test.js` **3/3 全绿**（150 pass / 1 todo / 0 fail） | 待真机 |

**关键差异**：

1. **数据库不同**：他们的 shim 拦截的是 `getpwuid_r`（**用户**数据库
   /etc/passwd 的查询语义）；我们的 nogroup 修复补的是**组**数据库
   （/etc/group 的条目）—— 两个不同的数据库、两类不同的失败。
2. **他们的 shim 走了三层**：LD_PRELOAD 尝试 → 对 bun 无效（shim 的符号
   内嵌编译进二进制，可执行文件自身符号优先）→ CI bottle 发版 → 真机确认。
   这条链路的工程深度（LD_PRELOAD 对 bun 的局限性的发现与验证）值得学习。
3. **同文件的其他用例对照**（他们的记录，直接适用于我们）：
   - `process.test.js` node 版本用例：硬编码期望 host node v26.3.0，
     harmonybrew node 已 v26.7.0 → `it.todoIf(isMacOS || isOHOS)`
     （e8e90fceaa）—— **我们同款失败（process.release / node 版本）的同款解法**
   - `test-child-process-execsync`：OHOS /bin/sh 不做 sh -c exec 优化，
     SIGTERM 只杀 sh、孙子进程占住管道 → 同机 node 对照同样挂 → 平台差异，
     bun 免责，维持 quarantine
   - `security-scanner-matrix-with-node-modules`：7200 用例矩阵超预算 →
     quarantine

### 9.3 getHomedir 导入别名（跟进修复 `a62cc31a68`）

§5.3 表格的 `getHomedir` 行 —— PR #21 合并后的跟进修复：runner 导入
`getHomedir`，utils 导出 `homedir` —— 名字不匹配 → 模块加载即失败。
修复 = 导入别名（1 行），对齐参考通道的写法（其 runner 同样
`homedir as getHomedir`）。

### 9.4 对齐结论

| 项 | 参考通道 | 我们 | 状态 |
|---|---|---|---|
| GROUP 数据库（nogroup/nobody） | （其环境预置或未暴露） | ⬜ 未落地——修复当时只在孤儿分支 `claude/container-test-fixes`（`b625c3cae8`），补丁存档见下 | ⬜ 待随下一批容器 PR 落地 |
| USER 查询语义（getpwuid_r 合成） | ohos-compat-shim（三层验证链） | 未实施 | ⬜ 若 USER 类失败出现再评估 |
| process.test.js node 版本用例 | `it.todoIf(isMacOS \|\| isOHOS)` | 未实施（同款失败存在） | ⬜ 可直接移植 |
| execSync 管道 EOF（/bin/sh 不做 exec 优化） | 平台差异，bun 免责，quarantine | 同因（可沿用同结论） | ✅ 结论一致 |

**对齐方向**：我们的 GROUP 类修复（/etc/group 补条目）是他们方案的简化等价；
他们的 **shim 三层验证链**（LD_PRELOAD 局限性 → CI bottle → 真机确认）和
**`it.todoIf` 平台 gating** 是值得跟进的两个实践。

### 9.5 孤儿分支补丁存档：容器 /etc/group 补组（待落地）

原 `claude/container-test-fixes` 分支（`b625c3cae8`，无 PR，dev/ohos-aarch64 均
不含）已随分支清理删除，补丁以此为唯一存档。修 vendored node
test-process-euid-egid / test-process-uid-gid 的 `ERR_UNKNOWN_CREDENTIAL`
（OHOS userland 的 /etc/group 缺 nogroup/nobody）。插入
`.github/workflows/ohos-container-test.yml` 容器 setup 段、`/system` 符号链接
之后：

```yaml
          # The vendored Node tests (test-process-euid-egid / test-process-uid-gid)
          # setgid/setegid("nobody"/"nogroup") — the OHOS userland's /etc/group
          # lacks both, and the credential lookup throws ERR_UNKNOWN_CREDENTIAL.
          docker exec "$CONTAINER" bash -lc \
            'grep -q "^nogroup:" /etc/group || echo "nogroup:x:65534:" >> /etc/group; \
             grep -q "^nobody:" /etc/group || echo "nobody:x:65534:" >> /etc/group'
```
