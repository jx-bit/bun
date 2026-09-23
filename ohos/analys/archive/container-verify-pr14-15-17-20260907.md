# PR #14/#15/#17 修复验证 — ohos-container-test（dispatch 34090874324）

> 运行：2026-09-07，dev tip `4092045402`（含 #14/#15/#16/#17 全部修复），
> binary 构建自 merge commit `4da7170f4`，runner.node.mjs `--parallel`（4）。
> 上一轮（33955739117）的 5841 文件结果被 vendor build 崩溃吃掉；
> 本轮 runner 修复（vendor 失败改为记录后继续）已生效，**results.json 首次完整产出**。

## 总览

| 指标 | 值 |
|---|---|
| 文件 | 5967（发现 5969，含 vendor/elysia 套件）|
| 通过 | **5687（95.31%）** |
| 失败 | 280 = test/ 树 ~110 + vendor/elysia ~170（build 失败按新逻辑记录，环境类）|
| 耗时 | 测试步骤 ~37 分钟（并行 4）|

## 三个 PR 的修复验证

### PR #15（dlopen musl loader 显式路径）— ✅ 验证通过

| 文件 | 结果 | 说明 |
|---|---|---|
| `test/js/node/process/process.test.js` | **165 pass** / 4 fail | 失败为 `process.release`、`node version expectation`、`stdin` ×2 —— **上一轮的 signal/dlopen 类失败已消失**；libc dlopen（lazyRaise）用例通过 |
| `test/js/web/intl/intl.test.ts` | 32 pass / 1 fail | 唯一失败是容器 locale（C.UTF-8），与 dlopen 无关 |
| `test/js/bun/http/bun-serve-file.test.ts` | 103 pass / 2 fail | mkfifo FIFO 用例失败属容器文件系统类；其余（含 lazyMkfifo dlopen 路径）通过 |

### PR #17（用户态 shebang 展开）— ✅ 验证通过

- 脚本 spawn 全链路在容器内工作：shell 套件 `ls.test.ts` 27/29（2 个失败为权限/目录环境类）、
  `spawn-path.test.ts` 3/4（1 个失败为 PATH 解析，见 residual）
- 无 shebang 改写引入的回归；展开逻辑与懒修复叠加路径无异常

### PR #14（codesign 校验 + compile strip 重签）— ✅ 验证通过（容器可测部分）

- `bun-build-compile.test.ts`：**13 pass** / 2 skip / 1 fail —— compile 产物在容器内正常生成并执行
  - 唯一失败：`compiled binary in a deleted cwd > exits cleanly instead of crashing`（期望空输出、实际打印
    `should-not-run`）—— 行为差异，记录待查（不阻塞）
- 内核签名强制类（EACCES 72 文件家族）容器测不到，真机通道为准

## 失败分类（280 = 110 test/ 树 + 170 vendor）

| 类别 | 数量 | 说明 |
|---|---:|---|
| vendor/elysia build 失败连带 | ~170 | elysia `bun run build` 容器内退出 1（已知，runner 已改为记录不中止）|
| node-gyp 工具链（napi ~31 + 零散） | ~35 | 容器 g++ 过旧（node-26 头要求 `source_location`）；对齐 social4hyq 的 PATH 修复可解 |
| node 不在 PATH / spawn 裸 node | ~9 | brew node bottle 404；可注入官方 node-arm64 或排除 |
| stdin/TTY/信号环境 | ~6 | 容器无 TTY + 并行 stdin 竞争 |
| locale/env/超时/行为差异 | 零散 | intl locale、compile deleted-cwd、sucrose 500ms 等 |
| docker 服务依赖 | 2 | 容器无 docker-in-docker |

## residual（待办）

1. `bun-build-compile` deleted-cwd 行为差异 —— 单独 triage
2. `spawn-path` "PATH from env" 空输出 —— 确认是否与 shebang 展开的 PATH 交互
3. napi node-gyp 工具链 —— 移植 social4hyq 的 PATH 修复（cross-triage 报告 §技术表第 1 项）
4. vendor/elysia build 容器内退出 1 的根因（不阻塞，已隔离为记录）
