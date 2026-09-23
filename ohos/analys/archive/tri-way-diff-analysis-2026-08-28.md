# 三方差异超级详细分析：dev vs bun-v1.4.0 vs social4hyq — 2026-08-28

> dev = jx-bit/bun:dev (merge bun-v1.4.0 后)
> v1.4.0 = oven-sh/bun:bun-v1.4.0
> social4hyq = social4hyq/ohos-bun:ohos-aarch64
>
> 51 个 src/ 差异文件，全部同时与 v1.4.0 和 social4hyq 不同——
> 没有任何一个文件的 OHOS 实现和 social4hyq 一致。

---

## 0. 总览

| 分组 | 文件数 | dev 的改动 | social4hyq 的改动 | 是否对齐 |
|---|---:|---|---|---|
| 1. Highway SIMD | 3 | 禁用 SVE + polyfill | 不禁用, 用 highway_dispatch.h | ❌ 分歧 |
| 2. 链接器脚本 | 2 | 裁剪 symbols.dyn + 8 个 shim 符号 | 全量 symbols.dyn + 18 个 shim 符号 | ❌ 分歧 |
| 3. flags.ts 链接块 | 1 | --version-script=symbols.dyn (污染) | --dynamic-list + --version-script=linker.lds | ❌ 分歧 |
| 4. EPOLLONESHOT | 1 | 禁用 + cfg gate | 不禁用 | ❌ 分歧 |
| 5. Install 回退 | 7 | copy_file_fallback + EPERM 回退 | 无此回退 | ❌ dev 独有 |
| 6. Spawn 签名 | 4 | spawn 时签 ELF | 无 spawn 签名 | ❌ dev 独有 |
| 7. ohos_sign | 10 | 完整 crate | 有 ohos_sign | ⚠️ 需对比 |
| 8. sys cfg gates | 5 | target_env="ohos" gates | 不加 ohos gates | ❌ 分歧 |
| 9. 其他 OHOS 代码 | 18 | 各种 cfg gates | 需逐个对比 | ⚠️ 待查 |

---

## 1. Highway SIMD（3 文件）— sourcemap-simd + console-iterator 32 用例回归的根因

### 涉及文件
- `src/jsc/bindings/highway_sourcemap.cpp`
- `src/jsc/bindings/highway_json.cpp`
- `src/jsc/bindings/highway_xml.cpp`

### dev 的改动（相对 v1.4.0）

**highway_sourcemap.cpp** — 新增 SVE 禁用 + ToBits SVE 分支：
```cpp
// dev 新增（v1.4.0 和 social4hyq 都没有）
#if defined(__aarch64__)
#define HWY_DISABLED_TARGETS (HWY_ALL_SVE)
#endif

// ToBits 新增 SVE 分支
#elif HWY_TARGET == HWY_SVE || HWY_TARGET == HWY_SVE2
    uint8_t bits[8] = {};
    hn::StoreMaskBits(d, m, bits);
    return *reinterpret_cast<uint64_t*>(bits);
```

**highway_json.cpp** — 新增同样的 SVE 禁用：
```cpp
#if defined(__aarch64__)
#define HWY_DISABLED_TARGETS (HWY_ALL_SVE)
#endif
```

**highway_xml.cpp** — 新增 BUN_BFM polyfill：
```cpp
#if HWY_TARGET == HWY_SVE || HWY_TARGET == HWY_SVE2
template<class D, class M>
HWY_INLINE uint64_t BitsFromMask(D d, M mask) {
    // CompressStore + Iota polyfill
}
#endif
#define BUN_BFM(d, mask) BitsFromMask(d, mask)  // SVE
#define BUN_BFM(d, mask) hn::BitsFromMask(d, mask)  // 其他
```

### social4hyq 的实现

social4hyq **不做任何 SVE 干预**：
- 无 `HWY_DISABLED_TARGETS`
- 无 `HWY_TARGETS` 限定
- 无 `ToBits` SVE 分支
- 无 `BUN_BFM` polyfill
- 直接 `hn::BitsFromMask(d, m)` 信任 Highway 原生行为
- 包含 `#include "highway_dispatch.h"`（dispatch 缓存，dev 无此文件）

### 分歧根因

| 问题 | dev | social4hyq |
|---|---|---|
| SVE `BitsFromMask` 缺失 | 用 `HWY_DISABLED_TARGETS` 禁用 SVE → 保留 EMU128/scalar 后端 | 不禁用 → 信任 Highway 版本/编译器 |
| highway_dispatch.h | 无 | 有（来自上游 #39616，缓存 dispatch 结果） |
| BUN_BFM polyfill | 有（highway_xml.cpp only） | 无 |
| ToBits SVE 分支 | 有（highway_sourcemap.cpp） | 无 |

