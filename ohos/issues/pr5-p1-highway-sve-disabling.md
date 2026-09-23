# P1: Highway SVE 禁用导致 32 用例回归
> **状态：✅ 已修复**。**关联 PR**：[#5](https://github.com/jx-bit/bun/pull/5)（移除 Highway SVE 禁用，恢复 32 用例）

> `HWY_DISABLED_TARGETS` 禁用 SVE 后保留了 EMU128 后端，可能导致 Highway dispatch
> 选择了 EMU128 而非 NEON，EMU128 的 `BitsFromMask` 结果与标量路径不一致。

---

## 1. 什么是 Highway SIMD

Highway 是 Google 开发的 C++ SIMD 库（类似 Rust 的 `std::simd`），bun 用它加速：
- **sourcemap 解码**（`highway_sourcemap.cpp`）— VLQ base64 解码的 SIMD 加速
- **JSON 结构索引**（`highway_json.cpp`）— simdjson 风格的 stage 1 解析
- **XML 解析**（`highway_xml.cpp`）— 结构化索引 + tape 生成
- **字符串搜索**（`highway_strings.cpp`）— memchr/memmem 的 SIMD 加速

Highway 支持**运行时 CPU dispatch**：编译时为多个 SIMD 后端生成代码（NEON、SVE、SVE2、
EMU128、Scalar），运行时自动选最好的。

### SIMD 后端层级（ARM64）

```
性能从高到低：
SVE2  >  SVE  >  NEON  >  EMU128  >  Scalar
（128-256bit）（可变长）（128bit）（软件模拟）（标量）
```

---

## 2. 问题是什么

### 2.1 我们做了什么

在 3 个 Highway 文件里加了 SVE 禁用：

**`highway_sourcemap.cpp`**：
```cpp
#if defined(__aarch64__)
#define HWY_DISABLED_TARGETS (HWY_ALL_SVE)
#endif

// ToBits 函数新增 SVE 分支：
#elif HWY_TARGET == HWY_SVE || HWY_TARGET == HWY_SVE2
    uint8_t bits[8] = {};
    hn::StoreMaskBits(d, m, bits);
    return *reinterpret_cast<uint64_t*>(bits);
```

**`highway_json.cpp`**：同样的 `HWY_DISABLED_TARGETS (HWY_ALL_SVE)`

**`highway_xml.cpp`**：`BUN_BFM` polyfill（CompressStore + Iota 模拟 BitsFromMask）

### 2.2 为什么要禁用 SVE

commit `7780f3e420` 的注释说：
> "BitsFromMask only defined for fixed-size SVE (SVE2_128/SVE_256) and NEON,
> not for scalable SVE/SVE2."

即 Highway 的 scalable SVE/SVE2 后端没有实现 `BitsFromMask` 函数。
编译时会报链接错误（missing symbol）。

### 2.3 禁用后的影响

| 指令 | 编译的后端 | 运行时选择 |
|---|---|---|
| `HWY_TARGETS = HWY_NEON` | 只编译 NEON | NEON（正确） |
| `HWY_DISABLED_TARGETS = HWY_ALL_SVE` | NEON + EMU128 + Scalar | **可能选 EMU128**（错误？） |

`HWY_DISABLED_TARGETS` 只禁用 SVE 系列，但保留了 EMU128（软件模拟 128 位）和 Scalar。
如果 Highway 的运行时 dispatch 因为某种原因选了 EMU128 而非 NEON，
EMU128 的 `BitsFromMask` 结果可能与 NEON 的标量路径不同 → SIMD 解码与标量解码不一致。

### 2.4 回归数据

| 测试 | 用例数 | 早期版 | 新版 | social4hyq |
|---|---:|---|---|---|
| `sourcemap-simd` | 24 | 24/0 ✅ | 0/24 ❌ | 24/0 ✅ |
| `console-iterator` | 8 | 17/0 ✅ | 9/8 ❌ | 17/0 ✅ |
| **合计** | **32** | ✅ | ❌ | ✅ |

social4hyq 通过 → 说明不禁用 SVE 也能正常工作。

---

## 3. social4hyq 怎么做的

social4hyq **不禁用 SVE**，也不加 polyfill：

```cpp
// social4hyq 的 ToBits — 极简，直接 BitsFromMask
static HWY_INLINE uint64_t ToBits(D d, M m)
{
#if HWY_TARGET <= HWY_AVX3
    return static_cast<uint64_t>(m.raw);
#else
    return hn::BitsFromMask(d, m);  // 信任 Highway 原生实现
#endif
}
```

social4hyq 的 Highway 版本/编译器配置可能不编译 scalable SVE 目标（Harmonybrew
的 clang 默认 `-march` 不含 SVE），所以不会触发 `BitsFromMask` 缺失问题。

social4hyq 还有 `highway_dispatch.h`（缓存 dispatch 结果，省 ~20 指令/调用），
我们通过 merge v1.4.0 也获得了这个文件。

---

## 4. 为什么 social4hyq 不需要禁用 SVE

可能的原因（按可能性排序）：

1. **Highway 版本差异**：social4hyq 有 429 个我们没有的上游 commit。
   如果其中一个 bump 了 `vendor/highway/` 版本，新版本可能已为 scalable SVE
   实现了 `BitsFromMask`。

2. **编译器配置差异**：Harmonybrew 的 clang 默认 `-march=armv8-a`（不含 SVE），
   Highway 的 `foreach_target.h` 不会编译 SVE 目标 → 不会触发缺失。
   我们的 CI 可能用了不同的 `-march` 或 clang 版本导致 SVE 被编译。

3. **`highway_dispatch.h`**：social4hyq 的 dispatch 缓存可能改变了后端选择逻辑。

---

## 5. 修复方案

### 方案 A：移除 `HWY_DISABLED_TARGETS`（对齐 social4hyq）

直接删掉 3 个文件里的 `HWY_DISABLED_TARGETS`、`ToBits` SVE 分支、`BUN_BFM` polyfill。

**前提**：需要验证我们的 Highway 版本是否已支持 scalable SVE 的 `BitsFromMask`。
如果不支持，编译会报 missing symbol。

### 方案 B：改用 `HWY_TARGETS = HWY_NEON`（严格只编译 NEON）

```cpp
#if defined(__aarch64__)
#define HWY_TARGETS (HWY_NEON)
#endif
```

只编译 NEON，不编译 EMU128/Scalar → 运行时只选 NEON → 结果正确。

**风险**：如果 CI 主机（aarch64-linux-gnu on Ampere SVE）的 Highway dispatch
需要 SVE 目标来通过编译检查，可能会报错。

### 方案 C：保留禁用但移除 EMU128（`HWY_DISABLED_TARGETS = HWY_ALL_SVE | HWY_EMU128`）

```cpp
#if defined(__aarch64__)
#define HWY_DISABLED_TARGETS (HWY_ALL_SVE | HWY_EMU128)
#endif
```

禁用 SVE 和 EMU128，只保留 NEON + Scalar。

### 推荐：方案 A（如果编译通过）→ 方案 B（如果 A 失败）

---

## 6. 涉及的文件

| 文件 | 当前改动 | 修复后（方案 A） |
|---|---|---|
| `highway_sourcemap.cpp` | `HWY_DISABLED_TARGETS` + `ToBits` SVE 分支 | 删除两者，恢复 v1.4.0 原版 |
| `highway_json.cpp` | `HWY_DISABLED_TARGETS` | 删除，恢复 v1.4.0 原版 |
| `highway_xml.cpp` | `BUN_BFM` polyfill（25 行） | 删除，恢复 v1.4.0 原版 |

---

## 7. 验证方法

1. 编译验证：`bun bd test test/js/node/module/sourcemap-simd.test.ts`
2. 如果编译失败（missing `BitsFromMask`）→ 退回方案 B
3. 如果编译成功且测试通过 → 32 用例回归修复

---

## 8. 术语速查

| 术语 | 解释 |
|---|---|
| **Highway** | Google 的 C++ SIMD 库，运行时 CPU dispatch |
| **NEON** | ARM64 的 128bit SIMD 指令集（所有 ARM64 CPU 都支持） |
| **SVE/SVE2** | ARM 的可变长 SIMD 指令集（只有新 CPU 支持） |
| **EMU128** | Highway 的软件模拟 128bit 后端（用标量代码模拟 SIMD） |
| **`HWY_DISABLED_TARGETS`** | 禁用指定后端编译（SVE 被禁用但 EMU128 保留） |
| **`HWY_TARGETS`** | 只编译指定后端（更严格，可以只留 NEON） |
| **`BitsFromMask`** | Highway 函数：把 SIMD mask 转成 uint64 bitmask |
| **`ToBits`** | bun 的封装：调用 `BitsFromMask` 或 `StoreMaskBits` |
| **`BUN_BFM`** | XML 用的 polyfill 宏：SVE 用自定义实现，其他用原生 |

---

*文档日期：2026-08-31 | 分析者：Sisyphus*
*关联文件：`highway_sourcemap.cpp`、`highway_json.cpp`、`highway_xml.cpp`*
*关联回归：sourcemap-simd(24) + console-iterator(8) = 32 用例*
