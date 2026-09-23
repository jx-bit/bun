# 三方差异详细分析 — 2026-09-02

> dev = jx-bit/bun:dev（`535fb153c7`，PR #11/#12 已执行后的当前状态；PR #12 待合并）
> v1.4.0 = oven-sh/bun:bun-v1.4.0（`34cbb9a40b`）
> social4hyq = social4hyq/ohos-bun:ohos-aarch64（`f6aec3047c`，2026-08-29，仍在活跃）
>
> **当日修复已执行**：PR #11 恢复上游测试树 129 文件；PR #12 与 social4hyq 的
> v1.4.0 线完成 3-way 对账（见 `../issues/pr12-p1-test-tree-upstream-restore-and-reconcile.md`）。
> **重要更正**：social4hyq 已自行 merge v1.4.0（`391bfb8629`）—— 08-29 版的
> "他们未 merge" 结论失效，其当前树 = v1.4.0 + 设备验证的 OHOS 适配。
>
> **diff 语义注意**：本文 test/、src/ 数字除特别注明外均为**两点全树 diff**
> （`git diff A B`，双向差异）；GitHub compare API 是三点（仅己方相对
> merge-base 的变更）—— 早前 "src/ 48 vs 99" 的困惑源于此。

---

## 0. 总览

### 0.1 数据快照（修复执行后）

| 对比方向 | 两点全树差异 | 其中 test/ | 其中 src/ | 其他 |
|---|---:|---:|---:|---|
| dev vs bun-v1.4.0 | **210** | 120 | 48 | .github/workflows 10、scripts/build 8、ohos/ 8、散件 16 |
| dev vs social4hyq | **177** | 25 | 99 | scripts/build、.github/workflows、ohos/fulltest 等 53 |

test/ 行数（vs v1.4.0）：v1.4.0 独有 **1,686**（修复前 14,482，全部位于含
真实 OHOS 改动的混合文件内）/ 我们独有 **3,454**（OHOS skip/预算/v1.4.0 快照格式）。

### 0.1.1 test/ 与 social4hyq：完全收敛

两点差异 **25 个文件，双向零缺失**（他们有的我们都有，反之亦然），
25 个全部是**有意保留**：

- 每仓状态文件 ×4（dead-code-escape-limits、rust-check-all、build-rust、vm-thread-door）
- OHOS skip / fork 超时预算 ×12（spawn-ohos、dns、process、shell/spawn leak、
  socket fixture skip、no-orphans、multi-run 等）
- 我们的 v1.4.0 内容 ×5（url punycode、migrate lockfile snapshot 等）
- 纯格式差异 ×2（autofix 已规范化的 regression 测试）
- 新增采纳 ×2（linker-lds-shim-exports 等）

src/ 与 social4hyq 的 99 = 97 个双方各有适配（路线分歧，08-29 分析过）+
2 个他们独有：`src/ohos_sign/Cargo.lock`（独立 crate lock，我们走 workspace lock，
非缺陷）和 **`src/runtime/api/bun/ohos_node_userinfo.rs`（660 行，见 §4 新 P2）**。

### 0.2 与 08-29 版相比的变化

| 变化 | 影响 |
|---|---|
| PR #10 恢复 EPOLLONESHOT（posix_event_loop.rs） | src/ 差异 49 → 48，该文件与 v1.4.0 逐字节一致 |
| PR #9 合并（mordant struct + clippy -D warnings + fmt 全仓） | src/ohos_sign 与上游 lint 全对齐 |
| autofix commit（`b2c4342892`） | ~25 个文件纯格式对齐，部分 test/ 差异消失 |
| **首次量化 test/ 树问题** | 272 个测试差异文件、14,482 行上游测试内容缺失 |

### 0.3 时间线（解释 test/ 树为什么是现在这样）

```
2026-08-14  91054212c8  test(ohos): sync test tree + expectations from social4hyq
            （git checkout social4hyq -- test/，整树覆盖为我们旧基线的测试）
2026-08-15  ce76c1855a  clean sync：删除 social4hyq 已移除的 89 个文件
            → test/ 树 = social4hyq@0338f88130 逐字节一致
2026-08-28  4c71ecb79a  Merge tag 'bun-v1.4.0' into dev
            → src/ 冲突精心做了 3-way；test/ 冲突全部以 "ours"（=social4hyq 版）解决
            → v1.4.0 的测试更新就此丢失
2026-08-29  social4hyq 继续前进（f6aec3047c），双方测试树开始再次分叉
```

