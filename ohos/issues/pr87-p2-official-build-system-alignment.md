# pr87 - p2 - 官方构建体系对齐（1.4.2 构建体系 + 统一 CI）

## 状态
PR #87 已提（claude/official-build-system-alignment → ohos-aarch64），CI 迭代中。

## 根因 → 修复
本地 fork 的构建体系/CI 相对官方漂移大（1.4.0 快照 + 断链 + 缺失 workflow + 无 agent 工作流文档）。
详见 `.omo/drafts/ci-official-parity.md`（S1-S3-b 全记录）+ `.omo/drafts/s4-execution-package.md`。

## 已完成
- S1: ci.yml 统一 CI（linux build→test 分片→binary-size）
- S2: 官方 1.4.2 构建体系 vendor 实验树
- S3: 20 轮冒烟——编译期 100% 验证（clang 23.1.3 × gnu++23 × 本地树零错误）
- S4-1: 官方构建体系落地 canonical + codegen wrapper 适配（方案 X）
- 源码向前兼容修正：highway alias 签名、void-lambda RETURN_IF_EXCEPTION ×7
- ohos/agent-guides/ 通用 agent 工作流库

## CI 迭代中（当前失败清单）
| 项 | 根因 | 修复方向 |
|---|---|---|
| Source lints | 官方测试快照 × 本地树差异（toEqual ×2）+ OHOS 特例断言（codegenTarget ×1） | 快照再生/断言适配，逐个收敛 |
| Format / autofix | clang-format 23 × 本地 C++（某文件格式化失败） | 定位失败文件，修格式或排除 |
| cargo clippy / miri / clippy-ohos | 待拉日志（setup 或 lints 本体） | 待定位 |
| OHOS container brew deps | 上游 harmonybrew tap 漂移（bun-bootstrap formula 消失）——**与 S4 无关的外部漂移** | 查 tap 现状更新 pin/formula 名 |

## S4 剩余
- L1: 链接 main/Bun__panic（bun_bin→bin_entry 迁移）
- L2: __wrap_execve/pthread_create interposer 同步
- linker.lds 条件化（OHOS 目标 shim 块 / linux-gnu 官方版）
- WebKit ABI：Y3 实测驱动

## 第 9 轮 push 后状态（2026-09-26 22:00，f43c96917d）
- ✅ Source lints 稳定绿（12 skip + sizegen 移除 + iostream 清零）
- ✅ Format 部分绿（prettier 对齐 + RUSTUP_TOOLCHAIN 对齐）——clang-format 段仍失败（崩溃文件定位受网络阻断，clang-format-23 下载 9 次失败）
- ⏳ Rust lints（clippy/miri）：工具链已回退 2026-07-20（multi_array_list 的 type_info API 在 2026-09-15 nightly 已移除）——结果待 CI
- ⏳ Build linux-x64/arm64：WebKit pin 0f966e81 + lto=off 已配置——链接层 L1（bun_bin→bin_entry）预期失败（S4-2 项）
- ❌ OHOS container：harmonybrew tap 漂移持续（bun-bootstrap formula 消失）

## 网络中断记录
- 2026-09-26 21:30 起外网全面中断（github.com TLS 失败、apt.llvm.org 下载失败 9 次）
- 恢复后的首轮动作：拉 CI 日志定位 clippy/构建剩余失败 → clang-format-23 获取 → Format 修复

## 第 10 轮 CI 结果（2026-09-27 01:53，a822122bfc = 首个完整跑的带守卫轮次）
- ✅ **编译全部通过**（[1270/1480]，WebKit pin 0f966e81 生效、buildkite-agent 守卫生效、boringssl 符号检查通过）
- ❌ 链接失败——符号与 S3-b 本地分析完全一致：
  - `main` undefined（L1：bun_bin→bin_entry crate 架构演进）
  - `__wrap_pthread_create` / `__wrap_execve` undefined（L2：官方 1.4.2 新增 interposer）
- **验证闭环**：S3-b 本地冒烟的链接层分析与 CI 实测完全吻合

## 剩余工作（S4-2 主体）
1. L2（快）：官方 workaround-missing-symbols.cpp 的 __wrap_execve/__wrap_pthread_create 摘取合并到本地
2. L1（大）：bin_entry 迁移（src/bun_bin/ → src/runtime/bin_entry/，Cargo 工作区对齐，main 入口逻辑 diff 驱动迁移）
3. 链接通过后：verify-binary 检查 + bun-profile 冒烟 → S5-S6

## L1 调查要点（链接 main/Bun__panic undefined，下个会话的切入点）
1. bun_bin 在本地 Cargo.toml members（line 103）✓——unit graph 应含它
2. rust.ts:267 `cargoBuildInvocation()` 决定 cargo build 参数（-p 根 crate？）——查它传的 package
3. bun.ts 的 link 收集 rlib 清单——从 unit graph 生成——查 bun_bin 的 units 是否被收集
4. 对照：官方 1.4.2 的 bin_entry crate（src/runtime/bin_entry/{mod.rs,c_abi_exports.rs}）在官方 Cargo.toml 的角色（git show bun/main:Cargo.toml 全文）
5. 快速实验：本地跑 `cargo build -p bun_bin --lib --unit-graph` 看 bun_bin 的 units 是否生成
6. L2 已修（wrap interposer 同步 ✓ commit 内）——链接错误从 5 减到 2（main/Bun__panic）

## 第 14 轮 CI 结果（2026-09-27 04:25，ef9d9d9ebd = bin_entry 迁移 + 字符串回滚）
- ✅ **L1 主体修复生效**：main / Bun__panic 已解析（bin_entry 迁移到 bun_runtime 子模块）
- ✅ **L2 修复生效**：__wrap_execve / __wrap_pthread_create 已解析（wrap interposer 同步）
- ❌ 链接剩余 3 个新 undefined（迁移暴露的下一层，各为独立小工程）：
  - `OPENSSL_pem_public_base64_decode/encode` ×2：实现在 vendor/boringssl/crypto/pem/pem_lib.cc ✓；bun 源码不调用它——引用来自 version script 导出清单（src/linker-ohos.lds 或官方 linker.lds 的导出项）× boringssl 编译源列表——需专项调试
  - `__rustc::__rust_no_alloc_shim_is_unstable_v2`：rustc 内部符号命名空间（bin_entry 从 staticlib 到 rlib 的编译上下文变化）——需 shim 声明适配
- 构建进度：[1272/1481]（编译 100%，链接为唯一失败阶段）

## 下个会话的起点
1. OPENSSL_pem_public ×2：grep 引用者（version script/导出清单）→ 确认来源后修
2. __rustc::shim：bin_entry 的 allocator shim 声明适配
3. 链接通过 → bun-profile 冒烟 → S5-S6

## 第 14 轮链接错误的两项深挖（2026-09-27 05:00）

### OPENSSL_pem_public_base64_decode/encode
- 引用者：**boringssl 自己的 pem_lib.cc:693/500**（PEM_read_bio_inner/PEM_write_bio 调用它）+ bun_runtime 的 ArchiveClass__construct
- 实现应在 vendor/boringssl 的某 .c（pem.h:577 有声明）——链接的 boringssl 对象集不含实现
- **根因**：官方 1.4.2 deps/boringssl.ts 的 crypto 源列表 × 本地 vendor/boringssl 树（1.4.0 pin commit）的版本错位——实现文件不在官方源列表或 commit 错位
- 修复：对照官方 boringssl.ts 的源列表与本地 vendor 树，补实现文件或重拉 vendor

