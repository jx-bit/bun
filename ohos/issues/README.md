# OHOS Issues 索引（按关联 PR 编号，全量覆盖）

> 本目录是 OHOS 适配问题文档的唯一存放地（原 `analys/issues/`，2026-09-05 迁入）。
> **命名规范**：`pr<N>-p<优先级>-<关键词>.md` —— `N` = 对应 PR 序号，**文件名
> 编号必须与索引行的 PR 号一致**。**只为 ohos-aarch64 交付线上的 PR 立档**
> （merge commit 可达 origin/ohos-aarch64，或 OPEN 且 base=ohos-aarch64）；
> dev 侧中间 PR、未合并/撤回的 PR 不立档 —— 内容并入对应交付 PR 文档
> （2026-09-08 清理：pr18/pr19/pr25 文档删除，内容并入 pr21/pr26 文档）。
> 每个文档头部有对应 PR 的链接；PR 侧不需要反向链接（PR 描述由 06-create-pr 生成）。
> 优先级含义：P0 阻断构建 / P1 测试回归 / P2 功能不完整或版本操作 / P3 不阻断。

## 全量覆盖表（PR #1 → #67）

| PR | 文档 | 一句话 | 状态 |
|---|---|---|---|
| [#1](https://github.com/jx-bit/bun/pull/1) | [pr1-p0-symbols-dyn-trimming.md](pr1-p0-symbols-dyn-trimming.md) | 拆分 OHOS version-script（#13 静态 libunwind 后残余消失） | ✅ |
| [#2](https://github.com/jx-bit/bun/pull/2) | [pr2-p2-v140-merge.md](pr2-p2-v140-merge.md) | v1.4.0 合入 ohos-aarch64（基线） | ✅ |
| [#3](https://github.com/jx-bit/bun/pull/3) | [pr3-p3-three-way-merge-build-trigger.md](pr3-p3-three-way-merge-build-trigger.md) | 4 文件 3-way 合回 + PR 触发 OHOS 构建 | ✅ |
| [#4](https://github.com/jx-bit/bun/pull/4) | [pr6-p2-linker-lds-shim-symbols-incomplete.md](pr6-p2-linker-lds-shim-symbols-incomplete.md)（前置）· [pr8-p3-source-lints.md](pr8-p3-source-lints.md)（引入 lint 漂移） | 符号导出对齐 | ✅ |
| [#5](https://github.com/jx-bit/bun/pull/5) | [pr5-p1-highway-sve-disabling.md](pr5-p1-highway-sve-disabling.md) | 移除 SVE 禁用，恢复 32 用例 | ✅ |
| [#6](https://github.com/jx-bit/bun/pull/6) | [pr6-p2-linker-lds-shim-symbols-incomplete.md](pr6-p2-linker-lds-shim-symbols-incomplete.md) | shim 符号 8→15 补全 | ✅ |
| [#7](https://github.com/jx-bit/bun/pull/7) | [pr7-p2-run-command-gates-incomplete.md](pr7-p2-run-command-gates-incomplete.md) | 补齐 5 个 OHOS gate | ✅ |
| [#8](https://github.com/jx-bit/bun/pull/8) | [pr8-p3-source-lints.md](pr8-p3-source-lints.md) · [pr8-p3-mordant-tuple-wants-struct.md](pr8-p3-mordant-tuple-wants-struct.md) | lint 基线同步 + mordant | ✅ |
| [#9](https://github.com/jx-bit/bun/pull/9) | [pr9-p3-parse-header-refactor.md](pr9-p3-parse-header-refactor.md) | parse_header → SectionHeaderTable 重构 | ✅ |
| [#10](https://github.com/jx-bit/bun/pull/10) | [pr10-p1-epolloneshot-disabling.md](pr10-p1-epolloneshot-disabling.md) | 恢复 EPOLLONESHOT 一次性注册 | ✅ |
| [#11](https://github.com/jx-bit/bun/pull/11) | [pr12-p1-test-tree-upstream-restore-and-reconcile.md](pr12-p1-test-tree-upstream-restore-and-reconcile.md) | 恢复上游 v1.4.0 测试树（129 文件） | ✅ |
| [#12](https://github.com/jx-bit/bun/pull/12) | [pr12-p1-test-tree-upstream-restore-and-reconcile.md](pr12-p1-test-tree-upstream-restore-and-reconcile.md) | 测试树与 v1.4.0 线对账 | ✅ |
| [#13](https://github.com/jx-bit/bun/pull/13) | [pr13-p1-ohos-fulltest-lane-unblock.md](pr13-p1-ohos-fulltest-lane-unblock.md) | 解锁 fulltest 通道（+ 静态 libunwind） | ✅ |
| [#14](https://github.com/jx-bit/bun/pull/14) | [pr14-p1-codesign-stub-inheritance.md](pr14-p1-codesign-stub-inheritance.md) | codesign 校验 + compile strip 重签 | ✅；设备复测待 fulltest |
| [#15](https://github.com/jx-bit/bun/pull/15) | [pr15-p1-dlopen-libc-path-openharmony.md](pr15-p1-dlopen-libc-path-openharmony.md) | dlopen musl loader 显式路径 | ✅ 真机验证 |
| [#16](https://github.com/jx-bit/bun/pull/16) | [pr14-p1-codesign-stub-inheritance.md](pr14-p1-codesign-stub-inheritance.md) §8 | 懒模式 codesign repair（性能后续） | ✅ |
| [#17](https://github.com/jx-bit/bun/pull/17) | [pr17-p3-shebang-expansion.md](pr17-p3-shebang-expansion.md) | 用户态 shebang 展开 | ✅ |
| [#18](https://github.com/jx-bit/bun/pull/18) | （无文档——PR 未合并，原方案文档已清理；幸存设计见 [pr21-p2-container-lanes-bringup.md](pr21-p2-container-lanes-bringup.md)） | CI 容器 fulltest 通道 | ❌ 关闭（方向调整撤回，文件保留在 dev 历史） |
| [#19](https://github.com/jx-bit/bun/pull/19) | （无文档——被 #21 取代，原文档已清理） | ❌ 关闭（被 #21 取代——同修复并入 lane bring-up commit） |
| [#20](https://github.com/jx-bit/bun/pull/20) | （native 设备构建通道——方向调整撤回，机制对比见 knowledge/ci-comparison-springmin.md） | ❌ 关闭 |
| [#21](https://github.com/jx-bit/bun/pull/21) | [pr21-p2-container-lanes-bringup.md](pr21-p2-container-lanes-bringup.md)（触发器 / --parallel / vendor 容错 / brew 漂移 / openharmony） | ✅ 合并（32053f6272） |
| [#22](https://github.com/jx-bit/bun/pull/22) | [pr22-p1-shebang-arg-dangling.md](pr22-p1-shebang-arg-dangling.md)（shebang 可选参数 CString 悬垂） | ✅ 合并（cc9e14c5fb，dev→ohos-aarch64 交付） |
| [#23](https://github.com/jx-bit/bun/pull/23) | [pr23-p3-container-env-align.md](pr23-p3-container-env-align.md)（llvm@21 PATH / OHOS_SYSROOT / dlopen 路径） | ✅ 合并（268fc966f1） |
| [#24](https://github.com/jx-bit/bun/pull/24) | [pr24-p2-gethomedir-import-alias.md](pr24-p2-gethomedir-import-alias.md)（getHomedir 导入别名） | ✅ 合并（ff908e9bbc，dev→ohos-aarch64 交付） |
| [#25](https://github.com/jx-bit/bun/pull/25) | （无独立文档——内容并入 [pr26 文档](pr26-p2-runner-env-device-lane.md)） | ✅ 合并进 dev 后被重整孤立，经 #26 送达 |
| [#26](https://github.com/jx-bit/bun/pull/26) | [pr26-p2-runner-env-device-lane.md](pr26-p2-runner-env-device-lane.md)（NODE_TEST_DIR 短路径 tmpdir + 外层 wall-clock ×3，含 #25 全部内容） | ✅ 合并（46a905a6cf，单 commit 296f566685） |
| [#27](https://github.com/jx-bit/bun/pull/27) | [pr27-p2-device-lane-env-compat.md](pr27-p2-device-lane-env-compat.md)（AF_UNIX capable tmpdir 探测 + wasi `/` preopen 探测；open 桶 24 文件审计见其 §5） | ✅ 合并（7a29e13314，单 commit fed363c7b5） |
| [#28](https://github.com/jx-bit/bun/pull/28) | [pr28-p1-browser-field-entry-panic.md](pr28-p1-browser-field-entry-panic.md)（browser-field 禁用入口 panic——20260908 两处 SIGABRT 根因） | ✅ 合并（106630a089，单 commit ffa13fe522） |
| [#29](https://github.com/jx-bit/bun/pull/29) | [pr29-p1-process-platform-openharmony.md](pr29-p1-process-platform-openharmony.md)（process.platform 误报 "linux"——isOHOS 门控全失效的 P0 根因） | ✅ 合并（c4323a5d33，单 commit ff4f267b86） |
| [#30](https://github.com/jx-bit/bun/pull/30) | [pr30-p1-process-platform-cpp-getter-and-bundled-inlining.md](pr30-p1-process-platform-cpp-getter-and-bundled-inlining.md)（#29 后续——JS 可见层漏修：C++ `constructPlatform` getter + bundle 期 `TARGET_PLATFORM` 内联，含 `os.type()` codegen 硬前提与 net.ts 内核语义门控；pr29 文档 §7 有后续小节） | ✅ 合并（62960fd817，单 commit 0c32a69fd8） |
| [#31](https://github.com/jx-bit/bun/pull/31) | [pr31-p1-bun-node-dir-app-tmp.md](pr31-p1-bun-node-dir-app-tmp.md)（bun-node shim 落在不可写的 /tmp——as-node 11 用例根因；**指南 F3 归因修正**：真实修复在 install/lib.rs BUN_NODE_DIR，非 which/lib.rs） | ✅ 合并（f898edf035，单 commit d8f8db5547） |
| [#32](https://github.com/jx-bit/bun/pull/32) | [pr32-p0-epoll-pipe-capture.md](pr32-p0-epoll-pipe-capture.md)（F1 管道输出丢失——OHOS epoll CTL_DEL dup 孤立 bug + rearm 看门狗 + sync wait；**指南 F1 归因修正**：真实修复面在 src/io/ 非 process.rs RefPtr/multi_run，以 A 轮 61dbc3a9d 同基线锚定） | ✅ 合并（0e0fd1559，单 commit 7f99b314fd） |
| [#33](https://github.com/jx-bit/bun/pull/33) | [pr33-p3-ci-pr-trigger-dedupe.md](pr33-p3-ci-pr-trigger-dedupe.md)（PR 构建 CI 双跑——push/pull_request 触发器重叠 + 并发组 ref 不匹配；push 触发器删 claude/ohos-*） | ✅ 合并（dec28e0278，单 commit 0bc299e9ad） |
| [#34](https://github.com/jx-bit/bun/pull/34) | [pr34-p0-pipe-capture-wave2.md](pr34-p0-pipe-capture-wave2.md)（管道捕获 wave-2——0e0fd1559 实测后剩余 F1 面：memfd→socketpair / waiter-thread OHOS 默认 / close_range 直呼 / 绑定层 $PWD 同步，4 文件逐字节 = A） | ✅ 合并（14fdf0d566） |
| [#35](https://github.com/jx-bit/bun/pull/35) | [pr35-p0-ci-container-gate-align.md](pr35-p0-ci-container-gate-align.md)（CI 容器门禁对齐上游 tap 重构——0912 bun.rb 删除 ohos-sdk 直接依赖致验证循环全 PR 必红；sdk 名动态解析 + pipefail 修复死代码重试 + lld@21 tap 前缀） | ✅ 合并（749687de00） |
| [#36](https://github.com/jx-bit/bun/pull/36) | [pr36-p3-ai-entry-ohos-pointer.md](pr36-p3-ai-entry-ohos-pointer.md)（AI 入口断层——AGENTS/CLAUDE 增 OHOS 交付线一节，任何 AI 落库首读即达台账与方法论；AGENTS.md 为 CLAUDE.md 符号链接，一处编辑双入口生效） | ❌ 关闭（2026-09-14 撤回未合并；重送见 [#47](https://github.com/jx-bit/bun/pull/47) 行） |
| [#37](https://github.com/jx-bit/bun/pull/37) | [pr37-p1-usockets-epoll-pwait2-readfile-race.md](pr37-p1-usockets-epoll-pwait2-readfile-race.md)（uSockets 强制禁用 epoll_pwait2(441) 修 inspector WS 1006 + ReadFile 读循环竞态串行化修 stdin 大读随机截断；2 文件 +166/−5 逐字节 = A） | ✅ 合并（c2459c8442） |
| [#38](https://github.com/jx-bit/bun/pull/38) | [pr38-p3-fulltest-layout.md](pr38-p3-fulltest-layout.md)（fulltest 工具归位——install-bun-ohos.sh 移入 + junit 脚本入库 + README 索引补全；配合 ohos/ 目录整理） | ✅ 合并（939cb72c30） |
| [#39](https://github.com/jx-bit/bun/pull/39) | [pr39-p2-waiter-thread-prewarm.md](pr39-p2-waiter-thread-prewarm.md)（waiter 线程 OHOS 预热——eventfd 惰性创建被 fd 快照测试计为泄漏；spawn-streaming-stdin 转绿） | ✅ 合并（f01b1a3f15） |
| [#40](https://github.com/jx-bit/bun/pull/40) | [pr40-p1-dns-system-backend-ipv4.md](pr40-p1-dns-system-backend-ipv4.md)（DNS 双栈超时——OHOS 无全局 IPv6 强制 Inet + backend 改 System 走 netsys IPC；node-dns 两连挂的根因） | ✅ 合并（5bbb4306d8） |
| [#41](https://github.com/jx-bit/bun/pull/41) | [pr41-p0-rwf-espipe-fallback.md](pr41-p0-rwf-espipe-fallback.md)（P0——pwritev2/preadv2 管道 ESPIPE 未降级致 shell 非 quiet 输出全灭 65507；探针实验实证，降级集合补 ESPIPE，~250 用例回补） | ✅ 合并（541794f8d1） |
| [#42](https://github.com/jx-bit/bun/pull/42) | [pr42-p1-cwd-rlimit-tmpdir-hardening.md](pr42-p1-cwd-rlimit-tmpdir-hardening.md)（cwd/rlimit/tmpdir/可执行检查 OHOS 加固——BUG-01 删除 cwd 诚实传播、rlimit 256 跌落回退、tmpdir 运行时探测、is_executable_file X_OK；3 文件 +156/−62 逐字节 = A） | ✅ 合并（c7eda0b873） |
| [#43](https://github.com/jx-bit/bun/pull/43) | [pr43-p1-openat2-ohos-gate.md](pr43-p1-openat2-ohos-gate.md)（P1——openat2_in_root 缺 OHOS 门控致目录路由全 404（F2）；两 fn 统一 A 结构，ENOSYS→包装器缓存回退） | ✅ 合并（3ac1bc4d89） |
| [#44](https://github.com/jx-bit/bun/pull/44) | [pr44-p1-operating-system-openharmony-match.md](pr44-p1-operating-system-openharmony-match.md)（OperatingSystem 枚举缺 OPENHARMONY——os 匹配对自身平台返回 false；architecture-match 4 用例根因） | ✅ 合并（5613067cf0） |
| [#45](https://github.com/jx-bit/bun/pull/45) | [pr45-p0-ohos-sdk-sysroot-probe.md](pr45-p0-ohos-sdk-sysroot-probe.md)（P0——tap 公式更名 ohos-sdk-native 致 sysroot 布局漂移、容器构建全阻；sysroot 布局探测链 + keg 自诊断） | ✅ 合并（5e69b884ef） |
| [#46](https://github.com/jx-bit/bun/pull/46) | [pr46-p0-core-tap-pin-sysroot-contract.md](pr46-p0-core-tap-pin-sysroot-contract.md)（P0——pr45 热修后的治本：core tap（harmonybrew/homebrew-core @ atomgit，llvm@21/ohos-sdk 真身）锁定 OHOS_CORE_PIN=5380be4e、构建 lane 与 canary 双侧 sysroot 契约断言、canary 保持浮动验收新 tip 并打印 bump SHA；断裂点溯源 39a060948） | ✅ 合并（163cabaa7b） |
| [#47](https://github.com/jx-bit/bun/pull/47) | [pr47-p3-ai-entry-readme.md](pr47-p3-ai-entry-readme.md)（P3——#36 重送：AGENTS/CLAUDE 一句话指针 + ohos/README.md 首批入库（去即时状态/去日期绑定/去悬空链接）；check-pr.sh 3b/3c 改白名单制） | ✅ 合并（0eafc2a105） |
| [#49](https://github.com/jx-bit/bun/pull/49) | [pr49-p1-terminal-pty-data-callback.md](pr49-p1-terminal-pty-data-callback.md)（P1——Bun.Terminal PTY data 回调永不触发/exit 启动期丢失，26286 设备 TIMEOUT 根因；看门狗接线半行缺失——#32 基建落库但全树无登记生产点，本 PR 补 Terminal 侧 EPOLL_REARM_WATCH 登记 + reader 末位启动/deferred_exit 重放 + openpty libc.so/RTLD_DEFAULT；#39/#37/#43 家族第四例，同基线 61dbc3a9d 逐字移植——参照线非官方，仅形态候选+验证锚点，见文档 §0） | ✅ 合并（3238ce0da1） |
| [#50](https://github.com/jx-bit/bun/pull/50) | [pr50-p1-npm-manifest-cache-otmpfile.md](pr50-p1-npm-manifest-cache-otmpfile.md)（P1——manifest 缓存写 O_TMPFILE attempt-#3 兜底被 Rust 重写窗口丢失；OHOS 沙箱 linkat EPERM 下缓存条目必丢、registry 重复请求；isolated-install/bun-lock 排除法命中，与 61dbc3a9d 逐字节恢复；ConnectionRefused 主因另见 20260921-remaining-issues §10.3 探针） | ✅ 合并（b957b11af3） |
| [#51](https://github.com/jx-bit/bun/pull/51) | [pr51-p1-test-runner-reference-defaults.md](pr51-p1-test-runner-reference-defaults.md)（P1——bun test 默认超时 30s 门（ASan 时代产物）偏离上游 5000ms 文档契约 + Arguments 丢失 getcwd_honest（上游 merge 冲掉 pr42 BUG-01）；两处与 61dbc3a9d 逐字节恢复；R8 第三成员归因产出；含 Cargo.lock 归位——2026-09-21 起允许随交付 PR 携带，守卫 3b 已同步） | ✅ 合并（ee8ebba8bd） |
| [#64](https://github.com/jx-bit/bun/pull/64) | [pr64-p1-cross-gate-pch.md](pr64-p1-cross-gate-pch.md)（P1——CI full mode 跳过 PCH 的旧假设被 1.4.0 门禁 cross 通道打破：`--ci=true`+full 无 PCH 编译，BunClientData.h（零 include 头）JSC 声明缺失 → linux-x64/darwin leg 全挂；`usePch = true` 无条件启用，windows/darwin 缓存用途的 cfg.ci 不动） | ✅ 合并（26713cbbe7） |
| [#66](https://github.com/jx-bit/bun/pull/66) | [pr66-p2-release-latest-assemble.md](pr66-p2-release-latest-assemble.md)（P2——五平台滚动 latest 装配：OHOS 容器构建成功后 workflow_run 链 cross 四 leg（同 SHA，workflow_call+sha 输入），汇集发布 latest（body 标注基线 SHA）；cross-x86 增 workflow_call 触发 + linux-arm64 leg（原生构建补第五产品）；**#72 并行化重构**：五产品同 push 并行构建、publish 同 run 收集、assemble 删除） | ✅ 合并（93306b095d）；**#72 并行重构 OPEN**（见 pr66 §6） |
| [#67](https://github.com/jx-bit/bun/pull/67) | [pr67-p2-install-script-release.md](pr67-p2-install-script-release.md)（P2——install-bun-ohos.sh 发布闭环：脚本 REPO 硬编码他库（装到的会是别人的 binary）+ ohos-release.yml 引用不存在的路径（\|\| true 静默丢第三件套）+ ohos-latest 无脚本资产三坑齐修；默认变体翻 github（每 merge 必发布的通道）；ohos-latest 发布加 PR 门禁守卫） | ✅ 合并（4e6158a9d9）；#68 配对修复 ✅（见 pr67 §5）；#76 SHASUMS256 校验链 ❌ 关闭未合并（见 pr67 §6）；**#77 配对门禁 OPEN**（tag 脚本默认构建错变体 + 滚动脚本被 tag 版覆盖 + 发布后零验证 + latest 跨 release 依赖 + 触发器只认 ohos-v*；任意 tag 自包含契约 + 发布后验证门禁，见 pr67 §7） |
| [#52](https://github.com/jx-bit/bun/pull/52) | [pr52-p2-node-userinfo-preload.md](pr52-p2-node-userinfo-preload.md)（P2——exec 出的 node 子进程 os.userInfo() ENOENT（沙箱 uid 无 /etc/passwd，子进程不带内嵌 shim）；NODE_OPTIONS --require 内容哈希 preload 注入 + BUN_OHOS_USERNAME，双 spawn 路径接线，probe-then-fallback 对健康环境严格 no-op；默认值对比产出，取参照 tip 终版 + 4 处 getenv_z/errno 适配） | ✅ 合并（ea2faf93de） |
| [#53](https://github.com/jx-bit/bun/pull/53) | [pr53-p2-os-machine-aarch64.md](pr53-p2-os-machine-aarch64.md)（P2——os.machine() 在 OHOS 误报 "arm64" 应为 "aarch64"（uname 语义），machine() 平台特判追加 openharmony 一行；同批 IS_MUSL/IS_OHOS 3 消费点扫描结论与待决策项（升级资产命名/Libc::Ohos）见其文档 §5） | ✅ 合并（486aeecba2） |
| [#54](https://github.com/jx-bit/bun/pull/54) | [pr54-p2-is-ohos-libc-detection.md](pr54-p2-is-ohos-libc-detection.md)（P2——libc 判定缺失三处错误：upgrade 空后缀拉 glibc 包变砖、--compile 元数据标签错、NAPI glibc 预检设备被跳过；IS_MUSL 加宽含 ohos + IS_OHOS/IS_GLIBC 常量 + SUFFIX_ABI 首位 `-ohos` + Libc::Ohos 变体；**拍板记录：-ohos 后缀，upgrade 404 优于变砖**，分发闭环另立专项；参照线 file:// 与 is_host_platform 有意不取） | ✅ 合并（6ba99e7085） |
| [#55](https://github.com/jx-bit/bun/pull/55) | [pr55-p2-test-safety-net.md](pr55-p2-test-safety-net.md)（P2——测试补网：#52/#53/#54 漏网复盘三机制（membership 松断言 / device-only skip 静音 / 常量无守护）→ skipIf-isOHOS 台账 lint（13 文件 17 位点全登记，device-only 条目记录解锁条件）+ libc 判定守卫 lint（#54 承重点全钉）+ 设备语义精确值测试 os-ohos.test.ts；source-lints.yml paths 补测试树 glob；**已 rebase 到 #52/#53/#54 合并后 tip，lint 全绿**；设备操作指导见 knowledge/device-test-guide.md） | ✅ 合并（f21748c2e9） |
| [#56](https://github.com/jx-bit/bun/pull/56) | [pr56-p0-windows-build-cfg-gates.md](pr56-p0-windows-build-cfg-gates.md)（P0——cfg-gate Linux-only pipe-writer epoll workarounds，解锁 Windows 构建） | ✅ 合并（96b1db1d0c） |
| [#57](https://github.com/jx-bit/bun/pull/57) | [pr57-p3-ohos-target-clippy-debt.md](pr57-p3-ohos-target-clippy-debt.md)（P3——ohos-target clippy 欠账第一批：spawn 路径 5 crate 11 处清零（undocumented unsafe ×6、ptr cast ×2、c 字符串、std::fs::File 迁移、from_utf8_unchecked UB 修复、多余 clone）；bun_standalone_graph 12 处结构性迁移留下一批；pr52 §6 发现项落地） | ✅ 合并（058d8e1de0） |
| [#58](https://github.com/jx-bit/bun/pull/58) | [pr58-p2-epoll-eexist-net-errno.md](pr58-p2-epoll-eexist-net-errno.md)（P2——双分支采纳分析产出：epoll CTL_ADD 撞 EEXIST 以 CTL_MOD 重发（OHOS 内核注册越过 close 存活，fd 号复用即挂死，skip-CTL_DEL 的互补半边）+ net 致命发送 errno 锁存（RST 时排队写静默丢 9.4MB 且 JS 被告知成功，A 侧设备追踪实锚）；用户影响：长跑服务器挂死 / 弱网静默丢数据；**覆盖边界**：更深的"死实例态"（ADD/MOD/DEL 皆无效）用户态不可救，A 侧 9ab94f22fbf 实验定案） | ✅ 合并（4ea39bf334） |
| [#59](https://github.com/jx-bit/bun/pull/59) | [pr59-p2-adoption-batch-2.md](pr59-p2-adoption-batch-2.md)（P2——采纳批次二：cwd_is_deleted 截断误判（>4095 字节深目录启动报"目录已删"，填满缓冲=不可判定）+ fs.watch IN_ATTRIB 打标抑制（同批前瞻 16 事件 + 跨读边界 2ms poll，ATTR→CRE 内核打标模式，建文件首事件恢复 rename）+ process.getgroups 含 egid（Node 语义）；采纳分析候选 #1/#4/#5） | ✅ 合并（586d8a1784） |
| [#60](https://github.com/jx-bit/bun/pull/60) | [pr60-p3-standalone-graph-clippy.md](pr60-p3-standalone-graph-clippy.md)（P3——ohos-target clippy 第二批：StandaloneModuleGraph 12 错清零（read_to_string/lines/split/File ×4/undocumented unsafe ×3/ptr cast ×2 → 字节级 maps 解析 + openat_a/File::from_fd/pread 迁移）；顺带修复非 UTF-8 maps 路径致 PIE 检测静默失效；**剩余 bun_install 7 错为第三批**（env::var→getenv_z 需逐位点语义分析）） | ✅ 合并（5d8820bcdc） |
| [#61](https://github.com/jx-bit/bun/pull/61) | [pr61-p2-link-linkat-routing.md](pr61-p2-link-linkat-routing.md)（P2——fs.linkSync 裸 libc::link 在设备全路径 EPERM（沙箱禁 link(2)，musl link() 裸 syscall 绕过 shim 拦的 linkat 符号）；OHOS 门控改走 linkat(AT_FDCWD) 触发 shim 原子拷贝回退；安装后端本已路由，fs.linkSync 为最后一个裸调用点；**指南 §6.1 交叉核对发现**） | ✅ 合并（fd344a6ff0） |
| [#62](https://github.com/jx-bit/bun/pull/62) | [pr62-p3-bun-install-clippy.md](pr62-p3-bun-install-clippy.md)（P3——ohos-target clippy 第三批：bun_install 7 错清零（env::var ×6 → getenv_z 字节直传 + from_utf8_unchecked UB → OsStr）；**第四批已枚举**：bun_runtime 自身 OHOS 门控 7 错（run_command env::var、ohos_node_userinfo ×3、dns ×3），见 pr62 文档 §4） | ✅ 合并（5d8820bcdc） |
| [#63](https://github.com/jx-bit/bun/pull/63) | [pr63-p3-runtime-clippy-final.md](pr63-p3-runtime-clippy-final.md)（P3——ohos-target clippy 第四批(末批)：bun_runtime 自身 7 错清零（HOME 类型化访问器、getpwuid_r SAFETY、is_managed_key unsafe 形式化、has_global_ipv6 SAFETY ×3）；**里程碑：ohos-target clippy 全链路首次全绿**（四批共 37 处）；防再发建议：CI 增 ohos-target clippy lane） | ✅ 合并（fd344a6ff0） |
| [#65](https://github.com/jx-bit/bun/pull/65) | [pr65-p3-ci-ohos-clippy-lane.md](pr65-p3-ci-ohos-clippy-lane.md)（P3——CI 增 ohos-target clippy lane（rust-lints.yml 新 job：rustup target add ohos + clippy -p bun_runtime，工作区 lint 自动 deny）——堵三车道盲区的防再发机制，起点即绿；pr63 §5 建议落地） | 🔄 OPEN |
| [#56](https://github.com/jx-bit/bun/pull/56) | [pr56-p0-windows-build-cfg-gates.md](pr56-p0-windows-build-cfg-gates.md)（P0——#32/#37 无门控平台代码阻断 windows-x64 构建（09-21 run 35611960605 两 E0308 + 被挡住的 read_loop_state 死码）；三处 cfg 门（PipeWriter×2 循官方 linux/android 谓词、read_file 循相邻字段 not(windows)），门内代码不动，Linux/OHOS 逐 token 一致；4 目标 cargo check + release 口径全绿；claude-find-issues 挂为仓级缺 secret 与本 PR 无关） | 🔄 OPEN |

## 无 PR 的分析 / 追踪文档

| 文档 | 性质 | 状态 |
|---|---|---|
| [p2-v140-regression-candidates.md](p2-v140-regression-candidates.md) | 追踪清单（v1.4.0 疑似回归候选） | 持续跟踪 |
| [../knowledge/test-tree-changes-vs-v1-4-0.md](../knowledge/test-tree-changes-vs-v1-4-0.md) | **测试树改动台账**（121 文件逐条机制详解 + 28 处参数适配清单 + skip 健康度） | 2026-09-09 建立 |
| [../knowledge/OHOS_TEST_STATUS.md](../knowledge/OHOS_TEST_STATUS.md) | 设备侧台账归档（social4hyq tip 619KB，T 编号 + C 探针证据） | 2026-09-09 归档 |
| [../knowledge/OHOS_TEST_STATUS.md](../knowledge/OHOS_TEST_STATUS.md) | 设备侧台账归档（social4hyq tip 619KB，T 编号 + C 探针证据；**OHOS_TEST_TODO.md 已删除**——内容早已并入 STATUS，2026-09-11 清理） | 2026-09-09 归档 |
| [../analys/next-fulltest-acceptance-checklist.md](../analys/next-fulltest-acceptance-checklist.md) | 下一轮 fulltest 验收清单（预期转绿项/观察项） | 2026-09-09 建立 |
| [../analys/20260911-jxbit-only-55-attribution.md](../analys/20260911-jxbit-only-55-attribution.md) | B-only 101→34 簇归因（F1 范围修正 ~20 文件、structured-clone 上游窗口 cherry-pick 候选、regression 10 项排除法、散布逐项方向） | 2026-09-11 建立 |

## 与代码的守护关联

PR #16/#17 在 `test/internal/source-lints/ohos-sign-call-sites.test.ts` 钉住了
签名与 shebang 的全部调用点；PR #30 在
`test/internal/source-lints/ohos-platform-reporting.test.ts` 钉住了 process.platform
三处来源（C++ getter 分支顺序 / codegenTarget 映射 / create-hash-table 归一化）
与配套门控——相关 issue（pr29/pr30）的修复不会被上游 merge 静默丢失，丢失时
对应 lint 直接红。

## 新增 issue 的操作要点

1. 修复落地提 PR 时同步建本文档：`pr<PR号>-p<优先级>-<关键词>.md`，头部带 PR 链接；**PR 描述/commit 不得引用本目录及任何 ohos/ 下文件路径**（工作区不入 git，公开 PR 里出现即指向不存在的文件），工作记录只进本文档；**PR 标题/描述/commit message 一律英文**
2. 同问题的后续 PR 不另立文档 —— 在主文档加 §后续小节，索引表该行追加 PR 号
3. 在本索引"全量覆盖表"插入对应行（保持 PR 号排序）
4. **一个 PR 一个 commit**：feature PR 提交前先过格式化（防 autofix.ci 追加
   commit）；交付 PR（dev → ohos-aarch64）用重整后的单 commit —— 先
   `git branch -f <tmp> <ohos-aarch64-tip>`、checkout 目标文件、单 commit、
   `--force-with-lease` 推 dev（先例：#24、#26）
5. **修复区域在 social4hyq 有对应实现的，文档必须有"与 social4hyq 实现的对比"
   章节**（先例：pr28 §3、pr29 §3、pr30 §3）——结论先行 + 逐项对照表 + 溯源 +
   暴露差异；每项标注证据类型（〔源码〕逐字核验 / 〔实测〕binary 行为 /
   〔推断〕机制反推）。注意与 06-create-pr 的反向规矩区分：fork 名只进本文档，
   **不进公开 PR**
6. **文档必须含「用户影响速览」**：每个缺陷一行的四要素表——用户在做什么
   （触发场景）/ 感知症状（具体表现，禁止只写内部机制）/ 频率 / 严重度；
   正文各小节展开同结构。**"修了什么"不等于"用户感知到什么变化"**——根因
   是给工程师的，用户影响是给排优先级和验收的人的，两者缺一不可
   （先例：pr59 §1 速览表）。PR body 至少携带一行每缺陷的用户可感描述

---

*索引维护：Sisyphus | 2026-09-05 迁移建立 | 同日按 GitHub 实际清单校正归属（#1/#5/#6/#7）并补齐 #2/#3/#9/#17 简单记录 | 2026-09-08 增补 #22-#25；#24/#25 合并状态校正 + #26 交付 PR（dev 回退事件见 pr25 文档头部）| 同日按 ohos-aarch64 交付线口径清理：删 pr18/pr19/pr25 文档（内容并入 pr21/pr26），#22 状态修正为已合并，确立"只为交付线 PR 立档"规范 | 同日 #26 合并、#27 设备环境兼容修复（open 桶审计）| 2026-09-09 增补 #28/#29（20260908 轮 jxbit_only 分析产出：browser-field panic + process.platform 误报）| 2026-09-10 增补 #30（confirm-jxbit-rebuild 复跑产出：#29 修复未达 JS 可见层，C++ getter + bundle 内联补修；pr29 文档追加 §7 后续）| 同日 #30 合并（62960fd817）——JS 可见层 platform 修复送达交付线，pr29 §5 设备复验预期可达 | 2026-09-10 增补 #31（jxbit-fix-guide F3：bun-node shim 迁入 OHOS 沙箱 tmp；指南归因修正——which/lib.rs 190 行 diff 全为 windows cfg）| 同日 #31 合并（f898edf035）| 2026-09-11 增补 #32（F1 管道捕获：epoll CTL_DEL dup bug 等 9 文件移植；确立"同基线树锚定 port"方法论）| 同日 增补 #33（CI 双跑修复：push 触发器删 claude/ohos-*，PR 构建砍半）| 同日 #33 合并（dec28e0278）——此后 PR 构建 2 run/push | 2026-09-11/14：#32 合并（0e0fd1559）+ 复跑 101→39 验证修复效果，wave2/#34 与 #35 跟进 | 2026-09-14 增补 #36（AI 入口断层：AGENTS/CLAUDE 增 OHOS 交付线节，落库首读即达台账）| 同日 清理 ohos/（134→64MB：TODO 归档/findings 并入/参考二进制）+ 三级导航 README + 文件整合归档 | 同日 #34 合并（14fdf0d566）——wave2 收复 13 文件（structured-clone ×2/html-rewriter/console-iterator 等），独有失败 39→31，新增 6 回归候选待排查 | 2026-09-14 增补 #38（fulltest 工具归位 + junit 脚本入库；#37 为并行会话的 uSockets/stdin 修复）| 2026-09-17 增补 #45（0916 tap 公式更名 ohos-sdk-native 致 sysroot 缺失全 PR 必红；探测链热修）+ #46（治本：core tap 锁 pin + sysroot 契约断言；漂移源修正——真身在 harmonybrew/homebrew-core @ atomgit 非 social4hyq/core，断裂点 39a060948，pin=其父 5380be4e）| 同日 #44/#45 合并状态校正（5613067cf0 / 5e69b884ef）| 同日 #46 合并（163cabaa7b）——core tap 锁 pin + sysroot 契约落库，容器构建全绿实证 | 同日台账对账：#34/#35/#37/#38 OPEN 行校正为实际已合并（14fdf0d566/749687de00/c2459c8442/939cb72c30）、#36 确认关闭未合并（内容待重送）、清理 #39-#42 重复行，PR #34-#46 行序归位 | 同日 原撤回的 AI 入口指针以 #47 重送（指针精简一句 + README 首批入库，守卫脚本 3b/3c 改白名单制）——初记于 pr36 §5，同日改为独立立档 pr47-p3-ai-entry-readme.md（全量覆盖口径：每 PR 一行一档），#36 行回归关闭态 | 同日 #47 合并（0eafc2a105）——AI 入口落库生效，行转 ✅；分支清理 * | 2026-09-21 增补 #49（Terminal PTY data/exit 交付——26286 设备 TIMEOUT 根因：内核 epoll 对 PTY master 不交付事件，reader 启动时序烧掉 one-shot exit 通知，openpty 解析缺 libc.so；三 patch 自同基线 61dbc3a9d 逐字移植 + 本仓 lint 适配，#39/#37/#43 家族第四例）；#48 行由并行会话补记（pr48-p0 文档已在目录） | 同日 #49 合并状态校正（3238ce0da1）+ 增补 #50（npm.rs attempt-#3 恢复，R8 归因产出）| 同日 #50 合并（b957b11af3）| 同日 增补 #51（test runner 参考默认恢复：30s 超时门退场 + honest-cwd 回归，R8 第三成员归因产出）| 2026-09-22 增补 #56（P0 Windows 构建阻断：#32/#37 平台专属代码无 cfg 门三处（PipeWriter unregister/storm 块 + read_file read_loop_state 字段），循官方 linux/android 谓词与相邻字段 not(windows) 补门，4 目标交叉验证 + windows release 口径；参考线同样无门但无 Windows 通道系其盲区，见 pr56 文档 §5） * | 同日 增补 #52/#53/#54（默认值语义对比产出：node 子进程 os.userInfo preload、os.machine aarch64、IS_OHOS libc 判定 + `-ohos` 拍板；#54 §5 记录决策过程与参照线 bottle 实证）+ #55（测试补网：skipIf-isOHOS 台账 lint 17 位点、libc 判定守卫、设备语义精确值断言；source-lints.yml paths 补测试树 glob）——#52/#53/#54/#55 同日全合并（ea2faf93de/486aeecba2/6ba99e7085/f21748c2e9），文档/索引状态同步 ✅ | 同日 增补 #57（ohos-target clippy 欠账第一批：spawn 路径 5 crate 11 处，含 from_utf8_unchecked UB 修复；按 lint 类改标 P3） | 2026-09-23 增补 #77 立档（pr67 §7 后续：发布配对双向错配——tag 脚本默认构建指向不存在变体 + 滚动脚本被 tag 注入版覆盖，补发布后验证门禁；#76 状态校正 OPEN→❌ 关闭未合并） *
