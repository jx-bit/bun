# 4 个文件丢失与恢复详解 — 写给初学者

> 用最通俗的语言解释：merge 时丢了什么、为什么丢、social4hyq 怎么做的、怎么修最优。

---

## 背景知识：什么是 merge 冲突？

想象两个人同时改同一份文档：

```
原始文档（merge-base）:     "Bun 运行在 Linux 上"
甲改了（OHOS base）:         "Bun 运行在 Linux 和 OHOS 上"
乙改了（bun-v1.4.0）:        "Bun 运行在 Linux、macOS 和 Windows 上"
```

两个人都改了同一句话，git 不知道该用谁的 → 这就是**冲突**。

merge bun-v1.4.0 时，4 个文件发生了这种冲突。我当时用 `--theirs`（取上游版本）解决，
相当于**完全用了乙的版本，丢弃了甲的全部改动**。结果 OHOS 相关的功能全丢了。

后来我从 OHOS base（merge 之前的状态）把这 4 个文件**原封不动复制回来**，CI 能 configure 了，
但这只是"回到 merge 前"，不是最优方案。

---

## 4 个文件分别发生了什么

### 文件 1：`scripts/build/config.ts`（构建配置）

**这个文件是干什么的**：告诉构建系统"你在什么平台上编译"。Bun 运行 `bun run build` 时，
这个文件会检测当前操作系统（Linux/macOS/Windows/FreeBSD）和 CPU 架构（x64/arm64），
然后生成对应的编译参数。

**OHOS base 改了什么（+116 行）**：
- 新增 `"ohos"` 平台类型（原来只有 linux/darwin/windows/freebsd）
- 新增 `ohos: boolean` 配置字段
- 新增 OHOS SDK 路径字段（`ohosSysroot`、`ohosSdkRoot`、`ohosCrossLibs`、`ohosIcuDir`）
- 新增 `openharmony` → `linux` 的平台映射（OHOS 系统的 Node.js 报告自己是 "openharmony"，
  需要映射成 "linux" 才能进入 Linux 的构建路径，然后再切换到 OHOS 目标）
- 新增整个 OHOS SDK 解析逻辑（找 sysroot、找 cross-libs、找 ICU）

**v1.4.0 改了什么（+65 行）**：
- 新增 `localDeps` 功能（从本地 checkout 构建依赖，不从远程下载）
- 新增 `writeFileSync` import
- 改了 `baseline` 字段的注释
- 其他小幅重构

**merge 时发生了什么**：两个版本都改了同一区域（Config 接口定义、resolveConfig 函数），
产生了冲突。我取了 v1.4.0 版本 → **OHOS 平台检测全丢** → CI 报 `Unsupported host platform: openharmony`。

**修复**：从 OHOS base 恢复了整个文件 → CI 能检测 OHOS 平台了。

**social4hyq 怎么处理的**：和我们的 OHOS base 版本**基本一致**——同样有 `"ohos"` 类型、
OHOS Config 字段、平台映射。这个文件两者对齐了。

**最优合并方案**：
- 以 OHOS base 版本为基础（保留全部 OHOS 逻辑）
- 手动把 v1.4.0 的 `localDeps` 功能加回去（约 10 行，加到 Config 接口和 resolveConfig 里）
- 手动把 v1.4.0 的 `writeFileSync` import 加回去（1 行）
- 工作量：约 15 行手动合并，不复杂

---

### 文件 2：`scripts/build/rust.ts`（Rust 编译配置）

**这个文件是干什么的**：告诉 cargo（Rust 的编译器）用哪个 target triple（目标三元组），
比如 `x86_64-unknown-linux-gnu` 或 `aarch64-unknown-linux-ohos`。

**OHOS base 改了什么**：
- 在 `rustTarget()` 函数里加了 OHOS 分支：
  ```ts
  if (cfg.ohos) return `${arch}-unknown-linux-ohos`;
  ```
  这样 cargo 就知道要编译 OHOS 目标了。

**v1.4.0 改了什么**：
- 把 `rustTarget()` 重构了——拆成 `rustTarget()` + `rustTriple()` 两个函数
  （原来只有一个函数，用 `cfg` 参数；新版拆成一个用 `cfg`、一个用独立的 `os/arch/abi` 参数）
