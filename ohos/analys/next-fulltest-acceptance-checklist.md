# 下一轮 fulltest 验收清单（2026-09-09 编制，同日更新：#27/#28/#29 已全部合并）

> 前提达成：ohos-aarch64 tip = `c4323a5d33`，**已包含全部三项修复**（#26 runner
> env、#27 tmpdir 探测 + wasi preopen、#28 panic 守卫、#29 platform
> "openharmony"）。**待办 = 从该 tip 构建新 binary → 下一轮 fulltest → 按本清单
> 核对。**
> 测试树口径二选一，验收项不同（标注 🌳=需我们树 / 🌲=任意树）。
> **注意**：#29 合并后 `process.platform` 首次报 "openharmony"——所有 isOHOS
> 门控是首次真机激活，既有 skip 与适配路径均为真机验证过的实现（他们的轮次
> 长期运行同款门控）。

## H 轮验收结果（2026-09-17，615b48e95，全量 2001 文件）

> 详细数据：[`20260917-round-report.md`](20260917-round-report.md)。
> 清单口径改用 runner log 逐文件行（设备侧 lists/ 提取有超时漏报 + 嵌套
> EXIT_CODE 假阳性，见轮报告 §2）。

| 项 | H 轮状态 |
|---|---|
| A1-1 unix socket 簇 18 子用例 | ⚠️ 残余：listen-connect-args、serve-args 各 1 文件挂（族 3） |
| A1-2 wasi hello world | ✅ 绿 |
| A1-3 browser-field panic 两文件 | ✅ x509 绿；bundler_edgecase 仍挂但为断言差异（crashes 0，非 panic） |
| A1-4 install $npm_* 簇 | ✅ publish/workspaces 绿；bun-pack、lifecycle-scripts 各 1 文件挂（族 1 verdaccio） |
| A1-5 terminal/tty/websocket 7 文件 | ❌ terminal ×3、tty 为慢性超时固定集（族 2 平台边界，与 A 同挂）；websocket-unix 挂（族 3） |
| A1-5b 23 个 isOHOS 门控文件 | ✅（#29 兑现，platform "openharmony"） |
| A1-5c browser-field panic | ✅（#28 兑现，Crashes 0 贯穿 G/H 两轮） |
| A1-6 napi uv / uv_stub 保持绿 | ❌ H 轮双挂（node-gyp bash 127 环境失败；G 轮全绿） |
| A1-7 / A2 测试树 OHOS skip 面 | ✅（fs-birthtime 等不在失败清单） |
| A3-8 vendored node EPERM ~22 文件 | ✅ 主面收复（vendored 残余并入族 8） |
| A3-10 node-net ×39 | ✅ 大面收复，残 3 文件（族 3） |
| **A3-11 mkfifo/FIFO 族 32 文件** | 🌳 **重新定性：测试树承载类**（2026-09-21，档案 [test-tree/a3-11-harness-libcpath-for-dlopen.md](../test-tree/a3-11-harness-libcpath-for-dlopen.md)）——修复面=我们树（PR15 已交付），非交付欠账。官方树对比轮残留：可选注入（`fulltest/patch-official-harness.sh`，指导 §4.5）或按本类口径扣减并标注 |
| C-1 超时收敛 | ❌ 12 个为慢性固定集（G↔H 11/12 相同），非负载波动；按固定重灾清单立册 |
| C-4 崩溃数 0 | ✅ 连续多轮保持 |
| —（新增观察）26286 hang | 间歇：G 全量 PASS → H TIMEOUT；诊断套件 `probe-p8/` 就绪待执行 |

## A. 预期转绿（逐项核对）

