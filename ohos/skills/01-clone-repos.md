## Skill 1：拉取四方代码仓库

### 目的

确保本地能同时对比 4 个仓库的代码：上游、social4hyq、ljy9812、我们。

### 操作

```bash
# 1. 确认 remote 已配置（一次性）
git remote -v
# 应该看到：
# bun    → oven-sh/bun.git（上游）
# hyq    → social4hyq/ohos-bun.git
# ljy    → ljy9812/bun.git
# origin → jx-bit/bun.git

# 2. 拉取上游 tag（OHOS 适配基于 bun-v1.4.0）
git fetch bun bun-v1.4.0
# 拉完后可以用 bun-v1.4.0 引用上游代码

# 3. 拉取各方分支
git fetch hyq ohos-aarch64
git fetch ljy ohos-aarch64
git fetch origin ohos-aarch64
git fetch origin dev

# 4. 验证拉取成功
git cat-file -t bun-v1.4.0         # 应该输出 tag
git cat-file -t hyq/ohos-aarch64   # 应该输出 commit
```

### 注意

- 如果网络超时，重试即可（WSL 环境常见）
- `git fetch` 超时改用 `gh api` 或 `curl` raw.githubusercontent.com 获取单个文件

---
