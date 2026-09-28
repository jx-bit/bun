# ohos/agent-guides/ — 通用 Agent 工作流 Skills

教 agent 用 `gh` 提 PR、读 CI 状态、看 CI 构建日志、做修复循环；所有操作参数化（`<owner>/<repo>`、`<base>/<head>`、`<PR#>` 占位符），不绑定任何具体 fork，换仓库即可复用。与构建机本地工作区的 `ohos/skills/`（fork 专属 16 步实战手册）互补：那边是 fork 专属实战记录，这里是通用操作规程。

## 索引

| 文件                                           | 标题                                     |
| ---------------------------------------------- | ---------------------------------------- |
| [gh-create-pr/](gh-create-pr/SKILL.md)         | 用 gh 创建/更新 PR                       |
| [gh-ci-status/](gh-ci-status/SKILL.md)         | 读取 PR 的 CI 状态                       |
| [gh-ci-logs/](gh-ci-logs/SKILL.md)             | 拉取 CI 构建日志与根因分析               |
| [fix-verify-loop/](fix-verify-loop/SKILL.md)   | CI 失败修复循环                          |
| [ci-not-triggered/](ci-not-triggered/SKILL.md) | CI 未触发排查                            |
| [pr-merge-verify/](pr-merge-verify/SKILL.md)   | PR 合并后验证                            |
| [buildkite-ci/](buildkite-ci/SKILL.md)         | 上游 BuildKite CI 调试                   |
| [check-pr.sh](check-pr.sh)                     | push 前门禁（单 commit/违禁引用/白名单） |

## SKILL.md 格式约定

每个主题一个目录 + `SKILL.md`。frontmatter 含 `name` + `description`（description 写触发条件：用户说什么话/什么场景该加载）。正文用英文书写。

## 使用方式

Agent 按需读取对应主题目录下的 `SKILL.md`；人读本 README 导航。

## 更新规范

- 新经验 = 新建主题目录，不塞进已有文件
- 内容变更直接修改对应文件
