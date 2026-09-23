# OHOS 知识库 — 代码签名与 spawn 机制从零讲

> 菜鸟友好版。从"程序是怎么跑起来的"讲到"为什么一次签名校验修复让全量测试翻倍"，
> 并完整对比 social4hyq 的实现。本文是
> [`../analys/archive/ci-forensics-5c0a93130-vs-3c97d0089.md`](../analys/archive/ci-forensics-5c0a93130-vs-3c97d0089.md)
> 的原理展开篇；所有代码事实都标注了文件与行号，可自行核对。

---

## 0. 术语表（先看这个）

| 术语 | 一句话解释 |
|---|---|
| **进程** | 运行中的程序实例。程序是磁盘上的文件，进程是它被加载进内存后正在执行的样子 |
| **ELF** | Linux/鸿蒙的可执行文件格式（Executable and Linkable Format）。bun、node、编译产物都是 ELF |
| **section（节）** | ELF 内部的"分区"，如 `.text`（代码）、`.data`（数据）、`.bun`（bun 自定义：内嵌 JS 模块图）、`.codesign`（鸿蒙自定义：签名） |
| **exec** | 内核"把一个 ELF 文件变成进程"的动作。签名校验就发生在这里 |
| **spawn** | 创建子进程（父进程拉起另一个程序）。`Bun.spawn()` 是 bun 的 API，底层走 `posix_spawn()` |
| **posix_spawn** | libc 提供的"创建子进程"系统调用封装（fork+exec 的现代合并版，开销更小） |
| **argv0** | 被 spawn 的程序文件路径（命令行第一个元素） |
| **SHA256** | 哈希函数：任意内容 → 固定 32 字节"指纹"。改 1 个字节，指纹完全不同 |
| **merkle 树** | 分页哈希再逐层合并的树状指纹结构（fs-verity 用它做到"逐页校验"） |
| **stub（毛坯）** | `bun build --compile` 时被复制来当"壳"的 bun 可执行文件本体 |
| **EACCES** | errno 13，"权限被拒"。鸿蒙内核验签失败时返回它 |
| **strip** | 从 ELF 里摘除某个节的操作 |

---

## 1. 基础：程序是怎么"跑起来"的

### 1.1 双击运行 → 内核做了什么

磁盘上的 `bun` 只是一堆字节。执行 `./some-program` 时，内核做一次 **exec**：

```
① 读文件头，确认是合法 ELF
② （鸿蒙定制）验证 .codesign 段 —— 见 §2   ← 签名关卡在这里！
③ 读取 PT_INTERP：动态链接器路径（鸿蒙 = /system/lib/ld-musl-aarch64.so.1）
④ 加载器把 ELF 的各个段映射进内存，链接动态库（NEEDED 列表）
⑤ 跳到程序入口点 → 进程诞生
```

任何一步失败，调用方拿到错误：②失败 = `EACCES`（权限拒绝）。

**关键认知：签名校验是"exec 时刻"的一次性事件。** 文件躺在磁盘上不去执行它，签名坏不坏没人管；
一旦 exec，内核当场验，过不了就拒绝。

### 1.2 spawn：一个进程怎么创建另一个进程

`Bun.spawn({ cmd: ["/path/to/bun", "build", ...] })` 的完整链路：

```
JS 调用 Bun.spawn
  → src/runtime/api/bun/spawn.rs（JS 绑定层，组装选项）
  → src/spawn_sys/spawn_process.rs :: spawn_process_posix()   ← 我们的 OHOS 签名块在这里
  → libc posix_spawn(argv0, ...)                              ← 真正的创建
      内核 exec 流程（§1.1 的 ①~⑤）
  → 子进程开始运行，父进程拿到 pid 和管道
```

两个要点：

1. **posix_spawn 之前，父进程还有一次"把关"机会** —— 文件还没交给内核，父进程可以
   先读它、检查它、甚至改写它。我们的补签就卡在这个时机。
2. **spawn 是测试里的高频动作**：`bun install` 每个用例要拉子进程、shell 每条命令、
   compile 测试每个产物…… 全量测试树的 spawn 总次数以万计。**在 spawn 路径上做任何
   O(文件大小) 的事，都会被乘几万倍。**