### A1. runtime 修复的收敛（🌲 任意树）
| # | 项 | 依据修复 | 上轮状态 |
|---|---|---|---|
| 1 | unix socket 簇 18 子用例（listen-connect-args ×5、serve-args ×9、serve.test unix ×4） | #27 tmpdir 探测 | 20260903/09 两轮 EPERM |
| 2 | wasi.test.js hello world | #27 preopen 探测 | EACCES |
| 3 | bundler_edgecase + x509（browser-field panic 两文件） | panic 修复 | SIGABRT |
| 4 | install 家族 $npm_* 簇（bun-pack/publish/lifecycle-scripts/workspaces） | de0c2dbfbe5（newEnvp，46a905a6c 已含） | 20260903 EPERM 类 |
| 5 | terminal/tty/websocket 7 文件 | b11d63bbcb9（EPOLLONESHOT，46a905a6c 已含） | 20260903 挂 |
| 5b | **23 个 isOHOS 门控文件**（fs-birthtime、listen-connect-args、serve-args、平台 fixture 族……清单=他们树含 isOHOS/openharmony 的 jxbit_only 交集） | platform "openharmony" 修复（PR #29，需进构建） | 20260902/09 两轮因门控失效挂 |
| 5c | browser-field panic 两文件（bundler_edgecase、x509） | panic 修复（PR #28，需进构建） | 20260908 SIGABRT |
| 6 | napi uv / uv_stub 保持绿 | 懒修复已验证 | sys-release_only ✓ |

### A2. 测试树侧的收敛（🌳 需我们树——9/2 reconcile 已带入）
| # | 项 | 依据 |
|---|---|---|
| 7 | fs-birthtime ×4、bun-build-compile ×2、24742、bundler_edgecase(AbsolutePath)、server.spec ×2、serve.test v6 | 测试树 OHOS skip（vs 他们的树无这些 skip） |

### A3. runner 侧收敛（🌲 需我们的 runner —— #26/#27）
| # | 项 | 依据 |
|---|---|---|
| 8 | vendored node EPERM 类 ~22 文件 | #26 NODE_TEST_DIR |
| 9 | 超时类 5-11 文件 | #26 wall ×3 |
| 10 | **node-net.test.ts ×39**（unix socket 落 hmdfs） | #27 tmpdir 探测（overlap 分析新确认的受益者，见 `20260908-overlap-135-classification.md`） |
| 11 | **mkfifo/FIFO 族 32 文件**（filesink ×21、fetch ×6、streams ×5） | 🌳 需我们树：我们 harness 的 `libcPathForDlopen()` 已返回 musl loader（他们的树返回裸名 "libc.so" → 挂）。零代码改动 |

## B. 不预期转绿（保持红，避免误判）

- 135 个 both-fail 中的网络域/第三方/长跑类（esbuild 产物、bunx、next-auth、grpc resolver、bun-add 摇摆）
- T49 族（ADDRCONFIG）、fs-birthtime、T23 签名类 —— 长期 skip/隔离
- ~~3 个疑似挂起~~ → **20260909 已解除**（4 个"疑似挂起"全部出结果并收敛为具体问题，见对比文档 §3.5）：bundler_compile=12 断言差异、serve-body-leak=HTTP2Unsupported（构建缺口，新立项）、spawn-pipe-leak=1 子用例超时+47 孤儿（唯一残余嫌疑）、spawn.test=1 断言
- HTTP2Unsupported：OHOS 构建的 H2 会话握手失败（代码与参考 fork 一致）→ **构建配置对比立项**（BoringSSL ALPN/uWS flags）

## C. 观察项（不定绿红，记录趋势）

1. 21 个超时是否收敛（设备负载因素 vs 真实挂起）
2. T50 管道竞态 / EPIPE 家族出现频率
3. skip 健康度：resolve-dns IPv6 旧 skip 是否可直接过（§6.2 试放开项）
4. 崩溃数应为 0（panic 修复后；若再现即为新 panic，立即取 bun.report）

## D. 产出物

- 与 20260908 轮逐文件 diff（fail_jxbit.txt 对比），按 A/B/C 归类
- 台账 `knowledge/test-tree-changes-vs-v1-4-0.md` §6.2 的试放开项复核结果回填
