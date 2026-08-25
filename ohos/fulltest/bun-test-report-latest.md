# Bun OHOS 最新测试结果报告

> 数据来源:设备 media 域全量测试,runner 同款口径(PARALLEL=2 / RETRIES=2 / 1937 文件)。
> 最新本地结果 = **2026-08-15 envfix 轮**(`dev-tmp/result_envfix.txt`)。
> 注:另有 cu 域一轮 **98.58%(61810/888)** 更优,明细在设备侧未拉回,见 §5。

---

## 1. 当前通过率(envfix 轮,2026-08-15)

| 指标 | 值 |
|---|---|
| **用例通过率** | **98.02%**(61632 pass / 1244 fail,分母 62876) |
| 文件通过率 | 86.8%(1681 / 1937) |
| 超时文件 | 8(用例剔出分母) |
| 崩溃(SIGABRT/SIGSEGV) | **0** |
| Duration | 03:15:11 |
| Binary | github-hosted 产物(1.4.0) |
| 环境 | PARALLEL=2 RETRIES=2 CI=1,media 域 + 环境修复(node 进 PATH 等) |

### 通过率演进

| 轮次 | 日期 | 用例率 | 说明 |
|---|---|---|---|
| sb-fy-sb 基线报告 | 06-12 | 88.7% | 外部对照基线 |
| 我们 v1(首次全量) | 07-27 | 94.8% | |
| v0.0.4(compile+napi 修复) | 07-29 | 95.0%(P3 全分母) | compile SIGSEGV 8→0、napi build 11→2 |
| ce76c18_r2(media,环境修复前) | 08-15 | 97.60%(58420/1438) | |
| **envfix(media+环境修复)** | 08-15 | **98.02%(61632/1244)** | ← 本报告 |
| cu 域(明细在设备) | 08-15 | **98.58%(61810/888)** | 当前最好成绩 |
| 参照:social4hyq 基线(7780f3e42 树 + github JIT on) | — | 98.48% | 已达到/超过 |

---

## 2. 失败用例模块分布(envfix 轮,按 per-file 结果行重算,2026-08-25 复核)

| 模块 | 失败用例 | 失败文件 | 环境修复前(ce76c18_r2) | 改善 |
|---|---:|---:|---:|---:|
| js/bun | 246 | 54 | (js 合计 556) | js 合计 -79 |
| cli/install | 226 | 18 | (cli 合计 516) | cli 合计 -64 |
| cli/run | 188 | 14 | | |
| js/node | 169 | 28 | | |
| bundler(全目录,含 transpiler 50) | 127 | 24 | bundler 139→127 | -12 |
| bake/dev(含 dev-and-prod 12) | 83 | 12 | bake 84→83 | -1 |
| regression/issue | 51 | 31 | regression 82→51 | -31 |
| js/first_party | 30 | 1 | | |
| cli/test | 25 | 4 | | |
| internal/source-lints | 23 | 16 | | |
| 其他(js/third_party 16、js/web 10、js/workerd 6、cli/inspect 5、cli 其余 8、integration 10、internal 其余 3、napi 3) | 60 | 33 | | |
| **合计(per-file 口径)** | **1232** | **248** | **1438(汇总口径)** | **-194 用例 / -126 文件** |

> 口径说明(2026-08-25 复核发现):汇总块 CF=1244,而 per-file 结果行加总=1232,**差 12**(推测为个别重试后通过的文件,其失败尝试被累计进汇总块;模块分布按 per-file 口径统计)。文件侧:256 failed = 248 个 ❌ FAIL 文件 + 8 个 ⏰ 超时文件(超时用例剔出分母)。

## 3. 失败用例最多的 Top15 文件

| 失败用例 | 文件 | 已知原因方向 |
|---:|---|---|
| 93 | cli/run/multi-run.test.ts | 多进程 spawn/env 继承 |
| 74 | js/node/async_hooks/AsyncLocalStorage-tracking.test.ts | async_hooks 跟踪差异 |
| 74 | cli/install/bun-install-lifecycle-scripts.test.ts | lifecycle script 执行 |
| 54 | cli/run/filter-workspace.test.ts | workspace 过滤 |
| 52 | js/bun/websocket/websocket-server.test.ts | WS 服务器 |
| 32 | bundler/transpiler/jsx-production.test.ts | JSX 生产模式转换 |
| 30 | js/first_party/ws/ws.test.ts | ws 库兼容 |
| 23 | cli/install/bun-patch.test.ts | patch 应用 |
| 23 | bundler/bundler_compile_autoload.test.ts | compile 自动加载 |
| 22 | cli/install/bun-install-security-provider.test.ts | 安全校验 |
| 21 | cli/install/migration/complex-workspace.test.ts | workspace 迁移 |
| 20 | cli/install/bunx.test.ts | bunx |
| 20 | cli/install/bun-run-bunfig.test.ts | bunfig |
| 19 | cli/test/test-changed.test.ts | |
| 18 | js/bun/util/filesink.test.ts | 文件写入(与 bundler/transpiler/type-export.test.ts 18 并列第 15) |

