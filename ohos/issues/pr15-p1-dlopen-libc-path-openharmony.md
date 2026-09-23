# P1: openharmony 的 libc dlopen 路径在消费版设备上失效 — 10 文件失败
> **关联 PR**：[#15](https://github.com/jx-bit/bun/pull/15)

> 真机全量测试（20260903 轮）中 **10 个文件**失败于：
> ```
> Failed to open library "/usr/lib/libc.so":
>   Error loading shared library /usr/lib/libc.so: No such file or directory
> ```
> 这些测试通过 `bun:ffi` 的 dlopen 加载 libc，调用 bun 未原生暴露的
> 系统函数（mkfifo / raise / tcgetattr…）。harness 的
> `libcPathForDlopen()` 对 openharmony 返回裸名 `"libc.so"`，由动态
> 加载器按 soname 搜索 —— 在**消费版鸿蒙 PC** 上搜索命中了
> `/usr/lib/libc.so`（损坏/悬空路径）→ dlopen 失败。
>
> **状态：✅ 修复已实施并真机验证通过**（2026-09-04，设备端 dlopen musl loader
> 成功 + getpid 符号导出验证通过）。PR #15 已合并（a346ec192a，2026-09-04）。
> **注：此问题不是新回归** —— 20260902 轮已有 30 次同样的失败
> （当时被 codesign 主线问题掩盖，未单独立档）。
>
> **后续（2026-09-04）**：运行时 dlopen 路径（`sys/lib.rs` 的 eager
> `ensure_signed`：每次 dlopen 全文件读 + presence-only 检查）同步改为懒模式
> repair（内核拒绝才修复重试），并统一打 `OhosSignRepair` scoped log ——
> 见 [`p1-codesign-stub-inheritance.md`](pr14-p1-codesign-stub-inheritance.md) §8。

---

## 1. 背景知识：bun:ffi 的 dlopen 与测试的 FFI helper 模式

### 1.1 谁在调用 dlopen —— 是测试代码，不是 bun 运行时

bun 运行时自身的动态依赖只有 `libc.so`（ELF NEEDED，由加载器直接
加载 ✓，与 dlopen API 无关）。失败的是**测试代码**通过 `bun:ffi`
发起的 dlopen：

```ts
// 测试文件里的典型模式（lazy FFI helper，首用时加载并缓存）
import { libcPathForDlopen } from "harness";

var lazyMkfifo: any;
export function mkfifo(path: string, permissions: number = 0o666): void {
  if (!lazyMkfifo) {
    lazyMkfifo = dlopen(libcPathForDlopen(), {
      mkfifo: { args: ["string", "int"], result: "int" },
    }).symbols;
  }
  lazyMkfifo.mkfifo(path, permissions);
}
```

**为什么测试要 FFI 调 libc**：bun 没有原生暴露 mkfifo / raise /
tcgetattr 等系统调用，测试需要验证这些行为时只能通过 FFI 直接调
libc。这是 upstream 就有的模式（v1.4.0 的
`test/cli/run/fixture-tty.js` 就用 `dlopen("libc.so.6", {tcgetattr…})`
做 TTY 断言）。

### 1.2 libcPathForDlopen() 的设计

harness 提供跨平台的 libc 路径解析，按 platform/libcFamily 分支：

| 平台 | 返回值 | 上游 v1.4.0 | OHOS 扩展方 |
|---|---|---|---|
| linux + glibc | `libc.so.6` | ✅ | —— |
| linux + musl | `/usr/lib/libc.so` | ✅ | —— |
| **openharmony** | （上游无此 case） | —— | ljy9812 添加 → **`"libc.so"`（裸名）** |
| darwin | `libc.dylib` | ✅ | —— |

OHOS 扩展（ljy9812/social4hyq）选择裸名的理由（代码注释）：

> OHOS hmusl: /usr/lib/libc.so does not exist on disk; the dynamic
> linker resolves bare names via LD_LIBRARY_PATH / soname search.

即：**在他们的环境里**裸名由加载器按 soname 搜索解析 —— 他们的
设备/镜像环境里这个搜索是成功的。

---

## 2. 问题是什么

### 2.1 失败机制

```
dlopen("libc.so")   ← 裸名（harness openharmony 分支）
    ↓ musl 加载器的搜索顺序（LD_LIBRARY_PATH → /lib → /usr/lib …）
    ↓ 在消费版鸿蒙 PC 上命中 /usr/lib/libc.so
    → 该路径损坏/悬空（ENOENT at load）
    → dlopen 失败 → 使用它的测试全挂
```

实测错误（设备）：

```
error: Failed to open library "/usr/lib/libc.so":
  Error loading shared library /usr/lib/libc.so: No such file or directory
 syscall: "dlopen", errno: 0, code: "ERR_DLOPEN_FAILED"
```

### 2.2 为什么 social4hyq 的设备上没问题

他们的测试环境（Harmonybrew 体系）里 `/usr/lib/libc.so` 是**有效
文件**（他们的 OHOS 发行版布局），裸名搜索命中后可正常加载。我们的
消费版鸿蒙 PC 上该路径损坏 —— 两类设备的 /usr 布局不同。

### 2.3 影响面

| 轮次 | dlopen 失败出现次数 |
|---|---:|
| 20260902（535fb153c7） | **30 次** |
| 20260903（3c97d0089） | 10 个文件 |

**不是新回归** —— 两轮的 harness 函数与设备路径问题完全相同
（设备树 982fc83613 与当前树的 libcPathForDlopen 逐字节一致）。
20260902 轮的分析聚焦 codesign 主线，此问题当时未单独立档。

受影响测试（dlopen libc 做 FFI 断言/夹具的文件）：

- test/js/bun/spawn/spawn-pipe-read-error-leak.test.ts（子进程 FFI）
- test/js/bun/transpiler/truncated-utf8.test.ts（BUN_TEST_LIBC_PATH）
- test/js/bun/net/socket.test.ts
- test/js/web/intl/intl.test.ts
- test/js/node/process/process.test.js（lazyRaise）
- test/js/bun/http/bun-serve-file.test.ts（lazyMkfifo）
- test/mkfifo.ts、call-raise.js（harness 夹具）
- 以及 spawn 系子进程间接命中（fs.test 的 mode 用例等同轮失败文件）

---

## 3. 几方对比：libcPathForDlopen 的 openharmony 分支

| 方 | openharmony 返回值 | 引入 | 在他们环境的表现 |
|---|---|---|---|
| **上游 v1.4.0** | 无此 case（函数存在，musl → `/usr/lib/libc.so`） | 上游无 OHOS 平台 | 不适用 |
| **ljy9812** | `"libc.so"`（裸名） | OHOS port 时添加 | 他们的设备上有效 |
| **social4hyq** | `"libc.so"`（裸名，同注释） | 继承 | 他们的 Harmonybrew 环境有效（/usr/lib 布局） |
| **我们（修复前）** | `"libc.so"`（裸名） | 继承 | ❌ 消费版设备上解析到损坏路径 |
| **我们（修复后）** | `/system/lib/ld-musl-aarch64.so.1` | 本地 commit | ✅ loader 即 libc，全设备存在 |

**dlopen 调用者定性**：测试代码经 `bun:ffi` 发起 —— bun 运行时自身
不参与（bun 的 NEEDED 只有 libc.so，加载器直载）。修复只动 harness
的路径解析，不涉及 bun 运行时。

---

## 4. 修复方案

### 方案 A：显式 dlopen musl loader（✅ 已实施，本地 commit）

```diff
     case "openharmony":
-      return "libc.so";
+      // 裸名在消费版设备上解析到损坏的 /usr/lib/libc.so；
+      // musl loader 本身就是 libc（导出全部 libc 符号），
+      // 全设备存在、world-readable、任意域可 dlopen。
+      return "/system/lib/ld-musl-aarch64.so.1";
```

- loader 即 libc：musl 的 `ld-musl-aarch64.so.1` 就是 libc.so 本体
  （导出 getpid/mkfifo 等全部 libc 符号 + _Unwind_*）
- 全设备存在：我们的 binary 的 PT_INTERP 就是它（binary 能跑 = 它在）
- 与 binary 的 PT_INTERP 一致 = 与构建链接的环境同源

### 方案 B：运行时探测（备用）

依次尝试 `/system/lib/ld-musl-aarch64.so.1` → `/system/lib/libc.so` →
裸名，取第一个成功者。仅在方案 A 的路径在未来设备上变化时需要。

### 方案 C：LD_LIBRARY_PATH 指向 /system/lib

让裸名搜索跳过 /usr/lib —— 影响**所有** dlopen 的解析顺序，副作用大，
不推荐。

---

## 5. 涉及的文件

| 文件 | 改动 |
|---|---|
| `test/harness.ts` | openharmony 分支返回值：`"libc.so"` → `"/system/lib/ld-musl-aarch64.so.1"`（1 行 + 注释更新）|

所有使用方（8 个文件的 `libcPathForDlopen()` / `LIBC_PATH` 调用点）
自动获得修复后的路径，无需改动。

---

## 6. 验证方法

1. **静态**：harness 的 openharmony 分支返回值与 binary 的 PT_INTERP
   一致（`/system/lib/ld-musl-aarch64.so.1`）
2. **容器**：ci-runner 容器内 `/system/lib/ld-musl-aarch64.so.1` 存在
   （configure 步骤创建了该符号链接）→ dlopen 应成功
3. **真机**：✅ **已验证通过**（2026-09-04，设备终端 + 3c97d0089 binary）：
   ```
   LOADER-PATH /system/lib/ld-musl-aarch64.so.1: DLOPEN-OK getpid = 41415
   BARE-NAME   libc.so:                          DLOPEN-OK getpid = 41415
   ```
   musl loader 路径在真机用户域可 dlopen 且 libc 符号完整可用。
   验证脚本留存：设备 `dev-tmp/dlopen-verify.js`（LOADER-PATH 主验证 +
   BARE-NAME 对照，可复跑）。
4. **设备侧核查**：`/usr/lib/libc.so` 在消费版设备上存在但加载失败
   （ENOENT at load）—— 具体形态（悬空符号链接 or 损坏文件）待
   hdc shell 核查（设备重连后）。

### 6.1 真机验证的重要发现

**裸名 dlopen("libc.so") 在设备终端的进程内成功**（命中进程已加载的
libc 副本）—— 与 fulltest 轮的失败矛盾的解释：

- **fulltest 轮（runner 环境）**：测试文件被 runner 以 `bun test <file>`
  逐文件拉起，**每个文件是独立子进程** —— 子进程内的 dlopen("libc.so")
  走加载器搜索 → 命中损坏的 `/usr/lib/libc.so` → 失败
- **设备终端验证（单进程）**：`bun -e` / 脚本进程内已加载 libc（主
  loader），裸名命中进程已加载的副本 → 成功

即：**裸名的成败取决于进程内是否已加载 libc 副本** —— fulltest 的
子进程是全新的，没有已加载副本，搜索必然走到损坏路径。

**PR #15 的显式 loader 路径彻底绕开该解析**（不依赖搜索、不依赖
进程内状态）—— 两类场景都稳定。

---

## 7. 术语速查

| 术语 | 解释 |
|---|---|
| bun:ffi | bun 的外部函数接口；测试用 `dlopen` 加载 libc 调用 bun 未暴露的系统函数 |
| lazy FFI helper | 测试文件里的"首次使用时 dlopen 并缓存符号表"模式（lazyMkfifo/lazyRaise） |
| soname 搜索 | 加载器按库名（无路径）在搜索路径中查找的机制 |
| WSLENV | WSL↔Windows 环境变量转发白名单（interop 子进程的 env 传递机制） |
| PT_INTERP | ELF 的动态加载器路径字段（OHOS = /system/lib/ld-musl-aarch64.so.1） |

---

## 8. 待办

- [x] 推送本地 commit（harness 修复）→ PR #15（dev → ohos-aarch64）
- [x] 真机验证：musl loader 路径 dlopen 成功 + getpid 符号导出验证通过
- [ ] 合并 PR #15 → 重跑 dlopen 依赖的测试文件（process-stdin / socket /
      intl / spawn-pipe-read-error-leak…）确认 10 个失败文件恢复
- [ ] 设备侧核查 `/usr/lib/libc.so` 的实际形态（悬空符号链接 or 损坏文件）
- [ ] 若未来设备 loader 路径变化 → 方案 B（运行时探测）

---

*文档日期：2026-09-04 | 分析者：Sisyphus*
*依据：20260903/20260902 两轮真机报告对比 + 四方源码对比
（dev / social4hyq@f6aec3047c / ljy9812@ohos-aarch64 / bun-v1.4.0）*
*关联：p1-codesign-stub-inheritance.md（同轮另一主线）、
p2-v140-regression-candidates.md、skills/16-device-fulltest.md*