---

## 2. 鸿蒙的代码签名机制

### 2.1 `.codesign` 段的物理布局

鸿蒙给 ELF 追加一个自定义节，字节布局（见 `src/ohos_sign/src/descriptor.rs`）：

```
┌──────────┬───────────────────────────┬───────────┐
│ 8B 魔数   │ 256B 描述符                │ 32B 签名   │
│ (标识这是 │ ├ file_size (8B)：本报告   │           │
│  签名段)  │ │   描述的文件应有多大      │           │
│           │ └ merkle root (32B)：     │           │
│           │   整个文件内容的指纹        │           │
└──────────┴───────────────────────────┴───────────┘
```

把它想成一份**体检报告**：报告里写着"这份文件应该有 N 字节、指纹是 X"。

### 2.2 merkle 树：给 105MB 算指纹（带数字的例子）

不能直接 SHA256 整个 105MB（那样改 1 字节就要重算全部，也没法逐页校验），
fs-verity 的做法是**分页 + 分层**：

```
第 1 步（叶子层）：105MB ÷ 4KB ≈ 26,910 页，每页算一个 SHA256
   page_0 → h_0, page_1 → h_1, …, page_26909 → h_26909

第 2 步（中间层）：每 128 个哈希（128×32B=4KB）打包成一页，再各算一个 SHA256
   26,910 个 → 211 个中间哈希

第 3 步（重复第 2 步）：211 个 → 2 个 →
第 4 步（根）：最后一层装进一页，SHA256 一次 → 根哈希（root，32B）
```

性质：**文件里任何一个字节变了，从那一页开始所有上层哈希都变，root 必然变。**
（代码：`src/ohos_sign/src/merkle.rs`，与鸿蒙上游 merkle_tree_builder 逐位对齐；
SHA256 是 `src/ohos_sign/src/sha256.rs` 的 132 行纯软件实现，**未用 ARM 芯片的
SHA 加速指令**，速度约 100~200MB/s。）

### 2.3 内核验签流程

```
exec(file)
  内核：找到 .codesign 段 → 读描述符
    ├ file_size == 实际文件大小 ？        ← O(1)，只比一个数字
    └ 按文件现算一遍 merkle root == 报告里的 root ？   ← O(N)，重算 25,700 页
  两关都过 → 放行；任一失败 → EACCES
```

### 2.4 三种失败形态（对应三次历史问题）

| 形态 | 报告 vs 实际 | 现实对应 |
|---|---|---|
| **无段** | 根本没有报告 | CI 产出的 binary（构建时不签，见 artifact 实证：无 `.codesign` 节）→ 设备端 `ohos_selfsign` 补报告 |
| **尺寸不符** | 报告说 105MB，实际 107MB | **compile 产物**：stub 的报告被原样继承，payload 注入后文件变长 → 0902 轮 72 文件 EACCES |
| **内容不符** | 尺寸一样，指纹对不上 | 同尺寸篡改（测试树中不存在此场景） |

---

## 3. `bun build --compile`：单文件可执行程序是什么

### 3.1 它是什么、解决什么问题

普通分发 JS 程序：用户得先装 bun（或 node），再 `bun run app.ts`。
`bun build --compile` 把 **JS 代码 + bun 运行时**捏成一个独立可执行文件：

```bash
$ bun build --compile ./server.ts --outfile myapp
$ ./myapp        # 双击就能跑，机器上不需要装 bun
```

用户视角是"打包"；底层视角是"**给 bun 本体（壳）注入一段数据（馅）**"。

### 3.2 底层原理：stub + `.bun` 段（当前代码的真实做法）

bun 在**构建自己时**就预埋了一个空的 `.bun` 节（占位）。打包时
（`src/standalone_graph/StandaloneModuleGraph.rs :: inject()`，
Linux/FreeBSD 分支，`CompileTargetOs::Linux | Freebsd`）：

