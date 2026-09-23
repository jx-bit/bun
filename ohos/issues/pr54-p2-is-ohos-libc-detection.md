# P2: OHOS 的 libc 判定缺失(IS_MUSL/IS_OHOS)——upgrade/compile/NAPI 三处行为错误 — 归档文档

> **关联 PR**：[#54](https://github.com/jx-bit/bun/pull/54)（单 commit
> `7c2254b983`，3 文件 +22/−7，base `ohos-aarch64` tip）
> **状态**：✅ 合并（6ba99e7085）
> **一句话**：OHOS 的 libc 是 musl，但代码里的 libc 判定常量
> `IS_MUSL` 不认识 OHOS——导致 `bun upgrade` 会下载 glibc 包**变砖**、
> `bun build --compile` 元数据标签错、NAPI glibc 检查在设备被跳过。
> **决策**：资产后缀采用 `-ohos`（2026-09-21 拍板，见 §5）。
> **家族**：默认值对比（vs 参照线）产出，同批姊妹 PR
> [#52](https://github.com/jx-bit/bun/pull/52)、
> [#53](https://github.com/jx-bit/bun/pull/53)。

## 0. 证据来源与参照线地位

**参照线不是官方**（独立 OHOS 移植线，非规范来源）。上游无此机制。
本 PR 的常量定义/分支顺序与参照线一致（逐字），正确性立论：
`aarch64-linux-ohos` target 的 libc **就是 musl**（OHOS SDK 用 musl），
`IS_MUSL` 不含 ohos 是客观误判，与参照线无关。

## 1. 三个消费点，三个错误（说人话版）

### ① bun upgrade —— 现状会"变砖"

`upgrade_command.rs` 拼下载文件名：`bun-<平台>-<架构><libc后缀>.zip`。
后缀链：musl→`-musl`、android→`-android`、**其余→空（=glibc）**。
OHOS 落"其余" → 去官方 release 下载 `bun-linux-aarch64.zip`
（glibc 版）→ **musl 设备跑不起来，还把当前能用的二进制覆盖了**。

### ② bun build --compile —— 元数据标签错

`compile_target.rs`：编出的单文件 exe 内嵌"我为哪个 os/架构/libc 构建"
的元数据，libc 三选一（Default=glibc/Musl/Android）。OHOS 上被记成
Default(glibc)——设备明明是 musl。且 `--target=bun-linux-aarch64-ohos`
这类目标串直接被拒（token 不认识）。

### ③ NAPI glibc 预检 —— 设备上被跳过

`napi/libc_check.rs`：加载 `.node` 原生模块前检查它是否 glibc 编译
（musl 系统加载 glibc 模块会炸出 cryptic dlopen 错误；此检查提前给
干净报错）。该检查 `IS_MUSL || BUN_INTERNAL_NAPI_FORCE_MUSL_CHECK`
才启用 → 设备上 IS_MUSL=false → **跳过** → 用户直接见底层炸。

## 2. 修复（3 文件，与参照线逐字）

| 文件 | 改动 | 效果 |
|---|---|---|
| `bun_core/env.rs` | `IS_MUSL = cfg!(any(target_env="musl", target_env="ohos"))`；新增 `IS_OHOS`、`IS_GLIBC` 常量（`IS_AARCH64/IS_X64` 转 pub(crate)） | 判定基建就位；③自动启用 |
| `runtime/cli/upgrade_command.rs` | `SUFFIX_ABI` 链 IS_OHOS 提到首位 → `"-ohos"` | ①不再下载 glibc 包 |
| `options_types/compile_target.rs` | `Libc::Ohos` 枚举变体（default 分支 IS_OHOS 优先、npm_name `-ohos`、parse 接受 `ohos` token、错误提示白名单、define_values 映射 `process.platform="openharmony"`） | ②标签正确 + `--target=...-ohos` 可解析 |

**有意不取**参照线的两处无关演进：`to_npm_registry_url` 的 file:// 前缀
支持、`is_host_platform` 方法（其消费方 CROSS_COMPILED_BYTECODE 特性
我方树不存在，取了即死代码）。排除法逐 hunk 核对。

## 3. 关键事实核验（2026-09-21 实测）

- **上游 oven-sh release（bun-v1.4.2）资产实测**：有
  `bun-linux-aarch64-musl.zip` / `-android.zip`，**无 `-ohos`**。
- **参照线真机分发实证**：不走 GitHub release，走 **harmonybrew
  bottle**（`social4hyq/homebrew-core` `Formula/b/bun.rb`：bottle tag
  `arm64_ohos`、托管 atomgit、source=上游 tag + fork revision、per-file
  patch 系列 replay 逐字节复现分支 tip）；其 `bun upgrade` 拼的
  `-ohos` zip 在任何 release 页都不存在（下载域名编译期写死
  oven-sh 未改）→ 真机升级实际走 brew。
- **后果矩阵**：现状空后缀=下载 glibc 包变砖（最差）；`-musl`=能跑但
  静默丢掉全部 OHOS 适配（#26-#53）；`-ohos`=404 诚实失败、保留当前
  版本（发布侧补资产后即闭环）。

## 4. 决策记录

**2026-09-21 拍板：采用 `-ohos` 后缀。** 接受 `bun upgrade` 在设备上
暂为 404（严格优于现状变砖）；真机分发/升级闭环（bottle 式发布流水线 +
客户端写死的 oven-sh 下载 URL 改造）**另立专项**，本 PR 不含。

## 5. 验证

- 〔本机〕cargo check + clippy（host，bun_runtime + bun_options_types）✅、
  cargo check `--target=aarch64-unknown-linux-ohos` ✅、rustfmt ✅、
  dead-code-escapes 24/24 ✅。
- 〔设备·验收〕①`bun upgrade --dry-run`/资产 URL 含 `-ohos` 且不再
  拉取 glibc 包；②`bun build --compile` 产物元数据 libc=ohos、
  `--target=bun-linux-aarch64-ohos` 可解析；③加载 glibc 链接的
  `.node` 模块得到干净诊断而非底层 dlopen 错误。
- 其余平台零变化：`IS_OHOS` 在非 OHOS target 恒 false，所有分支走向
  与改前一致。

## 6. 与参照实现的对比

**结论：三个文件的改动与参照线逐字一致；两处无关演进有意不取
（§2）；`Libc` 枚举的两个穷尽 match（npm_name/define_values）均已同步
扩展。** 参照线角色 = 形态候选 + 命名决策的先行者，非正确性依据——
正确性由"OHOS libc = musl"这一客观事实背书。证据类型：〔源码〕逐字
核验；〔实测〕上游 release 资产清单、参照 tap formula。