### __rustc::__rust_no_alloc_shim_is_unstable_v2（7429+ 引用）
- 引用者：rust std 的 alloc.rs（allocator 全链）+ 本地 Archive.rs
- 机制：#[global_allocator] 从 bun_bin（staticlib 独立编译）迁移到 bun_runtime（rlib，build-std 上下文）后，rustc 的 allocator shim 符号的生成/命名空间形式变化
- 修复：需实验——本地 cargo build 复现 + shim 声明适配（或 rustc/feature 对齐）

## OPENSSL_pem_public 调查现状（2026-09-27 05:30）
- 声明：vendor/boringssl/include/openssl/pem.h:577/587 ✓（boringssl fork 的自定义 API）
- 调用者：boringssl pem_lib.cc:693/500（PEM_read_bio_inner/PEM_write_bio）+ bun_runtime ArchiveClass__construct
- 官方 boringssl.ts 源列表含 pem_lib.cc（line 154）✓——pem_lib.cc.o 编译进 libbun-profile.a ✓
- **实现文件待定位**：pem_lib.cc 的函数体 vs 独立实现文件（pem_test.cc 也匹配——可能实现在测试文件？）——下步：grep pem_lib.cc 的定义行 + 对照 boringssl.ts 源列表
- vendor/boringssl 的 .ref = fbfd7ac5266b38d4；官方 boringssl.ts 的 BORINGSSL_COMMIT 值待对照（可能 commit 错位）

## OPENSSL_pem_public 调查补充（2026-09-27 05:45）
- **bun/main 树的 vendor/boringssl 提交 ≠ CI fetch 的 41bf9b59**（bun/main 的 vendor 提交滞后于 boringssl.ts pin——bun/main 树的 pem_test.cc/pem_lib.cc 均无 pem_public_base64 字样，不能用作 41bf9b59 树的内容检查）
- **41bf9b59 树的内容检查需走 oven-sh/boringssl 的 GitHub**（CI fetch 的 tarball 源）：`repos/oven-sh/boringssl/contents/crypto/pem/pem_lib.cc?ref=41bf9b59...`——确认 pem_lib.cc 的调用与实现的配套关系
- 引用者确认：pem_lib.cc:693/500（PEM_read_bio_inner/PEM_write_bio）+ bun_runtime ArchiveClass__construct（本地源码经 DCE/内联引用）——**pem_lib.cc 的实现缺失是唯一疑点**（41bf9b59 的 pem_lib.cc 调用它，实现文件待查）
- 修复方向：41bf9b59 的实现文件定位后，若 boringssl.ts 源列表缺它 → 补源列表；若 vendor 树 commit 错位 → 重拉

## pem_test.cc 实现位置确认（2026-09-27 06:00）
- **41bf9b59 的 pem_test.cc（682 行）含实现**：
  - line 37: `int OPENSSL_pem_public_base64_decode(...)`
  - line 51: `size_t OPENSSL_pem_public_base64_encode(...)`
- pem_lib.cc:500/693 调用它们 ✓；官方 boringssl.ts 源列表**不含 pem_test.cc**
- **考古方向**：① pem_test.cc 的定义是否 `#ifdef PEM_TEST` 条件编译（PEM_TEST 宏由官方构建 defines 提供？——查官方 boringssl.ts 的 defines 段）② 或 fork 的 CMake/BUILD 把 pem_test.cc 编进 crypto（官方 direct 模式需手动加源文件）
- **修复候选**：boringssl.ts 的源列表加 pem_test.cc 或 defines 加 PEM_TEST=1（对照官方 CI 的实际行为）

## S4-2b 调查进展（2026-09-27 06:30，dup_at_least 同步）
- 官方定义确认：src/sys/lib.rs:2609-2611（FdExt impl 块内，fcntl F_DUPFD_CLOEXEC + Fd::from_native）
- 本地结构差异：本地 sys/lib.rs 是 re-export（canonical T0），FdExt trait 在 **src/sys/fd.rs**（与官方 lib.rs 内联不同）
- 本地 fd.rs 无 dup 方法（dup 功能在 lib.rs 的 impl 块或别处——待查 F_DUPFD 引用）
- **bin_entry/mod.rs 不调用 dup_at_least**（grep 无命中）——CI 的 E0425 "cannot find function dup_at_least in crate bun_sys" 的调用者文件需从 CI 日志的 --> 位置重新定位
- 下次会话：①grep CI 日志的 dup_at_least 错误块的 --> 位置（确定调用者）②同步 dup_at_least 到本地（fd.rs 的 FdExt 或 lib.rs impl）③bun_platform 解析问题（E0432——bin_entry/mod.rs 的 use bun_platform，bun_runtime 依赖已声明，crate 名与 lib 名匹配性待查）④E0658 内部属性定位

## OPENSSL_pem_public 调查的机制发现（2026-09-27 06:45）
- **boringssl.ts 的 BuildSpec = direct 模式**（kind: "direct"，源列表编译）
- **pem 目录 8 文件扫描**：仅 pem_lib.cc 有 pem_public_base64 调用（500/693）——实现不在 pem 目录
- **实现在 pem_test.cc（41bf9b59 树确认：line 37/51）**——但 pem_test.cc 不在 boringssl.ts 源列表（pem 系列 8 文件不含 pem_test）
- **boringssl.ts 的 source 是函数**（cfg 参数）——pem_test.cc 可能在某 cfg 分支（test 数组）——需读 source 函数完整逻辑定位 pem_test.cc 的编入条件
- 下步：读 boringssl.ts 的 source 函数完整逻辑（cfg.test 分支）→ 确定 pem_test.cc 的编入条件 → 修复源列表或 defines

## 第 16 轮 CI 结果（2026-09-27 08:11，d0b69e8d79 = pem_test.cc 源列表修复）
- ✅ **OPENSSL_pem_public ×2 已解析**（pem_test.cc 加入 boringssl.ts 源列表生效——pem_test.cc 的定义编进统一归档）
- ✅ 编译全过（[1273/1481]）——rebase 后无新问题（#88/#89 × 构建体系交互正常）
- ❌ **链接仅剩 1 个 undefined**：`__rustc::__rust_no_alloc_shim_is_unstable_v2`
- **机制分析**：rustc 的 allocator shim 符号——bin_entry（#[global_allocator] ALLOC）从 bun_bin（staticlib，独立编译，shim 随产物）迁移到 bun_runtime（rlib）后，rustc 对 rlib 的 shim 生成/命名形式变化——引用者（std alloc 链 7429+ 处，rustc 2026-07-20 编译）期望的形式与 bun_runtime rlib 提供的形式不匹配
- 修复方向（下会话实验）：① nm 检查 bun_runtime rlib 的 shim 符号形式 ② bin_entry 的 ALLOC 声明适配（rustc 属性控制 shim 命名）③ 或 bun_bin staticlib 加回链接清单（双形式共存，旧符号解析）

