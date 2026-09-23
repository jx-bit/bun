## Skill 13：获取合并后的 PR 内容

### 目的

PR 合并到 ohos-aarch64 后，获取合并结果到本地 dev 分支，继续下一个问题的修复。

### 操作

```bash
# 1. 确认 PR 已合并
gh pr view <PR#> --repo jx-bit/bun --json state,mergedAt,mergeCommit

# 2. 拉取合并后的 ohos-aarch64（获取 merge commit）
git fetch origin ohos-aarch64

# 3. 切换到本地 dev 分支，拉取 origin/dev（应该已在合并前推送过）
git checkout dev
git pull origin dev

# 4. 如果 origin/ohos-aarch64 上有 GitHub 自动生成的 merge commit
#    （如 "Merge pull request #N from jx-bit/dev"），本地 dev 可能没有这个 commit
#    需要 rebase 或 merge 使 dev 和 ohos-aarch64 对齐：
git merge origin/ohos-aarch64
# 或
git pull --rebase origin ohos-aarch64

# 5. 验证合并结果
git log --oneline -5
git diff origin/ohos-aarch64 --stat  # 应该没有差异（或只有分析文档）
```

### 常见情况

| 情况 | 处理 |
|---|---|
| dev 和 ohos-aarch64 都有 merge commit（内容相同 SHA 不同） | `git merge origin/ohos-aarch64` 解决分叉 |
| dev 落后于 ohos-aarch64（GitHub merge commit 不在 dev 上） | `git merge origin/ohos-aarch64` 带进来 |
| dev 领先于 ohos-aarch64（有新的修复还没提 PR） | 正常，下一个 PR 会带到 ohos-aarch64 |
| 分析文档出现在 git diff 里 | `ohos/analys/` 下的文档不提交，reset 即可 |

---

## 实战案例时间线

```
┌────────────────────────────────────────────────────────────────┐
│ PR #4: 方案B 全量导出 + __n1 libcxx（8 次修复循环）             │
├────────────────────────────────────────────────────────────────┤
│ 08:00 → push 方案B commit                                      │
│ 08:10 → FAIL: bun_install 编译错 (Symlinker.rs 类型不匹配)      │
│ 08:25 → push Symlinker 修复                                    │
│ 08:50 → FAIL: StrongSet.h 找不到 (WEBKIT_REF 版本不匹配)        │
│ 08:58 → push WEBKIT_REF 修复                                   │
│ 09:33 → ✅ OHOS build 通过（30m15s）                            │
│         但验证的是裁剪版 symbols.dyn，非方案B                    │
│ 10:18 → PR #3 合并（方案B 改动在 amend 中，未经 CI 验证）        │
│ 14:16 → PR #8 push 方案B + OHOS build 触发                      │
│ 14:16 → FAIL: Cargo.lock --locked (ohos_sign 不在 lock 里)      │
│ → 加 ohos_sign 到 5 个包的依赖列表 + package 条目               │
│ → FAIL: Symlinker.rs 类型不匹配                                 │
│ → Ok(()) → Ok(true)/Ok(false)                                  │
│ → FAIL: StrongSet.h 找不到 (WEBKIT_REF 不匹配)                  │
│ → WEBKIT_REF: caad865e → 0f966e81                              │
│ → FAIL: WebKit 找不到 cstddef (自编译 __n1 symlink 路径错误)    │
│ → CROSS 改绝对路径 + ln -sfn + 头文件验证                        │
│ → FAIL: WebKit 报 rune table (self-compiled __n1 头文件)        │
│ → patch __config_site + flags.ts 加 defines                     │
│ → FAIL: bun_install 编译错 (同 Symlinker)                       │
│ → 修复 Symlinker                                                │
│ → ✅ OHOS build 通过（30m13s）                                  │
├────────────────────────────────────────────────────────────────┤
│ PR #5: Highway SVE 移除                                         │
│ → ✅ OHOS build 通过（31m37s）                                  │
├────────────────────────────────────────────────────────────────┤
│ PR #6: shim 符号补全 (8→15)                                     │
│ → ✅ OHOS build 通过                                            │
├────────────────────────────────────────────────────────────────┤
│ PR #7: run_command.rs 补 5 个 gate                              │
│ → FAIL: root_dir_info_is_fallback 作用域错误                    │
│ → 移除 completions 函数里的错误引用                              │
│ → ✅ OHOS build 通过（30m13s）                                  │
├────────────────────────────────────────────────────────────────┤
│ PR #8: Source lints + dead-code baseline + Windows LTO          │
│ → FAIL: rust-toolchain.toml 仍有 OHOS                           │
│ → 移除 OHOS                                                     │
│ → FAIL: Windows LTO config（windowsCross 丢失）                 │
│ → 恢复 v1.4.0 的 windowsCross LTO 逻辑                          │
│ → FAIL: linux LTO full→thin（v1.4.0 改了）                      │
│ → 恢复 v1.4.0 的 ThinLTO                                        │
│ → FAIL: -fno-split-lto-unit when 条件不对                       │
│ → 改回 c => c.lto（所有平台）                                    │
│ → ✅ Source lints 通过                                          │
│ → OHOS build 跑中                                               │
└────────────────────────────────────────────────────────────────┘
```

---