- 新增 `canCrossCompileFromLinux()` 函数（判断能否从 Linux 交叉编译）
- 新增 `buildPlatforms` 列表（CI 构建的所有平台 triple）

**social4hyq 额外有什么（我们没有的）**：
```ts
// 1. buildPlatforms 列表包含 OHOS triple
"aarch64-unknown-linux-ohos",

// 2. Tier 3 triple 分类包含 OHOS
triple === "aarch64-unknown-linux-ohos"  // isTier3()

// 3. OHOS 签名链接器！
if (cfg.ohos) rustflags.push(`-Clink-arg=--code-sign`);
cfg.ohos && process.env.OHOS_BUN_SIGNING_LINKER
  ? process.env.OHOS_BUN_SIGNING_LINKER
  : cfg.cxx
```

这意味着 social4hyq 在 **Rust 编译时就自动签名**了二进制（通过 `--code-sign` rustflag），
而我们是在 **spawn 时签名**（运行时检测到 ELF 就签）。两种方式不同：

| | 我们的方式（spawn 时签名） | social4hyq 的方式（编译时签名） |
|---|---|---|
| 时机 | 运行时，spawn 子进程前 | 编译时，链接阶段 |
| 优点 | 能签动态下载的二进制 | 一次签好，不用每次 spawn 检查 |
| 缺点 | 每次 spawn 都要检查 ELF | 需要签名链接器工具链 |

**最优合并方案**：
- 以 v1.4.0 的重构版本为基础（保留 `rustTriple()` 拆分 + `canCrossCompile` + `buildPlatforms`）
- 在 `rustTriple()` 里加 OHOS 分支：`if (os === "ohos") return \`${rustArch}-unknown-linux-ohos\``
- 在 `buildPlatforms` 列表里加 `"aarch64-unknown-linux-ohos"`
- 在 Tier 3 分类里加 `aarch64-unknown-linux-ohos`
- 考虑是否引入 social4hyq 的 `--code-sign` rustflag（需要签名链接器工具链，当前 CI 可能有）
- 工作量：约 20 行改动

---

### 文件 3：`src/runtime/cli/run_command.rs`（bun run 命令）

**这个文件是干什么的**：处理 `bun run xxx` 命令——找到 shell、设置环境变量、启动子进程。

**OHOS base 改了什么**：
- 新增 `ohos_set_pwd()` 函数：
  ```rust
  #[cfg(target_env = "ohos")]
  pub(crate) fn ohos_set_pwd(env: &mut DotEnv::Loader, cwd: &[u8]) {
      let pwd = if cwd == b"/" || cwd.is_empty() {
          bun_core::env_var::HOME::get().unwrap_or(cwd)
      } else { cwd };
      env.map.put(b"PWD", pwd).expect("unreachable");
  }
  ```
  **为什么需要这个**：OHOS 的 hmdfs 文件系统上 `getcwd()` 会失败（返回 EACCES）。
  bash 用 `getcwd()` 验证当前目录，如果失败就报错退出。`ohos_set_pwd()` 把 `$PWD`
  环境变量设好，让 bash 用 `stat($PWD)` 代替 `getcwd()` 来验证目录——绕过 hmdfs 的 bug。

- 在 `configure_env_for_run` 里调用 `ohos_set_pwd()`：3 个 `#[cfg(target_env = "ohos")]` 门控

**v1.4.0 改了什么**：
- 新增 `ConfigureEnvOptions` 结构体（把两个 bool 参数打包成一个 struct）
- 重构了 `configure_env_for_run` 的签名
- 其他重构

**social4hyq 有什么不同**：
- 有 **7 个** `#[cfg(target_env = "ohos")]` / `#[cfg(not(target_env = "ohos"))]` 门控
  （我们只有 3 个）
- social4hyq 可能涵盖了更多 OHOS 边界 case：
  - EPERM 回退（read_dir EPERM → 回退到 $HOME）
  - 信号处理差异
  - 环境变量传递差异

**最优合并方案**：
- 以 v1.4.0 版本为基础（保留 `ConfigureEnvOptions` 重构）
- 把 `ohos_set_pwd()` 函数加回去（约 10 行）
- 在 `configure_env_for_run` 的对应位置加 `#[cfg(target_env = "ohos")] ohos_set_pwd(env, cwd);`（约 3 处）
- 对比 social4hyq 的 7 个 gate，补上我们缺少的 4 个（需要逐个分析 social4hyq 代码）
- 工作量：约 30 行改动 + social4hyq 代码对比

