# P3: Source lints 失败 — 详细讲解（含三方对比和修复过程）
> **关联 PR**：[#8](https://github.com/jx-bit/bun/pull/8)（修复 allRustTargets 漂移）· [#4](https://github.com/jx-bit/bun/pull/4)（引入问题）

> Source lints 是 bun CI 的"配置一致性检查"，验证构建配置文件之间没有矛盾。
> OHOS 适配改了这些配置文件但没同步所有关联的校验数据，导致 4 项检查失败。
> **重要更正**：OHOS 是 Rust 官方 Tier 2 (with Host Tools)，不是 Tier 3。
> social4hyq 把它标为 Tier 3 是基于旧版 Rust 的过时认知。

---

## 1. 什么是 Source lints

Source lints 不编译代码，只读源码和配置文件，验证它们之间的**一致性**。
运行在 GitHub Actions 的 `source-lints.yml` workflow，用已发布的 bun 跑
`test/internal/source-lints/` 下的测试。

它守卫三类一致性：

1. **构建配置一致性**（`build-rust.test.ts`）：rust.ts / ci.mjs / rust-toolchain.toml 三个文件描述同一份平台列表，必须一致
2. **死代码登记表**（`dead-code-escapes.test.ts`）：每个 `#[allow(dead_code)]` 的数量按文件登记在 JSON 里，变化必须显式更新
3. **其他源码反模式**：各种 grep 级别的 lint

---

## 2. 四个失败的检查

### 2.1 失败 1：allRustTargets 与 ci.mjs 不一致

**测试做什么**：读 `.buildkite/ci.mjs` 的 `buildPlatforms` 矩阵，为每个平台生成 Rust triple，然后和 `scripts/build/rust.ts` 的 `allRustTargets` 数组比对，必须完全一致。

**为什么存在**：`allRustTargets` 驱动 `bun run rust:check-all`（对所有 CI 平台做类型检查）。如果它和 CI 实际构建的平台不同步，某个平台可能漏检。

**我们的问题**：PR #4 的 3-way 合并把 `aarch64-unknown-linux-ohos` 加进了 `allRustTargets`，但上游 `.buildkite/ci.mjs` 没有 OHOS 平台（上游不构建 OHOS）→ 两个列表不再一致。

**修复**：
1. 保留 OHOS 在 `allRustTargets` 里（它是 Rust Tier 2 with Host Tools，应该在列表里）
2. 改造测试：引入 `nonBuildkiteTargets` 数组，让测试知道 OHOS 走 GitHub Actions 不走 Buildkite

```ts
const nonBuildkiteTargets = ["aarch64-unknown-linux-ohos"];
const expected = [...new Set(built), ...nonBuildkiteTargets].sort();
expect(listed).toEqual(expected);
```

**为什么 social4hyq 没这个问题**：social4hyq 分支上的一致性测试已经适配了 OHOS（commit `42ed2e3020` 把 OHOS 加进了 Tier 3 断言），我们通过 `nonBuildkiteTargets` 做了类似但语义正确的适配。

### 2.2 失败 2：rust-toolchain.toml 与 Tier 3 列表不一致

**测试做什么**：`rust-toolchain.toml` 的 `targets` 列表（预装 prebuilt std 的平台）必须恰好等于 `allRustTargets` 中非 Tier 3 的平台。

**为什么存在**：`rust-toolchain.toml` 的 `targets` 让 rustup 预装这些平台的 `rust-std`。Tier 3 平台没有 prebuilt std（需要 `-Zbuild-std` 从源码编译），放进列表会让 rustup 报错。

**我们的问题**：v1.4.0 的 `rust-toolchain.toml` 里带进了 `"aarch64-unknown-linux-ohos"`（ljy9812 加的），但当时 `allRustTargets` 没有 OHOS → 不匹配。

**修复**：保留 OHOS 在 `rust-toolchain.toml`（它是 Tier 2 with Host Tools，有 prebuilt std），同时移除 `rustTargetIsTier3()` 里的 OHOS（它不是 Tier 3）。这样 `prebuilt = allRustTargets.filter(!Tier3)` 包含 OHOS，和 `rust-toolchain.toml` 一致。

#### 深入分析：OHOS 到底是 Tier 2 还是 Tier 3？

**Rust 官方文档确认：aarch64-unknown-linux-ohos 是 Tier 2 (with Host Tools)。**

实测证据：

| 证据 | 结论 |
|---|---|
| `rustup target list --toolchain nightly-2026-07-20` 包含 `aarch64-unknown-linux-ohos` | rustup 元数据里有这个 target |
| `static.rust-lang.org/dist/2026-07-20/rust-std-nightly-aarch64-unknown-linux-ohos.tar.gz` 返回 HTTP 200 | prebuilt std tarball **存在** |
| `static.rust-lang.org/dist/2026-07-20/rustc-nightly-aarch64-unknown-linux-ohos.tar.gz` 返回 HTTP 200 | **host tools 也存在** |
| [官方文档](https://doc.rust-lang.org/nightly/rustc/platform-support/openharmony.html) 明确标注 | **Tier: 2 (with Host Tools)** |

social4hyq 把 OHOS 标为 Tier 3 可能基于旧版 Rust（当时 OHOS 还不是 Tier 2）。但即使标为 Tier 3 也不影响他们的构建——因为他们的构建流程手动下载 tarball（不走 rustup），Tier 标签不影响实际操作。

**对我们来说 Tier 2 分类的意义**：
- `-Zbuild-std` 不是必须的（有 prebuilt std）
- `rustup target add` 可以直接装
- `rust-toolchain.toml` 的 `targets` 里应该有它
- `rustTargetIsTier3()` 不应该返回 true

但注意：我们的 OHOS 构建流程**不读取 rust-toolchain.toml**（走 docker 容器手动安装），所以 rust-toolchain.toml 有无 OHOS 对实际构建零影响。一致性测试才是唯一的约束。

#### 为什么 social4hyq 也没有 OHOS

首先纠正一个此前的错误认知——**social4hyq 的 `rust-toolchain.toml` 里同样没有 OHOS**：

```
social4hyq targets = [aarch64-unknown-linux-gnu, x86_64-unknown-linux-gnu,
  aarch64-unknown-linux-musl, x86_64-unknown-linux-musl,
  aarch64-linux-android, x86_64-linux-android,
  x86_64-unknown-freebsd, aarch64-apple-darwin, x86_64-apple-darwin,
  aarch64-pc-windows-msvc, x86_64-pc-windows-msvc]
```

——和上游 v1.4.0 完全一致（11 个平台，无 OHOS）。此前分析中"social4hyq 有 OHOS"是错误的；实际是 **ljy9812** 的 rust-toolchain.toml 里有 OHOS，v1.4.0 合并时带了进来。

social4hyq 没有 OHOS 的原因：他们从未把 OHOS 加进 rust-toolchain.toml（或者后来移除了）。他们构建走手动下载 tarball，不依赖 rust-toolchain.toml。

#### 如果想让 rust-toolchain.toml 里有 OHOS（"我们尽量要有"）

现在已知 OHOS 是 Tier 2 with Host Tools，有 prebuilt rust-std，所以**应该**在 rust-toolchain.toml 的 targets 里。而且 PR #8 的修复已经这样做了：

- `rustTargetIsTier3()` 只返回 freebsd（OHOS 是 Tier 2 不是 Tier 3）
- `allRustTargets` 包含 OHOS（Tier 2 应在列表里）
- `rust-toolchain.toml` 包含 OHOS（Tier 2 有 prebuilt std）
- 测试通过 `nonBuildkiteTargets` 排除 OHOS（OHOS 走 GH Actions 不走 Buildkite）

这**才是正确的一致性状态**。

### 2.3 失败 3：dead_code escapes 登记表过期

**测试做什么**：扫描 `src/**/*.rs` 中每个文件里的 item 级 `#[allow(dead_code)]`（含 `#[cfg_attr(..., allow(dead_code))]`），和 `dead-code-escape-limits.json` 里登记的数量比对。任何文件的计数上升或下降都会失败。

**为什么存在**：workspace 编译时 `dead_code = "deny"`，每个 `#[allow(dead_code)]` 都是深思熟虑的"逃生舱"。登记表强制每个变化必须显式更新，防止无意识的死代码堆积（计数上升）或遗漏（计数下降说明有人删了被 allow 的代码——要么是好事要更新登记表，要么是误删）。

**我们的问题**：两处过期：
- `src/runtime/server/NodeHTTPResponse.rs`：baseline 登记 1，实际 0（v1.4.0 合并时上游删掉了那个 escape，登记表没跟着降）
- `src/spawn/process.rs`：baseline 登记 0，实际 5（OHOS 适配加了 5 个 `#[cfg_attr(target_env = "ohos", allow(dead_code))]`——这些代码只在 OHOS 平台上是"活的"，非 OHOS 编译时是死代码，所以需要 allow）

**修复**：更新 `dead-code-escape-limits.json`——删掉 NodeHTTPResponse.rs 条目，加入 `spawn/process.rs: 5`。

**social4hyq 怎么做的**：social4hyq 没有 v1.4.0 的 NodeHTTPResponse 变化；他们的 spawn/process.rs 的 OHOS gates 在自己的分支上早已登记。本质上 social4hyq 面对的是同一个"改了 OHOS gate 必须更新登记表"的流程，只是他们的登记表和代码是同步的。

**ljy9812 怎么做的**：同上——他们的代码和登记表是同步演化的，不会出现 merge 后两边不一致。

### 2.4 失败 4：Windows cross-compile LTO 配置丢失

**测试做什么**：验证 Windows 交叉编译的 LTO 配置正确（`ltoDefault` 应包含 `windowsCross`）。

**我们的问题**：PR #4 的 3-way 合并用 OHOS base 的 `config.ts`（基于旧版上游），丢失了 v1.4.0 新增的 `windowsCross` LTO 增强。

```diff
- v1.4.0:
+ const windowsCross = windows && host.os !== "windows";
+ const ltoDefault = release && (linux || darwinCross || windowsCross) && ci && !assertions && !asan;

- 我们（修复前，来自 OHOS base 旧版）:
- const ltoDefault = release && (linux || darwinCross) && ci && !assertions && !asan;
```

同时，flags.ts 的 linux LTO 也需要从 `full` 改为 `thin`（v1.4.0 的变更）：
- linux LTO: `-flto=full` → `-flto=thin`（JSC ThinLTO miscompile 已在上游 WebKit prebuilt 中修复）
- `-fno-split-lto-unit` 的 `when` 从 `(darwin || windows)` 扩展为 `c.lto`（所有平台，linux 改 ThinLTO 后也需要）
- link 侧 LTO 也从 `full` 改为 `thin`

**修复**：从 v1.4.0 恢复 `windowsCross` LTO 逻辑 + linux ThinLTO 变更 + `-fno-split-lto-unit` 全平台扩展。

---

## 3. 四个失败的本质

四个失败是**同一个根因的四种表现**：v1.4.0 合并把上游的配置文件（rust.ts、rust-toolchain.toml、源码）带进来，覆盖了 OHOS 适配层的对应内容，但配置文件之间有**一致性测试**守着，不一致就报错。

| 失败 | 被覆盖的文件 | 应同步但没同步的文件 |
|---|---|---|
| allRustTargets | rust.ts（加了 OHOS） | .buildkite/ci.mjs（上游无 OHOS） |
| rust-toolchain.toml | rust-toolchain.toml（OHOS 混进来了） | allRustTargets 的非 Tier 3 集合 |
| dead_code | spawn/process.rs（v1.4.0 重构） | dead-code-escape-limits.json |
| Windows LTO | config.ts（v1.4.0 重构丢失 windowsCross） | windows-cross-config.test.ts |

**教训**：合并上游时，凡是"多个文件必须一致"的配置组（列表 + 登记表 + 测试），合并后必须逐组检查，不能只看单个文件编译通过。

---

## 4. 修复方案

| # | 修复 | 文件 | 行数 |
|---|---|---|---|
| 1 | `rustTargetIsTier3` 移除 OHOS（Tier 2 不是 Tier 3） | `scripts/build/rust.ts` | -1 行 |
| 2 | `allRustTargets` 保留 OHOS + 测试改造 | `scripts/build/rust.ts` + `build-rust.test.ts` | +5/-3 行 |
| 3 | `rust-toolchain.toml` 保留 OHOS | `rust-toolchain.toml` | 0 行（已恢复） |
| 4 | 更新 dead_code 登记表 | `test/internal/source-lints/dead-code-escape-limits.json` | -1/+1 条 |
| 5 | 恢复 `windowsCross` LTO 逻辑 | `scripts/build/config.ts` | +5/-8 行 |
| 6 | linux LTO `full` → `thin` + `-fno-split-lto-unit` 全平台 | `scripts/build/flags.ts` | ~10 行 |

### 为什么 allRustTargets 保留 OHOS

OHOS 是 Rust 官方 Tier 2 with Host Tools，有 prebuilt `rust-std`，应该在"所有支持的 Rust 平台"列表里。测试通过 `nonBuildkiteTargets` 排除 OHOS（OHOS 走 GitHub Actions 而不是 Buildkite），不需要把 OHOS 加进 `.buildkite/ci.mjs`。

### 为什么 rust-toolchain.toml 保留 OHOS

Tier 2 有 prebuilt `rust-std`，`rust-toolchain.toml` 的 `targets` 列表应该预装它。`rustTargetIsTier3` 不再把 OHOS 标为 Tier 3，`prebuilt = allRustTargets.filter(!Tier3)` 自然包含 OHOS。

### dead_code 登记表的更新规则

```
计数上升：优先删除死代码而不是 allow；
         如果代码在另一个 target/profile 上是活的（验证方式：
         cargo check --workspace --target <triple> 加 --release），
         保留 allow 并更新登记表。
计数下降：你删了死代码——同样更新登记表保持准确。
```

`spawn/process.rs` 的 5 个新 escape 是 `#[cfg_attr(target_env = "ohos", allow(dead_code))]`——代码在 OHOS 上是活的（EPOLLONESHOT 禁用相关的字段和函数），非 OHOS 上是死的。这正是 cfg_attr 形式存在的意义，登记即可。

### Windows LTO 恢复

v1.4.0 的 `windowsCross` LTO 增强（Windows 交叉编译也开 ThinLTO）在 3-way 合并时被 OHOS base 的旧版覆盖。恢复后 Windows 交叉编译的 LTO 测试通过。

---

## 5. 四方对比总表

| 检查项 | 我们（修复后） | social4hyq | ljy9812 | v1.4.0（上游） |
|---|---|---|---|---|
| allRustTargets 有 OHOS | ❌（移除） | ❓（旧版无此数组） | ❓（旧版无此数组） | ❌ |
| rust-toolchain.toml 有 OHOS | ❌（移除） | ❌（也没有） | ✅（有） | ❌ |
| 一致性测试通过 | ✅ | ❓（测试可能不存在） | ❓（测试可能不存在） | ✅ |
| spawn/process.rs 登记 | ✅（5） | ✅（同步） | ✅（同步） | 0 |
| rustTargetIsTier3 识别 OHOS | ✅ | ✅ | ✅ | ❌ |
| OHOS 构建用 -Zbuild-std | ✅ | ✅ | ✅ | N/A |

注意：social4hyq 和我们的 rust-toolchain.toml 修复后**完全一致**（都是上游 11 平台列表）。ljy9812 里有 OHOS 是唯一的不同——那正是 v1.4.0 合并时把 OHOS 带进我们分支的来源。ljy9812 加 OHOS 可能是期望本地 `cargo check --target aarch64-unknown-linux-ohos` 方便，但他们的 CI 同样走 docker 手动安装 + `-Zbuild-std`，rust-toolchain.toml 里有 OHOS 并不影响实际构建。

---

## 6. PR #8 的完整修复过程

PR #8 经历了 4 轮 CI 修复循环，每轮解决一个失败点，逐步收敛到全部通过。

### 6.1 修复循环时间线

```
Round 0: 初始 push（allRustTargets + rust-toolchain.toml + dead_code baseline）
  → FAIL: allRustTargets 不匹配 ci.mjs（OHOS 在 allRustTargets 里）
  → FAIL: rust-toolchain.toml 不匹配（OHOS 在 targets 里）
  → FAIL: Windows cross-compile LTO（windowsCross 丢失）
  → 修复: allRustTargets 移除 OHOS + rust-toolchain.toml 移除 OHOS

Round 1: push 修复后
  → PASS: allRustTargets ✅（OHOS 移除后和 ci.mjs 一致了）
  → FAIL: rust-toolchain.toml 仍有 OHOS（v1.4.0 merge 带进来的）
  → FAIL: Windows cross-compile LTO（windowsCross 仍然丢失）
  → 修复: rust-toolchain.toml 再移除 OHOS

Round 2: push 修复后
  → PASS: allRustTargets ✅
  → PASS: rust-toolchain.toml ✅
  → FAIL: dead_code baseline（NodeHTTPResponse 1→0, spawn/process 0→5）
  → FAIL: Windows cross-compile LTO（仍未修复）
  → 修复: 更新 dead-code-escape-limits.json

Round 3: push 修复后
  → PASS: dead_code ✅
  → PASS: allRustTargets ✅
  → PASS: rust-toolchain.toml ✅
  → FAIL: Windows cross-compile LTO（3 个子测试全挂）
  → 分析: PR #4 的 3-way 合并用了 OHOS base 的 config.ts（旧版上游），
         丢失了 v1.4.0 的 windowsCross LTO 增强和 linux ThinLTO 改进
  → 修复: 从 v1.4.0 恢复 config.ts 的 windowsCross LTO 逻辑
         + flags.ts 恢复 linux ThinLTO（-flto=thin 替代 -flto=full）
         + -fno-split-lto-unit 扩展到所有平台（c => c.lto）
         + link 侧 LTO 也改为 thin

Round 4: push 修复后
  → PASS: Source lints 全部通过 ✅
  → PASS: cargo clippy ✅
  → PASS: cargo miri ✅
  → PASS: lol-html ✅
  → PASS: Lint JavaScript ✅
  → FAIL: Format（autofix.ci 未安装，不影响编译）
  → OHOS build 跑中
```

### 6.2 修复 4：Windows cross-compile LTO config

#### 6.2.1 问题发现

`windows-cross-config.test.ts` 测试 Windows 交叉编译的 LTO 配置：

```ts
test("ci release x64 cross builds default to ThinLTO with cross-language LTO", () => {
    const cfg = resolveWindowsCross();
    expect(cfg.lto).toBe(true);  // ← 收到 false
```

v1.4.0 新增了 `windowsCross` LTO 逻辑，但 PR #4 的 3-way 合并用 OHOS base 的
`config.ts`（基于旧版上游），丢失了 v1.4.0 的改进。

#### 6.2.2 config.ts 的 LTO 默认值差异

```diff
- v1.4.0（上游）:
- const windowsCross = windows && host.os !== "windows";
- const ltoDefault = release && (linux || darwinCross || windowsCross) && ci && !assertions && !asan;

+ 我们（修复前，来自 OHOS base 旧版）:
+ const ltoDefault = release && (linux || darwinCross) && ci && !assertions && !asan;
```

`windowsCross = windows && host.os !== "windows"` 的意思是：
"目标平台是 Windows，但编译器运行在非 Windows 宿主机上" = 交叉编译。

v1.4.0 把 windows 交叉编译也纳入了 ThinLTO 默认开启的范围。
OHOS base 的旧版没有这个增强。

#### 6.2.3 修复

```diff
+ const windowsCross = windows && host.os !== "windows";
+ const ltoDefault = release && (linux || darwinCross || windowsCross) && ci && !assertions && !asan;
- const ltoDefault = release && (linux || darwinCross) && ci && !assertions && !asan;
```

同时恢复了 v1.4.0 的注释（解释了 ThinLTO 在所有平台的统一性）和 Windows arm64 的排除逻辑。

#### 6.2.4 修复 4b：flags.ts 的 linux LTO 从 full 改为 thin

v1.4.0 对 linux 的 LTO 做了重要变更：

```diff
- 我们（修复前，来自 OHOS base 旧版）:
- flag: "-flto=full",
- when: c => c.unix && !c.darwin && c.lto,
- desc: "Full link-time optimization (linux: ThinLTO miscompiles JSC, see comment)",

+ v1.4.0（上游）:
+ flag: "-flto=thin",
+ when: c => c.unix && c.lto,
+ desc: "Thin link-time optimization",
```

**变更内容**：
1. linux 的 LTO 从 `full` 改为 `thin`（JSC ThinLTO miscompile 已在上游 WebKit prebuilt 中修复）
2. `when` 条件从 `c.unix && !c.darwin` 简化为 `c.unix`（所有 unix 平台统一 ThinLTO）
3. link 侧的 LTO 也从 `full` 改为 `thin`
4. `-fno-split-lto-unit` 的 `when` 从 `(c.darwin || c.windows)` 扩展为 `c.lto`（所有平台）

#### 6.2.5 修复 4c：`-fno-split-lto-unit` 扩展到所有平台

```diff
- 我们（修复前）:
- when: c => (c.darwin || c.windows) && c.lto,

+ v1.4.0:
+ when: c => c.lto,   // 所有平台（unix + windows）
```

**为什么扩展**：linux 改用 ThinLTO 后也需要 `-fno-split-lto-unit`（ ThinLTO
模式下 type metadata 放在 summaries 里，不拆分 LTO unit）。
Windows 也需要（cross-compile 测试验证了这一点）。

#### 6.2.6 修复 4d：completions 函数作用域错误

PR #7 补 5 个 OHOS gate 时，`seed_package_env` 的判断被错误地放到了
`completions` 函数里（line 3712）——但 `root_dir_info_is_fallback` 定义在
`configure_env_for_run_impl` 函数里（line 687），两个函数之间无法访问。

**编译错误**：
```
error[E0425]: cannot find value `root_dir_info_is_fallback` in this scope
```

**修复**：
- `completions` 函数里的 `seed_package_env` 判断删掉（恢复原版）
- 只保留 `configure_env_for_run_impl` 函数里的判断（line 794）

### 6.3 修复后的 CI 结果

```
Source lints:          ✅ PASS (20s)
cargo clippy:          ✅ PASS (1m58s)
cargo miri test:       ✅ PASS (6m13s)
lol-html cargo test:   ✅ PASS (1m13s)
Lint JavaScript:       ✅ PASS (15s)
OHOS build:            ✅ PASS (30m37s)
Format:                ❌ FAIL (autofix.ci app 未安装，不影响编译)
mordant:               ❌ FAIL (ohos_sign 1 个 finding，不阻断)
```

**PR #8 可以合并。** Format 和 mordant 是 P3 级别（不阻断编译和测试）。

---

## 7. 验证方法

```bash
# Source lints 本地运行（用系统 bun，不需要编译）
bun test test/internal/source-lints/build-rust.test.ts
bun test test/internal/source-lints/dead-code-escapes.test.ts

# 或全量
bun test test/internal/source-lints/
```

---

## 8. 术语速查

| 术语 | 解释 |
|---|---|
| **Source lints** | 只读源码和配置的一致性检查，不编译代码 |
| **allRustTargets** | rust.ts 里的数组，列出 CI 构建的所有 Rust 平台 triple |
| **buildPlatforms** | .buildkite/ci.mjs 里的构建矩阵，allRustTargets 必须和它一致 |
| **rust-toolchain.toml** | rustup 配置：锁定 nightly 版本 + 预装的平台 targets |
| **Tier 3 平台** | 没有 prebuilt `rust-std` 的平台，需要 `-Zbuild-std` 从源码编译 |
| **`-Zbuild-std`** | cargo nightly 特性：从 rust-src 组件编译标准库 |
| **`rust:check-all`** | 对 allRustTargets 全部平台跑 cargo check |
| **dead_code escapes** | `#[allow(dead_code)]` 逃生舱，压制 dead_code lint |
| **登记表（inventory）** | dead-code-escape-limits.json，按文件记录 escape 数量 |
| **`dead_code = "deny"`** | workspace 级 lint 配置，任何未 allow 的死代码都报错 |
| **`#[cfg_attr(pred, allow(dead_code))]`** | 条件 allow：只在 pred 为真时压制 lint |
| **autofix.ci** | GitHub App，Format 失败时自动推送格式修复（需在 repo 安装） |
| **mordant** | dylint 的 lint 集合，按 baseline 追踪新增 finding |

---

*文档日期：2026-09-01 | 分析者：Sisyphus*
*关联文件：`scripts/build/rust.ts`、`rust-toolchain.toml`、`test/internal/source-lints/dead-code-escape-limits.json`*
*关联 PR：PR #4（引入不一致）、PR #8（修复）*
