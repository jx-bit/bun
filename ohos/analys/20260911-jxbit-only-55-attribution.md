# 失败归因演进：101（c4323a5d3）→ 39（0e0fd1559）→ **32（14fdf0d56，当前）**

> **2026-09-20 状态**：本文数据截至 round D（14fdf0d56）。G/H 轮（3ac1bc4d8、
> 615b48e95）后独有失败已收敛至 15（log 口径），确定性待修 0——最新构成与
> 口径修正见 [`20260917-round-report.md`](20260917-round-report.md)。

> 数据源：官方 v1.4.0 树同测试树双 binary 真机三轮。
> - 轮 1：B=c4323a5d3（修复前）——`fulltest-data/archive/round-B-file-inventory-c4323a5d3.tar.gz`（已归档）
> - 轮 2：0e0fd1559（含 #30/#31/#32）——`fulltest-data/archive/round-C-0e0fd1559.tar.gz`（已归档）
> - 轮 3（**当时**）：14fdf0d56（含 wave2 #34）——`fulltest-data/archive/round-D-14fdf0d56.tar.gz`（已归档）
>
> **最新结论速览**：修复演进 101 → 39 → **32**。wave2（#34）收复 13 文件
> （structured-clone ×2、html-rewriter、console-iterator、test-changed、
> cli/install ×5、bun-inspector-protocol、update_interactive、spawn-stdin）——
> 证实"不 port webcore、io 层是共同症状面"的判断。**新增 6 个回归候选**
> （bun-publish、frozen-lockfile ×2、pnpm-lock-v9、node-dns、inspect）需排查
> 是否 wave2 引入。剩余 32：cli/install 10、js/bun 8（shell ×5 + serve-dir）、
> cli/run 7、regression 3。逐轮详见 [archive/20260914-round-report.md](archive/20260914-round-report.md)。

> 定位方法论（仍有效）：①同测试树双 binary 对比（消除树漂移）②上游
> `bun-v1.4.0..bun-v1.4.2` 版本窗口 commit 考古 ③两树逐文件源码 diff 对拍。
> **§1–§5 为静态源码级定位时期的分析（历史快照，部分结论已被后续设备轮修正，
> 以头部最新结论与 pr 文档为准）；§6 行动清单已按三轮实测更新。**

## 1. 全局结论（静态定位时期快照）

101 个 B-only 失败的走向：

| 去向 | 数量 | 依据 |
|---|---:|---|
| 随 platform 修复回退（PR #30，已合并） | ~46 | sql-docker-gate 30 + fs-birthtime 等 platform 门控文件 |
| F3：bun-node shim（PR #31，已合并） | 1 | as-node（11 用例） |
| F1：mini event loop pipe 输出捕获 | ~9-20 | 见 §3（比指南估的 9 文件范围更大，见 §3.2） |
| F2：serve 目录路由（上游 1.4.0 合入） | 1 | serve-directory-routes（26 用例） |
| 上游 1.4.0→1.4.2 窗口修复缺失（cherry-pick 候选） | ~6-10 | 见 §4 |
| 待设备 34 清单逐一确认 | 剩余 | 静态证据不足以定案的散布项 |

上游窗口体量（参考树领先我方的真实差距）：`src/jsc` 1175 文件次、`src/runtime`
1055、`src/bundler` 226、`src/install` 135、`src/js` 113、`src/http` 46。**散布失败
的默认假设应为"窗口内上游修复缺失"，逐文件用窗口 log 反查**，而不是逐个盲 diff。

## 2. platform 回退面（46，已闭环）

- `test/js/sql/*` 30 文件（sql-docker-gate：`isCI && isLinux` → throw）
- `js/node/fs/fs-birthtime-linux.test.ts`（`skipIf(process.platform === "openharmony")`，
  hmdfs birthtime=0 平台差异）+ 其余 platform 条件 fixture 文件

## 3. F1 簇（mini event loop 下子进程 pipe 输出无人读取）——范围比指南估的大

### 3.1 新证据

1. **`src/shell/` 两树 diff 为空**（`git diff` 零输出）：9 个 shell 测试文件失败
   （exec 13、mv 7、env.positionals 4、ls 2、seq-condexpr 3 等 ≈33 用例）不能归因
   于 shell 实现差异 → 只能是 spawn/pipe 链路。
