# 现存失败与问题追踪清单（2026-09-21）

> 依据：`fulltest-data/ohos-bun全量测试报告.md`（A = brew 1.4.0_80 固定基线 185 失败 ×
> B = 615b48e95 182 失败）+ `analys/20260917-round-report.md`（H 轮分析）+
> `fulltest-data/615b48e95/confirm-...md`（3 轮隔离复跑补充节）。
> 本文档 = 修复工作清单：每项一个编号，修一项勾一项。

## 0. 全景（一句话版）

- B-only-fail 8：4 verdaccio 轮转（隔离复跑全绿，环境压力）+ 2 慢性超时（26286/expo）
  + 1 PARKED（bun-write）+ 1 已可结案（child-process-exec）。
- 稳定复现的真独有失败 = **0**（2 个 PARKED 不计）。
- both-fail 174：**50 个 Linux x64 基线也挂（上游问题）+ 124 个 OHOS 环境特有**
  （其中 ~9 internal/build 为构建机专属口径噪声，bake/dev 15，慢性超时 3，
  TTY/PTY ~6 与 A 同挂，AF_UNIX/hmdfs ~10，外部服务 ~6，其余 env-baseline）。
  **174 内部差异核查见 §9**：143 签名逐位一致 + 12 模式翻转 + 19 用例数漂移；
  最大真差距 = isolated-install ~54 用例（R8）。
- A-only-fail 11：我方已修复转绿（hot、bun-add、parallel、02499、32492、
  shell-hang、spawn-streaming-stdin、sleep、sourcemap-simd、fetch.tls、
  napi-finalizer-delete-ref）—— 正向差异，无需处理。
- 与 A 的真实残余 = 用例率 98.65% vs 99.08%（0.43pp）。

## 1. 问题清单与状态

| ID | 问题 | 优先级 | 修复面 | 状态 |
|---|---|---|---|---|
| R1 | A3-11 `libcPathForDlopen` openharmony 缺口：官方树 harness 无该 case → throw，7 失败文件段内 81 次报错 | ~~P1 修复项~~ → **测试树承载类**（修复面=我们树，PR15 已交付） | 档案 [test-tree/a3-11-harness-libcpath-for-dlopen.md](../test-tree/a3-11-harness-libcpath-for-dlopen.md)；官方树 patch 降为对比轮可选工具 | ✅ 已交付随树；对比轮待选注入或扣减口径 |
| R2 | 26286 hang 间歇性未定性（G PASS → H TIMEOUT） | P1 | 设备侧执行 `probe-p8/` | ✅ **根因已由 #49 修复交付**（Terminal PTY epoll：内核对 PTY master 不交付事件 + reader 启动时序烧掉 exit 通知；merge 3238ce0da1）——待下轮 fulltest 验证转绿 |
| R3 | child-process-exec 台账簇名 `pending-isolated-retest` 滞后（隔离复跑已 3 轮全绿） | P3 | 台账（报告 md/csv + 再生脚本） | ✅ 已结案为轮转波动 |
| R4 | 慢性超时 12 文件未立册，逐轮被误计回归 | P2 | knowledge/ 台账 | ✅ 已立册 |
| R5 | verdaccio 长跑劣化 4 文件（bun-audit/bun-update/frozen-lockfile-pruned/bun-add-catalog）：验收缺"隔离复跑复核"固化口径 | P2 | 验收口径（本档 §4） | ✅ 口径固化 |
| R6 | 设备侧 lists/ 提取缺陷（超时漏报 + 嵌套 EXIT_CODE 假阳性） | P2 | update-inventory.sh 补 log 口径清单生成 | ✅ 已实现 lists-log/ |
| R7 | PARKED 2 项（bun-write 切片、expo install 长跑） | 不修 | —— | 🅿️ 双方共识不修，验收扣减 |
| R8 | **both-fail 里的我方真差距**：install 全族 ConnectionRefused（isolated-install 55 + bun-lock 18 + bun-audit 106 + bun-update 104 + frozen-lockfile-pruned 80 ≈ **364 用例 = 931 的 39%**）+ bun-test.test.ts（✅ #51 已修）——见 §9.3 / §10 | **P0** | 归因 + 修复（npm.rs/#50、runner 默认/#51 已合并；主因探针 `analys/probe-r8/` 就绪待设备） | 🔬 签名扩展至全 verdaccio 族，探针就绪 |

---