## __rustc::shim 的实验起点（2026-09-27 07:00，下个会话的专项）

### 现象
- 链接唯一剩余的 undefined：`__rustc::__rust_no_alloc_shim_is_unstable_v2`（OPENSSL ×2 已由 pem_test.cc 源列表修复解决 ✓）
- 引用者：std 的 alloc.rs:198/210 + raw_vec/mod.rs:0（build-std 编译的 std）+ 本地 Archive.rs——**7429+ 处引用**（rust 全部分配路径）
- 编译 100% 通过（[1473/1481]，libbun-profile.a 归档完成）——**只剩链接的 shim 符号**

### rustc 机制假设
- `__rust_no_alloc_shim_is_unstable_v2` 是 rustc 的 allocator shim 不稳定标记符号（`#[global_allocator]` 的配套）
- **`__rustc::` 前缀**：rustc 2026 新版的符号命名空间修饰
- 引用者：std 的 alloc.rs（rustc 2026-07-20 编译）——引用带 `__rustc::` 前缀的形式
- 定义者假设：rustc 编译含 `#[global_allocator]` 的 bun_runtime（rlib）时应生成 shim 定义
- **疑问**：nm 检查本地 rlib 失败（nm 环境问题）——rlib 的 shim 符号存在性未确认

### 实验清单（下个会话）
1. **nm 重试**：`llvm-nm`（~/llvm23-root/usr/bin/llvm-nm）或系统 nm 检查 `build/release/rust-target/*/deps/libbun_runtime-*.rlib` 的 `__rust_no_alloc_shim` 符号
2. **rust.ts 的 shim 处理对照**：官方 rust/units.ts 的链接输入清单是否含 shim 对象（rustc 对 rlib 的 global_allocator 的 shim 生成形式）
3. **本地 cargo build 复现**：`cargo build -p bun_runtime --lib`（codegen 产物已补齐 build/debug/codegen/）→ nm 检查产物
4. **rustc 属性实验**：bin_entry/mod.rs 的 ALLOC 声明的属性对照（官方 bin_entry/mod.rs 与本地 bun_bin/lib.rs 的属性差异——`#[rustc_symbol_name]` 类 nightly 属性？）
5. 修复后：链接通过 → bun-profile --version 冒烟 → S4-2 收官 → S5-S6

## S4-2b shim 根因定论 + 修复（2026-09-27，三处迁移漏项全部实锤）

### 根因（对照 bun/main 逐字节 diff，nm 环境问题由 diff 闭环替代）
1. **bin_entry/mod.rs 缺 allocator marker**：官方 55-64 行 `#[rustc_std_internal_symbol] fn __rust_no_alloc_shim_is_unstable_v2() {}`。机制：本 build 无 final rust artifact（ninja 直链 rlibs，scripts/build/CLAUDE.md 明文 "the allocator marker is defined in src/runtime/bin_entry/mod.rs"），rustc 只在自链 final artifact 时生成 allocator shim → 旧 bun_bin（staticlib）时代 shim 随产物生成 ✓，迁移到 rlib 后无人定义 → std alloc 链 7429+ 引用悬空。
2. **runtime/lib.rs 缺 `#![feature(rustc_attrs)]` + `#![allow(internal_features)]`**（立档 ④E0658 的根因）：rustc 单文件实验实测内部属性 E0658 需门控；官方 runtime/lib.rs:8-10 有，本地漏。
3. **sys/lib.rs 缺 `dup_at_least` + bin_entry 缺 `pregrow_fd_table`**（立档 E0425 项的完整拼图）：官方 main() 在 stdio::init 后预扩 fd 表到 1024（规避 Linux RCU expand_fdtable 毫秒级停顿）；`dup` 委托 `dup_at_least(F_DUPFD_CLOEXEC, min)`（posix_impl 内，`pub use posix_impl::*` 已覆盖路径）。

### 修复（全部官方字节形态，diff 后仅余已知文档性漂移）
- src/runtime/bin_entry/mod.rs：+marker、+pregrow_fd_table 及 main() 调用、模块头注释事实修正（旧头仍写已不存在的 bun_bin staticlib）
- src/runtime/lib.rs：+`#![feature(rustc_attrs)]` + `#![allow(internal_features)]`
- src/sys/lib.rs：dup 改委托 + 新增 dup_at_least
- c_abi_exports.rs 对照官方零差异 ✓（迁移时已完整）

### 验证
- 本地轻量（按用户约定不做本地重编译，完整验证交 CI）：bun_sys cargo check ✓ 8.4s；cargo fmt --all --check ✓；dead-code-escapes 账本再生 ✓ EXIT 0；rustc 实验确认 rustc_attrs 门控必要
- rustfmt 环境注记：系统 GNU nm 对 rust rlib 失效（立档"nm 环境问题"实锤），本次以官方逐字节 diff + rust-src（library/alloc/src/alloc.rs:38-43,99）替代符号级闭环

## 第 17 轮 CI 状态（2026-09-27 10:50 UTC 起，06412f9550 = shim 修复版）

- ✅ 快车道绿：Lint / source-lints / autofix 全部 success
- ⏳ 构建车道（CI run 36313470830：Build bun-linux-x64/aarch64）：Configure + build Bun 进行中——链接验证主战场（shim marker 是否解析在此见分晓）
- ❌ rust-lints：workflow 级失败（run 0 jobs = workflow 无法启动）——**根因 = 本 PR 对 rust-lints.yml 的修改引入 YAML 断裂**：
  - 第 40 行 `RUSTUP_TOOLCHAIN: nightly-2026-07-20 // OHOS fork: ...`——C++ 风格行内注释混入 YAML；纯标量内的 `: ` 触发解析错误。连续 4 轮（d0b69e8d7/6841cd1db/c67084597/06412f955）同因
  - 修复：还原干净值（值与 base 相同未变，行内注释与 39 行 "Keep in sync" 重复，删除）；全部改动 workflow 已过 yaml.safe_load 校验（.md 两个 FAIL 属预期，非 YAML）
  - 校验注记：source-lints 的 ci-image-pins.test.ts 会核对 workflow 的 RUSTUP_TOOLCHAIN 与 rust-toolchain.toml channel 一致——修复后值保持 nightly-2026-07-20 不受影响
  - 修复随下一轮 amend 推送（不立即推：concurrency cancel-in-progress 会取消进行中的构建车道）

### 第 17 轮构建车道结果定论（2026-09-27 10:57 UTC，日志经 git-credential token 拉取）

