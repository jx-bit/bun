# P3: PR 构建 CI 双跑（push/pull_request 触发器重叠）— 工作记录

> **关联 PR**：[#33](https://github.com/jx-bit/bun/pull/33)（claude 分支 → ohos-aarch64，单 commit `0bc299e9ad`）
> **状态**：✅ 合并（2026-09-11，merge commit `dec28e0278`）
> **定位**：CI 效率问题（非测试回归）。每个 PR 的每次 push 实际 4 个 run
> （2× ohos-build-rust + 2× ohos-build-github），runner 时间与排队都翻倍。

## 1. 机制（用户定位，2026-09-11）

两个 workflow 都定义了重叠触发器：`push: [ohos-aarch64, claude/ohos-*]` +
`pull_request: [ohos-aarch64]`。PR 开着时每次 push 双事件命中：

- push → 构建分支头（`refs/heads/claude/...`）
- pull_request → 构建 `refs/pull/N/merge`

并发组 `group: <workflow>-${{ github.ref }}` 在两种事件下永不相同，
`cancel-in-progress: true` 匹配不上 → 两套并行跑完。`ohos-container-test.yml`
无此问题（push 只精确匹配 ohos-aarch64，正确范式）。

## 2. 修复

两个 workflow 的 `push.branches` 删除 `claude/ohos-*`（+1 行防回归注释），对齐
container-test 范式：PR 一套（pull_request 事件）、合并后一套（push 事件）、
WIP push 不烧 runner。`pull_request` 侧与并发组不动（重复源消失即够）。

> **命名注意**：曾考虑"以后 PR 分支换个命名避开 push 触发器"——不可行，push
> 触发器匹配的就是 `claude/ohos-*`，而仓库规矩要求 PR 分支必须 claude/ 开头，
> 任何合规命名都必然双触发。修触发器是唯一正解。

## 3. 验证

- 本 PR 自身的 push 仍双跑一次（push 事件用分支上的旧 workflow 定义），合并后生效
- 合并后观察下一个 PR：每次 push 应只有 pull_request 事件的 2 个 run

## 4. 关联

- 累计交付：#30（platform）→ #31（F3 shim）→ #32（F1 管道，OPEN）→ #33（本 PR）
