# jx-bit OHOS 构建修复指南

> 交付对象：jx-bit 构建设备/维护者。基于 2026-09-10 官方 v1.4.0 测试源码
> （oven-sh/bun `bun-v1.4.0` tag，2001 文件）双轮对比 + 247 失败文件复跑取证。
> 参考实现全部来自 social4hyq/ohos-bun `ohos-aarch64` 分支（HEAD `36854e8e`）。

## 0. 现状摘要

| 项 | 值 |
|---|---|
| 当前构建 | `1.4.0-canary.1+ab332f163`（process.platform 修复已生效 ✅） |
| 官方 v1.4.0 套件结果 | 1754/2001 通过，247 失败；**修复后复跑确认 69 个已随 platform 修复回退** |
| 剩余独有失败（vs social4hyq 1.4.0_80） | **34 文件 / ~340 用例**，归为 3 个根因簇 + 散布 |
| 参考实现 | social4hyq 1.4.0_80（`61dbc3a9d`）与 1.4.2_2（`36854e8e`）同树全量 99.08%/99.40% |

三个根因簇（按预计收益排序）：

| # | 根因 | 影响 | 修复源 |
|---|---|---|---|
| F1 | mini event loop 下子进程 pipe 输出无人读取 | ~9 文件 ~250 用例（multi-run/filter-workspace/test-changed/shell exec 等） | port `ProcessHandle` 重构 + `sys_uv.rs` OHOS 补丁 |
| F2 | `Bun.serve()` 目录路由特性缺失（404/空 body） | 1 文件 24 用例 | merge 上游 1.4.0 的 serve 实现 |
| F3 | `bun run` PATH bin 查找失败（`Script not found "node"`） | 1 文件 11 用例（跨三轮稳定） | port `which/lib.rs` PATH 搜索重构 |

## 1. 环境准备

```bash
# 1) 参考源码树（social4hyq 主线，包含全部正确实现）
git clone --depth 1 -b ohos-aarch64 https://github.com/social4hyq/ohos-bun.git ~/ref-ohos-bun

# 2) 被修复的 jx-bit 树（当前分支 HEAD 应 >= ab332f163）
git clone --depth 50 -b ohos-aarch64 https://github.com/jx-bit/bun.git ~/jx-ohos-bun
cd ~/jx-ohos-bun && git log --oneline -3   # 确认 HEAD

# 3) 生成两树差异（用于逐文件 port）
diff -ru --exclude=.git ~/jx-ohos-bun/src ~/ref-ohos-bun/src > /tmp/jx-vs-ref.diff || true
```

## 2. F1：输出捕获丢失（最大收益，先做）

### 2.1 现象（设备可复现）

```bash
cd /tmp && mkdir mrt && cd mrt
printf '{ "scripts": { "a": "echo AAA", "b": "echo BBB" } }' > package.json
bun run a                  # ✅ 正常输出 AAA
bun run --parallel a b     # ❌ 只有 "a | Done in" 行，AAA/BBB 丢失
bun run --sequential a b   # ❌ 同样丢失
bun -e 'await Bun.$`echo AAA`'  # ❌ shell 命令输出为空
```
机制：子进程 stdout/stderr 进了 pipe，但 pipe reader 在 mini event loop 上没有生效
（数据无人读取）；"Done in" 由 exit 回调打印所以可见。

### 2.2 需要搬运的文件（参考树 → jx-bit 树）

> **归因修正（2026-09-11 复核，以 A 轮 61dbc3a9d 同基线锚定）**：真实修复面在
> **`src/io/`**（posix_event_loop 的 epoll CTL_DEL dup 孤立 bug + rearm 看门狗 +
> PipeReader/PipeWriter/pipes）+ process.rs 的 sync wait 真实化 + SpawnSyncEventLoop
> 超时钳制，共 9 文件 ~600 行，已随 PR #32 交付（见
> `../issues/pr32-p0-epoll-pipe-capture.md`）。
> - `multi_run.rs` 两树（vs 61dbc3a9d）零差异——36854e8e 的 114 行是 1.4.2 漂移，勿搬
> - `process.rs` 的 RefPtr 重构（49ff888ffe3/82123d3a61a）不在 61dbc3a9d 内，A 轮无它
>   也通过 → 对 F1 非必需，勿整树搬运
> - `src/sys/` 16 文件嫌疑解除：sys/ 无涉，嫌疑面在 src/io/

