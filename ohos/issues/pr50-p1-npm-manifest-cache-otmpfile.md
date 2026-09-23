# P1: manifest 缓存写 O_TMPFILE attempt-#3 兜底丢失 — install 族缓存写 EPERM
> **关联 PR**：[#50](https://github.com/jx-bit/bun/pull/50)

> isolated-install（27/55）与 bun-lock（16/24 签名同源）稳定连挂的排查中，
> 排除法（`git diff 61dbc3a9d -- src/install/`）命中一处确认回归：
> `PackageManifest::write_file` 的 O_TMPFILE **attempt-#3 兜底**（linkat 仍失败时
> tmp_path 写入 + rename 原子落盘）在 Zig→Rust 重写窗口被上游版本覆盖丢失。
> 结合测试树台账 §1.3（**OHOS 沙箱 outright 禁止 linkat**），attempt-#3 在真机
> 是必现路径：丢失后 manifest 缓存写 EPERM → 缓存条目丢失 → registry 重复请求。
> **修复 = 与 61dbc3a9d 参考树逐字节恢复**（cargo check / clippy / fmt 全过）。
> **注**：attempt-#3 丢失不是 ConnectionRefused 的直接原因（后者错误名来自网络
> 层 errno，见 20260921-remaining-issues.md §10.3 设备探针计划），但加剧
> registry 负载、与主因叠加。

---

## 1. 与参考实现（61dbc3a9d 交付树）的对比

**结论先行：逐字节恢复，无实现差异。**

| 项 | 参考树（61dbc3a9d，全测通过） | 我方树（修复前） | 修复后 |
|---|---|---|---|
| attempt #1 | `linkat_tmpfile` | 同 | 同（逐字节） |
| attempt #2 | unlink 后重试 | 同 | 同（逐字节） |
| attempt #3 | tmp 写 + `renameat` 原子落盘（best-effort） | **无**（`?` 直接传播 EPERM） | 恢复（逐字节） |
| 溯源 | OHOS 本地补丁 | 上游 Rust 重写（23427dbc12f）版本胜出 | —

证据类型：〔源码〕`git diff 61dbc3a9d..HEAD -- src/install/npm.rs` 逐 hunk 核对 +
`git log -S "There is no attempt #3"`（仅命中重写提交）——正是 ohos/README 规则 4
警告的"上游窗口修复 ≠ 参考树拥有的修复"案例。

## 2. 为什么必须恢复（症状链）

1. OHOS 沙箱 linkat EPERM（台账 §1.3，isolated-install hardlink backend 整组
   skip 的同一根因）→ shim 的 /proc/self/fd 复制路径 attempt #1 "usually succeeds"；
2. 失败时 attempt #2/#3 是唯一恢复；我方树 attempt #2 失败即 `?` 传播 →
   缓存写整体失败；
3. 缓存条目丢失 → 同包后续 install 重新走 registry → 加重负载
   （isolated-install 单实例 verdaccio 扛 ~82 次 install，负载最重）。

## 3. 验证

- 静态：`cargo check -p bun_install` / clippy / fmt 全过；diff 逐字节 = 参考树。
- 真机（随下轮 fulltest）：install 族缓存相关失败面应收窄；
  **未修复构建上必现**——沙箱 linkat 策略下任何走 manifest 缓存写的 install
  在 attempt #1/#2 失败时即丢条目。

## 4. 关联

- 归因全景：[`../analys/20260921-remaining-issues.md`](../analys/20260921-remaining-issues.md) §10（R8）
- ConnectionRefused 主因候选（fd 耗尽/accept 溢出）与探针 P-R8-1~4 见 §10.3，
  独立于本修复推进。

---
*立档：2026-09-21 | 分析者：Sisyphus | 依据：H 轮日志取证 + 排除法 diff + 参考树逐字节对照*
