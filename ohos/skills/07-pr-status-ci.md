## Skill 7：查看 PR 状态和 CI

### 目的

跟踪 PR 的 CI 检查结果，知道哪些通过哪些失败。

### 操作

```bash
# 1. 查看所有 check 状态
gh pr checks <PR#> --repo jx-bit/bun

# 2. 只看失败的
gh pr checks <PR#> --repo jx-bit/bun | grep fail

# 3. 查看某个 run 的状态
gh run view <run_id> --repo jx-bit/bun --json status,conclusion

# 4. 列出最近的 runs
gh run list --repo jx-bit/bun --branch dev --limit 5

# 5. 查看特定 workflow 的 runs
gh run list --repo jx-bit/bun --workflow=ohos-build-github.yml --limit 3
```

### OHOS build 的 CI 时间

| 阶段 | 耗时 |
|---|---|
| 容器启动 + 工具链 | ~5 分钟 |
| 自编译 __n1 libcxx | ~10 分钟（首次，之后缓存） |
| WebKit 编译 | ~10 分钟 |
| Rust + C++ 编译 | ~10 分钟 |
| **总计** | **~30-35 分钟** |

---
