# P3: CI lane 清理——死文件退役 + 报警去噪 + 职责地图
> **关联 PR**：[#78](https://github.com/jx-bit/bun/pull/78)

> 用户提出 CI 流水线文件"交织在一起，谁做什么不清楚"。盘点全部注册 workflow
> （GitHub 44 个：OHOS 9 + 上游继承 ~30 + 幽灵 2 + 平台内置 1）后定位五个
> 病灶并整治。

## 1. 缺陷

| # | 缺陷 | 证据 |
|---|---|---|
| 1 | 三个死文件混在目录：ohos-build.yml（显式 DISABLED）、ohos-build-incremental.yml（仅手动、从未跑）、ohos-full-release.yml（触发 tag `ohos-full-v*` 从未推过） | workflow API 三者 0 次运行 |
| 2 | full-test 每周定时：自托管构建 job 等待 runner **24 小时**超时 | run 35542678381 注释 "exceeded the maximum execution time while awaiting a runner for 24h0m0s"；09-06/13/20 三周连续 |
| 3 | container-test 每周定时：全量测试集仅带 5 个排除，移植线已知失败基线下**结构性红** | 09-13、09-20 两周定时均失败；失败步骤 Run test suite（30m45s，前置 11 步全绿 = 基础设施正常，是测试基线红） |
| 4 | canary 语义错误：浮动 tip 无 sysroot（= 无可升级，**常态**）被表达为红色事故 | run 日志 "no ohos-sdk* keg carries native/sysroot"；09-16 起每天红 ≥8 天；同期构建 lane 锁 pin 全绿证明非真实事故 |
| 5 | 无职责地图：lane 的触发器/产物/活性全靠读 700 行文件考古 | 本会话定位"哪个 workflow 拥有哪个 release"耗费多轮考古 |

**用户影响速览**：

| 缺陷 | 用户在做什么 | 感知症状 | 频率 | 严重度 |
|---|---|---|---|---|
| 1 | 读 CI 目录 / 排查构建问题 | 分不清哪些 lane 是活的，读死代码浪费时间 | 每次接触 CI | 中 |
| 2 | 查看 Actions 页 | 每周一条灰色超时 run | 每周 | 中（噪音） |
| 3 | 查看 Actions 页 | 每周一条红色失败 run | 每周 | 中（噪音掩盖真事故） |
| 4 | 查看 Actions 页 | canary 连红 8 天，真报警来时已无感 | 每天 | 中（报警疲劳） |
| 5 | 新人/AI 上手 CI | 必须逐文件考古才能建立职责模型 | 每次上手 | 低（摩擦） |

## 2. 修复（PR #78，claude/ohos-ci-cleanup，+58/−823）

1. **删三个死文件**（git 历史可找回）；自托管构建骨架自此只存在于
   ohos-release.yml 一份（full-release 与其 80% 重复的病灶随之消失）。
2. **full-test / container-test 移除每周 schedule**，保留 workflow_dispatch
   （container-test 的 `--test-filter` 部分跑输入不变）。
3. **canary 语义修正**：无 sysroot → `::warning` + exit 0（"tip NOT
   consumable, keep OHOS_CORE_PIN"）；有 sysroot → 打印 bump SHA；红只留给
   评估失败（pour 失败/keg 缺失）。CORE_SHA 经 GITHUB_ENV 传入验证步骤。
4. **新增 `.github/workflows/README.md`**：活跃 lane 职责/触发/产物一页表 +
   已删除记录 + 定时语义约定（红 = 需处理；常态结论 = 绿 + warning）。
5. **上游降噪（交接）**：本会话 PAT 无 Actions:write 权限，`gh workflow
   disable` 全部 403——待用户以 UI 或有权限 token 执行禁用清单：
   claude-find-issues-for-pr（每 PR 红叉，缺 ANTHROPIC_API_KEY）、
   cancel-buildkite-on-pr-close（fork 无 BuildKite，14 天空转 24 次）、
   comment-cop（35 次）、close-stale-robobun-prs、auto-close-duplicates、
   release（上游发布机器）。**不动**：on-slop（有 `repository == 'oven-sh/bun'`
   守卫永不触发）、update-* ×10（每周 skip 零噪音）、format/lint/rust-lints/
   source-lints/bun-types/auto-label（在本 fork 实际工作）。

## 3. 验证

- 三处编辑 workflow YAML 解析通过；全部 run 块 `bash -n` 零失败；触发器
  形态核对（两测试 lane 无 schedule、canary 保留每日 cron）。
- canary 双分支本地模拟：可消费 → 打印 bump SHA；不可消费 → warning；均退出 0。
- 删除候选先经 workflow API 确认 0 次运行。
- check-pr.sh 全项 PASS（单 commit、message/body 无违禁引用、diff 白名单、基线新鲜）。

## 4. 与 #77 的关系

无文件重叠、无冲突。README 中 tag 发布 lane 的触发描述按 #77 合并后的
任意 tag 形态书写，任一合并顺序皆可（先合 #78 则 README 短暂超前）。

## 5. 归因方法备忘

- 死活判定：`gh run list --workflow=X --limit 1` 的运行历史 + 触发器形态
  （manual-only 从未手动 = 死）。
- 失败归因三件套：`gh run view <id>` 看 job/step 级结论（区分基础设施红
  vs 测试基线红）→ `--log-failed` 看日志尾部 → 对照工作流源码的断言语义
  （这次 canary"红=契约变化"的旧语义就是从文件头注释读出来的）。
- 幽灵注册（文件已删、API 仍注册）：不影响运行，GitHub 最终自清，不处理。

---
*立档：2026-09-23 | 分析者：Sisyphus | 依据：workflow API 全量盘点 + run 日志归因 + 三文件实读*
