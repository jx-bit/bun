# knowledge/ 索引

> 长期知识：台账、primer、对比、指南。按用途查；历史演进见各文档头部日期。

## 台账（持续更新）

| 文件 | 内容 |
|---|---|
| [OHOS-PLATFORM-DEFECTS.md](OHOS-PLATFORM-DEFECTS.md) | **鸿蒙平台缺陷与限制清单（权威结论视图）**：epoll/exec/splice/fs/net/进程/签名 七个子系统的已实证系统层怪癖，按稳定 ID 归档（EP-1…CS-4），每条含现象/证据/对策/状态 + shim 拦截器对应表 + 已知未解清单。修复/移植/验收前先查这里 |
| [OHOS_TEST_STATUS.md](OHOS_TEST_STATUS.md) | **设备侧主台账**（608KB）：T 编号问题逐条（根因/修复/真机验证）+ C 探针证据。OHOS 内核/沙箱怪行为**的完整证据链**在这里（本清单是它的结论视图） |
| [test-tree-changes-vs-v1-4-0.md](test-tree-changes-vs-v1-4-0.md) | **测试树改动台账**：121 文件逐条机制详解 + 28 处参数适配 + skip 健康度 |
| [chronic-timeout-registry.md](chronic-timeout-registry.md) | **慢性超时固定集台账**：G↔H 12 文件重灾清单（G↔H 11/12 相同）+ A 轮对照 + 验收扣减规则 |
| [ci-workflow-provenance.md](ci-workflow-provenance.md) | **CI Workflow 全量溯源**：40 个文件三层来源（上游继承/OHOS 家族/jx-bit 迭代）+ 分叉度 + 混乱点清单与治理建议 |

## Primer（工作机制入门）

| 文件 | 内容 |
|---|---|
| [codesign-and-spawn-primer.md](codesign-and-spawn-primer.md) | OHOS 签名机制 + spawn 链路（为什么 EACCES、怎么自签） |
| [bun-test-architecture-primer.md](bun-test-architecture-primer.md) | Bun 测试套件结构（launcher/runner/expectations 体系） |

## 对比（fork 间机制差异）

| 文件 | 内容 |
|---|---|
| [ci-comparison-social4hyq.md](ci-comparison-social4hyq.md) | 与 social4hyq 的 CI 构建管道对比 |
| [ci-comparison-springmin.md](ci-comparison-springmin.md) | 与 springmin 的 CI 构建管道对比 |
| [runner-comparison-social4hyq.md](runner-comparison-social4hyq.md) | 测试 runner 口径对比 |

## 指南

| 文件 | 内容 |
|---|---|
| [jxbit-fix-guide-20260910.md](jxbit-fix-guide-20260910.md) | 修复行动指南（F1/F2/F3；**三处归因修正已回写**——以文中灰色引用块为准，F1→pr32、F3→pr31、F2 已撤） |
| [confirm-jxbit-rebuild-20260910.md](confirm-jxbit-rebuild-20260910.md) | rebuild 复跑取证 + platform 修复源码级根因（pr30 的输入） |