```
① clone：复制 bun 本体到输出路径（stub → 产物）
② read_to_end：把产物整个读进内存（~105MB）
③ write_bun_section(bytes)：把 JS 模块图（编译好的字节码+源码树）
   塞进 .bun 节 —— 节被"撑大"，其后所有节的位置整体后移，文件变长
④ 【仅 OHOS，PR#14 加】has_codesign？→ sign_selfsign_with_strip：
   摘掉继承来的过期 .codesign，对最终字节重算 merkle、写新报告
⑤ write_all + ftruncate + chmod 755：写回磁盘
```

为什么选"撑大既有节"而不是"文件尾追加"：`.bun` 节在 ELF 里是**有正式户口**的
（section header table 里有条目），运行时可以按节名精确定位，不依赖文件尾部布局。

### 3.3 运行时怎么找回这段 JS（壳怎么吃馅）

编译产物启动后，bun 需要找到自己的模块图
（`StandaloneModuleGraph.rs :: elf::get_data()`）：

- **OHOS 主路径**：打开 `/proc/self/exe`（自己的磁盘文件），**按文件偏移**找到
  `.bun` 节，mmap 进内存 —— 不依赖虚拟地址计算，天然绕开 PIE 地址随机化。
- **通用回退**：`BUN_COMPILED` 符号记录了 `.bun` 节的链接期虚拟地址（vaddr），
  运行时加上加载基址（load bias，从 `/proc/self/maps` 或 `find_loaded_module` 拿）
  得到实际内存地址。

拿到 payload 后按内部格式解析（长度前缀 + 模块图），还原出整个 JS 应用 → 执行。
（`get_data` 返回 `(指针, 长度)`，8 字节头存 payload 长度。）

### 3.4 为什么打包**必然**弄坏签名（时间线）

```
t0  stub 在磁盘上，.codesign 报告：file_size=105MB, root=X     【有效】
t1  clone + .bun 节撑大 → 内存里的产物 107MB，报告还是 t0 那份
t2  写盘。此刻磁盘上的产物：报告说 105MB/X，实际 107MB/Y       【已失效】
t3  用户/测试 exec 产物 → 内核：尺寸都不对 → EACCES
```

**不修的三种结局**（历史上全发生过）：

| 结局 | 场景 |
|---|---|
| compile 时重签（§3.2 步骤④） | 正解。social4hyq 一直这么做（见 §5）；我们 a09c 加过、46557185da 误删、PR#14 找回 |
| spawn 时补签 | 兜底。前提是检查能识别"过期报告"（`has_codesign` 识别不了 → 0902 的 72 文件挂） |
| 谁都不管 | 产物永久 EACCES，所有 compile 测试全灭 |

### 3.5 修复的代码位置对照

| 方 | compile 重签位置 | 说明 |
|---|---|---|
| 我们（PR#14 后） | `StandaloneModuleGraph.rs:1760`（inject 内，写盘前） | `has_codesign → sign_selfsign_with_strip`（内存中 strip+重签后再写盘） |
| social4hyq | `runtime/cli/build_command.rs:1030` + `runtime/api/js_bundle_completion_task.rs:469` | 写盘并 fsync **之后**对文件 `sign_selfsign_inplace_with_strip`，再 chmod 755 |

位置不同（一个在图构建层、一个在命令/API 完成层），语义相同：**产物落盘的那一刻签名就是好的**。

---

## 4. spawn 补签：两种策略与成本数学

### 4.1 为什么 spawn 处会有补签（背景）

spawn 的目标文件不一定是 bun 自己创建的：测试装依赖时拉起的 `.node` 原生模块、
git clone 下来的二进制、用户编译的 fixture…… 这些文件没人给它签过名。
消费版鸿蒙内核 exec 一律验签 → 无段文件全挂（0902 轮 72 文件 EACCES 的另一半）。
所以 bun 在 `spawn_process.rs`（`#[cfg(target_env = "ohos")]` 块，调用 posix_spawn **之前**）
对 argv0 指向的 ELF 做检查修复。

### 4.2 两种策略

