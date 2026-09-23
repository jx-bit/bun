# P2: exec 出的 node 子进程 os.userInfo() ENOENT — 归档文档

> **关联 PR**：[#52](https://github.com/jx-bit/bun/pull/52)（单 commit
> `4af190243b`，5 文件 +596，base `ohos-aarch64` tip `ee8ebba8bd`）
> **状态**：✅ 合并（ea2faf93de）
> **一句话**：在鸿蒙设备上，bun 启动一个 **node 子进程**时（`Bun.spawn`
> 跑 node、`Bun.$` 执行 npm/npx/yarn/pnpm），子进程里任何代码调用
> `os.userInfo()` 都会**直接抛异常**——本 PR 修掉它。

## 0. 证据来源与参照线地位

**参照线不是官方**（独立 OHOS 移植线，非 oven-sh 上游、非规范来源）。
上游 `bun/main` 无任何对应机制（grep = 0）。本 PR 的实现形态取自参照线
（其真机验证过、且 tip 上带 2 个真机驱动的后续 bugfix），正确性立论见
§2 机制分析——每一步都可独立验证，不依赖"参照线是权威"。

## 1. 问题到底是怎么回事

### 1.1 背景：os.userInfo() 是什么、它的实现链

`os.userInfo()` 是 Node/bun 的标准 API，回答"当前运行程序的用户是谁"：
返回 `{ username, homedir, shell, uid, gid }`。它的实现一路走到 libc：

```
os.userInfo() → libuv uv_os_get_passwd → getpwuid_r(getuid())
```

`getpwuid_r` 的语义：拿自己的 uid 去 **`/etc/passwd`** 查"这个 uid 是谁"。
Linux 桌面/服务器上每个 uid 在 `/etc/passwd` 里都有一行（用户名、home、
shell），所以这套链路一直好用。

### 1.2 为什么鸿蒙设备上会查不到

OHOS 应用跑在**沙箱**里：你的 App 进程是一个随机 uid，而沙箱里**没有
`/etc/passwd`，更没有这个 uid 的条目**。于是：

```
getpwuid_r(沙箱uid) → 查无此人 → ENOENT
```

### 1.3 为什么 bun 自己没事、node 子进程就炸

| 谁 | os.userInfo() 的实现 | 查不到时 |
|---|---|---|
| **bun 自己**（`bun run x.js`） | bun 的 Rust 实现（`node_os.rs`） | **有兜底**：返回 `"unknown"`，不炸（两线一致） |
| **node 子进程**（spawn 出来的 `node`/`npm`/`npx`/`yarn`/`pnpm`） | 子进程链接的是**真 musl libc** + Node 标准库自己的 os 模块 | **没有任何兜底**——直接 throw ENOENT |

关键在于：bun 的兜底是**编译进 bun 二进制**的 Rust 代码。一旦 exec 出
一个真正的 node 子进程，它跑的是自己的代码 + 自己的 libc，**完全不经过
bun**——bun 帮不了它。另外 `bun build --compile` 出来的 exe 拷到设备上
（无 shell profile、无 $USER），里面再 exec node，同样炸。

设备上的实际表现：spawn 一个调了 `os.userInfo()` 的 node 工具/脚本
→ 工具启动即抛异常退出。

### 1.4 复现（设备）

```js
// spawn-node-userinfo.js
const p = Bun.spawnSync(["node", "-e", "console.log(require('os').userInfo().username)"]);
console.log(p.stdout.toString(), p.stderr.toString());
// 修复前: stderr 含 ENOENT（getpwuid 失败）
// 修复后: 打印用户名（经 preload 兜底）
```

## 2. 修复机制（本 PR 做了什么）

核心思路：**Node 自己留了一个注入口——`NODE_OPTIONS` 环境变量**。bun 在
spawn 一个"看起来像 node 的程序"时，把一个小 JS 补丁文件准备好，塞进
子进程的 `NODE_OPTIONS`。子进程的 node 一启动就会先执行这个补丁，补丁
把 `os.userInfo()` 包装出兜底。分四步：

**第 1 步：判断该不该管。** `compute(argv0, env_array)` 只在
`basename(argv0)` 是 node 家族时触发（`node`/`nodejs`/`node22` 这类
版本后缀 shim/`npm`/`npx`/`corepack`/`yarn`/`pnpm`/`pnpx`；明确拒绝
`nodemon`、`bun`）。两个逃生门任一命中就不注入：环境变量
`BUN_OHOS_NO_NODE_USERINFO=1`（bun 自己的环境或子进程 env 都算），或
shim 总开关 `OHOS_COMPAT_SHIM_DISABLE` 里含 `getpwuid_r`。

**第 2 步：把补丁文件写到设备上。** 内容是一段固定 JS（`PRELOAD_JS`），
按内容哈希命名 `bun-ohos-userinfo-<hash>.cjs`。候选目录按意图排序：
`$BUN_INSTALL/ohos` → `$HOME/.bun/ohos` →
`/data/storage/el2/base/.bun-ohos`（鸿蒙沙箱必可写的兜底）。含空格/
引号/反斜杠/tab 的路径直接跳过（NODE_OPTIONS 的词法传不过去，不转义、
绕开）。写入用"写临时文件 + 原子 rename"（并发 bun 进程永远看不到半个
文件）；**每次 spawn 都重新检查文件还在不在**，被系统清了就重写（自愈，
不依赖缓存标志位）。目录 mkdir 0700 后再 chmod 矫正（OHOS tmpfs 会强
制 setgid+组写，不矫正下次复用会误判非本人目录）。

**第 3 步：注入环境变量。** 子进程 env 里塞
`NODE_OPTIONS="--require <补丁路径>"`（若子进程已有 NODE_OPTIONS 则合并
到前面；已含相同 `--require` 则跳过——bun→bun→node 链不重复注入），
并附带 `BUN_OHOS_USERNAME=<用户名>`。用户名是 bun 进程启动后通过内嵌
ohos-compat-shim 的 `getpwuid_r` interposer 一次性解析缓存的（shim 拦截
了 libc 符号、能拿到沙箱身份；这就是为什么 bun 自己的 passwd 查询有值）。

**第 4 步：补丁在子进程里做什么。** probe-then-fallback：**先试**真
`os.userInfo()`——不炸就什么都不做（严格 no-op，mainline Linux/正常
环境零影响）；真炸（ENOENT）才用包装函数替换，兜底值：
用户名 `BUN_OHOS_USERNAME` → `$USER` → `$LOGNAME` → `"unknown"`（与
bun 自己的 fallback 一致）、homedir → `$HOME` → `/data/storage/el2/base`、
shell → `$SHELL` → `/bin/sh`。

**接线点 ×2**（缺一不可）：`Bun.spawn` 走
`js_bun_spawn_bindings.rs`（PWD 修正块之后）；`Bun.$`/`bun run` 走
`shell/subproc.rs`（argv null 哨兵之前，env 行用 arena bump 分配）。

## 3. 改了哪些文件（5 个）

| 文件 | 干什么 |
|---|---|
| `src/runtime/api/bun/ohos_node_userinfo.rs` | **新增**，全部机制本体（含 8 个单元测试，随 ohos target 激活） |
| `src/runtime/api.rs` | 声明模块（`#[cfg(target_env = "ohos")]`，host 构建不编译） |
| `src/bun_core/env_var.rs` | 注册 `BUN_OHOS_USERNAME`（仅登记供 grep/文档，bun 自己不消费，消费方是补丁 JS） |
| `src/runtime/api/bun/js_bun_spawn_bindings.rs` | Bun.spawn 接线（18 行） |
| `src/runtime/shell/subproc.rs` | shell 接线（25 行） |

## 4. 与参照实现的差异（4 处适配，零行为差异）

| 处 | 参照 | 本 PR | 原因 |
|---|---|---|---|
| is_disabled 环境回退 ×2 | `std::env::var_os` | `bun_core::getenv_z` | 本仓 clippy 规则 5 禁 `var_os`；语义同为活体 getenv 读取 |
| getpwuid_r 循环 EINTR/ERANGE | `sys::E::EINTR/ERANGE` | `libc::EINTR/ERANGE` | 我方 `sys::E` 新类型只有无前缀精选变体（无 `EEXIST`/`ERANGE`） |
| try_dir EEXIST | `sys::E::EEXIST` | `e.errno == libc::EEXIST as u16` | 同上（`Error::errno: u16` 公有字段） |
| 文件头 doc | 引用参照线内部 workarounds.ts | 删除该悬空指针 | 引用我方树不存在的文件 |

其余 541 行逐字一致。**参照线角色 = 实现形态 + 验证锚点，非正确性依据。**

## 5. 验证

- 〔本机〕`cargo check -p bun_runtime --lib --target=aarch64-unknown-linux-ohos`
  ✅（新文件与两注入块均 ohos-gated，此为编译主门禁）；host clippy ✅、
  fmt ✅、byte-search + dead-code-escapes 27/27 ✅。
- **未修复构建上必失败声明**：设备上 spawn node 子进程调 `os.userInfo()`
  抛 ENOENT（§1.4 复现）。
- 〔设备·验收〕§1.4 复现打印用户名不抛异常；
  `BUN_OHOS_NO_NODE_USERINFO=1` 时恢复原行为（抛 ENOENT）；
  mainline Linux 上 spawn node 无任何行为变化（补丁 no-op）。

## 6. 过程发现（非本 PR 范围，记录防丢）

ohos-target clippy 首次运行暴露**预存 lint 债**（cfg(ohos) 代码从未被
ohos-target clippy 检查过）：`bun_core/util.rs:4164`（manual_c_str_literals）、
`util.rs:4174`（borrow_as_ptr）、`bun_sys` 2× undocumented_unsafe_blocks。
均系 #32/#34/#42 时期移植代码，与本 PR 无关，建议后续小清理 PR。
