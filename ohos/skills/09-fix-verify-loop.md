## Skill 9：修复循环（Fix-Verify Loop）

### 目的

CI 失败 → 分析 → 修复 → 推送 → 再验证，循环直到通过。

### 操作

```bash
# 1. 分析失败原因（Skill 8）
gh run view <run_id> --repo jx-bit/bun --log-failed | grep ...

# 2. 定位根因（本地检查代码）
grep -n '相关代码' src/...

# 3. 修复
# 用 edit 工具修改

# 4. 提交（amend 到当前 commit 还是新建？）
# 如果是同一个问题的修复 → amend（保持 PR 只有 1 个 commit）
git add <file> && git commit --amend --no-edit

# 如果是不同问题的修复 → 新 commit
git commit -m "fix: <描述>"

# 5. 推送（WSL 网络不稳定时重试）
git push --force-with-lease origin dev
# 如果超时，在终端手动推

# 6. 重新触发 CI（如果 push 成功但 CI 没触发）
gh pr close <PR#> --repo jx-bit/bun && sleep 3 && gh pr reopen <PR#> --repo jx-bit/bun

# 7. 等 CI 完成（~30 分钟）
# 定期检查
gh pr checks <PR#> --repo jx-bit/bun

# 8. 如果又失败 → 回到步骤 1
```

### amend vs 新 commit 的选择

| 场景 | 用 amend | 用新 commit |
|---|---|---|
| 同一个 PR 的任何后续修改（补充修复、格式、追加批次） | ✅ | |
| 不同问题的修复（开新 PR） | | ✅ |
| 已经推送到 origin 的 commit | ✅（force push） | ✅ |

> **规则：一个 PR = 1 个 commit**（autofix.ci 的 bot commit 除外）。
> push 后被 autofix 顶出新 commit，后续再修改时先把本地 rebase 到
> `origin/dev`（含 autofix commit），再 amend 自己的那个 commit，
> 最后 `push --force-with-lease`。

---