```rust
// 旧（535）：O(1) —— 只看"有没有报告"，不验证报告真伪
if !ohos_sign::has_codesign(&bytes) {        // 解析节表，微秒级
    ohos_sign::sign_selfsign_inplace(p);     // 无段才签
}
// 漏洞：compile 产物的段"存在但过期" → 被短路 → 永久 EACCES

// 新（0903，PR#14）：O(N) —— 重新算一遍指纹，验证报告真伪
if !ohos_sign::has_valid_codesign(&bytes) {  // file_size 比对(O(1)) + 全文件 merkle 重算(O(N))！
    ohos_sign::sign_selfsign_inplace_with_strip(p);  // 过期则 strip + 重签
}
```

### 4.3 成本数学（为什么是 0.5~1.1 秒）

```
bun 本体 105MB（artifact 实测 110,214,128 字节）
  ÷ 4KB/页 ≈ 26,910 页
  × 软件 SHA256（~100-200MB/s，无硬件加速）
  = 每次 spawn 0.5~1.1 秒 纯哈希（还不算 105MB 的读）
× 全量测试树 ~万次级 spawn
  = 实测：总时长 9164s → 19135s（+109%），TOP30 变慢全是 spawn 密集文件
```

三个放大器：**① 无缓存**（同一文件每次 spawn 都重算，不按路径/mtime/size 记忆）；
**② 同步**（在父进程 JS 线程上，24 并发 spawn 串行排队 → 32492 的 22.5s）；
**③ 常见情形全额收费**（`has_valid_codesign` 先比 file_size —— compile 场景这一步
就能查出问题、轮不到 merkle；merkle 只对"已经正确的文件"跑满，防的是测试树里
不存在的"同尺寸篡改"）。

### 4.4 正解：让常态零成本

核心思路（已定案推荐）：**让内核（本来就必验的那一方）当唯一的裁判，bun 只在内核
说"不行"时才出手补签。** bun 目前的每次 spawn 验签是纯冗余 —— 它验完内核还要再验，
bun 那遍既不省内核的时间、也不产生任何安全增益。

| 方案 | 思路 | 常态成本 | 状态 |
|---|---|---|---|
| **B. 懒模式（已实施）** | **先直接 posix_spawn**；内核报 EACCES/EPERM 才"读→校验→strip→重签→重试一次" | **0**（只在真坏时付费一次） | ✅ 2026-09-04 实施，待真机复测 |
| A. 结果缓存 | 按 `(path, mtime, size)` 记住校验结果 | 首次 O(N)，之后 O(1) | 备选 |
| C. 写路径全覆盖 | 学 social4hyq：保证所有文件出生即有效，spawn 完全不查 | 0（但依赖内核不强制，见 §5.4） | 长期方向，不可单独采用 |

方案 B 与 dlopen 路径 2026-07 起就有的"EPERM → sign-and-retry"模式完全同构 —— 等于把
已有模式复制到 spawn（`src/sys/lib.rs:6098` 的 ensure_signed 是先签后开，install
路径则和旧 spawn 一样是 O(1) 门控）。实施注意：EACCES 也可能来自 seccomp 等别的原因，
重试后仍失败必须返回**原始错误**，不能吞掉；补签失败同样要透传原错误。


---

### 4.5 常见疑问：bun 本体已经签名了，spawn 时到底做了什么？怎么又要"签名"？

**澄清：bun 本体在 spawn 时永远不会被重新签名。** 代码是一个三分支：

```
spawn 前读 argv0 文件 → has_valid_codesign(验签：重算 merkle 比对报告)
  ├─ 报告有效（bun 本体、安装过的二进制）→ 什么都不写，直接 posix_spawn
  ├─ 无段（测试 fixture、下载的二进制）    → 首次签名（写一次 .codesign，之后有效）
  └─ 报告过期（compile 产物）             → strip 掉旧报告 + 重签（每文件只发生一次）
```

贵的是**验**（0.5~1.1s 的全文件 merkle 重算），不是**签**：

