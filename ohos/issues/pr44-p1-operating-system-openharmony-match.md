# P1: OperatingSystem 枚举缺 OPENHARMONY（os 匹配对自身平台返回 false）— 工作记录

> **关联 PR**：[#44](https://github.com/jx-bit/bun/pull/44)（单 commit，1 文件 +8/−3）
> **状态**：✅ 合并（5613067cf0，2026-09-17）
> **定位**：architecture-match 连续多轮 jxbit-only——失败点
> `["openharmony"] === true`（设备侧验收清单措辞），根因 100% 锁定。

## 1. 现象与测试语义

`test/cli/install/architecture-match.test.ts`（官方 v1.4.0，68 行）通过
`bun:internal-for-testing` 直接测 install 的平台匹配原语：

```js
const trues = [[], ["any"], ["any", process.platform], [process.platform],
               ["!sunos"], ["!sunos", process.platform], ["sunos", process.platform], ...];
test(`${os} === true`, () => expect(isOperatingSystemMatch(os)).toBe(true));
```

OHOS 上 `process.platform = "openharmony"` → 用例名 `["openharmony"] === true`
等 4 例（trues 中含 process.platform 的）**全部失败**：`isOperatingSystemMatch`
返回 false。falses 中 `["!" + process.platform]` 系列因未知值被忽略而**侥幸
通过**——与非对称失败的观察完全一致。

## 0. 一句话版本（TL;DR）

bun install 判断"这个包能不能装在本系统"时，拿包声明的 `os` 列表和当前平台
比对。比对用的**平台名单表漏了 openharmony**——OHOS 上包声明
`["openharmony"]`，bun 查表查不到，判定为"不匹配"（返回 false），测试
期望 true → 4 个用例挂。修复 = 把 openharmony 加进名单表（3 处小改，
与参考线逐字节一致）。

## 2. 根因（逐字对拍）

install 的 OS 匹配用 u16 位集枚举（`src/install_types/resolver_hooks.rs`）：

| 维度 | social4hyq（61dbc3a9d，A 轮） | 我方（541794f8d1）|
|---|---|---|
| `OPENHARMONY = 1<<9` 变体 | 〔源码〕有 | **无** ❌ |
| `ALL_VALUE` 含 OPENHARMONY | 〔源码〕含 | 无 ❌ |
| OHOS 的 `CURRENT` | 〔源码+实测〕`= OPENHARMONY` | `= LINUX` ❌（linux 非 android 分支落到 LINUX） |
| negatable_names `b"openharmony"` | 〔源码〕有 | 无 ❌（apply 无法映射 → 集合为空） |

失败链：`apply("openharmony")` 无法映射（negatable_names 缺条目）→ 集合无
LINUX 位 → `is_match(CURRENT=LINUX)` = false。`["!openharmony"]` falses
因未知负值被忽略而碰巧通过——非对称失败形态的完整解释。

A 的映射语义：package.json `os` 字段用 process.platform 值（Node 语义，
注释自证"NODE not NPM"），OHOS 上即 "openharmony"。

## 3. 修复内容（1 文件 +8/−3，与 A 逐字节一致）

- `OPENHARMONY: u16 = 1<<9` 常量 + 并入 `ALL_VALUE`
- OHOS 的 `CURRENT = OPENHARMONY`（linux 分支排除 ohos）
- `negatable_names!` 加 `b"openharmony" => OPENHARMONY`

### 3.1 实现选型：为什么加新变体而不是别名映射

| 候选 | 结论 | 理由 |
|---|---|---|
| **加 OPENHARMONY 独立位（采用，A 同款）** | ✅ | 语义诚实：process.platform 已经是 "openharmony"，位集如实反映；包可精确声明 os:["openharmony"]；is_match 的位运算不变 |
| 把 "openharmony" 别名映射到 LINUX 位 | ❌ | 让 OHOS 在位集里**伪装成 linux**：os:["linux"] 的包在 OHOS 上永远匹配（含明确声明 linux-only、实测不可用的包），掩盖真实兼容性；且与 process.platform="openharmony" 的报告值自相矛盾（#30 修复的平台语义被架空） |
| 只在测试里特判 | ❌ | 官方测试源码不改（项目裁决）；且匹配原语是 install 的公共路径（optionalDependencies 过滤等），测试外的真实安装同样受影响 |

位集结构保持不变：仍是 u16 位标志 + negatable 包装，仅扩充一个成员——
对既有调用方（optionalDependencies 过滤、lockfile 序列化）零改动。

## 4. 行为影响声明（重要）

`CURRENT` 从 LINUX 改为 OPENHARMONY 后，**声明 `os:["linux"]` 的包在 OHOS
上不再匹配**（Node 语义：os 字段匹配 process.platform）——这是诚实的对齐，
A 轮设备实证 install 面无回归（install 簇的失败为 verdaccio 轮转，与本变更
无关）。依赖 linux 包的 OHOS 用户需选择声明 openharmony 兼容的包版本——
与 npm 生态对其他新平台（如 freebsd）的一致处理。

## 5. 与 social4hyq 实现的对比

见 §2 表格（本例即逐字对拍直接产出：whole-file diff 的 4 hunk 全部为
OPENHARMONY 集群，零漂移混入 → whole-file checkout 忠实移植）。

## 6. 验证

- `cargo check -p bun_install_types -p bun_install` ✓
- dead-code-escapes lint 0 fail ✓
- 设备复测预期：architecture-match 16 用例全绿（含 `openharmony === true`
  4 例）；连带正面影响：optionalDependencies 的 os 过滤对 OHOS 语义正确

## 7. 关联

- 全树 A 侧 OHOS 补丁分诊（30 文件）：DNS=PR#40、cwd/rlimit/tmpdir=PR#42、
  **本 PR = install_types 簇**；install 剩余（PackageManager 等）待续
- 同族平台枚举：`bun_core/env.rs` 另有一个 OperatingSystem 枚举（A 未改，
  本 PR 不动）——若后续发现第二处匹配问题再议
