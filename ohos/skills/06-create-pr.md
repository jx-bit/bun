## Skill 6：创建 PR

### 目的

把 dev 分支的修改推送到 ohos-aarch64 分支。

### 操作

```bash
# 1. 确保 dev 和 origin/dev 同步
git push origin dev

# 2. 创建 PR
gh pr create --repo jx-bit/bun \
  --base ohos-aarch64 \
  --head dev \
  --title "fix(ohos): <标题>" \
  --body '### Problem
<问题是什么>

### Fix
<修了什么，列出文件>

### Risk
<有什么风险>

Co-Authored-By: Agent'

# 3. 如果 PR 已存在，更新描述
gh pr edit <PR#> --repo jx-bit/bun --body '<新描述>'
```

### PR 描述风格

参考上游 oven-sh/bun 的 PR 格式：

```markdown
### Problem
- 什么问题，几句话

### Fix
- 怎么修的，列出文件和关键改动

### Background
- 为什么这样修，技术原理

<details><summary>Notes</summary>
额外细节
</details>
```

### 注意

- 描述用英文（参照上游风格）
- **不提及 social4hyq / ljy9812 等内部 fork 名字** —— 中性说法用
  "the device-validated OHOS port" / "the other OHOS port line"
- 标题不用 conventional commit 前缀（上游用 `fix(ohos):` 格式）
- **创建 PR 前自查**（body + commit message 一起查）：

```bash
gh pr view <N> --repo jx-bit/bun --json body --jq '.body' | grep -icE 'social4hyq|ljy9812|ohos-bun'
git log --format='%B' -1 | grep -icE 'social4hyq|ljy9812|ohos-bun'
# 两处都应为 0；commit message 在 push 前查，PR body 在 create 后查
```

---
