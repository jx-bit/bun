# 2026-09-17 轮次报告：615b48e95（第九个构建）× 官方 v1.4.0 套件

> A = social4hyq 1.4.0_80 参考基线（61dbc3a9d 树）；B = 我方交付线。
> 构建 `1.4.0-canary.1+615b48e95`（#48 merge commit，2026-09-17 16:29 +0800），
> 当晚 18:39:05 启动全量，TMOUT=180 RETRIES=1，2001 文件。
> 数据：`../fulltest-data/615b48e95/`（log + 全量逐行报告 + lists/）。
> **本报告口径：runner log 逐文件行（2001 行）为地面真相**；设备侧确认文档
> （`confirm-jxbit-615b48e95-fullrun-20260917.md`）的 lists/ 提取有系统性缺陷，见 §2。

## 1. 演进总览（八轮横向，同树同口径）

| 轮 | binary | Duration | 文件通过 | fail 用例 | 用例率 | 独有失败 |
|---|---|---|---|---|---|---|
| A | sys-release 1.4.0_80 | 02:00:58 | 1816 | 637 | 99.08% | — |
| B | jx-bit c4323a5d3 | 02:31:39 | 1754 | 943 | 98.63% | 101 |
| C | jx-bit 0e0fd1559 | 02:02:33 | 1812 | 1181 | 98.29% | 39 |
| D | jx-bit 14fdf0d56 | 01:52:46 | 1808 | 1278 | 98.15% | 32 |
| F | jx-bit 007d7a07e | 01:58:46 | 1808 | 1220 | 98.23% | 29 |
| G | jx-bit 3ac1bc4d8 | 01:47:09 | 1830 | 1052 | 98.49% | 15 |
| **H** | **jx-bit 615b48e95** | **01:44:20** | **1819** | **931** | **98.65%** | **15** |

- Duration 以 log 汇总块为准（01:44:20，九轮最快）；设备确认文档写 01:29:53 系误抄。
- 文件通过 1819 较 G 轮 1830 回落 11——全部为轮转（见 §5），非修复回退。
- fail 用例 1052→931（−121），用例率 98.65% 历史新高，与 A 轮差 0.43pp。

## 2. 数据口径修正（本轮新发现，后续轮次沿用 log 口径）

对 H 轮 lists/ 三张清单逐文件对账（对照 log 2001 行 + 报告 2001 个 EXIT_CODE）：

| 清单 | 声称 | log 实况 | 缺陷 |
|---|---|---|---|
| `fail_615b48e95.txt` | 177 | 实际失败 **182**（170 ❌ + 12 ⏰） | 漏 8（7 个超时文件 + node-http-connect.test.ts；超时文件无内联输出段 → 系统性漏报），多 3 假失败 |
| `fail_615b48e95_only.txt` | 10 | 实际独有 **15** | 3 个假失败全被挤进 only（plugins/sqlite 本轮 42/122 用例全绿；node-http-connect.node.mts 两轮不在测试树） |
| `fail_overlap_both.txt` | 167 | **零虚警**（167 个全部属实） | — |

假失败成因：通过文件的嵌套 spawn 输出中含 `EXIT_CODE:1` 行，段落头提取误配。
G 轮清单同构（166 vs 实际 171）。**验收口径改用 log 逐文件行。**

总量对账（全吻合）：2001 = 1819 ✅ + 170 ❌ + 12 ⏰；931 fail 用例 = 170 个 ❌
文件的用例失败合计（⏰ 文件用例不计量，`-1` 占位）；Crashes 0。

## 3. 931 个失败用例的分担

| 归属 | 文件数 | fail 用例 | 占比 |
|---|---|---|---|
| overlap 167（A 轮也挂） | 163 非超时 | 638 | 68.5% |
| 我方独有 15 | 7 非超时 | 293 | 31.5% |
| ——其中 bun-audit + bun-update + frozen-lockfile-pruned | **3** | **290** | **31.1%** |
| ——其余 4 文件（bun-add-catalog/bun-write/child-process-exec/node-http-connect） | 4 | 3 | 0.3% |