### 问题分析

dev 的 `HWY_DISABLED_TARGETS (HWY_ALL_SVE)` 禁用 SVE 但**保留 EMU128（软件模拟 128 位）后端**参与运行时 dispatch。如果 Highway dispatch 因某种原因选了 EMU128 而非 NEON，EMU128 的 `BitsFromMask` 结果可能与 NEON/标量路径不同 → SIMD 解码与标量不一致 → sourcemap-simd 24/24 + console-iterator 8/8 = 32 个用例失败。

social4hyq 不禁用 SVE，其 Highway 版本或编译器配置可能不编译 scalable SVE 目标（Harmonybrew 的 clang 默认 `-march` 不含 SVE），所以不会触发 `BitsFromMask` 缺失问题。

### 修复方案

**方案 A（推荐 — 对齐 social4hyq）**：移除 dev 的 `HWY_DISABLED_TARGETS`、`ToBits` SVE 分支、`BUN_BFM` polyfill。引入 `highway_dispatch.h`（已在 merge v1.4.0 时带入）。信任 Highway 原生 dispatch，和 social4hyq 一致。

**方案 B（保守）**：将 `HWY_DISABLED_TARGETS (HWY_ALL_SVE)` 改为 `HWY_TARGETS (HWY_NEON)`（只编译 NEON，不编译 EMU128/scalar），和早期版本一致。

---

## 2. 链接器脚本（2 文件）— Linux CI 构建失败的根因

### 涉及文件
- `src/symbols.dyn`
- `src/linker.lds`

### dev 的改动（相对 v1.4.0）

**symbols.dyn** — 从 577 符号完整列表裁剪为 6 行：
```
{
    global:
        Bun__dlopen;
    local:
        *;
};
```

**linker.lds** — 新增 8 个 OHOS shim 符号：
```
syscall;
close_range;
getcwd;
getpwuid_r;
tmpfile;
linkat;
symlinkat;
splice;
```

### social4hyq 的实现

- **symbols.dyn** = 完整 577 符号 dynamic-list（和 v1.4.0 一样）
- **linker.lds** = 有 OHOS shim 符号（更多 — 18 个，含 `close`/`epoll_ctl`/`epoll_wait`/`epoll_pwait` 等）
- 不做 symbols.dyn 裁剪

### 分歧根因

dev 裁剪 symbols.dyn 是为了规避 OHOS 设备 v8::Array::New 的 `__1` vs `__n1` mangling 不匹配崩溃。social4hyq 不裁剪是因为自编译了 `__n1` libcxx，v8 符号 mangling 正确匹配设备。

dev 的 linker.lds 只有 8 个 shim 符号；social4hyq 有 18 个（2026-08-18 validation pass 更新，新增 `close`/`epoll_ctl`/`epoll_wait`/`epoll_pwait` 等 epoll 簇）。

### 问题分析

1. **Linux 构建失败**：dev 的 `symbols.dyn` 含 `local: *;`，Linux 用 `--dynamic-list=symbols.dyn` 时 lld 报错 `"local:" scope not supported in --dynamic-list`
2. **Linux 构建失败**：dev 的 `linker.lds` 含 OHOS shim 符号（syscall 等），Linux 上这些是 libc UND 符号，lld 报 `version script assignment ... failed: symbol not defined`
3. **OHOS 功能缺失**：dev 只有 8 个 shim 符号，social4hyq 有 18 个——`close`/`epoll_ctl`/`epoll_wait`/`epoll_pwait` 缺失会影响 dlopen'd 模块的 epoll 簇兼容

### 修复方案

1. 恢复 `symbols.dyn` 到 v1.4.0/social4hyq 的完整 577 符号版本
2. 对齐 social4hyq 的 `linker.lds` OHOS shim 符号列表（8 → 18 个）
3. 对 Linux 的 lld `symbol not defined` 错误，加 `--undefined-version` 到 Linux link flags（lld 16+ 支持）
4. OHOS 链接块改为 `--dynamic-list=symbols.dyn` + `--version-script=linker.lds`（对齐 social4hyq）

---

## 3. flags.ts OHOS 链接块 — 链接器配置分歧

### dev 的 OHOS 链接块
```ts
flag: c => [
  "-Wl,--gc-sections",
  "-Wl,--export-dynamic",
  `-Wl,--version-script=${c.cwd}/src/symbols.dyn`,  // ← 污染！
  "-Wl,--undefined=us_ssl_*",
  "-Wl,--undefined=Bun__dlopen",
  "-Wl,--undefined=BUN_COMPILED",
],
when: c => c.release && c.ohos,
```

