# P1: 测试树过期 — 上游恢复 + social4hyq v1.4.0 对账 — ✅ 已修复（PR #11 + #12）
> **关联 PR**：[#12](https://github.com/jx-bit/bun/pull/12)（reconcile 主修复）· [#11](https://github.com/jx-bit/bun/pull/11)（恢复 129 文件）

> 我们的 test/ 树在 2026-08-14 被整体替换为 social4hyq 的**pre-1.4.0** 测试树，
> 8-28 的 v1.4.0 合并又把全部测试冲突以 "ours" 解决 —— 结果 src/ 是 v1.4.0
> 基础，测试却是旧考卷：**14,482 行上游测试内容缺失**。
>
> **状态：已修复并合并。** PR #11（恢复 129 个文件，合并 `f7916100c5`）+
> PR #12（与 social4hyq 的 v1.4.0 线 3-way 对账 74 文件，单 commit
> `535fb153c7`，已合并 `982fc83613`）。
> 快 checks 全绿；设备侧验证（恢复的 ~128 个测试在真机跑一轮）待自托管
> runner 上线。

---

## 1. 问题是怎么形成的（时间线）

```
2026-08-14  91054212c8  test(ohos): sync test tree + expectations from social4hyq
            （git checkout social4hyq -- test/ 整树覆盖）
2026-08-15  ce76c1855a  clean sync：删除 social4hyq 已移除的 89 个文件
            → test/ = social4hyq@0338f88130 逐字节一致（pre-1.4.0 测试树）
2026-08-28  4c71ecb79a  Merge tag 'bun-v1.4.0' into dev
            → src/ 冲突精心 3-way；test/ 冲突全部以 "ours"（旧树）解决
2026-08-29  social4hyq 自己 merge 了 v1.4.0（391bfb8629）并继续设备验证
            → 双方测试树分叉，且他们已经是 v1.4.0 + OHOS 适配的形态
2026-09-02  本 issue 修复（PR #11 + #12）
```

关键教训：**8 月的"整树对齐 social4hyq"在对方还是旧基线时执行，
而 v1.4.0 合并时 test/ 冲突没有像 src/ 那样精心处理。**

---

## 2. 量化发现（tri-way-diff-analysis-2026-09-02）

```
git diff --numstat HEAD bun-v1.4.0 -- test/  （修复前）
  v1.4.0 独有行（缺失）: 14,482
  我们独有行:            2,969
  差异文件:              272
```

五类分解：

| 类 | 定义 | 文件数 | 处理 |
|---|---|---:|---|
| A | 整文件缺失（v1.4.0 有我们没有） | 89 | PR #11 恢复 |
| B | 纯过期（我们的版本是 v1.4.0 严格子集） | ~40 | PR #11 恢复 |
| C | 重度 OHOS 化 | 12 | 保留 / 对账 |
| D | 混合（双方都有改动） | ~95 | PR #12 对账 |
| E | 小 diff（格式/零星） | ~33 | 随 D 处理 |
| F | 我们新增 | 2 | 保留 |

---

## 3. 修复第一步：恢复上游测试树（PR #11，commit `dfb70ae1f5`）

### 3.1 恢复判据

**只恢复 `deletions == 0` 的文件**（我们侧零独有行）—— 有任何 OHOS 行的文件
必然 deletions>0，因此该判据从构造上保证零损失：

- 89 个缺失文件（`--diff-filter=A`）：43 个 node conformance（cluster/
  child_process 等）、~30 个 optional-peer-hoist 安装 fixture（.tgz+package.json）、
  debugger-buntranspiledmodule（246 行）、bun-install-git-deps（425 行）等
- 40 个严格过期文件：bundler_compile(127)/bundler_compile_splitting(88)/
  bundler_plugin(55)、bad-workspace(158)、transpiler(52) 等

### 3.2 安全验证

- `test/harness.ts` 与 v1.4.0 逐字节一致 → 恢复的测试 import 的 helper 全在
- 129 个文件中仅 1 个被现有 expectations.txt quarantine（node-dns）
- parse/imports 扫描：100 个代码文件全过；10 个 fixture package.json 合法 JSON
- C/D 类文件零触碰（抽查 bun-build-compile.test.ts 保持 5/75 原样）

### 3.3 效果

```
test/ 与 v1.4.0 差异文件: 272 → 143
v1.4.0 独有行:          14,482 → 5,251
```

---

## 4. 修复第二步：与 social4hyq v1.4.0 线对账（PR #12）

### 4.1 策略转向的依据

**新发现**：social4hyq 已自行 merge v1.4.0（`391bfb8629`），其当前树
（`f6aec3047c`）= v1.4.0 + 持续设备验证的 OHOS 适配（epoll re-arm 修复、
node-ohos ABI 优先、@ohos-ports 社区绑定、quarantine 重整）。

因此对账采用逐文件 3-way：

```
base   = 0338f88130        （我们测试树的实际来源）
ours   = dev               （base + 我们 v1.4.0 合并的 test 内容 + autofix）
theirs = hyq/ohos-aarch64  （base + 他们 v1.4.0 合并 + 设备适配）
git merge-file -L ours -L base -L theirs
```

### 4.2 批 1：非 test/js（36 文件，commit `88930e203d`）

| 决策 | 文件 | 理由 |
|---|---|---|
| 取 theirs 全量 | harness.ts | 找回 isOHOS helper + node-ohos ABI 优先逻辑；**我们 v1.4.0 合并曾把 isOHOS 删掉**，而大量 OHOS 测试依赖它 |
| 取 theirs 全量 | isolated-install / bun-add / native-plugin / watcher-trace / require-cache / bun-pm-scan / init / napi-uv | 重度分歧文件 diff3 会**静默错位拼接**（见 §4.4），他们的版本 = v1.4.0 + 设备验证 |
| 取 theirs 全量 | test/package.json + bun.lock | lock 必须与 package.json 状态一致 |
| 取 theirs 全量 | expectations.txt | 我们 sync 后**零改动**（delta=0），他们的版本是持续维护的现行分类学 |
| 采纳新文件 | linker-lds-shim-exports.test.ts | 他们新增，回归守护 linker.lds shim 导出漂移 —— 正好配套我们的 PR #6 |
| 保留 ours | dead-code-escape-limits.json / rust-check-all / build-rust / vm-thread-door | **每仓状态文件**，编码的是我们自己 src 的 lint 计数与工具链状态 |
| 保留 ours | migrate-bun-lockb snapshot | 我们的 v1.4.0 lockfile 格式（含 os/arch 字段） |
| 保留 ours | regression 24742 / 28159 / 29290 | 纯 prettier 格式差异，autofix 已规范化 |

结果：非 test/js 与 social4hyq 差异 36 → 10（全部是有意保留）。

### 4.3 批 2：test/js（58 文件，commit `155132cf5f` → rebase 后 `155132cf`）

| 决策 | 文件数 | 明细 |
|---|---:|---|
| 收敛到 theirs | 43 | 我们侧无独有内容 |
| 取 theirs 全量（冲突审后） | 5 | rm（OHOS unlinkat 可删 Linux 拒绝的深路径）、node-http-backpressure（上游 request-body 新覆盖）、node-http2 / process-stdin / node-tls-server（isOHOS skipIf） |
| 真合并（双方内容都保留） | 4 | |
| 保留 ours | 10 | OHOS skip/fork 预算（spawn-ohos、dns、process、shell/spawn leak、socket fixture skip）+ v1.4.0 新增（url punycode） |

### 4.4 踩坑：diff3 静默错位（重要经验）

三个"干净合并"（merge-file exit 0）的结果事后发现是错的：

| 文件 | 症状 | 根因 |
|---|---|---|
| isolated-install.test.ts | `gitExecutable has already been declared`（重复声明） | 两侧都各自加了相似测试块于不同位置，diff3 把两份都拼了进去 |
| harness.ts | 合并后 isOHOS 引用悬空 | 他们新增的 node-ohos 块引用 isOHOS，而我们 side 的 base 区已被 v1.4.0 重写 |
| bun-pm-scan.test.ts | import 有 setDefaultTimeout 但调用行丢失 | ours 在 base 上删了调用行，theirs 保留 → 自动取了我们的删除 |

**规则：重度分歧文件（双方都有大量改动）不要信任 exit-0 的 diff3，
逐文件对比合并结果与两个 parent，必要时要 their 全量。**

### 4.5 自动化验证

- 每次 batch 后 parse/imports 扫描（Bun.Transpiler.scanImports）：
  批 1 22/22、批 2 50/50
- OHOS 标记保全检查：结果文件标记数 < max(ours, theirs) 即报警
  → 由此抓出 harness/bun-pm-scan 丢失
- autofix 收敛：恢复与合并的文件 prettier 零修正或 bot 自动修
  （batch 1 触发 `725349a852`、batch 2 触发 `c19889c8b9`，均为纯格式）

---

## 5. 最终状态

```
test/ 与 social4hyq 差异（两点全树 diff）: 25 文件，双向零缺失
  → 全部为有意保留：每仓状态 ×4、OHOS skip/预算 ×12、
    我们的 v1.4.0 内容 ×5（url punycode、lockfile snapshot）、
    纯格式 ×2、其他 ×2
test/ 与 bun-v1.4.0 差异: 120 文件
  行数: v1.4.0 独有 1,686（修复前 14,482，全部位于含真实 OHOS
  改动的混合文件内）/ 我们独有 3,454
```

### 5.1 对账中发现的新缺口（新 P2）

`spawn-ohos-node-userinfo.test.ts`（OHOS 上验证 os.userInfo()）在
我们的测试树里，但其实现 —— social4hyq 的
`src/runtime/api/bun/ohos_node_userinfo.rs`（660 行，HarmonyOS 沙箱
uid 下给 bun 孵化的 node/npm 子进程修复 os.userInfo()，依赖
ohos-compat-shim 的 getpwuid_r interposition）—— **从未跟过来**
（8 月只 sync 了 test/）。当前设备上该测试必挂。
移植：实现文件 + runtime Cargo.toml 注册 + mod 挂载 + 触发点。
host CI 不受影响（skipIf !isOHOS）。

---

## 6. 挑战

| # | 问题 | 原因 | 解决方案 |
|---|---|---|---|
| 1 | diff3 exit-0 但结果错误 | 重度分歧文件的静默错位拼接 | 合并后必做三向对比（结果 vs ours vs theirs）+ parse 扫描 + 标记保全 |
| 2 | 本地无法跑 JS 测试套件 | 我们的 CI 只有 build+lint，无 host 测试 lane | 恢复的测试靠设备 fulltest 验证；失败项按"单测 quarantine"处理 |
| 3 | hyq fetch 网络超时 | WSL→github.com:443 抖动 | 本地已有 f6aec3047c 的 ref（历史 fetch 所致），fork 分析不依赖最新 |
| 4 | autofix 红但实际成功 | bot 推 commit 后旧 run 被 concurrency 顶掉标 failure | 看 dev 最新 commit 是否为 `[autofix.ci] apply automated fixes` 即可判定 |
| 5 | 08-29 分析结论过时 | "social4hyq 未 merge v1.4.0" 已失效 | 以 git merge-base 实测为准，文档随修复更新 |

---

## 7. 待办

- [ ] 自托管 runner 上线后跑 `ohos/fulltest`：恢复的 ~128 个测试 + 对账文件
- [ ] 失败项按"单测 skipIf/quarantine + 注明原因"处理（**禁止整文件删除**）
- [ ] **移植 `src/runtime/api/bun/ohos_node_userinfo.rs`**（§5.1 新缺口，P2）
- [ ] expectations.txt 持续维护策略成文：上游条目跟随 v1.4.x，OHOS 条目按设备实测增删
- [ ] P3：评估吸收 social4hyq 的 @ohos-ports 社区绑定（canvas/rspack unquarantine 路线）
- [ ] rust-check-all / build-rust / vm-door 等 per-repo 状态文件在我们 src 变更后按需再生成

---

## 8. 术语速查

| 术语 | 含义 |
|---|---|
| deletions==0 判据 | numstat 第二列为 0 = 我们侧零独有行，可无损覆盖为上游版本 |
| diff3 静默错位 | merge-file exit 0 但拼接结果丢失/重复 hunk，重度分歧文件的高发陷阱 |
| 每仓状态文件 | dead-code-limits、rust-check-all 等，内容编码本仓 src 状态，不可跨仓复制 |
| per-case quarantine | 失败的单个用例用 test.skipIf/expectations 单条隔离，而非删整文件 |
| `[autofix.ci] apply automated fixes` | bot 格式提交；判定 autofix 是否成功看 dev 头部是否有此 commit |

---

## 修复时间线

```
2026-08-14/15  测试树被整树替换为 social4hyq pre-1.4.0（91054212c8 + ce76c1855a）
2026-08-28     v1.4.0 合并，test/ 冲突全以 ours 解决 → 14,482 行缺失形成
2026-08-29     social4hyq 自己 merge v1.4.0（391bfb8629），随后持续设备验证
2026-09-01     tri-way 分析量化问题（272 文件 / 14,482 行）
2026-09-02     PR #11 创建 → CI 绿 → 合并（f7916100c5）
2026-09-02     发现 social4hyq 已 merge v1.4.0（391bfb8629）→ 策略改为 3-way 对账
2026-09-02     batch 1（88930e203d）+ batch 2（155132cf5f）推送，PR #12 创建
2026-09-02     autofix 两次格式收敛（725349a852、c19889c8b9）
2026-09-02     按"一 PR 一 commit"新规则 squash 为单 commit 535fb153c7
               （树内容与已验证状态逐字节一致）；快 checks 全绿
2026-09-02     PR 描述与 commit message 中性化（全部 PR body 0 处 fork 名）
2026-09-02     OHOS Build ✅ → PR #12 合并（982fc83613），ohos-aarch64 同步确认
2026-09-02     对账终态实测：test/ vs social4hyq 25 文件双向零缺失（全为有意保留）；
               发现 ohos_node_userinfo.rs 缺口（新 P2）
待办           设备 fulltest + per-case quarantine；移植 ohos_node_userinfo
```

---

*文档日期：2026-09-02 | 分析者/修复：Sisyphus*
*关联：tri-way-diff-analysis-2026-09-02.md、issues/p1-epolloneshot-disabling.md、PR #11/#12*
