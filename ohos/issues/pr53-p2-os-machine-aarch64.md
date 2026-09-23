# P2: os.machine() 在 OHOS 误报 "arm64"（应为 "aarch64"）— 归档文档

> **关联 PR**：[#53](https://github.com/jx-bit/bun/pull/53)（单 commit
> `5b812deb4c`，1 文件 1 行，base `ohos-aarch64` tip `ee8ebba8bd`）
> **状态**：✅ 合并（486aeecba2）
> **一句话**：在鸿蒙设备（arm64）上，JS 里的 `os.machine()` 返回
> `"arm64"`，但按 Node 语义应该返回 `"aarch64"`——一行修复。
> 本文档 §5 另附同批扫描出的 **IS_MUSL/IS_OHOS 待决策项**的白话说明。

## 0. 证据来源与参照线地位

**参照线不是官方**（独立 OHOS 移植线，非 oven-sh 上游、非规范来源）。
本 PR 与参照线逐字一致且仅 1 行，正确性直接由 Node 文档语义背书：
`os.machine()` 规定为 `uname(2)` 的 machine 字段，而 arm64 Linux 上
`uname -m` 输出就是 `aarch64`——不需要参照线背书，参照线只是同样改了
这一行的先行者。

## 1. 问题到底是怎么回事

### 1.1 os.machine() 是干什么的

`os.machine()` 是 Node 的标准 API，回答"这台机器的 CPU 是什么架构"。
Node 文档规定它返回 **`uname(2)` 的 machine 字段**——即在 Linux 终端敲
`uname -m` 看到的那个词。arm64 的 Linux 上，`uname -m` 输出 **`aarch64`**
（这是 ARM 官方在 Linux 世界的命名；`arm64` 是 Apple/另一套语境的叫法）。

### 1.2 bun 现状代码错在哪

`src/js/node/os.ts` 的 `machine()`：

```js
return process.arch === "arm64"
  ? process.platform === "android"      // ← 只特判了 Android
    ? "aarch64"
    : "arm64"                           // ← OHOS 落到这里
  : ...
```

Android 被特判成 `"aarch64"`（Android 内核 uname 同样报 aarch64），但
OHOS 平台（`process.platform === "openharmony"`）没进这个特判 → 设备上
`os.machine()` 返回 `"arm64"`。上游代码里的 TODO 注释自己都承认
"linux arm64 should also return aarch64 (Node/uname compat)"——只是
上游一直没修。

### 1.3 实际影响

凡是拿 `os.machine()` 判断"这是台什么架构的机器"的工具都会误判——典型
场景：按 `os.machine()` 拼 URL 下载对应架构的二进制/工具链（找
`arm64` 目录而实际该找 `aarch64`）、平台探测库输出错误架构名。
对这类工具，设备上是功能性故障，不只是显示问题。

## 2. 修复

一行（与参照线逐字一致）：

```diff
       return process.arch === "arm64"
-        ? process.platform === "android"
+        ? process.platform === "android" || process.platform === "openharmony"
           ? "aarch64"
           : "arm64"
```

其它平台（linux/mac/windows/freebsd x64 & arm64）的返回值**零变化**
——该分支只在 `process.platform === "openharmony"` 时新增生效，CI 各
lane 都跑不到这行的新路径。

## 3. 验证

- **未修复构建上必失败声明**：arm64 OHOS 设备 `os.machine()` 返回
  `"arm64"`；修复后返回 `"aarch64"`（= `uname -m`）。
- 设备验收：`bun -e "console.log(os.machine())"` → `aarch64`。
- os.ts 是打包内建 JS 模块，无原生编译面；随 CI 打包链路验证。

---

## 5. 同批扫描的待决策项（IS_MUSL / IS_OHOS，**未实施，需要拍板**）

这是默认值对比时发现的另一族差异。**不是马上要修的 bug，而是一个需要
先回答一个问题再动手的改造**。下面把背景、现状、选项讲清楚。

### 5.1 背景：IS_MUSL / IS_OHOS 是什么

代码里有三个地方需要知道"当前系统用的 libc 是哪一种"（musl 还是 glibc
还是 bionic），据此选择不同的行为。判断依据是编译期常量：

- 我方树：`IS_MUSL = target_env 是 musl`（**OHOS 不算**，尽管 OHOS 的
  libc 实际就是 musl）、**没有 IS_OHOS 常量**。
- 参照线：`IS_MUSL = musl 或 ohos`、另有独立的 `IS_OHOS` 常量。

### 5.2 三个消费点在设备上的现状（逐个说人话）

**① `bun upgrade`（upgrade_command.rs）**
升级命令拼下载文件名：`bun-<平台>-<架构><libc后缀>.zip`，后缀规则：
musl→`-musl`、android→`-android`、其余→空（= gnu/glibc）。
设备上现状：OHOS 不算 musl → 后缀为空 → 去下载 **glibc 版**的 bun——
在 musl 系统上根本跑不起来。无论填什么都比现状好，但**填什么取决于
我们的发布渠道里实际有哪些命名的资产**（见 5.3）。

**② `bun build --compile`（compile_target.rs）**
编译出的单文件 exe 内嵌元数据："我是为哪个 os/架构/libc 构建的"
（`Libc::Default`=glibc / `Musl` / `Android` 三选一）。设备上现状：OHOS
被记成 `Default`(glibc)——**标签错误**（设备明明是 musl）。参照线加了
第四个枚举值 `Libc::Ohos`（注释：HarmonyOS，musl 系，npm 产物独立）。
影响面：主要是元数据正确性 + `--target=bun-linux-aarch64-ohos` 这类
交叉编译目标能否被解析。

**③ NAPI 原生模块检查（libc_check.rs）**
加载 `.node` 原生模块前，检查它是不是 glibc 编译的（musl 系统加载
glibc 模块会炸出很难看的 dlopen 错误；这个检查提前给出干净的报错）。
**该检查只在 musl 上启用**。设备现状：OHOS 不算 musl → 检查被跳过 →
加载 glibc 的 .node 模块时直接炸出底层错误，用户不知道原因。
**这是三者里对设备用户价值最高的**——且它不需要任何新命名约定，
只要 IS_MUSL 把 ohos 算进去就自动生效。

### 5.3 参照线的实证答案（2026-09-21 核验）

**参照线的"资产"有两层，名字不一样：**

1. **真机实际安装/升级的资产 = homebrew bottle**（实证：tap formula
   `social4hyq/homebrew-core` 的 `Formula/b/bun.rb`）：
   - bottle 文件名 `bun--1.4.2-r13.arm64_ohos.bottle.tar.gz`——homebrew
     标准命名（formula 名 + 版本 + revision + **平台 tag `arm64_ohos`**，
     与上游 `arm64_linux` tag 同构；harmonybrew 这个 Homebrew fork 在
     OS 表里加了 ohos）；
   - 托管在 **atomgit**（`root_url .../releases/download/bun-v1.4.2-r13`）；
   - formula 的 source 指向上游官方 tag `bun-v1.4.2` + `revision` 字段填
     他们 fork 分支的 commit SHA，配 per-file patch 系列（export 自其
     分支，replay check 逐字节复现 tip）；CI 自动构建 bottle → 上传 →
     automerge；装机 `brew install/upgrade bun`（真机 `~/.harmonybrew/bin/bun`）。
2. **`bun upgrade` 客户端拼的 zip 名** = `bun-linux-aarch64-ohos.zip`
   （编译期常量三段：`PLATFORM_LABEL`="linux"（OS 枚举 fold，复用上游
   npm_name）+ `ARCH_LABEL`="aarch64" + `SUFFIX_ABI`="-ohos"（IS_OHOS
   插在最前），命名惯例显式对齐上游 android 先例）。**但这个资产任何
   release 页面都没有**：下载域名编译期写死 `github.com/oven-sh/bun`，
   参照线没有改；官方 release 实测只有 `-musl`/`-android`，无 `-ohos`；
   参照线自己的 GitHub 也无 releases。→ **参照线真机升级实际走
   harmonybrew（brew upgrade），不走 bun upgrade**；`-ohos` 后缀是
   "命名就位、等自建 release 闭环"的占位（`GITHUB_API_DOMAIN` env 可指
   自建镜像，那是唯一让它生效的方式）。

### 5.4 三个选项（含实测后果）

| 选项 | `bun upgrade` 在设备上的实际后果 |
|---|---|
| 现状（空后缀 → 下载 `bun-linux-aarch64.zip` = 官方 **glibc** 包） | **最差**：下载成功、musl 设备跑不起来 → 用不能运行的二进制覆盖自己（变砖） |
| **B. `-musl` 后缀** | 下载官方 musl 包（实测存在、musl 能跑），**但丢掉我们全部 OHOS 适配**（#26-#53）→ 升级"成功"实为静默降级 |
| **A. `-ohos` 后缀** | 404（诚实失败、保留当前版本）——除非我们自建 release 真的发这个资产，或把写死的 oven-sh 下载域名改掉（参照线没改域名，靠 brew 分发绕开） |

**决策问题因此拆成两个**：
1. 设备上 `bun upgrade` 要不要做成"真可用"？若要 → 必须自建 release
   资产 **且** 改客户端写死的下载 URL（额外代码改动，参照线也未做）。
2. 若暂不做（维持"404 诚实失败"），后缀选 `-ohos`（对齐参照、语义正确）
   ——同时真实分发通道走我们的 tap/release 体系（可仿照参照线的
   bottle 模式）。

**建议**：先落 A 的命名 + NAPI 诊断（IS_MUSL 加宽 + IS_OHOS 常量 +
三消费点），接受 `bun upgrade` 404（比现状变砖好）；分发/升级闭环另立
专项（涉及发布流水线 + URL 改造，超出本主题）。

**→ 决策已拍板（2026-09-21）：`-ohos`。已实施于
[#54](https://github.com/jx-bit/bun/pull/54)**（含 IS_MUSL 加宽、
IS_OHOS/IS_GLIBC 常量、SUFFIX_ABI 首位、Libc::Ohos 变体；NAPI 预检
随 IS_MUSL 加宽自动启用）。参照线分发机制实证（bottle `arm64_ohos` @
atomgit、`bun upgrade` 拼名从未闭环）与后果矩阵见
[pr54 文档](pr54-p2-is-ohos-libc-detection.md) §3。
