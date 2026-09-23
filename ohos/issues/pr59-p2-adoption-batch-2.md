# P2: 采纳批次二——cwd 截断误判、fs.watch IN_ATTRIB 噪声、getgroups 缺 egid — 归档文档

> **关联 PR**:[#59](https://github.com/jx-bit/bun/pull/59)（单 commit
> `defc9c8ef3`，3 文件 +147/−10，base `ohos-aarch64` tip `4ea39bf334`）
> **状态**：✅ 合并（586d8a1784）
> **来源**：[双分支采纳分析](../analys/20260922-two-branch-comparison-and-adoption.md)
> §2.1 候选 #1/#4/#5。第一批（EEXIST→CTL_MOD + errno 锁存）=
> [#58](https://github.com/jx-bit/bun/pull/58)（已合并 4ea39bf334）。
> **一句话**：三个"用户可感"缺陷——深目录启动直接报错、watcher 每次建
> 文件多一次假事件、组检查少一个 gid。

## 1. 问题与用户感知

### 用户影响速览

| # | 用户在做什么 | 感知症状 | 频率 | 严重度 |
|---|---|---|---|---|
| 1.1 | 在深目录(路径 >4095 字节)里运行任何 bun 命令 | 启动即报"目录已删"(CurrentWorkingDirectoryUnlinked),目录明明存在——**该目录下 bun 完全不可用** | 低(OHOS 沙箱前缀放大可达性) | 高(命中即不可用) |
| 1.2 | 用 fs.watch/递归 watcher 监听目录(dev server、构建 watcher、文件同步) | **每创建一个文件**先收到一次假 "change" 再收 "rename"——双重重载/重建;change 时读半成品文件 ENOENT | **每次文件创建**(本批最高) | 中-高(watcher 应用从烦人到坏) |
| 1.3 | 脚本/库调用 process.getgroups() 做组成员检查(权限工具、CI、Node 行为断言) | 返回列表**少有效 gid**——"我在不在 X 组"判断错;与 `id -G` 输出不一致 | 低(API 小众) | 低(数据错误,不崩溃) |

### 1.1 cwd 截断误判（bun_core/util.rs,OHOS-gated）

`cwd_is_deleted_ohos` 用 4095 字节缓冲 readlink `/proc/self/cwd`。目标
路径填满缓冲时 **readlink 不写 NUL**——代码把截断路径当完整路径 stat,
ENOENT → **误判"当前目录已删除"** → getcwd 返回
CurrentWorkingDirectoryUnlinked,bun 启动级故障。

- **触发场景**:应用在深层嵌套目录里运行 bun——OHOS 沙箱前缀
  `/data/storage/el2/base/haps/...` 先占 ~50 字符预算,深层项目/
  node_modules 嵌套可推过 4095。
- **用户感知**:目录明明存在,bun 报"目录已删"——模块解析、配置发现、
  `bun run` 全部按"目录已删"的错误路径走,该目录下 bun 完全不可用。
- **频率**:低,但 OHOS 沙箱前缀使其比桌面 Linux 更易触达。
- **严重度**:高(命中即该目录不可用)。
- **修复后**:填满缓冲 = 不可判定 → 报告 not-deleted,深目录正常工作
  (springmin 5061d20345)。

### 1.2 fs.watch IN_ATTRIB 抑制(path_watcher.rs)

OHOS 内核对 open(O_CREAT)/mkdir 创建的 inode **先发 IN_ATTRIB(安全打标)
再发 IN_CREATE**(裸 inotify 探针实证:设备 ATTR CRE / stock-Linux 容器
仅 CRE)。Node 语义:新条目首个事件必须是 "rename"。结果:每次建文件
watcher 先收一次假 "change",上游套件 3 个 watcher 用例确定性失败
(队列溢出幸存断言 + 两个 fs.promises.watch symlink-dir 用例)。

- **触发场景**:dev server、构建 watcher、文件同步等任何监听目录创建
  事件的应用。
- **用户感知**:每次建文件双重事件;在 "change" 时就读文件的处理器拿
  到**还没建完的文件**(ENOENT);chokidar 类自带防抖的库部分掩盖,
  裸 `fs.watch` 用户全中。
- **频率**:每次文件创建——本批三项里最高。
- **严重度**:中-高(watcher 类应用从烦人到坏)。
- **修复后**:建文件首事件恢复 "rename",与全平台语义一致。

**修复**(A 侧 48152d25e4c + 72bc3a80b44 两 commit 合一):
- 同批次前瞻(16 事件):同一读缓冲内,ATTRIB 后跟同 (wd,name) 的
  IN_CREATE → 判定为打标模式,抑制该 ATTRIB;真实 chmod/chown/utimens
  永不后跟 CREATE,原样通过
- **跨读边界扩展**:安静队列上读线程会在创建 syscall 到达 create 钩子前
  醒来(ATTRIB 单独落在一个 read 里),同批前瞻不够——ATTRIB 存活时
  poll fd 至多 2ms,可读则追加一次 read 并跨边界重跑前瞻(实测修复
  "symlink dir" 与溢出幸存断言两个残留);真 chmod 代价一次 2ms poll
- INotifyWatcher(bundler HMR)有意不动:假 change 最多多一次冗余重建,
  无 node 兼容契约

### 1.3 process.getgroups() 缺 egid(BunProcess.cpp)

Node 文档:返回补充组 ID 且**确保包含有效 gid**(POSIX 未规定)。裸
getgroups(2) 只回补充组——OHOS 实测 egid 20020101 不在补充组列表
[1006,1007,1097,3009,3099] 而 `id -G` 报全部六个。修复:egid 缺席时
追加(平台无关,无 target 门控)。

- **触发场景**:权限检查类脚本/工具(组成员判断)、CI 中断言 Node
  行为一致性的测试(vendored node 的 test-process-getgroups.js 深等值
  断言即此场景)。
- **用户感知**:getgroups() 少 egid——"我在不在 X 组"判断出错;与
  `id -G` 输出不一致。
- **频率**:低(API 小众)。
- **严重度**:低(数据错误,不崩溃)。
- **修复后**:与 Node/`id -G` 一致。

## 2. 与参照实现的对比

| 项 | 参照实现 | 本 PR | 证据 |
|---|---|---|---|
| cwd 截断 | sys/lib.rs posix_impl 正本(b7cff72839 内,+15) | 我方无 sys 正本(仅 util.rs 镜像),单点落地;errno 助手用 `crate::ffi::errno()`(我方命名) | 〔源码〕逐字同构 |
| IN_ATTRIB 抑制 + 跨边界 | 48152d25e4c(+53)+ 72bc3a80b44(跨读边界) | 逐字同,两 commit 合一 | 〔源码〕 |
| 对齐惯用法 | A helper 用 `buf.as_ptr().add(off).cast()`(**A 的 host clippy 未拦**) | 改用我方 reader loop 同款 `from_ref(&*buf).cast().byte_add(off)` 惯用法(从 4 字节对齐的 AlignedBuf 出发,规避 cast_alignment lint);helper 随之改收 `&AlignedBuf + n` | 〔源码〕本仓 lint 更严的适配 |
| AlignedBuf 作用域 | A 树? | 我方原为**循环体内局部 struct**——上移模块层(cfg 门 + repr(C, align(4)) 保持),helper 与循环共享 | 〔源码〕 |
| getgroups | BunProcess.cpp +23/−4 | 逐字同 | 〔源码〕 |

## 3. 验证

- 〔本机〕bun_core/bun_runtime host clippy 0 error;cargo check
  aarch64-unknown-linux-ohos ✅;rustfmt ✅;dead-code-escapes 24/24 ✅。
  C++ getgroups 无本地 clang,CI 编译覆盖。
- **未修复构建上必失败声明**:深 cwd 启动报 CurrentWorkingDirectory-
  Unlinked;fs.watch 建文件首事件为 "change";getgroups 缺 egid。
- 〔设备·验收〕深目录 bun run 正常;watch 建文件首事件 rename;
  vendored node 的 test-process-getgroups.js 深等值断言通过。

## 4. 采纳清单状态(收口)

采纳分析 §2.1 五项:#2/#3 → #58(已合并);#1/#4/#5 → 本 PR。
分析文档已同步标注。