---

## 1. src/ 差异（48 文件）— 全部为 OHOS 适配，与 08-29 分析一致

`git diff HEAD bun-v1.4.0 -- src/`：**0 个文件缺失**（v1.4.0 的 src 内容完整），
**11 个新增**（ohos_sign crate 11 文件 + Cargo.toml 注册）。48 个差异文件分组：

| 分组 | 文件数 | 状态 |
|---|---:|---|
| install SELinux 回退（copy_file_fallback / IgnoreFailure / EPERM） | 10 | ✅ 已修复类型问题（PR #4），有意保留 |
| ohos_sign crate | 11 | ✅ 与上游 lint 全对齐（PR #9），有意新增 |
| jsc/bindings（spawn 签名、c-bindings、wtf 等） | 8 | 有意保留（OHOS gate） |
| sys cfg gates（target_env="ohos"） | 5 | 有意保留 |
| spawn 签名（process.rs / spawn_process.rs / stdio.rs） | 3 | 有意保留 |
| standalone_graph PIE | 2 | 有意保留（v1.4.0 + OHOS PIE 分流） |
| run_command.rs | 1 | ✅ v1.4.0 重构 + ohos_set_pwd（PR #7 补齐 gate） |
| resolver / crash_handler / options_types / napi_body / sys_jsc | 6 | 有意保留 |
| linker.lds | 1 | ✅ 15 shim 符号（PR #6）+ --undefined-version（flags.ts） |
| ~~posix_event_loop.rs~~ | ~~1~~ | ✅ **PR #10 已清账**，文件与 v1.4.0 一致 |

**结论：src/ 侧没有遗留问题。** 全部差异都是刻意的 OHOS 适配，且非 OHOS 路径
与 v1.4.0 完全一致（clippy/miri 在 host 目标上全绿佐证）。

---

## 2. test/ 差异（272 文件）— 本报告核心发现

### 2.1 总量与方向

```
git diff --numstat HEAD bun-v1.4.0 -- test/
  v1.4.0 独有行（我们缺失）: 14,482 行
  我们独有行（OHOS 改造/新增）: 2,969 行
```

**我们比 v1.4.0 少 5 倍的测试内容。** 由于 merge-base 就是 v1.4.0 本身
（合并真实发生），这些缺失全部是合并时以 "ours" 解决冲突的直接后果。

### 2.2 五类分解

| 类别 | 文件数 | 判定 | 处理方向 |
|---|---:|---|---|
| **A. 整文件缺失**（v1.4.0 有、我们没有） | **89** | ce76c1855a 删除（对齐 social4hyq） | **恢复** —— 这些是合法的上游测试 |
| **B. 纯过期**（我们的版本是 v1.4.0 的严格子集，0 OHOS 价值） | ~43 | merge 冲突误用 ours | **直接 checkout v1.4.0 版本**，零风险 |
| **C. 重度 OHOS 化**（我们独有行远多于缺失行） | 12 | 刻意改造 | **保留**，逐文件 review |
| **D. 混合**（双方都有大量改动） | ~95 | ours + 丢失上游更新 | **3-way 对账**（最费工） |
| **E. 小 diff**（格式/零星行） | ~33 | autofix + 零星 OHOS gate | 随 B/D 一并处理 |
| **F. 我们新增**（v1.4.0 没有） | 2 | spawn-ohos-node-userinfo / spawn-stdin-large-buffer | 保留 |

### 2.3 A 类：89 个被删的上游测试（ce76c1855a）

分布：`test/js/node/test/parallel` 37、`sequential` 6、
`test/cli/install/registry/packages/optional-peer-hoist-*` 约 30（fixture 包）、
`test/internal` 3 + source-lints 2、`test/js/bun/spawn` 2、其他若干。

删除理由是"social4hyq 已移除、跑起来是 false failure"。**但那是 social4hyq
基于旧基线的判断** —— 这些文件在 v1.4.0 上是活的测试。典型如：

