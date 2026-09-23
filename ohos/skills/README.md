# OHOS Bun 工作流 Skills 索引

> 从零开始的完整工作流：拉代码 → 对比分析 → 写 issue 文档 → 修复 → 提 PR → 跟踪 CI → 分析失败 → 修复循环。
> 每个 skill 是独立可复用的步骤，按编号串联；新增经验以 `NN-<语义slug>.md` 追加单个文件。

## Skill 清单

| 文件 | 标题 |
|---|---|
| [01-clone-repos.md](01-clone-repos.md) | 拉取四方代码仓库 |
| [02-multi-repo-compare.md](02-multi-repo-compare.md) | 多仓库对比分析 |
| [03-single-file-three-way.md](03-single-file-three-way.md) | 三方对比单个文件 |
| [04-write-issue-doc.md](04-write-issue-doc.md) | 写 Issue 分析文档 |
| [05-apply-fix.md](05-apply-fix.md) | 执行修复 |
| [06-create-pr.md](06-create-pr.md) | 创建 PR |
| [07-pr-status-ci.md](07-pr-status-ci.md) | 查看 PR 状态和 CI |
| [08-ci-failure-logs.md](08-ci-failure-logs.md) | 拉取和分析 CI 失败日志 |
| [09-fix-verify-loop.md](09-fix-verify-loop.md) | 修复循环（Fix-Verify Loop） |
| [10-update-analysis-from-ci.md](10-update-analysis-from-ci.md) | 从 CI 失败中更新分析文档 |
| [11-ci-not-triggered.md](11-ci-not-triggered.md) | 处理 CI 未触发的情况 |
| [12-post-merge-verify.md](12-post-merge-verify.md) | PR 合并后验证 |
| [13-fetch-merged-pr.md](13-fetch-merged-pr.md) | 获取合并后的 PR 内容 |
| [14-wsl-hdc-device.md](14-wsl-hdc-device.md) | WSL 直连鸿蒙真机（hdc 三条路径） |
| [15-ci-artifact-dispatch.md](15-ci-artifact-dispatch.md) | CI artifact 拉取与 workflow dispatch（token 权限坑） |
| [16-device-fulltest.md](16-device-fulltest.md) | 真机 fulltest 部署与执行（鸿蒙 PC / aarch64 设备） |

## Skill 增补规范

1. 新经验 = 新文件 `skill-NN.md`（顺延编号），不塞进已有文件
2. 单文件只讲一个可复用动作：场景 → 操作 → 坑 → 对比表（如适用）
3. 内容变更直接改对应文件；跨 skill 的流程变化更新本 README 的示意
4. 本目录随修复进展**实时更新**（如 Skill 14-16 来自 2026-09-02 真机接入实战）