模块分布（182 失败文件）：cli/install 27、js/bun 39、js/node 22、third_party 17、
bake/dev 16、regression 16、js/web 6、internal+lints 9、bundler 6、napi 4、散点 ~26。

## 4. 我方独有失败 15 的构成（真实口径）

> **口径注**：本节 15 = log 失败集 − 设备侧 overlap 清单（A 快照为设备侧 09-17
> 口径）。若按**固定 A 基线**（`fulltest-data/ohos-bun全量测试报告` 的 A 列，brew
> 1.4.0_80 的 2026-09-10 真机全量）计算，则 B-only-fail = **8**（4 verdaccio +
> 26286/expo 慢性超时 + PARKED + 待定性），另 7 个慢性文件（terminal×2/tty/repl/
> sec-scanner×2/node-http-connect）与 A 基线共挂 = both-fail。交付口径以
> 全量测试报告（固定 A）为准。

**8 个超时（~360s = 180s×2 次尝试耗尽）**：security-scanner ×2、expo（366.5s）、
repl、terminal ×2、tty、26286。
**7 个非超时**：

| 文件 | fail 用例 | 定性 |
|---|---|---|
| bun-audit | −106 | verdaccio 依赖；G `+106/-76` → H `+76/-106` **镜像翻转**，随机不稳定 |
| bun-update | −104 | G 全绿 `+156/-0`（193s）→ H `+52/-104`（**12s 即死**，registry 挂起）；依赖 verdaccio |
| frozen-lockfile-pruned | −80 | 连续两轮 ~80 挂但隔离复跑可绿 → 长跑压力依赖 |
| bun-add-catalog | −1 | 187.7s 内 Verdaccio 被 SIGKILL |
| bun-write | −1 | **PARKED**（`Bun.write` 切片，双方共识不修） |
| child-process-exec | −1 | maxBuffer throw 行为，**待隔离复跑定性**（本轮新增且独有） |
| node-http-connect.test.ts | 0（exit≠0） | AF_UNIX `EPERM listen /storage/...` → 族 3（hmdfs/沙箱），`TMPDIR=/data/local/tmp` 规避 |

三个新认知：

1. **超时集是慢性固定集，不是轮转**：G↔H 两轮 12 个超时 **11 个完全相同**
   （仅 bun-install-registry ↔ next dev-server 对调，两者 G/H 互换 ✅/⏰）。
   这是设备长跑 + 180s 墙钟下的固定重灾清单。
2. **G→H 独有集合的真实交集是 5**：两轮 zip only 清单的字面交集 7 中，
   plugins/sqlite/node-http-connect.node.mts 三个是提取管线的共同假失败
   （两轮 log 中 42/122 用例全绿、node.node.mts 不存在）。log 口径下真实交集 =
   **bun-audit、frozen-lockfile-pruned、expo、bun-write、node-http-connect.test.ts**，
   其余独有成员两轮间轮转进出。
3. **26286 hang 轨迹**：G 全量 PASS → H TIMEOUT——间歇性定性维持，诊断套件
   `probe-p8/`（判定树 + 双 binary 对照脚本）就绪，下轮设备侧执行回填。

## 5. 两轮 diff（G→H）：无代码回归信号

**转绿 10**：architecture-match（30/30，#44 兑现）、inspect、bun-add、
bun-dedupe、bun-update-transitive、catalogs、pnpm-lock-v9、nested-overrides、
node-dns、napi-finalizer-delete-ref。

**新增失败 21**（18 个与 A 轮共挂 = overlap；3 个独有者均为环境类）：

| 模式 | 文件 | 特征 |
|---|---|---|
| 单用例轮转（11） | bunshell、migrate、migrate-bun-lockb-v2、spawnSync、spawn-pipe-leak、bundler_npm、native-plugin、26225、26657、bun-add-catalog、child-process-exec | G 全绿 → H 仅挂 1 用例（如 bunshell 422 用例挂 1），设备压力抖动 |
| bake/dev 族（4） | production、react-response、request-cookies、server-sourcemap | 族 6 摆动（13→17 文件），A 轮也挂 |
| install 压力轮转（4） | bun-update、bun-install-patch、bun-patch、bun-install-registry | verdaccio 状态劣化 |
| node-gyp 环境（2） | napi/uv、uv_stub | G `+295/-0` → H 0.7s 秒挂（node-gyp bash 127） |