### social4hyq 的 OHOS 链接块
```ts
flag: c => [
  "-Wl,-Bsymbolic-functions",
  "-rdynamic",
  `-Wl,--dynamic-list=${c.cwd}/src/symbols.dyn`,
  `-Wl,--version-script=${c.cwd}/src/linker.lds`,
],
when: c => c.ohos,
desc: "OHOS: dynamic symbol list + version script (mirror linux block)",
```

### 分歧

| | dev | social4hyq |
|---|---|---|
| symbols.dyn 用途 | `--version-script`（污染 shared file） | `--dynamic-list`（正确） |
| version-script | `symbols.dyn`（含 `local: *`） | `linker.lds`（含 napi/uv/v8 + shim） |
| `--gc-sections` | 有 | 无 |
| `--export-dynamic` | 有 | 用 `-rdynamic` 代替 |
| `--undefined=` | 有（uSockets SSL + Bun__dlopen + BUN_COMPILED） | 无 |
| 限定条件 | `c.release && c.ohos` | `c.ohos`（不限 release） |

### 修复方案

对齐 social4hyq 的链接块。如果 dev 需要 `--gc-sections` + `--undefined=` 来保留 uSockets 符号，可以保留这些但**必须**改用 `--dynamic-list` + `--version-script=linker.lds`。

---

## 4. EPOLLONESHOT — spawn-stdin + 26286 回归的根因

### 涉及文件
- `src/io/posix_event_loop.rs`

### dev 的改动

dev 在 `register` 函数中禁用 EPOLLONESHOT：
```rust
// dev 新增
#[cfg(target_env = "ohos")]
let one_shot = false;  // 强制 level-triggered
```
并添加注释说明 HongMeng 1.12 内核不解除 one-shot 兴趣。

### social4hyq 的实现

social4hyq **不禁用 EPOLLONESHOT**。代码中有注释说明 EPOLLONESHOT 的限制（"bidirectional one-shot is not supported"），但保持标准行为。

### 分歧根因

dev 的 `ee6251b171` commit 标注 "Cherry-picked from social4hyq/ohos-bun baea48bbb"——但 social4hyq 当前代码并**没有**禁用 EPOLLONESHOT。可能 social4hyq 后来移除了禁用，或者 cherry-pick 的是一个更早的版本。

### 问题分析

禁用 EPOLLONESHOT 后所有 epoll 变成 level-triggered，可能导致：
- spawn-stdin-readable-stream-integration（1 用例）：stdin 管道可读事件时序变化
- regression/issue/26286（超时）：特定 I/O 模式下事件风暴或死等

### 修复方案

对齐 social4hyq——移除 EPOLLONESHOT 禁用。如果 HongMeng 内核确实有 one-shot bug，应采用 social4hyq 的方式（不禁用，而是处理其限制）。

---

## 5. Install 回退（7 文件）— dev 独有的 OHOS 适配

### 涉及文件
- `src/install/PackageInstall.rs`
- `src/install/isolated_install/Hardlinker.rs`
- `src/install/isolated_install/Symlinker.rs`
- `src/install/lib.rs`（`copy_file_fallback()` 函数）
- `src/install/PackageInstaller.rs`
- `src/install/PackageManager.rs`
- `src/install/PackageManager/PackageManagerLifecycle.rs`

### dev 的改动

dev 从 social4hyq backport 了 4 个 install 适配（commit `7780f3e420`）：
1. `copy_file_fallback()` — linkat/symlinkat EPERM/EACCES 时回退到文件拷贝
2. Hardlinker 的 EPERM/EACCES fallback
3. Symlinker 的 `Strategy::IgnoreFailure`
4. lifecycle_script_runner 的 getcwd→HOME fallback

### social4hyq 的实现

social4hyq 的 `install/lib.rs` 中**没有** `copy_file_fallback` 函数。这些回退可能是 dev 独有的——social4hyq 可能在上游代码中用不同方式处理了 SELinux EPERM，或者 social4hyq 的 OHOS 设备不需要这些回退。

### 分析

这些回退是为了处理 OHOS SELinux 拦截 linkat/symlinkat 的问题。如果 social4hyq 不需要这些回退，可能是因为：
1. social4hyq 的设备配置不同（SELinux 策略不同）
2. social4hyq 用了不同的安装策略（如直接 copy 替代 hardlink）
3. social4hyq 的上游代码已经处理了这些问题

### 修复方案