- `test/cli/inspect/debugger-buntranspiledmodule.test.ts`（v1.4.0 中 246 行）
- `test/cli/install/bun-install-git-deps.test.ts`（425 行）
- 43 个 node 官方 conformance 测试（cluster/child_process 等）

恢复后这些测试大概率**直接可跑**（我们 src 已经是 v1.4.0 基础），
个别失败再按需 quarantine —— 这才是正确的 quarantine 流程
（先跑、失败才隔离），而不是先删后不跑。

### 2.4 B 类：纯过期 top 示例（约 43 个）

| 文件 | 丢失行数（v1.4.0 独有） |
|---|---:|
| test/bundler/bundler_compile.test.ts | 127 |
| test/bundler/bundler_compile_splitting.test.ts | 88 |
| test/bundler/bundler_plugin.test.ts | 55 |
| test/cli/install/bun-install-git-deps.test.ts | 425 |
| test/cli/install/bad-workspace.test.ts | 158 |
| test/bundler/transpiler/transpiler.test.js | 52 |
| ... | ... |

特征：numstat 显示 `N 0`（纯丢失、无独有内容）→ 我们的版本不含任何 OHOS
改动，纯粹是旧版。**`git checkout bun-v1.4.0 -- <file>` 即可无损修复。**

### 2.5 C 类：12 个重度 OHOS 化测试（保留）

| 文件 | 我们独有行 | 说明 |
|---|---:|---|
| test/expectations.txt | 351 | social4hyq 分类学 + 我们的 82 处 OHOS quarantine（见 §2.7） |
| test/js/bun/spawn/spawn-ohos-node-userinfo.test.ts | 122 | 我们新增（OHOS passwd 行为） |
| test/bundler/bun-build-compile.test.ts | 75 | OHOS 编译路径改造 |
| test/js/bun/spawn/spawn-stdin-large-buffer.test.ts | 64 | 我们新增 |
| test/integration/vite-build/vite-build.test.ts | 28 | OHOS 适配 |
| test/cli/run/no-orphans.test.ts | 23 | OHOS fork 开销预算 |
| 其余 6 个 | 14-38 | 零散 OHOS 适配 |

### 2.6 D 类：混合 ~95 个

典型：`test/js/node/fs/fs.test.ts`（13 OHOS 标记 + 丢失 v1.4.0 更新）、
`test/js/node/process/process.test.js`（9 标记）、`test/js/bun/dns/resolve-dns.test.ts`、
`test/cli/install/*` 大部分。这类需要逐文件把 v1.4.0 的新增 merge 回来，
同时保留 OHOS gate/skip —— 相当于对测试树重做一次"正确的 3-way"。

### 2.7 test/expectations.txt 三方状态

| 方 | 状态 |
|---|---|
| v1.4.0 | 上游维护的 quarantine 清单（含 Windows/musl 专项） |
| social4hyq | 旧基线清单 + 他们的 OHOS 项 |
| 我们 | **social4hyq 版整树覆盖** + 我们 82 处 OHOS 标记（spawn/EPOLLONESHOT/fulltest 相关） |

问题：上游在该文件里的条目变动（新增 quarantine、修复后移除）我们全都不知道。
文件头部的警告在我们这里尤其致命——"条目按子串匹配，过期条目静默禁用整个文件"。

### 2.8 影响评估

1. **上游 1.4.0 新增的测试我们一个都没跑**（回归保护缺位）。
2. **上游修复测试的 PR 我们全部没有** —— src 对齐了、测试没对齐，
   等于"代码是新的、考卷是旧的"。
3. 我们的 CI 测试数字与上游不可比（口径不同）。
4. 好消息：**src 是干净的** —— 恢复测试不会暴露 src 层的合并缺陷，
   失败只可能来自 (a) 真实的 OHOS 平台差异（ quarantine 即可），
   (b) 测试文件内嵌的 OHOS 假设需要更新。

---

## 3. dev vs social4hyq（177 文件，两点全树 diff）

social4hyq 仍在活跃开发（HEAD `f6aec3047c`，2026-08-29）：
unquarantine napi-rs/canvas + rspack（via @ohos-ports 社区绑定）、
resvg-js 解析迁移、multi-run.test.ts 超时预算确认修复等。