## 2. R1：A3-11 libcPathForDlopen —— **重新定性：测试树承载类**（2026-09-21）

> **定性修正**：本项不是"待修复的 runtime/工具债"—— 修复面就是我们自己
> fork 树的 `test/harness.ts`（PR #15 已交付并真机验证），正常交付 fulltest
> （我们 binary + 我们树）下该问题不存在。案例档案移至
> **[`test-tree/a3-11-harness-libcpath-for-dlopen.md`](../test-tree/a3-11-harness-libcpath-for-dlopen.md)**，
> 此处仅留技术要点与对比轮残留面。

### 2.1 根因（H 轮日志取证）

- 错误：`error: libcPathForDlopen: unsupported platform openharmony`，H 轮
  all-official-report 中出现 **81 次**，落在 filesink / cp / streams /
  bun-serve-file / bun-serve-cookies 等 7 个失败文件段。
- 堆栈路径：`/storage/.../bun-official-v140/test/harness.ts:1853` ——
  **A/B 对比轮部署的是官方 v1.4.0 测试树**，官方 harness 的
  `libcPathForDlopen()` 没有 `case "openharmony"`（bun-v1.4.0 tag 逐字核对：
  linux/darwin/android/freebsd → default throw @1853）。
- 我们的修复（PR #15，musl loader 显式路径
  `/system/lib/ld-musl-aarch64.so.1`）只存在于 fork 树 harness —— 官方树部署
  拿不到。因此该错误 **A、B 两轮共挂**（overlap），但属我方立项欠账。

### 2.2 对比轮可选工具（官方树注入，非交付必需）

| 文件 | 内容 |
|---|---|
| `fulltest/patches/official-v140-harness-openharmony.patch` | 对官方 v1.4.0 harness.ts 的最小 patch：补 `case "openharmony"` 返回 musl loader（与 fork 树 PR15 同语义） |
| `fulltest/patch-official-harness.sh` | 宿主机执行：对官方测试树目录打 patch（幂等：已打/非官方树均拒做并说明）；打完自动跑 §4.1 式校验 grep |
| 指导 §4.5（新增小节） | A/B 对比轮部署官方树时，打包前先跑 patch 脚本 |

### 2.3 验证

- 本地：patch 对 `git show bun-v1.4.0:test/harness.ts` 提取件 `git apply --check` 通过；
  脚本幂等性自测通过。
- 设备（待复跑）：重打官方树 tar → 部署 → 全量后 grep all-official-report
  无 `unsupported platform openharmony`；filesink/socket/fetch/streams/cp/
  process/bun-serve-file 段该错误清零。

---

## 3. R2：26286 hang（P1，阻塞于设备）

- 间歇性：G 全量 PASS → H TIMEOUT（360s×2 次尝试耗尽）。
- `analys/probe-p8/`（七针判定树 + 双 binary 对照脚本）已就绪，**待设备侧执行回填**
  → 出修复 PR 或降级结论。本会话（无设备）不动。

## 4. R5：verdaccio 长跑劣化 4 文件（验收口径，本轮固化）

**口径**（G 轮确认文档补充节方法，2026-09-17）：
全量轮出现的 install 族失败（verdaccio 依赖），验收前必须做 **3 轮隔离复跑**
（每次仅该批文件、约 1 分钟、同 binary 同树）：

- 3 轮全绿 → 定性"长跑环境压力随机波动"（设备 free ~1.5G + verdaccio 状态
  劣化），**不计入稳定独有失败**；
- 任一轮复现 → 升级为真回归，走 issue 立档。

当前 4 文件（bun-audit、bun-update、frozen-lockfile-pruned、bun-add-catalog）
H 轮隔离复跑已全绿 —— 按此口径不计回归，仅台账留痕。

## 5. R3：child-process-exec 结案（本轮已执行）

- 证据：H 轮 3 轮隔离复跑全绿（confirm 文档补充节）；全量轮为单用例挂
  （maxBuffer throw 行为），符合"单用例轮转"特征。
- 动作：台账簇 `pending-isolated-retest` → `rotation-single-case`
  （报告 md/csv 修正 + update-inventory.sh 映射同步，保证下轮再生一致）。

## 6. R4：慢性超时 12 文件立册（本轮已建册）

`knowledge/chronic-timeout-registry.md`：G↔H 11/12 相同的固定重灾清单
（sec-scanner×2、expo、repl、terminal×3、tty、26286、handle-leak、
bun-install-registry ↔ next dev-server 对调对），含 A 轮对照与验收扣减规则。