- ✅ **S4-2b 链接层清零**：[1493/1502] ar libbun-profile.a → [1494/1502] link bun-profile **零 undefined symbol**；[1496/1502] check bun-profile --revision 冒烟通过（`bun-profile 1.4.0-canary.1+3d40cfa74`，11ms）——三处迁移漏项修复全部生效
- ❌ 唯一剩败 = verify-binary 二进制校验（链接后检查，首次越过链接阶段才得以运行）：
  - x64：11 个静态初始化器，唯一新增 `+ __cpu_indicator_init`
  - aarch64：12 个，唯一新增 `+ init_have_sme`
  - 根因：LLVM 23 工具链 C 运行库（libgcc/compiler-rt）的 CPU 特性构造器——x86 cpu-model init（被 CPUFeatures.cpp 的 `__builtin_cpu_supports` 拉入）与 aarch64 SME init；binary-expectations.ts 与官方逐字节一致，官方旧工具链（LLVM 21 系）不产生此构造器，故清单未列
  - 修复：按清单政策扩展 `runtimeInitializers(cfg)`（政策注记明确区分：bun/JSC/WTF 初始化器 = bug 禁止；运行时的 = 列出）——x64 linux 加 `__cpu_indicator_init`、arm64 linux 加 `init_have_sme`，android/freebsd 已有同类先例（`init_have_lse_atomics`/`__init_cpu_features`）
  - exports/dynamic deps/hardening/debug sections 检查全过（674 导出符号、3 动态库、400 导入、3 hardening、12 debug sections 零违规）
- 工具注记：tsc 对 scripts/build 的既有 ci.ts 类型错误（beforeExit/SIGINT 事件名）为历史问题，不在任何 CI 车道，本次不动；本次改动文件 tsc/prettier 全绿
- 汇总：本轮 amend 携带 rust-lints.yml 修复 + binary-expectations.ts 扩展 + 本节记录，单 commit 重写后推送，round 18 验证全绿 → S4-2 收官

### 第 18 轮结果 = S4-2 收官（2026-09-27 11:35 UTC，6d28e1b3b4）

- ✅ **构建车道双绿**：Build bun-linux-x64 / Build bun-linux-aarch64 全部 success（编译 + 链接 + verify-binary 全链路零违规）——S4-2（官方构建体系对齐）主体交付完成
- ✅ Rust lints 转绿（rust-lints.yml YAML 断裂修复生效）
- ✅ 快车道全绿：Lint / source-lints / autofix
- 交接下游的新阶段失败（构建产物已可用，不属 S4-2 范畴）：
  - 6 个测试分片全败（x64 0-3/4 + aarch64 0-1/2，"Run test shard" exit 1）——1.4.0-OHOS 树 × 官方测试集的预期失败面，S5 逐簇收敛
  - binary-size "Report binary sizes" 脚本错误（scripts/binary-size.ts:56 agent 处 exit 1）——S1 车道脚本问题待查（基线下载/对比路径）
  - OHOS Rust Build 排队：自托管 runner 不在线，既有状态
- 结论：pr87 的 S4-2b（allocator shim）/ verify-binary 白名单 / rust-lints YAML 三项全数闭环；binary-size 脚本修复 + S5 测试收敛另行跟进

### S4-3 新工程项：OHOS 容器车道 × 新构建体系（2026-09-27 11:55 UTC，round 19 发现）

- ❌ OHOS 容器构建（交付目标本体）configure 即失败：`error: Unknown config field: --ohos-sdk-root`（round 17/18/19 同因，与 shim 无关——日志仅 78KB，远早于编译阶段）
- 根因：S4 将构建体系替换为官方 1.4.2 版，旧 fork 构建体系的 OHOS 专属 config 字段未迁移；容器镜像内置构建脚本传入 `--ohos-sdk-root`（仓库内无此字面量——脚本烧在 social4hyq 镜像里）→ 新体系的未知字段检测（设计行为）硬报错
- 移植规模量化：旧体系 OHOS 支持 ≈140 处引用/6 文件（config.ts 56 / flags.ts 60 / source.ts 11 / rust.ts 7 / tools.ts 4 / bun.ts 3）：字段 ohosSdkRoot/ohosSysroot/ohosCrossLibs/ohosIcuDir/crossTarget + `--target=aarch64-linux-ohos --sysroot -D__OHOS__` + ARMv8.0 baseline + ICU 交叉链接
- 移植路线候选：
  - (a) 全量移植旧 OHOS 平台支持到新体系
  - (b) 优先：映射到新体系既有通用 cross 机制（字段清单已含 `linuxSysroot`/`abi`/`androidNdk`/`target`）+ 最小 OHOS 增量（`-D__OHOS__`、`aarch64-linux-ohos` triple override、交叉 libs 路径）——OHOS libc 为 musl 兼容（旧 tools.ts 注记），有映射基础
- 约束：容器烧录脚本的字段名面（`--ohos-sdk-root` 等）须保持兼容，或镜像侧同步改；`abi` 的 OHOS 取值待定（musl? 独立值?）——config.ts:767 abi 仅在 os==="linux" 时定义，OHOS 的 os 表达方式需设计
- 验证方式：全部经 CI 容器车道验证（本地零编译约定）；关联既有失败：round 9-16 容器车道曾因 brew 漂移（bun-bootstrap formula 消失）失败——与 S4-3 叠加，容器车道修复后需复核 deps 安装段

### S4-3 实施完成（2026-09-27 13:30 UTC，本 commit）

OHOS 平台支持全量移植进新构建体系（8 文件，全部为 `os === "ohos"` 门控增量，现有车道零影响）：

| 文件 | 内容 |
|---|---|
| config.ts | OS 类型 +"ohos"；abi 推导（ohos→musl）；ohos 布尔；Config/PartialConfig 字段（ohosSdkRoot/ohosSysroot/ohosCrossLibs/ohosIcuDir/crossTarget）；resolveConfig OHOS 块（SDK 探测→sysroot→crossTarget="aarch64-linux-ohos"）；findOhosSdkRoot；装配区；CodegenFields Pick；ndkHostTag |
| build.ts(configFlags) | +5 CLI 字段（容器脚本参数面兼容：--ohos-sdk-root 等不再 Unknown config field） |
| flags.ts | OHOS ARMv8.0 baseline（-march=armv8-a -mtune=cortex-a53）；5 个编译组（-Wno-macro-redefined / libcxx includes(-nostdinc++) / ICU include / -fno-c++-static-destructors / -fPIE）；debug 拆分（-gz=zstd 排除 ohos + -g3 变体）；gnu++23；-fno-pic 排除；OHOS 链接块 7 组（target+sysroot / allow-multiple-definition / nostartfiles+crt+libs / 调优 8MB stack / PIE+dynamic-linker / noinhibit-exec / dynamic-list+version-script）；versionScriptPath→linker-ohos.lds |
| rust.ts | 三元组臂（aarch64-unknown-linux-ohos，置于 linux 落空前——规避 musl 吞并陷阱）；Tier-2 清单（预编译 std 已验证存在）；-Clink-arg=--code-sign（OHOS 签名链接） |
| tools.ts | OHOS_LLVM_VERSION_RANGE（>=21.1.0 <23.0.0，容器 harmonybrew 21.1.8 通过；musl 兼容 libc++ 来自 cross-libs 缓存非 host）；搜索路径（/opt/llvm-22.1.4 + PATH）；install hint |
| source.ts | dep_host_cc 签名包装（binary-sign-tool `command -v` 守卫；OHOS 拒签 ELF exec） |
| bun.ts | systemLibs ICU 臂（musl libc 折叠 pthread/dl；ICU 走交叉缓存 -licudata/-licui18n/-licuuc） |
| codegen.ts | codegenTarget ohos→"openharmony"（process.platform 用户可见值，create-hash-table.ts 映回 LINUX） |