| 目录 | 文件数 | 性质 |
|---|---:|---|
| test/ | 25 | **全部为有意保留**（§0.1.1）—— 测试树已对账完成 |
| src/ | 99 | 两点全树差异 = 97 个双方各有 OHOS 适配（路线分歧）+ 2 个他们独有（ohos_sign 独立 lock + ohos_node_userinfo.rs，后者为新 P2） |
| scripts/build、.github/workflows、ohos/ 等 | 53 | 我们的 CI 矩阵 / Tier2 分类 / fulltest 基础设施 + 他们侧的等价物 |

**结论：与 social4hyq 的剩余分歧是"路线"而非"缺陷"** —— 对的部分已吸收
（symbols.dyn 全量、Highway 不禁用、EPOLLONESHOT 恢复、测试树对账、
expectations 现行版），剩余分歧（install 回退、ohos_sign、v1.4.0 基础）是
我们的优势项。PR 描述与 commit message 已按规则中性化（不出现 fork 名）。

---

## 4. 修复建议执行状态（当日更新）

| 原优先级 | 事项 | 状态 |
|---|---|---|
| P1 | B 类纯过期测试恢复 | ✅ PR #11（40 文件） |
| P1 | A 类 89 个缺失测试恢复 | ✅ PR #11（合并执行） |
| P2 | D 类混合文件 3-way 对账 | ✅ PR #12（batch 1 非 test/js + batch 2 test/js，74 文件） |
| P2 | expectations.txt 重建 | ✅ 随 PR #12 采纳 social4hyq 现行分类学（我们 sync 后零自有改动，无损失） |
| P3 | test tree 真源策略成文 | ✅ 已成文（issues/p1-test-tree-...md §7）：上游为基准、OHOS 差异走 per-case quarantine |
| P3 | 吸收 @ohos-ports 社区绑定方案 | ⏸️ 未开始（social4hyq 08-29 的 canvas/rspack unquarantine 路线） |

### 新增 P2：`src/runtime/api/bun/ohos_node_userinfo.rs` 缺失

test/ 树里有 `spawn-ohos-node-userinfo.test.ts`（OHOS 上验证 os.userInfo()），
但对应实现 —— social4hyq 的 `src/runtime/api/bun/ohos_node_userinfo.rs`
（660 行，HarmonyOS 沙箱 uid 下给 bun 孵化的 node/npm 等子进程修复
os.userInfo()，依赖 ohos-compat-shim 的 getpwuid_r interposition）——
从未跟过来（8 月只 sync 了 test/）。**当前设备上该测试必挂**。

移植需要：实现文件 + runtime Cargo.toml 注册 + mod 挂载 + 触发点
（对照 social4hyq 的引用方式）。host CI 不受影响（测试 skipIf !isOHOS）。

---

## 5. 与 08-29 版结论的对照

| 08-29 结论 | 09-02 现状 |
|---|---|
| src/ 49 文件差异 | 48 文件（posix_event_loop.rs 清账，PR #10） |
| P0 symbols.dyn / linker.lds | ✅ 均已修复（全量 667 行 + --undefined-version） |
| P1 Highway SVE | ✅ 已修复（PR #5） |
| P1 EPOLLONESHOT | ✅ 已修复（PR #10） |
| P2 run_command gates / shim 符号 | ✅ 均已修复（PR #7 / PR #6） |
| P3 Format/Source lints | ✅ 已修复（PR #8/#9 + autofix 常驻） |
| **未覆盖：test/ 树问题** | ✅ **当日已修复**（PR #11 恢复 + PR #12 对账，见 issues/p1-test-tree-...md） |
| （08-29 未知）social4hyq 已 merge v1.4.0 | 当日实测确认（391bfb8629），对账策略据此调整 |
| （当日新发现）ohos_node_userinfo.rs 缺失 | 新 P2，见 §4 |

---

*分析日期：2026-09-02 | 分析者：Sisyphus*
*数据来源：git diff（HEAD=b11d63bbcb/add5d81289 vs bun-v1.4.0）+ gh api compare（social4hyq@f6aec3047c）*
*关联文档：tri-way-diff-analysis-2026-08-29.md、../issues/pr10-p1-epolloneshot-disabling.md、autofix-ci-format-pipeline.md*