| 文件 | 差异规模 | 内容 |
|---|---|---|
| `src/io/posix_event_loop.rs` 等 io/ 6 文件 | ~380 行 | F1 核心（epoll CTL_DEL dup bug + rearm watchdog + UAF 修复） |
| `src/spawn/process.rs` | ~84 行 | sync spawn no_orphans 真实化（poll+wait4+pidfd 父死监视） |
| `src/event_loop/SpawnSyncEventLoop.rs` | ~15 行 | epoll_wait 超时下溢钳制 |

### 2.3 操作

```bash
# 逐文件从参考树覆盖（先 diff 确认无 OHOS 无关冲突）
for f in src/spawn/process.rs src/runtime/cli/multi_run.rs \
         src/event_loop/SpawnSyncEventLoop.rs; do
  cp ~/ref-ohos-bun/$f ~/jx-ohos-bun/$f
done
# src/sys/ 不建议整目录覆盖（含 Windows/平台代码），逐文件 diff 后选择性 port：
diff -u ~/jx-ohos-bun/src/sys/sys_uv.rs ~/ref-ohos-bun/src/sys/sys_uv.rs
```

随后正常构建并过 §5 验证。

## 3. F2：Bun.serve() 目录路由

现象：`Bun.serve({ routes: { "/api/*": "./public" } })` 目录条目 404/空 body
（官方 v1.4.0 特性测试 `test/js/bun/http/serve-directory-routes.test.ts` 24 用例全挂）。

> **归因修正（2026-09-11 复核）**：我方树 = 官方 v1.4.0 基，`src/runtime/server/`、
> `src/http/` 与通过全部 serve 测试的参考 1.4.0_80 构建（61dbc3a9d）**逐字节一致**——
> "merge 上游 1.4.0" 的建议基于错误前提（无需 merge，代码已在）。"空 body" 的真实
> 嫌疑 = `src/io/` epoll 缺陷（响应体经 socket 投递失败，同 F1 家族），已随 PR #32
> 交付；"404" 部分待设备复跑后按剩余失败重判（若仍在，需 junit 断言日志定位）。

```bash
# 参考实现位置（social4hyq 已随上游 1.4.0 tag 合入）
diff -u ~/jx-ohos-bun/src/bun.js/http.zig ~/ref-ohos-bun/src/bun.js/http.zig
diff -ru ~/jx-ohos-bun/src/http ~/ref-ohos-bun/src/http
# ↑ 以上两行保留为历史记录：bun.js/http.zig 两树均不存在（老版布局残留）；
#   src/http/ 两树（vs 61dbc3a9d）diff 为空，勿改。
# 最直接: merge 上游 tag（推荐，一次带上 1.4.0 全部官方实现）
cd ~/jx-ohos-bun && git fetch --depth 1 origin refs/tags/bun-v1.4.0:refs/tags/bun-v1.4.0
git merge bun-v1.4.0   # 冲突重点: src/jsc/bindings/、src/runtime/、package.json version
```

## 4. F3：PATH bin 查找（Script not found "node"）

现象：PATH 注入 fake `node` 后 `bun run node` 报 `Script not found "node"`。
影响 `bun run <bin>`（as-node 类测试、用户脚本调用 PATH 工具）。

> **归因修正（2026-09-10 复核）**：`which/lib.rs` 两树间的 190 行 diff **全部是
> `#[cfg(windows)]` 代码**（win 扩展名探测/`which_win` 重构），POSIX `which()`
> 两树零差异，对 OHOS 无效——**不要 port 这个文件**。真实根因与修复：
> `src/install/lib.rs` 的 `BUN_NODE_DIR` 硬编码 `/tmp`（OHOS 沙箱不可写），
> shim 静默创建失败 → `which("node")` 落空。已随 PR #31 交付
> （`/data/storage/el2/base/tmp` + setgid chmod + EEXIST 容忍，见
> `../issues/pr31-p1-bun-node-dir-app-tmp.md`）。

```bash
diff -u ~/jx-ohos-bun/src/which/lib.rs ~/ref-ohos-bun/src/which/lib.rs
# ↑ 仅 Windows cfg 差异，勿 port（历史记录保留）
# 同步检查调用方:
grep -rn "which::" ~/jx-ohos-bun/src/runtime/cli/ | head
```

## 5. 验证

### 5.1 快速冒烟（构建后立刻做，2 分钟）

