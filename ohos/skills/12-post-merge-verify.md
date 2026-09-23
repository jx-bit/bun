## Skill 12：PR 合并后验证

### 目的

PR 合并到 ohos-aarch64 后，验证 ohos-aarch64 分支上的代码是正确的。

### 操作

```bash
# 1. 确认合并成功
gh pr view <PR#> --repo jx-bit/bun --json state,mergedAt,mergeCommit

# 2. 确认 ohos-aarch64 包含合并
git fetch origin ohos-aarch64
git log origin/ohos-aarch64 --oneline -5

# 3. 确认关键文件正确
git show origin/ohos-aarch64:<file> | grep '<关键内容>'

# 4. 合并后 push 到 ohos-aarch64 会自动触发 push 构建流水线
gh run list --repo jx-bit/bun --branch ohos-aarch64 --limit 3

# 5. 确认 v1.4.0 是 ohos-aarch64 的祖先
git fetch bun bun-v1.4.0
git merge-base --is-ancestor bun-v1.4.0 origin/ohos-aarch64 && echo "v1.4.0 是祖先"
```

---
