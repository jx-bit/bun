# CI 取证任务书 — 5c0a93130 vs 3c97d0089 两次构建差异调查

> **执行结果**（2026-09-04）：§2/§3 已完成，结论有重大修订 —— 环境零漂移（F1-F6 全一致），
> 根因嫌疑修订为 88a237b0e3 的 spawn 签名校验 O(N) 化（非 libunwind），三个回归重新定性为超时类。
> 详细取证结论已并入本文档附录（含全量 A/B +109% 定量证据与修订后实验清单）。

> **目的**: 解释 3 个确定性回归的引入源 — `websocket-server` 单跑挂死、`websocket.test.js` 大消息失败、`32492` worker-pool 停顿(同设备同测试树 A/B 已证绑定构建: 535 binary 全过, 3c97d0089 全挂)。
> **前置结论**(详细依据见 [`compare-20260903-3c97d0089-vs-early-09260f922.md`](../compare-20260903-3c97d0089-vs-early-09260f922.md) §3.1/§5): 源码 delta 仅 3 个 codesign/CI commit; 嫌疑收敛为 ① libunwind 动态→静态(flags.ts) ② 构建环境三通道漂移(镜像 :latest / brew bottles 不锁版本 / RUST_TOOLCHAIN 外部传入)。
> **执行环境**: 需要 jx-bit/bun 仓库读权限(下载日志 API 匿名返回 403 "Must have admin rights"); 网页端 Actions 页签也可人工核对。

---

## 1. 两次构建的身份对照(已核实)

| 项 | 535 轮 binary | 0903 轮 binary |
|---|---|---|
| 本地文件名 | `bun-ohos-535fb153c7-signed` | `bun-ohos-aarch64-github-signed` |
| `bun --revision` 自报 | `1.4.0-canary.1+5c0a93130` | `1.4.0-canary.1+3c97d0089` |
| revision 含义 | **CI 临时 merge commit**(`refs/pull/12/merge`, 不在分支历史) | 同左(`refs/pull/14/merge`) |
| 触发 PR | **PR#12**(test: reconcile test tree with social4hyq v1.4.0 line) | **PR#14**(fix(ohos): codesign validation + fulltest lane node from default core tap) |
| PR head commit | `535fb153c7eaf46f2197f0b4edf549679e31e98c` | `88a237b0e351bd1f07c0acf334f5b6553504af68` |
| PR merge(进分支) | `982fc8361`(09-02 08:13 UTC) | `443bbb0aa`(09-03 11:56 UTC) |
| **候选 workflow run** | **`33604972459`**(pull_request, 09-02 07:43 UTC, success) | **`33749364624`**(pull_request, 09-03 11:22 UTC, success) |
| run URL | https://github.com/jx-bit/bun/actions/runs/33604972459 | https://github.com/jx-bit/bun/actions/runs/33749364624 |
| job URL | …/job/100166847466("Build Bun for OHOS (aarch64, social4hyq container)") | (jobs 端点同查) |
| binary 传输到设备 | 09-02 19:07 CST(11:07 UTC) | 09-03 20:48 CST(12:48 UTC) |

> PR#14 的 pull_request run(11:22 UTC)与 merge push run(`33752429663` @ 443bbb0aa, 11:56 UTC)都成功; 只有 **pull_request run 的 GITHUB_SHA 是 CI merge commit**, push run 的 GITHUB_SHA = `443bbb0aa`(分支上可见)。binary 自报 3c97d0089 → **0903 出自 pull_request run 33749364624**(推送 run 可用日志 grep revision 排除)。

## 2. 第一步: 确认 run ↔ binary revision 对应关系

方法(任选其一):
1. **网页**: 打开上面两个 run URL → 展开唯一 job "Build Bun for OHOS" → 在构建日志里 `Ctrl+F` 搜 `revision`
   - 构建脚本(`scripts/build/config.ts` L1648)会打印 `  revision  xxxxxxxxxx`(revision 前 10 位)
   - 535 run 应含 `revision 5c0a93130…`; 0903 run 应含 `revision 3c97d0089…`
2. **API**(需登录 token, 只读权限即可):
   ```bash
   # 下载整份日志 zip(匿名 403, 需 token)
   curl -sL -H "Authorization: Bearer <TOKEN>" \
     "https://api.github.com/repos/jx-bit/bun/actions/runs/33604972459/logs" -o logs_535.zip
   unzip -p logs_535.zip | grep -n "revision"
   ```
3. **核对 GITHUB_SHA**: 日志开头 "Set up job" 步骤会 dump `GITHUB_SHA=<40位>` — 应为 `5c0a93130…`/`3c97d0089…` 开头(即 refs/pull/N/merge 的完整 SHA, 顺带留档)

> 若对应关系不成立(日志里 revision 不是预期值) → 停止, 重新按 §5 的 run 清单枚举。

