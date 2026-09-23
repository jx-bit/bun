## Skill 2：多仓库对比分析

### 目的

找出我们的代码和上游、social4hyq、ljy9812 之间的所有差异，按文件分组。

### 操作

```bash
# 1. dev vs 上游 v1.4.0 差异（文件列表）
git diff --name-only HEAD bun-v1.4.0 | sort > /tmp/diff-v14.txt

# 2. dev vs social4hyq 差异（用 GitHub API，因为 fetch 可能超时）
gh api "repos/social4hyq/ohos-bun/compare/ohos-aarch64...jx-bit:bun:dev" \
  --paginate --jq '.files[].filename' | sort > /tmp/diff-hyq.txt

# 3. dev vs ljy9812 差异
gh api "repos/ljy9812/bun/compare/ohos-aarch64...jx-bit:bun:dev" \
  --paginate --jq '.files[].filename' | sort > /tmp/diff-ljy.txt

# 4. 交叉对比：哪些文件同时和上游+social4hyq 都不同
comm -12 /tmp/diff-v14.txt /tmp/diff-hyq.txt | wc -l
# 结果 > 0 说明这些是 dev 独有改动

# 5. 按目录分组统计
cat /tmp/diff-v14.txt | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn

# 6. 每个文件的 OHOS 标记计数（区分 OHOS 专属 vs 意外丢失）
while IFS= read -r f; do
  ohos=$(git diff HEAD bun-v1.4.0 -- "$f" 2>/dev/null | grep '^-' | \
    grep -ciE 'ohos|__OHOS__|target_env|EPOLLONESHOT|ohos_sign|OHOS_CC|BUN_BFM|HWY_DISABLED')
  lines=$(git diff --numstat HEAD bun-v1.4.0 -- "$f" 2>/dev/null | awk '{print $1+$2}')
  printf "%3s OHOS  %4s lines  %s\n" "$ohos" "$lines" "$f"
done < /tmp/diff-v14-src.txt
```

### OHOS 标记关键字清单

| 关键字 | 含义 |
|---|---|
| `__OHOS__` | C++ 条件编译宏 |
| `target_env = "ohos"` | Rust cfg 条件 |
| `ohos_sign` | OHOS 签名 crate |
| `ohos_set_pwd` | OHOS pwd fallback |
| `OHOS_CC/OHOS_CXX` | OHOS 编译器覆盖 |
| `BUN_BFM` | Highway SVE polyfill |
| `HWY_DISABLED_TARGETS` | Highway SVE 禁用 |
| `EPOLLONESHOT` | epoll one-shot 禁用 |
| `copy_file_fallback` | install EPERM 回退 |
| `Strategy::IgnoreFailure` | Symlinker 忽略策略 |
| `openharmony` | OHOS 的 process.platform |
| `__MUSL__` | musl libc 宏 |

---