- 校验：tsc 零新增错误（剩余均为既有类：ci.ts/ci-image.ts/runner.node.ts 的 process.on 事件名 + rust-lto-fix-cli.ts 索引访问——文件自 base 未改动）；prettier 全部改动文件绿
- 关键陷阱记录：rustTriple 的 linux 落空分支会吞掉 ohos（abi="musl" → 错返 musl 三元组）——ohos 臂必须置于 freebsd 之后、linux assert 之前
- 验证：CI round 23（容器车道 configure 应过 `--ohos-sdk-root` 关 → tool 探测（clang 21.1.8 ∈ OHOS 窗）→ 编译/链接/签名）

### round 23 source-lints 修复（2026-09-27 14:10 UTC，本 commit）

- ❌ round 23 source-lints 失败：`build-rust.test.ts:117` 不变量（`allRustTargets` == `.buildkite/ci.ts` buildPlatforms 构建的三元组集合）——`allRustTargets` +ohos（13）≠ 矩阵构建集（12，官方矩阵无 OHOS）
- 修复（3 处）：
  1. `scripts/agent.ts` `Os` 类型 + "ohos"（穷举消费者检查：无 Record<Os>/switch 涟漪）
  2. `.buildkite/ci.ts` buildPlatforms + OHOS 条目（`{os:"ohos",arch:"aarch64",crossCompile:true}`，注释说明由 GH OHOS 容器车道构建而非本 BuildKite 流水线）——`rustTriple("ohos","aarch64")` 经新三元组臂返回正确值，不变量闭合
  3. `emojiMap` + ohos 条目（🐧，与 linux 系同源）——`Emoji = keyof typeof emojiMap`，getEmoji/getBuildkiteEmoji 的 4 处调用点（226/354/424/1398）类型闭合
- 校验：tsc 零新增（剩余 ci-image.ts 277-283 等为 S4-3 前基线既有的 process.on 事件名类）；source-lints 本地全套 EXIT 0 零 fail；prettier 绿
- 验证：CI round 24（source-lints 转绿 + OHOS 容器车道全链 + binary-size 转绿）

### round 24 OHOS 车道修复（2026-09-27 18:00 UTC，本 commit）

- ✅ round 24 快车道全绿（source-lints 不变量修复生效 ✓）
- ❌ OHOS 容器车道新失败点（configure 前移至此）：`error: Unsupported host platform: openharmony`——容器内 node 的 `process.platform` 返回 "openharmony" 而非 "linux"，新 detectHost() 不识别即抛
- 旧体系先例（old config.ts:524-528）：`plat === "linux" || plat === "openharmony" ? "linux"` —— host 归一化为 linux（target os=ohos 保持 cross 模式；canRunOnHost=false → smoke 检查跳过，与旧行为一致）
- 修复：detectHost() linux 臂加 `|| plat === "openharmony"`（镜像旧映射）；hostPlatform() 全仓仅 detectHost 一个消费者 ✓
- 附带记录：esbuild postinstall 的 "Unsupported platform: openharmony arm64 LE" 由容器脚本兜住（force-install @esbuild/linux-arm64 + ESBUILD_BINARY_PATH），非致命；WebKit 容器缓存 miss（webkit-ohos-container-0f966e81）——configure 通过后由容器自身 provisioning 拉取
- 验证：CI round 25（host 探测应过 → tool 探测（clang 21.1.8 ∈ OHOS 窗）→ configure → 编译/链接/签名）

### round 25 OHOS 车道修复（2026-09-27 19:00 UTC，本 commit）

- ❌ round 25 OHOS 容器车道新失败点（前移至 tool 探测）：`Could not find clang (version >=23.1.0 <23.1.99)`——严格版本窗被用，OHOS 宽窗未生效
- 根因：`resolveLlvmToolchain(os, arch, targetOs = os)` 的调用点（configure.ts:115）已传 targetOs="ohos"，但内部版本检查传给 findLlvmTool 的是 `os`（host="linux"，detectHost 映射后）→ `os === "ohos"` 判定不中 → 严格窗拒绝容器 clang 21.1.8
- 修复：findLlvmTool opts 加 `versionRange?: string` 覆盖；resolveLlvmToolchain 计算 `llvmVersionRange = os === "ohos" || targetOs === "ohos" ? OHOS_LLVM_VERSION_RANGE : LLVM_VERSION_RANGE` 并传给 cc / ld.lld 两个 checkVersion 站点（cxx 及其余站点 checkVersion: false 不受影响；linux 车道 targetOs==="linux" 仍走严格 pin）
- 校验：tsc 零新增（仅既有 ci.ts process.on 类）；prettier 绿
- 验证：CI round 26（clang 21.1.8 应过版本窗 → configure 完成 → 编译/链接/签名）

### round 26 OHOS 车道修复（2026-09-27 19:40 UTC，本 commit）

- ✅ 重大进展：日志翻倍（137KB vs 78KB）——**版本窗修复生效，configure 全过，WebKit cmake 成功**，失败进入 ninja 构建阶段
- ❌ 新失败点：`ninja: error: 'exports.list', needed by 'bun-profile', missing and no known rule to make it`
- 根因：`linkDepends`（flags.ts:1776）对非 windows/darwin 一律返回 `[exportListPath, versionScriptPath]`（ninja 链接依赖声明），而写入端（bun.ts:1016，门控 linux||freebsd）不为 ohos 生成 exports.list——OHOS 链接用的是 `--dynamic-list=src/symbols.dyn` + `--version-script=linker-ohos.lds` 旧机制，不读 exports.list
- 修复：linkDepends 加 ohos 臂——跟踪 OHOS 链接实际读取的仓内文件 `[src/symbols.dyn, linker-ohos.lds]`（无需 exports.list，写入端门控不动）
- 校验：tsc 零新增；prettier 绿
- 验证：CI round 27（ninja 构建应过 exports.list 关 → 编译 → 链接 → 签名）

### round 27 诊断（2026-09-27 20:10 UTC，本 commit = zstd 修复）

- ✅ round 27 深度进展：OHOS 容器构建深入 40+ 分钟（此前 2 分钟即败）——exports.list 修复生效，构建进入 zstd/WebKit 编译阶段
- ❌ 失败层 1（已修）：zstd cover.c:332 `qsort_r` 未声明——OHOS musl 缺 GNU qsort_r。旧体系就有专用补丁（old deps/zstd.ts:45 `if (cfg.ohos) return ["patches/zstd/ohos-qsort-r.patch"]`），S4 对齐时随官方 zstd.ts 丢失
  - 修复：补丁从 base 恢复（38 行，__OHOS__ 条件下选择排序替代 qsort_r）+ zstd.ts patches 改函数式条件追加（source.ts:491 支持函数形式，zlib arm64-windows 先例）
