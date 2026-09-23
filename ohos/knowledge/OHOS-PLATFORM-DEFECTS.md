# 鸿蒙平台缺陷与限制清单(OHOS Platform Defects & Limitations)

> **定位**:HongMeng 内核 / OHOS 沙箱 / 系统文件系统层"与标准 Linux 行为不同"
> 的缺陷与限制的**唯一权威归档**。修复、移植、验收前先查本清单,避免重复探雷。
>
> **收录标准**:系统层行为差异,且已被**裸 inotify/syscall 探针**或**真机 A/B**
> 实证——"疑似"不收录(那些进 `OHOS_TEST_STATUS.md` 台账,实证后收编本清单
> 并给稳定 ID)。
>
> **条目字段**:现象 / 证据等级 / 影响的 API 面 / 用户态对策(实现位置)/ 状态
> (已绕过 · 内核待修 · 不可救)。来源标注:A 侧发现(参照线先行)/ 我方发现。
>
> **与其它文档的关系**:`OHOS_TEST_STATUS.md` 是按时间线的完整台账(证据全文);
> 本清单是按子系统的**结论视图**。skip 台账
> (`test/internal/source-lints/ohos-skip-inventory.json`)里的"known-OHOS-class"
> 条目应能对应到本清单的 ID。

## epoll / 事件循环

