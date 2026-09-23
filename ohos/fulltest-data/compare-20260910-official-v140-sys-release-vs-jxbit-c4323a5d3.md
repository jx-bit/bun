# 2026-09-10 对比：官方 v1.4.0 测试源码 × social4hyq 1.4.0 vs jx-bit 最新构建

同设备、同测试树、同口径，唯一变量 = binary。**测试源码与被测版本严格对齐（1.4.0）**，
消除了"测试期望新行为"的干扰，独有失败直接反映 binary 自身差异。

## 口径

| 项 | 值 |
|---|---|
| 测试源码 | oven-sh/bun 官方 **`bun-v1.4.0` tag**（`34cbb9a4`，package.json 1.4.0） |
| 测试树 | `/storage/Users/currentUser/opencode/bun-official-v140`（git worktree） |
| 文件数 | 2062 pre-exclude − 61 `[OPENHARMONY] Skip` = **2001** |
| 超时口径 | TMOUT=180s RETRIES=1（bundler 900s / bake-dev 60s） |
| 环境适配 | esbuild@0.18.6/0.25.1 平台二进制手动放置 + ohos-selfsign；`--ignore-scripts` 装依赖 |

## 被测 binary

| binary | 版本 | 来源 |
|---|---|---|
| 轮 A `bun-sys-release` | **1.4.0+61dbc3a9d** | harmonybrew Cellar/bun/1.4.0_80（bottle `bun-v1.4.0-r92`，构建自 ohos-aarch64 @ 61dbc3a9d，2026-08-25） |
| 轮 B `bun-ohos-jxbit-signed` | **1.4.0-canary.1+c4323a5d3** | jx-bit/bun release `ohos-latest`（2026-09-09 构建，sha256 `5356c224…` 与元数据一致，ohos-selfsign 签名） |

> 两 binary 同为 1.4.0 系，但 commit 相差 15 天（08-25 vs 09-09），c4323a5d3 含
> PR #29 `fix(ohos): report process.platform as "openharmony"` 等新修复。

## 结果总览

| 指标 | A: social4hyq 1.4.0+61dbc3a9d | B: jx-bit c4323a5d3 | 差值 |
|---|---|---|---|
| Duration | **02:00:58** | 02:31:39 | B 慢 25% |
| 文件通过 | **1816/2001 (90.75%)** | 1754/2001 (87.66%) | A +62 |
| 用例 pass | **68919** | 68371 | A +548 |
| 用例 fail | **637** | 943 | A 少 306 |
| 用例率 | **99.08%** | 98.63% | A +0.45pp |
| 超时 | **6** | 12 | A 少 6 |
| 崩溃 | 0 | 0 | — |

## 文件级集合运算（2001 join）

| 集合 | 数量 | 占比 |
|---|---|---|
| 两轮都失败 | 146 | 7.3%（官方套件在 OHOS 的环境基线） |
| 仅 jx-bit 失败 | **101** | 5.0% |
| 仅 sys-release 失败 | **39** | 2.0% |

## jx-bit 独有失败 101 的根因

### ① `process.platform` 返回 "linux" → sql 段整段误杀（30 文件，最大簇）

**实测**：`jxbit -e 'console.log(process.platform)'` → `"linux"`；
`sys-release 1.4.0` → `"openharmony"`。

官方 v1.4.0 的 sql 测试 harness（如 `postgres-binary-numeric.test.ts` beforeAll）：
```ts
if (isCI && isLinux) throw new Error("A functional `docker` is required in CI for some tests.");
// isLinux = process.platform === "linux" (harness.ts:21)
```
- jx-bit：platform="linux" + CI=1 → throw → 30 个 sql 文件 0 用例直接挂
- social4hyq：platform="openharmony" → 不 throw → 正常跑本地 fixture

**讽刺点**：c4323a5d3 这个 commit 本身就是 PR #29 `fix(ohos): report process.platform as "openharmony"` 的 merge commit——**修复没进这个构建**（jx-bit CI 构建早于 merge 或取错 commit）。rebuild 后该簇应整簇消失。

### ② PATH bin 解析缺陷（cli/run 12 + cli/inspect 4）

`as-node.test.ts` 复现：`error: Script not found "node"`——测试经 PATH 注入 fake `node`，
jx-bit 构建的 `bun run` 找不到（与 fork 树轮 2026-09-08 的取证一致，跨树稳定复现）。

### ③ 其余（regression 10、cli/install 8、shell 9、spawn 3 等）
散布的 1.4.0 后期修复缺失/行为差异，同 fork 树轮结论。

## sys-release 独有失败 39 的根因

| 簇 | 数量 | 说明 |
|---|---|---|
| `bake/dev/` | 14 | sys-release 1.4.0 的 bake dev server 在官方树上整段偏弱（1.4.2 已收敛到 5 个，趋势良好） |
| `internal/`（含 source-lints） | 7 | 构建系统/源码 lint 类测试 |
| `cli/install/` | 4 | security-scanner matrix、lockb 迁移 |
| `regression/issue/` | 3 | 10132、26225、26657 |
| bundler 3、napi 2、v8/glob/mmap/os 各 1 | 11 | 散布 |

> jx-bit 分支晚 15 天，`bake/dev` 等段带有 social4hyq 1.4.0 分支还没有的修复——这 39 个
> 是"jx-bit 分支更新"的真实收益面。

## 结论

1. **同版本号对决（1.4.0 vs 1.4.0-canary.1），social4hyq harmonybrew 构建（1.4.0_80）整体更稳**：
   用例率高 0.45pp、快 25%、超时少一半，且 `process.platform="openharmony"` 语义正确
   （这正是 61dbc3a9d 时期已合入的正确行为）。
2. **jx-bit c4323a5d3 构建的 process.platform 修复未生效**（CI 构建流程问题）——rebuild 后
   sql 30 个 + 平台相关失败应大幅回退；PATH bin 解析（`Script not found`）仍需单独修。
3. 两 binary 在 1.4.0 官方套件上**均无崩溃**（对比 46a905a6c 在 fork 树上的 2 崩溃，
   c4323a5d3 的 panic 修复有效）。
4. 146 个重叠失败构成"官方 v1.4.0 套件 × OHOS"环境基线，后续轮次可直接复用。

## 归档

| 轮次 | 目录 |
|---|---|
| 轮 A sys-release | `archives/20260910_fulltest_official-v140-sys-release/` |
| 轮 B jx-bit | `archives/20260910_fulltest_official-v140-jxbit/`（lists/ 含三张集合清单） |

关联文档：`compare-20260908-sys-release-vs-jxbit-46a905a6c.md`（fork 树 1.4.0-fork 口径）、
`analysis-jxbit-46a905a6c-failures.md`（270 独有失败机制分析）、
`compare-20260908-sys-release-vs-jxbit-46a905a6c.md` 同目录。
