# P2: 发布资产收敛——预签 tar.gz 成为安装主故事，安装脚本退役
> **关联 PR**：[#83](https://github.com/jx-bit/bun/pull/83)

> #81 落地预签后，release 页面出现三层混乱：三个安装指引并存（Out-of-the-box /
> Quick Install / Variants）、滚动通道发裸二进制而版本化通道发 tar.gz（打包故事
> 不一致）、run 页 5 artifact 对 7 release 资产无映射。用户拍板：**预签 tar.gz
> 成为唯一安装主故事，install-bun-ohos.sh 直接退役**——#67/#68/#77 三轮修复的
> sed 注入/配对机器随脚本一并退场。

## 1. 用户影响速览

| 缺陷 | 用户在做什么 | 感知症状 | 频率 | 严重度 |
|---|---|---|---|---|
| 1 安装指引三选一打架 | 落地 release 页想装 bun | 三个节区三种命令，不知道用哪个 | 每次 | 中（决策瘫痪） |
| 2 通道间打包形态不一致 | 对比 ohos-latest / latest / 版本化页 | 有的页有 tar.gz 有的没有，资产名还不一样（github 后缀歧义） | 每次跨页对比 | 中 |
| 3 安装脚本自身故障面 | `curl \| sh` 装机 | 脚本依赖链（下载→PATH→签名→锚点配对）任何一环断即装机失败 | #67/#68/#77 三轮已证 | 中 |
| 4 滚动页资产堆积 | 看 ohos-latest 资产列表 | tag 通道每次打 tag 塞一个新名字的 tar，无上限增长 | 每 tag | 低-中 |

## 2. 决策（用户拍板记录）

1. **预签名版发布为 tar.gz**（springmin 式：`tar xzf` → 直接跑），滚动通道补齐
   ——三条通道打包形态就此一致；
2. **双资产收敛为两件套**：签名 tar.gz（主路径）+ 裸未签名二进制（自签自选）；
   裸签名二进制移除（tar.gz 就是签名版的发布形态，无增量）；
3. **install-bun-ohos.sh 退役删除**：下载/PATH/签名三个角色分别由 curl 一行、
   README 的 PATH 提示、发布侧预签门禁覆盖；脚本不存在后，#67 的 REPO 硬编码、
   #68 的版本配对、#77 的 sed 注入锚点+配对门禁**整类故障面消失**；
4. **ohos-latest 归容器通道独占**（每次 push 刷新），tag release 完全自包含、
   不再刷新 ohos-latest——滚动页跨通道资产名堆积（缺陷 4）连根消除。

## 3. 修后契约

| 通道 | OHOS 资产 | 页面安装指引 |
|---|---|---|
| ohos-latest（容器通道，每 push 刷新） | `bun-ohos-aarch64-github-<V>.tar.gz` + `bun-ohos-aarch64-github-unsigned` | 单 Quick Install 节 |
| latest（五平台滚动） | `bun-ohos-aarch64-<V>.tar.gz` + `bun-ohos-aarch64-unsigned`（+四平台裸二进制） | 同上（带 OHOS device 后缀） |
| 版本化 tag（自包含） | `bun-ohos-aarch64-<V>-<C>.tar.gz` + `bun-ohos-aarch64-unsigned` | 同上 |

Quick Install 节只保留 tar 两行命令；代理 / PATH / unsigned 自签 / 损坏诊断四条提示移除
（由 tar.gz README 与资产名自解释承载），Disclaimer + Known Limitations 前置到页面最前。整体回到 #79 的五段式统一布局。

tar.gz 内容 = 签名 bun + README（无脚本）。README 三段：直接跑 / 可选 PATH /
Permission denied = 损坏重下。

## 4. 验证

- 两 workflow YAML 解析通过；全仓 `install-bun-ohos` 引用零残留（历史 ledger 除外）；
- 本地 tar roundtrip：`tar xzf` → `./<dir>/bun` 结构与用户示例一致；
- 发布门禁资产清单扩至 tar.gz（tar 名取自实际装配文件而非重算，body 命令恒等于
  上传资产）；
- check-pr.sh 全项 PASS（单 commit b6e51965b6，base 含交付线 tip）；
- **待真机冒烟**：`tar xzf → ./bun --version` 免签名直跑（tar.gz 主路径）、
  `-unsigned` 自签路径。

## 5. 未修复形态

- 不做本 PR：三指引并存 + 通道不一致 + 脚本故障面延续（每项单独可感，见速览表）；
- 本 PR 的门禁在缺 tar.gz 资产时直接红——任一通道不再打包 tar.gz 即 CI 暴露。

## 6. 关联

- 前史：[pr81-p2-presigned-release-assets.md](pr81-p2-presigned-release-assets.md)（预签落地 + §5 remote 代码级对比）
- 脚本缺陷史：[pr67-p2-install-script-release.md](pr67-p2-install-script-release.md)（#67/#68/#77 三轮，本 PR 后归档为历史）
- 签名机制：[`../knowledge/codesign-and-spawn-primer.md`](../knowledge/codesign-and-spawn-primer.md)

## §后续：#84 页面布局微调（2026-09-24）

#83 的合并与最终页面布局强推发生竞态——进交付线的 b6e51965b6 仍带四条安装
提示 bullet 且 Disclaimer/Known Limitations 在页尾（强推的 f913f74afe 未赶上
合并）。[#84](https://github.com/jx-bit/bun/pull/84) 以纯 body 文本重构送达
终态：Disclaimer + Known Limitations 前置，Quick Install 只留 tar 两行命令
（代理/PATH/自签/损坏四条提示由 tar.gz README 与资产名承载）。纯文本变更，
资产/门禁不动，无"未修复即红"门禁（body 文本不承重）。 免责声明同步精简为中英双语短句（非官方社区项目、社区开发者维护），替换原英文长段。

---
---
*立档：2026-09-24 | 分析者：Sisyphus | 依据：两 workflow 实读 + 本地 tar roundtrip + 用户拍板记录*
