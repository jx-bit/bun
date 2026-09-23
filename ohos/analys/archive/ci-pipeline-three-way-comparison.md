# OHOS 编译流水线四方对比分析

> 对比 **我们的流水线**（jx-bit/bun）、**上游官方流水线**（oven-sh/bun）、
> **social4hyq 流水线**（social4hyq/ohos-bun）、**ljy9812 流水线**（ljy9812/bun）的差异。
>
> 日期：2026-08-29

---

## 1. 总体架构对比

### 上游官方（oven-sh/bun bun-v1.4.0）

上游 **没有 OHOS 构建**。上游的 CI 在 BuildKite 上跑（`.buildkite/ci.mjs`），
不在 GitHub Actions 上。上游只构建 Linux (x64/arm64)、macOS (x64/arm64)、
Windows (x64/arm64)。

GitHub Actions 上只有 lint/format/types 检查，没有编译流水线。

### social4hyq（social4hyq/ohos-bun）

social4hyq **不在 GitHub Actions 上编译 OHOS 二进制**。
他们的 GitHub Actions 只有：
- `ohos-full-test.yml` — 在 OHOS 容器里跑测试（用已经编译好的 bottle 二进制）
- 标准 lint/format 检查

OHOS 二进制的编译在 **自托管设备** 上完成（self-hosted runner），
不在 GitHub-hosted runner 上。编译好的二进制通过 Harmonybrew bottle
发布（`brew install social4hyq/core/bun` 会装编译好的二进制）。

### 我们（jx-bit/bun）

我们在 **GitHub-hosted ARM runner** 上编译 OHOS 二进制。
使用 Docker 容器（social4hyq 的 ci-runner 镜像）提供 OHOS 工具链，
在容器内从源码编译 bun。

---

## 2. 三方流水线对照表

| 维度 | 上游 oven-sh | social4hyq | ljy9812 | 我们 jx-bit |
|---|---|---|---|---|
| **CI 平台** | BuildKite | GitHub Actions（测试）+ 自托管（编译） | GitHub Actions | GitHub Actions |
| **OHOS 编译** | ❌ 不支持 | ✅ 自托管设备 | ✅ GitHub-hosted + Docker | ✅ GitHub-hosted + Docker |
| **编译环境** | — | 自托管 OHOS 设备 | Docker 容器（Harmonybrew） | Docker 容器（同 ljy9812） |
| **工具链来源** | — | 设备预装 | 容器内 `brew install` | 同 ljy9812 |
| **WebKit** | prebuilt tarball | prebuilt bottle | 从源码编译 | 从源码编译 |
| **WebKit 版本** | — | `0f966e81` | `caad865e`（旧） | `0f966e81`（v1.4.0） |
| **Rust** | rustup | 设备预装 | 手动下载 | 同 ljy9812 |
| **CI 触发** | BuildKite | `push` + `dispatch` | `push` + `dispatch` | `push` + **`pull_request`** + `dispatch` |
| **ABI** | — | `__1` | `__1` | `__1` |
| **v8 符号** | 全量导出 | 全量导出 | 仅 `Bun__dlopen` | 仅 `Bun__dlopen` |
| **签名** | — | 安装时 | 安装时 | 安装时 |
| **v1.4.0 merge** | — | 已 merge | ❌ 未 merge | ✅ 已 merge |
| **build 脚本** | — | — | 215 行（原始） | 215 行（同 ljy9812） |
| **OHOS workflow 数** | 0 | 1（测试） | 7 | 7（同 ljy9812） |

---

## 3. 我们的流水线详细流程

### 触发条件

```yaml
on:
  push:
    branches: [ohos-aarch64, claude/ohos-*]
  pull_request:
    branches: [ohos-aarch64]       # ← 我们新增的，social4hyq 没有
  workflow_dispatch:
    inputs:
      webkit_ref: ...
```

### 运行环境

