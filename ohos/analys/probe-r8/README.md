# probe-r8/ — install 全族 ConnectionRefused 诊断套件

> 建立：2026-09-21。R8 主因（install 族 ~364 失败用例 = 全量 931 的 39%）。
> 统一假设：**verdaccio 宿主（harness `fork(execPath: bunExe())` —— 宿主就是被测
> binary）在累计负载下退化/死亡** → install 客户端 ECONNREFUSED。
> 佐证：全族同签名（bun-audit 774× / bun-update 212× / frozen 203× /
> isolated-install 70× / bun-lock 39×）；隔离复跑绿（短负载不触发）、全量挂
> （长负载触发）、参考 binary 宿主稳。

## 探针与判定树

| 探针 | 命令 | 结果 → 结论 → 修复方向 |
|---|---|---|
| **r8a 生命体征**（决定性） | `bash r8a-registry-vitals.sh test/cli/install/isolated-install.test.ts r8a` | fd 数逼近 rlimit（256）→ **fd 耗尽** → 宿主连接管理/rlimit 适配；`NO-VERDACCIO` + dmesg OOM → **进程被杀** → 内存/oom_score 适配；体征平稳但测试挂 → 回到客户端/内核方向 |
| **r8b 负载塑形** | `bash r8b-lightload.sh test/cli/install/isolated-install.test.ts` | 低并发显著转绿 → 连接并发压垮宿主 → install 并发上限适配 |
| **r8c 隔离确定性** | `bash r8c-isolation.sh "test/cli/install/isolated-install.test.ts test/cli/install/bun-lock.test.ts"` | 3 轮全绿 → 累计负载依赖（与 r8a 长跑样本互证）；稳定同量挂 → binary 内在，直接复现 |
| **r8d 双 binary 对照** | 分别在 PATH 放我方 binary 与参考 binary 后跑 r8a | 参考宿主体征平稳 + 我方退化 → 宿主差异坐实（定位到 runtime 层） |

## 执行顺序（一次设备会话）

1. r8c（1 分钟，定性确定性）→ 2. r8a（决定性体征）→ 3. r8b（机制分流）→
4. r8d（参考对照）。全部输出留存本目录 `<前缀>-*.log/tsv`。

## 环境要求

- 设备 root（`hdc root`）；binary 在 PATH（`bun` 指向被测构建；r8d 时切换）；
- 语义 env 已内置于脚本（FEATURE_FLAG / GC_LEVEL / GITHUB_ACTIONS），
  与 launch-fulltest.sh 同口径；`HOME` 需已设为 `$DEVROOT/home`（ verdaccio
  缓存/htpasswd 位置一致）。

## 已知背景

- npm.rs attempt-#3（#50）与 runner 默认超时（#51）已合并——探针结论若指向
  缓存/超时残留面，先确认这两项在跑的 binary 里。
- 修复落地后：全量 install 族（~364 用例）预期大幅回收；复跑口径按
  `fulltest-data/` 台账再生 + lists-log 对账。
