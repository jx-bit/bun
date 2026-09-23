## Skill 5：执行修复

### 目的

根据 issue 文档的修复方案，修改代码。

### 操作步骤

```bash
# 1. 确保在 dev 分支上，工作区干净
git checkout dev && git pull origin dev
git status  # 确认干净

# 2. 修改代码
# 用 edit 工具逐文件修改

# 3. 验证修改
# grep 确认修改到位
grep -n '新增的关键字' <修改的文件>

# 4. 提交
git add <修改的文件>
git commit -m "fix(ohos): <修改描述>

<详细说明：根因 → 修复 → 影响范围>

Co-Authored-By: Agent"

# 5. 推送
git push --force-with-lease origin dev
# 注意：WSL 环境下网络可能超时，重试即可
# 如果多次超时，在终端手动推送
```

### 修改原则

1. **OHOS 代码必须 cfg gate**：`#[cfg(target_env = "ohos")]` 或 `#ifdef __OHOS__`
2. **非 OHOS 路径不能受影响**：修改后 grep 确认非 OHOS 逻辑没变
3. **注释必须解释 why**：不加 WHAT 注释，只加 WHY 注释
4. **一次修一个 issue**：每个 PR 只涉及一个问题
5. **一个 PR 一个 commit**：PR 的全部修改 amend 进唯一 commit；
   唯一例外是 autofix.ci bot 追加的 `[autofix.ci] apply automated fixes`
   commit（无法控制，出现即表示格式被 CI 收敛，属正常）。分批实现同一
   问题时，后续批次同样 amend 进该 commit（`git add -A && git commit
   --amend --no-edit`），不做第二个 commit

---
