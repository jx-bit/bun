# P0: v1.4.2 OHOS 资产无法启动——`--wrap` 在动态 musl 链接下产出未解析 `__real_*` 重定位
> **关联 PR**：[#93](https://github.com/jx-bit/bun/pull/93)

> v1.4.2 同步（#92）把上游 #40978 的 `-Wl,--wrap=execve/pthread_create` 带进交付线且未对
> OHOS 门控。bun-ohos 动态链接 ld-musl.so，lld 的 `--wrap` 无法解析 `__real_*`（仅静态链接
> 期可见），lld 只警告不报错——产物带未解析动态重定位出炉，设备 musl loader 启动即硬失败。
> **v1.4.2 发布资产执行即死，`--version` 都跑不了。**

## 1. 用户影响速览

| 缺陷 | 用户在做什么 | 感知症状 | 频率 | 严重度 |
|---|---|---|---|---|
| 二进制带未解析 `__real_execve`/`__real_pthread_create` 动态重定位 | 安装 v1.4.2 OHOS 包后执行任意命令（含 `bun --version`） | `Error relocating: __real_execve: symbol not found`，进程启动即死，零 JS 执行 | 必现（100%） | 最高（资产完全不可用） |

## 2. 根因

- 上游 ceef54734d（#40978）：内核竞态修复——任一线程处于 execve(2) 期间，clone(CLONE_FS)
  全部 EAGAIN（fs/exec.c check_unsafe_exec × kernel/fork.c copy_fs），杀死 --watch 重载。
  修法 = 链接期 `-Wl,--wrap=execve -Wl,--wrap=pthread_create`，`__wrap_*` 检测 in-flight exec
  并重试 EAGAIN。上游 Linux 构建静态 musl 链接，`__real_*` 静态期可解析。
- 交付线 `scripts/build/flags.ts` 的该条目 `when: c => c.linux`——而 config.ts 中
  `linux = os === "linux"` 对 `aarch64-linux-ohos` 恒真，wrap 无条件施加于 OHOS。
- OHOS 动态链接：`__real_*` 只在静态链接期可见，lld 对共享对象场景**只警告**，产物带
  UND 动态重定位出炉；设备 musl loader 重定位时符号不存在 → 硬失败。
- 三层门禁全空：lld 警告被无视；构建后冒烟 `--revision` 无法在构建机执行交叉产物；
  release lane 无设备冒烟（对比 1.4.0_1 发布有 SOP 探针+smoke 记录）。
- 关键对照：1.4.0_1 资产 0 个 `__real_*` 动态引用（早于 #40978，干净）。

## 3. 修复（cherry-pick ec3e87874c2，三文件 +142/-3）

| 文件 | 内容 |
|---|---|
| `scripts/build/flags.ts` | wrap 条目 `when: c => c.linux` → `when: c => c.linux && !c.ohos`（+注释说明排除原因与替代机制） |
| `src/jsc/bindings/c-bindings.cpp` | 新增 `#if defined(__OHOS__)` 分支：平名 `execve`/`pthread_create` 经 `dlsym(RTLD_NEXT, ...)` 解析，与 `__wrap_*` 同款重试算法（仅 in-flight exec 期间重试 EAGAIN，上限 1000 次）；真函数指针在 `bun_initialize_process()` 急切解析——懒 dlsym 会在 CLONE_VM\|CLONE_VFORK 子进程内（posix_spawn 路径）与被挂起的父进程抢动态链接器锁；`execve_counting_pid = getpid()` 移出非 OHOS 守卫，两变体共享 in-flight 记账 |
| `scripts/build/workarounds.ts` | 注册 `ohos-pthread-create-execve-interpose`（自过时登记，`expectedToBeFixed: () => false`——架构失配非工具链版本差），含清理指引 |

## 4. 验证

- `bunx tsc --noEmit`（scripts/build）：基线错误集与 base 完全一致（9 个既有错误，
  stash 对照实测），本改动零新增。
- `__OHOS__` dlsym 分支与 `__wrap_*` 分支分别以
  `clang++ --target=aarch64-linux-ohos --sysroot=<真机 musl sysroot> -fsyntax-only`
  编译通过——平名定义与 musl 自身声明签名兼容（此类插桩的真实编译风险点）。
- c-bindings.cpp 预处理器平衡程序化校验通过（cherry-pick 曾吞掉一个 `#endif`，已修复）。
- 未修复构建失败声明：任意未打此补丁的 OHOS 构建，执行即报
  `Error relocating: __real_execve: symbol not found`。
- CI 容器构建 + 设备冒烟/fulltest：本 PR 上待跑。

## 5. 与参考实现（social4hyq ec3e87874c2）的对比

本 PR 即该提交的 cherry-pick（〔源码〕逐字核验）：

| 项 | 参考实现 | 本 PR | 差异 |
|---|---|---|---|
| flags.ts 门控 | `when: c => c.linux && !c.ohos` | 同 | 无（注释措辞按交付线树适配） |
| c-bindings.cpp `__OHOS__` dlsym 分支 | 急切解析 + 平名插桩 + 同款重试 | 同（逐字） | 无 |
| `bun_initialize_process` 急切解析 | `execve_counting_pid` 移出守卫 + eager resolve | 同 | 无 |
| workarounds.ts 登记条目 | `ohos-pthread-create-execve-interpose` | 同 | 无 |
| OHOS_TEST_STATUS.md 基线修正 | 有 | **丢弃** | 该文件为参考树簿记，交付线不存在 |
| ohos-node-userinfo-preload 登记条目 | 同提交 diff 混入 | **丢弃** | 交付线机制已在（#52 合并），登记条目系参考树侧另行补记，非本修复面 |

参考实现的设备验证（2026-09-05 20 核真机基线：watch/execve EAGAIN 3/3 稳定清除）适用
于同一段代码；本 PR 的设备验收以其为预期口径。

## 6. 流程缺口（另行跟进）

1. release lane 无设备冒烟门禁——`bun --version` 一条命令即可拦住本次事故。
2. 宿主侧可加确定性审计：发布前 `readelf` 断言产物无 `__real_*` 未解析动态重定位
   （不依赖设备，可进 CI）。
3. `c.linux` 谓词对 OHOS 恒真是结构性隐患：今后上游任何 `when: c => c.linux` 旗标
   默认毒害 OHOS。每次 upstream sync 的 merge checklist 应审计新增 `-Wl,--wrap` 与
   `c.linux` 旗标（本条已由 workarounds.ts 登记覆盖本例，类级防线待 #6.2 的 CI 审计）。
