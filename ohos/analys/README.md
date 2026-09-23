# analys/ 索引

> 失败归因、验收追踪与数据集。**活跃文档在根部**（8 个），历史取证在
> [`archive/`](archive/)（9 个，内容完整保留，引用链接已更新）。

## 活跃文档（根部）

| 文件 | 内容 | 状态 |
|---|---|---|
| [20260922-cross-platform-divergence-audit.md](20260922-cross-platform-divergence-audit.md) | **跨平台偏离审计（fork vs 官方 v1.4.0）**：81 文件 226 hunk 逐谓词分类——3 功能级泄漏（cgroup 路径被删 / transpiler 无门 / OPENHARMONY 位进 ALL 掩码）+ 4 项有意跨平台修复待拍板（含 PR #56 的门）+ 10 处无门控角落回退 + 构建面不一致；干净面 ~85% 精确门；配套分诊脚本 `audit-triage.sh` | 2026-09-22 建立 |
| [20260922-two-branch-comparison-and-adoption.md](20260922-two-branch-comparison-and-adoption.md) | **参照线双分支对比与采纳分析**:ohos-aarch64(历史全量线)× ohos-minimal(1.4.2 现役线,151 commit)拓扑定性、5 项确认缺失的可采纳修复(cwd 截断/EEXIST→CTL_MOD/net errno 锁存/IN_ATTRIB/getgroups)+ 4 项已有等价 + 基建候选;**流向反转实锤(A 在采纳我方 "authority" 修复)** | 2026-09-22 建立 |
| [20260917-round-report.md](20260917-round-report.md) | **轮报告(G/H 轮)**:八轮演进 101→39→32→29→15→15、615b48e95 全量 931 fail 用例分解、独有 15 真实构成(8 慢性超时+3 verdaccio+PARKED+2 待定性)、lists/ 提取缺陷与 log 口径、A3-11 兑现缺口、下一步 | 2026-09-20 建立 |
| [20260914-failures-root-cause-and-user-impact.md](20260914-failures-root-cause-and-user-impact.md) | **失败深度分析**：独有 32（六簇逐文件签名+根因）× overlap 161（八族）× 用户影响总表（17 功能面）；基建噪声与真代码债分离；**八族口径仍为 overlap 分类的参照系** | 2026-09-14 建立 |
| [next-fulltest-acceptance-checklist.md](next-fulltest-acceptance-checklist.md) | fulltest 验收清单（预期转绿项/观察项）；**头部已回填 H 轮验收结果**（A3-11 libcPathForDlopen 未兑现等） | 每轮更新 |
| [20260911-jxbit-only-55-attribution.md](20260911-jxbit-only-55-attribution.md) | B-only 失败簇归因总表 + A 锚定方法论两条 + PR #32 效果 | 持续更新 |
| [cherry-pick-tracker-v1.4.0.md](cherry-pick-tracker-v1.4.0.md) | v1.4.0 线上游 cherry-pick 追踪 | 持续更新 |
| [20260908-overlap-135-classification.md](20260908-overlap-135-classification.md) | 135 个双轮重叠失败的分类（OHOS 环境基线） | 参考 |

## archive/（历史取证，供追溯）

| 文件 | 主题 |
|---|---|
| [archive/20260914-round-report.md](archive/20260914-round-report.md) | round D（14fdf0d56）轮次报告：三轮演进 101→39→32、wave2 战果、6 回归候选（已被 G/H 轮报告取代） |
| [archive/confirm-jxbit-541794f8d-rerun-20260914.md](archive/confirm-jxbit-541794f8d-rerun-20260914.md) | round F 期 541794f8d 失败集复跑确认 |
| [archive/fix-tasks.md](archive/fix-tasks.md) | 007d7a07e 轮 29 独有失败 → 4 修复任务拆解（含 p1~p6 探针实验，pr41 证据引用） |
| [archive/probes.zip](archive/probes.zip) | p1~p7b 探针脚本原始打包（pr43 证据引用；p8 套件在根部 [`probe-p8/`](probe-p8/)） |
| [archive/tri-way-diff-analysis-2026-08-28.md](archive/tri-way-diff-analysis-2026-08-28.md) / [-08-29](archive/tri-way-diff-analysis-2026-08-29.md) / [-09-02](archive/tri-way-diff-analysis-2026-09-02.md) | 三方树对比的三个日期快照（演进过程） |
| [archive/ci-forensics-5c0a93130-vs-3c97d0089.md](archive/ci-forensics-5c0a93130-vs-3c97d0089.md) | CI 取证（正文 + findings 已并入附录） |
| [archive/ci-pipeline-three-way-comparison.md](archive/ci-pipeline-three-way-comparison.md) | 三条 CI 管道机制对比 |
| [archive/four-files-lost-and-restored-explained.md](archive/four-files-lost-and-restored-explained.md) | 4 文件丢失/恢复事件复盘 |
| [archive/autofix-ci-format-pipeline.md](archive/autofix-ci-format-pipeline.md) | autofix.ci 格式化管道说明 |
| [archive/workflow-skill-handbook.md](archive/workflow-skill-handbook.md) | 旧入口指针（skills/ 现已上移至 `ohos/skills/`） |

## 数据与工具

- [`fulltest-data/`](../fulltest-data/README.md) — 设备 fulltest 轮次数据：
  **`615b48e95/`（最新，H 轮）**已解包入库（log + 全量报告
  + 确认文档 + lists/）；更早轮次按保留策略归档至
  [`fulltest-data/archive/`](../fulltest-data/archive/)（round-B/C/D/G，2026-09-21 起滚动执行）。逐文件地面真相 =
  各轮 runner log（lists/ 提取有缺陷，见轮报告 §2）
- `linux-baseline-fails-official-v140.txt` — 官方 v1.4.0 Linux x64 构建的失败基线（126 文件）：triage 时区分「上游也有」vs「OHOS 特有」。参考 x64 二进制已清理，来源 GitHub release bun-v1.4.0
- `probe-p8/` — 26286 hang / 子进程退出家族诊断套件（七针判定树 + 双 binary 对照脚本，**待设备侧执行回填**）
- **`skills/` 已上移至 [`ohos/skills/`](../skills/README.md)**（工作流手册：16 步
  拉代码 → 对比 → 立档 → 修复 → PR → CI 跟踪全流程，每步一文件）