2. **`console-iterator.test.ts`（8 用例）**：测试体 = `spawnSync(bun, run.ts)` 的
   stdout 逐字节断言 → 与 shell 同症状（子进程输出捕获）。
3. `cli/test/test-changed/test-shard`、`spawn/spawn-stdin-readable-stream-integration`
   等同为 spawn 输出/管道型。

### 3.2 修正后的 F1 文件面（静态归因，待设备确认）

- shell：`exec` `mv` `ls` `which` `env.positionals` `file-io` `shell-seq-condexpr`
  `yield`（`shell-cmdsub-crash` 为超时标记 −1，另判）
- cli/run：`multi-run` `filter-workspace` `run-shell` `run-quote` `shell-keepalive`
  `no-orphans` `run-crash-handler`（inventory 的 path-bin-resolution 簇内）
- cli/test：`test-changed` `test-shard`
- js/bun：`console-iterator` `spawn-stdin-readable-stream-integration` `spawn-signal`
  `spawn-pipe-read-error-leak`
- cli/install：`bun-run` `bun-run-bunfig`（bun run 输出链）

> 指南估 "~9 文件"偏保守；若上述全部随 F1 回退，收益 ≈ 20+ 文件 / 300+ 用例。
> **port 范围建议**：核心 3 文件（`spawn/process.rs` ProcessHandle 重构 +
> `multi_run.rs` + `SpawnSyncEventLoop.rs`，407 行）先行，`src/sys/` 11 文件
> （1368 行 diff，混 1.4.2 版本漂移）必须逐 hunk 核对 pipe/epoll 路径后再选择性
> port——与 pr31 教训一致（先核 cfg/版本归属，再动手）。

## 4. 上游窗口修复缺失（~~cherry-pick 候选~~ → 归因推翻，2026-09-11 二次复核）

**撤回原结论**：~~structured-clone 簇 = `e3bd3e44ed9` 缺失~~。决定性反证：**A 轮
（61dbc3a9d）的 `src/jsc/bindings/webcore/`、`src/runtime/server/`、`src/http/`
与我方逐字节一致**（`git diff` 三区域全部为空），但 A 通过了 structured-clone
（6 用例）与 serve 全系（含 directory-routes 26 用例）——异常检查/服务端代码均非
原因。`e3bd3e44ed9`（jsc-exception-lint，116 文件）不随 port 引入。

### 4.1 新统一假设：散布簇大半是 PR #32（src/io epoll 层）的症状面

两棵 1.4.0 基 OHOS 树的唯一实质差异 = `src/io/` 9 文件（PR #32 已移植）+ 若干
install/standalone 差异。排除法：A 通过、我方失败、且源码一致的区域（webcore/
server/http/shell）全部指向 **fd 事件投递层**——管道（PR #32 主目标）之外，
socket 响应体投递（serve "空 body"、ws、fetch-keepalive）、`Bun.spawn` stderr
读取（install-git-deps 的 `stderr: "pipe"` + Bun.serve dumb HTTP）同属
epoll CTL_DEL 孤立/静默停摆的暴露面。

| 簇 | 新归属 | 依据 |
|---|---|---|
| serve-directory-routes（26） | PR #32 症状面（待复跑确认） | server 代码两树一致；"空 body" = 响应体投递失败 |
| bun-install-git-deps（5） | 同上 | 测试体 = `stderr: "pipe"` 读 git/serve 输出 |
| structured-clone（6）、workers | 待设备日志 | webcore 一致；worker 走 MessagePort/fd，嫌疑同层但无直接证据 |
| install-proxy / bun-run / bun-run-bunfig | F1/F2 症状面 + 待确认 | spawn 管道 + serve |
| console-iterator（8）、shell 系 | F1 症状面（已 port） | spawnSync stdout 断言 |

**教训（第二条方法论）**：A 锚定法的完整形态 = 对每个候选簇，先跑
`git diff origin/ohos-aarch64 61dbc3a9d -- <该簇源区>`——**空 diff 即排除该区域**，
剩余唯一差异区（src/io）即嫌疑集中地。盲信"上游窗口反查"会在版本漂移里找错凶手
（窗口修复是"参考树比 A 新"的部分，不是"A 比我们多"的部分——后者才是失败归因）。

