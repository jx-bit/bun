# P2: 五平台滚动 latest 装配流水线（ljy 式发布）
> **关联 PR**：[#66](https://github.com/jx-bit/bun/pull/66)

> OHOS 容器构建成功后自动链 cross 四 leg（同 SHA）并汇集发布滚动 `latest`：
> bun-ohos-aarch64 / bun-linux-x64 / bun-linux-arm64 / bun-windows-x64.exe /
> bun-darwin-arm64，body 标注基线 SHA。参照 ljy9812 发布页形态 —— 但其流水线
> 并无现成装配环节（cross-x86 只上传 artifacts，08-04 的五产品 release 为手工
> 组装），故装配 workflow 为新写。

## 1. 结构

```
push → ohos-aarch64
  ├─ OHOS Build (容器通道, 原有)
  └─ workflow_run(完成) → ohos-latest-assemble.yml
       ├─ start: 记录装配起始时间（workflow_call run 的 head_sha 继承
       │         调用方上下文而非交付 SHA，故 cross run 以 created>=since 定位）
       ├─ cross: workflow_call cross-x86.yml, inputs.sha = 触发 run 的 head_sha
       └─ publish: 定位 cross run（created>=since 首个 success）→
            下载两路 artifacts → 归一命名 → 发布/更新 latest
```

- cross-x86.yml 增 `workflow_call` + `sha` 输入（checkout 遵循）+ `linux-arm64`
  leg（aarch64 宿主原生构建，无 sysroot；webkit arm64 prebuilt 已验证存在）
- 守卫：OHOS run conclusion ≠ success 时 cross/publish 跳过（首次实跑 93306b095d
  被取消的构建触发空跑，守卫正确生效）
- OHOS 单品滚动 `ohos-latest` 保持独立（两线并行的双 latest 模型，同参照线）

## 2. 前置依赖

- **#64（PCH 无条件启用）**：cross legs 的 TU（BunStreamSource.cpp →
  BunClientData.h）依赖 PCH 注入的 JSC 声明；未修复时 linux-x64/darwin 必挂
  （已实证）。合并顺序：#64 → #66 → 生效。

## 3. 验证

- YAML 校验通过；首次真跑 = 合并后下一次 ohos-aarch64 push 的完整链
  （OHOS Build → Assemble → latest 出现五产品 + 基线 SHA）。
- latest 未出现时的排查：Assemble run 的 job 跳过态（OHOS run 非成功）/
  cross leg 失败（回 #64 验证）/ publish 定位失败（created 过滤窗口）。

## 4. §后续：#69 标题约定对齐（2026-09-23）

Release 标题向参照线看齐（全部 "Bun OHOS …" 前缀）：滚动 ohos-latest 裸 tag 名 →
**"Bun OHOS (Latest)"**；五产品 latest → **"Bun OHOS Cross-Build (latest)"**；
版本化通道已对齐。现有 ohos-latest 标题已一次性 edit 修正。

## 5. §后续：#72 并行化重构（2026-09-23，取代 workflow_run 串行链）

用户指出串行链（OHOS 构建 → workflow_run → cross legs → assemble）设计缺陷：
五个目标互相独立，cross 没有理由等 OHOS。#72 重构为并行：

```
push → ohos-aarch64
   ├─ build  （OHOS 容器 leg，原有）
   ├─ cross  （cross-x86 workflow_call，sha=github.sha，与 build 并行）
   └─ publish（needs 两者）→ 滚动 latest 五产品 + 基线 SHA
```

- 同 run 内 artifact 收集（无需跨 run 发现），assemble workflow 删除
- 发布门禁 = push 到 ohos-aarch64（PR gate 跳过 publish；cross 补 PR 覆盖只需一行 if）
- ohos-latest（OHOS 单品）发布由 build job 保留，双 latest 模型不变
- 顺带：linux-arm64 leg 的 arch 令牌修正（aarch64 非 arm64，#70 同款排查路径；
  本档案 §3 的"首次真跑"预期由并行链兑现）

---
*立档：2026-09-23 | 分析者：Sisyphus | 依据：ljy9812 发布页观察 + 两仓库 workflow 对照*
