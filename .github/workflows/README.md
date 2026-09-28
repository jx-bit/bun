# OHOS CI 职责索引

> 交付线 ohos-aarch64 的 workflow 一页地图；新增/改动/删除 lane 时同步本表。
> 上游（oven-sh/bun）继承的 workflow 不列于此——文件保持原样以减少上游合并
> 冲突；在本 fork 永不生效的上游 lane（comment-cop、buildkite 取消器、上游
> release 机器、issue 机器人、find-issues）应在仓库设置层禁用（Actions →
> 选中 workflow → ⋯ → Disable workflow），不改文件。

## 活跃 lane

| Workflow | 职责 | 触发 | 产物 |
|---|---|---|---|
| `ohos-build-github.yml` | 权威构建：容器通道全量构建（GitHub 托管 ARM）+ 预签（ohos-selfsign + verify 门禁） | push / PR 到交付分支；任意 tag push（排除滚动 tag） | `ohos-latest`（签名 tar.gz + unsigned）、`latest`（5 平台 + OHOS tar.gz/unsigned）、**tag push → 版本化 release（6 产物，页面自动生成）**；统一页面布局，占位文档自动播种到 release-docs |
| `ohos-build-rust.yml` | 快速反馈：自托管增量 Rust 构建（sccache） | push/PR 命中 Rust 源码路径 | 无（仅构建校验） |
| `ohos-brew-deps-canary.yml` | 漂移哨兵：浮动 tap tip 日常验收 | 每日 cron | 运行结论：tip 可消费（打印 bump SHA）/ 不可消费（warning，保持 OHOS_CORE_PIN）；红 = 评估本身失败 |
| `ohos-container-test.yml` | 容器内 JS 测试集（无设备，全 GitHub 托管） | 手动 / 本文件变更 | results.json（`--test-filter` 支持部分跑） |
| `ohos-full-test.yml` | 两段式：自托管构建 → 容器测试 | 手动 / 本文件变更 | 测试报告 |

上游 lane 中在本 fork 实际工作的：format（autofix.ci）、lint、rust-lints、
source-lints、bun-types、auto-label。

## 已删除（2026-09-23，均从未运行过）

| Workflow | 淘汰原因 |
|---|---|
| `ohos-release.yml` | 版本发布通道（自托管构建，2026-09-24 退役）：自托管设备不存在，run 永远排队；版本发布改由 `ohos-build-github.yml` 的 tag 触发路径承载（容器构建 + 同构 6 产物 + 自动页面） |
| `ohos-build.yml` | 最早的交叉编译构建，早已显式禁用；被容器通道取代 |
| `ohos-build-incremental.yml` | "1-3 分钟增量构建"设想，仅手动触发且从未跑过；被 `ohos-build-rust.yml` 取代 |
| `ohos-full-release.yml` | 构建到共享目录的发布设想（触发 tag 从未推送）；tag 发布流已覆盖该需求 |

## 定时任务语义约定

红 = 需要有人处理；常态化的"无动作结论"一律绿 + warning（先例：canary 的
"浮动 tip 不可消费 → 保持 pin"）。测试 lane 的每周定时已移除——full-test
的自托管构建 job 曾在定时触发时等 runner 24 小时，container-test 以 5 个
排除跑全量集、在移植线已知失败基线清零前是结构性红；两者保留手动 dispatch。