## 7. R6：lists/ 提取管线（本轮已修复）

- 缺陷：设备侧按段落头提取，超时文件（无内联输出段）系统性漏报、通过文件
  嵌套 spawn 的 `EXIT_CODE:1` 造成假阳性（H 轮漏 8 多 3）。
- 修复：`update-inventory.sh` 在再生台账时同步输出 **log 口径**三张清单到
  `<轮目录>/lists-log/`（fail_B / fail_B_only / fail_overlap_both），
  与 runner log 逐文件行（地面真相）严格同源。设备侧 lists/ 保留作对照。

## 8. R7：PARKED（不修）

- `test/js/bun/io/bun-write.test.js` 43/1：`Bun.write` 切片行为，双方共识不修。
- `test/integration/expo-app/expo.test.ts`：install 长跑 exit=143，设备性能边界。
- 验收时按固定扣减项处理，不进入修复队列。

---

## 9. A∩B 共同失败 174 的差异核查（2026-09-21）

> 口径：失败集合 both-fail 的 174 文件，逐文件对比 A/B 签名（模式 ❌/⏰ +
> 用例 pass/fail）；漂移文件再用 G 轮（3ac1bc4d8）runner log 做三方对照
> （G 轮已归档：`fulltest-data/archive/round-G-3ac1bc4d8.tar.gz`），
> 区分"H 轮单轮轮转"与"G/H 稳定差距"。上游共享口径：174 中 **50 个**
> Linux x64 基线也挂（B-only 侧另有 expo 1 个；合计 51）。

### 9.1 总拆分

| 类别 | 数量 | 结论 |
|---|---|---|
| 签名一致 | **143（82%）** | 稳定共挂，A/B 无差异（❌ 比对含用例数；⏰ 对 ⏰ 只比模式不比时长，如 repl/handle-leak） |
| 模式翻转 ❌↔⏰ | **12** | 见 §9.2，全部有既有归因 |
| 用例数漂移 | **19** | 见 §9.3，G 轮对照后 12 个为噪声级 |

### 9.2 模式翻转 12（无一需要新动作）

**A❌ → B⏰（8 个）**：sec-scanner ×2、bun-install-registry、terminal ×3、tty、
next-build —— **全部是慢性超时册成员**（`knowledge/chronic-timeout-registry.md`）。
同文件 A 轮硬失败、B 轮拖成超时：慢设备把"能跑完但挂"变成"跑不完"，册内
扣减规则已覆盖。

**A⏰ → B❌（4 个）**：bake bundle/css/hot（A 轮旧墙钟 120s 代超时 → B 轮跑完
暴露用例级失败 16/14/11）+ spawn.test（A ⏰360.4s → B ❌135/1）。方向是
"B 轮跑得更完整后仍挂"，属观察口径差异而非回归。

### 9.3 用例数漂移 19 × G 轮三方对照

**① H 轮单轮轮转（G = A 签名，H 突变）—— 1 个**

| 文件 | A | G | H |
|---|---|---|---|
| `test/js/bun/patch/patch.test.ts` | ❌26/1 | ❌26/1 | ❌13/14 |

与 20260917-round-report §5"install 压力轮转（verdaccio 状态劣化）"一致，无动作。

**② G = H 稳定差距（同树同设备下我方 binary 与 A 的真差距）—— 4 个** 🆕

| 文件 | A | G | H | 判读 |
|---|---|---|---|---|
| `test/cli/install/isolated-install.test.ts` | ❌81/1 | ❌28/54 | ❌27/55 | **最大单点差距 ~54 用例**：both-fail 内 B 侧失败用例 626 中独占 55（≈9%）。G/H 两轮高度一致 → 非 H 轮抖动，是我方 binary 的稳定差距，**立项归因（R8）** |
| `test/cli/install/bun-lock.test.ts` | ❌39/1 | ❌16/24 | ❌22/18 | ~17-23 用例稳定差距（G/H 间有波动），并入 R8 |
| `test/cli/test/bun-test.test.ts` | ❌93/2 | ❌1/0 | ❌1/0 | **失败性质不同**：A = 用例级（93 跑 2 挂）；G/H = 文件级（仅 1 用例跑完 exit≠0，早退）。持续两轮，并入 R8 |
| `test/js/bun/websocket/websocket-server.test.ts` | ❌86/31 | ❌116/1 | ❌116/1 | **反向差距**：我方稳定好 ~30 用例（A 差），残余 1 用例挂，观察即可 |

