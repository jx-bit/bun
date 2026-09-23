# 慢性超时固定集台账（chronic-timeout registry）

> 建立：2026-09-21（依据 G 轮 3ac1bc4d8 / H 轮 615b48e95 两轮全量对比）。
> 用途：设备长跑 + 180s 墙钟 ×2 次尝试下的**固定重灾清单**。验收时按本册
> 扣减，不逐轮计回归；离开本册（转绿）才算修复，新增成员才算回归候选。

## 1. 成员（H 轮 ⏰ 12 文件，G↔H 11/12 相同）

| 文件 | H 轮 | G 轮 | A 基线 | 定性 |
|---|---|---|---|---|
| `test/cli/install/bun-security-scanner-matrix-with-node-modules.test.ts` | ⏰360.3s | ⏰ | ❌56/11 | 长跑 + verdaccio 压力 |
| `test/cli/install/bun-security-scanner-matrix-without-node-modules.test.ts` | ⏰360.3s | ⏰ | ❌44/21 | 长跑 + verdaccio 压力 |
| `test/cli/install/bun-install-registry.test.ts` | ⏰360.4s | ✅ | ❌240/3 | G↔H 对调对（见 §3） |
| `test/regression/issue/26286.test.ts` | ⏰360.3s | ⏰ | ✅2/0 | 间歇性 hang，**probe-p8 待设备执行**（R2） |
| `test/js/bun/repl/repl.test.ts` | ⏰360.5s | ⏰ | ⏰360.4s | TTY/PTY 平台边界（与 A 同挂） |
| `test/js/bun/terminal/terminal-platform-gaps.test.ts` | ⏰360.4s | ⏰ | ❌16/3 | TTY/PTY 平台边界 |
| `test/js/bun/terminal/terminal-spawn.test.ts` | ⏰360.3s | ⏰ | ❌12/4 | TTY/PTY 平台边界 |
| `test/js/bun/terminal/terminal.test.ts` | ⏰360.3s | ⏰ | ❌89/7 | TTY/PTY 平台边界 |
| `test/js/node/net/handle-leak.test.ts` | ⏰360.3s | ⏰ | ⏰360.3s | 长跑 fd 压力（与 A 同挂） |
| `test/js/node/tty.test.ts` | ⏰360.2s | ⏰ | ❌6/1 | TTY/PTY 平台边界 |
| `test/integration/expo-app/expo.test.ts` | ⏰366.5s | ⏰ | ✅1/0 | install 长跑 exit=143，**PARKED**（R7） |
| `test/integration/next-pages/test/next-build.test.ts` | ⏰360.4s | ⏰ | ❌0/1 | 重型构建工具，设备性能边界 |

> A 轮对照列里 `⏰360.4s`（repl / handle-leak）= A 轮同文件也超时（平台共挂）；
> ❌ = A 轮是硬失败（慢设备把硬失败拖成超时）；✅ = A 轮通过（仅 26286、expo
> 两个，即 B-only-fail 里的慢性成员）。

## 2. 边界说明

- `test/bake/dev/{bundle,css,hot}.test.ts` 的 A 轮 ⏰120s 属旧墙钟代数据，
  B 轮为 ❌，**不在本册**（bake/dev 族另计，见 20260914 归因文档族 6）。
- 成员内与 A 共挂的部分是平台/环境边界（both-fail）；26286、expo 是唯二
  A 通过的成员 —— 26286 挂 probe-p8 判定树（R2），expo 已 PARKED（R7）。

## 3. G↔H 对调对

两轮超时集 12↔12，**11 个完全相同**；唯一进出对：
`bun-install-registry`（G ✅ → H ⏰）↔ `next-pages/test/dev-server.test.ts`
（G ⏰ → H ❌）。同父族（install/next 重活）内轮转，是设备长跑资源竞争的
特征，不按回归处理。

## 4. 验收规则

1. 全量报告的失败文件数包含 ⏰，但**用例数不计量**（⏰ 无 `-N`）。
2. 验收对比时先对齐本册：本册成员的 ⏰ 不计入"新增失败"；本册成员转绿
   （连续一轮 ✅）才允许出册；非本册文件新出现 ⏰ 视为回归候选，走
   `analys/` 归因 + 隔离复跑定性（3 轮口径见 `analys/20260921-remaining-issues.md` §4）。
3. 本册随轮滚动维护：每轮再生台账后核对成员进出，并在头部更新依据轮次。