---

### 文件 4：`src/standalone_graph/StandaloneModuleGraph.rs`（独立模块图）

**这个文件是干什么的**：处理 `bun build --compile` 生成的独立可执行文件。
编译后的 bun 二进制里有一个 `.bun` 段（section），存着打包的模块代码。
运行时这个文件负责从二进制里找到并读取 `.bun` 段的内容。

**OHOS base 改了什么**：
- 新增 OHOS PIE load base 处理：
  ```rust
  #[cfg(target_env = "ohos")]
  {
      // 方式1：打开 /proc/self/exe + 按文件偏移定位 .bun 段 + mmap
      if let Some(data) = ohos_primary_get_data() { return Some(data); }
  }
  #[cfg(target_env = "ohos")]
  let target = {
      // 方式2：扫 /proc/self/maps 找 PIE 基地址
      let load_base = ohos_pie_load_base()?;
      (load_base.wrapping_add(vaddr as usize)) as *mut u8
  };
  #[cfg(not(target_env = "ohos"))]
  let target = vaddr as *mut u8;
  ```
  **为什么需要这个**：OHOS 的二进制是 PIE（位置无关可执行文件），运行时的实际内存地址
  和编译时的虚拟地址不同（内核会随机偏移）。标准方式用 `dlpi_addr` 获取偏移量，
  但 OHOS 的 hmdfs 文件系统使这个方式失效。所以需要用 `/proc/self/maps` 手动扫描。

- 新增 `ohos_primary_get_data()` 和 `ohos_pie_load_base()` 两个辅助函数（约 150 行）

**v1.4.0 改了什么**：
- 改用 `bun_sys::elf::find_loaded_module()` 获取 load bias（标准方式）
- 改了注释

**social4hyq 有什么不同**：
- 也有 `#[cfg(target_env = "ohos")]` 门控
- 引用了 "springmin/bun ohos-aarch64 @ 39d8416e" 的实现
- 实现细节可能不同（需要逐函数对比）

**最优合并方案**：
- 以 v1.4.0 版本为基础（保留 `find_loaded_module` 标准方式用于非 OHOS）
- 把 OHOS 的 `ohos_primary_get_data()` + `ohos_pie_load_base()` 加回去（约 150 行）
- 在 `get_data()` 里加 `#[cfg(target_env = "ohos")]` 分支（约 15 行）
- 对比 social4hyq 的实现，看是否有更新版本
- 工作量：约 170 行改动（主要是复制已有代码 + 加 cfg gate）

---

## 3-way 合并的最优策略

### 总原则

```
最优 = v1.4.0 上游改进 + OHOS 专属功能 + social4hyq 的 OHOS 演进
```

不是简单取某一方的版本，而是**三方各取所长**。

### 每个文件的具体策略

| 文件 | 基础版本 | 要加回的 OHOS 改动 | 要加回的 v1.4.0 改动 | 要参考的 social4hyq 改动 |
|---|---|---|---|---|
| `config.ts` | OHOS base（OHOS 逻辑完整） | — | `localDeps`(10行)、`writeFileSync`(1行) | 确认对齐 |
| `rust.ts` | v1.4.0（重构更好） | OHOS triple(3行) | — | `--code-sign`签名(5行)、Tier3(2行)、buildPlatforms(1行) |
| `run_command.rs` | v1.4.0（重构更好） | `ohos_set_pwd`(10行)、3处gate(6行) | — | 4个额外gate(需分析) |
| `StandaloneModuleGraph.rs` | v1.4.0（标准方式） | PIE函数(150行)、cfg gate(15行) | — | 确认实现等价 |

### 实现步骤

```
Step 1: config.ts — 以 OHOS base 为基础，手动加 v1.4.0 的 localDeps
Step 2: rust.ts — 以 v1.4.0 为基础，手动加 OHOS triple + social4hyq 签名
Step 3: run_command.rs — 以 v1.4.0 为基础，手动加 ohos_set_pwd + 补 social4hyq 的 gate
Step 4: StandaloneModuleGraph.rs — 以 v1.4.0 为基础，手动加 OHOS PIE 函数
```