## 5. 其余散布（静态证据不足，逐项待查）

| 文件 | 用例 | 初步方向 |
|---|---|---|
| `cli/install/bun-install-git-deps`（5） | git 可用性/`git` 依赖安装在沙箱 PATH 的表现 | 设备日志 |
| `cli/install/bun-install-proxy`（1）、`bun-pm-licenses`（3）、`bun-pm-version`（1）、`bun-update-lockfile-sync`（2）、`isolated-relink`（1） | install/linker 面；`src/install` 窗口 135 文件次 | 窗口反查 |
| `js/bun/binary/tls-segment-size`（1）、`js/bun/ffi/addr32`（1） | 底层内存/BoringSSL 面，两树可能无源码差异（构建配置） | 构建配置对比（同 serve-body-leak H2 结论路径） |
| `js/bun/net/unix-socket-long-path`（4） | AF_UNIX 路径长度；PR #27 探测相关 | 设备日志 |
| `js/bun/http/serve-file-slice-read-error`（1）、`io/bun-write`（1）、`symbols`（1）、`transpiler-truncated-utf8`（1） | 散点 | 逐个窗口反查 |
| `js/node/fs/fs-oom`（4）、`dns`（1）、`process/stdin/process-stdin-stale-hup`（1） | 资源/事件循环面，可能与 F1 同源 | F1 port 后复跑 |
| `js/web/fetch/fetch-tcp-keepalive`（6） | `src/http` keepalive 面（两树 749/806 行 diff，混版本漂移） | 窗口反查：`git log bun-v1.4.0..bun-v1.4.2 --oneline -- src/http/` 逐条核对 |
| `js/web/intl`（1） | ICU 数据/构建配置面 | 构建配置对比 |
| `js/web/websocket/autobahn`（1）、`websocket-proxy`（1）、`first_party/ws`（1） | ws 面（`src/js/thirdparty/ws` 或 uWS） | 窗口反查 |
| `js/workerd/html-rewriter`（1） | lolhtml 面 | 窗口反查 |
| `integration/mysql2`、`integration/expo-app`（超时 −1） | 第三方集成/长跑 | 设备日志 |
| `cli/inspect/*`（4 文件，path-bin 簇内） | bin 解析相邻，PR #31 后复跑 | 复跑确认 |

## 6. 行动清单（按收益排序）

1. **F1 port**（§3.2 清单）：✅ **已交付 PR #32**（2026-09-11）——以 A 轮 61dbc3a9d
   同基线锚定后，真实修复面修正为 `src/io/` 6 文件（epoll CTL_DEL dup 孤立 bug +
   rearm watchdog）+ process.rs sync wait + SpawnSyncEventLoop 超时钳制（9 文件
   +435/−50，与 A 逐字节一致）；RefPtr 大迁移对 F1 非必需（A 无它也通过）。
   详见 [../issues/pr32-p0-epoll-pipe-capture.md](../issues/pr32-p0-epoll-pipe-capture.md)
2. **cherry-pick `e3bd3e44ed9`**（structured-clone 6 用例 + 消灭整类缺
   exception-check 隐患；可顺带跑上游 jsc-exception-lint 扫出同类缺口）
3. **PR #31 合并后复跑**：cli/inspect 4 文件 + regression 26207 + guide 冒烟 §5.1
4. **向设备侧要 34 清单**（`fail_jxbit_only_after-fix.txt`）+ 逐文件 junit 日志
   （per-case round C 机制已就绪），替换本 doc 的静态推断
5. 散布项按 §5 的"窗口反查"逐个定位（每项一条 `git log bun-v1.4.0..bun-v1.4.2 -- <源区>`）

## 7. 方法教训（并入工作流）

- 跨树 port 前必须核两件事：hunk 的 `cfg` 归属（pr31：which/lib.rs 190 行全
  windows）+ 是否上游窗口版本漂移（本 doc：regression 10 项 fix 均已在两树）
- `git log bun-v1.4.0..bun-v1.4.2 -- <area>` 是散布失败定位的第一性工具，
  比逐文件盲 diff 便宜一个量级
