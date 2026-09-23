## Skill 11：处理 CI 未触发的情况

### 场景

push 成功了但 GitHub Actions 没有触发新的 run。

### 解决方案

```bash
# 方案 A：关闭再重开 PR（触发 pull_request 事件）
gh pr close <PR#> --repo jx-bit/bun && sleep 3 && gh pr reopen <PR#> --repo jx-bit/bun

# 方案 B：推一个空 commit
git commit --allow-empty -m "chore: trigger CI re-run"
git push origin dev

# 方案 C：手动触发 workflow（需要 Actions 权限）
gh workflow run ohos-build-github.yml --repo jx-bit/bun --ref ohos-aarch64
```

### 为什么 CI 有时不触发

| 原因 | 说明 |
|---|---|
| pull_request 触发在 base 分支的 workflow 文件里 | base 分支（ohos-aarch64）的 workflow 文件可能没有 pull_request trigger |
| concurrency cancel-in-progress | 新 push 取消了旧 run，但新 run 可能排队延迟 |
| GitHub Actions 缓存延迟 | push 后 CI 需要几秒到几分钟才触发 |
| force push | force push 理论上触发 synchronize 事件，但有时延迟 |

---