### 风险评估

| 风险 | 概率 | 影响 | 应对 |
|---|---|---|---|
| v1.4.0 重构的函数签名变了，OHOS 代码调不通 | 中 | 编译失败 | 手动适配函数调用 |
| social4hyq 的额外 gate 依赖我们没有的 crate | 低 | 编译失败 | 检查依赖 |
| localDeps 功能和 OHOS 逻辑冲突 | 低 | 配置错误 | 测试 OHOS 构建是否正常 |

### 已完成的 3-way 合并（commit 19b1d54f3）

两个临时 commit（`1fd2873ff` 恢复 + `94568e79f` 3-way 合并）已 squash 成一个：
`19b1d54f3 fix(ohos): 3-way merge 4 source files lost in v1.4.0 merge`。

每个文件的具体改动：

#### config.ts（+242/-83 行）

以 OHOS base 为基础（保留全部 OHOS 平台检测），手动加回 v1.4.0 的新功能：

| 新增内容 | 行数 | 来源 |
|---|---:|---|
| `writeFileSync` import | 1 | v1.4.0 |
| `localDeps: Record<string, string>` Config 字段 + 文档注释 | 8 | v1.4.0 |
| `nm: string | undefined` Config 字段 | 2 | v1.4.0 |
| `localDeps?: string` PartialConfig 字段 | 1 | v1.4.0 |
| `nm: string | undefined` Toolchain 字段 | 2 | v1.4.0 |
| `parseLocalDeps()` 函数 | 18 | v1.4.0 |
| `localDeps: parseLocalDeps(...)` resolveConfig 赋值 | 1 | v1.4.0 |
| `nm: toolchain.nm` resolveConfig 赋值 | 1 | v1.4.0 |
| `localDeps` features 输出 | 1 | v1.4.0 |

注：`nm` 字段在 `tools.ts` 中已有 `findLlvmTool("llvm-nm")` 赋值，无需额外改动。

#### rust.ts（+7/-0 行）

以 v1.4.0 重构版本为基础（保留 `rustTriple()` 拆分 + `canCrossCompile` + `buildPlatforms`），加回 OHOS：

| 新增内容 | 行数 | 来源 |
|---|---:|---|
| `if (os === "ohos") return \`${rustArch}-unknown-linux-ohos\`` | 1 | OHOS base |
| `"aarch64-unknown-linux-ohos"` buildPlatforms 列表 | 1 | social4hyq |
| `triple === "aarch64-unknown-linux-ohos"` Tier 3 判定 | 1 | social4hyq |
| `if (cfg.ohos) rustflags.push("-Clink-arg=--code-sign")` | 1 | social4hyq |

`--code-sign` rustflag 让 OHOS SDK 的签名链接器在链接阶段自动签名二进制（替代 spawn 时签名）。

#### run_command.rs（+15/-0 行）

以 v1.4.0 重构版本为基础（保留 `ConfigureEnvOptions` struct），加回 OHOS：

| 新增内容 | 行数 | 来源 |
|---|---:|---|
| `ohos_set_pwd()` 函数 | 10 | OHOS base |
| `#[cfg(target_env = "ohos")] ohos_set_pwd(env, cwd)` 调用点 | 3 | OHOS base |
| `use DotEnv::Loader` import（已在 v1.4.0 中） | 0 | — |

`ohos_set_pwd` 解决 OHOS hmdfs 文件系统 `getcwd()` 失败的问题：设 `$PWD` 环境变量让 bash 用 `stat($PWD)` 验证目录。

#### StandaloneModuleGraph.rs（+160/-0 行）

以 v1.4.0 标准版本为基础（保留 `find_loaded_module` 用于非 OHOS），加回 OHOS PIE 处理：

| 新增内容 | 行数 | 来源 |
|---|---:|---|
| `get_data()` 中 `#[cfg(target_env = "ohos")]` 前置分支 | 7 | OHOS base |
| `get_data()` 中 `#[cfg]` target 路径分流 | 8 | OHOS base |
| ELF 常量（ELF_MAGIC, EHDR_*, SHDR_*） | 11 | OHOS base |
| `ohos_pie_load_base()` — 扫 /proc/self/maps 找 PIE 基地址 | 22 | OHOS base |
| `ohos_primary_get_data()` — /proc/self/exe + mmap | 24 | OHOS base |
| `locate_bun_section()` — ELF section header 解析 | 40 | OHOS base |
| `read_at()` — pread64 封装 | 13 | OHOS base |