保留这些回退——它们是针对特定 OHOS 设备的 SELinux 限制的必要适配。但应该检查 social4hyq 是否有更新的版本或不同的实现方式。

---

## 6. Spawn 签名（4 文件）

### 涉及文件
- `src/spawn_sys/spawn_process.rs`
- `src/spawn/process.rs`
- `src/jsc/bindings/bun-spawn.cpp`
- `src/runtime/api/bun/spawn/stdio.rs`

### dev 的改动

dev 在 `spawn_process.rs` 中新增 OHOS ELF 签名逻辑：
```rust
#[cfg(target_env = "ohos")]
{
    // OHOS seccomp blocks exec of unsigned ELF binaries.
    // Sign any native binary before spawning.
    if bytes[..4] == [0x7f, 0x45, 0x4c, 0x46] {
        // sign the binary
    }
}
```

并在 `spawn/process.rs`、`bun-spawn.cpp` 中大量使用 `#[cfg(target_env = "ohos")]` / `#[cfg(not(target_env = "ohos"))]` 门控。

### social4hyq 的实现

social4hyq 的 `spawn_process.rs` 没有 ELF 签名逻辑。social4hyq 可能在安装时签名（`install-bun-ohos.sh` 在设备上签名），而不是在 spawn 时签名。

### 修复方案

检查 social4hyq 的签名时机。如果 social4hyq 在安装时签名，dev 的 spawn 时签名是冗余的（但可能对动态生成/下载的二进制有用）。保留 dev 的 spawn 签名但考虑对齐 social4hyq 的安装时签名。

---

## 7. ohos_sign/（10 文件）

### 涉及文件
- `src/ohos_sign/Cargo.toml` + `src/ohos_sign/src/{elf,descriptor,merkle,sha256,lib}.rs` + `src/ohos_sign/src/bin/ohos_selfsign.rs` + 4 个 test 文件

### 三方对比

- dev: 有完整的 ohos_sign crate（342 行 elf.rs + 117 行 selfsign + merkle/sha256/descriptor）
- v1.4.0: 无
- social4hyq: 有（HTTP 200）

### 修复方案

需要逐文件对比 dev 和 social4hyq 的 ohos_sign 实现。由于签名逻辑涉及 ELF 解析、Merkle 树、SHA-256 KAT，实现差异可能导致签名不兼容。优先对齐 social4hyq 的实现。

---

## 8. sys cfg gates（5 文件）

### 涉及文件
- `src/sys/lib.rs`（17 行 + 77 行 diff）
- `src/sys/Error.rs`（17 行 diff）
- `src/sys/linux_syscall.rs`（9 行 diff）
- `src/sys/Cargo.toml`
- `src/sys_jsc/signal_code_jsc.rs`

### dev 的改动

dev 在多处 cfg gate 中添加 `target_env = "ohos"`：
```rust
// dev
#[cfg(any(target_env = "musl", target_env = "ohos", target_os = "android"))]
// v1.4.0
#[cfg(any(target_env = "musl", target_os = "android"))]
```

并在 `sys/Error.rs` 新增 `From<Error> for bun_core::Error` 实现。

### social4hyq 的实现

social4hyq 的 `sys/lib.rs` 中**没有** `target_env = "ohos"` 出现在 cfg gates 中。social4hyq 可能：
1. 用 `target_os = "android"` 覆盖 OHOS（如果 OHOS 的 cfg 别名映射到 android）
2. 或者 OHOS 的 sys 层行为和 musl/android 一致，不需要单独 gate

### 修复方案

检查 dev 的 `target_env = "ohos"` cfg gate 是否必要。如果 OHOS 的 sys 行为和 musl 一致（OHOS 用 musl libc），可以改用 `target_env = "musl"` 覆盖。如果 OHOS 有独特行为，保留 gate 但记录原因。

---

## 9. 其他 OHOS 代码（18 文件）

### 涉及文件
- `src/crash_handler/lib.rs` — OHOS 崩溃处理
- `src/install/Cargo.toml` + `src/install/bin.rs` + `src/install/lifecycle_script_runner.rs` — OHOS install 适配
- `src/install/PackageInstaller.rs` + `src/install/PackageManager.rs` + `src/install/PackageManager/PackageManagerLifecycle.rs` — OHOS 包管理
- `src/jsc/bindings/BunProcess.cpp` — OHOS 进程绑定
- `src/jsc/bindings/c-bindings.cpp` + `src/jsc/bindings/wtf-bindings.cpp` — OHOS C++ 绑定
- `src/jsc/bindings/workaround-missing-symbols.cpp` — OHOS mimalloc `mi_on_thread_idle()` 占位
- `src/jsc/bindings/sqlite/NodeSqlite.h` — 合并残留（2 行重复）
- `src/options_types/context.rs` — OHOS 上下文
- `src/resolver/lib.rs` + `src/resolver/resolver.rs` — OHOS 解析器
- `src/runtime/Cargo.toml` + `src/runtime/napi/napi_body.rs` — OHOS runtime
- `src/spawn_sys/Cargo.toml` + `src/standalone_graph/Cargo.toml` — OHOS crate 配置

