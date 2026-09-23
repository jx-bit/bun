# P2: fs.linkSync 路由 linkat——硬链接沙箱 EPERM 修复 — 归档文档

> **关联 PR**:[#61](https://github.com/jx-bit/bun/pull/61)（单 commit
> `971502eecd`，1 文件 +29/−1，base `ohos-aarch64` tip `5d8820bcdc`）
> **状态**：✅ 合并（fd344a6ff0）
> **来源**:[双分支采纳分析](../analys/20260922-two-branch-comparison-and-adoption.md)
> §2.1 候选 #6——由规避指南 §6.1 交叉核对发现（指南所述 EPERM 现状与
> A 侧已路由事实冲突,追查确认我方缺失）。
> **一句话**:OHOS 沙箱整体禁止 link(2),内嵌 shim 靠拦 `linkat` **符号**
> 提供原子拷贝回退——但 musl 的 `link()` 走裸 syscall 绕过该符号,
> `fs.linkSync` 在设备上全路径 EPERM。路由到 linkat 即触发 shim 回退。

## 1. 问题与用户感知

### 用户影响速览

| # | 用户在做什么 | 感知症状 | 频率 | 严重度 |
|---|---|---|---|---|
| 1 | JS 里用 `fs.linkSync` / `fs.promises.link` 创建硬链接 | **全路径 EPERM**——无论源/目标在哪;`Error: EPERM: Operation not permitted, link` | 每次调用(100%) | 中(API 完全不可用;`fs.copyFile` 是可用替代) |
| 2 | 依赖硬链接语义的第三方工具(去重存储、增量快照类库) | 同上,工具报权限错误 | 随工具面 | 中 |

**注意**:`bun install` 的硬链接安装后端**不受影响**(见 §2.4——安装器
本就走 linkat,shim 可见)。

### 1.1 背景知识:硬链接与符号插值

**硬链接**(hardlink):同一 inode 的多个目录项——零拷贝、零额外空间。
bun 的包安装器在 Linux 上默认用硬链接把全局缓存里的包物化到项目
`node_modules`(`--backend hardlink` 默认值)。POSIX 创建硬链接的
syscall 有两个等价形式:`link(2)` 与 `linkat(AT_FDCWD, ..., AT_FDCWD, ..., 0)`。

**符号插值(symbol interposition)**:ELF 动态链接规则——**可执行文件
自身定义的符号,在符号解析时优先于动态库的同名符号**。内嵌 shim
(`ohos_compat_shim.c` 编译进 bun 本体)定义了 `linkat` 等符号,因此
bun 内所有对 `libc::linkat` 的 FFI 调用实际落在 shim 的实现上——这正是
"内嵌 shim"在不依赖 LD_PRELOAD 的前提下生效的机制(与 LD_PRELOAD 的
区别:前者只覆盖本进程,后者可覆盖子进程)。

### 1.2 缺陷机制:为什么 link() 绕过、linkat() 被拦

OHOS 沙箱在 syscall 层拒绝一切硬链接创建:link(2) 与裸 linkat syscall
均返回 EPERM/EACCES(任何路径、任何目录——沙箱策略防配额绕过,与权限
位无关)。shim 的对策是 interpose `linkat` **符号**:对 libc 级的
`linkat` 调用,不执行真 syscall,而是回退为**原子字节拷贝**
(temp 写 + rename;其非原子窗口已在 shim v0.2.x 修复)。

缺陷路径(我方修复前):

```
fs.linkSync(a, b)
  → node_fs link() → libc::link(a, b)            ← musl 的 link 实现:
      内部直呼 syscall(SYS_linkat, AT_FDCWD, ...)   【裸 syscall,不过符号】
  → 沙箱 EPERM(且 shim interposer 永不触发)
```

而 `libc::linkat(...)` 调用走**符号** → 命中 shim interposer → 拷贝
回退 → 成功。同一个内核、同一个 shim,唯一差异是**走没走符号**。

用户感知:设备上 `fs.linkSync(a, b)` **全路径 EPERM**——无论源/目标在
哪个目录(沙箱策略,非权限位问题);任何依赖硬链接的第三方工具同样
失败。频率:每次调用,100%。

### 1.3 与安装后端的关系(为什么 bun install 不受影响)

我方安装器两条物化路径**早已走 linkat**:`PackageInstall.rs:1597/:1609`
(hardlink 物化)与 isolated `Hardlinker.rs:257/:267/:302`——均经
`sys::linkat` 符号,shim 可见。唯一残留的裸 `libc::link` 调用点 =
node_fs 的 linkSync(本 PR 修复)。

**A 侧对应结构不同**:A 的 sys 层有 `sys::link`(posix_impl),其安装
路径经 `sys::link` → 需要 e512bffe965 在 **sys 层**路由;我方 POSIX 无
`sys::link` 包装(node_fs 直呼 FFI)→ A 的 sys 层 commit 对我方
**不适用**,只需 node_fs 一处。

## 2. 修复

`node_fs.rs` link 的非 Windows 分支拆为两个 cfg:

```rust
#[cfg(all(not(windows), target_env = "ohos"))]
return ... libc::linkat(libc::AT_FDCWD, from, libc::AT_FDCWD, to, 0) ...;
#[cfg(all(not(windows), not(target_env = "ohos")))]
return ... libc::link(...) ...;   // 原路径,非 OHOS 逐字保持
```

- `linkat(AT_FDCWD, from, AT_FDCWD, to, 0)` 与 `link(from, to)` 在
  POSIX 语义上**严格等价**(AT_FDCWD = 以当前目录解析两个路径)——
  stock Linux 上行为零变化,且非 OHOS 分支根本不编译。
- OHOS 上:调用命中 shim 的 `linkat` 符号 → 原子拷贝回退 → 成功;
  `OHOS_COMPAT_SHIM_DISABLE=linkat` 可关(关闭后恢复 EPERM——这本身
  就是设备验收的对照组)。

## 3. 与参照实现的对比(结论先行)

**node_fs 层与 A minimal 逐字同(ade348ec659);A 的 sys 层路由
(e512bffe965)对我方不适用——我方 POSIX 无 sys::link 包装,结构不同。**

| 项 | 参照实现(A minimal) | 本 PR | 证据 |
|---|---|---|---|
| node_fs link 路由 | ade348ec659(OHOS 门控 linkat AT_FDCWD;原 link 分支收窄 cfg) | 逐字同 | 〔源码〕 |
| sys::link 层路由 | e512bffe965(sys/posix_impl 的 link 加 OHOS 分支,+41/−7) | **不适用**——我方 POSIX 无 sys::link(linkSync 直呼 libc::link;安装后端已走 linkat) | 〔源码〕grep 结构 |
| sys::link 的来源 | **A 自建封装**——上游 v1.4.0/v1.4.2 的 sys/lib.rs 均 0 命中 `pub fn link(src`;A minimal node_fs :5357 调它(hardlink 物化面) | 我方保持上游内联风格(node_fs 直呼 FFI) | 〔源码〕grep 双版本 |
| shim 原子性 | v0.2.x 修非原子拷贝窗口(3f5121b) | 同一 shim,同受益 | 〔源码〕ledger |
| 覆盖面 | A:node_fs + sys 两层 | 我方:node_fs 一层即全覆盖(我方 POSIX 的 link 调用点仅此一处) | 〔源码〕grep 全树 |

参照线 = social4hyq/ohos-bun(非官方);原始修复 A 侧
(e512bffe965 + ade348ec659)。

## 4. 验证

- 〔本机〕bun_runtime host clippy ✅(socket_body/node_fs 非 cfg-gated,
  host 全 lint 集覆盖)、cargo check bun_runtime ohos-target ✅、
  rustfmt ✅、dead-code-escapes ✅。
- **未修复构建上必失败声明**:设备上 `fs.linkSync(a, b)` 全路径 EPERM
  (指南 §6.1)。
- 〔设备·验收〕`fs.linkSync` 成功;`OHOS_COMPAT_SHIM_DISABLE=linkat`
  对照组恢复 EPERM(证明生效路径确为 shim);`bun install`(hardlink
  backend)物化阶段不再 EPERM。

## 5. 检索教训(收编)

对比两线代码须按**行为特征**搜索(binfmt_script/AT_FDCWD/缓冲尺寸),
不能只 grep 我方符号名——同一功能在另一条线的名字、位置、组织完全不同
(初版误判"A 无此对策/已弃",实为内联实现 + 术语差异;同型错误第二次
出现,第一次是 statx 层混淆,均记录于 PLATFORM-DEFECTS 验证记录)。