OHOS 的 PIE 处理绕过 `dlpi_addr`（在 hmdfs 上失效），改用 `/proc/self/maps` 扫描和 `/proc/self/exe` 文件偏移定位 `.bun` 段。

### 最终状态

- ✅ OHOS 功能完整（平台检测 + cfg gates + PIE 处理 + pwd 回退 + 签名）
- ✅ v1.4.0 上游改进保留（localDeps、rustTriple 重构、ConfigureEnvOptions、find_loaded_module）
- ✅ social4hyq 演进引入（--code-sign rustflag、Tier 3 分类、buildPlatforms）
- ⚠️ 后续可改进：social4hyq 的 4 个额外 run_command gate（需逐个分析后补上）

---

## 5. Cargo.lock 与 ohos_sign：第五个问题

### ohos_sign 是什么

`ohos_sign` 是 OHOS 专属的 Rust crate，用来给 bun 二进制做 ELF 签名。
OHOS 内核的 seccomp 会阻止执行未签名的 ELF 二进制文件，所以需要在
spawn 子进程前或链接时对二进制签名。

它包含：
- `elf.rs` — ELF 文件解析（找到需要签名的段）
- `sha256.rs` — SHA-256 计算
- `merkle.rs` — Merkle 树（签名结构）
- `descriptor.rs` — 签名描述符
- `ohos_selfsign.rs` — 命令行工具入口

### 问题怎么来的

```
merge 前 OHOS 分支:
  Cargo.toml 有 "src/ohos_sign" 工作区成员 ✅
  Cargo.lock 有 ohos_sign 条目 ✅           ← 匹配

v1.4.0:
  Cargo.toml 没有 ohos_sign                  ← 上游没有这个 crate
  Cargo.lock 没有 ohos_sign                  ← 匹配

merge 后:
  Cargo.toml 有 "src/ohos_sign"              ← 从 OHOS 分支保留
  Cargo.lock 没有 ohos_sign                  ← 从 v1.4.0 取来
                                              ↑ 不匹配 ❌
```

cargo 用 `--locked` 模式编译时，检查 Cargo.toml 和 Cargo.lock 是否一致。
发现 Cargo.toml 里有 ohos_sign 但 Cargo.lock 里没有 → 报错：
`cannot update the lock file because --locked was passed`。

### 为什么 ohos_sign 不只是"工作区成员"

ohos_sign 是 5 个 crate 的**依赖**（不只是工作区成员）：

| crate | Cargo.toml 声明 | target-gate? |
|---|---|---|
| `bun_spawn_sys` | `ohos_sign = { path = "../ohos_sign" }` | ❌ 无条件 |
| `bun_standalone_graph` | `ohos_sign = { path = "../ohos_sign" }` | ❌ 无条件 |
| `bun_install` | `ohos_sign = { path = "../ohos_sign" }` | ✅ `cfg(target_env = "ohos")` |
| `bun_runtime` | `ohos_sign = { path = "../ohos_sign" }` | ✅ `cfg(target_env = "ohos")` |
| `bun_sys` | `ohos_sign = { path = "../ohos_sign" }` | ✅ `cfg(target_env = "ohos")` |

这意味着 Cargo.lock 不只需要 ohos_sign 的 `[[package]]` 条目，
还需要在上述 5 个包的 `dependencies` 列表里都加上 `"ohos_sign"`。

### 修复经过（三次尝试）

**第一次**：手动加 `[[package]]` 条目到 Cargo.lock 末尾

```
[[package]]
name = "ohos_sign"
version = "0.0.0"
```

结果：CI **仍然失败**。因为只加了包本身的条目，没加 5 个依赖者的引用。
cargo 检查 `bun_spawn_sys` 的依赖列表，发现 Cargo.toml 里声明了 ohos_sign
但 Cargo.lock 的 `bun_spawn_sys` 依赖列表里没有 → 还是认为不匹配。