### EP-1 EPOLLONESHOT 不自动解除
- **现象**:oneshot 注册触发后内核不解除兴趣,依赖 oneshot 自动解除的程序 100% 忙等。
- **证据**:真机 A/B(T43,r42 装机验证)。**适合报给内核方**:解除语义未实现。
- **对策**:bun 侧 PipeWriter 显式重挂(A 侧 ca2bb787e+deb827a3b;我方
  #10 恢复一次性注册,独立实现)。
- **状态**:已绕过。影响所有 EPOLLONESHOT 用户(不限 bun)。

### EP-2 注册项越过 close 存活
- **现象**:fd 关闭后内核 epoll 注册残留;fd 号复用时新 ADD 撞 EEXIST、
  事件永不交付。
- **证据**:真机(A 侧 skip_ctl_del 引入后观察到死实例,见 EP-3)。
- **对策**:①close 紧随时跳过 CTL_DEL(A 侧 734614fd2e0,我方 #32);②
  ADD 撞 EEXIST 时以 CTL_MOD 重发(我方 #58,移植 springmin d91b7c5487)。
- **状态**:已绕过。

### EP-3 死实例态(不可救)
- **现象**:注册项进入损坏态——ADD=EEXIST、MOD=SUCCESS 但就绪投递永不
  恢复,CTL_DEL 返回 EEXIST 无法移除。epoll_ctl(ADD/MOD/DEL 任何组合)
  均不可救;watchdog 的 MOD 兜底对"晚到态"有效、对此态结构性无效。
- **证据**:A 侧 2026-08-20/21 两轮 CI 构建 + 真机 A/B(3 假设 2 证伪 1 排除,
  DEL+ADD 实验 54/54 双 EEXIST;`9ab94f22fbf`)。**适合报给内核方**。
- **对策**:无(用户态不可修)。表现 = terminal.test.ts 摇摆的"死实例"分支。
- **状态**:**内核待修**。残余风险与参照线一致。

### EP-4 晚到态(watchdog 可救但可能晚于断言窗口)
- **现象**:注册有效但投递延迟,watchdog CTL_MOD 补踢能救,救活可能晚于
  测试断言窗口(数据最终到齐,用例已判负)。
- **证据**:A 侧真机插桩(2026-08-21,与 EP-3 同轮区分定案)。
- **对策**:epoll_rearm_watchdog(#49 移植我方;`BUN_DISABLE_EPOLL_REARM_WATCHDOG`
  逃生门)。
- **状态**:已绕过。

## pipe / splice

### SP-1 splice 源 EOF 返回 EPIPE
- **现象**:splice 从已达 EOF 的源读,内核报 EPIPE 而非 0(标准语义)。
- **证据**:shim 常驻探针 `splice_eof_is_zero`(baseline 段故意失败)。
- **对策**:shim splice interposer(v0.2.1,`07500` 3/3 转绿)。
- **状态**:已绕过(LD_PRELOAD 场景);A 侧发现。

### SP-2 splice 进 pipe 不唤醒 poll/epoll waiter
- **现象**:splice 写入 pipe 后,停在 poll 的读端永不唤醒。
- **证据**:功能探针 `splice_wakes_poll_waiter`(常驻探针)。
- **对策**:shim epoll_pipe readiness repair(v0.3.0,`07500` 3/3;亦修复
  multi-run pipes)。
- **状态**:已绕过。A 侧发现。

## exec / spawn

### EX-1 hmdfs 拒绝 open("/proc/self/exe")
- **现象**:编译产物落在 hmdfs(鸿蒙分布式文件系统)时,进程 open 自身
  被拒——"读自身"的常规手法(定位内嵌载荷等)全部失效。
- **证据**:A minimal 的 get_data Err 分支注释(hmdfs 场景专设回退)。
- **对策**:我方:`ohos_pie_load_base()`(#60 迁移为字节级 maps 解析)+
  FFI vaddr 回退,不开文件纯 maps 推算 PIE base;A:同款 maps 回退。
- **状态**:已绕过。A 侧发现。

### EX-2 脚本 shebang 内核 128 字节截断 + 未签名脚本不可 exec
- **现象**:binfmt_script 只读脚本头 128 字节;长解释器路径被截断,截断
  余部仍是合法路径 → exec 出错报困惑性 EACCES。且 OHOS 内核拒绝 exec
  未签名文件、shebang 脚本本身无法签名——必须展开后直取已签名的解释器。
- **证据**:真机(两线各自实现:A 侧 8f35afccb63 将 spawn 路径读缓冲
  128→4096 并记录 122 行根因文档;我方 #17 独立实现)。
- **对策**:**两条线均有 spawn 路径用户态展开,等价实现**——A:inline 于
  spawn_process.rs(4096 缓冲 + keepalive + "短读才算行尾"解析细节);
  我方:独立 shebang.rs 模块(build_rewrite + 单测,#17,`parse_shebang`
  的短读标志与 A 等价)。
- **状态**:已绕过。~~初版误判"我方领先/A 无此对策"~~——教训:对比时
  按**行为特征**(binfmt_script/缓冲尺寸)搜索,不能只 grep 我方符号名
  (A 的实现内联且术语不同:"shebang-shim" 指此展开层,非 compat shim)。

### EX-3 execve/pthread_create EAGAIN(1.4.1 上游变更后)
- **现象**:上游 1.4.1 引入的 execve/pthread_create --wrap 在 OHOS 触发
  EAGAIN;WTF GC 暂停握手的 execve 在途窗口另有 SIGSEGV 报告(修复尝试
  后 A/B 判负并回退)。
- **证据**:A 侧真机(dlsym interposition 恢复 + 回退记录)。
- **对策**:A 侧 dlsym interposition;GC 暂停握手问题**未解**(已回退)。
- **状态**:部分绕过;GC-suspend 一项**未解**。

## 文件系统 / procfs

### FS-1 IN_ATTRIB 先于 IN_CREATE(创建打标)
- **现象**:open(O_CREAT)/mkdir 创建 inode 时内核先排队 IN_ATTRIB(安全
  打标)再 IN_CREATE——fs.watch 首事件变 "change" 而非 "rename";stock
  Linux 无此模式(裸 inotify 探针实证)。
- **证据**:裸探针 + 上游 3 用例确定性失败。
- **对策**:我方 #59 path_watcher 同批前瞻(16 事件)+ 跨读边界 2ms poll
  抑制;bundler HMR watcher 有意不动。
- **状态**:已绕过(node:fs.watch 面)。

### FS-2 deleted cwd:readlink 报 ENOENT(非 " (deleted)")
- **现象**:rmdir 掉 cwd 后,`readlink /proc/self/cwd` 返回 ENOENT 而非
  标准的 " (deleted)" 后缀——标准检测手法失效;且 readlink 填满缓冲时
  无 NUL(截断)。
- **证据**:真机(A 侧三部曲 61dbc3a9d + 我方 #59 截断保护)。
- **对策**:我方 #42/#59(`cwd_is_deleted_ohos` + getcwd 容错)。
- **状态**:已绕过。

### FS-3 statx 拒绝 socket fd(EBADF)
- **现象**:statx(2) 对 socket 支撑的 fd 返回 EBADF(标准 Linux 允许)——
  `fs.fstatSync(1)` 在 socket stdio 下(测试 runner 正是如此)必然失败。
- **证据**:真机裸 syscall 对照(statx(socket_fd)→-1/EBADF,fstat(同一
  fd)→0;A 侧 T04 深挖,四条移植线各自独立修复 = 缺陷普遍性铁证)。
- **对策**:sys::fstatx 封装内 OHOS 门控的 EBADF→fstat 回退
  (`sys/lib.rs` posix_impl)。**我方 2026-08-13 起已有**(26a2cb78151,
  原始移植期带入;ljy/springmin/A-aarch64 同日各自修复)。
- **状态**:已绕过。**注意**:A 的 ohos-minimal 重建**丢失了此修复**
  (minimal sys/lib.rs 无该回退,grep=0)——minimal ≠ aarch64 超集的
  实证之一。

### FS-7 link(2) 被沙箱整体 EPERM(需路由 linkat 才能触达 shim)
- **现象**:EL2 沙箱对 link(2) 任何路径/任何目录直接 EPERM;node_fs 的
  fs.linkSync 与安装器 hardlink backend 均用裸 `libc::link` → 全部失败;
  内嵌 shim 的 linkat interposer(原子拷贝回退)只拦 linkat 符号,看不见
  link 调用。
- **证据**:指南 §6.1("任何路径、任何目录都会失败")+ A 侧修复双 commit。
- **对策**:A 侧 e512bffe965(sys::link → linkat)+ ade348ec659(node_fs
  linkSync → linkat,"the actual fs.linkSync path")——路由后 shim 的
  原子拷贝回退接管(3f5121b 修其非原子窗口),硬链接 backend 可用。
  **我方未路由(裸 libc::link)——采纳候选**。
- **状态**:我方未修;hardlink 安装 backend 当前 EPERM(bun 是否自动降级
  copy backend 待核)。

### FS-3b(同族)statx 路径变体
- lstatx 同样受影响;A minimal 的 node_fs 用 `SUPPORTS_STATX_ON_LINUX`
  运行时门控(1.4.2 上游演进),与 aarch64 的 EBADF 回退是不同机制——
  两条线在 statx 面已结构性分叉。

### FS-4 fchmodat2 被 seccomp 阻断(SIGSYS)
- **现象**:新 glibc 内部用 fchmodat2(syscall 452),OHOS seccomp 直接
  SIGSYS 杀进程。
- **证据**:真机(A 侧 shim interposer;我方 SYS_fchmodat 直呼双实现)。
- **对策**:我方:进程内裸 SYS_fchmodat 直呼(sys/lib.rs);A:shim 拦截
  fchmodat2 符号。两条线不同拦截面,殊途同归。
- **状态**:已绕过。

### FS-5 linkat/symlinkat 缺失(原子性丢失)
- **现象**:link/symlink 系统调用不可用,退化为拷贝路径存在非原子窗口。
- **证据**:真机(A 侧 shim v0.2.x linkat/symlinkat atomic 修复)。
- **对策**:shim interposer(默认开);我方 node_fs link 路由 linkat。
- **状态**:已绕过。A 侧发现。

### FS-6 tmpfs 新目录强制 setgid+组写
- **现象**:OHOS tmpfs 上新建目录带 setgid+组写,属主检查会误判。
- **证据**:真机(#52 preload 目录场景)。
- **对策**:mkdir 后显式 chmod 0700 矫正(#52 ohos_node_userinfo)。
- **状态**:已绕过。

## 网络 / DNS

### NET-1 无全局 IPv6(ULA 误判可路由)
- **现象**:wlan0/vpn-tun 常报 ULA(fc00::/7)地址,dns.lookup({all:true})
  仍返回实际不可路由的 AAAA。
- **证据**:真机(A 侧发现;我方 #40 系同款修复)。
- **对策**:has_global_ipv6 只认 2000::/3(我方 dns.rs:5175)。
- **状态**:已绕过。

### NET-2 ADDRCONFIG 过滤 IPv4 loopback
- **现象**:getaddrinfo 的 ADDRCONFIG 把 127.0.0.1 过滤掉 → WebSocket/
  TLS 连 localhost 超时(T49 家族)。
- **证据**:真机(A 侧 shim getaddrinfo 重试强制 AF_INET)。
- **对策**:shim getaddrinfo interposer。
- **状态**:已绕过。A 侧发现。

### NET-3 透明代理使所有 outbound connect 成功
- **现象**:设备上 vpn-tun 透明代理让 connect 永不失败——以 connect 失败
  为信号的诊断手法全部失真;对端 RST 更频繁。
- **证据**:真机(A 侧 T32)。
- **对策**:无(诊断时须知);RST 后果由 #58 errno 锁存缓解。
- **状态**:记录在案(环境事实)。

### NET-4 对端 RST 表现为干净 EOF
- **现象**:读路径上对端 RST 被内核呈现为干净 EOF——写路径的发送错误
  成为唯一信号(T30;容器上读路径会报错,设备上不会——两环境差异掩蔽
  了写侧缺陷很久)。
- **证据**:真机 A/B(A 侧 T30)。
- **对策**:我方 #58 errno 锁存(写侧错误必达)。
- **状态**:已绕过(写侧)。

### NET-5 getaddrinfo stateful 解析器返回 v6-only
- **现象**:即使无 ADDRCONFIG,stateful 解析器也可能只回 v6 地址。
- **证据**:真机(A 侧 shim a925ff65689 强制 AF_INET 重试)。
- **对策**:shim getaddrinfo interposer。
- **状态**:已绕过。A 侧发现。

## 进程 / 凭据

### PC-1 沙箱 uid 无 /etc/passwd(getpwuid_r ENOENT)
- **现象**:应用沙箱 uid 不在 /etc/passwd,getpwuid_r 返回 ENOENT ——
  os.userInfo()/userinfo 类调用直接失败。
- **证据**:真机(A 侧 shim interposer + 我方 #52 preload 双实现)。
- **对策**:shim getpwuid_r interposer(own-uid 门控)+ #52 node 子进程
  NODE_OPTIONS preload(bun 自身有 fallback,子进程没有)。
- **状态**:已绕过。

### PC-2 $USER 为空(无 shell profile)
- **现象**:`bun build --compile` 产物直接装机运行时 $USER/$LOGNAME 为空。
- **证据**:真机(A 侧发现)。
- **对策**:同 PC-1(preload 的 BUN_OHOS_USERNAME 链)。
- **状态**:已绕过。

### PC-4 close_range 被 seccomp SIGSYS
- **现象**:close_range(2) 无条件 SIGSYS 杀进程。
- **证据**:真机(A 侧 shim interposer,默认开)。
- **对策**:shim close_range interposer(OHOS_COMPAT_SHIM_DISABLE 可关)。
- **状态**:已绕过。A 侧发现。

### PC-5 CONFIG_PROC_CHILDREN 缺失
- **现象**:内核未编译 CONFIG_PROC_CHILDREN,/proc/*/task/*/children 不可用。
- **证据**:真机(A 侧 /proc 扫描回退)。
- **对策**:A 侧 /proc 扫描回退。
- **状态**:已绕过。A 侧发现。

### PC-6 mksh ulimit -f no-op
- **现象**:设备 shell(mksh)的 ulimit -f 静默无效,rlimit 测试环境失真。
- **证据**:真机(A 侧 T 系列,改用 zsh)。
- **对策**:测试基建用 zsh 跑 ulimit 用例。
- **状态**:已绕过(测试侧)。

## 代码签名 / ELF

### CS-1 exec 时校验 .codesign(EACCES)
- **现象**:exec 时刻内核验证 ELF 的 .codesign 节,缺失/陈旧 → EACCES。
- **证据**:真机(A 侧 + 我方 primer 全链路分析)。
- **对策**:compile 时重签(写路径,学 A,#14 找回)+ spawn/dlopen 拒绝时
  惰性修复重试(#52 系)。
- **状态**:已绕过。

### CS-2 dlopen 同样校验 .codesign
- **现象**:dlopen 的 ELF 也走验签,缺失即拒。
- **证据**:真机(A 侧惰性修复设计——eager 全文件读曾使全量轮时间翻倍)。
- **对策**:我方 #52 拒绝时惰性修复重试;A:eager ensure_signed + retry。
- **状态**:已绕过。两条线策略不同(我方 lazy 有实测性能依据)。

### CS-3 OHOS musl 头 O_EXEC == O_PATH
- **现象**:OHOS musl 头文件把 O_EXEC 定义为 O_PATH,使 is_executable_file
  的 O_EXEC 探测对任何存在路径返回 true。
- **证据**:真机(A 侧 batch-2,authority 来源即我方 #42 系)。
- **对策**:OHOS 上改 stat+S_ISREG+access(X_OK)(#58 采纳,但实为 #59 前
  batch;以 #58 body 为准)。
- **状态**:已绕过。

### CS-4 设备签名校验偶发误拒(napi .node)
- **现象**:真机上 node-gyp 产物偶发签名校验失败,需重试+复验。
- **证据**:真机(A 侧 napi.test.ts signing retry)。
- **对策**:A 侧测试基建签名重试;我方测试树未复现同场景,暂未采纳。
- **状态**:观察中。

## shim 拦截器 ↔ 缺陷对应总表

`ohos_compat_shim.c` 默认开启的拦截器 family(源自同一内核缺陷集):
close_range(PC-4)、getpwuid_r(PC-1)、tmpfile、getcwd(FS-2 同族)、
fchmodat2(FS-4)、linkat/symlinkat(FS-5)、splice(SP-1/SP-2)、
epoll_pipe(SP-2/EP-4)、getaddrinfo(NET-2/NET-5)。
统一逃生门:`OHOS_COMPAT_SHIM_DISABLE=<symbol,...>`。

## 已知未解(诚实清单)

| 项 | 状态 |
|---|---|
| EP-3 死实例态 | 用户态不可救,内核待修(报内核方的候选) |
| EX-3 GC-suspend/execve 在途窗口 SIGSEGV | A 侧修复尝试 A/B 判负已回退,未解 |
| CS-4 napi 签名偶发误拒 | A 侧重试缓解,根因未明 |
| NET-3 透明代理环境事实 | 无对策,诊断须知 |

## 验证记录(2026-09-22 全量核验)

对照三方实测:`hyq/ohos-minimal`(A 现役)、`hyq/ohos-aarch64`(A 历史
全量线)、我方 tip。方法:逐条 grep 位点 + commit 祖先判定
(`merge-base --is-ancestor`)。

| 结论 | 明细 |
|---|---|
| shim 拦截器家族确认 | A minimal shim 2532 行,10 家族全命中(close_range 40/getpwuid_r 14/tmpfile 13/getcwd 14/fchmodat2 14/linkat 30/symlinkat 11/splice 36/epoll_pipe 15/getaddrinfo 12) |
| **修正 1**:shebang | A 的 ohos_compat_shim **无 shebang**(aarch64/minimal 均 0);其 aarch64 的 "shebang-shim widen" 指向安装期 shim 层且 minimal 未携带——EX-2 对策改写 |
| **修正 2**:statx | 我方 sys/lib.rs **早有** EBADF 回退(26a2cb78151,2026-08-13)——初版"对策缺失"为误报(node_fs 层与 sys 封装层混淆);A minimal **重建丢失**(aarch64 有/minimal 无) |
| **修正 3**:IN_ATTRIB | A minimal **丢失**抑制(aarch64 有 attrib_shadowed_by_create ×4,minimal 0)——我方 #59 领先 A 现役线 |
| **修正 4**:getgroups | 三线三态:aarch64 **0 命中**(上游 merge 丢失)、minimal 4 命中(保留)、我方 #59 已修——丢失模式又一先例 |
| 确认:EP-1 | PipeWriter ONESHOT:A minimal 1 命中、我方 2 命中(独立实现) |
| 确认:EX-1 | hmdfs open 拒绝:A minimal get_data Err 分支注释实证 |
| 确认:锁存/重注册 | pending_fatal_send_errno:双侧均有;EEXIST→CTL_MOD:仅 minimal 有(aarch64 的 ADD-retry 8/21 证伪)——**两分支各持一半,#58 合一** |
| **修正 5**:shebang | **两线均有 spawn 路径展开,等价实现**:A inline 于 spawn_process.rs(:983,4096 缓冲 + keepalive + 短读解析),我方独立 shebang.rs 模块(#17)+ 单测——初版"我方领先/A 无此对策"为**检索方法错误**(只 grep 我方符号名,漏 A 的内联实现;"shebang-shim" 术语也不同) |
| 关键教训 | **minimal ≠ aarch64 超集**:重建至少丢失 statx 回退、IN_ATTRIB 抑制等修复(唯 shebang 经修正确认两线均有);对照 A 必须**两分支都查**,且搜索须按行为特征而非符号名;我方守卫 lint(#55/#57)的存在价值再次实证——我们的修复不会被重建悄悄丢掉 |

## 维护规则

1. 新怪癖:先进 `OHOS_TEST_STATUS.md` 台账(探针/真机证据全文)→ 实证后
   收编本清单(给稳定 ID)→ 对应 skip 台账条目注明本清单 ID。
2. 收编需三选一证据:裸 syscall/inotify 探针、真机 A/B、node 同设备对照。
3. 修复落地后条目状态改"已绕过"并链 PR;内核侧问题标注"适合报内核方"。