| | 验签（validation） | 签名（signing） |
|---|---|---|
| 做什么 | 读全文件重算 merkle，和报告比对 | 算 merkle **并写入**新报告 |
| 什么时候发生 | **每次 spawn 都发生**（对任何文件） | 仅验签失败时，且每文件通常只一次 |
| 对 bun 本体 | 每次都做（这就是 S2 税） | 永不发生（它本来就有效） |
| 成本 | O(N) 读+哈希 | O(N) 哈希 + O(N) 写（更贵，但罕见） |

**为什么明知道它有效还要每次验？** 因为 spawn 时 bun 无法事先区分"这是有效的 bun 本体"
还是"这是没签过的 fixture"还是"这是过期的 compile 产物"—— 只能查。而查 = 全文件哈希。

**更根本的问题：这次验签是纯冗余。** bun 验完放行后，内核在 exec 时**还会再验一次**
（§2.3）。等于同一份文件、同一次 exec 被哈希了两遍 —— bun 那遍白做。这就是 §4.4
三个方案（缓存/懒模式/写路径全覆盖）能省掉的根源：让"检查"只发生在有必要的时刻。

## 5. social4hyq："spawn 完全不碰"，功能怎么实现？

### 5.1 "不碰"的精确含义

"spawn"指程序创建子进程这件事本身（§1.2）。**social4hyq 没有删除/绕过 spawn 功能** ——
他们的 `Bun.spawn`、`bun test` 拉子进程、shell 命令全都正常工作。**"不碰"指的是：
他们的 spawn 路径里没有任何"读文件验签/补签"的逻辑。**（准确说：他们的 spawn 里有
两处 OHOS 特殊块，但做的是 **shebang 手动展开**，见 5.2 表格最后一行 —— 目的同样是
绕开内核签名关卡，而不是做签名。）

代码对比（`src/spawn_sys/spawn_process.rs`）：

```
我们：  ... spawn_process_posix() {
          ...
          #[cfg(target_env = "ohos")] {          ← 签名块（PR#14 起 O(N) 校验）
              读 argv0 文件 → has_valid_codesign? → 必要时重签
          }
          posix_spawn::spawn_z(...)
        }

他们：  ... spawn_process_posix() {
          ...
          #[cfg(target_env = "ohos")] {          ← shebang 手动展开（不是签名！见下）
          posix_spawn::spawn_z(...)              ← 对 argv0 文件本身零签名操作
        }
```

他们树里的 `target_env = "ohos"` 出现处都是**排除型**（如 `not(target_env = "ohos")`
走 memfd 快路径），没有一处读文件验签。

### 5.2 那功能怎么实现？—— 把签名挪到"出生时刻"

他们不是"不处理签名"，而是**在每个文件被创建的那一刻就把它签好**。覆盖地图
（全部是写路径，全部 O(1) 门控或无脑签）：

| 文件怎么出生 | 谁负责签名 | 代码位置 |
|---|---|---|
| `bun build --compile` 产物 | CLI 编译命令写完 fsync 后立即 strip+重签 | `runtime/cli/build_command.rs:1030` |
| `Bun.build()` JS API compile 产物 | 打包任务完成回调里同样处理 | `runtime/api/js_bundle_completion_task.rs:469` |
| `bun install` 装的 `.so`/`.node` 原生模块 | 安装器落盘时签 | `install/PackageInstaller.rs:2541`（`has_codesign` O(1) 门控） |
| `dlopen` 的目标库 | dlopen 前检查补签 | `src/sys/lib.rs:6159` |
| **shebang 脚本**（`#!/usr/bin/env bun` 之类） | **不让内核 exec 脚本**：spawn 时手动解析 `#!` 行，改为 exec **已签名的解释器**，脚本路径降级为普通 argv（只被打开读取，永不过签名关卡） | `src/spawn_sys/spawn_process.rs:987`（详解见 §5.6；另修复了 128 字节 binfmt_script 限长被深层 TMPDIR 路径截断的坑） |
| bun 本体 | 安装/部署环节（brew/安装脚本自签） | 仓库外 |

> 注：shebang 展开就是 failure-analysis.md 行动项 P3 提到的"social4hyq 方案" ——
> 我们尚未实施（`spawn_process.rs:981` 的适配债），详见该文档 §六。