- **Runner**: `ubuntu-24.04-arm`（GitHub-hosted ARM64 runner）
- **超时**: 360 分钟
- **并发控制**: `concurrency: cancel-in-progress: true`（同一分支的新 push 取消旧的）

### 容器

```bash
docker pull ghcr.io/social4hyq/ci-runner:latest
docker run -d --name ohos --init \
  --security-opt seccomp=unconfined \
  -v "$GITHUB_WORKSPACE:/workspace/bun" \
  ghcr.io/social4hyq/ci-runner:latest sleep infinity
```

**为什么用 Docker 而不是 GHA `container:`**：
容器是 musl 用户空间（Harmonybrew），GHA 的 Node.js runner 需要 glibc。
用 `docker run` + `docker exec` 绕过这个限制。

**`seccomp=unconfined`**：容器内需要 io_uring（WebKit 编译用到），
默认 seccomp 配置会阻止。

### 容器初始化（5 步）

#### Step 1: 模拟 OHOS 设备路径

```bash
mkdir -p /data/local/tmp /system/bin /system/lib
ln -sf /bin/sh /system/bin/sh
ln -sf /lib/ld-musl-aarch64.so.1 /system/lib/ld-musl-aarch64.so.1
```

bun 的 ELF 的 `PT_INTERP` 指向设备路径 `/system/lib/ld-musl-aarch64.so.1`。
容器里没有这些路径，所以要创建符号链接。

#### Step 2: cargo 配置

```bash
printf '[registries.crates-io]\nprotocol="sparse"\n...' > /root/.cargo/config.toml
```

sparse protocol 加速 crates.io 索引下载。

#### Step 3: brew trust（关键）

```bash
git config --global --add safe.directory <tap_path>
brew tap social4hyq/core
brew trust social4hyq/core
```

**为什么需要 trust**：`brew install --only-dependencies` 会安装 bun.rb formula 的
传递依赖（如 `bun-bootstrap`、`bun-webkit`）。这些传递依赖通过 `depends_on`
加载，不走命令行显式指定——会触发 trust 检查。如果没 trust，brew 静默拒绝
加载（exit 0，不报错）→ 零依赖安装 → 后续 cargo 报 `libssl.so not found`。

**必须先 `git config safe.directory` 再 `brew trust`**：trust 会通过 git 查询
tap 的 origin_url，dubious-ownership（host UID vs container root）会导致
git 查询返回 nil → trust 存了空引用 → 依然不加载传递依赖。

#### Step 4: 安装 brew 依赖

```bash
brew install --only-dependencies --build-bottle social4hyq/core/bun
```

- `--only-dependencies`：只装依赖，不运行 bun 的 install block
- `--build-bottle`：包含 `:build` 标记的依赖（Harmonybrew 的 brew fork
  不识别 `--include-build`，`--build-bottle` 是等效的）

安装后验证每个依赖都装上了（trust 拒绝是静默的）：

| 依赖 | 用途 |
|---|---|
| `llvm@21` | C/C++ 编译器（clang/clang++/lld/llvm-strip/llvm-nm） |
| `ohos-sdk` | OHOS sysroot + 原生库 |
| `icu4c@78` | ICU 国际化库 |
| `bun-bootstrap` | 代码生成用的 bun（跑 generate-classes.ts 等） |
| `openssl@3` | cargo 的 SSL（git2/registry 传输需要） |
| `cmake` + `ninja` | 构建系统 |

#### Step 5: 安装 Rust 工具链

```bash
# 下载 aarch64-unknown-linux-ohos 的 Rust nightly（musl host）
curl -fsSL "https://static.rust-lang.org/dist/2026-07-20/rust-nightly-aarch64-unknown-linux-ohos.tar.gz"
# + rust-src（-Zbuild-std 需要）
```

**为什么不用 rustup**：OHOS 是 Tier 3 目标，rustup 没有 prebuilt `rust-std`，
需要 `-Zbuild-std` 从源码编译 std。

