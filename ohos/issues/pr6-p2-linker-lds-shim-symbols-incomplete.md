# P2: linker.lds OHOS shim 符号不全 — 详细讲解
> **关联 PR**：[#6](https://github.com/jx-bit/bun/pull/6)（shim 符号 8→15 补全，本 issue 主修复）· [#4](https://github.com/jx-bit/bun/pull/4)（--undefined-version 前置）

> 用最简单的方式讲清楚：什么是 shim、为什么有些符号没导出、有什么后果、怎么修。

---

## 1. 背景：OHOS 的兼容性问题

### 1.1 OHOS 内核和 Linux 不一样

OHOS（HarmonyOS）基于 Linux 内核，但加了一层"沙箱"（seccomp 过滤器）。
这个沙箱会**拦截或改变某些 Linux 系统调用的行为**：

| 系统调用 | OHOS 沙箱的行为 | 后果 |
|---|---|---|
| `close_range` | 直接 SIGSYS 崩溃 | 不能批量关闭 fd |
| `linkat` | EPERM（SELinux 拦截） | 不能创建硬链接 |
| `symlinkat` | EPERM | 不能创建符号链接 |
| `getcwd` | hmdfs 文件系统返回失败 | 获取当前目录失败 |
| `tmpfile` | hmdfs 不支持 | 临时文件创建失败 |
| `getpwuid_r` | 无 /etc/passwd | 用户信息查询失败 |
| `epoll` 簇 | T50 内核 bug：pipe readiness 异常 | epoll 事件丢失/重复 |

### 1.2 什么是 shim（垫片）

**通俗比喻**：你买了一台进口电器，插头是欧洲标准的，中国插座插不进去。
你买了一个"转换插头"——这个转换插头就是 shim。

shim 是一个 C 文件（`ohos_compat_shim.c`），**重新实现**了这些有问题的函数。
当程序调用 `getcwd()` 时，实际执行的是 shim 里的 `getcwd()`，
而不是 libc 里的原版 `getcwd()`。

### 1.3 shim 的工作原理

```
程序调用 getcwd()
    ↓
链接器查找 getcwd 符号
    ↓
找到 bun 二进制里的 shim 版本（而不是 libc 原版）
    ↓
执行 shim 的 getcwd()：
    1. 先尝试真正的 getcwd()
    2. 如果失败（hmdfs bug），用 fallback（$PWD 环境变量）
    ↓
返回结果
```

shim 的设计原则：**优先用原版，只有原版失败才用 fallback**。
所以 shim 在没有问题的平台上是"透明"的（no-op）。

---

## 2. shim 和 `.node` 模块的关系

### 2.1 什么是 `.node` 模块

`.node` 文件是编译好的原生插件（C/C++ 写的），通过 `dlopen` 加载到 bun 进程里。
比如 `better-sqlite3.node`、`sharp.node` 等。

`.node` 模块在运行时也会调用 `getcwd()`、`epoll_ctl()`、`close()` 等函数。

### 2.2 `.node` 模块怎么找到函数

当 `.node` 模块调用 `epoll_ctl()` 时，动态链接器会按顺序查找：

```
1. bun 二进制的 .dynsym（动态符号表）— 如果 bun 导出了 epoll_ctl，用 bun 的版本
2. libc.so（系统库）— 如果 bun 没导出，用 libc 的原版
```

### 2.3 version-script 控制导出

`linker.lds` 是一个 version-script 文件，控制 bun 导出哪些符号：

```
BUN_1.2 {
    global:
        napi*;           ← 导出所有 napi 符号
        node_api_*;      ← 导出所有 node_api 符号
        syscall;         ← 导出 shim 的 syscall
        close_range;     ← 导出 shim 的 close_range
        ...
    local:
        *;               ← 隐藏其他所有符号
};
```

**关键**：`local: *;` 的意思是"除了 `global:` 列表里列出的，其他全部隐藏"。

如果 shim 的 `epoll_ctl` **不在** `global:` 列表里 → 被 `local: *` 隐藏 →
`.node` 模块找不到 bun 的 `epoll_ctl` → 用 libc 原版 → 绕过了 shim 修复。

---

## 3. 问题是什么

### 3.1 shim 定义了 15 个函数

`ohos_compat_shim.c` 里定义了 15 个公共函数（会被外部调用的）：

| # | 函数 | 解决什么问题 |
|---|---|---|
| 1 | `close_range` | seccomp 拦截 → 用 close 逐个关闭 |
| 2 | `syscall` | 拦截 SYS_close_range + SYS_epoll_ctl |
| 3 | `getpwuid_r` | 无 /etc/passwd → fallback |
| 4 | `getaddrinfo` | 强制 AF_INET（OHOS 不支持 IPv6） |
| 5 | `getcwd` | hmdfs getcwd 失败 → fallback $PWD |
| 6 | `splice` | EPIPE-on-EOF 处理 |
| 7 | `epoll_ctl` | pipe readiness repair（T50 内核 bug） |
| 8 | `epoll_wait` | 同上 |
| 9 | `epoll_pwait` | 同上 |
| 10 | `poll` | 同上 |
| 11 | `ppoll` | 同上 |
| 12 | `close` | epoll pipe cleanup hook |
| 13 | `linkat` | SELinux EPERM → copy fallback |
| 14 | `symlinkat` | SELinux EPERM → copy fallback |
| 15 | `tmpfile` | hmdfs tmpfile → fallback |

### 3.2 linker.lds 只导出了 8 个

```
当前 linker.lds 的 global 列表：
  syscall, close_range, getcwd, getpwuid_r, tmpfile, linkat, symlinkat, splice
```

### 3.3 缺失的 7 个

| # | 函数 | 缺失的后果 |
|---|---|---|
| 1 | `epoll_ctl` | `.node` 模块的 epoll 不走 pipe repair → 事件丢失 |
| 2 | `epoll_wait` | 同上 |
| 3 | `epoll_pwait` | 同上 |
| 4 | `poll` | `.node` 模块的 poll 不走 pipe repair |
| 5 | `ppoll` | 同上 |
| 6 | `close` | `.node` 模块的 close 不走 cleanup hook → registry 残留 |
| 7 | `getaddrinfo` | `.node` 模块的 DNS 不强制 AF_INET → IPv6 可能失败 |

### 3.4 为什么 epoll 簇 + close 必须一起导出

OHOS 的 T50 内核 bug 是：epoll 管道（pipe）的就绪状态会丢失。
shim 的修复方案是：

```
1. epoll_ctl 注册时 → shim 记录到 registry（g_ep_pipes 数组）
2. epoll_wait 返回时 → shim 检查 registry，如果管道就绪但内核没通知，手动触发
3. close(fd) 时 → shim 从 registry 删除该 fd（cleanup）
```

这三个步骤**必须都用 shim 版本**，否则：
- 如果 `close` 用 libc 原版（没导出）→ registry 不会清理 → 残留条目 → 后续 fd 复用时读到脏数据
- 如果 `epoll_ctl` 用 libc 原版（没导出）→ registry 不会注册 → epoll_wait 的修复找不到需要修复的管道
- 如果 `epoll_wait` 用 libc 原版（没导出）→ 即使注册了，也不会做 readiness repair

所以 epoll 簇 + close 是**一个整体**，必须一起导出，不能只导出一部分。

---

## 4. 三方对比

| | 我们（当前） | social4hyq | ljy9812 |
|---|---|---|---|
| shim 定义函数数 | 15 | 15 | 15 |
| linker.lds 导出数 | 8 | ~18 | 8 |
| 缺失 | 7 个（epoll 簇 + close + getaddrinfo） | 0 | 7 个（和我们一样） |
| 后果 | `.node` 模块绕过 shim | `.node` 模块正常 | 和我们一样 |

social4hyq 的 linker.lds 注释说：
> "2026-08-18 validation pass: the shim now interposes 18 symbols total"

说明 social4hyq 在 8 月 18 日做了一次验证，把 shim 符号列表从 8 个补到了 18 个。
我们和 ljy9812 没有跟进这个更新。

---

## 5. 修复方案

在 `linker.lds` 的 OHOS shim 符号块里补上 7 个缺失的符号。

### 修改前（8 个）

```
/* ohos-compat-shim interposers ... */
syscall;
close_range;
getcwd;
getpwuid_r;
tmpfile;
linkat;
symlinkat;
splice;
```

### 修改后（15 个）

```
/* ohos-compat-shim interposers ... */
syscall;
close_range;
getcwd;
getpwuid_r;
tmpfile;
linkat;
symlinkat;
splice;
getaddrinfo;
epoll_ctl;
epoll_wait;
epoll_pwait;
poll;
ppoll;
close;
```

### 注意事项

- `close` 和 `epoll_ctl`/`epoll_wait`/`epoll_pwait`/`poll`/`ppoll` 在非 OHOS
  平台上是 libc 的导入符号（UND）→ `--version-script` 对 UND 符号赋版本会报错
- 我们已经在 PR #4 里加了 `--undefined-version` 到 Linux link flags，
  所以非 OHOS 平台上 lld 会忽略这些 UND 符号的版本赋值
- 不需要修改 `ohos_compat_shim.c`（函数已经定义好了，只是没导出）

---

## 6. 涉及的文件

| 文件 | 改动 |
|---|---|
| `src/linker.lds` | 补 7 个 shim 符号到 global 列表（7 行） |

---

## 7. 验证方法

1. OHOS build 编译通过
2. 设备上 `readelf --dyn-syms bun | grep epoll_ctl` 确认导出
3. 设备上 `readelf --dyn-syms bun | grep 'close\b'` 确认导出
4. `.node` 模块测试（如果有的话）

---

## 8. 术语速查

| 术语 | 解释 |
|---|---|
| **shim（垫片）** | 重新实现有问题的函数，让程序不崩溃 |
| **ohos_compat_shim.c** | OHOS 兼容垫片的源文件，定义了 15 个 shim 函数 |
| **`.dynsym`（动态符号表）** | 二进制里"对外开放"的符号列表 |
| **`linker.lds`** | version-script 文件，控制哪些符号导出 |
| **`global:`** | version-script 里"要导出"的符号列表 |
| **`local: *`** | 隐藏所有没在 global 里列出的符号 |
| **`.node` 模块** | 编译好的原生插件，通过 `dlopen` 加载 |
| **`dlopen`** | 动态加载一个 .so/.node 文件到进程里 |
| **`RTLD_NEXT`** | dlsym 的标志：查找"下一个"同名符号（即 libc 原版） |
| **epoll 簇** | epoll_ctl + epoll_wait + epoll_pwait + poll + ppoll |
| **registry（g_ep_pipes）** | shim 维护的管道注册表，记录哪些 fd 需要修复 |
| **pipe readiness repair** | OHOS T50 内核 bug 的修复：手动触发内核漏掉的事件 |
| **`--undefined-version`** | lld 参数：允许 version-script 给 UND 符号赋版本 |

---

*文档日期：2026-08-31 | 分析者：Sisyphus*
*关联文件：`src/linker.lds`、`scripts/build/shims/ohos_compat_shim.c`*
*关联 PR：PR #4（已加 `--undefined-version` 到 Linux link flags）*
