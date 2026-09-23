# P1: process.platform / os.platform JS 可见值仍报 "linux"（C++ getter + bundle 内联漏修）— 工作记录

> **关联 PR**：[#30](https://github.com/jx-bit/bun/pull/30)（claude 分支 → ohos-aarch64，单 commit `0c32a69fd8`）
> **状态**：✅ 合并（2026-09-10，merge commit `62960fd817`）
> **定位**：[pr29](pr29-p1-process-platform-openharmony.md) 的后续 —— #29 只修了
> npm/install 链路（Rust `Global::os_name`），JS 可见的 `process.platform` /
> `os.platform()` 在 rebuild 复跑中仍为 "linux"
> （根因确认：[../knowledge/confirm-jxbit-rebuild-20260910.md](../knowledge/confirm-jxbit-rebuild-20260910.md)）。

## 1. 现象

rebuild（同 commit c4323a5d3 重建）复跑实测：

| API | 我们的 binary | 期望 |
|---|---|---|
| `process.platform` | `"linux"` ❌ | `"openharmony"` |
| `os.platform()` | `"linux"` ❌ | `"openharmony"` |
| `os.type()` | `"Linux"` | `"Linux"`（一致，无问题） |

247 文件复跑仅 2 个偶发转 PASS —— **PR #29 的修复没有到达 JS 可见层**。

## 2. 机制：JS 可见平台值有三处来源，#29 修复的是其中与 JS 无关的一处

| 来源 | 消费方 | #29 后状态 |
|---|---|---|
| Rust `Global::os_name`（`src/bun_core/Global.rs`） | npm user-agent、optional-deps 平台匹配 | ✅ 已修（#29） |
| C++ `BunProcess.cpp :: constructPlatform()`（L203） | 运行时 `process.platform`（用户代码） | ❌ 缺 `__OHOS__` 分支，落入 `__linux__` 返回 `"linux"` |
| bundle 期 `--define process.platform=<TARGET_PLATFORM>` | builtins（`src/js/**`）经 DCE 后的字面量 | ❌ `codegenTarget()`（scripts/build/codegen.ts）把 ohos 映射成 `"linux"` |

三个承重事实：

1. **OHOS triple（`aarch64-unknown-linux-ohos`）同时定义 `__OHOS__` 与
   `__linux__`** —— C++ `#elif` 分支顺序是承重的，`__OHOS__` 必须在
   `__linux__` 之前。c4323a5d3 树内唯一的 `__OHOS__` 引用在 spawn `close_range`
   排除处（`BunProcess.cpp:2035` 一带）——说明作者知道该宏，只是没用在 getter 上。
2. **`os.platform()` 是 bundle 期字面量，运行时永远修不了**：`src/js/node/os.ts`
   的 `platform: function() { return process.platform; }` 经 `--define` + DCE 变成
   `return "linux"`。只修 C++ getter 对它无效；必须在构建系统层把
   `TARGET_PLATFORM` 翻成 `openharmony`。
3. **`os.type()` 是硬前提**：内联值翻转成 `"openharmony"` 后，`type()` 三元链被
   DCE 折叠到 `$bundleError("TODO: type")` 残留 → 真实 codegen 抛
   `Errors in node/os.ts: "TODO: type"`，**OHOS 构建直接失败**。不同步补
   `type()` 映射，binary 根本出不来（反证组实测复现）。

## 3. 与 social4hyq 实现的对比（逐字核验）

### 3.1 结论先行

他们的 fork **有** C++ getter 的 OHOS 分支，我们**没有**——JS 可见层漏修是两家
fork 的真实功能差异（与 pr29 的 Global.rs 对比结论同性质）。我们的修复 = **移植
他们的补丁 + 补齐构建系统层的连带前提**，getter 代码与他们的版本逐字一致。

### 3.2 逐项对照

证据类型标注：〔源码〕= 两棵树源码逐字核验（confirm 报告 §源码级根因分析）；
〔实测〕= 双方 binary 行为实测（rebuild 复跑 + 20260910 轮）；〔推断〕= 机制反推。

| 维度 | social4hyq（ohos-aarch64 @ 36854e8e） | 我们（c4323a5d3）→ 本 PR 修后 |
|---|---|---|
| `constructPlatform()` C++ getter | 〔源码〕`#elif defined(__OHOS__)` → `"openharmony"`，置于 `__APPLE__` 后、`__ANDROID__` 前 | 无此分支，落 `__linux__` → 本 PR 补齐，**分支位置与其一致** |
| bundle 期 `TARGET_PLATFORM` | 〔推断〕内联 `"openharmony"`（由其 binary `os.platform()="openharmony"` 反推——该值只可能来自 bundle 期 define，运行时修不了） | `codegenTarget()` 落 `"linux"` → 本 PR 补 `cfg.ohos` 分支 |
| `process.platform` | 〔实测〕`"openharmony"` ✅ | `"linux"` ❌ → 修后 `"openharmony"` |
| `os.platform()` | 〔实测〕`"openharmony"` ✅ | `"linux"` ❌ → 修后 `"openharmony"` |
| `os.type()` | 〔实测〕`"Linux"`（内联 openharmony 后仍 Linux——其 `type()` 链必带 openharmony→Linux 映射，否则他们的构建同样过不了 codegen） | `"Linux"`（内联 linux 直接命中）→ 本 PR 补映射，修后仍 `"Linux"` |
| LUT `OS()` 预处理 | 无源码证据（其 create-hash-table 未见） | 本 PR 归一化 openharmony→LINUX，逐字节验证 |
| `net.ts` 内核语义门控 | 未逐字核验（无其源码片段） | 本 PR 并入 openharmony（errno -104 / abstract socket） |

### 3.3 溯源：为什么他们有、我们没有

- 官方 `bun-v1.4.1` 无任何 OHOS 支持（pr29 §3.3 已证 Global.rs；C++ getter 同理
  ——上游 oven-sh/bun 无 `__OHOS__` 分支）。他们的 constructPlatform 分支是
  **自研 OHOS 补丁**，与 pr29 的 `os_name` 特判同一来源体系。
- c4323a5d3 树内唯一的 `__OHOS__` 引用在 spawn `close_range` 排除处
  （`BunProcess.cpp:2035` 一带，`#if !defined(__OHOS__)`）——作者知道这个宏，
  只是没有用在 platform getter 上。

### 3.4 为什么 20260908 轮分析时没发现、rebuild 后才暴露

- 20260908 轮定位到 `Global::os_name`（npm user-agent 侧实测可变）即提了 #29，
  未做 JS 可见层验证（`bun -e 'console.log(process.platform)'`）——机制上
  Global.rs 与 C++ getter / bundle 内联是三条独立链，修其一不动其二。
- rebuild 复跑的 `process.platform`/`os.platform()` 实测（confirm 报告）直接
  揭穿：**PR 合并 ≠ JS 行为修复**。本 PR 的验证清单据此加入"修复组/反证组"
  真实 codegen 跑通 + 守卫 lint（§6）。

## 4. 修复内容（6 文件，+96/-11）

| 文件 | 修改 | 作用 |
|---|---|---|
| `src/jsc/bindings/BunProcess.cpp` | `constructPlatform()` 在 `__APPLE__` 后、`__linux__` 前加 `#elif defined(__OHOS__)` → `"openharmony"` | 运行时 `process.platform` |
| `scripts/build/codegen.ts` | `codegenTarget()`：`cfg.ohos` → `"openharmony"` | `TARGET_PLATFORM` → builtins 内联，修 `os.platform()` |
| `src/codegen/create-hash-table.ts` | `openharmony` 归一化回 `LINUX` | 同一 env var 也喂 WebKit `OS()` `#if` 预处理；WebKit 无 `OS(OPENHARMONY)`，不归一化会剥掉 LINUX 块、破坏生成的 LUT |
| `src/js/node/os.ts` | `type()` 增加 `openharmony` → `"Linux"` | §2 承重事实 3 的硬前提；`uname -s` 语义 = Linux 内核 |
| `src/js/node/net.ts` | errno 兜底（ECONNRESET=-104）与 abstract-socket `isLinux` 门控并入 `openharmony` | 内联值翻转的连带面：否则 OHOS 构建上 errno 变 -54（macOS 值）、abstract socket 校验被跳过 |
| `test/internal/source-lints/ohos-platform-reporting.test.ts` | 新增守卫 lint（5 用例） | 见 §6 |

设计原则与 #29 一致：**内核级 OS 保持 linux，用户可见字符串 openharmony**。

## 5. 验证

- **修复组**：`TARGET_PLATFORM=openharmony bun src/codegen/bundle-modules.ts` 全量
  跑通；生成的 `os.js` 中 `platform() → return "openharmony"`、`type() → return
  "Linux"`、`@bundleError` 残留 0 处。
- **反证组**：stash 掉 `os.ts` 修改后同参数运行 → codegen 抛
  `Errors in node/os.ts: "TODO: type"` 失败。
- **LUT 归一化**：`TARGET_PLATFORM=linux` vs `=openharmony` 分别运行真实
  `create-hash-table.ts`，对 `BunProcess.cpp`（48 处 `OS()` 守卫）与
  `ZigGlobalObject.lut.txt` 输出逐字节一致；输入中不存在 `OS(OPENHARMONY)` 守卫。
- **回归面**：主机（linux）路径上 `cfg.ohos=false`、`__OHOS__` 未定义、全部
  `openharmony` 分支被 DCE/预处理剔除，行为零变化；`scripts/build` tsc 无新增
  （16 存量不变）；prettier 通过。
- **编译限制**：本机无 host clang ≥21，C++ 分支未本地编译（与相邻分支同构的
  预处理器分支，非 OHOS 平台为死分支），CI 承担。

## 6. 守卫

`test/internal/source-lints/ohos-platform-reporting.test.ts`（与
`ohos-sign-call-sites.test.ts` 同类先例）：钉住 constructPlatform 分支顺序、
codegenTarget 映射、create-hash-table 归一化、os.type() 映射、net.ts 两处内核
语义门控。无修复 0 pass / 5 fail，有修复 5 pass —— 防止上游 merge 再次静默丢弃。

## 7. 生效面与预期

- `process.platform` / `os.platform()` → `"openharmony"`；`os.type()` → `"Linux"`
- pr29 §5 的设备复验预期（23 个门控文件转绿、`bun -e 'console.log(process.platform)'`
  输出 openharmony）**在本 PR 交付后才真正可达**
- `js/sql` 31 文件的 `isCI && isLinux` docker 误判链路解除
- 下轮 fulltest 验收：验收清单 A1-5b 继续挂起至本 PR 合入

## 8. 关联

- 前序：[pr29-p1-process-platform-openharmony.md](pr29-p1-process-platform-openharmony.md)
  （npm 链路层修复，§7 后续小节指向本文档）
- 根因确认与复跑数据：[../knowledge/confirm-jxbit-rebuild-20260910.md](../knowledge/confirm-jxbit-rebuild-20260910.md)
- 机制对照：social4hyq 36854e8e 的 `constructPlatform` 分支（pr29 §3 同源对照法）
- 验收清单：`../analys/next-fulltest-acceptance-checklist.md` A1-5b
