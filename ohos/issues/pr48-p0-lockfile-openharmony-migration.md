# P0: 旧 lockfile 在新 binary 上损坏 os 字段（OPENHARMONY 位集迁移缺失）

> **关联 PR**：[#48](https://github.com/jx-bit/bun/pull/48)（单 commit，1 文件
> `src/install/lockfile/bun.lockb.rs` +32，与参考线逐字节一致）
> **状态**：🔄 OPEN
> **一句话**：旧版 bun 写的二进制 lockfile（bun.lockb），拿到新版 bun 上跑一次
> install，所有包会被错误标记成「不支持 openharmony」，之后安装全部跳过。
> 修复 = 读入时把旧掩码升级/治愈。

## 1. 问题（大白话）

`bun install` 判断"包能不能装在本系统"，靠包声明里的 `os` 字段和当前平台
（OHOS 上 = `"openharmony"`）比对。比对用一张**位表**：每个系统占一位
（linux 一位、darwin 一位……）。

问题出在两代 bun 的位表不一样：

```
旧 binary 的位表：  aix | darwin | freebsd | linux | openbsd | sunos | win32 | android     （8 位）
新 binary 的位表：  同上 8 位 + openharmony                                                （9 位）
```

一个"任何系统都能装"的包，旧 binary 写 lockfile 时把 os 位打满 **8 位**；
新 binary 读进来，8 位 ≠ 自己的 9 位全值 → 误判"这个包声明了限制" →
序列化时写上 **`os: "!openharmony"`**（= 明确排除本平台）→ 之后每次
install 都跳过这些包。

## 2. 复现（设备，两版 binary 对照，5 分钟）

前提：旧版 binary（任意 #44 合并前的构建，如 `c4323a5d3`）+ 新版 binary
（`541794f8d` 或更新）。

### 复现 1（NONE 路径，设备已实证 @esbuild 案例）

```bash
mkdir p && cd p
echo '{"name":"r","dependencies":{"no-deps":"1.0.0"},
       "optionalDependencies":{"@esbuild/openharmony-arm64":"0.25.0"}}' > package.json

<旧binary> install     # 旧位表不认识 "openharmony" → 该包 os 记为 NONE（什么都不匹配）
<新binary> install     # NONE 匹配不到任何平台 → optional 包被【跳过】
ls node_modules/@esbuild 2>/dev/null || echo "✗ 包被跳过（二进制缺失，esbuild postinstall 失败）"
```

（A 维护者的设备观察原文：`@esbuild/openharmony-arm64 from a pre-OHOS
lockb is skipped on OHOS itself, failing esbuild's postinstall`。）

### 复现 2（LEGACY_ALL 路径，序列化污染）

```bash
mkdir p2 && cd p2
echo '{"name":"r","dependencies":{"no-deps":"1.0.0"}}' > package.json
<旧binary> install                        # 写 bun.lockb（二进制，8 位全值掩码）
<新binary> install                        # 读入 + 回写
grep -c 'os: "!openharmony"' bun.lock     # >0 = 每个无限制包被污染 ✗
```

（`LEGACY_ALL = 旧全值`：新 binary 读入后 ≠ 新全值 → 序列化按"有 OS 限制"
处理，把缺失的第 9 位以否定形式展开到每个包。）

## 3. 修复（= 参考线同款迁移）

读入 lockfile 时对每个包的 os 掩码执行两级治愈：

```rust
const LEGACY_ALL: u16 = ALL_VALUE & !OPENHARMONY;   // 旧全值
if meta.os == LEGACY_ALL || meta.os == NONE { meta.os = ALL; }   // 升级/治愈
```

- `LEGACY_ALL` → `ALL`：旧全值 = "无限制"，升级到新全值（bit 9 无害）
- `NONE` → `ALL`："什么都不匹配"绝不是有意限制——是写入方枚举不认识
  token；不治愈则包的原生平台二进制被永久跳过（比装错平台更糟）

## 4. 为什么现在才修（时序）

| 时点 | 事件 |
|---|---|
| #44 合并前 | 位表 8 位，无此问题（NONE/LEGACY_ALL 语义在旧表内自洽）|
| #44 合并 | 位表加第 9 位 → **旧 lockfile 的掩码全部"失真"** → 本缺陷激活 |
| 本 PR | 读入时迁移/治愈 → 新旧 lockfile 都收敛到正确语义 |

即：本缺陷是 #44（平台匹配修复）的**必要配套**——#44 修了"匹配"，
本 PR 修"匹配所依赖的存储格式迁移"。缺一，install 面在 OHOS 上损坏。

## 5. 与 social4hyq 实现的对比（逐字核验）

证据类型：〔源码〕两树 diff 逐字核验；〔实测〕A 维护者注释中的设备观察
（@esbuild/openharmony-arm64）。

| 维度 | social4hyq（61dbc3a9d，A 轮） | 我方（0eafc2a105）→ 本 PR |
|---|---|---|
| OPENHARMONY 匹配位 | 〔源码〕有（= PR#44 内容） | ✅ 已合并 |
| **lockfile LEGACY_ALL 迁移** | 〔源码+实测〕load() 入口迁移块 | **缺失** ❌ → 逐字节移植 |
| NONE → ALL heal | 〔源码+实测〕有（@esbuild 观察注释） | 无 ❌ → 同 hunk 移植 |

## 6. 验证

- `cargo check -p bun_install` ✓；dead-code-escapes lint 0 fail ✓
- 设备复测：复现 1/2 的命令在新 binary 上不再产生污染；install 面
  （bun-dedupe/nested-overrides/config-precedence/frozen-lockfile-pruned
  等输出差异类）若含 lockfile 损坏成分则连带回补

## 7. 影响面与风险

- 迁移只把「旧全值/NONE」**升级为 ALL**，不触碰任何真实限制
  （`os:["linux"]` 等显式声明原样保留）——语义只会变宽不会变窄
- `netbsd` 等 token 仍未映射（A 注释自证），同样走 NONE heal——与 A 一致
- 非 OHOS 平台零影响（heal 逻辑与平台无关，且语义等价）

## 8. 关联

- 前序：pr44（OPENHARMONY 匹配位——本 PR 为其存储格式配套）
- 同簇待续：npm.rs O_TMPFILE/linkat 回退、PackageInstall FUSE hardlinks
  （install 簇剩余 A 差量）
- 探针方法先例：pr41（ESPIPE）同款设备分层实验法