**第二次**：从 Cargo.toml 工作区成员里去掉 ohos_sign

思路：ohos_sign 不进工作区，就不需要进 Cargo.lock（和 lol_html 一样）。

结果：CI **仍然失败**。因为 5 个 crate 的 Cargo.toml 里声明了
`ohos_sign = { path = "../ohos_sign" }` 作为依赖——不管 ohos_sign
是不是工作区成员，cargo 都要在 Cargo.lock 里找到它。

**第三次（最终）**：保留工作区成员 + 正确更新 Cargo.lock

- Cargo.toml：恢复 `"src/ohos_sign"` 到工作区成员列表
- Cargo.lock：在 5 个包的 `dependencies` 列表里都加上 `"ohos_sign"`，
  再加上 `[[package]] name = "ohos_sign" version = "0.0.0"` 条目

### social4hyq 怎么处理的

social4hyq **保留了** ohos_sign 在工作区里，Cargo.lock 里也正确包含了
ohos_sign（4 处引用：3 个依赖者 + 1 个 `[[package]]` 条目）。
他们没有跳过 `--locked`——Cargo.lock 是完整的、匹配的。

| | 我们的修复 | social4hyq |
|---|---|---|
| ohos_sign 在 workspace | ✅ 保留 | ✅ 保留 |
| `--locked` | ✅ 保留 | ✅ 保留 |
| Cargo.lock 有 `[[package]]` 条目 | ✅ 手动加 | ✅（cargo generate-lockfile 生成） |
| Cargo.lock 有 5 个依赖者引用 | ✅ 手动加 | ✅（cargo generate-lockfile 生成） |
| 生成方式 | 手动编辑（本地 rustup 坏了跑不了 cargo） | `cargo generate-lockfile` 自动生成 |

### 共同点和差异

**共同点**：
- 都保留 ohos_sign 在 workspace 和 Cargo.lock 里
- 都不跳过 `--locked`（保持 CI 可复现性）
- ohos_sign 的功能相同（ELF 签名）

**差异**：
- social4hyq 的 Cargo.lock 是 cargo 自动生成的（格式保证正确）
- 我们的 Cargo.lock 是手动编辑的（可能排序不完美，但内容正确）
- 后续应该在能跑 cargo 的环境里用 `cargo generate-lockfile` 重新生成，
  替换掉手动编辑的版本

### 为什么不能直接跳过 `--locked`

`--locked` 保证 CI 每次构建用同样的依赖版本，不会因为某个依赖升级
导致构建突然失败。跳过它虽然能临时解决问题，但会：
1. 每次构建可能拉到不同版本的依赖
2. 不可复现——同一代码不同时间构建结果可能不同
3. 和上游 bun 的 CI 不一致（上游用 `--locked`）

---

## 术语解释

| 术语 | 通俗解释 |
|---|---|
| merge conflict | 两个人改了同一行代码，git 不知道用谁的 |
| `--theirs` | 解决冲突时"用对方的版本"（丢弃自己的改动） |
| `--ours` | 解决冲突时"用自己的版本"（丢弃对方的改动） |
| 3-way merge | 三方合并：参考原始版本 + 甲的改动 + 乙的改动，各取所长 |
| cfg gate | Rust 的条件编译：`#[cfg(target_env = "ohos")]` 表示"只在 OHOS 编译时才包含这段代码" |
| PIE | 位置无关可执行文件：每次运行时内存地址随机，需要特殊处理 |
| target triple | 编译目标三元组，如 `aarch64-unknown-linux-ohos` 告诉编译器"给 OHOS 的 arm64 编译" |
| dynamic-list | 链接器指令：指定哪些符号导出给动态链接的模块用 |
| version-script | 链接器指令：更强大的符号控制，能隐藏没列出的符号（`local: *`） |
| Cargo.lock | Rust 的依赖版本锁定文件，保证每次构建用同样的依赖版本 |
| `--locked` | cargo 参数：禁止更新 Cargo.lock，严格按锁定的版本编译 |
| `[[package]]` | Cargo.lock 里的一条记录，描述一个包的名字、版本、依赖 |
| target-gate | Rust 条件编译：`[target.'cfg(...)'.dependencies]` 只在匹配目标时生效 |

---

*文档日期：2026-08-29 | 作者：Sisyphus*
