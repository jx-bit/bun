# CI Workflow 溯源（.github/workflows 全量谱系）

> 建立：2026-09-23。回答"整个 CI 流程的来源"——40 个 workflow 逐个溯源到
> 三层来源：**上游 oven-sh/bun 继承 → ljy 线 OHOS 家族 → jx-bit 交付线迭代**。
> 方法：`git log --diff-filter=A`（引入提交）× 三方参照（oven-sh bun/main、
> ljy9812/bun 当前、61dbc3a9d 参考树）。

## 1. 谱系总图

```
oven-sh/bun (上游)
  └─ ~30 个 workflow 原样继承（build-x86/release/format/rust-lints/update-* …）
      ↓ 2026-07-25  ljy9812（OHOS 移植线起点）
   9dcaf3279e7 "ci(ohos): add OHOS build/release pipeline"
      ├─ ohos-build.yml / ohos-build-rust.yml / ohos-build-incremental.yml
      ├─ ohos-release.yml / ohos-full-release.yml
      └─ ohos/install-bun-ohos.sh（安装脚本同批）
      ↓ 逐个加入
   07-30 ljy9810  ohos-build-github.yml（容器通道，GitHub-hosted）
   08-03 ljy9810  cross-x86.yml（交叉编译 spike）
   08-13 ljy9810  ohos-full-test.yml（fulltest 通道 + OPENHARMONY expectations）
   09-03 bytechears ohos-container-test.yml
   09-14 bytechears ohos-brew-deps-canary.yml（tap 重构后的容器门禁金丝雀）
      ↓ 2026-09 起交付线（jx-bit）迭代
   #64-#75：PCH / arch 令牌 / sysroot 门控 / 验证断言 / 并行化 / 发布页
```

**身份注**：ljy9812 / ljy9810 / bytechears 为参照线侧的三位提交者；我们的
交付线提交在 claude/* 分支经 PR 合入。

## 2. 三层分类（40 个文件）

| 层 | 数量 | 文件 |
|---|---|---|
| 上游继承 | ~30 | auto-assign-types / auto-close-duplicates / auto-label-claude-prs / build-x86 / bun-types / cancel-buildkite / claude-* ×3 / close-stale / comment-cop / deploy-site / format / freebsd-smoke / lint / on-slop / packages-ci / release / rust-lints / source-lints / update-* ×11 / vscode-release … |
| OHOS 家族（ljy 线） | 10 | 见 §3 |
| jx-bit 新增 | 0 | 无全新文件——全部迭代在 OHOS 家族之上 |

## 3. OHOS 家族逐文件溯源

| 文件 | 引入 | 用途 | 我们 vs ljy 分叉 | 交付线迭代 |
|---|---|---|---|---|
| ohos-build.yml | 07-25 ljy9812 | 自托管 OHOS 构建（批 1） | **4 行**（近一致） | 无 |
| ohos-build-rust.yml | 07-25 ljy9812 | OHOS Rust 构建 | 近一致 | 无 |
| ohos-build-incremental.yml | 07-25 ljy9812 | 增量构建（dispatch-only） | 近一致 | 无 |
| ohos-release.yml | 07-25 ljy9812 | tag `ohos-v*` 三件套发布 | **4 行** | #67（脚本路径/README URL）+ #68（tag 注入） |
| ohos-full-release.yml | 07-25 ljy9812 | 自托管全量发布（共享目录） | 近一致 | 无 |
| **ohos-build-github.yml** | 07-30 ljy9810 | 容器通道（GitHub-hosted） | **763 行**（深度分叉） | #67/#69/#71/#72（门禁/标题/body/并行 cross+publish） |
| **cross-x86.yml** | 08-03 ljy9810 | aarch64 宿主交叉编译 | **309 行**（深度分叉） | #66（workflow_call+sha+arm64 leg）/#70（arch 令牌）/#73（sysroot 门控）/#74（验证断言） |
| ohos-full-test.yml | 08-13 ljy9810 | fulltest 通道 | 中等 | runner env 迭代（pr26 线） |
| ohos-container-test.yml | 09-03 bytechears | 容器门禁测试 | 中等 | #35/#45/#46 线 |
| ohos-brew-deps-canary.yml | 09-14 bytechears | brew 依赖金丝雀 | 自有 | #46 线 |

## 4. 混乱点清单（溯源产出）

1. **多代通道共存未退役**：ohos-build / build-rust / build-incremental /
   full-release / build-github 五代构建通道并存，实际活跃的只有
   build-github（容器）与 full-release（自托管发布）；其余三代是历史层。
2. **双滚动 latest**：`ohos-latest`（OHOS 单品，bot 自动）与 `latest`
   （五产品，#72 后自动）并存 —— 参照线同构（他的 latest 是手工），语义
   不同（单品滚动 vs 多产品捆绑），页面标题已区分（#69）。
3. **WebKit fork 引用分裂**：我们的通道引用 oven-sh/WebKit@0f966e81，
   ljy 线引用 springmin/WebKit@ohos-aarch64 —— 同一 prebuilt 家族的两条
   指针，升级时要双处核对。
4. **分叉两极**：build/release/full-release 与 ljy 仅差 4 行（改 URL 即同
   步），build-github（763 行）/cross-x86（309 行）深度分叉 —— 后两者是
   全部交付线 CI 迭代的落点，也是唯一需要主动维护同步认知的文件。
5. **来源身份三账号**：ljy9812 / ljy9810 / bytechears（参照线侧多人多
   账号），溯源时按提交内容而非作者名判定。

## 5. 治理建议（按收益）

1. **退役声明**：在 ohos-build.yml / build-rust / build-incremental 三个
   历史通道头部加 `# SUPERSEDED by ohos-build-github.yml` 注释（或
   disable），消除"哪条是活的"的歧义。
2. **近一致文件的同步纪律**：release / full-release / build 与 ljy 仅差
   4 行 —— 改动它们时先 `diff` 对照，避免无意扩大分叉。
3. **深度分叉文件的所有权**：build-github / cross-x86 的改动一律走
   PR + issues 立档（现状已如此），文档即同步机制。
4. WebKit fork 引用统一决策：oven-sh/WebKit 固定 ref vs springmin 分支
   跟随 —— 二选一写入通道注释。

---
*立档：2026-09-23 | 分析者：Sisyphus | 方法：diff-filter=A 溯源 + 三参照比对*
