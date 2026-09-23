# 20260908 轮 overlap（135 文件，两 binary 都挂）分类与要解决的问题清单

> 生成：2026-09-09。数据源：`20260908_fulltest_jxbit/lists/fail_overlap_both.txt`
> × 详报逐文件签名（122 个有 (fail) 签名 + 13 个超时/崩溃类）。
> overlap = 换 binary 也解决不了的公共债——**真正的"要解决的问题"都在这里**。

## 总分解

| 簇 | 文件数（约） | 根因 | 类别 | 修复载体 |
|---|---:|---|---|---|
| **AF_UNIX/hmdfs tmpdir 族** | ~45（node-net ×39 + install/http 散布） | `os.tmpdir()` 落 hmdfs，AF_UNIX bind EPERM（`bun.test.*/0.sock` 实证） | 设备环境 | **#27 已修**（tmpdir 探测）——下轮自动收敛 |
| **FFI/TCC libc 链接路径** | ~32（filesink ×21、fetch ×6、streams ×5、ffi/cc 家族） | FFI JIT（tinycc）链接 libc 时尝试 `/usr/lib/libc.so`——OHOS 无此路径（musl loader 在 `/lib/ld-musl-aarch64.so.1`） | **功能源码** | **待修**（见 P1） |
| **Bun.Terminal setRawMode** | ~12（terminal ×8、terminal-spawn ×4） | PTY raw mode 切换失败——T27（PTY 行规程限制）族的具体化 | **功能源码调查** | P2 |
| **bunx/安装安全检查误拒** | ~4 | "refusing to use bunx cache directory … not owned by current user"——hmdfs 上 stat uid 语义与 getuid 不匹配 | **功能源码调查** | P2 |
| 断言差异（toBe/toEqual/toContain 散布） | ~25 | 逐个甄别（行为差异 vs 测试过期） | 待查 | 逐条 |
| mkfifo 等 fixture 可移植性 | ~3 | 沙箱 PATH 无 mkfifo 可执行 | 测试源码 | P3 |
| 超时/崩溃（无 (fail) 签名） | 13 | 见验收清单 C 组 | 待查 | 下轮观察 |

## 要解决的问题清单（按优先级）

### P1-A：mkfifo/FIFO 族（×32 文件）—— ✅ 已确认并解决：无需代码改动，换我们的树即解

- **现象**：`Failed to open library "/usr/lib/libc.so": Error loading shared
  library`（ERR_DLOPEN_FAILED）——filesink ×21、fetch ×6、streams ×5，全部是
  FIFO/mkfifo 相关子用例（~2.7ms 快速失败）。
- **调用链**（20260908 详报堆栈实证）：测试 → `import { mkfifo } from "mkfifo"`
  → **tsconfig 别名 `"mkfifo": ["./mkfifo.ts"]`**（两棵树都有，npm 包是烟雾弹，
  实际走本地助手）→ `test/mkfifo.ts` → `dlopen(libcPathForDlopen())`。
- **根因**：**他们 harness 的 `libcPathForDlopen()` 在 openharmony 分支返回裸名
  `"libc.so"`**（注释假设动态链接器会经 LD_LIBRARY_PATH 解析）——消费级
  HarmonyOS PC 上裸名解析到**损坏/悬空的 `/usr/lib/libc.so`** → ENOENT。
  **他们 harness 有 bug**。
- **我们的树已经是对的**：我们的 `libcPathForDlopen()`（46a905a6cf 即含）
  openharmony 分支直接返回 `/system/lib/ld-musl-aarch64.so.1`（musl loader 本身
  就是 libc、导出全部符号、任何域可 dlopen），linux/musl 分支也先探测
  `/system/lib` → `/lib`。**领先他们的实现**。
- **为何三轮都挂**：三轮设备轮跑的都是**他们的树** → 他们的 helper bug 生效；
  我们树里修好的 helper 从未被设备轮执行过。
- **处置**：
  1. 我们树零代码改动——换我们的树跑，32 文件即绿（musl loader dlopen 对
     mkfifo 符号成立：libc 导出全部 POSIX 符号）
  2. 可选反哺：把我们的 openharmony 分支共享给他们的树（他们的裸名写法在消费级
     PC 上必挂，对他们也是真 bug）
  3. 台账备注：`test/package.json` 的 npm `mkfifo` 依赖被 tsconfig 别名遮蔽，
     实际不参与解析（防止后人误修）

### P1-B：AF_UNIX tmpdir 族——已修，验收待做

#27 探测覆盖 node-net ×39 等。**注意**：这些文件在 20260908 轮属 overlap（当时
两个 binary 都挂），下轮起随 #27 收敛——验收清单应把 node-net ×39 计入预期
转绿项（已补录）。

### P2-A：Bun.Terminal setRawMode（功能源码调查，×12 文件）

- **现象**：`Failed to set raw mode`（Terminal.rs:1663 throw）。
- **机制待查**：具体哪个 ioctl 失败、errno 是什么——与 T27（PTY 行规程不生成
  信号）同族但需要独立确认（可能是 TCSETS 被沙箱/行规程拒绝）。
- **方向**：设备端 `stty raw` 探针 + Terminal.rs 失败分支打点；若为行规程限制
  → class B 平台限制（测试门控）；若可绕行 → runtime 修复。

### P2-B：bunx 缓存目录所有权误拒（功能源码调查，×4 文件）

- **现象**：`refusing to use bunx cache directory … not a directory owned by
  the current user`（bunx_command.rs:1007/1307）。
- **机制待查**：hmdfs 上 `stat().st_uid` 与 `getuid()` 的映射语义（可能恒返回
  root/映射 id）→ 所有权启发式误拒。
- **方向**：设备端 stat 探针；若确认 uid 语义差异 → openharmony 下放宽或改用
  其他安全判据（同他们 compat-shim getpwuid_r 修复的思路——那个修的是名字，
  这个是 uid 比较）。

### P3：测试源码/基建

- mkfifo 依赖 → fixture 改用可移植 API（fs API/spawn mknod）
- 断言差异簇 ~25 个 → 逐条 triage（对照官方 v1.4.0 期望与 STATUS 台账）
- 13 个超时/崩溃文件 → 下轮观察

## 与其他文档的关系

- 平台字符串根因（23 文件）：pr29 / 对比文档 §3.0
- panic 根因（~10 文件）：pr28 / 对比文档 §3.2
- 树×binary 漂移（大头，非修复对象）：对比文档 §3.1
- 疑似挂起解除：对比文档 §3.5
- 本清单的 P1-A/P2-A/P2-B 为**新定位的功能源码问题**——20260908 轮分析的新增产出
