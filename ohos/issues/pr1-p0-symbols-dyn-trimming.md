# P0: symbols.dyn 裁剪问题 — 详细讲解
> **关联 PR**：[#1](https://github.com/jx-bit/bun/pull/1)（方案 A：拆分 version-script，本 issue 的主修复）· [#13](https://github.com/jx-bit/bun/pull/13)（静态 libunwind 后残余场景消失）。注：文中"PR #10"为旧编号痕迹，GitHub #10 是 EPOLLONESHOT 修复

> 用最简单的方式讲清楚：这是什么、为什么裁剪、出了什么问题、怎么修。

---

## 1. 什么是 symbols.dyn

### 通俗比喻

想象 bun 编译出来的二进制是一栋大楼，里面有很多"房间"（函数）。
`symbols.dyn` 就是大楼的**门牌目录**——告诉外面的人"哪些房间对外开放"。

外部模块（比如 `.node` 插件）需要通过这个门牌目录找到 bun 里的函数。
如果某个函数在目录里，外部模块就能调用它；如果不在目录里，就找不到。

### 技术含义

`symbols.dyn` 是一个链接器文件，控制 bun 二进制**导出哪些符号**（函数/变量）
给动态链接的外部模块用。链接器（lld）在编译时读这个文件，决定哪些符号
放进 `.dynsym` 段（动态符号表）。

### 文件格式

v1.4.0 和 social4hyq 的 `symbols.dyn` 有 667 行，长这样：

```
{
    __ZN2v811HandleScope12CreateHandleEPNS_8internal7IsolateEm;
    __ZNK2v85Value16QuickIsUndefinedEv;
    _napi_acquire_threadsafe_function;
    _napi_add_async_cleanup_hook;
    _uv_accept;
    _uv_async_init;
    ...（共 577 个符号）
};
```

这些符号包括：
- `__ZN2v8*` — V8 兼容层（C++ name mangling，给 napi 模块用的 V8 API）
- `_napi_*` — Node-API 函数（`.node` 插件调的）
- `_uv_*` — libuv 函数（事件循环）
- `Bun__dlopen` — bun 自己的 dlopen

### 怎么被使用的

在 `scripts/build/flags.ts` 里，有两个链接器参数引用 `symbols.dyn`：

```ts
// Linux 用法（正确）
"-Wl,--dynamic-list=${c.cwd}/src/symbols.dyn",
"-Wl,--version-script=${c.cwd}/src/linker.lds",

// OHOS 用法（有问题！）
"-Wl,--version-script=${c.cwd}/src/symbols.dyn",
```

| 参数 | 作用 | 支持的格式 |
|---|---|---|
| `--dynamic-list` | 把列表里的符号加入 `.dynsym`（导出） | 只能写符号名，**不支持** `local:` |
| `--version-script` | 控制版本标签和符号可见性 | **支持** `global:`/`local:`/版本标签 |

---

## 2. 为什么我们的 symbols.dyn 只有 6 行

### 引入裁剪的 commit

裁剪策略由 **commit `7780f3e420`**（2026-08-10）引入，作者是 `ljy9810`。
这是 PR #10 "fix(ohos): social4hyq container + ABI alignment + 4 sb install backports"
中的一个子提交，标题：

> `fix(ohos): restrict .dynsym to Bun__dlopen only — fix symbol not found`

### 为什么要裁剪（commit message 原文翻译）

问题的根因：

1. **OHOS 设备的 libc++ 用 `__n1` 命名空间**
   OHOS 设备的 `libc++_shared.so` / `libv8_shared.so` 导出 `std::__n1::*` 符号
   （OHOS 设定 `_LIBCPP_ABI_NAMESPACE=__n1`）。

2. **bun 的编译环境用 `__1` 或 `__h` 命名空间**
   Harmonybrew 的 llvm@21 bottle 和 OHOS SDK 的 .a 文件，
   C++ 符号都 mangle 为 `std::__h::*` 或 `std::__1::*`。

3. **V8 符号导出后设备尝试解析 → 不匹配 → 崩溃**
   当 bun 用 `--dynamic-list=symbols.dyn`（577 符号）+ `--version-script=linker.lds`
   （`v8::*` 通配）全量导出 V8 符号时，设备动态链接器要解析
   `v8::Array::New(..., std::function)` → 在设备的 `libc++_shared.so`
   里找 `std::__n1::function` → 但 bun 导出的符号是 `std::__1::function`
   → **"symbol not found" 崩溃**。

4. **用 `nm` 确认了崩溃原因**
   作者对已发布的 `bun-ohos-aarch64` 二进制运行 `nm`，发现其导出的
   `v8::Array::New` 确实用的是 `std::__h::function`——和设备不匹配。

### 裁剪策略

**思路**：既然导出 V8 符号会导致设备崩溃，那就**只导出 `Bun__dlopen`**，
其他全部隐藏。设备永远不会尝试解析 V8 符号 → 不崩溃。

具体改动（commit message 原文）：

> `src/symbols.dyn`: 577 行 dynamic-list → version-script
> `{ global: Bun__dlopen; local: *; }`（和 sb-fy-sb 的工作构建一致）
>
> `flags.ts` OHOS 链接块：去掉 `--dynamic-list` + `--version-script=linker.lds`；
> 改用 `--gc-sections --export-dynamic --version-script=symbols.dyn`
> + `--undefined=us_ssl_*/Bun__dlopen/BUN_COMPILED`
>（强制保留 gc-sections 会删除的 uSockets SSL 符号）

### 作者的错误假设

commit message 最后一句：

> OHOS builds only (c.linux=false so Linux --dynamic-list path is untouched)

翻译："只在 OHOS 构建时生效（c.linux=false，所以 Linux 的 --dynamic-list 路径不受影响）"

**这个假设是错的**：`c.linux=false` 只控制哪个 flag 块在编译时生效，
但 `symbols.dyn` 是一个**共享文件**——同一个文件被 Linux 的 `--dynamic-list`
和 OHOS 的 `--version-script` 同时引用。把文件内容从 577 行符号列表
改成 `{ global: Bun__dlopen; local: *; }`，Linux 的 `--dynamic-list`
也会读到这个格式 → lld 报错 `local: scope not supported in --dynamic-list`。

### 为什么不直接修 ABI（social4hyq 的做法）

social4hyq 在同一个 commit `7780f3e420` 里也尝试了自编译 `__n1` libcxx
的方案（commit message 里有 "self-compile __n1 libcxx from LLVM source" 子提交），
但这个方案在 GitHub-hosted CI 上遇到了困难：
- 自编译 libcxx 需要 ~10 分钟
- 需要额外的 CI 步骤
- 多次尝试都失败了（commit message 记录了多次迭代）

最终作者选择了**裁剪策略**作为更简单的替代方案：
- 不需要自编译 libcxx
- 不需要额外的 CI 步骤
- 一行 `local: *` 就能避免设备崩溃

**代价**：napi/uv 符号不再导出（`.node` 模块兼容性受限）+ 污染了共享文件
导致 Linux 编译失败。

### sb-fy-sb 是什么

commit message 里提到 "matches sb-fy-sb exactly" 和 "sb-fy-sb's working build"。
`sb-fy-sb` 是作者的一台自托管 OHOS 设备的代号（可能是 "sb-fy" = 某个设备名）。
这台设备上有一个能正常运行的 bun 构建，作者用它作为参考——裁剪策略就是
从这台设备的构建配置里复制的。

### 裁剪的副作用

| 影响 | 说明 |
|---|---|
| `.node` 插件无法解析 napi/uv 符号 | 外部模块找不到 `_napi_*`、`_uv_*` → 功能受限 |
| 二进制段布局变化 | `local: *` + `--gc-sections` 改变段大小 → `tls-segment-size` 测试失败 |
| **Linux 编译失败** | `symbols.dyn` 被 Linux 当 `--dynamic-list` 用，但 `local:` 在 dynamic-list 里不合法 |

---

## 3. 出了什么问题

### 问题 1：Linux 编译失败

```
ld.lld: error: src/symbols.dyn:6: "local:" scope not supported in --dynamic-list
```

**根因**：Linux 的链接器把 `symbols.dyn` 当 `--dynamic-list` 用（行 1569）。
`--dynamic-list` 的格式**不允许** `local:` 关键字——只能列符号名。
但我们的文件有 `local: *;`，lld 拒绝接受。

**通俗理解**：`--dynamic-list` 是"白名单"模式（列出要导出的符号），
不支持"黑名单"模式（列出要隐藏的符号）。`local: *` 是"隐藏全部"，
属于黑名单，所以不被接受。

### 问题 2：OHOS 专用配置污染了共享文件

`symbols.dyn` 被 Linux、FreeBSD、OHOS 三个平台共用：

```
Linux:    --dynamic-list=symbols.dyn    （需要：纯符号列表）
FreeBSD:  --dynamic-list=symbols.dyn    （需要：纯符号列表）
OHOS:     --version-script=symbols.dyn  （需要：global:/local: 格式）
```

OHOS 用 `--version-script`（支持 `local:`），但 Linux/FreeBSD 用
`--dynamic-list`（不支持 `local:`）。一个文件不能同时满足两种格式。

---

## 4. 三方对比

| | 我们 / ljy9812 | social4hyq | v1.4.0（上游） |
|---|---|---|---|
| symbols.dyn 行数 | 6 | 667 | 667 |
| 内容 | `global: Bun__dlopen; local: *` | 577 个符号 | 577 个符号 |
| OHOS 用法 | `--version-script=symbols.dyn` | `--dynamic-list=symbols.dyn` + `--version-script=linker.lds` | 不适用（无 OHOS） |
| Linux 用法 | `--dynamic-list=symbols.dyn` | 同 | `--dynamic-list=symbols.dyn` |
| Linux 编译 | ❌ 失败 | ✅ 正常 | ✅ 正常 |
| v8 符号导出 | ❌ 隐藏 | ✅ 全量导出 | ✅ 全量导出 |
| napi/uv 导出 | ❌ 隐藏 | ✅ 全量导出 | ✅ 全量导出 |
| 设备 v8 崩溃 | ✅ 避免（不导出 v8） | ✅ 避免（ABI 匹配） | 不适用 |

### social4hyq 为什么能全量导出

social4hyq 在编译时自编译了 `__n1` ABI 的 libcxx：

```bash
# social4hyq 的做法（简化）
cmake -DLIBCXX_ABI_NAMESPACE=__n1 ...
# → libcxx 的 C++ 符号 mangle 为 __n1
# → 和 OHOS 设备的 libc++_shared.so 匹配
# → V8 符号可以安全导出
```

我们的编译环境用 Harmonybrew 的 llvm@21，其 libcxx 是 `__1` ABI。
和设备的 `__n1` 不匹配，所以不能全量导出 V8 符号。

---

## 5. 修复方案

### 方案 A：拆分文件（PR #1 的方案，已验证）

把 OHOS 的 `--version-script` 用法和 Linux 的 `--dynamic-list` 用法分离：

1. `src/symbols.dyn` 恢复成 v1.4.0 的 667 行纯符号列表
2. 新建 `src/linker-ohos.lds` 存 OHOS 专用版本脚本：
   ```
   {
       global:
           Bun__dlopen;
       local:
           *;
   };
   ```
3. `flags.ts` 的 OHOS 链接块改用 `linker-ohos.lds`

**优点**：Linux 不受影响，OHOS 保持裁剪策略
**缺点**：napi/uv 符号仍然不导出（OHOS 的 `.node` 模块兼容性受限）

### 方案 B：对齐 social4hyq（根本解决）

1. 恢复 `symbols.dyn` 到 667 行
2. OHOS 链接块改用 `--dynamic-list=symbols.dyn` + `--version-script=linker.lds`（和 Linux 一样）
3. 自编译 `__n1` ABI 的 libcxx（在 CI 里加一步）

**优点**：napi/uv 符号全量导出，和 social4hyq 一致
**缺点**：需要在 CI 里加 libcxx 自编译步骤（~10 分钟）

### 方案 C：`--undefined-version`（临时绕过）

不改 symbols.dyn，只在 Linux 链接参数里加 `--undefined-version`，
让 lld 忽略 version-script 里未定义的符号（OHOS shim 符号在 Linux 上是 UND）。

**优点**：改动最小
**缺点**：symbols.dyn 的 `local:` 仍然会破坏 `--dynamic-list`，这个方案不能单独解决

### 推荐方案

**短期**：方案 A（拆分文件，PR #1 已验证可行）
**长期**：方案 B（自编译 `__n1` libcxx，根本解决 ABI 不匹配）

---

## 6. 涉及的其他文件

### linker.lds

`linker.lds` 是 version-script 文件，控制符号的版本标签和可见性。
我们的 `linker.lds` 含有 OHOS shim 符号（syscall, close_range 等）：

```
BUN_1.2 {
    global:
        napi*;
        node_api_*;
        node_module_register;
        syscall;          ← OHOS shim
        close_range;      ← OHOS shim
        getcwd;           ← OHOS shim
        ...
    local:
        *;
};
```

Linux 上这些 shim 符号是 libc 的导入符号（UND），lld 会报
`version script assignment ... failed: symbol not defined`。
需要加 `--undefined-version` 或把 shim 符号移到 OHOS 专用文件。

### flags.ts

OHOS 链接块（行 1319-1340）需要改为 social4hyq 的方式：

```ts
// 当前（有问题）
flag: c => [
    "-Wl,--gc-sections",
    "-Wl,--export-dynamic",
    `-Wl,--version-script=${c.cwd}/src/symbols.dyn`,  // ← 污染共享文件
    ...
]

// 修复后（方案 A）
flag: c => [
    "-Wl,--gc-sections",
    "-Wl,--export-dynamic",
    `-Wl,--version-script=${c.cwd}/src/linker-ohos.lds`,  // ← OHOS 专用
    ...
]

// 修复后（方案 B，对齐 social4hyq）
flag: c => [
    "-Wl,-Bsymbolic-functions",
    "-rdynamic",
    `-Wl,--dynamic-list=${c.cwd}/src/symbols.dyn`,         // ← 全量导出
    `-Wl,--version-script=${c.cwd}/src/linker.lds`,         // ← 和 Linux 一样
]
```

---

## 7. 相关的回归测试

| 测试 | 回归原因 | 用例数 |
|---|---|---|
| `tls-segment-size` | `local: *` + `--gc-sections` 改变二进制段布局 | 1 |
| `sourcemap-simd` | Highway SVE 禁用（和 symbols.dyn 无直接关系，但同一根因：OHOS 裁剪策略的副作用） | 24 |
| `console-iterator` | 同上 | 8 |

---

## 8. 方案 B 的核心：自编译 `__n1` libc++

方案 B 选择全量导出（恢复 symbols.dyn 到 667 行），这意味着 v8 符号会被导出。
但 v8 符号里有一个 `v8::Array::New(Context, size_t, std::function)` 重载——
`std::function` 的 mangle 名包含 ABI 命名空间，如果 bun 用 `__1` 编译，
设备用 `__n1`，符号名不匹配 → "symbol not found" 崩溃。

### 8.1 什么是 ABI 命名空间

C++ 标准库（libc++）的符号名里有一个"命名空间前缀"，由 `_LIBCPP_ABI_NAMESPACE` 宏决定：

```
_LIBCPP_ABI_NAMESPACE=__1  → std::function mangle 为 _ZNSt3__18function...
_LIBCPP_ABI_NAMESPACE=__n1 → std::function mangle 为 _ZNSt4__n18function...
_LIBCPP_ABI_NAMESPACE=__h  → std::function mangle 为 _ZNSt3__h8function...
```

不同前缀的符号**不能互相解析**——链接器认为它们是不同的符号。

### 8.2 OHOS 设备用 `__n1`

OHOS 系统设定 `_LIBCPP_ABI_NAMESPACE=__n1`，设备的 `libc++_shared.so` 里
所有 C++ 标准库符号都是 `std::__n1::*`。

如果 bun 导出的 `v8::Array::New` 用了 `std::__1::function`，设备解析时找不到 → 崩溃。

### 8.3 两套现成的 libc++ 包都不满足需求

CI 容器（Harmonybrew）里有两套 libc++：

| 属性 | Harmonybrew llvm@21 | OHOS SDK (DevEcoStudio) |
|---|---|---|
| 位置 | `llvm@21/include/aarch64-linux-ohos/c++/v1/` | `ohos-sdk/native/llvm/include/libcxx-ohos/include/c++/v1/` |
| clang 版本 | 21.1.8 ✅（满足 bun 的 `>=21 <23`） | 15.0.4 ❌（不满足） |
| C++23 头文件 | ✅ 完整（`<expected>`, `<print>` 等） | ❌ 不完整（`_LIBCPP_VERSION 15004`） |
| ABI 命名空间 | `__1` ❌（不匹配设备） | `__n1` ✅（匹配设备） |

**没有任何现成的包同时满足「LLVM 21 C++23 头文件」+「`__n1` ABI」。**

### 8.4 为什么不能混用

- **用 llvm@21 的头文件 + ohos-sdk 的 `__n1` 库**：头文件里 `__config_site` 定义
  `__1`，编译器据此 mangle 为 `std::__1::*`，链接 `__n1` 库时符号名不匹配 → 链接失败
- **sed 改头文件 `__1` → `__n1`**：头文件改了，但 llvm@21 的 `.a` 库里的符号还是
  `__1` → 链接时 `std::__n1::function` 找不到实现 → undefined reference
- **用 ohos-sdk 的 `__n1` 头文件 + llvm@21 的 clang**：头文件是 LLVM 15 版本，
  缺 C++23 特性 → bun 代码用 `-std=gnu++23` → 编译失败

### 8.5 唯一可行方案：从 LLVM 21.1.8 源码自编译

```cmake
-DLIBCXX_ABI_NAMESPACE=__n1
```

这样得到：
- **头文件**：LLVM 21 版本 → 支持 C++23 ✅
- **ABI 命名空间**：`__n1` → 匹配设备 ✅
- **静态库**：和头文件同一次编译 → ABI 一致 ✅
- **编译器**：仍然用 llvm@21 的 clang 21（满足版本要求）

### 8.6 自编译过程

在 `build-ohos-container.sh` 里，下载 LLVM 21.1.8 源码后分两个 Stage 编译：

**Stage 1：编译 libunwind**（独立，不依赖 libc++）
```cmake
cmake -DLLVM_ENABLE_RUNTIMES="libunwind" \
  -DCMAKE_INSTALL_PREFIX=$CROSS/libunwind
```

**Stage 2：编译 libcxx + libcxxabi + libunwind**（依赖 Stage 1 的头文件）
```cmake
cmake -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
  -DLIBCXX_ABI_NAMESPACE=__n1 \    ← 关键
  -DCMAKE_INSTALL_PREFIX=$CROSS
```

编译产物安装到：
```
$CROSS/include/c++/v1/     ← 头文件（LLVM 21 + __n1 ABI）
$CROSS/lib/libc++.a        ← __n1 静态库
$CROSS/lib/libc++abi.a     ← __n1 静态库
$CROSS/lib/libunwind.a     ← 纯 C，无 ABI 命名空间
```

### 8.7 自编译遇到的 8 个问题及解决方案

| # | 问题 | 原因 | 解决方案 |
|---|---|---|---|
| 1 | CMake 找到 `LLVMExports.cmake`，报缺 `libLLVMDemangle.a` | brew bottle 缺静态库 | temporarily hide `$LLVM_PREFIX/lib/cmake` 目录（mv 到 .bak，编译完恢复） |
| 2 | `CMAKE_DISABLE_FIND_PACKAGE_LLVM` 导致 `ClangConfig` 失败 | Clang 依赖 LLVM | 不用 DISABLE，用 hide 方式 |
| 3 | `CMAKE_IGNORE_PATH` 没生效 | symlink 路径解析问题 | 不用 IGNORE，用 hide 方式 |
| 4 | libcxx 编译报 `unknown rune table` | musl 没有 rune table（glibc 特有） | 编译时加 `-D_LIBCPP_PROVIDES_DEFAULT_RUNE_TABLE` |
| 5 | libcxx 编译报 `strtoll_l`/`strtoull_l` 未定义 | musl 不提供 glibc 的 locale 版本 | sed patch LLVM 源码：`strtoll_l(a,b,c,d)` → `strtoll(a,b,c)`（去掉 locale 参数） |
| 6 | `libunwind.a` 验证 `__n1` 失败 | libunwind 是纯 C，没有 ABI 命名空间 | 验证时不检查 libunwind，只检查 `libc++.a` 和 `libc++abi.a` |
| 7 | WebKit 编译找不到 `cstddef` 等头文件 | `CROSS` 用相对路径，symlink 解析为死链接 | 改用绝对路径 + `ln -sfn` |
| 8 | WebKit 编译报 `rune table` 错误（即使 flags.ts 加了 define） | WebKit 的 CMake 自己生成编译命令，不走 flags.ts | patch `__config_site` 头文件：把 defines 写进头文件，所有 `#include` 它的代码自动获得 |

### 8.8 编译后的使用流程

**步骤 1：创建 flags.ts 期望的目录布局**

cmake install 的头文件在 `$CROSS/include/c++/v1/`，但 flags.ts 期望 `$CROSS/libcxx/include/v1/`。
用 symlink 映射（用绝对路径避免相对路径解析问题）：

```bash
CROSS="$SRC/build/ohos-cross-libs"   # 绝对路径
ln -sfn "$CROSS/include/c++/v1" "$CROSS/libcxx/include/v1"
ln -sfn "$CROSS/include/c++/v1" "$CROSS/libcxxabi/include/v1"
ln -sfn "$CROSS/lib/libc++.a"      "$CROSS/libcxx/lib/libc++.a"
ln -sfn "$CROSS/lib/libc++abi.a"   "$CROSS/libcxxabi/lib/libc++abi.a"
ln -sfn "$CROSS/lib/libunwind.a"   "$CROSS/libunwind/lib/libunwind.a"
```

**步骤 2：patch `__config_site`**

cmake install 的 `__config_site` 只有 `#define _LIBCPP_ABI_NAMESPACE __n1`，
没有 musl 兼容的 defines。WebKit 的 CMake 不走 flags.ts，所以需要直接写进头文件：

```bash
echo '#define _LIBCPP_PROVIDES_DEFAULT_RUNE_TABLE' >> "$CONFIG_SITE"
echo '#define _LIBCPP_HAS_NO_LOCALIZATION' >> "$CONFIG_SITE"
```

这样所有 `#include <__config_site>` 的代码（包括 WebKit）都自动获得这两个 define。

**步骤 3：WebKit 和 bun C++ 编译**

flags.ts 里 OHOS CXX flags：
```ts
flag: c => [`-nostdinc++`, `-I${c.ohosCrossLibs}/libcxx/include/v1`, ...]
```

- `-nostdinc++`：不用系统默认 C++ 头文件
- `-I$CROSS/libcxx/include/v1`：用自编译的 `__n1` 头文件

WebKit 和 bun 的 `.cpp` 文件 `#include <cstddef>` 时，找到的是自编译的 `__n1` 版本。
编译出来的符号都 mangle 为 `std::__n1::*`。

**步骤 4：链接**

链接时用 `$CROSS/libcxx/lib/libc++.a`（`__n1` 静态库），所有 `std::__n1::*` 引用都能解析。

**步骤 5：设备运行**

设备 `libc++_shared.so` 是 `__n1` ABI。`.node` 模块 dlopen 解析 bun 导出的
`v8::Array::New(..., std::__n1::function)` → 匹配设备 ✅ → 不崩溃。

### 8.9 缓存

自编译 libcxx 约 10 分钟。用 `actions/cache` 缓存 `$CROSS` 目录，key 为
`ohos-libcxx-n1-llvm21.1.8-1`，只在第一次跑时自编译，后续复用缓存。

WebKit 缓存 key 也改为 `abi-n1`（因为 ABI 变了，旧的 `__1` 编译的 WebKit 不能复用）。

### 8.10 替代方案对比

| 方案 | ABI | v8 profiler | CI 复杂度 | .node 兼容性 |
|---|---|---|---|---|
| 自编译 `__n1`（social4hyq/我们） | `__n1` ✅ | ✅ 正常 | 高（自编译 ~10min） | ✅ 全量 |
| `__h` + V8 stub（springmin） | `__h` | ❌ 空函数 | 低 | ✅ 全量（2 个 v8 函数除外） |
| 裁剪 symbols.dyn（ljy9812） | `__1` | ❌ 不导出 | 最低 | ❌ napi/uv 不导出 |

---

## 9. 术语速查

| 术语 | 通俗解释 |
|---|---|
| **符号（symbol）** | 函数或变量的名字，编译后存在二进制里 |
| **导出（export）** | 把符号放到 `.dynsym` 段，让外部模块能找到 |
| **`.dynsym`** | 动态符号表，存"对外开放"的符号列表 |
| **`--dynamic-list`** | 链接器参数：白名单模式，只列要导出的符号名 |
| **`--version-script`** | 链接器参数：支持 `global:`/`local:`，能控制可见性 |
| **`global:`** | 版本脚本里"要导出"的符号列表 |
| **`local: *`** | 版本脚本里"全部隐藏"（除了 global 列出的） |
| **UND 符号** | 未定义符号，本二进制需要从外部库导入（如 libc 的 `syscall`） |
| **ABI 命名空间** | C++ 的 `__1`/`__n1` 前缀，不同 libcxx 版本用不同前缀 |
| **`.node` 模块** | 编译好的原生插件，通过 `dlopen` 加载，需要从 bun 找到 napi/uv 符号 |

---

*文档日期：2026-08-31 | 分析者：Sisyphus*
*关联文件：`src/symbols.dyn`、`src/linker.lds`、`scripts/build/flags.ts`、`.github/scripts/build-ohos-container.sh`*
*关联 PR：PR #1（方案 A 已验证）、PR #3（当前修复）、PR #4（方案 B 自编译 __n1）*
