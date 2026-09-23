# 三方差异详细分析（更新版）— 2026-09-01

> dev = jx-bit/bun:dev（merge v1.4.0 + 方案B 全量导出 + __n1 libcxx 自编译 + 全部 OHOS gate 补齐后）
> v1.4.0 = oven-sh/bun:bun-v1.4.0
> social4hyq = social4hyq/ohos-bun:ohos-aarch64
> ljy9812 = ljy9812/bun:ohos-aarch64（OHOS 适配原始仓库，未 merge v1.4.0）
>
> **49 个 src/ 差异文件，全部同时与 v1.4.0 和 social4hyq 不同。**
> Highway 3 文件已对齐上游（PR #5），从差异列表中消失。

---

## 0. 总览

### 与前版（2026-08-28）相比的变化

| 变化 | 文件数 | 说明 |
|---|---:|---|
| Highway 3 文件对齐上游 | -3 | PR #5 移除了 SVE 禁用 |
| symbols.dyn 恢复全量 | 0→1 | PR #4 方案B，仍在差异列表（但方向对了） |
| run_command.rs | +1 | 3-way 合并后 v1.4.0 重构 + OHOS gate |
| StandaloneModuleGraph.rs | +1 | 3-way 合并后 v1.4.0 标准版 + OHOS PIE |
| **总计** | **49** | 从 53 → 49（Highway 3 个消失，其余不变） |

### 重要更正：OHOS 是 Rust Tier 2 (with Host Tools)，不是 Tier 3

