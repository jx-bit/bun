# P0: 容器构建 sysroot 布局探测（tap 公式改名致 native/sysroot 缺失）— 工作记录

> **关联 PR**：[#45](https://github.com/jx-bit/bun/pull/45)（单 commit，1 文件
> `.github/scripts/build-ohos-container.sh`）
> **状态**：✅ 合并（5e69b884ef，2026-09-17）
> **定位**：PR #44 容器构建失败——`OHOS sysroot not found at
> …/opt/ohos-sdk-native/native/sysroot`。与 PR 内容无关（#44 只改
> resolver_hooks.rs）；同脚本的 #43 轮构建 success。

## 1. 根因（失败/成功轮日志对拍 + 镜像 digest 恒等证明）

| | PR #42 轮（9/15，成功） | PR #44 轮（9/17，失败） |
|---|---|---|
| 容器镜像 digest | `sha256:38e740c8…` | **完全相同** |
| `brew update` 后 llvm@21 的 sdk 依赖 | `ohos-sdk@26.0.0.18`（带版本后缀） | **`ohos-sdk-native`**（tap 改名/重构） |
| keg | `opt/ohos-sdk@26.0.0.18`（含 native/sysroot ✓ cmake 实证） | `opt/ohos-sdk-native` 存在，但 **无 native/sysroot** |
| 构建结果 | sysroot 找到 → 成功 | config.ts 校验失败 → exit 1 |

机制：`brew update` 刷新浮动 tap → llvm@21 的 sdk 依赖公式更名
（ohos-sdk@<ver> → ohos-sdk-native），新公式 keg 的**布局与旧版不同**
（无 native/ 子目录）。构建脚本按旧布局拼 `…/native/sysroot` → 缺失 →
config.ts 抛错。镜像 digest 恒等 ⇒ 容器基底一致 ⇒ 差异纯在 tap 浮动层。

## 2. 修复内容（1 文件）

`SDK_PREFIX` 解析后增加 **sysroot 布局探测链**：

```bash
SDK_SYSROOT=""
for cand in \
    "$SDK_PREFIX/native/sysroot" \
    "$SDK_PREFIX/sysroot" \
    "$BREW_PREFIX"/opt/ohos-sdk@*/native/sysroot \   # 镜像内置旧版 keg（digest 固定 ⇒ 必在）
    "$BREW_PREFIX/opt/ohos-sdk/native/sysroot"; do
    [ -d "$cand" ] && { SDK_SYSROOT="$cand"; break; }
done
```

- 命中即用（`OHOS_SDK_ROOT` = keg 根、`OHOS_SYSROOT` = 探测到的 sysroot）；
  旧 keg 回退路径与历史成功构建的实证值完全一致
- 全部未命中 → 错误信息**列出 ohos-sdk* keg 顶层内容**（自诊断：下一轮
  直接看到新布局）

同族背景：tap 公式更名是本轮第二次冲击（上一例 = PR #35 门禁期的
ohos-sdk@26.0.0.18 → ohos-sdk-native 依赖更名）；本修复让 sysroot 解析
**布局无关**，后续公式再改名（如 ohos-sdk@27）也自动适配（探测链含
`ohos-sdk@*` 通配）。

## 3. 与 social4hyq 实现的对比

| 维度 | social4hyq（61dbc3a9d 构建/其 lane） | 我方 → 本 PR |
|---|---|---|
| sysroot 解析 | 〔推断〕其 lane 早于 tap 改名，未暴露 | 静态旧布局 ❌ → 布局探测链（新旧 keg 通吃） |

（tap 公式不在 GitHub 公开面，新布局细节待容器内 `ls` 确认——失败时
自诊断输出即为此设计。）

## 4. 验证

- `bash -n` ✓
- CI：容器 lane 重跑即验证（探测链命中旧 keg → 构建继续；若新 keg 布局
  可用则命中第一候选）
- 不确定项：新 `ohos-sdk-native` keg 的 sysroot 子路径未知——探测链 +
  自诊断输出兜底，设备侧亦可 `docker exec … ls` 直查

## 5. 关联

- 前序：pr35（容器门禁对齐）、pr43（openat2 门控）
- 同族：tap 浮动合同治理——PR #35 建立了动态公式解析，本 PR 补齐
  **sysroot 布局**维度；pr35 的 `verify-retest` 对账工具不受影响