8 个超时文件(均为重量级/泄漏类,非回归信号):bun-install、bun-run、bunshell、shell-cmdsub-crash、spawn-pipe-leak、spawn、terminal-platform-gaps、handle-leak。

## 4. 失败原因分类(ce76c18_r2 轮的 376 个失败文件逐一定类;envfix 后 ENV 类已大幅收敛)

| 类别 | 文件数 | 失败用例 | 说明 |
|---|---:|---:|---|
| **ENV_OTHER_EXE** | 217 | 638 | 外部可执行缺失(git 之外的第三方 CLI 等)——**环境类最大头** |
| **BUG_REAL** | 72 | 508 | 真实源码 bug / 平台行为差异——**唯一需要改 bun 源码的类别** |
| ENV_NODE | 28 | 155 | node 不在 PATH(envfix 主要修复项) |
| TIMEOUT | 12 | 154 | 环境修复前超时更多 |
| ENV_NATIVE | 12 | 50 | 原生模块/编译类 |
| ENV_BASH | 8 | 72 | bash 特性 |
| ENV_NETWORK | 6 | 73 | 网络限制 |
| ENV_NULL / ENV_GIT / ENV_ESBUILD | 9 | 131 | /dev/null、git、esbuild |
| OTHER | 12 | 0 | 0 用例失败(多为 util 类辅助文件仅文件级失败),补齐 376 文件口径 |

> 11 个类别合计 = 376 失败文件 / 1781 失败用例(ce76c18_r2 轮)。

## 5. 距离 99% 的路径(以最好成绩 cu 域 98.58%/888 fail 为基准;已分析,用户 08-17 决定暂缓)

> cu 域数字来自设备侧汇总,明细未拉回本地,无法逐项复核(本节用例数若与 §6 不一致,§6 为 ce76c18_r2 轮口径、本节为 envfix/cu 轮口径)。

到 99% 需 fail ≤ 627,即**再消 ≥261 个失败用例**。cu 域 888 fail 的构成:62%(~550)环境因素(网络超时 ~300 + 进程模型 ~250 + 外部服务 ~50 + 源码 lint ~50),38%(~340)真实 bug。

1. **路径 A:ENV Skip(快速,无需重建 binary,约 -400 用例)**——扩充 `test/expectations.txt` 的 `[ OPENHARMONY ] ... [ Skip ]` 条目,移除纯环境类失败文件:
   - 网络超时 ~300 case(cli/install 15 个 timeout 文件: bun-install/bun-lock/bun-publish/hoist/npmrc/pnpm-migration 等,OHOS 访问 npm registry 极慢,900s 仍超)
   - 外部服务 ~50 case(js/bun/s3 3 文件 S3 连接 + cli/inspect 4 文件 DevTools 协议)
   - 源码 lint ~50 case(internal/source-lints,非完整源码树预期失败)
   - 落地后用例率 ~**99.2%**。social4hyq 已用此机制(46 条 OPENHARMONY),是上游认可的平台 skip 方式
2. **路径 B:BUG 源码修复(慢,需 CI 重建)**——修真 bug,大头:
   - multi-run pipe stdout 转发 bug(本节 cu 域口径 ~92 case;§6 按 ce76c18_r2 轮为 184+filter-workspace 54=238,两轮数字不同但同一根因:子进程 stdout 未转发给 parent,`filter_run.rs` 同根因)
   - filter-workspace(54 case,已 skipIf 临时跳)
   - jsx-production(32 case,bundler 转译边缘)
   - child_process.exec stdout(24 case)

另:media→cu 域本身净赚 356 用例(node v26/git/bash 进 PATH),**先把 cu 域轮明细从设备拉回本地**可确认增益构成。

## 6. BUG_REAL 的性质拆分:适配差距 vs OHOS 平台局限(2026-08-25 新增;同日按复核修正口径)

