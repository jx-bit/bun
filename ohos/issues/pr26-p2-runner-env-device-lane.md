# P2: runner 设备通道环境缺配（NODE_TEST_DIR + 外层超时 ×3）— 工作记录

> **关联 PR**：[#26](https://github.com/jx-bit/bun/pull/26)（dev → ohos-aarch64，交付 PR，OPEN）
> · 前身 [#25](https://github.com/jx-bit/bun/pull/25)（合并进 dev `dc89738c12` 后因 dev
> 重整被孤立，内容经 #26 单 commit `296f566685` 送达）
> **状态**：🔄 #26 OPEN（待真机/容器轮复验）
> **落地链路**：claude 分支 → dev（#25）→ 重整为单 commit → dev → ohos-aarch64（#26）。
> **规则（已固化进 README 操作要点）**：一个 PR 一个 commit —— 交付 PR 用重整后的
> 单 commit（对齐 #24 先例）；feature PR 提交前先过格式化，避免 autofix.ci 追加
> 第二个 commit。
> **定位**：20260903 fulltest（200 失败）交叉 triage 后落地的第一批可移植修复 —— 设备通道 runner 环境/超时对齐。
> 数据源：`20260903_fulltest_aarch64-github/`（数据集已清理，交叉 triage 结论已并入本档）。

## 1. 问题一句话

20260903 轮 200 个失败文件中，有两类在我们侧是 runner 环境缺配而非运行时缺陷：
vendored node 测试临时根落在不能放 AF_UNIX/硬链接的目录树内（EPERM 类 ~22 文件），
以及外层 wall-clock kill 无视文件自身 `setDefaultTimeout()`（超时类 5-11 文件）。

## 2. 根因

### 2.1 NODE_TEST_DIR 缺配（EPERM 类）

vendored node 测试的 `test/js/node/test/common/tmpdir.js:24`：

```js
const testRoot = process.env.NODE_TEST_DIR ?
  fs.realpathSync(process.env.NODE_TEST_DIR) : path.resolve(__dirname, '..');
```

不设 `NODE_TEST_DIR` 时，临时根 = `test/js/node/` —— 源码树内的深层长路径。
OHOS 上该位置：

- **AF_UNIX bind EPERM**：socket 文件落在受限目录树内；
- **硬链接 EPERM**：同上，test-fs 系列直接红；
- **`sun_path` 108 字节上限**：`common/index.js` 用 `path.relative(cwd, NODE_TEST_DIR)`
  推导 AF_UNIX pipe 路径，长路径挤爆 `sockaddr_un.sun_path`。

参考通道（social4hyq runner.node.mjs，真机验证）在 `process.platform === "openharmony"`
时注入 `NODE_TEST_DIR = mkdtempSync(join(tmpdir(), "nt-"))` —— 短前缀是刻意的（见注释）。

### 2.2 外层 wall-clock 无 OHOS 缩放（超时类）

runner 的 `spawnBunTest` 对每个测试文件有独立于 bun test 内部超时的外层 wall-clock kill：

```js
timeout: isReallyTest ? Math.ceil(timeout * (isAsan ? 2 : 1)) : 30_000,
```

OHOS fork/spawn 与 fs 系统调用慢 2-3 倍，外层 kill 又**无视文件自身的
`setDefaultTimeout()`** —— install/migration 重组件把内部超时提到 5 分钟也没用，
外层先杀。参考通道的修法：openharmony 时 ×3（与 ASAN ×2 叠乘）。
本轮口径 TIMEOUT=300s → OHOS 实效 900s。

## 3. 修复（scripts/runner.node.mjs）

两处均 openharmony-gated，其他平台零行为变化（落地形态 +14/-1，autofix 格式化后）：

```diff
   TEST_TMPDIR: tmpdirPath, // Used in Node.js tests.
+  ...(process.platform === "openharmony"
+    ? { NODE_TEST_DIR: mkdtempSync(join(tmpdir(), "nt-")) }
+    : {}),
   ...(ohosSysroot ? { OHOS_SYSROOT: ohosSysroot } : {}),
```

```diff
-  timeout: isReallyTest ? Math.ceil(timeout * (isAsan ? 2 : 1)) : 30_000,
+  timeout: isReallyTest
+    ? Math.ceil(timeout * (isAsan ? 2 : 1) * (process.platform === "openharmony" ? 3 : 1))
+    : 30_000,
```

注入点在 `spawnBun` 的 `bunEnv`，串行与 parallel-bucket 两条路径都经此收敛（单点生效）。

## 4. 与参考通道的全面对比（摘要）

参考通道 runner 共 5 处 `openharmony` 门控 + 2 处 TERM 处理，逐块逐字核对完毕。
**每处的双方原始代码并列、逐字 diff 与量化影响**见专用对比文档：
[`../knowledge/runner-comparison-social4hyq.md`](../knowledge/runner-comparison-social4hyq.md)。

| # | 门控点 | 结论 |
|---|---|---|
| 1 | `getCombinedPath` llvm@21 PATH（node-gyp） | ✅ 一致（#23 已移植） |
| 2 | `OHOS_SYSROOT` fallback（ffi TCC） | ✅ 逐字一致 |
| 3 | `NODE_TEST_DIR` 短路径 tmpdir | ✅ 代码逐字一致（本修复） |
| 4 | 外层 wall-clock ×3 | ✅ 表达式逐字一致（本修复） |
| 5 | expected-durations `ohos` 装箱列 | ❌ 我们缺失 → 后续（需先产出 ohos 时长数据） |
| 6 | TERM dumb→xterm（runner 层） | ⚠️ 层级缺口 → 暂缓（§4.1） |
| 7 | styletext 专项 TERM pin | 不需要（该测试不在本轮 200 失败清单） |
| 8 | 每测试 `--timeout` 缩放 | ✅ 双方均不缩放（避免并发桶突破 shard 预算） |
| 9 | env 漏斗架构（spawnBun 单点组装） | ✅ 等价 —— 本修复单点注入对串行+并行桶同时生效 |

### 4.1 TERM 层级差异（暂缓，记录决策）

参考通道在 runner 层做 `TERM=dumb → xterm-256color`（不加门控），覆盖的是
**`bun test` 进程本身**；我们的 `harness.ts:86` 同语义修复只覆盖测试**派生的
子进程**。理论上 agent shell 以 TERM=dumb 调起 runner 时，`bun test` 进程内的
readline/REPL 光标断言仍会挂。暂缓理由：

- 未映射到本轮 200 失败清单中任何确证失败类（repl/terminal 在其台账中的归因
  是 fetch-tls flake 与并发假象，非 TERM）；
- 参考通道的实现不加门控，照搬会把非 OHOS 通道（Buildkite 继承 lane）的
  TERM 语义一并改掉，超出本修复范围；
- 若后续轮次出现 TERM=dumb 相关失败，按 openharmony 门控补 1 行即可。

## 5. 验证

- `node --check scripts/runner.node.mjs` 通过
- 系统 bun + runner 冒烟全流程（`--include=bun/empty-file`）：文件匹配、执行、
  results.json 产出 `ok=true` —— Linux 上改动按设计惰性
- OHOS 生效路径为参考通道真机验证过的原版实现的忠实移植（其 runner
  NODE_TEST_DIR 块与外层超时行逐行对齐）
- 交付形态核验：#26 GitHub diff = 1 文件（runner.node.mjs）+14/-1，单 commit，
  与 #25 内容一致
- 附带核查：上会话标记"疑似被覆盖"的 `src/spawn_sys/spawn_process.rs`
  自 `cf279097ff` 起无变动，完好，无需恢复

## 6. 预期收敛（对照 20260903 轮 200 失败清单）

| 类 | 文件数 | 代表文件 |
|---|---:|---|
| EPERM（NODE_TEST_DIR） | ~22 | `test/js/node/fs/fs.test.ts`、`node-net.test.ts`、`watch/fs.watch.test.ts`、`message-port-context-destroy-leak.test.ts` 等 vendored node 用例 |
| 超时（wall ×3） | 5-11 | `multi-run.test.ts`、`no-orphans.test.ts`、`run-crash-handler.test.ts`、watch/shell-leak 系 |

完整逐文件映射见同目录 cross-triage 文档 `cross-triage-map.tsv`（bucket 列）。

## 7. 交付链路事件（dev 重置与单 commit 重整）

#25 合并进 dev（`dc89738c12`）10 分钟后，dev 被重置回合并前点位 `ff908e9bbc`
（例行"dev 对齐 ohos-aarch64 tip"操作，当时 #25 内容尚未经交付 PR 送达），
#25 的 merge commit 从所有分支悬空。处置：以 `ff908e9bbc` 为基重建单 commit
`296f566685`（含 autofix 格式化），`--force-with-lease` 推 dev，开 #26 送达。
教训：**dev 是交付暂存区，交付 PR（dev → ohos-aarch64）合并前不要重置 dev；
feature PR 直进 dev 的 merge 会被后续交付重整吸收。**

## 8. 后续问题分析（2026-09-08 更新：前两项已重新归因）

1. **install 家族 ~24 文件（原"待移植 $npm_* 修复"）—— ✅ 无需新代码**：
   参考通道的 e39db04d6 实为 `bun-spawn.cpp` 的 newEnvp 悬垂修复（envp 指针
   数组声明在嵌套 if 内、出作用域后才被 execve 读 → 生命周期脚本子进程里
   `$npm_*` 等环境变量丢失/错乱）。我们已有同题移植 `de0c2dbfbe5`（8/13），
   在 origin/ohos-aarch64。20260903 轮二进制 3c97d0089 血缘"不含 8 月版"
   → 不含此修复 —— 下一轮构建应自然恢复 bun-pack/publish/lifecycle-scripts/
   workspaces 对应用例。install 家族剩余失败另有归因：网络域（lane 无
   registry 访问）、posix_spawn EACCES 簇、摇摆（bun-add 300s git 依赖超时）。
2. **terminal/tty/websocket 回挂 7 文件 —— 构建血缘问题，非新代码回归**：
   535fb153c7e（9/2，含 EPOLLONESHOT 恢复 `b11d63bbcb9`）过、3c97d0089
   （9/3，不含 8 月版）挂。7 个文件（terminal ×2、tty、websocket ×3、ws）
   全部 event-loop fd 驱动，与 pr10 文档记载的"禁用 EPOLLONESHOT → I/O
   时序变化/特定 I/O 模式超时"症状形状吻合。首嫌疑：9/3 构建缺
   `b11d63bbcb9`（9/2 10:55，仅早于构建交接 34 小时）。3c97d0089 是选择性
   血缘（含 pr14 codesign，9/3 19:56 合并）——说明构建方有挑拣机制，漏了
   这批。**行动：向构建方提交修复清单，或直接从 ohos-aarch64 tip 切下一轮
   构建**，必须包含：`de0c2dbfbe5`（newEnvp）、`b11d63bbcb9`（EPOLLONESHOT）、
   `09c6251265c`（SVE 恢复）、`6e4aadc682a`（shim 符号）、`519c8f5e37b`
   （run_command cfg gates）、#26（NODE_TEST_DIR + wall ×3）。
3. **napi 设备通道**：`.node` 产物手动补签名（build:napi 路径不经 bun 签名流程）
4. **shard 装箱 `ohos` 时长列**（对比表 #5）：参考通道按
   `expected-durations.json` 的 `ohos` 列做 LPT 装箱；我们的
   `loadExpectedDurations`（runner.node.mjs L2566）无该列，OHOS 上按 default
   （x64）时长装箱 → 重件（如 run-crash-handler 2268ms vs 519s）集中单桶。
   前置条件：先从一轮真机 run 产出 `ohos` 列数据（参考其
   scripts/update-ohos-test-durations.mjs），再补列选择。

## 9. 关联

- 容器通道对齐基线：[pr21-p2-container-lanes-bringup.md](pr21-p2-container-lanes-bringup.md) §5.3/§5.4
- 容器环境三项：[pr23-p3-container-env-align.md](pr23-p3-container-env-align.md)
- 交付先例：[pr24-p2-gethomedir-import-alias.md](pr24-p2-gethomedir-import-alias.md)（同为 dev → ohos-aarch64 单 commit 交付）
- 交叉 triage 全量：`20260903_fulltest_aarch64-github/`（数据集已清理，cross-triage-social4hyq-20260907 结论已并入本档）