## 3. 第二步: 从两次 run 日志提取构建环境指纹(核心)

在**两份日志**里分别检索以下行, 逐项抄录成对照表:

| # | 日志检索关键词 | 提取内容 | 对应漂移通道 |
|---|---|---|---|
| F1 | `docker pull` / `docker run` / `Image:` / `digest:` | **容器镜像 digest**(ci-runner, 当前 workflow 用 `:latest` 未 pin — workflow L55-56 TODO 自认) | 镜像漂移 |
| F2 | `brew install --only-dependencies` 之后的 pour 列表 | **llvm@21、ohos-sdk、icu4c@78、openssl@3、cmake、ninja 各自的版本号/bottle 构建号**(形如 `llvm@21-21.1.x` 或 `Pouring llvm@21-21.1.x.…bottle`) | bottle 漂移 |
| F3 | `RUST_TOOLCHAIN` / `rustc --version` / `rust-nightly` | **rustc 具体版本**(如 `rustc 1.9x.0-nightly (hash date)`) | Rust 工具链漂移 |
| F4 | `clang --version` / `Android (…)` / `OHOS` clang 版本行 | **clang 实际版本串** | 编译器漂移 |
| F5 | `--webkit=local` 附近的 WebKit checkout 信息 / `vendor/WebKit` commit | **WebKit 源码 commit**(预期两轮相同 — 子模块指针未变, 作为对照组) | 应为零差异 |
| F6 | `icu4c` 数据版本(`ICU 78.x`) | ICU 数据版本 | icu 漂移 |
| F7 | `bun --revision` / `revision`(构建产物自检) | 已在 §2 核对 | 身份 |

**判定矩阵**:

| 结果 | 结论 | 下一步 |
|---|---|---|
| F1-F4 全部一致 | 环境零漂移 → 嫌疑集中在 **libunwind 静态化**(源码内唯一构建行为改动) | §4 实验 A |
| F1 或 F2 任一不同 | **环境漂移坐实** | §4 实验 B(优先) |
| F3 不同 | rustc 漂移坐实 | §4 实验 B |

## 4. 第三步: 变量隔离实验(需构建权限)

复现命令(两台或同台切换 binary 均可, OHOS 设备上):

```bash
B=ohos/test-binaries
export LD_LIBRARY_PATH=$PWD/$B/lib HOME=$PWD/home
export BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1 BUN_GARBAGE_COLLECTOR_LEVEL=0 GITHUB_ACTIONS=false CI=1 NO_COLOR=1

# ① websocket-server(最重的信号: 535=0 fail/21.4s, 3c97d0089=挂死>120s)
timeout 90 $B/bun-ohos-535fb153c7-signed test test/js/bun/websocket/websocket-server.test.ts
timeout 90 $B/bun-ohos-aarch64-github-signed test test/js/bun/websocket/websocket-server.test.ts

# ② 32492 worker-pool 停顿(535=1 pass/69.1s, 3c97d0089=停顿 22.9s)
timeout 60 $B/bun-ohos-535fb153c7-signed test test/regression/issue/32492.test.ts
timeout 60 $B/bun-ohos-aarch64-github-signed test test/regression/issue/32492.test.ts

# ③ websocket 大消息(535=0 fail/8.9s, 3c97d0089=1 fail/14.1s)
timeout 60 $B/bun-ohos-535fb153c7-signed test test/js/web/websocket/websocket.test.js
timeout 60 $B/bun-ohos-aarch64-github-signed test test/js/web/websocket/websocket.test.js
```

| 实验 | 做法 | 判定 |
|---|---|---|
| A: libunwind 假设 | 把 flags.ts 改回 `-lunwind`(动态), 用 0903 同一镜像/bottle 重建 **3c97d0089 源码** → 跑 ①②③ | 三项转绿 → **libunwind 静态化是根因**; 仍挂 → 排除 |
| B: 环境漂移假设 | 用 0903 run 的**同一镜像 digest + 同 bottle 版本**重建 **5c0a93130 源码**(把 flags.ts 改回 `-lunwind` 保持源码一致) → 跑 ①②③ | 三项转红(挂) → **环境/工具链漂移是根因**; 仍绿 → 差异只剩源码 3 commit, 逐个 revert 验证 |
| C: 源码 commit 假设 | 逐个 revert 3 个 commit(codesign×2 / libunwind)重建 | 定位到具体 commit |

## 5. 附: 09-02/09-03 窗口全部 workflow runs 清单(已核实, 供交叉)