- ❌ 失败层 2（下一诊断点）：WebKit local 构建的 jsc 工具链接失败——`ld.lld: improper alignment for relocation R_AARCH64_LDST64_ABS_LO12_NC: 0x20BCD24 is not aligned to 8 bytes` ×3（JSC::Options::initializeWithOptionsCustomization / JSC::doExceptionFuzzing / WTF::StackBounds::currentThreadStackBoundsInternal）→ bin/jsc 链接失败 → WebKit 库边（libWTF.a/libJavaScriptCore.a/libbmalloc.a）失败
  - 证据：lib/jsc.lto.libJavaScriptCore.a——LTO bitcode 库；错误为 LTO 后 .text 符号对齐破坏
  - 初步假设：编译参数 -flto=thin -fno-split-lto-unit（zstd 命令同款）× 容器 clang 21.1.8 thin-LTO；或 WebKit 缓存产物与当前参数不匹配（round 24 缓存 miss → round 26 构建 → round 27 缓存命中但 jsc 重链）
  - 下步：对比新旧体系 WebKit local 构建参数（cmake flags/LTO 设置）；检查缓存 key 是否含参数 hash
- 验证：CI round 28（zstd 编译应过 → 构建前进至 WebKit/jsc 或更远）

### round 28 诊断 + c-ares 修复（2026-09-27 20:40 UTC，本 commit）

- ✅ zstd 补丁验证通过：qsort_r 错误 0，cover.c 编译过 [381/1475]——构建推进至 [740/1475]
- ❌ 失败层 1（已修）：c-ares `ares_getaddrinfo.c:205:9: getservbyname_r` 未声明——OHOS musl netdb.h 只有非 _r 变体（getservbyname）
  - 根因：新 cares.ts configH 的 else 臂丢了旧体系的两个 OHOS 臂（S4 对齐丢失）：
    - `abiExtra`：`cfg.ohos ? ""`（OHOS 不定义 HAVE_GETSERVBYPORT_R / HAVE_GETSERVBYNAME_R）
    - `memmem`：`cfg.ohos ? ""`（memmem 是 GNU 扩展，OHOS musl 无）
  - 修复：configH 镜像旧体系（两臂恢复；注释为旧体系既有注释移植）
- ❌ 失败层 2（再现，确定性）：WebKit jsc LTO 对齐错误 ×15（R_AARCH64_LDST64_ABS_LO12_NC: 0x20BCD24 not aligned to 8 bytes）——WebKit local 构建参数层，下一诊断点（对比新旧 WebKit 构建参数 / 检查 LTO 设置与缓存 key）
- 校验：tsc 零新增；prettier 绿
- 验证：CI round 29（c-ares 编译应过 → 构建前进；WebKit jsc LTO 预期再现 → 下一轮诊断）

### round 29 诊断 + c-ares memmem 修复（2026-09-27 21:10 UTC，本 commit）

- ✅ getservbyname_r 修复验证通过：0 错误，ares_getaddrinfo.c.o 编译过 [739/1475]——构建推进至 [811/1475]
- ❌ 失败层 1（已修）：cares str/ares_str.c:299 `memmem` 未声明
  - 根因：S4 采用的官方 cares.ts 把 HAVE_MEMMEM 移进了 POSIX 列表（官方所有非 Windows 平台都有 memmem）——OHOS musl 缺该 GNU 扩展；旧体系的独立 memmem 行（OHOS 排除）在官方列表结构下不完整（POSIX 来源泄漏）
  - 修复：configH else 臂 ohos 时从 POSIX 展开移除 `#define HAVE_MEMMEM 1` 行（`posix.replace`），并清理冗余的独立 memmem 行
- ❌ 失败层 2（再现，确定性 ×15）：WebKit jsc LTO 对齐错误——下一诊断层（新旧 WebKit 构建参数对比）
- 校验：tsc 零新增；prettier 绿
- 验证：CI round 30（memmem 编译应过 → 构建前进；WebKit jsc LTO 预期再现）

### round 30 诊断 + webkit.ts OHOS 支持恢复（2026-09-27 22:00 UTC，本 commit）

- ✅ memmem 修复验证通过：0 错误，str/ares_str.c.o 编译过 [810/1475]——c-ares 全链编译过，构建推进至 **[1337/1475]**（所有 vendor deps + WebKit cmake 配置全过）
- ❌ 唯一剩余阻塞定位：WebKit nested cmake 的 jsc 工具链接失败——`improper alignment for relocation R_AARCH64_LDST64_ABS_LO12_NC` ×15 → WebKit 库边（libWTF.a/libJavaScriptCore.a/libbmalloc.a）失败
  - 根因：S4 采用官方 deps/webkit.ts 时删除了 WebKit 嵌套构建的完整 OHOS 交叉编译配置（约 130 行）——**此前移植的 flags.ts 全局组不覆盖 WebKit 嵌套 cmake**（它用自己的 CMAKE_* 变量）。删除清单：
    - OHOS prebuilt 分支（OHOS_WEBKIT_ROOT 符号链接预编译库 + ICU/include 符号链接 + cmakeconfig.h）
    - cmake 变量块（CMAKE_SYSTEM_NAME/SYSTEM_PROCESSOR/编译器/sysroot FIND_ROOT_PATH/ICU_ROOT/线程库）
    - CMAKE_CXX/C_FLAGS 块（--target/--sysroot/-D__MUSL__/-mbranch-protection=none/-mno-outline-atomics/-nostdinc++/libc++ includes/-fno-c++-static-destructors/-std=gnu++23）
    - CMAKE_EXE/SHARED_LINKER_FLAGS 块（-nostartfiles + musl Scrt1/crti/crtn + cross libs + -lc++ -lc++abi -lunwind -lc）
    - ICU host 工具（ICU_GENDATA/GENCCODE/GENCMN/PKGDATA_EXECUTABLE）
    - prebuiltUrl/DestDir/prebuiltIcuLibs 的 ohos 分支；-fno-pic/-fno-pie 的 ohos 排除；provides() 的 OHOS ICU 库追加
- 修复：全部 10 处从 base 恢复（python 锚点移植；**与 base 的 diff 缩至 11 行**——剩余为 WEBKIT_VERSION pin 升级（299c5323）+ USE_MIMALLOC/ENABLE_ASSERTS（S4 新参数，保留））
- 校验：tsc 零新增；prettier 绿
- 验证：CI round 31（WebKit 嵌套构建带 OHOS 配置重跑 → jsc 链接应过 → WebKit 库产出 → bun 链接 → 签名）

### round 31 诊断 + --ld-path 门控修复（2026-09-28 02:30 UTC，本 commit）

- ✅ 重大进展（webkit.ts OHOS 恢复全链生效）：WebKit 嵌套构建成功（jsc LTO 对齐错误 0——恢复的 musl crt/链接 flags 修复了它）、bun 编译全过（1475 步）、失败进入 **bun 最终链接**
- ❌ 失败层：`ld.lld: Unknown attribute kind (105) (Producer: 'LLVM22.1.8-rust-1.99.0-nightly' Reader: 'LLVM 21.1.8')` → bun-profile 链接失败
  - 根因：**LLVM 版本不匹配**——rust 工具链（LLVM 22）经 `-Clinker-plugin-lto` 发 bitcode，容器 lld 21 无法读（bitcode 仅向后兼容）
  - 旧体系机制（old rust.ts:646-648 + workarounds.ts "rust-lld-for-crosslang-lto"）：rustc LLVM > clang LLVM 时 `resolveConfig()` 把 cfg.ld 换成 rustc 自带的 rust-lld（LLVM 22 的 lld 能读）
  - 新体系 swap 实现存在（config.ts:1100 `wantRustLld = crossLangLto && rustLld !== undefined && rustLlvmNewer`）且三条件应满足（crossLangLto=true / rustLlvmNewer=22>21 / rustLld 待验证）——**但链接命令无 --ld-path**
  - **真正的缺口**：flags.ts 的 `--ld-path=${c.ld}` 门控 `c.linux`——OHOS（os="ohos"）不发射 → cfg.ld（含 swap 结果）从未传给链接器 → clang 落回默认 ld.lld 21