安装到 `/data/storage/el2/base/tmp/rust-nightly-2026-07-20/`（模拟设备路径）。

### WebKit 编译

```bash
# 检出 WebKit fork（pin 在 WEBKIT_REF）
git fetch --depth 1 origin $WEBKIT_REF
git checkout FETCH_HEAD
```

我们用 `--webkit=local` 模式（从源码编译 WebKit），不用 prebuilt tarball。

**WebKit 版本对齐**：`WEBKIT_REF` 必须和 `webkit.ts` 的 `WEBKIT_VERSION` 一致，
否则代码引用的头文件（如 `StrongSet.h`）可能在 WebKit 里不存在。

**缓存**：WebKit 编译结果按 `(WEBKIT_REF, WEBKIT_VERSION, abi-1)` 缓存。
版本不变时复用缓存（跳过 3000+ 个编译步骤，省 ~10 分钟）。

### bun install

```bash
BUN_INSTALL_IGNORE_SCRIPTS=1 bun install  # root
BUN_INSTALL_IGNORE_SCRIPTS=1 bun install  # src/node-fallbacks
```

`BUN_INSTALL_IGNORE_SCRIPTS=1` 跳过 esbuild postinstall：
OHOS 的 Node.js 报 `process.platform = "openharmony"`，
esbuild 不认识 → `Unsupported platform: openharmony` 报错。

esbuild 的原生二进制在后面通过 `ESBUILD_BINARY_PATH` 环境变量解决：
强制安装 `@esbuild/linux-arm64`（静态链接 Go 二进制，musl 可执行）。

### 构建脚本（build-ohos-container.sh）

1. **搭建 cross-libs 脚手架**：把 llvm@21 的 libcxx/libcxxabi/libunwind
   链接到 `build/ohos-cross-libs/`（ABI `__1`）
2. **搭建 ICU**：把 icu4c@78 链接到 `build/ohos-icu/`
3. **设置环境变量**：
   - `LD_LIBRARY_PATH`（openssl/zlib/libxml2）
   - `CC`/`CXX`（raw llvm@21 clang，无签名 shim）
   - `OHOS_SDK_ROOT`/`OHOS_SYSROOT`/`OHOS_LLVM_PREFIX`
   - `GITHUB_SHA`/`GIT_SHA`（容器里没 git，不传会 panic）
4. **esbuild fix**：强制安装 `@esbuild/linux-arm64`，设 `ESBUILD_BINARY_PATH`
5. **Configure**：`bun scripts/build.ts --profile=release --os=ohos --arch=aarch64 --webkit=local --configure-only`
6. **WebKit CMake**：`ninja configure-WebKit`（生成 WebKit 的 build.ninja）
   - 修 `-lpthreads` → `-lpthread`（WebKit CMake FindThreads bug）
7. **Build**：`ninja bun -j2`（容器性能有限，只跑 2 个 job）

### 验证

```bash
# 1. 确认是 ARM64 ELF
file bun | grep "ELF.*arm64"

# 2. v8 未定义符号必须为 0（否则设备崩溃）
readelf --dyn-syms bun | grep -c "_ZN2v8.*UND"  # want: 0

# 3. 只导出 Bun__dlopen
readelf --dyn-syms bun | grep "GLOBAL.*T "
```

### 发布

- 上传 artifact（`bun-ohos-aarch64-github`，保留 90 天）
- 上传到 `ohos-latest` release tag

---

## 4. 与 social4hyq 的关键差异

### 4.1 编译位置

| | social4hyq | 我们 |
|---|---|---|
| 编译位置 | 自托管 OHOS 设备 | GitHub-hosted ARM runner + Docker 容器 |
| 工具链 | 设备预装（Harmonybrew） | 容器内 `brew install` |
| WebKit | prebuilt bottle（`brew install bun-webkit`） | 从源码编译（`--webkit=local`） |
| Rust | 设备预装 | 手动下载 nightly |
| 优势 | 快（不用装工具链） | 不需要设备（CI 上即可跑） |
| 劣势 | 需要维护设备 | 慢（每次 ~35min，从零装工具链） |

