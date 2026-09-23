# P2: install-bun-ohos.sh 发布闭环（脚本指错库 + 路径断链 + 滚动发布缺资产）
> **关联 PR**：[#67](https://github.com/jx-bit/bun/pull/67)

> 用户要的安装脚本三件套（binary + tar.gz + install-bun-ohos.sh）发布链断裂：
> 脚本存在且功能完整（下载/校验/安装/PATH/设备自动签名），但三处缺陷让它
> 要么不出现、要么装错东西。

## 1. 三处缺陷

| # | 缺陷 | 后果 |
|---|---|---|
| 1 | 脚本 `REPO="ljy9812/bun"` 硬编码，头部 URL 全指向他库 | 从我们 release 执行 `curl \| sh` 会**下载并安装别人的 binary** |
| 2 | ohos-release.yml 两处 cp 引用 `ohos/install-bun-ohos.sh`（实际在 `ohos/fulltest/`），`\|\| true` 静默吞错 | 版本化 release **第三件套悄悄缺失** |
| 3 | 滚动 ohos-latest 只上传裸 binary | `curl …/ohos-latest/install-bun-ohos.sh \| sh` 无从谈起 |

## 2. 修复

1. 脚本：`REPO="${BUN_INSTALL_REPO:-jx-bit/bun}"`（env 可覆盖，便于测试）；
   头部/内嵌 URL 全指本库；默认变体翻为 **github**（容器通道每 merge 必发布，
   `self` 变体保留给自托管通道 A/B）。
2. ohos-release.yml：两处 cp 路径修正为 `ohos/fulltest/`；tarball 内 README
   安装 URL 指本库。
3. ohos-build-github.yml：ohos-latest 发布加 `install-bun-ohos.sh` 资产；
   并补回 PR 门禁守卫（仅 `refs/heads/ohos-aarch64` 发布滚动 release，
   1.4.0 分支删除时该守卫随分支丢失，本 PR 恢复）。

## 3. 验证

- `sh -n` 通过；两 workflow YAML 解析通过。
- 合并后：`curl -fsSL https://github.com/jx-bit/bun/releases/download/ohos-latest/install-bun-ohos.sh | sh`
  在设备上下载**本库** `bun-ohos-aarch64-github`、安装、自签名。
- 未修复形态：缺陷 2/3 静默（release 缺资产不报错），缺陷 1 语义性装错 ——
  均不可由 CI 捕获，故以发布链人工核验为准。

## 5. §后续：#68 脚本/二进制版本配对（2026-09-23）

用户提出发布契约缺口：**每个版本的安装脚本必须配对自己的二进制**。审计结论：

| 通道 | 配对状态（#67 后） |
|---|---|
| 滚动 ohos-latest | ✅ 发布时同 commit 成对替换；旧脚本存档会装"最新"——滚动通道语义，接受并注明 |
| 版本化 ohos-v* | ❌ 打包脚本 `RELEASE_TAG="ohos-latest"` 硬编码 → tar.gz 自带 bun 却被无视，执行时下载滚动最新 → **版本化形同虚设** |

**#68 修复**（[pr68](https://github.com/jx-bit/bun/pull/68)，claude/ohos-install-script-pairing）：
1. tar.gz 内脚本**优先安装同目录自带 bun**（最强配对——解包即所装，零下载）；
2. 独立脚本资产由 ohos-release.yml 打包时 **sed 注入实际 tag**（`RELEASE_TAG="ohos-latest"` → `"<tag>"`），独立下载也指自己版本；
3. 滚动 ohos-latest 语义不变（脚本默认 tag 不动，发布时不注入）。

验证：sh -n / YAML 通过；未修复形态 = 解包旧版 archive 执行自带脚本会拉取滚动最新 binary 静默换版。

## 6. §后续：#76 校验和清单（上游发布约定，2026-09-23）

用户提出参照官方 bun-v1.4.0 发布页（38 资产）。分类学：全 zip 打包、x64 三档
CPU 变体（-baseline/-profile，aarch64 无此分层不适用）、**SHASUMS256.txt+.asc
校验清单**、body 每平台安装命令（#71 已对齐）。

**采纳：SHASUMS256 校验链**（此前安装脚本唯一完整性检查是"体积>1MB"）：
1. ohos-latest（build job）：binary+script 的 SHASUMS256.txt 随发布上传；
2. 五产品 latest（publish job）：五产品各自 sha256 + body 链接清单；
3. ohos-release.yml：版本化三件套 SHASUMS256.txt；
4. install-bun-ohos.sh：下载后拉同 tag 清单 `sha256sum -c`，**mismatch 硬失败
   并移除下载**；清单缺失（旧 release）warn 跳过。

**不采纳**：CPU 变体（无 aarch64 分层）、-profile（上游自用诊断）、S3/npm/
homebrew 分发机器（我们不运营）、zip-only（curl|sh 需要裸下载）。

## 7. 关联

- 五平台滚动 latest：[#66](https://github.com/jx-bit/bun/pull/66)（装配 workflow）
- 版本化 release 通道：ohos-release.yml（tag `ohos-v*` 触发，self-hosted）
- 守卫白名单：ohos/fulltest/ 已入库（#38 批次），check-pr.sh 规则 3b 白名单
  扩充为 `README.md|fulltest/`（2026-09-23）

---
*立档：2026-09-23 | 分析者：Sisyphus | 依据：脚本实读 + 两个 release workflow 对照*
