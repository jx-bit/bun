# P0: core tap 锁定 + sysroot 契约断言（tap 漂移治本）— 工作记录

> **关联 PR**：[#46](https://github.com/jx-bit/bun/pull/46)（单 commit，2 文件
> `.github/workflows/ohos-build-github.yml` + `ohos-brew-deps-canary.yml`，
> +58/−7；rebase 于 5613067cf0）
> **状态**：🔄 OPEN
> **定位**：pr45（sysroot 布局探测）是热修——上游再改名时探测链自适应，但
> llvm@21 之外的面（bun.rb 依赖、llvm flags、bottle 剪枝）漂移仍会直接打穿
> 构建 lane。本 PR 治本：把漂移源锁在构建 lane 之外，升级走 canary 验收。

## 1. 根因（继承 pr45 §1，本轮新增漂移源定位证据）

事故本身见 pr45 §1（镜像 digest 恒等、tap 改名致 sysroot 缺失）。本轮补齐
两个此前未定位的事实：

1. **漂移源不是 `social4hyq/core`**。该 tap 只是 11 个 formula 的覆盖层
   （bun.rb / bun-webkit / bun-bootstrap 等，`Formula/b/bun.rb`）；`llvm@21`、
   `ohos-sdk` 等由 bun.rb **不带前缀**引用，实际解析在烘焙进镜像的
   **harmonybrew core tap**（`brew --repo harmonybrew/core`）。定位过程：
   克隆 social4hyq/homebrew-core 在 09-15 时点 commit 下 `find Formula -name
   "*.rb"` 无 llvm@21〔实测〕→ 沿其自带 `.github/scripts/setup-container.sh`
   找到 core tap 的 fast-forward 逻辑 → `git ls-remote` 探测
   `atomgit.com/harmonybrew/homebrew-core` 成功〔实测〕。
2. **断裂 commit 精确到 39a060948**（2026-09-16 15:06 +0800，"llvm@21: use
   ohos-sdk-native"；同日 07:00 UTC 先落 `ohos-sdk-native: add 26.0.0.18
   bottle`）。其父 `5380be4e`（09-16 10:40 +0800）验证为已知良好状态：
   `Formula/l/llvm@21.rb` 第 33 行 `depends_on "ohos-sdk@26.0.0.18"`（注释
   "sysroot + libcxx-ohos headers"）、`Formula/o/ohos-sdk@26.0.0.18.rb` 存在
   且含 arm64_ohos bottle〔源码，克隆逐字节核对〕。pr45 注释里"镜像内置旧
   版 keg 必在"的假设由此部分修正：09-15 成功轮的版本化 keg 实为**运行时
   pour 所致**（当时浮动 tap 的 llvm@21 依赖还是版本化名），非镜像烘焙。

## 2. 修复内容（2 文件）

**`ohos-build-github.yml`**：

- 新增 `OHOS_CORE_PIN: 5380be4e…`（env，注释含事故日期与断裂 commit 号）。
- "Install brew deps" 步：`brew update` **之后**、pour **之前**，容器内
  `git -C "$(brew --repo harmonybrew/core)" fetch origin main` +
  `checkout --detach $OHOS_CORE_PIN`。顺序承重：update 会把 core 重置到
  origin/main，pin 放 update 前会被静默覆盖。fetch/checkout 失败即
  `::error` 退出（坏 pin 数秒内红，绝不静默浮动）。
- 验证步加 **sysroot 内容断言**：至少一个 `opt/ohos-sdk*` keg 携带
  `native/sysroot`——旧检查只验 keg 存在（09-17 事故中 `OK
  ohos-sdk-native` 放行、6 分钟后死于 configure）。

**`ohos-brew-deps-canary.yml`**：

- canary **有意保持浮动**（消费 core origin/main）：每日验证新 tip，绿了
  才 bump pin；Pour 步打印 core tip SHA（bump 即复制粘贴）。
- Verify 步加与构建 lane 相同的 sysroot 断言——否则 keg 存在性检查会让
  布局漂移下的 canary 持续绿灯，失去预警意义（本次事故类即如此穿透）。

升级流程闭环：canary 绿于新 tip → 复制打印的 SHA → 改 `OHOS_CORE_PIN`
（一行 diff，PR 审查）→ 构建 lane 获得新 tap。

## 3. 与 social4hyq 实现的对比

| 维度 | social4hyq（setup-container.sh） | 我方 → 本 PR |
|---|---|---|
| core tap 状态 | 〔源码〕`fetch origin main` + `reset --hard origin/main`，**有意浮动** | 锁定到验证 commit；浮动面移交给 canary |
| 浮动的合理性 | 他们消费**自己的** tap/镜像一体化，漂移即其产品内部变更 | 我方消费**别人的** tap，浮动 = 无验收的上游变更直通 PR 门禁 |
| 布局漂移防护 | 〔推断〕其 lane 未暴露（2026-09-16 后其自身构建是否受影响未知） | 探测链（pr45）+ 内容断言（本 PR）双层 |

## 4. 验证

- **真实容器**：PR 自身 CI run 35179783293 的 "Install brew deps" 步——
  同时承载 pin checkout 与 sysroot 断言、均为失败即红设计——**已成功
  通过**（步骤绿即两者通过）；完整 ninja 编译仍在跑（本 PR 不触碰构建面，
  workflow-only diff）。
- **pin SHA 溯源**：克隆 atomgit core 于 `5380be4e` 逐文件核对（见 §1）。
- YAML 解析 ✓；canary 文件 prettier 干净；build-github.yml 的 prettier 报差
  为基线既有（workflow_dispatch inputs 引号风格，本 PR 未触碰行）。
- 待验证：canary 新断言 + SHA 打印——手动 dispatch 因 token 缺
  `actions:write` 被拒（HTTP 403），由下一次每日调度（02:23 UTC）覆盖。
- 不确定项：pin 对 overlay tap（social4hyq/core）未覆盖——其漂移仍靠
  canary 现有验证集 + pr45 探测链兜底（pr35 事故先例在 bun.rb 侧）。

## 5. 关联

- 前序：pr45（sysroot 探测热修，本 PR 的直接动因）、pr35（tap 动态解析
  合同的建立——本轮证明"动态解析名字"仍不够，须锁状态）
- 相关：pr36（AI 入口指针）——AGENTS.md 已在工作区加入指向
  ohos/README.md 的描述（未提交，待独立 PR 送达；不并入本 PR，见一 PR
  一关注点）
- 同族合同演进：静态名（09-14 破）→ 动态名（09-17 破）→ 布局探测
  （pr45）→ **锁状态 + 验收式升级**（本 PR）
