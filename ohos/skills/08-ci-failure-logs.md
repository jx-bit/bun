## Skill 8：拉取和分析 CI 失败日志

### 目的

OHOS build 失败时，提取错误信息定位根因。

### 操作

```bash
# 1. 获取失败的日志（自动匹配失败的 job）
gh run view <run_id> --repo jx-bit/bun --log-failed

# 2. 过滤关键错误行
gh run view <run_id> --repo jx-bit/bun --log-failed | \
  grep -iE 'error|FAILED|cannot|undefined|not found' | \
  grep -v 'Performing\|Looking\|Checking\|sphinx\|note:\|warning' | head -20

# 3. 过滤特定类型的错误
# Rust 编译错误
gh run view <run_id> --repo jx-bit/bun --log-failed | grep 'error\['

# C++ 编译错误
gh run view <run_id> --repo jx-bit/bun --log-failed | grep 'fatal error'

# 链接错误
gh run view <run_id> --repo jx-bit/bun --log-failed | grep -E 'ld: error|undefined reference'

# Cargo 错误
gh run view <run_id> --repo jx-bit/bun --log-failed | grep -E 'error:.*cargo|error:.*lock'

# 4. 获取完整 build.log（OHOS 构建会上传 artifact）
gh run download <run_id> --repo jx-bit/bun --name ohos-build-log

# 5. 看 job 状态
gh api repos/jx-bit/bun/actions/runs/<run_id>/jobs --jq '.jobs[] | {name: .name, status: .status, conclusion: .conclusion}'
```

### 常见错误模式识别

| 错误模式 | 含义 | 典型原因 |
|---|---|---|
| `error[E0308]: mismatched types` | Rust 类型不匹配 | 上游重构改变了类型 |
| `error[E0425]: cannot find value` | Rust 变量/函数不存在 | 函数在不同作用域 |
| `fatal error: 'xxx.h' file not found` | C++ 头文件缺失 | include 路径错误或头文件不存在 |
| `ld.lld: error: undefined reference` | 链接时符号未定义 | 库缺失或符号 mangle 不匹配 |
| `ld.lld: error: version script assignment...` | version-script 引用不存在的符号 | OHOS shim 符号在非 OHOS 平台是 UND |
| `cannot update the lock file because --locked` | Cargo.toml 和 Cargo.lock 不同步 | merge 后 lock 文件过期 |
| `cannot update Cargo.lock... --locked` | 同上 | 同上 |
| `error connecting to api.github.com` | 网络问题（WSL） | 重试或手动在终端操作 |
| `mordant: N finding(s) over the baseline` | dylint 发现新 finding | 修代码或更新 baseline，或加 `continue-on-error: true` |
| `test ! -s target/mordant/over-baseline.txt` 失败 | 同上 | 同上 |
| `autofix.ci app is not installed` | autofix.ci GitHub App 未安装 | 在 repo Settings → GitHub Apps 安装 |

> **mordant 注意**：上游（oven-sh/bun）的 mordant job 设了 `continue-on-error: true`（advisory，不阻断 CI）。social4hyq 同样。如果我们的 mordant job 没有这个设置，OHOS 专属代码（如 ohos_sign）的新 finding 会导致 CI 硬失败。详见 `ohos/issues/pr8-p3-mordant-tuple-wants-struct.md`。

---
