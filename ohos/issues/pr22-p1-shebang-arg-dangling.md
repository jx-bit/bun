# P1: shebang 展开丢失可选参数 CString — env 收到堆垃圾字节 — 详解（重写版）

> **关联 PR**：[#22](https://github.com/jx-bit/bun/pull/22)（单 commit，2 文件 +109/-24）
> **状态**：🔄 OPEN（checks 验证中）
> **定位**：shebang 展开（PR #17）移植时引入的所有权 bug —— 只影响带可选
> 参数的 shebang（`#!/usr/bin/env X`）。

---

## 1. 背景：shebang 展开在做什么（30 秒回顾）

OHOS 内核拒绝 exec 未签名 ELF。脚本（文本文件）没有 .codesign 段，无法
签名 → 内核的 binfmt_script 透明转交也过不了签名关卡。解法：bun 在
spawn 前解析 `#!` 行，**改为 exec 已签名的解释器**，脚本降级为普通参数：

```
spawn(["./run.sh"])
  ↓ bun 读 run.sh 头部 → "#!/usr/bin/env bash"
重写 exec：  argv0 = /usr/bin/env（已签名的 ELF）
             argv   = [/usr/bin/env, "bash", "./run.sh"]
  ↓ env 在 PATH 里找到 bash → bash 执行 run.sh
```

脚本自始至终只被**读取**，从未被 exec —— 签名关卡绕过。

## 2. Bug 的逐步内存图

以 `spawn(["/tmp/t.sh"])`、脚本头 `#!/usr/bin/env bash` 为例，
修复前的代码（`spawn_process.rs :: ohos_expand_shebang`）：

```rust
let interp = CString::new("/usr/bin/env")?;      // ① 堆分配 A
let script = CString::new("/tmp/t.sh")?;         // ② 堆分配 B
let arg    = CString::new("bash")?;              // ③ 堆分配 C

let mut owned = Vec::new();                      // keepalive（本应持有全部）
let mut ptrs  = Vec::new();                      // argv 指针数组

ptrs.push(interp.as_ptr());                      // ptrs[0] → A
if let Some(a) = &arg {
    ptrs.push(a.as_ptr());                       // ptrs[1] → C（此刻有效）
}
ptrs.push(script.as_ptr());                      // ptrs[2] → B
owned.push(script);                              // ✅ 只有 B 进了 keepalive
// ❌ C（arg）没有任何去处 —— 它是局部变量

Some(ShebangRewrite { interp, _owned: owned, ptrs })
// ④ 函数返回：arg（C）drop → 堆缓冲区释放
//    ptrs[1] 仍指向 C 的已释放内存 → 悬垂指针
```

### 2.1 三个 CString 的命运

| CString | 内容 | push 的指针 | 所有权去向 | 结局 |
|---|---|---|---|---|
| interp（A） | `/usr/bin/env` | ptrs[0] | **move 进返回的 struct** | ✅ 存活 |
| script（B） | `/tmp/t.sh` | ptrs[2] | **move 进 `_owned` Vec** | ✅ 存活 |
| **arg（C）** | `bash` | ptrs[1] | **谁都没给 —— 局部变量** | ❌ 函数退出即 drop |

### 2.2 posix_spawn 时刻发生了什么

```
argv = [ptrs[0]→A "/usr/bin/env", ptrs[1]→C "bash"(已释放!), ptrs[2]→B "/tmp/t.sh", ...]

exec("/usr/bin/env", ["env", <ptrs[1]>即垃圾, "/tmp/t.sh", ...])
  → env: '\310\021\360\255\022\004': No such file or directory
  → env 退出 127 → 脚本没跑 → 测试得空输出
```

`ptrs[1]` 的内容是**释放后的堆内存**——分配器可能已把它复用给别的分配，
所以每次的字节都不同（`\310\021\360\255\022\004`、`\200\a\260rn\005`、
`p\apĀ\004`……）—— 这正是"use-after-free 读到垃圾"的签名。

### 2.3 为什么只有带可选参数的 shebang 触发

| 脚本头 | parse 结果 | argv 指针 | 悬垂？ |
|---|---|---|---|
| `#!/bin/sh` | interp=/bin/sh, arg=无 | ptrs=[A,B] 都有主 | ✅ 过 |
| `#!/usr/bin/env bash` | interp=/usr/bin/env, arg=bash | ptrs=[A,**C悬垂**,B] | ❌ 垃圾 |

`env: '\310...'` 与 `env: '\200\a\260rn\005'` 的垃圾不同 = 释放堆的残留
内容不同 —— 同一 bug 的两次独立取样。

## 3. 为什么此前"看起来随机"

- 无参脚本（`#!/bin/sh`）不受影响 → 同一测试文件里部分用例过、部分挂
- 悬垂读取的内容取决于堆状态 → 报错字节每次不同 → 像随机
- 只在 OHOS 通道出现（展开逻辑 cfg(target_env="ohos")）—— 上游 Linux
  走内核 binfmt_script，无此代码

## 4. 修复（所有权先行，指针在后）

```rust
let mut owned = Vec::new();
if let Some(a) = &arg {
    owned.push(a.clone());        // ← 先入 keepalive（克隆亦可）
}
owned.push(script);

let mut ptrs = Vec::new();
ptrs.push(interp.as_ptr());
for s in &owned {
    ptrs.push(s.as_ptr());        // ← 指针从 owned 取，绝无悬垂
}
ptrs.extend_from_slice(tail);
ptrs.push(std::ptr::null());
```

**不变量**：`ptrs` 的每个条目都必须 alias 一个被返回结构体持有的
CString（`interp` 或 `_owned`）—— 活到 posix_spawn 之后。

装配逻辑抽为 `shebang.rs :: build_rewrite(interp, arg, script, tail)`
（纯函数，宿主可测），`ohos_expand_shebang` 只负责读文件 + 调用。

## 5. 怎么测试验证（四层）

### 5.1 单元回归测试（已入 PR，锁定 bug 类）

`src/spawn_sys/shebang.rs :: rewrite_owns_every_entry_it_points_to`：

- 构造 `#!/usr/bin/env bash` 的完整 rewrite
- 断言 argv 形状：`[interp, arg, script, tail..., null]` 逐项内容正确
- **断言所有权对应**：`_owned[0].as_ptr() == ptrs[1]`、
  `_owned[1].as_ptr() == ptrs[2]` —— bug 存在时 ptrs[1] 不对应任何
  owned 条目 → 断言失败
- 无参变体（`rewrite_without_optional_arg`）：ptrs = [interp, script, null]

运行：`cargo test -p bun_spawn_sys`（CI 全量构建环境）。

### 5.2 手动复现（真机或容器，1 分钟）

```bash
# 准备一个带可选参数 shebang 的脚本
cat > /tmp/t.sh <<'EOF'
#!/usr/bin/env bash
echo "hello from script"
EOF
chmod +x /tmp/t.sh

# 修复后 binary：
bun-ohos /tmp/t.sh
#   → "hello from script"（每次都一样）

# 修复前 binary（对照，可选）：
#   → env: '<每次不同的垃圾字节>': No such file or directory
```

**判据**：旧 binary 跑 N 次失败 N 次、且 env 的报错参数每次不同（垃圾）；
新 binary 稳定输出。无参 shebang 的脚本（`#!/bin/sh -c 'echo ok'` 模式）
在两个版本上行为一致 —— 排除环境干扰。

### 5.3 定向 CI 验证（按路径过滤，~10 分钟）

```bash
gh api -X POST repos/jx-bit/bun/actions/workflows/ohos-container-test.yml/dispatches \
  -f ref=<分支> -f 'test-filter=js/bun/spawn' \
  -H "Authorization: token <classic token>"
```

关注用例：

| 用例 | 修复前 | 修复后 |
|---|---|---|
| `spawn-path > spawn uses PATH from env if present` | `""`（env 垃圾）| `hello from script` |
| `spawn-path > 相对 PATH 两条`（无参 shebang） | 本来就过（对照） | 仍过 |
| 任何 `#!/usr/bin/env node` 的 fixture 脚本 | env 垃圾 / 空输出 | 正常 |

### 5.4 全量轮验证

合并后的下一轮 container-test：此前 12 处 env 垃圾字节失败
（run 33955739117 分类）+ spawn-path —— 全部应消失。

## 6. 波及面

- **同根因失败**：fulltest 轮 12 处 env 垃圾字节 + spawn-path 空输出
  （run 33955739117 分类）—— 全部是 `#!/usr/bin/env X` 脚本
- **不受影响**：无参 shebang（走 binfmt_script 的内核路径——容器内核
  是 Linux，binfmt_script 可用；鸿蒙真机内核的 binfmt_script 行为是
  另一个议题，见 knowledge/primer §5.6 的参考实现讨论）
- **上游 Linux**：无此代码（cfg target_env="ohos"），零影响


## 7. social4hyq 的同位实现对比（他们的写法本身就是对的）

### 7.1 他们的代码（hyq 树 spawn_process.rs:1060-1068）

```rust
ptrs.push(interp_cs.as_ptr());
if let Some(a) = arg_cs {
    ptrs.push(a.as_ptr());
    owned.push(a);            // ← CString 立即 move 进 keepalive
}
ptrs.push(script_cs.as_ptr());
owned.push(script_cs);
```

关键：ptr push 与 `owned.push(a)` 在**同一个 if-let 里** —— CString 的堆
缓冲区地址跨 move 稳定，ptr 永远有效。三个 CString（interp/arg/script）
全部在返回前进入 keepalive。

### 7.2 keepalive 结构对比

| | 他们 | 我们（PR#22 修复后）|
|---|---|---|
| 载体 | `Option<(CString, Vec<CString>, Vec<*const c_char>)>` 元组（'shim labeled block 内联在 spawn 函数里） | `ShebangRewrite` 结构体（interp + _owned + ptrs），装配抽为 `shebang.rs :: build_rewrite` 纯函数 |
| arg 保活 | ptr push 与 `owned.push(a)` 同一 if-let | `owned.push(a.clone())` 先于 ptrs 取址 |
| 可测性 | 内联、无单测 | shebang.rs 独立模块 + 12 个单测（parse 10 + rewrite 所有权对应 2）|

语义在 PR#22 后**等价**；我们的结构体形式多了可测性（本次 bug 若有
对应关系单测，移植当时就会红）。

### 7.3 归属澄清

悬垂 bug 是**我们的 PR#17 移植**在重构 keepalive 时丢失了
`owned.push(a)` 引入的 —— social4hyq 的原始实现没有这个 bug
（此前对话中"springmin 原版"的表述是误标 —— 正确的实现出自
social4hyq 的树；springmin 的 spawn 文件本分支未比对，不下结论）。

### 7.4 他们块里我们已经对齐的其余细节

- 4096 缓冲（内核 binfmt_script 128 字节截断坑：深层 TMPDIR 路径
  截断后仍像合法绝对路径 → exec 目录 → 误导性 EACCES）✓
- 无换行 + buffer 满时的 bail（宁失败不截断）✓
- 解释器绝对路径要求 / CRLF / 空白处理 ✓
- CString 内部 NUL 的 bail ✓
- argv 尾部拷贝 + null 终止 ✓

---

*文档：Sisyphus | 2026-09-08 | 依据 run 34090874324 results.json + spawn_process.rs 源码 + social4hyq 同位实现比对*