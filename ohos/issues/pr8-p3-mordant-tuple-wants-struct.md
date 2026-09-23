# P3: mordant finding — ohos_sign elf.rs tuple_wants_struct — 详细讲解
> **关联 PR**：[#8](https://github.com/jx-bit/bun/pull/8)

> mordant（dylint lint 集合）在 `ohos_sign` crate 发现 1 个超出 baseline 的 finding：
> `parse_header` 函数返回 4 元素 tuple，lint 建议改用 struct。
> **这个问题只在我们（jx-bit/bun）的 CI 上失败**——上游、social4hyq 和 ljy9812 都不会遇到。

---

## 1. 什么是 mordant

### 1.1 mordant 是什么

mordant 是 bun 使用的 **dylint lint 集合**（基于 Rust 编译器的自定义 lint 框架）。
可以理解为"Rust 版的 ESLint 插件"——在编译时扫描代码，发现可读性或正确性问题。

运行在 GitHub Actions 的 `rust-lints.yml` workflow 中的 `mordant` job。

### 1.2 mordant 的 ratchet（棘轮）机制

mordant 使用**基线（baseline）追踪**——"只能变好不能变差"：

```
mordant-baseline.toml 记录格式：
  [crate_name]
  "lint_name:file_path" = 数量

例如：
  [bun_jsc]
  "defaulted_failure:src/jsc/ConsoleObject.rs" = 4
  → ConsoleObject.rs 有 4 个 defaulted_failure finding（历史遗留）
```

**CI 规则**：

| 场景 | 结果 |
|---|---|
| 新增 finding（超过 baseline） | ❌ CI 失败 |
| 修复 finding（低于 baseline） | ✅ 通过 |
| 无变化 | ✅ 通过 |

目的：**已有的技术债务不阻塞 CI，但新增的必须处理**。

### 1.3 tuple_wants_struct lint

函数返回 **4+ 元素的 tuple** 时告警，建议改为 struct。

```rust
// 4 元素 tuple — lint 建议改为 struct
fn parse_header(elf: &[u8]) -> Result<(u64, u16, u16, u16), SignError>

// 改为 struct 后 — 不再告警
struct SectionHeaderTable { e_shoff: u64, e_shnum: u16, ... }
fn parse_header(elf: &[u8]) -> Result<SectionHeaderTable, SignError>
```

---

## 2. 问题是什么

### 2.1 触发位置

`src/ohos_sign/src/elf.rs` 的 `parse_header` 函数（line 66）：

```rust
fn parse_header(elf: &[u8]) -> Result<(u64, u16, u16, u16), SignError> {
    ...
    Ok((e_shoff, e_shnum, e_shstrndx, e_shentsize))
}
```

调用方（line 123）：
```rust
pub fn has_codesign_section(elf: &[u8]) -> bool {
    let Ok((e_shoff, e_shnum, e_shstrndx, e_shentsize)) = parse_header(elf) else {
        return false;
    };
    find_section_by_name(elf, e_shoff, ..., CODESIGN_NAME).is_some()
}
```

### 2.2 mordant 的 CI 报告

```
warning: --> src/ohos_sign/src/elf.rs:66:32
warning: --> src/ohos_sign/src/elf.rs:123:59
note: `tuple_wants_struct` over the mordant baseline (0 recorded for src/ohos_sign/src/elf.rs)
warning: mordant: 1 finding(s) over the baseline in ohos_sign
```

baseline 里 `ohos_sign` 的记录数是 **0**（新 crate，从未有过 baseline 记录）。

---

## 3. 四方对比

### 3.1 ohos_sign 的存在性

| 仓库 | ohos_sign 存在 | elf.rs tuple 返回 | 说明 |
|---|---|---|---|
| **v1.4.0（上游 oven-sh/bun）** | ❌ 没有 | ❌ 不适用 | 上游没有 OHOS 构建需求 |
| **social4hyq/ohos-bun** | ✅ 有 | ✅ 同样的 tuple | OHOS 适配引入 |
| **ljy9812/bun** | ✅ 有 | ✅ 同样的 tuple | OHOS 适配引入 |
| **我们 jx-bit/bun** | ✅ 有 | ✅ 同样的 tuple | 从 ljy9812/social4hyq 继承 |

**上游没有 ohos_sign**——这是 OHOS 适配引入的全新 crate。
上游 v1.4.0 的 `mordant-baseline.toml` 里没有 ohos_sign 的记录（也不应该有）。

### 3.2 mordant CI 为什么只有我们失败

| 仓库 | mordant job 设置 | ohos_sign 在 workspace | 会失败吗 |
|---|---|---|---|
| **v1.4.0（上游）** | `continue-on-error: true` | ❌ 没有 ohos_sign | ❌ 不会 |
| **social4hyq** | `continue-on-error: true`（advisory） | ✅ 有 | ❌ 不会（advisory 不阻断） |
| **ljy9812** | 旧版独立 mordant.yml，有 `continue-on-error` | ✅ 有 | ❌ 不会（advisory 不阻断） |
| **我们 jx-bit/bun** | **无 continue-on-error** | ✅ 有 | ✅ **会失败** |

**根因**：上游和 social4hyq 的 mordant job 都设了 `continue-on-error: true`（advisory，建议性的），即使有 finding 也不阻断 CI。我们的 `rust-lints.yml` merge v1.4.0 后，mordant job 的 `continue-on-error` 属性丢失了。

**上游注释**：
```yaml
# Advisory while the pack is new: shows up on the PR, does not block it.
continue-on-error: true
```

social4hyq 也有相同的设置和注释。

### 3.3 mordant-baseline.toml 对比

| 仓库 | baseline 有 ohos_sign | 说明 |
|---|---|---|
| **v1.4.0（上游）** | ❌ 不适用（无 ohos_sign） | 上游没有 OHOS |
| **social4hyq** | ❌ 没有 | 但 advisory 不阻断，所以不失败 |
| **ljy9812** | ❌ 没有 | 同上 |
| **我们** | ❌ 没有 | **无 continue-on-error → CI 硬失败** |

所有仓库的 baseline 都没有 ohos_sign 记录。social4hyq 和 ljy9812 不会失败是因为 advisory 设置，不是因为 baseline 里有记录。

---

## 4. 修复方案

### 方案 A：tuple 改为 struct（消除 finding）

```rust
/// Parsed ELF section header table metadata.
struct SectionHeaderTable {
    e_shoff: u64,
    e_shnum: u16,
    e_shstrndx: u16,
    e_shentsize: u16,
}

fn parse_header(elf: &[u8]) -> Result<SectionHeaderTable, SignError> {
    ...
    Ok(SectionHeaderTable { e_shoff, e_shnum, e_shstrndx, e_shentsize })
}
```

### 方案 B：ohos_sign 加进 mordant-baseline.toml

```toml
[ohos_sign]
"tuple_wants_struct:src/ohos_sign/src/elf.rs" = 1
```

### 方案 C：mordant job 加 `continue-on-error: true`（对齐上游和 social4hyq）

```yaml
mordant:
    continue-on-error: true   # Advisory: shows findings, does not block
```

### 各方案对比

| 方案 | 效果 | 工作量 | 推荐度 |
|---|---|---|---|
| A: tuple → struct | 消除 finding，代码更好 | ~15 行 | ⭐⭐⭐ |
| B: baseline 登记 | CI 通过，finding 保留 | 2 行 | ⭐⭐ |
| C: continue-on-error | CI 通过，finding 保留 | 1 行 | ⭐（但应该有——上游有） |

### 推荐

**同时做 A + C**：
- A 消除 tuple_wants_struct finding（代码改进）
- C 对齐上游的 advisory 设置（防止未来 OHOS 专属代码产生新的 mordant finding 阻断 CI）

---

## 5. 涉及的文件

| 文件 | 改动 |
|---|---|
| `src/ohos_sign/src/elf.rs` | tuple → struct（方案 A，~15 行） |
| `.github/workflows/rust-lints.yml` | mordant job 加 `continue-on-error: true`（方案 C，1 行） |
| `mordant-baseline.toml` | 方案 B 时才需要（用方案 A 则不需要） |

---

## 6. 验证方法

1. OHOS build 编译通过
2. mordant CI 检查通过
3. `bun run rust:mordant` 本地无 finding

---

## 7. 术语速查

| 术语 | 解释 |
|---|---|
| **mordant** | bun 使用的 dylint lint 集合（Rust 自定义编译器 lint） |
| **dylint** | 基于 Rust 编译器的自定义 lint 框架 |
| **baseline（基线）** | 按文件记录的历史 finding 数量，追踪新增 |
| **ratchet（棘轮）** | 只能变好不能变差的机制：新增 finding 失败，修复通过 |
| **tuple_wants_struct** | mordant lint：函数返回 4+ 元素 tuple 时建议改用 struct |
| **ohos_sign** | OHOS ELF 签名 crate（用于设备上签名 bun 二进制） |
| **`mordant-baseline.toml`** | mordant 的 baseline 文件 |
| **`over-baseline.txt`** | mordant 运行时生成的文件，列出超出 baseline 的 finding |
| **`continue-on-error`** | GitHub Actions 属性：job 失败不让整个 workflow 失败 |
| **advisory** | 建议性的 CI 检查（失败不阻断，只显示警告） |
| **`elf.rs`** | OHOS ELF 签名的核心实现：解析 ELF header 和 section table |
| **`SignError`** | ohos_sign 的错误类型（NotElf64, NoSectionHeaders 等） |

---

## 8. 为什么上游没有这个问题

这个问题是 **OHOS 专属的**——上游 oven-sh/bun 根本没有 `ohos_sign` crate：

| 组件 | 上游 v1.4.0 | 我们 |
|---|---|---|
| `ohos_sign` crate | ❌ 不存在 | ✅ 存在（OHOS 设备签名） |
| `mordant-baseline.toml` 有 ohos_sign | ❌ 不适用 | ❌ 没有（导致失败） |
| `rust-lints.yml` mordant `continue-on-error` | ✅ 有 | ❌ 没有（merge 丢失？） |
| OHOS 设备需要签名 | ❌ 不需要 | ✅ 需要（seccomp 拦截未签名 ELF） |

上游没有 OHOS 构建需求，没有 ohos_sign crate，自然不会有这个 finding。
这是 **OHOS 适配引入的新 crate 产生的新的 mordant finding**——baseline 里需要登记或消除。

---

*文档日期：2026-09-01 | 分析者：Sisyphus*
*关联文件：`src/ohos_sign/src/elf.rs`、`mordant-baseline.toml`、`dylint.toml`*
*关联 PR：PR #8（mordant 失败）*
*关联上游：oven-sh/bun 的 `rust-lints.yml`（continue-on-error: true）*