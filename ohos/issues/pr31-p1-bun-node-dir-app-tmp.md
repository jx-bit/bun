# P1: OHOS 上 bun-node shim 落在不可写的 /tmp —— `Script not found "node"` — 工作记录

> **关联 PR**：[#31](https://github.com/jx-bit/bun/pull/31)（claude 分支 → ohos-aarch64，单 commit `d8f8db5547`）
> **状态**：🔄 OPEN
> **定位**：jxbit-fix-guide F3 根因簇（`bun run` PATH bin 查找失败，as-node 11 用例）——但
> 指南 §4 的归因有误，真实修复在 `src/install/lib.rs` 的 `BUN_NODE_DIR`，见 §3.1。

## 1. 现象

设备上（官方 v1.4.0 套件，跨三轮稳定）：

- `cli/run/as-node.test.ts` 11 用例全挂，stderr = `Script not found "node"`
- 指南冒烟：`PATH=/tmp/fakebin:$PATH bun run node` 同样失败

`fakeNodeRun`（harness L649）的 argv 是 `[bun, "--bun", "node", file]`——**不注入任何
PATH**，依赖 bun 内置的 bun-node shim 机制。桌面 Linux 同 argv 通过（系统 bun 实测），
设备失败 → binary 在 shim 链路上有平台差异。

## 2. 机制

`bun --bun node <file>` 的解析链：

```
scripts(无) → 文件(无) → .bin/PATH fallback: which(PATH, "node")
                                                    ↑
                            PATH 首段 = <BUN_NODE_DIR>（bun-node/node → bun 自身的链接）
                                                    ↑
                            shim 由 create_fake_temporary_node_executable() 种下
```

shim 创建（`src/install/lib.rs`）：

```rust
match bun_sys::mkdir(DIR_Z, 0o700) {
    ...
    Err(_) => return Ok(()),   // ← OHOS 设备上 /tmp 不可写，mkdir 必败，静默放弃
}
```

`BUN_NODE_DIR` 硬编码 `/tmp/bun-node-<sha>`。OHOS 应用沙箱不可写 `/tmp`（应用可写
tmp 在 `/data/storage/el2/base/tmp`）→ mkdir 必败 → `return Ok(())` 静默跳过（调用方
无从感知）→ PATH 无 shim → `which("node")` 落空 → `Script not found "node"`。

11 个用例共用这一条链，是其在设备失败的唯一解释。次生问题：即使 mkdir 成功，OHOS
tmpfs 对新建目录强制 setgid + group-write，EEXIST 复用检查要求 `mode & 0o022 == 0`
→ 第二次运行起拒绝已有目录 → 首跑过、复跑挂的间歇态（release 构建 shim 目录按
GIT_SHA 常驻，必然复用）。

## 3. 与 social4hyq 实现的对比（逐字核验）

### 3.1 指南归因修正（先说结论）

jxbit-fix-guide §4 让 port `src/which/lib.rs`（190 行 diff、`search_bin_in_path`
统一入口）。**逐字核验后该归因不成立**：这 190 行 diff 的每个 hunk 都是
`#[cfg(windows)]` 代码（`WIN_EXTENSIONS_W`/`which_win`/`search_bin_in_path_list`/
`.com` 扩展等），是参考树 base（1.4.2）的上游 Windows 侧重构，POSIX `which()`
在两树间零差异。照搬它对 OHOS 零效果。

真实修复在参考树 `src/install/lib.rs`（BUN_NODE_DIR 三件套），机制、现象、
验收（as-node 转绿）完全对齐。

### 3.2 逐项对照

证据类型：〔源码〕两树 diff 逐字核验；〔实测〕设备 binary 行为。

| 维度 | social4hyq（@ 03188eac62） | 我们（62960fd817）→ 本 PR 修后 |
|---|---|---|
| `BUN_NODE_DIR` tmp 常量 | 〔源码〕ohos → `/data/storage/el2/base/tmp` | `/tmp` ❌ → 本 PR 同款分支 |
| mkdir 后 mode 处理 | 〔源码〕OHOS 下 chmod 回 0700 | 无 → 本 PR 补齐 |
| EEXIST 复用检查 | 〔源码〕`& 0o022 == 0 \|\| cfg!(target_env = "ohos")` | 仅 `& 0o022 == 0` ❌ → 本 PR 同款 |
| `bun --bun node file` | 〔实测〕通过（as-node 11/11） | `Script not found "node"` ❌ → 修后预期转绿 |
| `which/lib.rs` POSIX 路径 | 〔源码〕与两树一致（其 190 行 diff 全是 windows cfg） | 一致，**无需改动** |

### 3.3 为什么会归因错

F3 的 34 文件源码级分析（`confirm-jxbit-ab332f163-rebuild2-20260910.md`）定位到
"PATH bin 查找失败"后，按文件名直觉查 `which` crate——两树该文件确有 190 行 diff
（数量显眼），但未逐 hunk 核对 cfg 属性。教训：**跨树 port 必须先核 hunk 的
cfg 归属**（同 pr30 教训：修复是否在"编译进 OHOS binary 的路径"上）。

### 3.4 本 PR 未包含的部分

- 参考树 `bin.rs` 的 `lchmod` 用法**不搬**：我方 `fchmodat(flags=0)` 才是 OHOS 适配
  （lchmod 在 OHOS ENOSYS，注释在 bin.rs L1325 一带），方向与 F3 相反。
- `lib.rs` 尾部我方的 `copy_file_fallback`（SELinux 下 linkat/symlinkat 被禁时的
  copy 兜底）为我方独有 OHOS 适配，保留不动。

## 4. 修复内容（src/install/lib.rs，+18/-4，3 hunk）

1. `BUN_NODE_DIR`：ohos → `/data/storage/el2/base/tmp`
2. mkdir Ok 分支：`#[cfg(target_env = "ohos")] chmod(DIR_Z, 0o700)`（tmpfs 强制
   setgid + group-write 的回写）
3. EEXIST 分支：`&& ((mode & 0o022) == 0 || cfg!(target_env = "ohos"))`

三处为一个整体：只改目录不改 mode 处理会出现首跑过、复跑挂的间歇失败。

## 5. 验证

- 本地无 OHOS 工具链（host clang 缺失 + pinned nightly 工具链 manifest 损坏无法
  下载），编译由 CI 承担；3 hunk 与参考树逐字一致（git diff 对拍，仅注释差异）
- 非 OHOS 平台：全部分支 `cfg` 死代码化，桌面行为零变化
- 设备验收随下一轮 fulltest：as-node 11 用例转绿；`bun --bun node <file>` 正常；
  `bun run` 子进程 `$PATH` 首段出现 `<BUN_NODE_DIR>`

## 6. 关联

- 指南：`../knowledge/jxbit-fix-guide-20260910.md` §4（归因修正已回写）
- 同轮前序：[pr30](pr30-p1-process-platform-cpp-getter-and-bundled-inlining.md)（platform 层）、[pr29](pr29-p1-process-platform-openharmony.md)
- F1/F2 未立档：F1（ProcessHandle 重构）需设备验证管道，F2（serve 目录路由）是
  上游 1.4.0 版本合入而非源码补丁，指南 F2 的 `src/bun.js/http.zig` 路径两树均不存在
- 验收清单：`../analys/next-fulltest-acceptance-checklist.md`（as-node 项）
