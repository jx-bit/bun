# P1: openat2_in_root 缺 OHOS 门控（F2 目录路由全 404 根因）— 归档文档

> **关联 PR**：[#43](https://github.com/jx-bit/bun/pull/43)（单 commit，1 文件
> `src/sys/linux_syscall.rs` +49/−35）
> **状态**：🔄 OPEN
> **定位**：F2——`Bun.serve({routes:{"/*":{dir}}})` 目录路由 24 用例连续三轮
> 全 404（0e0fd1559 / 14fdf0d56 / 007d7a07e 均 jxbit-only；探针 p7b 实锤）。
> **本文件自包含**：F2 相关探针实验全文归档于此；确认合并后
> `_archive/fix-tasks.md`、`_archive/probes.zip`、`analys/probe-p7-directory-route.md`
> 可清理（F1/ESPIPE 部分的实验记录归档于 [pr41 文档](pr41-p0-rwf-espipe-fallback.md)）。

## 1. 现象与影响

`Bun.serve({ port: 0, routes: { "/*": { dir: <绝对路径> } } })` —— bun 1.4.0
的静态目录路由。设备上：服务注册成功（`{dir}` 对象语法被类型校验接受、
无崩溃、无异常日志），但**所有路径 404**——含存在的 `/index.html`、
`/plain.txt`、嵌套 `/sub/file.txt`；仅 `/missing` 的 404 属正确行为。
24 用例（files/nested/prefix/index/content-type/HEAD/ETag/304/Range/
traversal/percent-decode）全部依赖此路径 → 全灭。

## 2. 探针实验归档（2026-09-14，设备实测，A/B 双 binary 对照）

方法：分层 JS 探针（p1~p7b），每针只验一层，逐层排除。
A = 参考 `1.4.0+61dbc3a9d`（harmonybrew 1.4.0_80）；
B = 我方 `1.4.0-canary.1+541794f8d`（sha256 `0f69b039…`）。
脚本原样归档于本节与 §2.4（`probes.zip` 为原始打包）。

### 2.1 实验矩阵（全量）

| 探针 | 验证层 | A | B | 判定 |
|---|---|---|---|---|
| p1 | `Bun.spawn` pipe 读（单子进程） | ✅ "AAA\n" | ✅ | 一致 |
| p2 | `Bun.spawn` pipe 读（**并发 2 进程**） | ✅ | ✅ | 一致 → **pipe/epoll/并发层排除** |
| p3 | `Bun.$` 非 quiet（stdout 直通） | ✅ 直通 AAA，exit 0 | ❌ "" exit **65507** | F1 命中（→ 归档于 pr41 文档，#41 已修） |
| p4 | `Bun.$` + `.quiet()`：builtin/外部/sh -c 三形态 | ✅×3 | ✅×3 | 一致 → 排除 shell 解释器整体 |
| p6 | p3 稳定性复验（3 次） | ✅ 3/3 | ❌ 3/3 | F1 100% 复现（同上） |
| p7 | 目录路由**字符串语法** `"/*": "./dir"` | ❌ TypeError | ❌ TypeError | 两构建一致拒绝 → 类型校验行为留档（官方语法为对象式） |
| **p7b** | 目录路由**对象语法** `"/*": { dir }`（F2） | ✅ 200×3 + 404 | ❌ **全 404** | **F2 命中**：实现整体失效 |

### 2.2 推翻的假设（实验证据，防重蹈）

1. ~~ProcessHandle/pipe-watcher 层缺陷~~ → p1/p2 在 B 上完全正常；且 A
   （61dbc3a9d，无 ProcessHandle 重构的旧 to_process API）multi-run 同样通过
2. ~~wave2（#34 memfd/waiter/close_range/PWD）引入~~ → c4323a5d3 时期
   （wave2 前）multi-run 即挂
3. ~~verdaccio/环境毒化~~ → 非 verdaccio 签名（grep 未见），且三轮稳定
4. ~~缺特性/需 merge 上游实现~~ → 交付线 541794f8d1 的
   `src/runtime/server/` 与 dev 分支、与 v1.4.0 **三方逐字节一致**
   （DirectoryRoute.rs 已在）→ 实现在，行为不在 → 差异在运行时层
5. ~~（本轮）openat2_beneath 未门控~~ → 我方 beneath 有 openat 回退门控，
   install/resolver 面正常——不对称只在 **in_root**

### 2.3 探针脚本（p7b.js，F2 的 30 秒判定器）

fixture：`p7dir/{index.html:"<html>INDEX</html>", plain.txt:"PLAIN",
sub/file.txt:"SUBFILE"}`（与脚本同目录）。

```js
// p7b.js — 目录路由对象语法（F2 判定器）
const base = import.meta.dir;
const cases = [
  ["GET /index.html", "/index.html"],
  ["GET /plain.txt", "/plain.txt"],
  ["GET /sub/file.txt (nested)", "/sub/file.txt"],
  ["GET /missing (expect 404)", "/missing"],
];
const server = Bun.serve({ port: 0, routes: { "/*": { dir: base + "/p7dir" } } });
for (const [name, path] of cases) {
  try {
    const r = await fetch("http://localhost:" + server.port + path);
    console.log(name, "→", r.status, r.headers.get("content-type"),
                JSON.stringify((await r.text()).slice(0, 30)));
  } catch (e) { console.log(name, "→ ERROR", String(e).slice(0, 80)); }
}
server.stop(true);
```

实测：A → `200 text/html "<html>INDEX</html>"` / `200 text/plain "PLAIN"` /
`200 text/plain "SUBFILE"` / `404`；B → **四行全 404**。
（p7.js 为字符串语法误用对照：A/B 均 `ERR_INVALID_ARG_TYPE`，留档。）

## 3. 根因（不对称门控 + 包装器探针设计缺陷）

### 3.1 失败定位链

1. p7b：`{dir}` 语法被接受（ServerConfig 类型校验通过）→ 路由**注册成功**
2. 每个文件请求 → `DirectoryRoute::open_beneath(root_fd, rel)` →
   `bun_sys::openat2_in_root(root_fd, rel, O_RDONLY|CLOEXEC|NONBLOCK, 0)`
   → `.ok()?` → **None → 404**
3. 即：**openat2_in_root 在 OHOS 上每次调用失败**，且失败未被降级/回退

### 3.2 不对称门控（交付线 541794f8d1 的实况）

`src/sys/linux_syscall.rs`：

| fn | OHOS 门控 | 实际行为 |
|---|---|---|
| `openat2_beneath` | ✅ `#[cfg(ohos)]` → 回退 plain openat | install/resolver 面正常 |
| **`openat2_in_root`** | ❌ **无门控**（直接 rustix openat2，RESOLVE_IN_ROOT\|NO_MAGICLINKS） | HongMeng 对 RESOLVE_IN_ROOT 返回 EINVAL → 每次 EINVAL |

（旁证：我方文件内既有注释"OHOS seccomp blocks openat2 (437) with
SIGSYS"——beneath 的门控源于该认知，in_root 漏加。）

### 3.3 为什么 sys/lib.rs 的包装器没有自愈

`bun_sys::openat2_in_root` 包装器：真实 openat2 失败（EINVAL）后用
**O_PATH\|O_DIRECTORY 的探针**（无 resolve 标志）区分"内核无 openat2"与
"此路径失败"：

- 探针在 HongMeng 上**成功**（内核接受无 resolve 标志的 openat2）→
  判定"内核支持、此路径有问题" → **EINVAL 原样传播，不缓存 UNAVAILABLE**
- 后续每次调用重复同样失败 → DirectoryRoute 每次打开 None → 全 404

即：探针只验证"openat2 系统调用存在"，未验证"**RESOLVE_IN_ROOT 语义**
可用"——HongMeng 属于后者（syscall 在、语义残缺）。

### 3.4 A 树的处理（设备实证）

A 的 `linux_syscall.rs` 对两个 fn 均在 OHOS 上**合成 `Err(ENOSYS)`**（注释
自证：seccomp 对 openat2 为不可捕获 SIGSYS，探针活不到回退）→ 包装器
探针同样 ENOSYS → 缓存 UNAVAILABLE → **永久回退 plain openat** → 文件
打开成功。穿越防护由 `resolve_subpath` 的字符串级拒绝在 open 之前承担
（traversal 用例 404 于 open 前产生，A 轮同证）——openat2 的 IN_ROOT
为纵深防御层，回退后该层失效但**被测行为不变**。

## 4. 实现选型（为什么这样修）

| 候选 | 结论 | 理由 |
|---|---|---|
| **in_root 补 OHOS 门控（合成 ENOSYS）→ 包装器缓存 + plain openat 回退**（采用，A 结构） | ✅ | 与 beneath 对称；缓存后零重复失败开销；resolve_subpath 的字符串级穿越拒绝保持被测行为 |
| 修包装器探针：用带 RESOLVE_IN_ROOT 的探针区分"syscall 在/语义残缺" | ❌ | 探针本身在残缺内核上行为不可信（本次教训：探针通过 ≠ 语义可用）；A 的"OHOS 直接 ENOSYS"更简单且设备实证 |
| OHOS 上 in_root 直接 plain openat（不试 openat2） | ≈ | 与采用方案最终路径相同，但绕过了包装器的缓存结构；采用 A 结构保持两树一致 |
| 改测试/禁用路由 | ❌ | 官方测试源码不改；特性是 1.4.0 正式功能 |

非 OHOS 平台：真实 openat2 保持（零影响）。

## 5. 修复内容（1 文件）

`src/sys/linux_syscall.rs`：`openat2_beneath` 与 `openat2_in_root` 统一为
A 结构——OHOS 上内层 cfg 合成 `Err(ENOSYS)`，非 OHOS 走真实 openat2。
sys/lib.rs 包装器无需改动（ENOSYS 探针失败 → 缓存 UNAVAILABLE →
plain openat 回退链既有）。

规范适配：A 侧 fn 可见性为 `pub`（跨 crate 调用）；我方调用均在 bun_sys
crate 内，保持 `pub(crate)`。

## 6. 与 social4hyq 实现的对比（逐字核验）

证据类型：〔源码〕两树 diff 逐字核验；〔实测〕设备探针 p7b（§2）。

| 维度 | social4hyq（61dbc3a9d，A 轮） | 我方（541794f8d1）→ 本 PR |
|---|---|---|
| `openat2_beneath` OHOS 门控 | 〔源码〕内层 cfg → ENOSYS | 有（等价，结构不同）→ 统一为 A 结构 |
| `openat2_in_root` OHOS 门控 | 〔源码〕内层 cfg → ENOSYS | **无**（裸 openat2）❌ → 同 A |
| serve-directory-routes | 〔实测〕24 用例通过 | 全 404 ❌ → 预期转绿 |

## 7. 验证

- `cargo check -p bun_sys -p bun_runtime` ✓
- 设备冒烟：`bun p7b.js` 四行输出 200×3 + 404（与 sys-release 一致）
- 全量复测预期：serve-directory-routes 24 用例转绿（F2 关闭）

## 8. 关联与数据归档说明

- 探针原始打包：`_archive/probes.zip`（p1~p7b + README 矩阵 +
  fix-methods 修复建议）；本文件 §2 已全文归档其内容
- 轮次数据：`fulltest-data/archive/round-D-14fdf0d56.tar.gz`（D 轮，已归档）、
  `fulltest-data/007d7a07e/`（F 轮，数据已清理）
- **清理计划**（本 PR 合并且设备确认 p7b 转绿后）：
  `_archive/fix-tasks.md`、`_archive/probes.zip`、
  `analys/probe-p7-directory-route.md` 三份可删除——其内容已全部收入
  本文件与 [pr41 文档](pr41-p0-rwf-espipe-fallback.md)（F1 部分）
- 同族 syscall 门控：fchmodat2(452)、epoll_pwait2(441)、openat2(437)——
  OHOS seccomp 黑名单治理的第三例；close_range(436)/copy_file_range/
  pidfd_open 实证可用
- 前序：pr34/pr35/pr37/pr39/pr40/pr41
