# P2: run_command.rs OHOS gate 不足 — 详细讲解
> **状态：✅ 已修复**。**关联 PR**：[#7](https://github.com/jx-bit/bun/pull/7)（补齐缺失的 5 个 OHOS gate）

> 我们只有 2 个 OHOS gate（`ohos_set_pwd`），social4hyq 有 7 个。
> 缺失的 5 个 gate 处理目录读取失败和 npm 环境变量播种的 OHOS 兼容。

---

## 1. 背景：`bun run` 做了什么

### 1.1 `bun run` 的执行流程

当用户执行 `bun run script.js` 时，`run_command.rs` 里的 `configure_env_for_run_impl`
函数负责配置运行环境。流程如下：

```
1. 设置 $PWD（ohos_set_pwd — 解决 getcwd 失败）
       ↓
2. 读取当前目录信息（read_dir_info）
       ↓
3. 如果目录读取失败 → 报错退出
       ↓
4. 用目录信息设置 npm 环境变量（npm_package_name、npm_package_version 等）
       ↓
5. 找到 shell，启动子进程
```

### 1.2 OHOS 上的目录读取问题

OHOS 的 hmdfs 文件系统 + SELinux 会导致 `read_dir_info()` 出现两种异常：

| 异常 | 原因 | 非OHOS行为 | 应有的OHOS行为 |
|---|---|---|---|
| `Err(EPERM)` | SELinux 拦截目录读取 | 报错退出 | 容错，fallback 到 $HOME |
| `Ok(None)` | hmdfs 返回空 | 报错退出 | 容错，fallback 到 $HOME |

**非 OHOS 平台**：目录读取失败 = 真实错误，应该退出。
**OHOS 平台**：目录读取失败可能是 SELinux 误拦截，应该 fallback 到 $HOME 继续。

### 1.3 npm_package_* 环境变量

`bun run` 会在环境变量里设置 `npm_package_name`、`npm_package_version` 等。
这些变量告诉脚本"你正在运行的是哪个包"。

```
例如：在 /home/user/my-project/ 下运行 bun run build
→ npm_package_name = "my-project"
→ npm_package_version = "1.0.0"
→ npm_package_json = "/home/user/my-project/package.json"
```

如果目录读取失败后 fallback 到 $HOME，$HOME 的 package.json 可能是**另一个项目**，
不应该把它的 name/version 播种到环境变量里——否则脚本会以为自己在运行 $HOME 的项目。

---

## 2. 问题是什么

### 2.1 我们的代码（v1.4.0 重构版 + ohos_set_pwd）

当前代码在 `configure_env_for_run_impl` 里（line 644-675）：

```rust
let root_dir_info: DirInfoRef =
    match this_transpiler.resolver.read_dir_info(top_level_dir) {
        Err(err) => {
            // 所有平台统一行为：报错退出
            return Err(crate::Error::CouldntReadCurrentDirectory);
        }
        Ok(None) => {
            // 所有平台统一行为：报错退出
            return Err(crate::Error::CouldntReadCurrentDirectory);
        }
        Ok(Some(info)) => info,
    };

// 后面直接用 root_dir_info（没有 fallback 逻辑）
if let Some(package_json) = root_dir_info.enclosing_package_json {
    // 总是播种 npm_package_*（没有 fallback 判断）
    env_loader.map.put(b"npm_package_name", &package_json.name);
}
```

**问题**：
1. OHOS 上 EPERM/EACCES → 直接退出（没有 fallback）
2. OHOS 上 Ok(None) → 直接退出（没有 fallback）
3. 没有 fallback 目录的逻辑
4. 没有判断当前目录是否是 fallback（总是播种 npm_package_*）

### 2.2 social4hyq 的代码（7 个 gate）

social4hyq 在**同样的位置**加了 5 个额外的 cfg gate：

```rust
let root_dir_info: Option<DirInfoRef> =
    match this_transpiler.resolver.read_dir_info(top_level_dir) {
        // Gate 2: OHOS 上 EPERM/EACCES 不报错
        #[cfg(target_env = "ohos")]
        Err(err) if with_linker
            && (err == EPERM || err == EACCES) => None,
        // 非 OHOS：报错退出
        Err(err) => {
            return Err(crate::Error::CouldntReadCurrentDirectory);
        }
        // Gate 3: OHOS 上 Ok(None) 不报错
        #[cfg(target_env = "ohos")]
        Ok(None) if with_linker => None,
        // 非 OHOS：报错退出
        Ok(None) => {
            return Err(crate::Error::CouldntReadCurrentDirectory);
        }
        Ok(Some(info)) => Some(info),
    };

// Gate 4: OHOS 上 None → fallback 到 $HOME
#[cfg(target_env = "ohos")]
let mut root_dir_info_is_fallback = false;
#[cfg(target_env = "ohos")]
let root_dir_info: DirInfoRef = match root_dir_info {
    Some(info) => info,
    None => {
        root_dir_info_is_fallback = true;  // 标记是 fallback
        let home = std::env::var("HOME").unwrap_or_default();
        let info = resolver.read_dir_info_ignore_error(home)
            .or_else(|| resolver.read_dir_info_ignore_error(b"/"))  // HOME 不行就用 /
            .ok_or(crate::Error::InstallFailed)?;
        // 打印警告
        pretty_errorln!("warn: cannot read {}; resolving from {} instead", ...);
        info
    }
};
// Gate 5: 非 OHOS 直接 expect（保证不为 None）
#[cfg(not(target_env = "ohos"))]
let root_dir_info: DirInfoRef =
    root_dir_info.expect("Ok(None)/EPERM/EACCES arms are OHOS-only");

// ... 后面的 npm_package_* 播种逻辑 ...

// Gate 6: OHOS 上 fallback 时不播种
#[cfg(target_env = "ohos")]
let seed_package_env = !root_dir_info_is_fallback;
// Gate 7: 非 OHOS 总是播种
#[cfg(not(target_env = "ohos"))]
let seed_package_env = true;

if let Some(package_json) = root_dir_info.enclosing_package_json.filter(|_| seed_package_env) {
    // 只有 seed_package_env = true 时才播种
    env_loader.map.put(b"npm_package_name", &package_json.name);
}
```

### 2.3 5 个缺失 gate 的对照

| # | social4hyq 的 gate | 我们有没有 | 作用 |
|---|---|---|---|
| 1 | `ohos_set_pwd` | ✅ 有 | 设 $PWD 让 bash 不用 getcwd |
| 2 | `Err(EPERM/EACCES)` → `None` | ❌ 没有 | OHOS 上 SELinux 拦截时不退出，返回 None |
| 3 | `Ok(None)` → `None` | ❌ 没有 | OHOS 上目录不存在时不退出，返回 None |
| 4 | `None` → fallback to `$HOME` | ❌ 没有 | 用 $HOME 或 / 作为 resolver 起点 |
| 5 | 非 OHOS `expect` | ❌ 没有 | 非 OHOS 断言 root_dir_info 不为 None |
| 6 | fallback 时不播种 `npm_package_*` | ❌ 没有 | 避免用 $HOME 的 package.json 的 name/version |
| 7 | 非 OHOS 总是播种 | ❌ 没有 | 非 OHOS 保证 npm_package_* 可用 |

---

## 3. 缺失 gate 的实际影响

### 3.1 场景：SELinux 拦截目录读取

```
用户在 /data/storage/el2/base/tmp/my-project/ 下运行 bun run build
→ read_dir_info("/data/.../my-project/") 返回 Err(EPERM)
→ 我们的代码：报错退出 ❌
→ social4hyq 的代码：fallback 到 $HOME，打印警告，继续运行 ✅
```

### 3.2 场景：hmdfs 目录不存在

```
用户在 hmdfs 挂载点上运行 bun run
→ read_dir_info 返回 Ok(None)
→ 我们的代码：报错退出 ❌
→ social4hyq 的代码：fallback 到 $HOME，继续运行 ✅
```

### 3.3 场景：fallback 后的 npm_package_* 播种

```
目录读取失败 → fallback 到 $HOME = /home/user
/home/user/package.json = { "name": "dotfiles", "version": "0.0.1" }
→ 我们的代码：用 fallback 目录的 package.json 播种
  → npm_package_name = "dotfiles"  ← 错误！
→ social4hyq 的代码：root_dir_info_is_fallback = true → 不播种
  → npm_package_name 不设置 ← 正确
```

---

## 4. 三方对比

| | 我们 | social4hyq | ljy9812 |
|---|---|---|---|
| 基础版本 | v1.4.0（ConfigureEnvOptions） | OHOS base | OHOS base |
| `ohos_set_pwd` | ✅ | ❌（没有） | ✅ |
| EPERM → None | ❌ | ✅ | ❌ |
| Ok(None) → None | ❌ | ✅ | ❌ |
| fallback to $HOME | ❌ | ✅ | ❌ |
| 非 OHOS expect | ❌ | ✅ | ❌ |
| fallback 不播种 | ❌ | ✅ | ❌ |
| 非 OHOS 总是播种 | ❌ | ✅ | ❌ |
| cfg gate 总数 | 2 | 7 | 3 |

**注意**：social4hyq 没有 `ohos_set_pwd`（他们用 Gate 4 的 `read_dir_info_ignore_error`
解决了 `getcwd` 问题——fallback 目录不依赖 `getcwd`）。我们两者都有（不冲突）。

---

## 5. 修复方案

在 `configure_env_for_run_impl` 函数里补 5 个 gate。

### 5.1 需要修改的位置

**位置 1**：`read_dir_info` 的 match 块（line 644-675）

在 `Err(err)` 和 `Ok(None)` 分支前加 OHOS gate。

**位置 2**：match 块后（line 676）

加 fallback 到 $HOME 的逻辑 + 非 OHOS expect。

**位置 3**：`npm_package_*` 播种前（line 754）

加 `seed_package_env` 判断。

### 5.2 修改难度

**中等**——需要把 social4hyq 的 gate 逻辑适配到 v1.4.0 的代码结构上。
主要差异：
- social4hyq 的 `root_dir_info` 类型是 `Option<DirInfoRef>`
- v1.4.0 的 `root_dir_info` 类型是 `DirInfoRef`（不是 Option）
- 需要把 v1.4.0 的 `DirInfoRef` 改成 `Option<DirInfoRef>`，然后 Gate 4 展开

### 5.3 代码量

约 40 行新增（5 个 gate × ~8 行/gate）。

---

## 6. 涉及的文件

| 文件 | 改动 |
|---|---|
| `src/runtime/cli/run_command.rs` | 补 5 个 OHOS cfg gate（~40 行） |

---

## 7. 验证方法

1. OHOS build 编译通过
2. 设备上在 SELinux 受限目录运行 `bun run` → 应该 fallback 到 $HOME 而不是退出
3. fallback 后 `echo $npm_package_name` → 不应该有值

---

## 8. 术语速查

| 术语 | 解释 |
|---|---|
| **cfg gate** | `#[cfg(target_env = "ohos")]` 条件编译，只在 OHOS 编译时生效 |
| **read_dir_info** | 读取目录信息，返回 `DirInfoRef` 或 `Err` |
| **EPERM** | 权限被拒（Operation not permitted） |
| **EACCES** | 权限被拒（Permission denied） |
| **hmdfs** | OHOS 的分布式文件系统（HarmonyOS Distributed File System） |
| **SELinux** | 安全增强 Linux，OHOS 用它限制文件访问 |
| **fallback 目录** | 原目录读取失败时，用 $HOME 代替 |
| **DirInfoRef** | 目录信息的引用类型 |
| **read_dir_info_ignore_error** | 读取目录信息但忽略错误（用于 fallback） |
| **npm_package_*** | npm 的环境变量（name、version、config 等） |
| **seed（播种）** | 把 package.json 的内容设到环境变量里 |
| **root_dir_info_is_fallback** | 标记当前目录是真实的还是 fallback 的 |
| **ConfigureEnvOptions** | v1.4.0 重构的结构体，打包 `log_errors` + `store_root_fd` |
| **with_linker** | 是否加载 bundler linker（有 linker 时才做 fallback） |
| **ohos_set_pwd** | 设 $PWD 让 bash 用 stat 代替 getcwd（hmdfs getcwd 会失败） |

---

*文档日期：2026-08-31 | 分析者：Sisyphus*
*关联文件：`src/runtime/cli/run_command.rs`*
*关联差异：social4hyq 有 7 个 gate，我们只有 2 个*