Rust 官方文档 [platform-support/openharmony.html](https://doc.rust-lang.org/nightly/rustc/platform-support/openharmony.html) 明确标注：

> **aarch64-unknown-linux-ohos: Tier: 2 (with Host Tools)**

这意味着：
- ✅ 有 prebuilt `rust-std`（rustup target add 可以直接装）
- ✅ 有 prebuilt `rustc`/`cargo` host tools
- ✅ `rust-toolchain.toml` 的 `targets` 里**应该**有它
- ❌ `rustTargetIsTier3()` 返回 true 是**错误的**

social4hyq 把 OHOS 标为 Tier 3 可能基于旧版 Rust（当时 OHOS 还不是 Tier 2）。我们的构建流程走 docker 容器手动下载 tarball（不走 rustup），所以 Tier 标签不影响实际构建，但影响一致性测试。

**我们的修复（PR #8）已经修正了这个分类**：
- `rustTargetIsTier3()` 只返回 freebsd（OHOS 不再误标为 Tier 3）
- `allRustTargets` 包含 OHOS（Tier 2 应在列表里）
- `rust-toolchain.toml` 包含 OHOS（Tier 2 有 prebuilt std）
- 测试通过 `nonBuildkiteTargets` 排除 OHOS（OHOS 走 GH Actions 不走 Buildkite）

### 四方对比总表

| 分组 | 文件数 | 我们的做法 | social4hyq | ljy9812 |
|---|---:|---|---|---|
| Highway SIMD | 3 | 禁用 SVE + BUN_BFM polyfill | 不禁用 + highway_dispatch.h | 和我们相同 |
| 链接器脚本 | 2 | 裁剪 symbols.dyn(6行) + 8 shim 符号 | 全量(667行) + 更多 shim 符号 | 和我们相同 |
| flags.ts 链接块 | 1(非src/) | `--version-script=symbols.dyn` | `--dynamic-list + --version-script=linker.lds` | 和我们相同 |
| EPOLLONESHOT | 1 | 禁用(2 处 gate) | 不禁用(1 处注释) | 和我们相同 |
| Install 回退 | 9 | copy_file_fallback + EPERM + IgnoreFailure | 无此回退 | 和我们相同 |
| Spawn 签名 | 4 | spawn 时签 ELF + --code-sign rustflag | --code-sign rustflag | spawn 时签 ELF |
| ohos_sign | 13 | 完整 crate | 有 ohos_sign | 和我们相同 |
| sys cfg gates | 5 | `target_env="ohos"` 加入多处 cfg | 不加 ohos cfg | 和我们相同 |
| run_command.rs | 1 | v1.4.0 重构 + ohos_set_pwd(2 gate) | 7 个 cfg gate(更多) | OHOS base 版(3 gate) |
| StandaloneModuleGraph | 1 | v1.4.0 标准版 + OHOS PIE(17 gate) | 4 个 cfg gate(更少) | OHOS base 版(23 gate) |
| 其他 | 13 | 各种 cfg gates | 需逐个对比 | 和我们相同 |

---

## 1. Highway SIMD（3 文件）— 32 用例回归的根因

### 涉及文件
- `src/jsc/bindings/highway_sourcemap.cpp`（5 OHOS 标记，13 行 diff）
- `src/jsc/bindings/highway_json.cpp`（2 OHOS 标记，7 行 diff）
- `src/jsc/bindings/highway_xml.cpp`（13 OHOS 标记，47 行 diff）

### 我们的做法

**highway_sourcemap.cpp**：
```cpp
// 禁用所有 SVE 后端，只保留 NEON
#if defined(__aarch64__)
#define HWY_DISABLED_TARGETS (HWY_ALL_SVE)
#endif

// ToBits 函数新增 SVE 分支（用 StoreMaskBits 代替 BitsFromMask）
#elif HWY_TARGET == HWY_SVE || HWY_TARGET == HWY_SVE2
    uint8_t bits[8] = {};
    hn::StoreMaskBits(d, m, bits);
    return *reinterpret_cast<uint64_t*>(bits);
```

**highway_json.cpp**：同样的 `HWY_DISABLED_TARGETS (HWY_ALL_SVE)`

**highway_xml.cpp**：`BUN_BFM` polyfill（CompressStore + Iota 模拟 BitsFromMask）

### social4hyq 的做法

- **不做任何 SVE 干预**：无 `HWY_DISABLED_TARGETS`，无 `BUN_BFM`，无 `ToBits` SVE 分支
- **直接 `hn::BitsFromMask`**：信任 Highway 原生行为
- **有 `highway_dispatch.h`**：缓存 dispatch 结果（我们也有，来自 v1.4.0 merge）
- social4hyq 的 Highway 版本/编译器配置可能不编译 scalable SVE 目标

### ljy9812 的做法

和我们**完全相同** — 同样有 `HWY_DISABLED_TARGETS`、`BUN_BFM`、`ToBits` SVE 分支。
这些 OHOS 修改源自 ljy9812。

### 差异分析

| | 我们/ljy9812 | social4hyq |
|---|---|---|
| SVE 处理 | 禁用 (`HWY_DISABLED_TARGETS`) | 不禁用 |
| BitsFromMask 缺失 | polyfill + StoreMaskBits | 不处理（信任 Highway） |
| highway_dispatch.h | ✅ 有（v1.4.0 带来） | ✅ 有 |
| 风险 | EMU128 后端可能产生不一致结果 | 可能编译失败（如果 SVE 被编译） |

**回归影响**：sourcemap-simd(24 用例) + console-iterator(8 用例) = 32 用例失败。
根因：`HWY_DISABLED_TARGETS` 保留了 EMU128 后端，dispatch 可能选 EMU128 而非 NEON。

---

## 2. 链接器脚本（2 文件）— Linux CI 构建阻断

### 涉及文件
- `src/symbols.dyn`（669 行 diff，0 OHOS 标记）
- `src/linker.lds`（17 行 diff，3 OHOS 标记）

### 我们的做法

**symbols.dyn** = 6 行（OHOS 裁剪版）：
```
{
    global:
        Bun__dlopen;
    local:
        *;
};
```

**linker.lds** = 有 8 个 OHOS shim 符号（syscall, close_range, getcwd, getpwuid_r, tmpfile, linkat, symlinkat, splice）

### social4hyq 的做法

**symbols.dyn** = 667 行（完整 dynamic-list，和 v1.4.0 一样）

**linker.lds** = 有更多 OHOS shim 符号（5 个 grep 匹配，但实际更多 — 含 close/epoll_ctl/epoll_wait/epoll_pwait 簇）

### ljy9812 的做法

和我们**相同** — 6 行 symbols.dyn + 8 个 shim 符号。

### 差异分析

| | 我们/ljy9812 | social4hyq |
|---|---|---|
| symbols.dyn | 6 行（裁剪到 Bun__dlopen） | 667 行（全量 v8/napi/uv） |
| 动机 | 规避设备 v8 `__1` vs `__n1` 崩溃 | 自编译 `__n1` libcxx，ABI 匹配 |
| Linux 影响 | `--dynamic-list` 报错（`local:` 不支持） | 无影响（和 Linux 一样） |
| napi/uv 导出 | ❌ 不导出 | ✅ 全量导出 |
| shim 符号数 | 8 个 | ~18 个（含 epoll 簇） |

---

## 3. EPOLLONESHOT（1 文件）— spawn 回归根因

### 涉及文件
- `src/io/posix_event_loop.rs`（13 行 diff，3 OHOS 标记）

### 我们的做法

```rust
// 禁用 EPOLLONESHOT：HongMeng 内核不解除 one-shot 兴趣
#[cfg(target_env = "ohos")]
let one_shot = false;  // 强制 level-triggered
```

2 处 `cfg(target_env = "ohos")` gate。

### social4hyq 的做法

**不禁用 EPOLLONESHOT**。代码中只有 1 处关于 EPOLLONESHOT 的注释
（说明 bidirectional one-shot 不支持），保持标准行为。

### ljy9812 的做法

和我们相同 — 同样禁用 EPOLLONESHOT。

### 差异分析

| | 我们/ljy9812 | social4hyq |
|---|---|---|
| EPOLLONESHOT | 禁用 | 不禁用 |
| 原因 | HongMeng 1.12 内核不解除 one-shot | 不认为这是问题 |
| 回归影响 | spawn-stdin(1) + 26286(超时) | 无 |

---

## 4. Install 回退（9 文件）— OHOS SELinux 适配

### 涉及文件
- `src/install/PackageInstall.rs`（116 行，4 OHOS 标记）
- `src/install/isolated_install/Hardlinker.rs`（50 行，3 OHOS 标记）
- `src/install/isolated_install/Symlinker.rs`（17 行，2 OHOS 标记）— **我们修复了类型不匹配**
- `src/install/lib.rs`（31 行，2 OHOS 标记）— `copy_file_fallback()` 函数
- `src/install/PackageInstaller.rs`（50 行，8 OHOS 标记）
- `src/install/PackageManager.rs`（25 行，6 OHOS 标记）
- `src/install/PackageManager/PackageManagerLifecycle.rs`（24 行，7 OHOS 标记）
- `src/install/bin.rs`（5 行，1 OHOS 标记）
- `src/install/lifecycle_script_runner.rs`（11 行，2 OHOS 标记）

### 我们的做法

- `copy_file_fallback()` — linkat/symlinkat EPERM/EACCES 时回退到文件拷贝
- Hardlinker 的 EPERM/EACCES fallback
- Symlinker 的 `Strategy::IgnoreFailure`（**修复后**：`Ok(true)`/`Ok(false)` 而非 `Ok(())`）
- lifecycle_script_runner 的 getcwd→HOME fallback

### social4hyq 的做法

social4hyq 的 `Symlinker.rs` **没有** `Strategy::IgnoreFailure`（grep = 0）。
social4hyq 的 `install/lib.rs` **没有** `copy_file_fallback`。
这些回退可能是 ljy9812 独有的，或者 social4hyq 用不同方式处理了 SELinux。

### ljy9812 的做法

和我们相同 — 同样有这些回退（但 ljy9812 的 `Symlinker.rs` 还没有我们的类型修复）。

### 差异分析

| | 我们/ljy9812 | social4hyq |
|---|---|---|
| copy_file_fallback | ✅ 有 | ❌ 无 |
| Strategy::IgnoreFailure | ✅ 有（**我们修复了类型**） | ❌ 无 |
| EPERM 回退 | ✅ 有 | ❌ 无 |
| 类型修复 | ✅ `Ok(true)`/`Ok(false)` | 不适用（没有这个代码） |

---

## 5. Spawn 签名 + --code-sign rustflag（4 文件）

### 涉及文件
- `src/spawn/process.rs`（59 行，16 OHOS 标记）
- `src/spawn_sys/spawn_process.rs`（17 行，4 OHOS 标记）— spawn 时 ELF 签名
- `src/jsc/bindings/bun-spawn.cpp`（195 行，18 OHOS 标记）
- `src/runtime/api/bun/spawn/stdio.rs`（9 行，4 OHOS 标记）

### 我们的做法（3-way 合并后）

- **v1.4.0 的 `--code-sign` rustflag**（从 social4hyq 引入）— 链接时签名
- **OHOS base 的 spawn 时签名**（`spawn_process.rs` 里 `#[cfg(target_env = "ohos")]` 检测 ELF 并签名）
- 两种签名方式**并存**

### social4hyq 的做法

- 有 `--code-sign` rustflag（2 处 grep 匹配）
- 有 `OHOS_BUN_SIGNING_LINKER` 环境变量（自定义签名链接器路径）
- 有 ohos triple（4 处 grep 匹配，比我们多 1 处 — 可能在 `rustTriple` 函数里用了不同写法）
- 不确定是否有 spawn 时签名（需进一步检查）

### ljy9812 的做法

- 有 spawn 时签名（`spawn_process.rs` 里的 `#[cfg(target_env = "ohos")]` 块）
- **没有** `--code-sign` rustflag（ljy9812 的 `rust.ts` 没有 OHOS triple 和签名）
- 只有 spawn 时签名这一种方式

### 差异分析

| | 我们 | social4hyq | ljy9812 |
|---|---|---|---|
| `--code-sign` rustflag | ✅（v1.4.0/social4hyq） | ✅ | ❌ |
| spawn 时签名 | ✅（OHOS base） | ❓ 需确认 | ✅ |
| OHOS triple in rust.ts | ✅（3 处） | ✅（4 处） | ❌ |
| Tier 3 分类 | ✅ | ✅ | ❌ |

---

## 6. ohos_sign（13 文件）

### 涉及文件
- `src/ohos_sign/Cargo.toml` + `src/ohos_sign/src/{elf,descriptor,merkle,sha256,lib}.rs` + `ohos_selfsign.rs` + 4 个 test 文件

### 三方对比

- **我们**：有完整 ohos_sign crate（从 OHOS base 保留）
- **social4hyq**：也有 ohos_sign（HTTP 200 确认存在）
- **ljy9812**：有完整 ohos_sign（原始来源）

### Cargo.lock 差异

| | 我们 | social4hyq | ljy9812 |
|---|---|---|---|
| Cargo.toml 有 ohos_sign | ✅ | ✅ | ✅ |
| Cargo.lock 有 ohos_sign | ✅ 6 处（我们手动修复） | ✅（cargo 自动生成） | ❌ 0 处（有 bug！） |

**ljy9812 也有 Cargo.lock 缺失 bug**，但因为没 merge v1.4.0，`rust.ts` 没有 `--locked` →
bug 没被触发。我们 merge v1.4.0 带来了 `--locked` → 触发了 bug → 我们修复了。

---

## 7. sys cfg gates（5 文件）

### 涉及文件
- `src/sys/lib.rs`（94 行，16 OHOS 标记）
- `src/sys/Error.rs`（17 行，0 OHOS 标记）
- `src/sys/linux_syscall.rs`（9 行，3 OHOS 标记）
- `src/sys/Cargo.toml`（3 行，2 OHOS 标记）
- `src/sys_jsc/signal_code_jsc.rs`（11 行，3 OHOS 标记）

### 我们的做法

```rust
// dev 有 OHOS gate
#[cfg(any(target_env = "musl", target_env = "ohos", target_os = "android"))]
// v1.4.0 没有 OHOS
#[cfg(any(target_env = "musl", target_os = "android"))]
```

在多处 cfg gate 中添加 `target_env = "ohos"`，让 OHOS 走和 musl/android 相同的路径。

### social4hyq 的做法

social4hyq 的 `sys/lib.rs` 没有 `target_env = "ohos"` 出现在 cfg gates 中。
可能 social4hyq 用 `target_os = "android"` 覆盖 OHOS，或者 OHOS 的 sys 行为
和 musl 一致不需要单独 gate。

### ljy9812 的做法

和我们相同 — 同样有 `target_env = "ohos"` cfg gates。

---

## 8. run_command.rs（1 文件）— 3-way 合并后的新状态

### 涉及文件
- `src/runtime/cli/run_command.rs`（15 行，5 OHOS 标记）

### 我们的做法（3-way 合并后）

以 **v1.4.0 重构版**为基础（保留 `ConfigureEnvOptions` struct），加回：
- `ohos_set_pwd()` 函数（10 行）
- `#[cfg(target_env = "ohos")] ohos_set_pwd(env, cwd)` 调用点（3 行）
- 总共 **2 处** cfg gate

### social4hyq 的做法

- **没有** `ohos_set_pwd`（grep = 0）
- 有 **7 处** `cfg(target_env = "ohos")` gate（比我们多 5 处）
- social4hyq 可能用不同方式处理了 hmdfs getcwd 问题

### ljy9812 的做法

- 有 `ohos_set_pwd`（和我们相同）
- 有 **3 处** cfg gate（OHOS base 版本，没有 v1.4.0 的 `ConfigureEnvOptions` 重构）

### 差异分析

| | 我们（3-way 合并后） | social4hyq | ljy9812 |
|---|---|---|---|
| 基础版本 | v1.4.0（`ConfigureEnvOptions`） | — | OHOS base |
| ohos_set_pwd | ✅ 有 | ❌ 无 | ✅ 有 |
| cfg gate 数 | 2 | 7 | 3 |
| v1.4.0 改进 | ✅ 保留 | — | ❌ 没有 |

---

## 9. StandaloneModuleGraph.rs（1 文件）— 3-way 合并后的新状态

### 涉及文件
- `src/standalone_graph/StandaloneModuleGraph.rs`（160 行，21 OHOS 标记）

### 我们的做法（3-way 合并后）

以 **v1.4.0 标准版**为基础（保留 `find_loaded_module` 用于非 OHOS），加回：
- `get_data()` 中 `#[cfg(target_env = "ohos")]` 前置分支（`ohos_primary_get_data`）
- `#[cfg]` target 路径分流（OHOS 用 `ohos_pie_load_base`，非 OHOS 用 `find_loaded_module`）
- `ohos_pie_load_base()` — 扫 `/proc/self/maps` 找 PIE 基地址
- `ohos_primary_get_data()` — `/proc/self/exe` + mmap
- `locate_bun_section()` — ELF section header 解析
- `read_at()` — `pread64` 封装
- ELF 常量（ELF_MAGIC, EHDR_*, SHDR_*）
- 总共 **17 处** cfg gate

### social4hyq 的做法

- 有 **4 处** `cfg(target_env = "ohos")` gate（比我们少 13 处）
- **没有** `ohos_pie_load_base` 和 `ohos_primary_get_data`（grep = 0）
- 可能用不同的 PIE 处理方式

### ljy9812 的做法

- 有 **23 处** cfg gate（OHOS base 版本，比我们的 17 处多 — 因为 ljy9812 没做 3-way 合并）
- 有 `ohos_pie_load_base` 和 `ohos_primary_get_data`

### 差异分析

| | 我们（3-way 合并后） | social4hyq | ljy9812 |
|---|---|---|---|
| 基础版本 | v1.4.0（`find_loaded_module`） | — | OHOS base |
| OHOS PIE 函数 | ✅ 4 个（160 行） | ❌ 无 | ✅ 有 |
| cfg gate 数 | 17 | 4 | 23 |
| 非 OHOS 路径 | ✅ `find_loaded_module`（v1.4.0） | — | ❌ 无分流 |
| v1.4.0 改进 | ✅ 保留 | — | ❌ 没有 |

---

## 10. 其他文件（13 个）

### 涉及文件

| 文件 | 行数 | OHOS 标记 | 内容 |
|---|---:|---:|---|
| `src/crash_handler/lib.rs` | 28 | 3 | OHOS 崩溃处理 |
| `src/jsc/bindings/BunProcess.cpp` | 2 | 1 | OHOS 进程绑定 |
| `src/jsc/bindings/JSWrappingFunction.h` | 2 | 0 | 小差异 |
| `src/jsc/bindings/NodeVM.h` | 2 | 0 | 小差异 |
| `src/jsc/bindings/c-bindings.cpp` | 22 | 2 | OHOS C++ 绑定 |
| `src/jsc/bindings/sqlite/NodeSqlite.h` | 12 | 0 | 合并残留 |
| `src/jsc/bindings/workaround-missing-symbols.cpp` | 7 | 0 | mimalloc `mi_on_thread_idle()` 占位 |
| `src/jsc/bindings/wtf-bindings.cpp` | 19 | 2 | OHOS WTF 绑定 |
| `src/options_types/context.rs` | 5 | 3 | OHOS 上下文 |
| `src/resolver/lib.rs` | 48 | 4 | OHOS 解析器 |
| `src/resolver/resolver.rs` | 27 | 4 | OHOS 解析器 |
| `src/runtime/napi/napi_body.rs` | 6 | 2 | OHOS napi |
| `src/spawn/process.rs` | 59 | 16 | OHOS spawn cfg gates |

这些文件全部源自 ljy9812，social4hyq 的实现可能不同（需逐个对比）。

---

## 11. 修复后的对齐状态

### 与 ljy9812 的对齐

- **48/53 文件**：完全一致（OHOS 适配代码源自 ljy9812）
- **5/53 文件**：我们有 v1.4.0 改进（config.ts, rust.ts, run_command.rs, StandaloneModuleGraph.rs, Symlinker.rs）
- ljy9812 的 Cargo.lock 有 ohos_sign 缺失 bug（未触发，因为没 `--locked`）

### 与 social4hyq 的对齐

- **0/53 文件**：完全一致
- 每个文件都有分歧（方式不同或实现不同）
- social4hyq 不禁用 SVE、不裁剪 symbols.dyn、不禁用 EPOLLONESHOT

### 与 v1.4.0 的对齐

- **0/53 文件**：一致
- 全部 53 个文件都有 OHOS 专属修改
- 非 OHOS 部分与 v1.4.0 完全一致

---

## 12. 修复优先级（更新）

| 优先级 | 修复项 | 影响 | 状态 |
|---|---|---|---|
| ✅ 已修复 | Cargo.lock ohos_sign | `--locked` 编译失败 | 给 5 个包加依赖引用 |
| ✅ 已修复 | Symlinker.rs 类型 | `bun_install` 编译失败 | `Ok(())` → `Ok(true)`/`Ok(false)` |
| ✅ 已修复 | WEBKIT_REF 版本 | `StrongSet.h` 找不到 | `caad865e` → `0f966e81` |
| ✅ 已修复 | 4 文件 3-way 合并 | CI `openharmony` 不支持 | OHOS base + v1.4.0 + social4hyq |
| ✅ 已修复 | pull_request 触发 | PR 不触发 OHOS 编译 | 加 `pull_request` trigger |
| **P0** | symbols.dyn 裁剪 | Linux `--dynamic-list` 报错 | 恢复全量 or 拆文件 |
| **P0** | linker.lds OHOS shim | Linux lld `symbol not defined` | `--undefined-version` or 移走 |
| **P1** | Highway SVE 禁用 | 32 用例回归 | 移除 `HWY_DISABLED_TARGETS` |
| **P1** | EPOLLONESHOT 禁用 | 2 用例回归 | 移除禁用 |
| **P2** | run_command.rs gate 不足 | OHOS 边界 case | 补 social4hyq 的 5 个额外 gate |
| **P2** | linker.lds shim 符号不全 | dlopen 模块功能 | 8 → 18 个（补 epoll 簇） |
| **P3** | Cargo.lock 手动编辑 | 排序可能不完美 | 在能跑 cargo 的环境重新生成 |
| **P3** | Format/Source lints | 不阻断编译 | 后续 PR |

---

*分析日期：2026-08-29 | 分析者：Sisyphus*
*数据来源：git diff HEAD bun-v1.4.0 / GitHub API social4hyq+ljy9812*