### 4.2 WebKit 策略

| | social4hyq | 我们 |
|---|---|---|
| WebKit 来源 | Harmonybrew bottle | `oven-sh/WebKit` fork 从源码编译 |
| 版本控制 | bottle 版本（跟随 brew 更新） | `WEBKIT_REF` + `WEBKIT_VERSION` pin |
| 编译时间 | ~0（用 prebuilt） | ~10 分钟（3000+ 个编译步骤） |
| 缓存 | brew bottle 缓存 | actions/cache（按版本 key） |
| 风险 | bottle 版本和源码不匹配 | WEBKIT_REF 和 WEBKIT_VERSION 不一致 |

### 4.3 CI 触发

| | social4hyq | 我们 |
|---|---|---|
| push 触发 | ✅ `push: [ohos-aarch64]` | ✅ `push: [ohos-aarch64, claude/ohos-*]` |
| PR 触发 | ❌ 无 | ✅ `pull_request: [ohos-aarch64]`（我们新增） |
| 手动触发 | ✅ `workflow_dispatch` | ✅ `workflow_dispatch`（含 webkit_ref 输入） |

我们新增的 `pull_request` 触发是关键改进——PR 提交后自动编译验证，
不需要先合并再发现编译失败。

### 4.4 二进制验证

我们的流水线有一个 social4hyq 没有的验证步骤：
- 检查 `v8 UND = 0`（确保 v8 符号不被导出，避免设备 `__1` vs `__n1` 崩溃）
- 检查只导出 `Bun__dlopen`

这是因为我们用 `symbols.dyn` 的 `local: *` 裁剪策略，
而 social4hyq 用全量导出（他们的 ABI 已匹配，不需要裁剪）。

### 4.5 ABI 策略

| | social4hyq | 我们 |
|---|---|---|
| libcxx ABI | `__1`（Harmonybrew bottle） | `__1`（同 Harmonybrew） |
| v8 符号导出 | 全量（`--dynamic-list` + `--version-script=linker.lds`） | 仅 `Bun__dlopen`（`local: *` 裁剪） |
| 设备 v8 崩溃风险 | 无（ABI 匹配） | 无（设备不解析 v8） |
| napi/uv 导出 | ✅ 全量（`.node` 模块可用） | ❌ 不导出（`.node` 兼容性受限） |

---

## 5. 与上游 oven-sh/bun 的差异

### 5.1 CI 平台

| | 上游 | 我们 |
|---|---|---|
| CI 平台 | BuildKite | GitHub Actions |
| CI 配置 | `.buildkite/ci.mjs` | `.github/workflows/*.yml` |
| OHOS 支持 | ❌ | ✅ |
| 并发控制 | BuildKite agent pool | `concurrency` group |

### 5.2 构建方式

| | 上游 | 我们 |
|---|---|---|
| 目标平台 | Linux/macOS/Windows × x64/arm64 | + OHOS aarch64 |
| 编译方式 | 各种 split CI 模式（rust-only/cpp-only/link-only） | 单 job 全量编译 |
| WebKit | prebuilt tarball | 从源码编译（`--webkit=local`） |
| Rust | rustup + prebuilt std | 手动下载 nightly + `-Zbuild-std` |
| 符号导出 | 全量（`--dynamic-list` + `--version-script`） | 裁剪（`local: *`） |

---

## 5.5 ljy9812/bun 流水线分析

### ljy9812 是什么

`ljy9812/bun` 是 OHOS 适配作者 `ljy9810` 的个人 fork。OHOS 适配的绝大部分
代码（ohos_sign、EPOLLONESHOT、install 回退、CI workflow、build 脚本）
都源自这个仓库。我们的 `jx-bit/bun` 和 `social4hyq/ohos-bun` 的 OHOS 构建
流水线都基于 ljy9812 的原始版本。

