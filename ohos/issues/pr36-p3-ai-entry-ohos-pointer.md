# P3: AI 入口断层——AGENTS/CLAUDE 零提及 OHOS 交付线 — 工作记录

> **关联 PR**：[#36](https://github.com/jx-bit/bun/pull/36)（claude 分支 → ohos-aarch64，单 commit `ec766acb2c`，+18 行纯文档）
> **状态**：🔄 OPEN
> **定位**：工作流基础设施。任何 AI 代理落库首读的 AGENTS.md/CLAUDE.md 只载上游
> Bun 规则，OHOS 交付线的存在、台账、方法论全部不可发现——每次靠人工口头交接。

## 1. 机制

- 根入口 `AGENTS.md`（→ `CLAUDE.md` 的符号链接，一文件双入口）无一处 OHOS 指针；
  `grep -in ohos AGENTS.md` 为空
- `ohos/` 是未跟踪本地目录（fresh clone 不存在）——即使 AI 主动 `ls` 也仅在
  git status 未跟踪列表里偶然可见
- 本轮（pr30–pr33）沉淀的文档体系（issues 台账 / 归因方法论 / 修复指南）入口为
  `ohos/README.md`，但悬浮在主线入口之外

## 2. 修复

两个入口文件（同一文件）开头新增「OHOS adaptation line (this fork's delivery
line)」：入口链（ohos/README → issues/README）、分支/commit 规矩、最新设备数据
位置、跨树移植方法论（同基线锚定 + cfg/漂移核对，指向 pr31 §3 / pr32 §3），
并明确 ohos/ 为构建机上的本地工作目录（fresh clone 不存在）。

## 3. 验证

- `diff AGENTS.md CLAUDE.md` 一致（符号链接）；CI 纯文档变更
- 效果验收：新开一个 AI 会话落库，首读 AGENTS.md 后应能不经人工提示到达
  ohos/issues/README.md 并正确遵循立档/分支规矩

## 4. 关联

- 前置清理：`--help/`、`undefined/` 垃圾目录与已合并分支清理（同日）
- 文档体系入口：`ohos/README.md`（顶层地图，2026-09-11 建立）

## 5. 后续：重送（2026-09-17）

原 PR 撤回后，指针内容于 09-17 以精简形态重送：**[#47](https://github.com/jx-bit/bun/pull/47)**
（单 commit `ae0b7f536f`，2 文件：CLAUDE.md 指针一句 + ohos/README.md 首批入库）。

与原方案差异：
- 指针从"一节 OHOS 交付线介绍"瘦身为**一句话**（路径 + 目标分支 + 阅读时机），
  规则细节留在 README 单一来源，避免双事实源漂移
- ohos/README.md 随同入库（入口文档先行），子目录仍为本地工作区、精简后分批入库；
  分支守卫脚本规则 3b/3c 相应由"diff/body 禁含 ohos/"改为**白名单制**
  （当前白名单 = ohos/README.md，随入库批次扩充）
- 入库的 README **不含即时状态节**（合并清单/失败数字等快照类内容不入公开库），
  状态事实源在本地台账 issues/README.md；README 只留入口、硬规则、路由、目录

状态：重送独立立档为 [pr47-p3-ai-entry-readme.md](pr47-p3-ai-entry-readme.md)（全量覆盖口径：每 PR 一行一档），本节保留为原方案与撤回记录
