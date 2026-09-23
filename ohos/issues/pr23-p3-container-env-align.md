# P3: 容器测试环境对齐 — llvm@21 PATH / OHOS_SYSROOT / dlopen 路径 — 详解

> **关联 PR**：[#23](https://github.com/jx-bit/bun/pull/23)（单 commit，2 文件 +46/-3）
> **状态**：🔄 OPEN（checks 验证中）
> **定位**：容器测试环境的三个缺口 —— 每个缺口挂一类测试。与 #22（shebang
> 悬垂修复）文件不重叠，可独立合并。机制背景见
> [`../knowledge/ci-comparison-social4hyq.md`](../knowledge/ci-comparison-social4hyq.md)。

---

## 0. 三个缺口一句话

| 缺口 | 症状 | 波及 |
|---|---|---|
| node-gyp 找错编译器 | 31 个 napi 文件死于缺 C++20 头 | test/napi/* 全军覆没 |
| bun:ffi 的 TCC 找不到 stdint.h | napi-value-ffi 失败 | ffi 编译类 |
| harness 的 libc dlopen 路径不存在 | dlopen 类测试空输出 | spawn-pipe-read-error-leak / intl / filesink 等 |

三个缺口的解法全部来自参考通道（他们的 runner.node.mjs/utils.mjs 带同样的
handler，已真机验证）。

---

## 1. 修复一：llvm@21 keg bin 排 PATH 最前（openharmony 时）

### 1.1 根因

`~/.harmonybrew/bin/clang(++)` 实际解析到 ohos-sdk 自带的旧版 clang
（15.0.4，无 `<source_location>`/C++20 libc++），而 llvm@21 的 keg 里有
21.1.8 —— 两个配方都装了同名二进制，node-gyp 按 PATH 搜索编译器
（无视 CC/CXX env），静默用错 → 每个原生插件构建死于缺 C++20 头。

参考通道的实测：**test/napi 从 0% 覆盖修复到 60/60 通过**（同款根因修复）。

### 1.2 修复（runner.node.mjs getCombinedPath，openharmony 分支）

```js
if (process.platform === "openharmony") {
  const brew = spawnSync("brew", ["--prefix", "llvm@21"], { encoding: "utf-8" });
  if (!brew.error && brew.status === 0) {
    paths.push(join(brew.stdout.trim(), "bin"));   // llvm@21 keg bin 排最前
  }
}
paths.push(process.env.PATH);
```

---

## 2. 修复二：OHOS_SYSROOT 注入测试环境

### 2.1 根因

bun:ffi 的 TCC 链接器只在 `$OHOS_SYSROOT` 已设时才添加 OHOS sysroot 的
libc/include 路径（见 `src/runtime/ffi/ffi_body.rs`）—— 没有它，
`napi-value-ffi` 死于 `<stdint.h>` not found。CI 在 job 级已设置；
runner 内每次测试 spawn 需要兜底（ad-hoc 本地跑会静默丢失）。

### 2.2 修复（runner.node.mjs spawnBun）

```js
let ohosSysroot;
if (process.platform === "openharmony" && !process.env.OHOS_SYSROOT) {
  const brew = spawnSync("brew", ["--prefix", "ohos-sdk"], { encoding: "utf-8" });
  if (!brew.error && brew.status === 0) {
    ohosSysroot = join(brew.stdout.trim(), "native", "sysroot");
  }
}
// bunEnv 里：
...(ohosSysroot ? { OHOS_SYSROOT: ohosSysroot } : {}),
```

---

## 3. 修复三：harness 的 libc dlopen 路径

### 3.1 根因

`test/harness.ts :: libcPathForDlopen()` 的 linux+musl case 返回
`/usr/lib/libc.so` —— **Alpine 专用路径**：ci-runner 容器（OHOS userland）
与消费版鸿蒙 PC 都没有它。dlopen 类测试（spawn-pipe-read-error-leak、
transpiler-truncated-utf8、intl、filesink）全部死于
`Failed to open library "/usr/lib/libc.so"`。

### 3.2 修复（OHOS 感知级联）

```js
case "musl": {
  // OHOS: the musl loader IS libc — on device (/system/lib) and in the
  // container (via the fixup symlink). /usr/lib/libc.so is Alpine-specific.
  if (existsSync("/system/lib/ld-musl-aarch64.so.1")) return "/system/lib/ld-musl-aarch64.so.1";
  if (existsSync("/lib/ld-musl-aarch64.so.1")) return "/lib/ld-musl-aarch64.so.1";
  return "/usr/lib/libc.so";
}
```

级联顺序的理由：/system/lib 在真机 ✓ + 容器 fixup ✓（两个部署环境都存在）；
/lib/ld-musl 是通用 musl；/usr/lib/libc.so 仅 Alpine 式布局有效。

---

## 4. 与 PR #22 的关系

| | PR #22 | PR #23 |
|---|---|---|
| 文件 | src/spawn_sys/*（spawn_process.rs、shebang.rs）| test/harness.ts、scripts/runner.node.mjs |
| 类 | shebang 悬垂指针（内存安全）| 测试环境三缺口 |
| 交互 | 无 —— 不同文件、不同机制 | 可独立合并，任意顺序 |

---

## 5. 验证状态

- 双 target 编译 ✅（host + aarch64-unknown-linux-ohos，pinned nightly）
- 容器 run 验证中：预期 napi/node-gyp/dlopen 三类收敛
- 合并后的下一轮全量：确认失败清单收敛幅度

---

*文档：Sisyphus | 2026-09-08 | 依据 run 34079587941/34183365924 的失败分类 + 参考通道源码比对*