| run id | 触发 | head | 时间(UTC) | 结论 |
|---|---|---|---|---|
| 33604972459 | pull_request(PR#12) | dev @ **535fb153c7** | 09-02 07:43 | (待查, 预期 success)← **535 来源** |
| 33607584792 | push | ohos-aarch64 @ 982fc8361 | 09-02 ~08:13 | success |
| 33610127367 | pull_request | dev @ dba1bfe45 | 09-02 08:42 | success |
| 33618027633 | pull_request | dev @ 929c8cf24 | 09-02 10:09 | cancelled |
| 33619517215 | pull_request | dev @ b9bc37a1c | 09-02 10:26 | cancelled |
| 33621730822 | pull_request | dev @ 121865cb7 | 09-02 10:52 | cancelled |
| 33623470337 | pull_request | dev @ f38f7eac0 | 09-02 11:13 | cancelled |
| 33625011127 | pull_request | dev @ ed20069e0 | 09-02 11:31 | **failure** |
| 33742083757 | pull_request | dev @ a9db4b68d | 09-03 10:01 | **failure** |
| 33745602071 | pull_request | dev @ 9e532ac45 | 09-03 10:40 | cancelled |
| 33748104312 | pull_request | dev @ bd59583b3 | 09-03 11:09 | cancelled |
| 33749364624 | pull_request(PR#14) | dev @ **88a237b0e** | 09-03 11:22 | success ← **0903 来源** |
| 33752429663 | push | ohos-aarch64 @ 443bbb0aa | 09-03 11:56 | success |
| 33844615272 | pull_request(PR#15) | dev @ a1b9112d3 | 09-04 06:30 | success |
| 33853168694 | push | ohos-aarch64 @ a346ec192a(PR#15 merge) | 09-04 08:23 | in_progress |

> 排除记录: 0903 binary 传输于 09-03 12:48 UTC, 对应 run 需在此之前完成 — 33752429663 的 GITHUB_SHA=443bbb0aa(分支可见)与 binary 自报 3c97d0089 不符, 排除。

## 6. 已知事实备查(不用重查)

- 源码 delta `982fc8361..443bbb0aa` = 3 commit/8 文件: codesign 校验+spawn 补签升级+compile 写盘 strip&重签+**libunwind 静态化**+CI workflow; **无 websocket/worker-pool/事件循环改动**
- 4 个测试文件(hot/serve-body-leak/websocket.test.js/32492)两树零 diff
- dev 分支 PR#15 增量仅 1 个 test-harness commit(a1b9112d3)
- WebKit = vendor/WebKit 子模块 from-source(`--webkit=local`), 指针未变
- A/B 复现矩阵与逐文件失败用例: `compare-20260903-3c97d0089-vs-early-09260f922.md` §3.1-§3.2
- 535 binary 依赖 `libunwind.so.1`(NEEDED 实测), 0903 binary 仅依赖 `libc.so`(静态化实证)

---

*任务书生成: 2026-09-04 | API 已核验: PR merge_commit_sha ×4、workflow runs ×15 | 日志 zip 下载需登录 token(匿名 403 admin)*


---

# 附录：详细取证结论（原 ci-forensics-5c0a93130-vs-3c97d0089-findings.md，2026-09-11 并入）

# CI 取证结论 — 5c0a93130 vs 3c97d0089（任务书执行结果）

> 对应任务书：[`ci-forensics-5c0a93130-vs-3c97d0089.md`](ci-forensics-5c0a93130-vs-3c97d0089.md)
> 执行日期：2026-09-04。§2/§3 已完成（gh 已登录 jx-bit，日志下载成功）；§4 设备实验未执行（本机无设备），
> 但本地日志/源码取证已将嫌疑从"libunwind 静态化"修订为"**spawn 签名校验 O(N) 化**"，并给出定量证据链。

---

## 结论速览

| 任务书预设 | 取证结果 |
|---|---|
| §2 run ↔ binary 对应 | ✅ **核实通过**（两次 run 日志各打印 `revision 5c0a931300` / `3c97d0089d`，与 binary 自报一致） |
| §3 环境指纹 F1-F6 | ✅ **全部一致**（见 §B 对照表）→ 环境漂移通道**排除**，落判定矩阵第一行 |
| 根因 = libunwind 静态化 | ⚠️ **修订**：对三个确定性回归**无证据支持**；真正的量化根因是任务书 §6 未列入的 **88a237b0e3 spawn 校验改动**（下称 S2） |
| S2 的前因（§C2 新增） | 上游 merge `46557185da`（08-14）**静默丢失** compile 路径 OHOS 签名块 → 0902 轮 72 文件 EACCES → PR#14 用 O(N) spawn 校验补漏 → 引入 S2 |
| websocket-server "挂死>120s" | ❌ 重新定性：**不是死锁**。0903 上该文件单跑 91.5s（全量轮实测），复现命令 `timeout 90` 必然截断 —— 是变慢穿越了复现墙 |
| 三个回归的性质 | **全部是超时类失败**（10s 用例超时 / 4s 测试内看门狗 / 9s build 预算），0 崩溃、0 断言错位 |

---

## A. §2 对应关系核实（任务书步骤一）

| run | 日志 revision 行 | binary 自报 | 判定 |
|---|---|---|---|
| 33604972459 (09-02 07:43 UTC) | `revision 5c0a931300` | `1.4.0-canary.1+5c0a93130` | ✅ |
| 33749364624 (09-03 11:22 UTC) | `revision 3c97d0089d` | `1.4.0-canary.1+3c97d0089` | ✅ |

日志留存：`/tmp/opencode/ci-forensics/logs_535/`、`logs_0903/`（zip 已下载，job "Build Bun for OHOS (aarch64, social4hyq container)"）。

## B. §3 环境指纹对照表（任务书步骤二，判定矩阵输入）

| # | 指纹 | 535 run | 0903 run | 判定 |
|---|---|---|---|---|
| F1 | ci-runner 镜像 digest | `sha256:38e740c8e355…bb56` | 同左（逐字节） | **一致** |
| F2 | bottles | expat-2.8.3 / libedit-20260512-3.1 / libffi-3.8.0 / unzip-6.0_8 / libunistring-1.4.2 / gettext-1.0 / libxcrypt-4.5.2 / util-linux-2.42.2 / musl-compat-1.0.1 / python@3.14-3.14.7_6 / libyaml-0.2.5 / ruby-4.0.6_1 / **node-26.8.1** …（Pouring 列表逐字节相同） | 同左 | **一致** |
| F3 | RUST_TOOLCHAIN | `nightly-2026-07-20`（workflow 锁定） | 同左 | **一致** |
| F4 | clang | `OHOS clang version 21.1.8` | 同左 | **一致** |
| F5 | WebKit | oven-sh/WebKit @ `0f966e81b78c84bb23213e391bc679c4ef83e56b` | 同左 | **一致** |
| F6 | ICU | icu4c@78（sysroot ICU 72.1） | 同左 | **一致** |

**→ 判定矩阵落点：F1-F4 全一致 ⇒ 环境零漂移 ⇒ 嫌疑集中在源码 delta（982fc8361..443bbb0aa）。**

Artifact 交叉验证（0903，GitHub artifact 9891999234 直下）：
- 原始 ELF **110,214,128 bytes（105MB）**，`NEEDED` 仅 `libc.so`（libunwind 静态化实证，与任务书 §6 设备实测一致）
- **无 `.codesign` 段** → 设备端 ohos_selfsign 后才有段 → 运行时每次 spawn 都会走有段分支（见 §C）

---

## C. 核心发现：任务书 §6 的 delta 描述遗漏了一个运行时行为改动（S2）

任务书 §6："源码 delta … **无 websocket/worker-pool/事件循环改动**" —— 就进程内逻辑而言属实，
但 **88a237b0e3 把每次 spawn 的签名检查从 O(1) 改成了 O(文件大小)**：

```diff
  src/spawn_sys/spawn_process.rs（OHOS 专用路径，每次 posix_spawn ELF 都执行）
- if !ohos_sign::has_codesign(&bytes) {          // O(1)：section header 存在性
+ if !ohos_sign::has_valid_codesign(&bytes) {    // O(N)：全文件 merkle 重算
```

`has_valid_codesign`（src/ohos_sign/src/elf.rs）→ `merkle::root_hash_and_tree`：
**每 4KB 页一次 SHA256 + 树构建**。105MB binary ≈ 26,900 次哈希。
`sha256.rs` 是 132 行纯软件实现（无 ARMv8 SHA 扩展）→ aarch64 上 ~100-200MB/s。

**每次 spawn 的净增成本 ≈ 105MB 读 + 105MB 软件 SHA256 ≈ 0.5-1.1s（热缓存）**，且：
1. **无缓存** —— 同一 argv0 每次 spawn 都重算（不按 mtime/size 记忆）；
2. 535 旧代码同路径只做廉价 section 检查 → 有段即跳过，**零哈希**；
3. 全量测试里 install/spawn/repl/shell 家族每个用例都在 spawn bun ⇒ 税收在每个用例上。

## C2. S2 的前因后果（变更史完整因果链）

### 第 0 层：物理约束（不变量）

鸿蒙 PC 内核**拒绝 exec/dlopen 无有效 `.codesign` 段的 ELF**（fs-verity 式
file_size + merkle SHA256 描述符，内核加载时校验"段内描述 == 实际文件"）。
一切设计都源于这一条。

### 第 1 幕：建立（07-07 / 07-27）

| commit | 内容 | 架构决策 |
|---|---|---|
| `87262b15b4` (07-07) | ohos_sign crate 进程内自签（替代外部 binary-sign-tool/objcopy） | 签名能力内建 |
| `a09c4e3714` (07-27) | 4 个 sign-before-use 调用点：**spawn**（`has_codesign` O(1) 门控 → 无段才签）、**dlopen**（EPERM → sign-and-retry 懒模式）、install（.so/.node）、**compile**（payload 注入后 strip+重签） | **写路径负责签名，spawn 只兜底无段文件（零常态成本）** |

### 第 2 幕：静默回归（08-14）—— 真正的根因 commit

**`46557185da`（上游 #38246 "Android: fix --compile executables (PIE load bias)"）**
重构 `StandaloneModuleGraph::inject()` 同一区域时，merge 把 OHOS 签名块
（`#[cfg(target_env="ohos")] { … sign_selfsign_inplace_with_strip }`，位于
`#[cfg(not(windows))]` compile 分支）**冲突解决时丢弃**。

- `git show 46557185da` diff 确凿：删除的正是该 10 行块；535 树全文件 0 处 `ohos_sign` 引用
- **8 月 binary `9d5d706c9`（08-26）树不含此 commit**（非祖先）→ compile 签名仍在
  → 与 20260902 实验铁证吻合（8 月 compile 产物段 hash MATCH ✅ / 535 产物 MISMATCH ❌）
- 静默性：树上无任何测试覆盖"已签名 stub → compile → 产物可执行"，CI 无 OHOS 真机，
  只能等真机全量暴露

### 第 3 幕：全量暴露（0902）→ 修复（09-03 PR#14）

两缺陷叠加，缺一不挂：

```
46557185da 删 compile 重签（缺陷 A）
  + stub 本体被 ohos_selfsign 签名（0902 起设备端流程）
    → compile 产物继承 stub 失效段（file_size 110,221,928 ≠ 实际 112,218,656）
      + has_codesign 只查"段存在"（缺陷 B）→ 短路跳过补签
        → 72 文件（33%）posix_spawn EACCES
```

PR#14 `88a237b0e3` 双修复：
- **方案 B**（compile 路径）：Linux/OHOS 分支补回 strip+重签 —— 恢复第 1 幕不变量 ✅
- **方案 A**（spawn 路径）：`has_codesign` → `has_valid_codesign` —— 把"存在"升级为"有效" ✅ 意图正确，**成本模型未评估**（= S2）

### 第 4 幕：修复代价显现（0903）

`has_valid_codesign` 内部顺序：**先** O(1) `file_size == 实际长度` 检查，**后**全文件 merkle。
于是成本精确地压在**最常见的有效情形**上：

- compile 继承场景（产物变大）→ file_size 不匹配 → O(1) 即判失效，**merkle 根本不用跑**
- bun 本体（有效签名，105MB）→ file_size 匹配 → 走全文件 merkle → **每次 spawn 0.5-1.1s**
- merkle 防的是"同尺寸篡改"—— 威胁模型中不存在的场景（自有 signer + compile 已 strip 重签）

### 三个本可避免的设计选择（根因批评）

1. **昂贵的检查防不存在的威胁**：file_size O(1) 已覆盖实际故障模式；全量 merkle 是纯常态税。
2. **懒模式已有先例未复用**：dlopen 路径从 07-27 起就是 "EPERM → sign-and-retry"；
   spawn 完全可以照搬（先 exec，EACCES 才 validate+strip+重签+重试）→ 快路径零成本。
3. **纵深防御的放置位置**：方案 B（compile strip+重签）单独已让 72 文件复活；
   spawn 校验作为第二道防线，却放在了每 spawn 必经的同步热路径上（父进程 JS 线程、无缓存）。

### 结构性教训

- **上游 merge 触碰 OHOS 私有 hunk 所在区域时缺 checklist** —— `cherry-pick-tracker-v1.4.0.md`
  已有追踪机制，但 merge（非 cherry-pick）路径未覆盖；建议给 `spawn_sys`/`StandaloneModuleGraph`/
  `ohos_sign` 的 OHOS 块建立 upstream-merge 显式核对项。
- **fork 私有行为无回归测试**：`bun build --compile` 产物"段有效性"应有单元测试
  （PR#14 已补 5 个，但都测试 signer 自身；"上游重构不得丢失调用点"需要 CI 侧 grep 守护或集成测试）。
- **性能敏感热路径的修复要带成本论证**：PR#14 若在 commit message 里量化"每 spawn 全文件哈希"，
  当轮即可发现（0903 轮 wall time 翻倍是肉眼可见的信号）。

## D. 定量验证：全量 A/B（同文件同用例数）

解析两轮 result 文件逐文件耗时（1971 个公共文件）：

- **总时长 9164s → 19135s（+9971s，+109%）**，与 wall clock（02:17:23 → 04:27:22）吻合
- 变慢 Top 榜全是 spawn 密集家族，且 **PASS→PASS 用例数不变（纯变慢，无行为差异）**：

| 文件 | 535 | 0903 | Δ | 用例 | Δ/用例 |
|---|---:|---:|---:|---:|---:|
| cli/install/bun-run.test.ts | 39.2s | 293.2s | +254s | 285 | ~0.9s |
| napi/uv_stub.test.ts | 52.3s | 291.8s | +240s | 295 | ~0.8s |
| cli/install/bun-add-catalog.test.ts | 39.0s | 276.1s | +237s | 149 | ~1.6s |
| cli/install/bun-update-lockfile-sync | 34.8s | 250.6s | +216s | 75 | ~2.9s |
| js/bun/import-attributes | 45.9s | 235.9s | +190s | 12 | ~15s(12例多次spawn) |
| js/node/async_hooks/ALS-tracking | 16.9s | 143.1s | +126s | 74 | ~1.7s |

**单位开销 ≈ 0.8-2.9s/spawn，与 105MB 软件 SHA256 merkle 的理论成本吻合。这是 S2 的定量指纹。**

## E. 三个"确定性回归"逐个归因（全部超时类）

### ① 32492 worker-pool 停顿 → 父进程 spawn 串行化

测试结构（test/regression/issue/32492.test.ts）：16 轮 × 24 并发 `Bun.spawn(bunExe() build …)` = **384 次 spawn**，
预算 slowest < 9000ms。每个 spawn 在**父进程**（JS 线程）同步执行 105MB merkle 重算；
24 并发 spawn 串行排队 → 最后启动的 build 光排队就吃了 ~20s。实测 slowest = **22586ms**，首轮即 FAIL。

- 535：同 384 次 spawn，O(1) 检查 → 16 轮全过（文件 53.3s，slowest < 9s）
- 测试名里的 "worker-pool shutdown" 是它守护的上游 bug；本轮观测到的 22.5s
  由 spawn 排队即可解释（10s idle-futex 特征无法从日志单独剥离 → 留 §H 实验 3 验证）

### ② websocket-server "挂死" → spawn 税 × 117 个并发用例的 10s 预算

| 轮 | 结果 | 文件耗时 |
|---|---|---:|
| 535 | PASS +117/-0 | **13.1s** |
| 0903 | FAIL +73/-44 | **91.5s** |

44 个失败**全部**是 `timed out after 10000ms`（readyState/send/sendText/subscribe/publish 矩阵，
`it.concurrent` 并发），时长递减（17.1s→10.8s）是共享资源排队特征；连接与 ping 正常
（日志大量 `Connected ws://…`、`Received ping`）—— **服务端功能正常，是预算被 spawn 税吃光**。
任务书复现命令 `timeout 90`：0903 单跑 91.5s（冷缓存更慢）→ 永远"挂死"。**死锁假说撤案。**

### ③ websocket.test.js 大消息 → 测试自带 4s 看门狗

| 轮 | 结果 | 文件耗时 |
|---|---|---:|
| 535 | PASS +48/-0 | 6.7s |
| 0903 | FAIL +47/-1 | 18.5s |

失败用例自带 `setTimeout(() => ws.close(), 4000)` 看门狗（websocket.test.js L545）：
TLS 握手 + 160KB 回环在变慢的系统上 4s 没完成 → 看门狗 close（此时还在 CONNECTING）
→ `WebSocket is closed before the connection is established`。**功能无回归，是 4s 预算穿越。**

## F. libunwind 静态化的角色重估

- 静态化本身为真（artifact NEEDED 实证），但三回归**无一是崩溃/断言错位/栈回溯类**失败；
- 两轮崩溃均为 0；三回归全部超时类且 S2 已定量覆盖；
- **对 timeout 16 个文件、断言不匹配 62 文件中"真变慢"的子集，同样优先怀疑 S2**（它们与 spawn 无关的才需要单独 triage）；
- libunwind 保留为低优先级对照变量（§H 实验 2 顺带覆盖）。

## G. 对 failure-analysis.md 行动项的影响

| 原行动项 | 修订 |
|---|---|
| P1 dlopen /usr/lib/libc.so（10 文件） | ✅ 已闭环（PR#15 已合并 a346ec192a，真机验证通过，见 issues/p1-dlopen-libc-path-openharmony.md） |
| P1 ex-codesign ~44 文件 triage | **先修 S2 再 triage** —— 其中超时/变慢类（如 serve-body-leak、hot、sleep、terminal 系、16 个 TIMEOUT）大概率是 S2 税收受害文件 |
| P2 断言不匹配 62 文件 | 不变，但注意其中"时序敏感"用例可能只是变慢后踩线 |
| P2 timeout 11 文件超时预算 | 若 S2 修复，部分文件无需加预算 —— **先修后调** |
| 新增 | **S2 修复为最高优先级**（见 §I 方案） |

## H. 修订后的设备实验清单（原任务书 §4 的替代）

1. **S2 单变量确认（最低成本）**：0903 binary 上
   `time bun -e 'for(let i=0;i<5;i++) Bun.spawnSync([Bun.which("bun"),"-e","1"])'`
   对比 535 binary 同命令 → 预期每次 spawn 差 ~0.5-1.1s。
   再 `md5sum` binary 前后对比 → 若变化 = 走了重签分支（校验恒假，比预估更糟）。
2. **A/B 复跑三回归**（任务书 §4 原命令不变），加测 `bun-run.test.ts`、`uv_stub.test.ts` 两个 S2 指纹文件。
3. **32492 分解**（可选）：0903 + 临时短路 `has_valid_codesign`（或按 mtime+size 缓存）重建 →
   32492 转绿即坐实；仍红 = worker-pool 停顿真回归，再按原任务书实验 A 查 libunwind。
4. strace（可选）：`strace -f -e trace=openat,read,execve -c` 跑一次 spawn，确认 105MB 读 + 时间分布。

## I. S2 修复方案（已定案：懒模式 —— 已实施，待真机复测）

判定依据：bun 每次 spawn 的验签与内核 exec 时的验签**完全重复** —— bun 那遍不产生任何
安全增益（内核不信 bun 的结果），只产生 0.5-1.1s/spawn 的税。让内核（本来就必验的一方）
当唯一的裁判，bun 只在内核拒绝时出手。

| 方案 | 做法 | 常态成本 | 状态 |
|---|---|---|---|
| **A. 懒模式（已实施）** | spawn 先直接 `posix_spawn`；返回 EACCES/EPERM 才"读 argv0 → 校验 → strip → 重签 → 重试一次"。与 dlopen 路径已有的 "EPERM → sign-and-retry" 模式同构 | **0**（真坏时一次性付费） | ✅ 2026-09-04 实施 |
| B. 结果缓存 | 按 `(path, mtime, size)` 缓存校验结果 | 首次 O(N)，之后 O(1) | 备选，未采用 |
| C. 写路径全覆盖 | social4hyq 形态：所有文件出生即有效，spawn 零检查（见 findings §J） | 0 | 长期方向；消费版内核强制未解除前不可单独采用 |

实施内容（3 文件，+113/-19）：

- `src/spawn_sys/spawn_process.rs`：删除 eager 校验块；spawn 失败且 errno ∈ {EACCES, EPERM}
  时调 `repair_codesign_if_needed` → 仅当文件确实被改写才重试一次
- `src/ohos_sign/src/lib.rs`：新增 `repair_codesign_if_needed(path) -> bool`
  （非 ELF/读取失败/已有效 → false 不动文件；否则 strip+重签）
- `src/ohos_sign/tests/elf_sign.rs`：4 个新测试（有效文件字节不变 / 无段补签 /
  过期段重签后通过校验 / 非 ELF 与缺文件 no-op）

实施注意（已在实现中遵守）：
- EACCES 也可能来自 seccomp 等非签名原因 → `repair_codesign_if_needed` 对"已有效"的
  文件返回 false → 不重试，**原始错误原样透传**
- 补签失败透传原始错误；重试只做一次，不循环
- compile 路径（PR#14 方案 B）保留不动：产物出生即有效 → 懒模式补签分支几乎不触发

验证状态：
- ✅ `ohos_sign` crate 测试 18/18 通过（含 4 个新测试；独立环境 cargo test + clippy 0 告警 + rustfmt 干净）
- ✅ OHOS cfg 块在 `aarch64-unknown-linux-ohos` target（pinned nightly-2026-07-20）类型检查通过；
  非 OHOS 路径 host target 构建干净（无 unused_mut）
- ⚠️ 本环境 vendor 依赖缺失，无法做完整 workspace 构建；**待设备端复测**：
  32492 / websocket-server / websocket.test.js 三文件 + 全量时长对比（预期回落到 ~2h 量级）

### I.2 残余优化清单（2026-09-04 评审）

P0（正确性，已随本次实施修复）：
- ✅ `repair_codesign_if_needed` 补回 regular-file 守卫（旧代码有、初版实施漏掉）——
  spawn argv0 为字符设备（如 /dev/zero）时 exec 报 EACCES 落入修复路径，
  `fs::read` 对 char device 永不到 EOF → 挂死/OOM。测试 `repair_skips_non_regular_files` 锁定。

P1（同类病灶的其余两处调用点）：
1. ✅ **dlopen**（`sys/lib.rs`）：已改懒模式 —— 先 dlopen，被拒后 `repair_codesign_if_needed`
   → 文件被改写才重试一次。修掉两个旧缺陷：每次 dlopen 全文件读（O(N) 税）+
   presence-only 检查让过期段直达内核拒绝且无恢复。Bun__dlopen 的文档注释
   （"sign and retry"）从此与实现一致。social4hyq 同模式仍在（其环境未踩到）。
2. ✅ **install**（`PackageInstaller.rs`）：`has_codesign + sign_selfsign_inplace` 对
   换为 `repair_codesign_if_needed`（获得过期段修复：patched native module 场景）。

P2（失败路径效率，rare path，性价比一般，未实施）：
3. repair 双读：`fs::read` 后 inplace sign 内部再读一次 —— 105MB 读两遍；
   可读一次后走内存内 `sign_selfsign_with_strip` + 写回。
4. O(1) pread 预检：描述符 file_size 两次小 pread 即可比对，尺寸不符场景免全文件读。
5. sha256 硬件加速（ARMv8 SHA2 intrinsics，当前纯软件）：懒模式后仅失败路径 +
   compile 重签（一次 ~1s）用哈希，实测 compile UX 受影响再做。

P3（加固 / 可观测）：
6. ✅ **防 46557185da 复发的 lint 守卫**：`test/internal/source-lints/ohos-sign-call-sites.test.ts`
   断言 4 个调用点（compile/spawn/dlopen/install）存在 —— 上游 merge 再丢 hunk 时 CI 直接红，
   失败信息内含恢复指引。走 source-lints workflow（`src/**/*.rs` paths 触发，无需改 workflow）。
7. ✅ **修复事件可观测**：三个调用点在 repair 成功时打 scoped log（scope `OhosSignRepair`，
   hidden）—— 设备端 `BUN_DEBUG_OhosSignRepair=1 bun test ...` 可见；默认零输出。
8. ⬜ 设备端 md5sum 核查（§H 实验 1）：确认设备自签 binary 不触发重写循环（signer 版本偏差 paranoia）。

不推荐动：静态 libunwind 改回随包分发（无致害证据）；重试扩展到其他 errno（无实证）。

不推荐动：静态 libunwind 改回随包分发（无致害证据）；重试扩展到其他 errno（无实证）。

## J. 与 social4hyq 实现的对比（hyq/ohos-aarch64 @ f6aec3047c）

| 维度 | 我们（jx-bit/dev @ a346ec192a） | social4hyq | 影响 |
|---|---|---|---|
| 签名调用点 | spawn（O(N) 校验）+ compile（strip 重签）+ install（O(1)）+ dlopen（O(1)） | **compile（写入完成时 strip 重签，`build_command.rs:1030` / `js_bundle_completion_task.rs:469`）+ install + dlopen（O(1)）**；**spawn 无任何签名逻辑** | 他们把"写路径负责"贯彻到底，读路径零成本，从未有 spawn 税 |
| compile 签名历史 | a09c 加入 → **46557185da 丢失** → PR#14 找回 | 一直在（树分叉早，未踩上游 merge） | 我们多付了一轮 72 文件 EACCES + 一轮全量翻倍 |
| 内核强制程度 | 消费版鸿蒙 PC **强制**（0902 72 文件 EACCES 实证；无段文件 spawn 必挂） | 环境为 Harmonybrew/OpenHarmony 体系，**文档对签名零讨论**，runner 直接 node spawn —— 未见强制表现（或预签名全覆盖） | 他们的"无 spawn 兜底"架构成立依赖宽松内核；**在消费版设备上不能照搬删除 spawn 兜底**，应改懒模式 |
| libunwind | **静态** `-l:libunwind.a`（因设备/CI 镜像无 libunwind.so.1） | **动态** `-lunwind`，链接自家交叉编译产物（`ohosCrossLibs/libunwind`），随包分发 .so（测试时 `LD_LIBRARY_PATH=$B/lib`） | 他们选择"带库"，我们选择"嵌库"—— 静态化本身无证据致害（§F） |
| harness libc dlopen | PR#15：显式 `/system/lib/ld-musl-aarch64.so.1` | 裸名 `"libc.so"`（其 /usr/lib 布局有效） | 消费版设备裸名命中损坏路径 → 已修，见 p1-dlopen 文档 |
| 测试方法论 | 1988 文件，PARALLEL=2，单遍 | 4751 文件，20 核 node runner，**三阶段复核**（全量→低并发复测剔除并发假象→隔离单跑） | 他们明确记载 **32492 并发下失败、完全隔离单跑 100% 通过** —— 独立佐证我们的"负载类失败"定性 |

**结论**：social4hyq 的签名架构（写路径全责、读路径零校验）即本报告 §I 修复方案的目标形态；
差异在于内核强制程度 —— 我们必须在消费版设备上保留 spawn 兜底，但应改为 **EACCES 触发的懒模式**
（对齐 dlopen 路径已有的 retry 模式），常态成本归零。

---

*取证执行：Sisyphus | 2026-09-04*
*证据物：/tmp/opencode/ci-forensics/{logs_535,logs_0903,report_535,artifact_0903.zip,compare.py}（本地，未入库）*
*交叉引用：failure-analysis.md（20260903 轮）、ci-forensics-5c0a93130-vs-3c97d0089.md（任务书）、
issues/p1-dlopen-libc-path-openharmony.md（P1 已闭环）*