```bash
B=<新构建的二进制路径>
# F1
cd /tmp/mrt && $B run --parallel a b        # 期望: a | AAA / b | BBB / Done 行
$B run --sequential a b                     # 同上
$B -e 'await Bun.$`echo AAA`'               # 期望输出 AAA
# F2
$B -e 'Bun.serve({routes:{"/x/*":"./"}}); console.log("up")'  # 用测试文件验证目录路由
# F3
mkdir -p /tmp/fakebin && printf '#!/bin/sh\necho FAKE-NODE\n' > /tmp/fakebin/node && chmod +x /tmp/fakebin/node
PATH=/tmp/fakebin:$PATH $B run node         # 期望: FAKE-NODE
# platform（回归确认，勿退步）
$B -e 'console.log(process.platform)'       # 期望: openharmony
```

### 5.2 失败集复跑（247 文件清单法）

测试树：`git clone --depth 1 -b bun-v1.4.0 https://github.com/oven-sh/bun.git`，
在树根 `bun install` + `cd test && bun install --ignore-scripts`。
（esbuild@0.18.6/0.25.1 在 OHOS 上无平台包：把 aarch64 gnu 二进制放到
`test/node_modules/.bun/esbuild@<v>/node_modules/esbuild/bin/esbuild` 并 OHOS 签名。）

复跑脚本（对 247 失败清单逐文件单跑，2 并发）：

```bash
#!/bin/bash
# rerun.sh <失败清单> <日志输出目录> <binary> <测试树根>
set -u
LIST="$1"; OUT="$2"; BUN="$3"; TREE="$4"
mkdir -p "$OUT"; cd "$TREE" || exit 1
export BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1 BUN_GARBAGE_COLLECTOR_LEVEL=0 \
  GITHUB_ACTIONS=false CI=1 BUN_DEBUG_QUIET_LOGS=1 NO_COLOR=1 HOME="$TREE/home"
mkdir -p "$TREE/home"
run_one() {
  f="$1"; rel="${f#test/}"; log="$OUT/${rel//\//__}.log"; wt=180
  case "$f" in */bundler/*) wt=900 ;; *bake/dev/*) wt=60 ;; esac
  setsid "$BUN" test --timeout 300000 "./$f" > "$log" 2>&1 &
  pid=$!; ( sleep "$wt"; kill -TERM -- -"$pid" 2>/dev/null; sleep 3; kill -KILL -- -"$pid" 2>/dev/null ) & wd=$!
  wait "$pid" 2>/dev/null; ec=$?
  pkill -P "$wd" 2>/dev/null; kill -KILL "$wd" 2>/dev/null; wait "$wd" 2>/dev/null
  echo "$f exit=$ec" >> "$OUT/status.txt"
}
while IFS= read -r f; do run_one "$f" &
  while [ "$(jobs -rp | wc -l)" -ge 2 ]; do sleep 1; done
done < "$LIST"; wait; echo DONE
```

失败清单与验收基线（本机已产出，随文档附带走）：
`fail_official-v140-jxbit.txt`（247）、`fail_jxbit_only_after-fix.txt`（34）、
`fail_sys-release_only_after-fix.txt`（41）。

**验收标准**：
- F1 修复 → multi-run/filter-workspace/test-changed/shell exec 等 9 文件 PASS（~250 用例回补）
- F2 修复 → serve-directory-routes 24 用例 PASS
- F3 修复 → as-node 11 用例 PASS
- 不退步：`process.platform` 保持 `openharmony`；原已 PASS 的文件不因 port 引入新失败
  （建议 port 后跑一次全量：launcher 口径 PARALLEL=2 RETRIES=1 TMOUT=180
  `BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1 BUN_GARBAGE_COLLECTOR_LEVEL=0
  GITHUB_ACTIONS=false CI=1`，对 2001 文件出完整报告）

## 6. 全量测试的启动口径（与对照轮一致）

```bash
cd <测试树根>
BUN=<你的新binary绝对路径> BUN_PROC_PATTERN=<binary文件名> \
DEVROOT=$PWD TMOUT=180 RETRIES=1 \
setsid nohup bash <launcher>.sh > result.log 2>&1 &
```

## 7. 附：历史结论文档（本机）

- `confirm-jxbit-ab332f163-rebuild2-20260910.md`（含 34 失败源码级分析）
- `confirm-jxbit-rebuild-20260910.md`（platform 修复源码根因：`BunProcess.cpp`
  `constructPlatform()` 缺 `#elif defined(__OHOS__)` 分支——已修复，勿回退）
- `compare-20260910-official-v140-sys-release-vs-jxbit-c4323a5d3.md`
- `harmonybrew-bun-version-management.md`