### 5.3 生命周期视角：签名状态流

```
             出生（创建/落盘）            使用（exec/dlopen）
              ┌──────────────┐           ┌──────────────┐
social4hyq：  │ 写路径立刻签名 │ ──有效──→ │ 内核验签，通过 │   读路径零工作
              └──────────────┘           └──────────────┘
              ┌──────────────┐           ┌──────────────┐
我们(现状)：  │ compile 重签 ✅│           │ spawn 时再全量 │   读路径每次 O(N)
              │ 其他写路径部分✅│ ──?────→ │ 校验兜底（S2） │
              └──────────────┘           └──────────────┘
              ┌──────────────┐           ┌──────────────┐
我们(目标)：  │ 写路径立刻签名 │ ──有效──→ │ spawn 直接放行 │   懒模式：EACCES 才补签一次
              └──────────────┘           └──────────────┘
```

一句话：**他们把"验"的职责前置成了"保"的职责。** 每个文件出生时签名就有效，
spawn 时内核自然放行，不需要 bun 再做任何事。

### 5.4 为什么他们敢这么做，我们不能直接照搬

| 差异点 | social4hyq | 我们 |
|---|---|---|
| 运行环境 | Harmonybrew/OpenHarmony 体系（自建发行版布局，`/usr/lib/libc.so` 有效、bottle 生态自洽） | 消费版鸿蒙 PC（HarmonyOS 5） |
| 内核强制表现 | **文档对签名零讨论**，runner（node）直接 spawn，从未见 EACCES 类问题记录 | **实测强制**：0902 轮无段文件 spawn 72 文件 EACCES 铁证 |
| 测试文件来源 | 受控（brew 体系内分发，链路上有签名保障） | 测试树包含 git clone/编译 fixture/第三方二进制，来源不受控 |

结论：**在消费版设备上，spawn 兜底不能删**（删了就回到 0902 之前的 EACCES 世界），
但必须改成 §4.4 方案 B 的懒模式 —— 常态零成本，保住兜底语义。

### 5.5 其他两处差异（同一轮取证中发现）

- **libunwind**：他们动态链接自家交叉编译的 `libunwind`（`-lunwind`，随包分发 .so，
  测试时 `LD_LIBRARY_PATH` 指向）；我们静态 `-l:libunwind.a`（因为目标设备/CI 镜像
  上没有这个 .so）。静态化本身无证据致害（见 findings §F）。
- **测试 harness 的 libc 路径**：他们的设备 `/usr/lib/libc.so` 是有效文件，裸名
  `dlopen("libc.so")` 能命中；我们消费版设备该路径损坏 → PR#15 改显式 loader 路径
  （`/system/lib/ld-musl-aarch64.so.1`）。
- **测试方法论**：他们 4751 文件 / 20 核 / 三阶段复核（全量 → 低并发复测剔除并发假象
  → 隔离单跑复核），并明确记载 **32492 并发下失败、完全隔离单跑 100% 通过** ——
  独立佐证我们"32492 是负载类失败"的定性。

### 5.6 详解：shebang 手动展开 —— 他们的脚本签名绕行方案

> 这是 failure-analysis.md 行动项 P3 说的"social4hyq 方案"（我们尚未实施，
> `spawn_process.rs:981` 的适配债）。与我们的懒修复互补：懒修复解决
> "**无段/过期的 ELF** 不能 exec"，shebang 展开解决"**文本脚本**根本无法 exec"。

#### ① shebang 是什么（背景）

一个文本脚本的第一行如果以 `#!` 开头（如 `#!/bin/sh`、`#!/usr/bin/env bun`），
这行叫 **shebang**。普通 Linux 内核有个叫 **binfmt_script** 的特性让脚本可以被
"直接执行"：

```
$ ./run.sh          # 内核实际执行的是：
                    # /bin/sh ./run.sh
```

内核的透明做法：exec 一个文件时发现头两个字节是 `#!` → 读出第一行里的
`解释器路径 [可选参数]` → **重新组织一次 exec**：argv0 换成解释器，脚本路径
塞进 argv（变成解释器的第一个参数）。