### ljy9812 的流水线特点

| 维度 | ljy9812 | 我们 (jx-bit) | 差异 |
|---|---|---|---|
| **CI 平台** | GitHub Actions | GitHub Actions | 相同 |
| **OHOS 编译** | ✅ GitHub-hosted ARM runner + Docker | ✅ 同 | 流水线结构相同 |
| **workflow 来源** | 原始作者 | 从 ljy9812 复制 | 我们基于 ljy9812 的版本 |
| **触发条件** | `push` + `workflow_dispatch` | `push` + `pull_request` + `workflow_dispatch` | 我们新增 `pull_request` |
| **WEBKIT_REF** | `caad865e`（旧版） | `0f966e81`（v1.4.0 新版） | 我们 merge v1.4.0 后升级 |
| **WEBKIT_VERSION** | `caad865e` | `0f966e81` | 同上 |
| **WebKit 一致性** | ✅ REF = VERSION（都是 `caad865e`） | ✅ REF = VERSION（都是 `0f966e81`） | 两边都一致，但版本不同 |
| **build-ohos-container.sh** | 215 行 | 215 行（相同） | 无差异 |
| **OHOS workflow 数** | 7 个 | 7 个（相同） | 无差异 |
| **Cargo.toml ohos_sign** | ✅ 在 workspace | ✅ 在 workspace | 相同 |
| **Cargo.lock ohos_sign** | ❌ 缺失（0 处） | ✅ 有（6 处，我们修复后） | **ljy9812 也有同样的 bug！** |
| **flags.ts OHOS 链接** | `--version-script=symbols.dyn` | 同 | 相同（都用裁剪策略） |
| **v1.4.0 merge** | ❌ 未合并 | ✅ 已合并 | ljy9812 代码是旧版 |

### ljy9812 vs 我们：关键差异

#### 1. `pull_request` 触发（我们新增）

ljy9812 的 workflow 只有 `push` 和 `workflow_dispatch` 触发。
PR 提交后不会自动编译——必须合并后 push 到 `ohos-aarch64` 才会触发。

我们新增了 `pull_request: branches: [ohos-aarch64]`，PR 提交后自动编译验证。

#### 2. WebKit 版本（merge v1.4.0 后升级）

ljy9812 没有合并 v1.4.0，所以代码和 WebKit 版本都是旧的（`caad865e`），
内部一致，不会出现 `StrongSet.h` 找不到的问题。

我们合并 v1.4.0 后，代码引用了新版 WebKit 的头文件（`StrongSet.h`），
但 workflow 的 `WEBKIT_REF` 还是旧的（`caad865e`）→ 不匹配 → 编译失败。
修复：把 `WEBKIT_REF` 从 `caad865e` 升级到 `0f966e81`。

#### 3. Cargo.lock ohos_sign（我们修复了，ljy9812 仍有 bug）

ljy9812 的 `Cargo.toml` 有 `ohos_sign` 在 workspace 成员里，
但 `Cargo.lock` 里没有（0 处引用）。如果 ljy9812 用 `--locked` 编译，
**也会报同样的 `cannot update the lock file` 错误**。

可能 ljy9812 的 CI 没有触发过这个错误，因为：
- 他们的 `rust.ts` 可能在 merge v1.4.0 之前就没有 `--locked`（`--locked` 是
  v1.4.0 的 commit `c418051447 build: pass --locked to cargo (#38863)` 加的）
- 或者他们的 CI 用的是旧版 `rust.ts`，没有 `--locked`

我们 merge v1.4.0 后，`rust.ts` 带来了 `--locked` → 触发了这个 bug → 我们修复了。

#### 4. workflow 文件名差异

