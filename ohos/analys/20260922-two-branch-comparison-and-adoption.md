# 双分支对比与采纳分析:参照线的 ohos-aarch64(历史全量线)+ ohos-minimal(现役精简线)

> 2026-09-22 建立。对比对象:`social4hyq/ohos-bun` 的两条分支(非官方参照线),
> 目标 = 系统性提取可采纳项 + 确认双向收敛状态。本文产出直接喂给下一批 PR 候选。
> 方法:commit 主题分类 + 逐位点 grep 核验(全部标注〔源码〕/〔实测〕)。

## 1. 分支拓扑与定性(先纠正一个认知)

| 分支 | 位置 | 定性 |
|---|---|---|
| `ohos-aarch64` | 4576412c6d(2026-09-16 后停更) | **历史全量开发线**:r42-r80 轮次、T03-T53 triage 系列、~350 commit——我们移植过的全部修复(61dbc3a9d deleted-cwd、skip_ctl_del、epoll_rearm、shebang…)的源头总库 |
| `ohos-minimal` | e353e6d81f4(**2026-09-21 仍活跃**) | **现役交付候选线**:从 744846f844(1.4.2 bump,即 formula revision)分叉,151 commit,"minimize-ohos-implementation" 重构 + batch 采纳 |

关键事实:
- **版本基线不同**:我方 1.4.0 vs A minimal **1.4.2**(上游差 2 个 minor)——文件级 diff 混有上游漂移,采纳时必须按 rule 4 逐簇锚定,不能整文件搬
- **shim 分叉巨大**:同一 `ohos_compat_shim.c` 祖先,A 的 minimal 版 2532 行(我方 ~1600),LD_PRELOAD/内嵌 interposer 家族(close_range/getpwuid_r/tmpfile/getcwd/fchmodat2/linkat/symlinkat/splice + per-symbol SIGSYS-catch)
- **流向反转实锤**:A 的 `b7cff72839 "adopt batch-2 runtime fixes from the reference ports"` 明确标注采纳来源,**其中 "authority" 经逐项比对 = 我方交付线**(is_executable_file X_OK、subprocess blob stdin 均为我方 #42 系)——A 在移植我们的修复

## 2. 可采纳清单(逐项 grep 核验过我方树)

### 2.1 确认缺失,建议采纳(按优先级)

| # | 修复 | A 来源 | 我方现状 | 优先理由 |
|---|---|---|---|---|
| 1 | **`cwd_is_deleted` 截断保护**:readlink 填满缓冲(无 NUL)= 截断 → 不可判定,不得判 deleted | minimal 5061d20345(springmin) | ✅ 已采纳:[#59](https://github.com/jx-bit/bun/pull/59) | 真 bug,趁热 |
| 2 | **`FilePoll::register` EEXIST→重发 CTL_MOD**:关闭 fd 的陈旧注册使复用 fd 号永收不到事件;永不 DEL 活注册(skip-CTL_DEL 的缺失半边) | minimal b7cff72839(springmin d91b7c5487) | ✅ 已采纳:[#58](https://github.com/jx-bit/bun/pull/58)。**边界注意**:A 侧 9ab94f22fbf(2026-08-20/21)的真机实验定案了更深的"死实例态"(ADD=EEXIST/MOD=SUCCESS/DEL=EEXIST,用户态 epoll_ctl 任何组合不可救)——#58 的修复覆盖"陈旧注册阻塞新 ADD"场景,死实例态不在覆盖内 | #32 家族互补 |
| 3 | **net 致命发送 errno 锁存**(`pending_fatal_send_errno`):对端 RST 时排队写静默丢失 | aarch64 519c8163c0b + 496fdb61ac9 | ✅ 已采纳:[#58](https://github.com/jx-bit/bun/pull/58) | 用户可感(写丢失无报错) |
| 4 | **fs.watch IN_ATTRIB 创建标记抑制**:OHOS 内核在 IN_CREATE 前发 IN_ATTRIB 的竞态 | aarch64 48152d25e4c + 72bc3a80b44 | ✅ 已采纳:[#59](https://github.com/jx-bit/bun/pull/59) | fs.watch 设备体验 |
| 5 | **`process.getgroups()` 含 egid**(Node 文档语义) | aarch64 35eaf7a0e09 | ✅ 已采纳:[#59](https://github.com/jx-bit/bun/pull/59) | Node 兼容语义 |
| 6 | **link(2) → linkat 路由**:沙箱整体 EPERM link(2),路由后内嵌 shim 的原子拷贝回退接管 → hardlink 安装 backend 与 fs.linkSync 可用 | aarch64 e512bffe965 + ade348ec659 | ✅ 已采纳:[#61](https://github.com/jx-bit/bun/pull/61)(指南 §6.1 交叉核对发现;sys 层路由不适用——我方结构不同,详见 pr61 文档 §3) | 指南 §6.1 交叉核对发现 |

### 2.2 已拥有等价实现(无需采纳)

| 项 | 我方状态 |
|---|---|
| has_global_ipv6 ULA(fc00::/7)误判 | ✅ dns.rs:5175 已有(与 #40 DNS 系一致) |
| ReadFile 并发读循环串行化 | ✅ #37 已移植 |
| deleted-cwd 三部曲 / skip_ctl_del | ✅ #49/#32 系已有 |
| Terminal TCSADRAIN 挂死 | ✅ 天然免疫——我方 `set_termios` 无条件 TCSANOW,从不走 DRAIN(A 的 738701916f0 是为 DRAIN 挂死打的补丁) |
| node-userinfo / libc 判定 / os.machine | ✅ #52/#54/#53(A minimal 已反向采纳我们的等价实现) |

### 2.3 需进一步核验

- `node_fs` unknown_size sentinel 读循环(c38ba14a3b4):我方 node_fs 未 grep 到同名字段——可能命名不同或确实缺失,实施时先核对我方 fstat 回退路径
- ICU 静态链接(3565953f0ea)/ WebKit 嵌套构建诊断(487ab56cf6c 等):构建基建类,按需取用

### 2.4 测试/构建基建候选(非 bug,方法论学习)

- **expected-durations.json 的 ohos lane updater**(a692278b53,"from authority")——我方 fulltest 轮的时长预算自动化
- **quarantine 分级方法**:A 把 quarantine 按 known-OHOS-class / Flaky / structural 分类且逐条记录理由(151 commit 中 ~30 条 test:*),与我方 #55 skip 台账同思路——两边台账将来可互相对表
- **zstd qsort_r shim**(cf2b351d49)+ 无条件 patch 数组(4daf953acb)——vendor 补丁健壮性
- **selfsign canonical 算法 vendoring**(6f1d417f1d)——ohos_sign 与参照签名实现的对齐
- **64KiB linker page 统一**——链接布局一致性

## 3. 反向输出确认(我们领先 A 的)

| 我方已有 | A minimal 状态 |
|---|---|
| #17 shebang 展开 | ✅ **有等价实现**(初判"无"为检索错误——A 内联于 spawn_process.rs,:983 起 4096 缓冲展开 + "exec 已签名解释器"理据;修正记录见 PLATFORM-DEFECTS EX-2) |
| #52 node-userinfo preload | 无 ohos_node_userinfo.rs |
| #54 libc 判定 / `-ohos` 命名 | 有等价实现(IS_OHOS ×4)——**已采纳我们的等价物** |
| #55 测试安全网(skip 台账/守卫 lint) | 无对应机制 |
| #57 ohos-target clippy 清理 | `from_utf8_unchecked`/`std::fs::File` 欠账仍在,clippy 车道仍 host-only |
| #56 Windows cfg 门 | A 无 Windows 通道(系其盲区) |

## 4. 采纳方法论提醒

1. minimal 基于 **1.4.2**、我方基于 **1.4.0**——任何文件级 diff 都混上游漂移,逐簇按 README 规则 4 锚定,禁止整文件搬(先例:#54 排除 file:// 与 is_host_platform)
2. 移植时与原实现逐字对齐后做本仓适配(先例:#52 的 getenv_z/errno 适配、#57 的 lint 适配)
3. 采纳来源标注惯例:A 文档用 "authority"/"springmin" 指代来源线;我方档案按台账惯例写明参照线(非官方)

## 5. 建议执行顺序

1. **候选 #1(cwd 截断)+ #2(EEXIST→CTL_MOD)**:一个 PR(#32 家族互补 + #57 同函数,两项都小)
2. **候选 #3(net errno 锁存)+ #4(IN_ATTRIB)+ #5(getgroups)**:第二个 PR(net/进程/fs 各一簇,或拆分)
3. **#57 合并后**:bun_standalone_graph 12 处结构迁移(独立专项,已在 #57 文档锁定清单)
4. **设备 fulltest 验收轮**(阻塞中,待设备上线):#49-#55 全部修复 + 本分析的新采纳项可并入同一轮验收