BUG_REAL(72 文件 / 508 用例)按根因性质分三档(依据:历轮诊断已知根因 + 失败模式 + 是否依赖平台特性)。**本节子项数字来自 ce76c18_r2 轮的 categorization_final.json,与 envfix/cu 域轮的 per-file 数字(如 multi-run 93)口径不同,不可直接相加**;三档为抽样归类而非 508 全集逐一定档,未覆盖部分为散在小簇。

### A. 适配差距——bun 源码可修,优先级最高(~324 用例,占 BUG_REAL ~64%)

| 簇 | 用例 | 已知根因/判断依据 |
|---|---:|---|
| multi-run + filter-workspace | 238(ce76c18_r2 轮:184+54) | **根因已定位**(A1 诊断):脚本子进程 stdout 没转发给 parent,`multi_run.rs`/`filter_run.rs` 同根因,一处修复两簇全消 |
| bundler transpiler(decorators 12 + decorator-metadata 5) | 17 | 纯 JS 转译逻辑,**不依赖任何 OHOS 特性**——预期可通过源码适配修复(注:同属 transpiler 的 jsx-production 32 用例在 categorization 中归 ENV_OTHER_EXE,不在本档口径内,见下方说明) |
| bun shell(exec / ls / env.positionals / seq-condexpr) | ~25 | shell 内建实现,失败模式是输出/环境差异,适配性质 |
| as-node / bun-serve-html / child-process-exec stdout / spawn-maxbuf / test-shard | ~44 | 进程 spawn/env 继承/输出转发类,与已修过的 PDEATHSIG/execve envp 同族 |
| **合计** | **~324** | 324/508 ≈ **64%** |

> **jsx-production 说明**(2026-08-25 复核修正):原版报告把它算进 A 档(49=17+32),但 categorization_final.json 中它是 ENV_OTHER_EXE。从失败性质看(纯 JS 转译)更像适配差距,归 ENV 可能是分类时的保守处理;本报告取严格口径移出 A 档。**若后续定性为真 bug 并修复,A 档实际收益比表中更大**(+32)。

> 历史佐证:EPOLLONESHOT、PDEATHSIG、execve envp 悬垂、TCSANOW、statx EBADF 都是同类适配差距,**每修一个消一整片**。multi-run(238 用例)是当前性价比最高的单点。

### B. OHOS 平台局限——内核/SELinux/系统服务限制,bun 侧只能 workaround 或 skip(~50~80 用例,其中已逐一定性约 19)

| 簇 | 用例 | 局限点 |
|---|---:|---|
| install 的 link/symlink 类(bun-link、hoist 部分) | ~10 | SELinux 拒 linkat/symlinkat(EPERM),历轮报告 C+A 类,内核策略问题 |
| fs-birthtime-linux | 4 | statx 不提供真实 birthtime,内核字段限制 |
| grpc-js resolver | 3 | OHOS getaddrinfo 行为差异(compat-shim 已部分覆盖) |
| inspect(DevTools 协议) | 8 | 依赖外部服务/调试通道 |
| 网络.registry 慢导致的 install 类 | (部分计入 TIMEOUT) | npm registry 访问极慢,900s 仍超 |

> 上表已定性 ~19 用例;"~50~80"的上界是按同类失败模式外推,未逐一核实。

### C. 待深挖——证据不足以定性(~80~100 用例)

crypto.key-objects(30,可能是 OpenSSL/BoringSSL 行为差异,也可能适配)、bun-patch/bun-run-bunfig/isolated-install(panic,疑似真 bug)、url-fileurltopathbuffer、html-rewriter(workerd,疑似 ICU 相关)等。定性需要逐文件看 REPORT 明细输出。

### 结论

- **适配差距 ≈ 64% 的 BUG_REAL 用例**(严格口径;若 jsx-production 定性为 bug 则更高)——意味着"真 bug"里大部分**不是 OHOS 做不到,而是我们还没适配到位**,是可持续的工程收敛方向;
- **平台局限是小头**——修完适配差距后,剩余局限类失败走 OPENHARMONY expectations 机制(与 social4hyq 一致的上游认可做法);
- 与 §5 路径 B 呼应:路径 B 的 ~340 用例与本节 A 档(~324)量级一致,其中 multi-run 单点 238 用例应最先做。

---

*报告生成:2026-08-25;原始数据 `dev-tmp/result_envfix.txt` / `result_ce76c18_r2.txt` / `categorization_final.json`;CI 闭环与 BUG 性质拆分为本日补充。同日子 agent 复核后修正:§2 模块分布按 per-file 口径重算(文件数原表有误)、§4 补 OTHER 行、§6 A 档剔除 jsx-production(350/69% → 324/64%)、§5 multi-run 数字注明轮次口径。*

