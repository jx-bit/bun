## Skill 15：CI artifact 拉取与 workflow dispatch（token 权限坑）

### 两类 token 的能力差异（本仓库实测）

| 操作 | 细粒度 PAT (github_pat_) | classic token (gho_) |
|---|---|---|
| gh api 读 runs/jobs | ✅ | ✅ |
| `gh run download` artifact | ❌ **静默失败**（空目录、无报错） | ✅ |
| workflow dispatch / cancel run | ❌ 403（缺 actions:write） | ✅ |
| self-hosted runner 列表 | ❌ 403 | （未测） |

### artifact 下载的可靠姿势

```bash
# 1) 找 run id（按 commit 前缀）
RUN_ID=$(gh api "repos/jx-bit/bun/actions/workflows/ohos-build-github.yml/runs?status=success&per_page=30" \
  --jq '.workflow_runs[] | select(.head_sha | startswith("535fb153")) | .id' | head -1)
# 2) 查 artifact id 与大小
gh api "repos/jx-bit/bun/actions/runs/$RUN_ID/artifacts" --jq '.artifacts[] | {name, size_in_bytes, id}'
# 3) classic token 直连 zip 下载（gh run download 失败时用它）
CLASSIC=$(grep -oP 'https://42936419:\K[^@]+' ~/.git-credentials | head -1)
curl -sL -H "Authorization: token $CLASSIC" -o out.zip \
  "https://api.github.com/repos/jx-bit/bun/actions/artifacts/<id>/zip"
```

### workflow dispatch（classic token）

```bash
gh api -X POST "repos/jx-bit/bun/actions/workflows/ohos-full-test.yml/dispatches" \
  -f ref=dev -f 'inputs[test-filter]=js/bun/spawn' \
  --header "Authorization: token $CLASSIC"
```

### 补充技巧（2026-09-03 实战）

- **修改文件并提交的最简通道**：`PUT /repos/<repo>/contents/<path>`
  （带 message/content(base64)/sha(现文件 blob)/branch）—— 一次调用
  完成 commit + ref 更新，无需手拼 blob→tree→commit→PATCH 四步
- **大文件 blob 走 @file**：base64 后的 payload 以 `-d @file.json` 传给
  curl；直接 `-d "$payload"` 在文件 >100KB 时报 "Argument list too long"
- **workflow dispatch 的默认分支限制**：workflow_dispatch 要求 workflow
  文件存在于仓库默认分支；只在 dev 上新增的 workflow，合并进默认分支前
 无法 dispatch（push 触发不受此限）
- **计数陷阱**：`content.count("name: <workflow>")` 会把 `run-name:` 行
  也算进去 —— 用 `^name:` 行首锚点或 strict YAML 解析器做重复键校验
- **REST commit 是追加式的**：fix-verify 循环里每轮 = 新 commit；
  合并时用 squash（或合并前本地 soft-reset 收敛）保证 1 PR 1 commit

### 诊断口诀

- `gh run download` 空目录无报错 → 换 classic + curl zip
- dispatch/cancel 403 → PAT 缺 actions:write，换 classic
- runner 列表 403 → PAT 非 admin，让仓库管理员查 Settings → Actions → Runners

---
