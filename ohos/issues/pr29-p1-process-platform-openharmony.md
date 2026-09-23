# P1: OHOS 构建 process.platform 误报 "linux" — 工作记录

> **关联 PR**：[#29](https://github.com/jx-bit/bun/pull/29)（claude 分支 → ohos-aarch64，单 commit `ff4f267b86`）
> **状态**：🔄 OPEN
> **定位**：20260908 轮 270 个 jxbit_only 失败的 **P0 根因**之一 —— 所有 isOHOS 门控
> 在我们的 binary 上静默失效。

## 1. 现象（决定性证据）

`fs-birthtime-linux.test.ts` 在两棵测试树中**逐字节相同**且带
`describe.skipIf(… || process.platform === "openharmony")`：

| binary | 结果 |
|---|---|
| 他们的（sys-release 轮） | ✅ 过（skip 生效） |
| 我们的（20260902，binary 535fb153c7） | ❌ 挂 ×4（skip 未生效） |
| 我们的（20260908，binary 46a905a6c） | ❌ 挂 ×4（同） |

同树同文件、二元变量 → 我们的 binary `process.platform` 没报 `"openharmony"`。
20260902 轮同因 —— **该 bug 存在于我们全部 OHOS binary**。

## 2. 机制

我们的 rust target 是 `aarch64-unknown-linux-ohos`：`target_os = "linux"`、
`target_env = "ohos"`。`src/bun_core/Global.rs` 的 `os_name` 只特判了 android：

```rust
pub const os_name: &str = if cfg!(target_os = "android") {
    "android"
} else {
    env::OS.name_string()   // ← OHOS 落这里；OS 枚举无 Ohos 变体 → Linux → "linux"
};
```

`os_display` 同理（banner 显示 "Linux arm64"）。

## 3. 与 social4hyq 实现的对比（逐字核验）

### 3.1 结论先行

他们的 fork **有**这个特判，我们**没有**——这是两家 fork 的真实功能差异（不是
照抄关系）。我们的修复 = **移植他们的补丁**，功能代码与他们的版本逐字一致。

### 3.2 逐项对照

| 维度 | social4hyq（ohos-aarch64 @ 36854e8e） | 我们（PR #29） |
|---|---|---|
| `os_name` | `cfg!(target_env = "ohos")` → `"openharmony"`，android 次之，默认落 `env::OS.name_string()` | 移植后**功能逐字一致** |
| `os_display` | `cfg!(target_env = "ohos")` → `"OpenHarmony"` | 移植后一致 |
| 注释 | 合并为单条："Android + OHOS: the kernel-level OS enum stays .linux (so syscall switches keep working), but user-facing strings — npm user-agent, process.platform — must match Node.js so native-addon optional deps resolve correctly" | 我们保留了原 android 注释 + 新增 OHOS 注释（**措辞组织差异，功能无差异**） |
| 内核枚举 | 保持 `.linux`（syscall 开关不受影响） | 同 |
| npm 发布命名 | 不受影响（`bun-linux-<arch>-ohos`） | 同 |

### 3.3 溯源：这个补丁是他们自研的，官方没有

**官方 `bun-v1.4.1` tag 的 `Global.rs` 不含 openharmony**（grep 实证）——与 pr28
的守卫（官方 v1.4.1 原生携带）性质不同。platform 特判是 **social4hyq 的自研
OHOS 补丁**，在他们线上真机验证。我们 8/13 的 upstream main 合并即使再新也带
不来它（它不在上游）——这就是为什么两家的"鸿蒙适配方案差不多"，这个 bug 却
只存在于我们的 binary。

### 3.4 失效的完整链条（为什么一个字符串能炸出这么多失败）

`process.platform = "linux"` 时，测试树里所有以它为条件的适配**全部静默走错
分支**：

1. `skipIf(isOHOS)` → 不跳过：fs-birthtime（hmdfs birthtime=0）等直接红；
2. `isOHOS ? tempDir/cwdScope : undefined` → 不切换：依赖 tmpdir 适配的用例
   在错误位置创建产物；
3. 平台条件 fixture/依赖 → 选错变体：esbuild、`@ohos-npm-ports/typescript` 等；
4. npm user-agent 平台段 = "linux" → `@ohos-ports/*` 的 optional deps 解析路径
   与其包声明（os: openharmony）不符。

20260908 轮 270 个 jxbit_only 中 **23 个文件**的测试内容含此类门控——这 23 个
是本 PR 的直接解释范围。

> **边界澄清（2026-09-09 修正）**：unix socket 簇（listen-connect-args、
> serve-args、serve.test、socket.test）在 20260908 轮属于 **overlap（两轮都挂）**，
> 不是本 PR 范围——它们的失败与 binary 无关（设备 tmpdir 卷的 AF_UNIX 能力问题，
> 见 PR #27 的 tmpdir 探测）。本 PR 修复的是"门控失效"这一层。

### 3.5 生效后的连带面（为什么翻转是安全的）

- **内核枚举不动**：syscall 层（splice/openat2/epoll 等所有 OHOS 分支）零变化
- **vendored node 测试**：`common/index.js` 的 `isLinux` 已认 openharmony
  （两棵树都有该适配，L309）→ 不受反向影响
- **npm 发布命名**：`npm_name` 与 `os_name` 是两个字段，发布保持
  `bun-linux-<arch>-ohos`
- **他们树的 23 个门控**：适配路径本来就是真机验证过的——翻转后走的是
  "设备验证过"的分支而非"从没跑过"的分支

## 4. 修复内容（src/bun_core/Global.rs，+9/-2）

见 §3.2 对照表：`os_name`/`os_display` 各加一个 `cfg!(target_env = "ohos")`
分支。代码库既有同款写法：`signal_code_jsc.rs`、`run_command.rs`。

## 5. 验证

- 功能代码与 social4hyq 版本逐字一致；cfg 写法与代码库既有用法一致
- rustfmt 解析通过；cargo check 由 CI 承担（编写环境无编译工具链）
- 设备复验：下一轮 fulltest，23 个门控文件预期转绿（验收清单 A1-5b）；
  `bun -e "console.log(process.platform)"` 应输出 `openharmony`

## 6. 关联

- 同轮分析：`../analys/archive/compare-20260908-sys-release-vs-jxbit-46a905a6c.md` §3.0
- 验收清单：`../analys/next-fulltest-acceptance-checklist.md` A1-5b
- 同轮另一修复：[pr28-p1-browser-field-entry-panic.md](pr28-p1-browser-field-entry-panic.md)（性质不同：那是官方上游代码跟进，本 PR 是自研补丁移植）
- 测试树台账：`../knowledge/test-tree-changes-vs-v1-4-0.md` §13（合并后台账所有
  `// isOHOS:` 门控才真正生效的说明）

## 7. 后续（2026-09-10）

本 PR 的修复范围（Rust `Global::os_name`）只覆盖 npm/install 链路。rebuild 复跑
确认 JS 可见的 `process.platform` / `os.platform()` 仍报 "linux"——真实 getter
在 C++ `constructPlatform()`（缺 `__OHOS__` 分支），且 `os.platform()` 是 bundle
期 `TARGET_PLATFORM` 内联字面量，两处均未被本 PR 覆盖。后续修复见
[pr30-p1-process-platform-cpp-getter-and-bundled-inlining.md](pr30-p1-process-platform-cpp-getter-and-bundled-inlining.md)；
§5 的设备复验预期在 pr30 交付后才可达（复跑根因确认见
`../knowledge/confirm-jxbit-rebuild-20260910.md`）。