**③ 噪声级漂移（|Δfail| 1-3 或 G/H/A 间无方向）—— 14 个**

bun-install(230/8→237/1)、bundler_compile(63/7→68/2)、fs.test(493/11→498/6)、
migrate(121/4→124/1)、dns(69/11→67/13)、process.test(162/7→163/6)、
fs.watch(38/3→36/5)、spawn-maxbuf、spawnSync、spawn-pipe-leak、
resolver-permission-denied-ancestor、bundler_npm、require-cache、bun-upgrade ——
同一文件两轮挂的用例数不同但量级不变，设备压力噪声（round report §5
"单用例轮转"定性一致），无动作。

### 9.4 对既有结论的修正

1. 上一版全景写"53 个上游共享"系提取混入图例行的口径误差，**更正为 51**
   （both-fail 50 + B-only expo 1）/ OHOS 特有 131。
2. "overlap 167 全部与 A 同挂"应精确为：**文件级 100% 同挂，但用例级存在
   19 处漂移，其中 4 处是 G/H 稳定差距** —— isolated-install 是 overlap 里
   最大的我方单点失分来源，此前未被单独立项。

---

## 10. R8 归因首轮：isolated-install 55 连挂（2026-09-21）

### 10.1 取证链（H 轮 all-official-report isolated-install 段，852 行 / 55 fail）

- **签名**：70× `ConnectionRefused` + 72× `failed to resolve`；36 处 "panic"
  全是断言模板（`expect(err).not.toContain("panic:")`），**无真 panic**。
- **失败形态**：install 子进程 stderr = `Resolved, downloaded and extracted [N]`
  之后多条 `ConnectionRefused downloading package manifest <pkg>` → checkInstall
  `expect(exited).toBe(0)` 挂。失败用例从第 2 个用例贯穿到文件最后一个 ——
  **非"verdaccio 中途死"模式**，按用例内禀因素确定性分流（G 28/54 ↔ H 27/55，±1）。
- **registry 结构**：`VerdaccioRegistry` 每文件一实例；verdaccio 以
  `fork(execPath: bunExe())` 拉起 —— **服务器宿主 = 被测 binary 本身**。
  A 轮 verdaccio 跑在 A runtime 上、B 轮跑在我们 runtime 上：同树不同服务器宿主，
  这就是 A/B 差异的结构性来源。verdict 旁证：同轮其他 verdaccio 文件
  （bun-add-catalog 148/1、bun-audit 76 过）证明 verdaccio 在我们 binary 上可跑，
  isolated-install 是单实例扛 ~82 次 install 的最重负载场景。
- **客户端排除**：`PackageManagerTask.rs`（fetch 代码）、`src/dns/lib.rs` 与
  61dbc3a9d **零差异** —— ECONNREFUSED 非客户端代码回归。
- harness `registryUrl()` 返回 `http://localhost:<port>/`，verdaccio 被
  `-l 127.0.0.1` 钉死 IPv4（harness 注释自述此坑）；本轮未发现 localhost→::1
  解析差异证据，DNS 假说暂列观察。

### 10.2 排除法命中并已修复的确认回归：npm.rs O_TMPFILE attempt-#3 丢失

- `git diff 61dbc3a9d..HEAD -- src/install/npm.rs`：上游 Rust 重写窗口
  （23427dbc12f）把 A 基线树的 OHOS attempt-#3 兜底吃掉 —— "linkat 仍失败时
  tmp_path 写入 + rename 原子落盘"。结合台账 §1.3（**OHOS 沙箱 outright 禁止
  linkat**），attempt-#3 在真机是必现路径而非理论兜底：丢失后 manifest 缓存写
  直接 Err（上游版 `?` 传播）。
- **已恢复**：src/install/npm.rs 与 61dbc3a9d 逐字节一致（`cargo check -p
  bun_install` / clippy / fmt 全过）。**已交付 PR #50**（claude/ohos-npm-otmpfile-manifest-cache，
  单 commit fd1bb0dd5f，check-pr.sh PASS），档案
  [`issues/pr50-p1-npm-manifest-cache-otmpfile.md`](../issues/pr50-p1-npm-manifest-cache-otmpfile.md)。
- 注意：该回归的症状是缓存写失败（PermissionDenied 族），**不是** 55 连挂的
  ConnectionRefused 直接原因；但它增加 registry 重复请求负载，与主因叠加。

