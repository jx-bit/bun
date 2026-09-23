# P1: cwd/rlimit/tmpdir/可执行检查 OHOS 加固（参考线 3 文件移植）— 工作记录

> **关联 PR**：[#42](https://github.com/jx-bit/bun/pull/42)（单 commit，3 文件 +156/−62，
> 与 A 逐字节一致）
> **状态**：🔄 OPEN
> **定位**：全树 A 侧 OHOS 补丁分诊（30 文件）中的 bun_core/resolver/c-bindings 簇——
> 对应 which/26207/exec 族、bun-run/bun-run-bunfig 的 cwd 面、以及 fd 预算类隐患。

## 1. 四项修复（A 侧设备实证，逐字移植）

### 1.1 删除 cwd 的诚实传播（BUG-01，`bun_core/util.rs` + `resolver/lib.rs`）

OHOS 的 ohos-compat-shim 拦截 `getcwd()`：cwd 被删除时**静默替换为 $HOME**
而非返回 ENOENT。后果：`bun test`/`bun install` 在用户真实 $HOME 里继续跑
（从不确定环境执行 JS），而非干净报错。

- 新增 `getcwd_honest()`：OHOS 上经 `/proc/self/cwd` readlink+stat 复核，
  真删除则返回 `CurrentWorkingDirectoryUnlinked`（错误变体已在 error.rs）
- `getcwd_or_exe_dir()` 同步修正：撤销 shim 的替换，回落 exe-dir（与上游
  语义对齐——启动继续、`process.cwd()` 稍后报真实错误）
- resolver 的 DirnameStore 路径改用 `getcwd_honest`（BUG-01 传播点）

### 1.2 rlimit 软上限跌落回退（`resolver/lib.rs`）

`ulimit -Sn 256 && exec bun`（OHOS 实测形态）：无特权进程无法抬高 hard
limit → 现有 setrlimit 整体失败 → 整个会话以 **256-fd 预算**运行（fd 耗尽
类失败的潜在来源）。回退语义对齐 Node：soft 抬到 hard 允许的上限。

另：OHOS 并入 musl 的 163840 下限门控（OHOS 即 musl 基）。

### 1.3 tmpdir 运行时可写性探测重写（`resolver/lib.rs`）

OHOS `/tmp` 为只读 erofs。A 版本：`OnceLock` 缓存 + `/tmp` →
`/data/local/tmp` → `$HOME/tmp` → `/tmp`（末选）的运行时 access(W_OK)
探测链，替换我方的静态顺序版（TMPDIR 优先 + 固定回退链）。

### 1.4 `is_executable_file` OHOS 内核 bug（`c-bindings.cpp`）

OHOS 内核 `open(O_EXEC)` **不检查 x 权限位**（0660 文件误判可执行）。
改用 `access(X_OK)` + `S_ISREG` 复核（目录 x 位 = traversal，需排除）。
影响 PATH 可执行解析（which/26207/exec 家族）。

## 2. 与 social4hyq 实现的对比（逐字核验）

证据类型：〔源码〕两树 diff 逐字核验；〔实测〕A 轮设备行为。

| 维度 | social4hyq（61dbc3a9d，A 轮） | 我方（541794f8d1）→ 本 PR |
|---|---|---|
| 删除 cwd 传播 | 〔源码〕`getcwd_honest` + resolver 挂钩（BUG-01） | shim 静默替换 ❌ → 逐字节移植 |
| rlimit 跌落回退 | 〔源码+实测〕EPERM 时 clamp 到 hard | 整体失败即放弃 ❌ → 同 A |
| tmpdir 探测 | 〔源码+实测〕OnceLock 运行时 access 链 | 静态顺序版 ❌ → 同 A |
| `is_executable_file` | 〔源码〕access(X_OK)+S_ISREG | open(O_EXEC)（OHOS 内核不查 x 位）❌ → 同 A |

## 3. 验证

- `cargo check -p bun_core -p bun_resolver` ✓；dead-code-escapes lint 0 fail
- c-bindings.cpp 为 C++ → CI container 编译验证
- 设备复测预期：which/26207/exec 族转绿；bun-run/bun-run-bunfig 的 cwd 面
  改善；EMFILE/fd 预算类随机失败减少

## 4. 关联

- 全树 A 侧 OHOS 补丁分诊（30 文件）：DNS 簇 = PR #40、本 PR = 本簇、
  install 簇（PackageManager/resolver_hooks）待后续
- 行为变化声明：tmpdir 探测顺序与 A 对齐（TMPDIR 优先级被 A 移除，
  设备上 A 轮已验证该顺序）；`bun run` 的 $HOME 回退不再 seed
  npm_package_* 身份变量（A 的 gating，防跨包身份污染）