### 修复方案

逐个对比 social4hyq 版本。优先级：
1. `workaround-missing-symbols.cpp` — 可能需要更新以匹配 social4hyq 的 mimalloc fork
2. `crash_handler/lib.rs` — 崩溃处理差异可能影响诊断
3. `resolver/` — 解析器差异可能影响模块解析
4. 其余按需对比

---

## 10. scripts/ 差异（12 文件）

### 关键差异

| 文件 | dev 的改动 | social4hyq |
|---|---|---|
| `scripts/build/flags.ts` | OHOS 专用链接块 + `-march=armv8-a` baseline | 镜像 Linux 链接块 |
| `scripts/build/config.ts` | OHOS sysroot/sdk/cross-libs 配置 | 类似 |
| `scripts/build/rust.ts` | OHOS rust 编译配置 | 类似 |
| `scripts/build/deps/webkit.ts` | OHOS WebKit fork 版本 | 不同的 WebKit 版本 |
| `scripts/build/deps/mimalloc.ts` | OHOS mimalloc fork 版本 | 不同的 mimalloc 版本 |

### 修复方案

1. `flags.ts`：对齐 social4hyq 的 OHOS 链接块（见第 3 节）
2. `webkit.ts` / `mimalloc.ts`：保持各自的 fork 版本（预期差异）
3. 其余对齐 social4hyq

---

## 11. 修复优先级总结

| 优先级 | 修复项 | 影响 | 修复方式 |
|---|---:|---|---|
| **P0** | symbols.dyn 恢复全量 | Linux CI 构建失败 | `git checkout bun-v1.4.0 -- src/symbols.dyn` |
| **P0** | linker.lds OHOS shim 对齐 | Linux lld `symbol not defined` + OHOS 功能缺失 | 加 `--undefined-version` 或对齐 social4hyq 18 符号 |
| **P0** | flags.ts OHOS 链接块 | symbols.dyn 污染 | 改为 `--dynamic-list + --version-script=linker.lds` |
| **P1** | Highway SVE 处理 | sourcemap-simd(24) + console-iterator(8) 回归 | 移除 `HWY_DISABLED_TARGETS`，对齐 social4hyq |
| **P1** | EPOLLONESHOT | spawn-stdin(1) + 26286(超时) 回归 | 移除禁用，对齐 social4hyq |
| **P2** | ohos_sign 对齐 | 签名兼容性 | 逐文件对比 social4hyq |
| **P2** | install 回退验证 | 可能冗余 | 检查 social4hyq 是否有更新版本 |
| **P2** | sys cfg gates | 可能排除功能 | 检查 `target_env = "ohos"` 是否必要 |
| **P3** | spawn 签名时机 | 可能冗余 | 对齐 social4hyq 安装时签名 |
| **P3** | 其他 18 文件 | 零散差异 | 逐个对比 social4hyq |

---

## 12. social4hyq 有而 dev 没有的（merge v1.4.0 后仍缺失）

| 项目 | 来源 | 影响 |
|---|---|---|
| `highway_dispatch.h` | 上游 #39616 | dispatch 缓存，省 ~20 指令/调用 |
| `highway_dispatch.h` 的 `BUN_HWY_DISPATCH` 应用 | 上游 #39616 | 所有 highway 文件的 dispatch 优化 |
| OHOS shim 符号 18 个（dev 只有 8 个） | social4hyq 2026-08-18 validation | `close`/`epoll_ctl`/`epoll_wait`/`epoll_pwait` 等 |

注：`highway_dispatch.h` 已在 merge v1.4.0 时带入，但 dev 的 highway 文件仍用 `HWY_DYNAMIC_DISPATCH`（未切换到 `BUN_HWY_DISPATCH`），因为 dev 的 highway 文件有 OHOS SVE 修改导致 merge 时取了 dev 版本。

---

*分析日期：2026-08-28 | 分析者：Sisyphus*
*数据来源：git diff HEAD bun-v1.4.0 / GitHub API social4hyq/ohos-bun:ohos-aarch64*
