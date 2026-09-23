# P3: bun_install 的 OHOS 代码编码规则修复(env::var / 路径 UB)— 归档文档

> **关联 PR**:[#62](https://github.com/jx-bit/bun/pull/62)（单 commit
> `684122346a`，3 文件 +29/−21，base `ohos-aarch64` tip）
> **状态**：🔄 OPEN
> **一句话**：修复 **3 个文件里只在 OHOS 构建中才编译的运行时代码**——
> 它们违反项目编码规则（clippy 检出），其中 2 处是真 bug（非 UTF-8 路径
> 场景）。**本 PR 不改 clippy 配置**，改的是被 clippy 查出的代码。
> **来源**:[#60](pr60-p3-standalone-graph-clippy.md) §5 枚举的第三批;
> 承接 pr57/pr60。

## 1. 这是什么、为什么现在才发现

**clippy** 是 Rust 的静态检查器（编译器之上的规则层）。本仓库用
`clippy.toml` + `-D warnings` 把一组编码规则定为**强制**（禁用
`std::env::var`、禁 `from_utf8_unchecked`、unsafe 必须写 SAFETY 注释等
——见 clippy.toml 的 disallowed-methods 表，每条带理由）。

**为什么一直没发现**：这 3 个文件的问题代码都在
`#[cfg(target_env = "ohos")]` 门控里——只在为 OHOS 编译时才存在。此前
所有 clippy 车道都跑在 host triple 上（门控代码被整体剔除，对 linter
不可见），而 OHOS 容器构建走 `cargo build`（clippy 的规则不参与普通
编译）。三车道盲区，与 #55 复盘的"skip 静音"同族。#57 起建立了
`--target=aarch64-unknown-linux-ohos` 的 clippy 检查面，这批欠账才可见
（第一批 = #57 spawn 路径 11 处，第二批 = #60 standalone_graph 12 处,
本 PR = 第三批 bun_install 7 处）。

## 2. 用户影响速览

| # | 用户在做什么 | 感知症状 | 频率 | 严重度 | 修复后 |
|---|---|---|---|---|---|
| 2.1 | 设备上设置 `OHOS_SYSROOT` 跑 node-gyp/make 类生命周期脚本，路径含非 UTF-8 字节 | 工具链路由**静默失效**——脚本拿不到 sysroot 旗标，编译报错难定位 | 低（非 UTF-8 路径少见） | 中（功能失效） | 字节直传，正常路由 |
| 2.2 | `bun install` 装一个**目录名含非 UTF-8 字节**的原生包，触发 codesign 修复 | 进程 **UB**（`from_utf8_unchecked` 作用在非 UTF-8 字节上）——可能崩溃或任意行为 | 低 | 高（内存未定义） | `OsStr::from_bytes` 接受任意字节，安全 |

（第 3 处改动——`env::var` 换 `getenv_z` 的另外 4 个位点——与 2.1 同
模式，无独立用户影响。）

## 3. 改了什么（3 个文件,逐文件功能性描述）

### 3.1 PackageManagerLifecycle.rs + PackageManager.rs（同一逻辑的两份）

**改前**:`std::env::var("OHOS_CC"/"OHOS_CXX"/"OHOS_SYSROOT")` 读用户
设置的工具链环境,写进 lifecycle 脚本环境。

**改后**:`bun_core::getenv_z(...)` 读（工作区规定:env 读取必须走它,
见 src/AGENTS.md）。

- **功能影响**:仅一处改善——`OHOS_SYSROOT` 路径含非 UTF-8 字节时,
  `var()` 会因 NotUnicode **报错**（路由静默失效,见速览 2.1）,字节
  直传后正常。其余场景（缺失/正常值）行为逐位一致。
- `OHOS_SYSROOT` 旗标拼接从 `format!` 改为字节 `extend`（避免对字节
  切片做 lossy 转换）。

### 3.2 PackageInstaller.rs

**改前**:codesign 修复路径用
`core::str::from_utf8_unchecked(包目录字节)` 构造 `Path`——包目录名
含非 UTF-8 字节时是**未定义行为**。

**改后**:`std::os::unix::ffi::OsStrExt::from_bytes` 构造 `OsStr` →
`Path`(接受任意字节);日志 lossy 显示。

- **功能影响**:非 UTF-8 包目录从 UB 变为正常工作;其余逐位一致。

### 3.3 没有改的东西

- **clippy 配置本身**:零改动(clippy.toml / -D warnings 均未动)。
- 非 OHOS 平台:全部改动点在 cfg 门控内,host/Win/mac 构建不含这些
  代码,行为零变化。

## 4. 与参照实现的对比

**无参照实现**——这 6 处 `std::env::var` 是我方 #42 系自加的 OHOS
工具链路由（参照线无此机制,其 env 面走 shim）。本批为纯自查清理,
无移植。证据:参照线（A minimal）grep 无 OHOS_CC 路由〔源码〕。

## 5. 验证

- 〔本机〕bun_install ohos-target clippy **0 error**（修复前 7:var ×6 +
  undocumented unsafe ×1）;host clippy ✅;rustfmt ✅;dead-code-escapes ✅。
- **未修复构建上必失败声明**:同命令 7 error;非 UTF-8 OHOS_SYSROOT 下
  lifecycle 工具链路由失效;非 UTF-8 包目录 codesign 修复为 UB。
- 〔设备·验收〕设 `OHOS_SYSROOT` 为含非 UTF-8 字节的路径跑
  `bun install <带编译脚本的包>` → 工具链旗标正常注入。

## 6. 剩余欠账(第四批,已枚举)

`bun_runtime` 自身 OHOS 门控代码 **7 错**（bun_install 清零后暴露）:
run_command.rs:694（env::var）、ohos_node_userinfo.rs:149/:390/:433
(undocumented unsafe / raw-deref 公开函数 / slice::windows——#52 移植面)、
dns.rs:5156/:5166/:5167(undocumented unsafe ×3——#40 系)。全部为我方
近期 PR 的门控代码,机械修复为主（SAFETY 注释 + strings 惯用法）,
仅 is_managed_key 需 unsafe fn 签名调整。
