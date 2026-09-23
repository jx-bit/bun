# P3: AI 入口指针重送 + ohos/README.md 首批入库 — 工作记录

> **关联 PR**：[#47](https://github.com/jx-bit/bun/pull/47)（单 commit
> `374fc9134f`，2 文件：`CLAUDE.md` +1 行指针、`ohos/README.md` 首批入库）
> **状态**：✅ 合并（0eafc2a105，2026-09-17）
> **定位**：原 #36（AI 入口断层）09-14 撤回后未重送，AI 落库首读 AGENTS.md
> 仍无法到达交付线台账与硬规则；本 PR 补齐入口并让入口文档本身入库。
> 前案记录见 [pr36 文档](pr36-p3-ai-entry-ohos-pointer.md) §1-§4。

## 1. 根因

- pr36 文档 §1：AGENTS/CLAUDE 无 OHOS 交付线入口，AI 落库即断链。
- 09-17 新增一层：AI 按 AGENTS.md 提 PR 时不遵循交付线 PR 规约
  （#46 描述未按模板、未立档）——入口缺失的实害已发生，重送优先级上调。

## 2. 修复内容（2 文件）

1. `CLAUDE.md`（AGENTS.md 为其符号链接，一处编辑双入口生效）：**Landing
   PRs** 小节末尾一句话指针——交付线 PR 规格在 `ohos/README.md`，开/改 PR
   前必读。
2. `ohos/README.md` 首批入库：入口、硬性规则、任务路由、目录图。两个防腐
   设计：
   - **不含即时状态节**（合并清单/失败数字等快照不入公开库），状态事实源
     在本地台账 issues/README.md 单点维护；
   - **任务路由只绑稳定目标**（目录/各 README 索引，不绑带日期的归因文档；
     未入库文件用代码样式路径不放 markdown 链接，公开页零死链）。
   尾注写明拆分现状：其余子目录（issues/knowledge/analys/skills 等）仍为
   本地工作区，精简后分批入库。

## 3. 与原 #36 方案的对比

| 维度 | 原 #36（撤回） | 本 PR |
|---|---|---|
| AGENTS.md 内容 | 一节 OHOS 交付线介绍 | 〔源码〕一句话指针（路径+分支+时机），规则细节留 README 单一来源，避免双事实源漂移 |
| ohos/README.md | 未入库（外部不可达） | 首批入库；去即时状态、去日期绑定、去悬空链接 |
| 守卫脚本 | "diff/body 禁含 ohos/"一刀切 | 〔源码〕check-pr.sh 规则 3b/3c 改**白名单制**（当前白名单 = ohos/README.md，随入库批次扩充）——不改则 gate 拦截入库动作本身 |

## 4. 验证

- `bash ohos/check-pr.sh` 全项 PASS：单 commit、commit message/body 无违禁
  引用、diff 仅白名单内 ohos/ 文件、base 含交付线 tip
- 指针可达性：AGENTS.md → CLAUDE.md 符号链接实测；README 与指针同 commit
  落库，链接不悬空
- README 时效性：全文无日期绑定文件、无即时状态数字（grep 实证）
- 未修复构建的失败形态：AI 落库无入口 → 提 PR 不按交付线规约（#46 实证）

## 5. 关联

- 前案：pr36（撤回记录与原始设计）
- 实害案例：pr46（描述未按模板、未立档——入口缺失的直接后果）
- 后续：ohos/ 其余子目录精简后分批入库；check-pr.sh 白名单随批次扩充
