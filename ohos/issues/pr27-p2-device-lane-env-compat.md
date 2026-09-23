# P2: 设备通道环境兼容（AF_UNIX tmpdir 探测 + wasi `/` preopen 探测）— 工作记录

> **关联 PR**：[#27](https://github.com/jx-bit/bun/pull/27)（claude 分支 → ohos-aarch64，单 commit `fed363c7b5`）
> **状态**：🔄 OPEN
> **定位**：20260903 open 桶（24 文件，两轮都挂）审计后可代码修复的部分 —— unix socket
> EPERM 簇（18 子用例）+ wasi 直接执行（1 文件）。

## 1. 问题一句话

设备默认 tmpdir 解析到用户存储卷（`/storage/Users/currentUser/...`，hmdfs）：
普通文件 I/O 正常但 **AF_UNIX bind() EPERM**，18 个 unix socket 子用例全军覆没；
同时 `bun xxx.wasm` 因沙箱拒绝 `open("/")` 在 WASI 构造阶段就抛错。

## 2. 根因

### 2.1 unix socket EPERM 簇（listen-connect-args ×5、serve-args ×9、serve.test ×4）

失败证据（20260903 详报）：`EPERM: operation not permitted, listen
'/storage/Users/currentUser/uds-tls-identity-*/s.sock'`。测试侧的 isOHOS
tempdir 处理（cwdScope 到 tmpdir）**已在且双方逐字一致**，仍挂 —— 是环境而非
测试代码：hmdfs 不支持 AF_UNIX。runner 传的 TMPDIR 也源自 runner 自己的
`tmpdir()`，同样落在 hmdfs。

**分层归因（2026-09-09 修正，含 20260908 轮证据）**：该簇在 20260908 轮属
**overlap（他们的 binary 也挂，`lists/fail_overlap_both.txt` 实证）**——失败
与 binary 无关，是设备 tmpdir 卷（`os.tmpdir()` → hmdfs）的 AF_UNIX 能力问题，
两个维度叠加：

1. **门控维度**：我们的 binary 曾把 `process.platform` 报成 "linux"（PR #29），
   isOHOS 适配根本不触发；他们的 binary 触发适配。
2. **tmpdir 能力维度（本 PR 的 target）**：即便适配触发，落点 `os.tmpdir()`
   在本设备仍是 hmdfs → 依旧 EPERM（他们的 binary 在本设备同样挂即为此证）。

因此本 PR 的探测是**对两个 binary 都必要的设备级修复**，与 PR #29 互补。

### 2.2 wasi.test.js（`bun hello-wasi.wasm`）

`src/js/wasi-runner.js` 无条件 preopen `/`；OHOS 沙箱 `open("/")` EACCES →
WASI 构造抛错 → exitCode 非 0。他们的线已修（`39b9cf057d`，2026-08-08）——
20260908 轮 wasi 为 **jxbit_only**（他们的 binary+树过、我们挂），实证该修复
必要且我们缺失。

## 3. 修复（2 文件，+65/-6）

1. **runner.node.mjs**：openharmony 时探测候选 scratch 根（`$TMPDIR` →
   `/data/local/tmp` → `os.tmpdir()` → `/tmp`），用真实 socket bind 探针取
   第一个 AF_UNIX 可用的；`TMPDIR`/`BUN_TMPDIR`/`TEST_TMPDIR`/`NODE_TEST_DIR`
   全部锚定到它。无候选可用则回退 `os.tmpdir()`（原行为）。每轮只探一次
   （promise 缓存）。
2. **src/js/wasi-runner.js**（移植参考通道 39b9cf057d 的 wasi 部分）：
   preopen `/` 前 `openSync("/")` 探测，仅真实拒绝（EACCES）时丢弃该 preopen
   （EISDIR 仍算可打开）；显式 `WASM_ROOT_DIR` 原样透传。

两处均 openharmony 门控（wasi 探测按平台行为自然分化：Linux 上 `/` 可打开，
preopen 保留，行为不变）。

### 3.1 与 social4hyq 实现的对比（runner tmpdir：超集关系）

| 维度 | social4hyq（其 runner.node.mjs，真机验证） | 我们（PR #27） |
|---|---|---|
| `NODE_TEST_DIR` | `mkdtempSync(join(tmpdir(), "nt-"))`，openharmony 门控，短前缀为 sun_path 108 上限 | **逐字一致**（#26 已移植） |
| `TMPDIR`/`BUN_TMPDIR`/`TEST_TMPDIR` | `mkdtempSync(join(tmpdir(), "buntmp-"))` —— **直接信任 `os.tmpdir()`** | 同源同值，**但先探测**：候选 `$TMPDIR` → `/data/local/tmp` → `os.tmpdir()` → `/tmp`，真实 socket bind 取第一个 AF_UNIX 可用的根 |
| 设备假设 | 其设备的 `os.tmpdir()` 落在 AF_UNIX 可用位置 → 无需探测 | 我们设备（zjx）的 `os.tmpdir()` 落在 hmdfs → 不探测必挂（20260902/03/08 三轮 unix 簇全挂的机制） |
| 探针成本 | — | 每轮一次（promise 缓存）；候选全败则回退 `os.tmpdir()`（= 他们的行为） |

**关系定性：我们的探测是他们方案的严格超集**——tmpdir 可用的设备上探测结果与
他们的行为一致；不可用的设备上（我们的实际情况）自动降级到可用根。没有探测
就无法区分"tmpdir 可用/不可用"，这正是 unix 簇在同一设备上跨三轮、跨两个
binary 反复挂的原因。

### 3.2 与 social4hyq 实现的对比（wasi：逐字移植）

| 维度 | social4hyq | 我们（PR #27） |
|---|---|---|
| 实现 | `src/js/wasi-runner.js`：preopen `/` 前 `openSync("/")` 探测，EACCES 丢弃该 preopen（EISDIR 仍算可打开）；显式 `WASM_ROOT_DIR` 原样透传 | **diff 为空（逐字一致，实测验证）** |
| 引入 | commit `39b9cf057d`（2026-08-08，"fix(ohos): wasi-runner skips unopenable '/' preopen; sync compat-shim getaddrinf…"） | 2026-09-09 移植（#27） |
| 真机验证 | 其轮 wasi.test.js 5/5 pass | 待下轮（20260908 轮我们的 binary 无此修复 → wasi jxbit_only 失败，实证必要） |
| 同 commit 的另一部分 | `ohos_compat_shim.c` getaddrinfo 拦截器（+102 行，DNS/udp 修复） | **未移植**——属 DNS/网络主题，待评估（pr21 §9.4 对齐表口径） |

## 4. 验证

- `node --check` 通过；prettier 干净；`bun build` 可解析修改后的内建模块
- Linux runner 冒烟（`--include=bun/empty-file`）：3/3 通过 —— probe 平台门控，
  Linux 路径不变
- preopen 逻辑在 Linux 实测：`/` preopen 保留；EACCES 丢弃路径为参考通道
  真机验证过的原版实现，逐字移植
- 真机复验：下一轮 fulltest 观察 18 个 unix socket 子用例 + wasi

## 5. open 桶（24 文件）完整审计结论（2026-09-08）

| 类 | 文件 | 处置 |
|---|---|---|
| 本 PR 修复 | listen-connect-args、serve-args、serve.test（unix 部分）、socket.test（TLS unix/kqueue）、wasi.test.js | 本 PR（tmpdir 根 + preopen 探测） |
| 当前测试树已修（9/2 reconcile 带入，9/3 构建跑了旧树） | fs-birthtime ×4 子用例、bun-build-compile ×2、24742 ×1、bundler_edgecase ×1、server.spec ×2、serve.test v6 ×1 | 无需动作，下轮自动恢复 |
| 需更长超时判定（疑似真挂起） | bundler_compile、serve-body-leak、spawn-pipe-leak | 专门排查（§7） |
| 第三方产物/网络域 | bunx、next-auth、esbuild（需 ohos-ports 包）、grpc-js resolver、bun-add（摇摆） | infra/包渠道，非代码 |
| IPC 真 bug | serve-types fixture（cluster/test-docs-http-server） | 已深挖，留专门 session（pr24 文档口径） |

## 6. 关联

- 前置交付：[pr26-p2-runner-env-device-lane.md](pr26-p2-runner-env-device-lane.md)（#26 已合并 46a905a6cf）
- 交付先例：[pr24-p2-gethomedir-import-alias.md](pr24-p2-gethomedir-import-alias.md)
- 交叉 triage 全量：`20260903_fulltest_aarch64-github/`（数据集已清理，cross-triage-social4hyq-20260907 结论已并入本档）