**关键：这条透明链路里，"被 exec 的文件"始终是那个脚本** —— 解释器是内核
代你指定的，脚本本身要先被内核"执行"一次。

#### ② 为什么鸿蒙上必然失败

鸿蒙的签名关卡（§2.3）作用于**每次 exec 的目标文件**。脚本 `.sh` 是文本文件
—— **文本文件没有地方放 ELF 的 `.codesign` 段**，永远不可能"签过名"：

```
execve("./run.sh")
  → 内核签名校验：./run.sh 有 .codesign 段吗？→ 没有
  → EACCES / EPERM（他们实测：要么拒绝、要么挂死）
```

所以任何"直接执行脚本"的测试在鸿蒙上全军覆没 —— 与 ELF 补签无关，
补签只对 ELF 有意义，脚本没地方写签名。

#### ③ 他们的方案：把内核的活搬到用户态干

思路一句话：**别让内核碰脚本 —— 我们自己解析 `#!` 行，直接 exec 解释器
（解释器是已签名的 ELF），把脚本降级成解释器的普通输入文件。**

```
用户请求：  spawn(["./run.sh", "--flag"])
              │ bun 在 spawn 前读 argv0 文件头
              ▼
文件头是 "#!/bin/sh" ？
              ▼ 是
重写 exec：  argv0  = /bin/sh                ← 已签名的 ELF，内核放行
             argv   = [/bin/sh, ./run.sh, --flag]
                          └─ 脚本只是普通参数
              ▼
             解释器正常打开并"读取" run.sh   ← 读文件 ≠ exec，不过签名关卡
```

这就是内核 binfmt_script 本来要做的事，但提前到用户态做 —— 脚本从头到尾
**没有被 exec 过**，签名关卡形同虚设。对上层完全透明：`Bun.spawn(["./run.sh"])`
的行为与其他平台一致。

#### ④ 实现细节（`spawn_process.rs:987-1088`，四个值得学的工程点）

**1）解析流程**（每步失败都安全回退到普通 spawn，绝不改变非脚本文件的行为）：
- 读 argv0 文件前 4096 字节；头两字节 ≠ `#!` → 原样放行
- 解析 `#!` 后的内容：跳过空白 → 按第一个空白切成 **解释器 + 可选单参数**
  （POSIX shebang 只允许一个参数）→ 去掉尾部空白和 `\r`（兼容 CRLF 脚本）
- 解释器必须是**绝对路径**（`/` 开头）→ 否则回退内核行为
- 组装新 argv：`[解释器, 可选参数, 脚本路径, ...原始参数]`

**2）128 字节截断坑（他们踩过的真实 bug）**：传统内核 binfmt_script 只读文件
**前 128 字节**找 shebang 行。他们的 OHOS 沙箱 TMPDIR 深层嵌套，解释器路径
经常 150+ 字节：

```
#!/storage/Users/currentUser/deep/nested/tmp/dir150+bytes/bun  ← 128 字节处被截断
                                    ↑ 截断后剩余部分"看起来仍是合法绝对路径"
→ 内核 exec 半截路径（一个目录）→ 报出误导性的 EACCES，真问题被掩盖
```

用户态解析用 4096 字节缓冲（PATH_MAX 余量），整类问题直接消失。

**3）无换行兜底**：4096 读满了还没遇到 `\n` → 说明 shebang 行可能更长 →
**放弃改写**（回退内核行为）而不是用半截数据 —— 宁可失败也不要静默截断
（和第 2 点是同一条设计原则的两面）。

**4）生命周期 keepalive**：`posix_spawn` 只收裸指针。改写后的解释器路径和
argv 数组必须**活到 spawn 调用结束**——他们用一个绑定变量
`_ohos_shebang_keepalive: Option<(CString, Vec<CString>, Vec<*const c_char>)>`
持有所有权，spawn 完成前不解构；改写失败时回退原始 `(argv0_cstr, argv)`。
这是 FFI 场景"指针的所所指内容必须有人持有"的典型范例。

#### ⑤ 与我们懒修复的关系（互补，不冲突）