## 6. overlap 167 的八族构成（对照 `20260914-failures-root-cause-and-user-impact.md` 族口径）

族 1 install/verdaccio 基建 ~25；族 2 TTY/PTY 平台边界 ~6（terminal×3/tty/repl，
**与 A 完全同挂，平台口径一致**）；族 3 AF_UNIX/hmdfs 沙箱 ~10；族 4 外部服务 ~19
（third_party 17 + valkey 2）；族 5 重型构建工具 ~10；族 6 bake/dev 17；
族 7 HTTP/网络投递 ~8；族 8 构建机专属+断言差异 ~35。
上轮 161 → 本轮 167，**组成高度稳定，+6 全在族 6/族 8 摆动**。

## 7. 修复兑现核对（H 轮全量口径）

| 项 | 结果 |
|---|---|
| platform "openharmony" / F3 | ✅ 保持 |
| F1 p6 + multi-run | ✅ 保持 |
| F2 p7b 目录路由 | ✅ 保持 |
| architecture-match（#44） | ✅ **全量转 PASS（30/30）** |
| A3-11 `libcPathForDlopen` musl loader（FIFO 族 32 文件） | ❌ **未兑现**：7 个失败文件段内仍现 `libcPathForDlopen: unsupported platform openharmony`（filesink、socket、fetch、streams、cp、process、bun-serve-file）——虽属 overlap，但系明确立项项，**需重新跟进** |

## 8. 结论与下一步

**结论**：
1. 五大修复（platform/F1/F2/F3/architecture-match）全量兑现，无回归。
2. 确定性待修项 **0**：独有 15 = 8 慢性超时 + 3 verdaccio 轮转 + PARKED 1 +
   待定性 2（child-process-exec、node-http-connect）。
3. 与 A 的真实残余面 = 0.43pp 用例率 + **慢性面约 10 文件**（固定超时 8 +
   frozen-lockfile-pruned + node-http-connect），不是"稳定独有仅 2"。
4. 设备确认文档三处出入（Duration 01:29:53→实为 01:44:20；交叠 5→实为 7；
   独有 10→实为 15）已由本报告 log 口径修正，zip 原样保留不改。

**下一步（按收益）**：
1. **A3-11 兑现缺口**：`libcPathForDlopen` openharmony 分支（影响 7 失败文件，
   harness 侧 musl loader 路径）——唯一明确立项未兑现项。
2. **child-process-exec / frozen-lockfile-pruned 隔离复跑定性**（3 轮 × 10 文件
   口径沿用 G 轮补充节方法）。
3. **26286 hang**：执行 `probe-p8/` 七针判定树，回填结果出修复 PR 或降级结论。
4. **超时集治理**：12 个慢性超时文件单独立册（`knowledge/` 测试台账），
   验收时按"固定重灾清单"口径扣除，避免逐轮误计回归。
5. **lists/ 提取管线修复**：改用 log 逐文件行（✅/❌/⏰）生成三张集合清单，
   消除超时漏报与嵌套 EXIT_CODE 假阳性（§2）。

## 文件清单

| 文件 | 内容 |
|---|---|
| `../fulltest-data/615b48e95/fulltest-615b48e95.log` | runner 进度日志（**2001 行逐文件结果，本轮地面真相**） |
| `../fulltest-data/615b48e95/all-official-report-20260917_183905.txt` | 逐文件详细输出（2.5MB，内联段仅覆盖重试文件） |
| `../fulltest-data/615b48e95/lists/` | 设备侧三张集合清单（**有 §2 缺陷，仅供对照**） |
| `../fulltest-data/615b48e95/confirm-jxbit-615b48e95-fullrun-20260917.md` | 设备侧确认文档（含 3 轮隔离复跑补充节） |
| `../fulltest-data/archive/round-G-3ac1bc4d8.tar.gz` | G 轮数据（已归档 2026-09-21；rerun + fullrun 确认、repro-logs 在包内，log = 地面真相） |
