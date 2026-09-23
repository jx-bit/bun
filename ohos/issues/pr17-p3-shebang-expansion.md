# P3: 用户态 shebang 展开（脚本直接执行支持）— 工作记录

> **关联 PR**：[#17](https://github.com/jx-bit/bun/pull/17)
> **状态**：✅ 已合并（2026-09-05）

## 1. 做了什么

移植 shebang 用户态展开方案：spawn 前解析 `#!` 行，改 exec 已签名的
解释器，脚本降级为普通 argv —— 文本脚本从此绕开内核 exec 签名关卡
（文本文件无 .codesign 段，此前直接 exec 脚本必 EACCES/EPERM）。

## 2. 结构

- `src/spawn_sys/shebang.rs`：`parse_shebang` 纯函数（10 个单元测试，
  cfg `any(ohos, test)` 门控，任意 host 可测）
- `src/spawn_sys/spawn_process.rs`：`ohos_expand_shebang` 装配
  （4096 缓冲、无换行兜底、`_owned` keepalive）
- `test/internal/source-lints/ohos-sign-call-sites.test.ts`：钉住两个调用点
- 分层：先 shebang 改写、后 codesign 懒修复（PR #16），链路有界

## 3. 详解与移植要点

[`../knowledge/codesign-and-spawn-primer.md`](../knowledge/codesign-and-spawn-primer.md) §5.6
