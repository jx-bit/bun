# P1: CI full mode 跳过 PCH —— cross 通道 JSC 声明缺失编译全挂
> **关联 PR**：[#64](https://github.com/jx-bit/bun/pull/64)（base 1.4.0）

> 1.4.0 门禁的 cross linux-x64 / darwin-arm64 leg 确定性失败。根因：
> cross 构建 `--ci=true`（winsysroot/SDK 缓存所需）+ 默认 mode=full 恰好命中
> `usePch = !cfg.ci || cfg.mode !== "full"` 的跳过分支 —— 而 C++ TU 依赖 PCH
> 强制注入的 JSC 声明。修复：`usePch = true`（无条件）。

---

## 1. 证据（run 35808046552，linux-x64 leg）

```
In file included from ../../src/jsc/bindings/webcore/streams/BunStreamSource.cpp:1:
src/jsc/bindings/BunClientData.h:18:40: error: no type named 'VM' in namespace 'JSC'
src/jsc/bindings/webcore/streams/WebStreamsInternals.h:518:66: error: unknown type name 'JSCompressionStream'
```

- `BunStreamSource.cpp` 第一行 include `BunClientData.h`；该头**自身零 include**，
  依赖 PCH 强制注入的 root-pch.h 提供 JSC 声明。
- 失败命令里无 `-include-pch`/`-include`，而 ninja 配置有专门的 `cxx_pch` 规则
  —— cross 构建**从未生成/使用 PCH**（日志 pch 零命中）。
- darwin leg 同错误（BunClientData.h:18）；windows leg 历史绿（其 TU 集不依赖）。
- 同源码在 OHOS 通道绿 —— 该通道不传 `--ci=true`，PCH 启用。

## 2. 与参考实现的对比

不适用（非移植项）：`usePch` 条件是本 fork 构建脚本自有逻辑；上游 oven-sh 在
bun/main 同形态（精简 BunClientData.h + line-1 include）+ 其原生 CI（无 --ci）
自洽 —— 是我们的 ci-full 跳过分支打破了它。

溯源：`usePch` 条件源自 build.ts TypeScript 化重构（#27973 线），
"CI full mode (unused by the pipeline)" 的假设被 cross-x86 通道（本次 1.4.0
门禁启用）首次打破。

## 3. 验证

- 1.4.0 门禁自身即验证：合并后 cross legs 带 `-include-pch` 编译，
  BunClientData.h / WebStreamsInternals.h 错误消失。
- **未修复构建上确定性失败**：每次 cross run 的 linux-x64/darwin leg 必挂于
  BunClientData.h:18。

## 4. 关联

- 爆炸半径评估：`cfg.ci` 其余消费点（config.ts winsysroot/SDK 缓存解析）不动；
  `noPchSources`（rescle/highway-json）排除不受影响；原生 lanes（build-x86、
  OHOS）本就 PCH-on，TU 集已兼容。
- 1.4.0 门禁背景：PR #51 行（Cargo.lock 策略）、cross-x86 push/pull_request
  触发器（本分支 ci 提交）。

---
*立档：2026-09-23 | 分析者：Sisyphus | 依据：run 35808046552 双 leg 日志 +
compile.ts PCH 规则 + 与 bun/main / 61dbc3a9d 三方对照*