### 10.3 ECONNREFUSED 主因候选与设备探针（下一步）

| 候选 | 机制 | 探针 |
|---|---|---|
| **fd 耗尽（首选）** | 设备 rlimit NOFILE=256（台账/pr42），verdaccio-under-bun 的 keep-alive 连接 + install 并发 48 连接 → 宿主 accept EMFILE → 新连接 RST → ECONNREFUSED | P-R8-3：失败时 `ps` + `/proc/<verdaccio pid>/fd` 计数 vs 256 |
| accept 队列溢出 | manifest burst > somaxconn/backlog | P-R8-2：`BUN_CONFIG_MAX_HTTP_REQUESTS=4` 对照重跑，若转绿即坐实 |
| 确定性复核 | 排除长跑态依赖 | P-R8-1：isolated-install 单文件隔离复跑 3×（沿用 G 轮补充节方法） |
| 双 binary 对照 | 61dbc3a9d 参考构建跑同探针 | P-R8-4：A 探针包方法（probe-p8 模式） |

修复方向（按探针结论）：fd 耗尽 → 我们 runtime 的 node:http 连接管理/OHOS
rlimit 上限适配；队列溢出 → install 侧 OHOS 并发上限适配。

### 10.4 R8 第三成员：bun-test.test.ts 归因（2026-09-21，已修复交 PR #51）

H 轮日志段 206 行取证，两个确定性机制，均已恢复与参考树逐字节一致（**PR #51**）：

1. **默认每用例超时 30s ≠ 上游契约 5000ms**（`context.rs` 的
   `target_env="ohos"` 门控，d576713d37c 引入）：ASan 插桩慢构建时代的有意适配，
   前提已失效；官方树 `--timeout > timeout should default to 5000ms` 确定性失败
   （子测试 5.5s 完成而未被 5s 击杀，日志实证 `(pass) timeout [5502.69ms]`）。
   这是 binary 公开行为偏离（非测试树承载），已移除门控恢复 5s。
2. **`absolute_working_dir` 丢失 `getcwd_honest()`**（`Arguments.rs`，上游 merge
   6692a5d5b1b 冲掉 pr42 BUG-01 hunk）：shim 的 getcwd 拦截器把已删除 cwd 静默
   替换为 $HOME → `bun test` 扫真实 $HOME / discovery 基路径漂移 —— scanner
   MAX_PATH 跳过用例（3-files-vs-1）失败的候选根因，已恢复调用点，待真机复核。

顺带发现：工作区索引曾被外部工具整体 stage（提交误带 142 文件），check-pr.sh
正确拦截；后续提交一律用显式 pathspec 形式。

### 10.5 签名扩展：ConnectionRefused 覆盖全 verdaccio 族（2026-09-21，R8 升 P0）

对 H 轮报告逐文件统计 ConnectionRefused：bun-audit **774**×、bun-update 212×、
frozen-lockfile-pruned 203×、bun-add-catalog 1× —— 与 isolated-install（70×）、
bun-lock（39×）**同签名**。install 全族失败用例合计 ~364 = 全量 931 的 39%。

**统一假设**（合并原"verdaccio 轮转/环境压力"旧归因与 R8）：verdaccio 宿主
（= 被测 binary，harness fork execPath）在**累计负载**下退化/死亡 → ECONNREFUSED。
模型自洽性：隔离复跑绿（短负载不触发阈值）、全量挂（长负载触发）、A binary 宿主稳
（其 runtime 更稳）、bun-add-catalog（轻负载）几乎不受影响。

→ 旧归因修正：bun-audit/bun-update/frozen-lockfile-pruned 的"轮转"与
isolated-install 的"稳定差距"是**同一机制在不同负载敏感度下的表现**，
§4 的隔离复跑口径保留但定性文本改为"阈值待探针定罪"。
→ **探针套件就绪**：[`probe-r8/`](probe-r8/README.md)（r8a 生命体征 / r8b 负载
塑形 / r8c 隔离确定性 / r8d 双 binary 对照 + 判定树），待设备会话执行。
修复落地后预期回收 ~364 用例。

---

*建立：2026-09-21 | 依据：H 轮（615b48e95）全量报告 + 20260917-round-report +
confirm 补充节 | R3/R4/R6 本轮落地；R1 重新定性为测试树承载（档案
test-tree/a3-11-*），其官方树注入为对比轮可选项；R2 设备执行为遗留验证点*
