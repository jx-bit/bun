# P1: compile 产物继承无效 codesign 段 + spawn 补签短路 — 72 文件 EACCES
> **关联 PR**：[#14](https://github.com/jx-bit/bun/pull/14)（主修复）· [#16](https://github.com/jx-bit/bun/pull/16)（懒模式后续，2026-09-04）

> 真机全量测试（20260902，binary `535fb153c7-signed`）中 **72 个文件（占失败
> 33%）** 因 `posix_spawn EACCES` 失败。实验闭环定位：`bun build --compile`
> 产物**原样继承 stub 的 codesign 段**（段内 hash 描述的是 stub 而非产物），
> 而运行时补签逻辑被"段已存在"短路，永久跳过修复。
>
> 状态：**已实施并合并**（PR #14，单 commit，2026-09-03 合并至 ohos-aarch64）。
> 方案 A（spawn 校验重签）+ 方案 B（compile strip+重签）均已落地，
> 含 5 个单元测试。真机复测待下一轮 fulltest。
> 详见报告 `ohos/analys/20260902_fulltest_535fb153c7.zip` 的
> `failure-analysis.md`（hash 逐字节对齐铁证）。
>
> **后续（2026-09-04）**：方案 A 的 eager 校验引入了 O(N)/spawn 性能税
> （105MB 全文件 merkle 重算 × 全量测试数万次 spawn → 全量时长 +109%、
> 三个超时类假回归），CI 取证定位后已改为**懒模式**（内核拒绝才修复，
> 常态零成本）—— 见 §8，取证与定量证据见
> [`../analys/archive/ci-forensics-5c0a93130-vs-3c97d0089.md`](../analys/archive/ci-forensics-5c0a93130-vs-3c97d0089.md)。

---

## 1. 背景知识：鸿蒙 PC 的执行签名策略

鸿蒙 PC（HarmonyOS 5，HAD-W32）内核**拒绝执行未经签名的 ELF**。
签名机制：`ohos_selfsign` 工具对 ELF 追加 `.codesign` 段（内含
fs-verity 式的 file_size + hash），内核加载时校验"段内描述的文件
大小/哈希 == 实际文件"。

这条策略带来两类需求：

1. **被测 binary 本体**要有有效段 → 设备端 `ohos_selfsign` 签名解决
2. **binary 运行时产生的子进程/产物**也要有 → 运行时补签机制
   （`spawn_process.rs` 的 sign-on-spawn，PR #4 引入）

## 2. 问题是什么

### 2.1 我们的现状（两处缺陷叠加）

**缺陷 A：compile 产物继承 stub 的段**

`bun build --compile` 的实现（`src/standalone_graph/StandaloneModuleGraph.rs`
~line 1715+）：以当前可执行文件为 stub，clone 本体 → 向 `.bun` 段注入
payload → 写出产物。

```
stub（已签名，段内 hash = stub 本体，110,221,928 字节）
    ↓ clone + payload 注入（产物变大 2MB）
产物 112,218,656 字节，但 .codesign 段原样搬迁
    → 段内 file_size 110,221,928 ≠ 实际 112,218,656
    → 段内 hash ≠ 产物实际 hash
    → 内核校验失败 → EACCES
```

Linux/FreeBSD 分支**没有任何签名处理**（PE/Mach-O 分支有 strip/sign）。

**缺陷 B：spawn 补签被短路**

`src/spawn_sys/spawn_process.rs:986`（spawn 前的补签逻辑）：

```rust
if bytes.len() > 4 && bytes[..4] == [0x7f, 0x45, 0x4c, 0x46] {
    if !ohos_sign::has_codesign(&bytes) {          // ← 只判断"段存在"
        let _ = ohos_sign::sign_selfsign_inplace(p);
    }
}
```

compile 产物的段**存在但无效** → `has_codesign()` 返回 true → 跳过
补签 → 永久 EACCES。测试用例里 `bunExe()` 即被测 binary → 所有
compile 类测试必踩。

### 2.2 影响面（真机实测）

72 个文件（215 失败的 33%）：regression 25 / bundler 17 / js/bun 12 /
js/node 11 / napi 3 / cli 3 / workerd 1。所有 `bun build --compile`
相关测试全灭。

### 2.3 实验闭环（铁证，报告 failure-analysis.md）

| 产物 | 段内 hash | 段内 file_size | 实际大小 | 校验 | 执行 |
|---|---|---|---|---|---|
| 本轮 binary 的 compile 产物 | `ad530db2…` | 110,221,928 | 112,218,656 | **MISMATCH** | ❌ |
| stub 本体（被测 binary） | `ad530db2…` | 110,221,928 | 110,221,928 | MATCH | ✅ |
| 8 月 binary 的 compile 产物 | `1e1c99ab…` | 108,685,768（=实际） | 108,685,768 | **MATCH** | ✅ |

关键对照：**8 月 binary 的 compile 产物段 hash 是对产物自身计算的**
—— 8 月的私有构建流程会 strip 旧段并重签；本轮 binary 的构建
（revision 5c0a93130，私有 commit）该流程退化为直接搬迁 stub 段。

恒定性实验：payload 30B 与 1MB 的产物大小完全相同（112,218,656）、
段内容逐字节相同 → 与 payload 无关，纯 stub 遗传。

---

## 3. 几方对比

| 方 | spawn 补签 | compile 产物签名 | 依赖陪送 |
|---|---|---|---|
| **我们（dev）** | `!has_codesign()` 短路（ljy9812 原版） | Linux 分支无处理 | 无（裸 binary） |
| **ljy9812** | 同我们（原始来源，line 1003） | 同我们 | 无 |
| **social4hyq** | **无补签** —— 用 shebang 手动展开绕过（kernel 拒签非 ELF 脚本，展开后 exec 已签名的解释器） | 无源码级处理 | **bottle 模式**：brew 把 libunwind 等依赖瓶随包安装 |
| **上游 v1.4.0** | 无签名逻辑（0 处） | 无 | 不适用（无 exec 签名策略的平台） |

要点：

1. **共享版 libunwind.so.1 的来源**：链接参数 `-lunwind` 命中交叉库
   缓存的共享版（p0 自编译产物）。social4hyq 的 binary 同样带这个
   NEEDED，但他们的 **bottle 模式让依赖瓶陪送**到运行环境，所以
   永远能解析 —— 我们裸部署，故 PR #13 已改为 `-l:libunwind.a`
   静态自包含（本 issue 的 libunwind 部分随之消失）。
2. **social4hyq 的 shebang 展开**（`spawn_process.rs:981+`）是另一类
   签名策略问题的解法（脚本无法签名 → 手动展开 exec 解释器），
   我们的树没有这个处理 —— OHOS 适配债，可后续单独吸收。
3. **8 月 binary 的 strip+重签存在于私有构建管线**（binary 提供方的
   后处理），公开树（四方）都没有 —— 所以修复要落在我们自己的
   compile 代码里。

---

## 4. 修复方案

### 方案 A：spawn 补签条件升级（兜底层，1 个文件）

`spawn_process.rs:986`：`has_codesign()` → **校验段有效性**（段内
file_size == 实际文件大小 + hash 复算一致），无效即重签：

```rust
if !ohos_sign::has_valid_codesign(&bytes) {   // 新函数：校验而非仅存在性
    let _ = ohos_sign::sign_selfsign_inplace(p);
}
```

- 优点：兜底**任何来源**的失效段（compile 产物、手动改过的 ELF…）
- 成本：ohos_sign/elf.rs 增加一个校验函数（读段、比对 file_size/hash
  —— 逻辑与设备端 ohos_selfsign 的校验一致）
- 风险：低（重签是幂等操作，已有 sign_selfsign_inplace）

### 方案 B：compile 产出时 strip + 重签（产出层，正确性最佳）

`StandaloneModuleGraph.rs` Linux/OHOS 分支：payload 注入后、写盘前：

```rust
// strip 继承的 .codesign 段（ohos_sign 现成能力）
ohos_sign::strip_codesign(&mut output_bytes);
// 对完整产物重签（或留给首次 spawn 补签）
```

- 优点：产物**生来正确**；与 8 月私有构建行为对齐
- 成本：compile 热路径增加一次全文件 hash 计算（110MB → 数百 ms，
  compile 本身就是重操作，可接受）；需在容器/CI 验证 strip 后
  ELF 完整性
- 风险：低（strip_codesign 已有测试覆盖：ohos_sign/tests）

### 方案 C：构建期不带段（测试 binary 专项，短期缓解）

测试专用 binary 构建后 strip 段（不签名）→ 产物无段 → spawn 补签
（方案 A 修复后）即有效。仅适用于测试场景，不解决用户侧 compile。

### 推荐：**A + B 都做**

- B 让产物出厂即正确（用户侧 compile 可用）
- A 兜底所有其他来源的失效段
- 实施顺序：A 先（小，独立可验），B 后（需要真机验证 compile 输出）

---

## 5. 涉及的文件

| 文件 | 改动 |
|---|---|
| `src/ohos_sign/src/elf.rs` | +`has_valid_codesign()`（file_size + hash 校验）|
| `src/spawn_sys/spawn_process.rs:986` | 补签条件升级（方案 A）|
| `src/standalone_graph/StandaloneModuleGraph.rs` Linux 分支 | payload 注入后 strip + 重签（方案 B）|
| `src/ohos_sign/tests/` | 校验函数的单元测试（构造有效/无效段）|

---

## 6. 验证方法

1. **单元**：elf.rs 校验函数 —— 有效段 ✓ / 无段 ✓ / 段存在但
   file_size 不符 ✗ / hash 不符 ✗（四个 case）
2. **容器**（ci-runner lane，`filter=compile`）：compile 产物在容器内
   生成 + 执行（容器无签名策略，验证产物结构）
3. **真机**：部署新 binary → 跑 `bun build --compile` 用例 →
   72 文件的失败类别消失 → 全量通过率预计 +3~4 个百分点
4. **对照**：确认非 OHOS 平台不受影响（`when: c.ohos` gate 保持）

---

## 7. 术语速查

| 术语 | 解释 |
|---|---|
| codesign 段 | ELF 追加段，内含 file_size + hash，内核加载时校验 |
| fs-verity | 内核的文件内容校验机制，鸿蒙用它实施执行签名策略 |
| stub | `bun build --compile` 的模板：当前 bun 本体 clone 后注入 payload |
| sign-on-spawn | spawn 子进程前为其补签的运行时机制（PR #4 引入） |
| `-l:libunwind.a` | 链接器精确文件名语法，强制静态链接（PR #13 引入） |
| ohos_selfsign | 设备端签名工具（独立编译于 opencode/ohos-sign-build） |

## 8. 后续：方案 A 的成本反噬与懒模式修复（2026-09-04）

方案 A 落地后，20260903 真机全量（3c97d0089）暴露其代价：

- `has_valid_codesign` 对**每次 spawn** 做全文件 merkle 重算（105MB，纯软件
  SHA256，无缓存）≈ 0.5-1.1s/spawn；全量测试数万次 spawn → 总时长
  **9164s → 19135s（+109%）**，并伪装出三个超时类"确定性回归"
  （32492 / websocket-server / websocket 大消息，均非功能死锁）。
- 讽刺点：`has_valid_codesign` 内部先做 O(1) file_size 比对 —— 本 issue 的
  compile 遗传场景（文件变长）这一步即可判定，merkle 只对"已有效"的常见
  情形全额收费，防的是威胁模型中不存在的同尺寸篡改。
- 根因结构：bun 的验签与内核 exec 时的验签**完全重复**，bun 那遍无安全增益。

**懒模式修复**（内核当唯一裁判）：

| 调用点 | 新行为 |
|---|---|
| spawn（`spawn_process.rs`） | 先直接 posix_spawn；EACCES/EPERM 才 `repair_codesign_if_needed` → 文件被改写才重试一次 |
| dlopen（`sys/lib.rs`） | 同构（顺带修掉旧 presence-only 检查的过期段盲区） |
| install（`PackageInstaller.rs`） | 统一走 repair（patched native module 的过期段在安装时即修复） |
| compile（方案 B，不变） | 产物出生即有效 → 修复分支几乎不触发 |

- 新 `ohos_sign::repair_codesign_if_needed(path) -> bool`：非 ELF/已有效返回
  false 不动文件（原始错误透传）；regular-file 守卫（防 /dev/zero 无限读）。
- 修复事件打 `OhosSignRepair` scoped log（`BUN_DEBUG_OhosSignRepair=1` 可见）。
- 防 46557185da 复发：`test/internal/source-lints/ohos-sign-call-sites.test.ts`
  断言 4 个调用点存在，上游 merge 丢 hunk 时 CI 直接红。
- 状态：已实施（dev，待 PR 合并）。待设备复测：32492 / websocket-server /
  websocket.test.js 转绿 + 全量时长回落。

---

*文档日期：2026-09-03 | 分析者：Sisyphus | §8 增补：2026-09-04*
*依据：20260902 真机全量报告 failure-analysis.md（hash 闭环实验）+
四方源码对比（dev / social4hyq@f6aec304 / ljy9812 / bun-v1.4.0）*
*关联：p1-ohos-fulltest-lane-unblock.md、skills/16-device-fulltest.md*
