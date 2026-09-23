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

## 7. §后续：#77 发布配对门禁——双向错配修复 + 发布后验证（2026-09-23）

用户提出发布契约升级：**不同 tag/release 各自对应的脚本必须存在且不出问题**，后升格为
普适契约：**任何名字的 tag 发布的 release，页面归档自己的安装脚本、脚本下载自己的
二进制**。审计 #68 配对机制发现两处残留错配 + 三处机制空洞（1/2 为潜伏——ohos-v* 通道
至今未发布；4 于当日删除事故实际暴露；5 为覆盖缺口）：

| # | 缺陷 | 后果 |
|---|---|---|
| 1 | 版本化 release 只带 self 变体二进制，但其 tag 注入脚本默认构建仍是 `github` | tag release 上执行 body 一行命令 → 下载 `bun-ohos-aarch64-github` → **404**（默认即错） |
| 2 | tag 工作流更新 ohos-latest 时把滚动脚本也覆盖成 tag 注入版 | 滚动入口默认与 `-- github` 模式全 404，仅 `-- self` 幸存；窗口持续到下一次交付分支 push 覆盖回原样脚本 |
| 3 | 发布后零验证：脚本资产缺失/配对断裂静默通过 CI | 只有设备上安装失败才暴露——当日 ohos-latest 被手动删除（09:52）后数小时无人发现即实例 |
| 4 | `latest` 的安装入口跨 release 依赖：body 命令指向 ohos-latest 的脚本 | 目标缺失时 latest 页面命令同样死——当日事故中 latest 自带 bun 却装不了 |
| 5 | tag 触发器只认 `ohos-v*` 前缀 | 其他名字的 tag 推上去无任何反应，"任意 tag = 自包含 release"契约无从成立 |

**用户影响速览**：

| 缺陷 | 用户在做什么 | 感知症状 | 频率 | 严重度 |
|---|---|---|---|---|
| 1 | 从版本化 release 页复制 Quick Install 一行命令到设备执行 | "Download failed. Check your network."——网络正常仍失败，无从排查 | 用 tag release 即必现 | 高（该通道一行命令完全不可用） |
| 2 | tag 发布后照常使用滚动一行命令（默认或显式 github） | 同上 404 伪装成网络错误；以为滚动入口坏了 | tag 发布 → 下次交付 push 的窗口内必现 | 高（主入口失效） |
| 3 | 正常安装（任意通道），资产因误删/发布故障缺失 | 安装失败，发布方无任何告警，需人工排查 | 资产缺失时必现 | 中（可恢复但发现滞后） |
| 4 | 从 latest 页面复制 Quick Install 命令到设备 | 目标 release 缺失期间 404（尽管 latest 自身就有 bun） | ohos-latest 缺失期间必现 | 中 |
| 5 | push 任意非 `ohos-v*` 名字的 tag 期望发布 | 毫无反应，须查工作流源码才知道前缀限制 | 每次用自定义 tag 名 | 低（摩擦而非故障） |

**#77 修复**（[pr77](https://github.com/jx-bit/bun/pull/77)，claude/ohos-release-script-pairing）：
1. 脚本：默认构建改 `BUILD="${BUN_INSTALL_BUILD:-github}"`——env 可覆盖、release 打包
   可 sed 注入（该字面量为注入锚点，已验证全脚本唯一）；下载失败信息带资产名 + release
   链接（区分"资产不在该 release"与网络故障）；头部过期注释修正（默认早已翻 github，
   注释仍写 self-hosted，且示例参数错位）。
2. ohos-release.yml：tag 注入改双 `-e`（RELEASE_TAG + BUILD 默认→self，归档内与独立脚本
   两份同改）；ohos-latest 改收**原样脚本**（新增 rolling_script_path 输出，资产名不变），
   滚动入口两种模式都自洽；版本化 release body 一行命令指向**自身 tag**；独立脚本 sed 的
   `2>/dev/null \|\| true` 静默删除（注入失败必须红，不能带病发布）。
3. 验证门禁：ohos-release.yml 与 ohos-build-github.yml 各增发布后验证步骤——资产存在性
   （GitHub API，自托管 runner 用 python3 urllib 无 gh 依赖）+ 脚本配对锚点断言（staged
   字节 grep：tag 版 `RELEASE_TAG=<tag>`+`:-self`，rolling 版原样 + `:-github`）；build job
   另断言 ohos-latest 两资产、publish job 断言 latest 五产品齐全。配对断裂直接红，不再等
   设备端发现。
4. latest 自包含：publish job 增 checkout（与构建产品同 commit 取脚本），脚本随产品入列
   （注入 `RELEASE_TAG="latest"` + 默认 self → 下载本 release 的 `bun-ohos-aarch64`），
   body 命令自指，验证步骤扩为 6 资产 + 脚本锚点。
5. 任意 tag 泛化：ohos-release.yml 触发器 `ohos-v*` → `*`（排除 CI 自管滚动 tag
   `ohos-latest`/`latest` 与共享目录构建 `ohos-full-v*`）——任何 tag push 即产自包含
   release。注：CI 以 GITHUB_TOKEN 发布，产生的事件不触发上游 release.yml（`on: release
   published`），无递归双跑（当日 release.yml 仅 schedule run 且全 skipped 佐证）。

验证：`sh -n` + sed 注入模拟（两锚点各唯一命中 1 次；任意 tag、`latest`、rolling 原样
三种副本均按预期改写/不改写）；两 workflow YAML 解析（含新触发器形态核对）+ 全部 run 块
`bash -n` 通过；验证
python 从工作流 heredoc 原样提取后实弹测试——已删除 release（HTTP 404）与资产缺失 release
两场景均干净报错 exit 1，恰好复现当日 ohos-latest 被删事故类。验证步骤门禁在交付分支
push 才执行（PR run 不得发布），合并后首跑生效；check-pr.sh 全项 PASS（单 commit、
message/body 无违禁引用、diff 白名单、基线新鲜）。

**修后契约**：任何 tag push（除排除项）即产自包含 release——页面命令自指、脚本下载本
release 资产、tar.gz 归档零下载；ohos-latest / latest / 任意 tag 三类入口全部满足，发布后
统一门禁验收。发 release 的方式统一为 `git push origin <tag>`（网页 UI 手动建的
release/tag 不触发工作流）。

## 8. 关联

- 五平台滚动 latest：[#66](https://github.com/jx-bit/bun/pull/66)（装配 workflow）
- 版本化 release 通道：ohos-release.yml（tag `ohos-v*` 触发，self-hosted）
- 守卫白名单：ohos/fulltest/ 已入库（#38 批次），check-pr.sh 规则 3b 白名单
  扩充为 `README.md|fulltest/`（2026-09-23）

---
*立档：2026-09-23 | 分析者：Sisyphus | 依据：脚本实读 + 两个 release workflow 对照*