| 场景 | 我们的懒修复 | 他们的 shebang 展开 |
|---|---|---|
| 无段/过期的 **ELF** | ✅ 内核拒绝 → repair → 重试 | —（不处理）|
| **文本脚本** | ❌ 不是 ELF → repair 返回 false → 原样失败（脚本无签名可补） | ✅ 绕开签名关卡 |
| 组合效果 | 两机制叠加 = 全覆盖：ELF 走懒修复，脚本走用户态展开 | |

**我们树上的状态**：✅ **已实施**（2026-09-04，dev 分支）。移植要点：
- 解析逻辑抽为独立模块 `src/spawn_sys/shebang.rs` 的纯函数 `parse_shebang(head, at_eof)`
  （cfg `any(ohos, test)` 门控）—— 纯字节解析可在任意 host 测试（10 个单元测试：
  CRLF / 可选单参数 / 相对路径拒绝 / 无换行兜底 / 128 字节坑两面）；
- 装配层 `ohos_expand_shebang`（cfg ohos）保留他们的 4096 缓冲、无换行兜底、
  keepalive 所有权语义（`_owned` 字段，下划线前缀标注"故意不读"）；
- 分层顺序 = **先 shebang 改写、后懒修复**：改写发生在首次 spawn 之前，
  因此修复重试自然指向解释器（脚本 → 解释器 → 修复解释器，链路有界）；
- source-lints 已钉住两个调用点（`ohos_expand_shebang` / `parse_shebang`）。


---

## 6. 一页复盘：完整因果链

```
07-07  87262b15b4   ohos_sign crate 落地（进程内自签，替代外部工具）
07-27  a09c4e3714   4 个签名调用点：spawn(O(1) 门控) / dlopen / install / compile(strip 重签)
                    ── 架构：写路径负责签名，spawn 只兜底无段文件
08-14  46557185da   上游 #38246(Android PIE) 重构 inject() 时把 OHOS compile 签名块丢失
                    （8月 binary 树不含此 commit → 其 compile 产物签名有效）
09-02  535 全量轮   stub 已签名 + compile 签名缺失 + spawn O(1) 短路
                    → 产物继承过期报告 → 72 文件（33%）EACCES
09-03  88a237b0e3   PR#14：compile 重签找回（✅）+ spawn 升级 O(N) 校验（意图✅，成本未评估）
09-03  0903 全量轮  spawn 税兑现：+109% 时长 → 32492/websocket-server/大消息 全变超时类假回归
09-04  取证结论     环境零漂移（F1-F6）；根因 S2；修复=懒模式/缓存（常态归零）；
                    dlopen P1 已由 PR#15 闭环
```

---

## 7. 参考索引

- 取证结论：[`../analys/archive/ci-forensics-5c0a93130-vs-3c97d0089.md`](../analys/archive/ci-forensics-5c0a93130-vs-3c97d0089.md)
- 任务书：[`../analys/archive/ci-forensics-5c0a93130-vs-3c97d0089.md`](../analys/archive/ci-forensics-5c0a93130-vs-3c97d0089.md)
- codesign-stub 完整分析（0902 铁证）：[pr14-p1-codesign-stub-inheritance.md](../issues/pr14-p1-codesign-stub-inheritance.md)
- dlopen P1（已闭环）：[pr15-p1-dlopen-libc-path-openharmony.md](../issues/pr15-p1-dlopen-libc-path-openharmony.md)
- 关键代码：`src/ohos_sign/src/{elf,merkle,sha256,descriptor}.rs`、
  `src/spawn_sys/spawn_process.rs`（OHOS 块）、
  `src/standalone_graph/StandaloneModuleGraph.rs`（inject/get_data）
- 关键 commit：`87262b15b4` / `a09c4e3714` / `46557185da` / `88a237b0e3` / `a1b9112d31`
- 对比仓库：`hyq/ohos-aarch64`（social4hyq/ohos-bun @ f6aec3047c）

---

*归档：Sisyphus | 2026-09-04 | 依据本地代码与两轮真机全量报告，全部结论可在标注的文件/行号核对*
