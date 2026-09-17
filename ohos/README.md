# ohos/ — OHOS 适配工作区

> 本 fork 的交付线：OHOS (OpenHarmony) aarch64 移植，目标分支 `ohos-aarch64`。
> **AI/新人从这里开始**：先读下面的硬性规则，再按「任务路由」进入对应文档。

## 硬性规则（违反 = 返工）

1. **一个 PR 一个 commit**。分支上的后续修改一律
   `git reset --soft <base>` → 重写 commit → `push --force-with-lease`；
   **禁止追加 commit**。
   **push 前必跑 `bash ohos/check-pr.sh <branch>`**（校验：单 commit、commit message
   与 PR body 无 fork 名/内部路径引用、diff 不含 ohos/ 与 Cargo.lock、base 含交付线
   tip）——FAIL 不推送。
2. **每个 PR（含 docs/CI）必须在 `ohos/issues/` 立档**：
   `pr<N>-p<P0阻断/P1回归/P2不完整/P3不阻断>-<关键词>.md`（根因 → 修复 →
   验证 → 参考实现对比），并更新 `issues/README.md` 索引行与脚注。
3. **PR 描述与 commit 禁止出现内部 fork 名 / 内部报告名**（中性说法代替）；
   必须含：根因、精确修复行、验证方式、在未修复构建上会失败的声明。
4. **跨树移植前先做排除法**：对候选簇跑
   `git diff <我方> 61dbc3a9d -- <该簇源区>`（61dbc3a9d = 通过全部测试的
   1.4.0 基参考构建）——**空 diff 即排除该区域**；非空则逐 hunk 核对
   cfg 归属与版本漂移（上游窗口修复 ≠ 参考树拥有的修复，勿混）。
5. **代码改动后过四件 lint 套件**：clippy 禁用类型（std `HashMap`/`Mutex`/
   `var_os`/`thread::spawn` → `bun_collections::HashMap` / `bun_threading::Guarded`
   / `bun_core::getenv_z` / `bun_threading` 工作池）；mordant 裸布尔参数 →
   命名结构体；`dead-code-escape-limits.json` 精确匹配（改代码后跑
   `test/internal/source-lints/dead-code-escapes.test.ts` 再生账本）；rustfmt。
6. **验证链**：CI 全绿（含 container 编译）→ 设备 fulltest 验收。
   复跑包的 `lists/` 三张集合清单（only / overlap / sys-only）是验收口径。

## 任务路由

| 要做什么 | 去哪 |
|---|---|
| 修一个失败用例/文件 | `analys/`（README 索引取最新归因文档）→ 规则 4 排除法 → 规则 2 立档 → port/修 → PR |
| 看某个 PR 的来龙去脉 | `issues/`（README 索引行 → 对应 pr 文档） |
| 设备复跑数据回来了 | 解包到 `analys/test-reports/` → 更新归因文档数字与簇归属 → 重算剩余清单 |
| OHOS 内核/沙箱怪行为 | `knowledge/`（README 有索引：codesign/spawn primer、测试台账、CI 对比） |
| 工作流步骤细节 | `skills/`（16 步：拉代码 → 对比 → 立档 → 修复 → PR → CI → 失败分析） |
| 对外使用者说明 | `OpenHarmony-Bun-已知限制与规避指南.md`（功能级限制 × 影响 × 规避，无内部信息） |

## 目录

| 目录 | 内容 |
|---|---|
| `issues/` | PR 台账（每 PR 一档 + 索引 + 规程），**主索引入口** |
| `knowledge/` | 长期知识：测试树改动台账、设备 STATUS、codesign/spawn primer、修复指南 |
| `analys/` | 归因/取证/验收 + 轮次数据集（archive 存历史轮） |
| `skills/` | 工作流手册（16 步 + 索引）：拉代码 → 对比 → 立档 → 修复 → PR → CI → 失败分析 |
| `fulltest/` | 设备全量测试脚本（launcher / 部署 / 安装签名）——**入库** |
| `_archive/` | 暂时归档（未跟踪：junit 变体脚本等 round C 定型后再定去留） |

> 本 README 已入库（AI/新人入口）；其余子目录（issues/knowledge/analys/skills 等）
> 仍为构建机本地工作区，精简后分批入库；`analys/binary/reports/BINARIES-SOURCE.md`
> 记录已清理的参考二进制来源。