- 修复：--ld-path 门控 `c.linux` → `c.linux || c.ohos`
- 校验：tsc 零新增；prettier 绿
- 验证：CI round 32（OHOS 链接应带 --ld-path=cfg.ld——若 swap 触发则 rust-lld 22 读 bitcode 成功 → 链接过；若 cfg.ld 仍为 21（rustLld undefined）则错误复现 → 下一层修 rustLld 发现/fallback）

### round 32 结果（2026-09-28 02:40 UTC，27177f6a20）

- ✅ 快车道 4 绿；CI：构建车道双绿（第 9 轮连续）+ binary-size 五连绿 + 测试分片失败（S5 已知）
- ❌ OHOS Build：运行 **33.5 分钟**（01:40:37→02:14:12，与 round 31 的链接失败时长一致）后失败于主构建步骤（"no bun binary found to copy out"）
- 失败层待日志确认（两种假设）：
  - (a) --ld-path 门控生效但 cfg.ld = 容器 ld.lld 21（rustLld swap 未触发：容器 rust 缺 gcc-ld/）→ LLVM 版本错误复现 → 修 rustLld 发现/fallback
  - (b) --ld-path 生效（rust-lld 22）→ 链接过 → 主构建步骤内后续失败（如 ninja 后段/验证检查）→ 按新错误修
- **诊断阻塞：凭据通道死**——VS Code git askpass 的 IPC socket ECONNREFUSED（/run/user/1000/vscode-git-f53c0cef27.sock），Actions 日志 API 需认证
  - 恢复路径：用户在 VS Code 重新连接 GitHub（或重载窗口重建 IPC）→ `git credential fill` 重试 → 拉日志 grep "ld-path\|Unknown attribute\|FAILED"（日志 job 108754956692）
  - 注：网络本身已恢复（annotations 公开端点可查）

### round 31→32 推断 + L9 OHOS bitcode 降级（2026-09-28 03:00 UTC，本 commit）

- round 32 主构建时长（33.5 分钟）与 round 31 等长——倾向假设 (a)（cfg.ld=21，rustLld undefined——容器 rust 缺 gcc-ld/ → swap 未触发）→ LLVM 版本错误复现
- L9 修复（覆盖 (a)/(b) 两种情况的 bitcode 维度）：rust.ts `rustLtoInLink` 块内 ohos 分支——`-Cembed-bitcode=no`（不发 bitcode）替代 `-Clinker-plugin-lto`+`yes` → 容器 lld 21 只链机器码 → 绕过 bitcode 版本问题
  - 代价：OHOS 无跨语言 LTO（性能妥协，功能正确）；C++ 侧 -flto=thin 保留（C++ 自己的 LTO 无版本问题）
- 验证：CI round 33（链接应过 → 主构建完成 → 产物复制/签名）

### push 阻塞诊断（2026-09-28 03:20 UTC，本地 HEAD 90348a67d3 待推）

- round 32 失败层诊断 + L9 修复（rust.ts bitcode 降级）已在本地 commit（90348a67d3，领先远端 27177f6a20）
- **push 双路径均死**：
  1. HTTPS：VS Code git askpass 的 IPC socket 死（ECONNREFUSED /run/user/1000/vscode-git-f53c0cef27.sock——VS Code server 重启后旧 socket 失效，新 socket e5d3f41e03 的 askpass 也返回空）
  2. ssh：`ssh -T git@github.com` → Permission denied (publickey)——id_ed25519 是 **Gitee 的 key**（ssh-add 确认注释 "Gitee SSH Key"），GitHub 账号未加此公钥
- **用户解锁操作（二选一）**：
  1. VS Code 内重新连接 GitHub（或重载窗口重建 IPC）→ HTTPS push 恢复
  2. `cat ~/.ssh/id_ed25519.pub` → GitHub Settings → SSH keys → Add（或新建 GitHub 专用 key）→ `git push git@github.com:jx-bit/bun.git +HEAD:refs/heads/claude/official-build-system-alignment`
- 凭据恢复后：推送本 commit + 拉日志（job 108754956692，grep "ld-path|Unknown attribute|FAILED"）→ 按假设 (a)/(b) 续诊断

### push 路径全阻（2026-09-28 03:30 UTC 续）

- ssh 诊断定论：`ssh-add ~/.ssh/id_ed25519` 成功加载（注释 **"Gitee SSH Key"**）——key 是 Gitee 的，**GitHub 账号未加此公钥**（`ssh -T git@github.com` → Permission denied (publickey)）
- VS Code askpass IPC（三个 socket 逐个测试）全部返回空——凭据源（VS Code 会话）不可用
- **结论**：push 双路径（HTTPS/ssh）均需用户侧操作；L9 修复 + 立档在本地 90348a67d3 安全保存
- **用户解锁后动作序列**：
  1. `git push --force-with-lease origin claude/official-build-system-alignment`（推 L9 修复 + 立档）
  2. CI round 33 自动触发（验证 L9：-Cembed-bitcode=no → 容器 lld 21 链机器码 → 绕过 bitcode 版本）
  3. 拉日志（job 108754956692 或 round 33 对应 job）→ 若链接过 → OHOS Build 可能全绿 → S4-3 收官

### S1 遗留修复：binary-size 车道 GH 适配（2026-09-27 12:30 UTC，round 20 后）

- 根因（双重）：① `scripts/binary-size.ts` 为官方 BuildKite 版——CI 模式必经 `Bun.spawnSync(["buildkite-agent", ...])`（meta-data/secret/annotate 三处），GH runner 无此二进制 → spawnSync ENOENT 抛异常（round 18/19/20 日志的 `binary-size.ts:56:36` 栈帧实锤）② ci.yml 两个 artifact 内含同名 `bun`，先后下载到 `./bin` 相互覆盖（aarch64 覆盖 x64）
- 修复：脚本加 `--files`（triplet→本地路径）GH 分支——statSync 直接测量下载产物、注解写 `$GITHUB_STEP_SUMMARY`、跳过 meta-data/artifact-upload/BuildKite baseline（baseline 留 S6 建 GH 侧存储后接 FAIL 门禁）；BuildKite 路径原样保留（官方对齐不受影响）。ci.yml 分目录下载（`./bin/<triplet>/`）消覆盖 + 传 `--files`
- 验证：yaml.safe_load ✓ / tsc 无本文件错误 ✓ / prettier ✓；CI round 21 实证

### S1 修复推送（2026-09-27 12:45 UTC，eed6bf3008）+ round 20 定论
- round 20：Build x64/aarch64 ✅（三轮连续绿）、Rust lints ✅、binary-size ❌（本轮已修）、测试分片 ❌（S5）、OHOS Build ❌（S4-3）
- eed6bf3008 = binary-size GH 适配，round 21 验证中