ljy9812 保留了一些旧版 workflow 文件名（从上游复制时的旧名称）：
- `clippy.yml` / `lolhtml.yml` / `miri.yml`（3 个独立文件）

我们 merge v1.4.0 后，这些被合并成了一个 `rust-lints.yml`（上游重构）。

### ljy9812 和 social4hyq 的关系

ljy9812 和 social4hyq 是**同一个作者**（`ljy9810`）的两个仓库：
- `ljy9812/bun` — OHOS CI + OHOS 适配代码的原始开发仓库
- `social4hyq/ohos-bun` — OHOS 适配的稳定发布仓库（Harmonybrew bottle 源）

social4hyq 从 ljy9812 的代码发展而来，但两者的策略有分歧：
- ljy9812：在 GitHub Actions 上编译（和我们一样）
- social4hyq：在自托管设备上编译，GitHub Actions 只跑测试

### 四方关系图

```
oven-sh/bun (上游)
    │
    │ merge bun-v1.4.0
    │
    ├── ljy9812/bun (OHOS 适配原始仓库)
    │       │
    │       │ fork / 复制
    │       │
    │       ├── social4hyq/ohos-bun (发布仓库, 自托管编译)
    │       │
    │       └── jx-bit/bun (我们的 fork, GitHub-hosted 编译 + v1.4.0 merge)
    │
    └── (上游不关注 OHOS)
```

---

## 6. 本次修复过程中的 5 个 CI 失败及解决

| # | 失败原因 | 根因 | 修复 |
|---|---|---|---|
| 1 | `Unsupported host platform: openharmony` | merge 取了 v1.4.0 的 config.ts，丢失 OHOS 平台检测 | 从 OHOS base 恢复 4 个文件 |
| 2 | `cannot update Cargo.lock (--locked)` | v1.4.0 的 Cargo.lock 没有 `ohos_sign` | 给 5 个包的依赖列表 + package 条目加 ohos_sign |
| 3 | `mismatched types: expected bool, found ()` | OHOS 回退代码用 `Ok(())` 但 v1.4.0 改了返回类型为 `Result<bool>` | `Ok(())` → `Ok(true)`/`Ok(false)` |
| 4 | `'JavaScriptCore/StrongSet.h' file not found` | `WEBKIT_REF`（旧版 caad865e）和 `WEBKIT_VERSION`（新版 0f966e81）不一致 | `WEBKIT_REF` 对齐到 `WEBKIT_VERSION` |
| 5 | Format/Source lints/mordant fail | 代码格式 + rust.ts buildPlatforms 未同步 ci.mjs | 后续 PR 修（不阻断 OHOS 编译） |

### 修复时间线

```
08:00  push 修复 commit
08:10  失败：bun_install 类型不匹配 (Symlinker.rs)
08:25  push Symlinker 修复
08:50  失败：StrongSet.h 找不到 (WebKit 版本不匹配)
08:58  push WEBKIT_REF 修复
09:33  ✅ OHOS build 成功 (34m43s)
```

---

## 7. 已知遗留问题（后续 PR）

| 问题 | 影响 | 优先级 |
|---|---|---|
| `symbols.dyn` 含 `local: *` | Linux `--dynamic-list` 报错 | P0（Linux 构建阻断） |
| `linker.lds` 含 OHOS shim 符号 | Linux lld `symbol not defined` | P0 |
| `flags.ts` OHOS 链接块用 `--version-script=symbols.dyn` | 污染共享文件 | P0 |
| Highway `HWY_DISABLED_TARGETS` | sourcemap-simd + console-iterator 回归 | P1 |
| EPOLLONESHOT 禁用 | spawn-stdin + 26286 回归 | P1 |
| `ohos_sign` 手动加到 Cargo.lock | 排序可能不完美 | P2（应在能跑 cargo 的环境重新生成） |
| Format/Source lints/mordant | 不阻断编译 | P3 |

---

*文档日期：2026-08-29 | 作者：Sisyphus*
