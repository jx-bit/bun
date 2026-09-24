# P2: 发布资产预签——签名/未签名双资产共存（签名版推荐）+ 脚本降级便利层
> **关联 PR**：[#81](https://github.com/jx-bit/bun/pull/81)

> 两条发布通道（ohos-build-github.yml / ohos-release.yml）产出的 binary 一律无
> `.codesign` 段，设备上 exec 必被内核拒绝——开箱即用被"设备端签名"这一步硬阻断，
> install-bun-ohos.sh 成了唯一主入口。本 PR 把签名前置到发布侧，并按用户要求
> **双资产共存**：规范资产名携带预签二进制（推荐，开箱即用），新增 `-unsigned`
> 变体保留裸构建产物（想自行设备端签名/二次分发的用户自选）；三个 release
> 通道（ohos-latest / latest / 版本化 tag）全部带上两份。脚本保留（PATH +
> A/B 变体），先试运行自动适配两种资产。

## 1. 用户影响速览

| 缺陷 | 用户在做什么 | 感知症状 | 频率 | 严重度 |
|---|---|---|---|---|
| 1 资产无签名 | 从 release 页直接下载 binary（不走脚本）到设备 | exec 报裸 `Permission denied`，与"没 chmod +x"症状相同无从区分，用户以为下载坏了或系统拒装 | 每次绕过脚本直接下载 | 中（主入口脚本可用，但开箱即用缺失） |
| 2 签名是设备端单点 | 设备上无 binary-sign-tool（非 OHOS 环境 / 工具被裁剪） | 脚本安装到最后一步 warn"sign it first"，装完跑不起来 | 设备缺工具时必现 | 中 |
| 3 发布门禁不验签 | CI 发布损坏/无签名资产 | 静默通过（#77 门禁只查资产存在性 + 脚本锚点），只有设备端安装失败才暴露 | 资产损坏时必现，发现滞后 | 中 |

## 2. 根因

- 历史顺序：`ohos_sign` crate（07-07）为**运行时补签**落地（spawn/dlopen/install/
  compile 四写路径），CI 产出无签名 binary 是当时的前提；安装脚本独立长出了
  binary-sign-tool 设备端兜底。发布链从未回头接上预签（pr67 文档 §5-§7 的配对
  工作都围绕"脚本↔资产"配对，未覆盖"签名时机"）。
- 设备端 binary-sign-tool 依赖 HarmonyOS libc++.so，openEuler 构建机跑不了
  （ohos-release.yml 原注释明言）——发布侧一直没有可用的签名器。
- 实际上签名器早已具备：`src/ohos_sign` 纯 Rust、std-only、自签名内容自包含
  （file_size + merkle root + SHA256 摘要，无私钥/证书/设备绑定），且带独立 CLI
  `src/ohos_sign/src/bin/ohos_selfsign.rs`。

## 3. 修复

| # | 文件 | 内容 |
|---|---|---|
| 1 | `src/ohos_sign/src/bin/ohos_selfsign.rs` | 新增 `verify` 子命令——调 `has_valid_codesign` 重算 file_size + 全文件 merkle root，**内核等价**校验；原 `check` 只查段存在，做发布门禁形同虚设。顺带修参数解析：`sign`/`strip` 原先 `args[0]` 无条件当文件名，flag 前置写法（`sign --force <input>`）会读错文件——CI 两个 workflow 均用 flag 前置形式，不修必炸。 |
| 2 | `ohos-build-github.yml` | "Verify binary" 后新增 **Pre-sign binary** 步骤：host 侧 `cargo build -p ohos_sign --bin ohos-selfsign`（RUSTUP_TOOLCHAIN=stable 绕开 pinned nightly 的交叉 target 列表；缺 cargo 则 rustup 装最小 stable；crate 零依赖 8s 编完）→ `sign --force --output bun-signed bun`（**构建输出原地保留为 unsigned 变体**，签名写入副本）→ `verify` 门禁验签名副本。资产装配：规范名 `bun-ohos-aarch64-github` = 签名版（推荐），`bun-ohos-aarch64-github-unsigned` = 裸构建输出；artifact 携带两份，publish job 同步双资产入 `latest`；两处 release body 加 Out-of-the-box + Variants 段。头部 "Signing: NOT done in CI" 注释同步改写。 |
| 3 | `ohos-release.yml` | 同上注入自托管通道（独立 CARGO_TARGET_DIR=/tmp，避免与 ninja 的 OHOS-target 共享目录冲突）。`Package release`：规范名 = 签名版、`-unsigned` = 裸输出、tar.gz 内 bun 用签名版（解包即所装的配对语义不变）；版本化与 ohos-latest 两处上传清单/body 同步双资产。tar.gz 内 README 改为预签直跑推荐 + "Permission denied = 损坏重下"说明。发布后 python 验证集加 `-unsigned` 资产。 |
| 4 | `ohos/fulltest/install-bun-ohos.sh` | Verify & Sign 段重排：先试运行 `--version`——**能跑（预签资产）则跳过设备端签名**（binary-sign-tool 对已签文件的行为未实测，直接规避）；跑不动（unsigned 资产经脚本安装 / 老 release 资产 / 损坏下载）才走原 binary-sign-tool 流程。对老 release 资产行为完全不变。脚本锚定资产名不变（`bun-ohos-aarch64(-github)` = 签名版），无需改动即自动受益。 |

不采纳：HAP 包分发 / Harmonybrew bottle（CLI 工具非标准路径，证书体系成本高）；
SHASUMS256 清单（#76 已关闭——预签后内核 exec 验签本身就是更强的完整性检查）。

## 4. 验证

- `sh -n` 安装脚本通过；sed 注入锚点（`RELEASE_TAG="ohos-latest"` /
  `BUN_INSTALL_BUILD:-github`）各唯一 1 处（#77 CI 断言依赖不变）；
- 两 workflow YAML 解析通过；
- `cargo clippy -p ohos_sign` 零警告、`cargo fmt --check` 零 diff、
  `cargo test -p ohos_sign` 25/25 通过；
- CLI 实弹六项：无签名 reject / 签后 pass / **篡改 1 字节 reject**（内核等价证明，
  exec 时同样死）/ 重签复活 / strip 摘段 / flag 前置+位置前置两种顺序均解析正确；
- **分离产物 roundtrip**（双资产核心前提）：`sign --force --output sep-signed sep`
  → 副本 verify 通过、原件 `cmp` 与构建输出逐字节相同且 verify 正确拒绝（未签名）；
- 安装脚本双分支隔离实测（set -eu 下 `if VERSION=$(...)` 行为）：可执行 → 跳签名；
  chmod -x（EACCES）→ 落入设备端签名分支；
- **待真机冒烟（验收口径）**：设备上 `curl -o bun … && chmod +x bun && ./bun --version`
  免签名直跑（签名版）；tar.gz 解包 `./bun` 直跑；`-unsigned` 资产按 body 指引
  binary-sign-tool 手动签后直跑；老 release 资产经脚本安装仍正常补签。
- 未修复形态：直接下载的签名版仍不存在（用户只剩毛坯）；无 `-unsigned` 变体时
  自行签名/二次分发者只能拿被改过的文件。均不可由现有 CI 捕获，以真机冒烟为准。

## 5. 与 social4hyq 实现的对比

同一"出生即有效"理念（codesign primer §5.2），应用面不同：

| 项 | social4hyq | 本 PR 后的我方 |
|---|---|---|
| 理念 | 所有写路径签名（compile/install/dlopen 落盘即签），spawn 零签名操作 | 同一理念延伸到**发布链**：binary 在 CI 打包时签名，用户解包即所得 |
| bun 本体分发 | Harmonybrew bottle，链路上已签 | GitHub release 资产，此前无签名 → 本次补上 |
| 签名材料 | brew 体系内自洽 | self-sign 内容自包含（无私钥），与设备端 binary-sign-tool 产物逐位对齐（`src/ohos_sign` 与上游工具逐位对齐，见 primer §2.2） |
| 内核约束 | 其环境签名未强制 | 消费版强制验签（0902 轮 72 文件 EACCES 铁证）——预签正是对这一强制的正面满足 |

## 6. 发布契约增量

- **双资产语义**：规范资产名 `bun-ohos-aarch64(-github)` = **预签开箱即用**（推荐）；
  `bun-ohos-aarch64(-github)-unsigned` = 裸构建输出（自行设备端签名/二次分发）。
  三个通道（ohos-latest / latest / 版本化 tag）全部携带两份；tar.gz 内 bun 固定
  签名版（解包即所装）。
- 脚本行为对预签资产 no-op（试运行通过即跳过）；对 `-unsigned`/老资产走设备端
  binary-sign-tool——同一脚本同时服务两种用户选择。
- 门禁升级：发布前 `verify`（内核等价）断言承重——签名缺失/描述符失效/文件损坏
  直接红，不再等设备端发现（补齐 #77 验证步骤对二进制内容的盲区）。
- 三通道 body 均为三段式：Out-of-the-box（推荐）+ Variants（unsigned 自签指引）
  + Quick Install（脚本，顺带写 PATH）。

## 7. 关联

- 签名机制原理：[`../knowledge/codesign-and-spawn-primer.md`](../knowledge/codesign-and-spawn-primer.md)
- 发布链前史：[pr67-p2-install-script-release.md](pr67-p2-install-script-release.md)（§5 #68 配对 / §7 #77 配对门禁）
- 脚本解析：脚本本体头部注释 + 本文档 §3

---
*立档：2026-09-24 | 分析者：Sisyphus | 依据：两 workflow + 脚本 + `src/ohos_sign` 实读，
CLI 实弹测试在 x86_64 Linux scratch ELF 上完成*