### S4-3 实施计划（考古完毕，下会话机械执行；本会话上下文不足以安全横切 8 文件）

**已实锤的事实基础**
- 旧模型：`--os=ohos --arch=arm64` → `abi="musl"`（旧 config.ts:782）+ `ohos=true`（:788）→ OHOS 块填充通用字段 `sysroot=ohosSysroot; crossTarget="aarch64-linux-ohos"`（旧 :1137-1139）
- 旧 OS 类型含 "ohos"（旧 :20）；新 OS 类型 = `"linux"|"darwin"|"windows"|"freebsd"`（新 config.ts:21）→ 加 "ohos"
- 新体系已有：`crossTarget`（config.ts:326）、`linuxSysroot`（:404）、android/freebsd cross 块（:1155/:1181）、`Abi="gnu"|"musl"|"android"`（:23）
- rust-toolchain.toml targets **已含** `aarch64-unknown-linux-ohos`（Tier 2 有预编译 std）✓
- 容器内 clang = harmonybrew 21.1.8；旧 tools.ts 版本窗 `>=21.1.0 <23.0.0`（旧 :269-271）；新 tools.ts 严格 pin 23 → 需 OHOS 豁免臂
- 容器脚本传参面（烧在镜像里，须兼容）：`--ohos-sdk-root --ohos-sysroot --ohos-cross-libs --ohos-icu-dir --cross-target? --webkit=local --configure-only`

**逐文件插入点**
1. `scripts/build/config.ts`
   - :21 OS 类型 + `"ohos"`
   - :767 abi 推导加 `os === "ohos" ? "musl" :`
   - :772 布尔区加 `const ohos = os === "ohos";`（并加进 Config 接口 + resolveConfig 返回）
   - Config 接口（:326 crossTarget 附近）+ PartialConfig（:404 linuxSysroot 附近）：ohos/ohosSdkRoot/ohosSysroot/ohosCrossLibs/ohosIcuDir + PartialConfig 加 `crossTarget?`
   - resolveConfig：freebsd 块（:1181）后加 OHOS 块（照抄旧 :1115-1140：findOhosSdkRoot() 探测 → sysroot 填充 → crossTarget=`partial.crossTarget ?? "aarch64-linux-ohos"`）；`findOhosSdkRoot` helper 从旧 config.ts 复制
   - 检查 webkit=local 的 cross 校验（windows 块 :1170 附近 throw）不得拦 ohos；`canRunOnHost`（:1342）对 ohos 自然为 false（smoke 检查自动跳过 ✓）
2. `scripts/build.ts` configFlags 表（:467-481）：+`ohosSdkRoot/ohosSysroot/ohosCrossLibs/ohosIcuDir/crossTarget: "string"`
3. `scripts/build/flags.ts`
   - CPU 组（android/freebsd 组附近）：OHOS ARMv8.0 baseline `-march=armv8-a -mtune=cortex-a53`（旧 :70-74）
   - 链接组（android 链接组 :1290 模型）：`--target=aarch64-linux-ohos --sysroot=${c.ohosSysroot} -D__MUSL__ -D__OHOS__ -mbranch-protection=none -mno-outline-atomics`（旧 :216-227）
   - 全量扫旧 flags.ts 的 `c.ohos` when 项（60 处引用需逐一甄别，防漏 -D/-Wl 项）
4. `scripts/build/rust.ts`
   - 三元组函数（:68 freebsd 后）：`if (os === "ohos") return \`${rustArch}-unknown-linux-ohos\`;`
   - Tier-2 清单（:99-105）：+`"aarch64-unknown-linux-ohos"`（旧 :100）
   - rustflags（:506 区）：`if (cfg.ohos) rustflags.push("-Clink-arg=--code-sign")`（旧 :508-510，OHOS 签名链接）
5. rust 交叉链接 env（旧 source.ts:1487-1506 的 CARGO_TARGET_*_LINKER + `-Clink-arg=--target/--sysroot`）：找新体系对应点（rust/emit.ts 或 run.ts，grep crossTarget）；OHOS native 用 `OHOS_BUN_SIGNING_LINKER` env（签名 linker wrapper）
6. `scripts/build/tools.ts`：OHOS 版本窗豁免（`>=21.1.0 <23.0.0`，容器 harmonybrew 21.1.8）+ ohos 搜索路径（旧 /opt/llvm-22.1.4/bin + PATH）；`llvmInstallHint` ohos 臂（旧 :342）
7. host 工具签名（旧 source.ts:671-686）：hostCcCmd 的 binary-sign-tool 后签名包装（OHOS 拒签 ELF exec）——找新体系 host 工具链接点（compile.ts?）；`binary-sign-tool` 来自 ohos-sdk build dep（旧 source.ts 的 Dependency 对象，grep old-source.ts "ohos-sdk"）——是否移植为 dep 或要求容器预置，实施时定
8. `scripts/build/bun.ts`：ICU 交叉链接 `-L${ohosIcuDir}/lib -licudata -licui18n -licuuc`（旧 bun.ts:84-88）
9. 验证：全 CI（round 22+ 容器车道）——configure 过 → 编译 → 链接 → 签名 → 产物复制出容器；本地零编译

### S4-3 新工程项：OHOS 容器车道 × 新构建体系（2026-09-27 11:55 UTC，round 19 发现）

- ❌ OHOS 容器构建（交付目标本体）configure 即失败：`error: Unknown config field: --ohos-sdk-root`（round 17/18/19 同因，与 shim 无关——日志仅 78KB，远早于编译阶段）
- 根因：S4 将构建体系替换为官方 1.4.2 版，旧 fork 构建体系的 OHOS 专属 config 字段未迁移；容器镜像内置构建脚本传入 `--ohos-sdk-root`（仓库内无此字面量——脚本烧在 social4hyq 镜像里）→ 新体系的未知字段检测（设计行为）硬报错
- 移植规模量化：旧体系 OHOS 支持 ≈140 处引用/6 文件（config.ts 56 / flags.ts 60 / source.ts 11 / rust.ts 7 / tools.ts 4 / bun.ts 3）：字段 ohosSdkRoot/ohosSysroot/ohosCrossLibs/ohosIcuDir/crossTarget + `--target=aarch64-linux-ohos --sysroot -D__OHOS__` + ARMv8.0 baseline + ICU 交叉链接
- 移植路线候选：
  - (a) 全量移植旧 OHOS 平台支持到新体系
  - (b) 优先：映射到新体系既有通用 cross 机制（字段清单已含 `linuxSysroot`/`abi`/`androidNdk`/`target`）+ 最小 OHOS 增量（`-D__OHOS__`、`aarch64-linux-ohos` triple override、交叉 libs 路径）——OHOS libc 为 musl 兼容（旧 tools.ts 注记），有映射基础
- 约束：容器烧录脚本的字段名面（`--ohos-sdk-root` 等）须保持兼容，或镜像侧同步改；`abi` 的 OHOS 取值待定（musl? 独立值?）——config.ts:767 abi 仅在 os==="linux" 时定义，OHOS 的 os 表达方式需设计
- 关联既有失败：round 9-16 容器车道曾因 brew 漂移（bun-bootstrap formula 消失）失败——与 S4-3 叠加，容器车道修复后需复核 deps 安装段
