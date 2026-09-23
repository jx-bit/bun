# jx-bit rebuild 确认报告（2026-09-10）

## 背景

jx-bit 侧对 `ohos-latest` release 重新生成构建。下载验证后，对官方 v1.4.0 口径
轮 B（`20260910_fulltest_official-v140-jxbit`，247 个失败文件）用新 binary 全量复跑。

## 构建验证

| 项 | 值 |
|---|---|
| 新构建 sha256 | `019a30d554b4a10ee49776df237092096083771aa38747b5b161b266fc8094b1` |
| 上一构建 sha256 | `5356c224a0aa…`（已保留为 `bun-ohos-jxbit-c4323a5d3-r1-signed`） |
| 源码 commit | 两者同为 `c4323a5d3`（分支 HEAD 未变，同 commit 重建） |
| `--revision` | 1.4.0-canary.1+c4323a5d3 |
| **process.platform 实测** | **仍为 `"linux"`**（期望 `"openharmony"`） |

> PR #29（fix: report platform as openharmony）的 merge commit 就是 c4323a5d3，
> 但**两次构建中该修复均未生效**——问题在代码/构建配置层，不是构建时机。

## 复跑结果（247 个轮 B 失败文件 × 新 binary，单次跑，v1.4.0 树同口径）

| 复跑结果 | 数量 | 说明 |
|---|---|---|
| 转 PASS（exit=0） | **2** | `bunshell-instance`、`uv_stub`（偶发类，非修复证据） |
| 仍 FAIL（exit=1） | **236** | 失败集合与轮 B 基本重合 |
| 超时（143） | 9 | 与轮 B 超时分布一致 |
| 崩溃 | 0 | — |

**关键簇复核**：
- `js/sql` 31 文件：全部仍失败（platform="linux" → `isCI && isLinux` docker 检查照旧误触发）
- `cli/run/as-node.test.ts`：仍 `Script not found "node"` ×11（PATH bin 解析缺陷依旧）

## 结论

1. **rebuild 是无差异重建**：247 个失败仅 2 个偶发转 PASS，无实质修复被引入。
2. **两个已知缺陷在 rebuild 后依旧**：
   - `process.platform` 误报 `"linux"`（PR #29 修复未生效——需排查修复代码本身的
     生效条件/编译路径，而非重新触发构建）
   - `bun run` 对 PATH 中的 bin 解析失败（`Script not found "node"`）
3. 对比基线不变：同口径下 social4hyq 1.4.0_80（99.08%）仍优于 jx-bit c4323a5d3（98.63%）。

## 给 jx-bit 维护方的行动清单（更新）

1. **排查 PR #29 修复为何在 c4323a5d3 构建中不生效**（commit 已在 HEAD，但
   `process.platform` 仍 "linux"——检查修复是否改在未被 release 构建使用的代码路径，
   或 Zig/C++ 侧 platform 常量有另一处来源）
2. `bun run` PATH bin 解析（`Script not found`）单独修复
3. 修复落地后 rebuild，可用本报告的复跑方法（247 文件清单 + rerun 脚本）一键验证

## 源码级根因分析：PR #29 为什么没生效

### 调用链事实

`process.platform` 的 JS getter **不在 Rust 层**，而在 C++ JSC 绑定：

```
process.platform (JS)
  → src/jsc/bindings/BunProcess.cpp :: constructPlatform()   ← 真正的 getter
      #if defined(__APPLE__) → "darwin"
      #elif defined(__ANDROID__) → "android"
      #elif defined(__linux__) → "linux"          ← OHOS 构建落到这里
      ...
```

### 两棵树的对照（同一文件同一函数）

**social4hyq `36854e8e`（有效，返回 openharmony）：**
```cpp
static JSValue constructPlatform(VM& vm, JSObject* processObject)
{
#if defined(__APPLE__)
    return ... "darwin"_s);
#elif defined(__OHOS__)                                    // ← 有这个分支
    return JSC::jsString(vm, makeAtomString("openharmony"_s));
#elif defined(__ANDROID__)
    ...
```

**jx-bit `c4323a5d3`（失效，返回 linux）：**
```cpp
static JSValue constructPlatform(VM& vm, JSObject* processObject)
{
#if defined(__APPLE__)
    return ... "darwin"_s);
#elif defined(__ANDROID__)                                 // ← 没有 __OHOS__ 分支
#elif defined(__linux__)
    return ... "linux"_s);                                 // ← OHOS 落到这里
```

### PR #29（ff4f267b）改了什么、漏了什么

ff4f267b 只在 **Rust 侧** `src/bun_core/Global.rs:549` 加了：
```rust
pub const os_name: &str = if cfg!(target_env = "ohos") {
    "openharmony"
} else if cfg!(target_os = "android") { ...
```
但 `Global::os_name` 的全部消费方是 **npm/install 链路**
（`install/lib.rs:844`、`npm.rs:88/123`、`publish_command.rs`、`run_command.rs` ——
npm user-agent、optional-deps 平台匹配），**不喂给 `process.platform`**。

即：PR #29 修好了 npm 侧平台匹配，**漏掉了 C++ 层真正的 `process.platform` getter**。

### `__OHOS__` 宏本身没问题

`__OHOS__` 由 ohos target（`aarch64-unknown-linux-ohos`）编译器预定义，无需 build 脚本注入。
c4323a5d3 树内唯一的 `__OHOS__` 引用在 `BunProcess.cpp:2035`
（spawn `close_range` 的 OHOS 排除，`#if !defined(__OHOS__)`）——说明作者知道这个宏，
只是没在 `constructPlatform` 加分支。

### 同类遗漏检查（实测）

| API | jx-bit c4323a5d3 | social4hyq 1.4.0_80 |
|---|---|---|
| `process.platform` | `"linux"` ❌ | `"openharmony"` ✅ |
| `node:os` `os.platform()` | `"linux"` ❌ | `"openharmony"` ✅ |
| `node:os` `os.type()` | `"Linux"` | `"Linux"`（两边一致，无问题） |

### 修复方案（一行级）

在 jx-bit 树 `src/jsc/bindings/BunProcess.cpp` 的 `constructPlatform()` 补上与
social4hyq 相同的分支（置于 `__ANDROID__` 之前或之后均可，注意 OHOS 与 Android
互斥所以顺序无实际影响，与参考 fork 保持一致即可）：
```cpp
#elif defined(__OHOS__)
    return JSC::jsString(vm, makeAtomString("openharmony"_s));
```
另需检查 `os.platform()` 的实现路径（若独立于 process.platform，同样补 `__OHOS__`）。

## 原始数据

- 复跑日志：`/storage/Users/currentUser/opencode/repro-jxbit-r2/`（247 文件）
- 复跑状态：`/storage/Users/currentUser/opencode/repro-status.txt`
- binary 副本：`bun-ohos-jxbit-c4323a5d3-r1-signed`（上一构建）、`bun-ohos-jxbit-signed`（本次 rebuild）
