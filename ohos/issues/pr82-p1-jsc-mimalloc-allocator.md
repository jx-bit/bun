# P1: JSC 走 mimalloc 分配器——Bun.$ 每次调用 ~7KB 泄漏（线性不收敛，OOM 风险）
> **关联 PR**：[#82](https://github.com/jx-bit/bun/pull/82)

> 1.4.0 线上 JSC 内部分配器（libpas）在 `Bun.$` 工作负载下每次 spawn 泄 ~7KB，
> RSS 线性增长永不收敛。上游 1.4.1 起改为 JSC 分配走 Bun 的 mimalloc（webkit
> cmake `USE_MIMALLOC=ON` + mimalloc bump）。本 PR 只取分配器状态三行对齐上游
> 1.4.1，不携带其余 1.4.1 变更。

## 1. 用户影响速览

| 缺陷 | 用户在做什么 | 感知症状 | 频率 | 严重度 |
|---|---|---|---|---|
| JSC libpas 每 spawn 泄 ~7KB | 脚本里反复 `Bun.$` 跑命令（构建脚本 / 任务编排 / CI 工具链场景） | 进程 RSS 每 1 万次 spawn 涨 ~69MB 永不回落；3GB 限额下 ~43 万次被 OOM 杀掉，用户只看到"跑着跑着进程没了" | 长跑 shell 编排必现 | 高（长跑必 OOM） |

## 2. 根因

- **排除 shell 层**：v1.4.0..v1.4.1 间 `src/runtime/shell/` 全部 commit 逐一排查
  （管道错误路径 #40740/#40788、arraybuffer 重定向 unpin #40819、refcount 重构簇
  #40238/#40478/#40516、dead-code 三连），无一命中——JS 侧 `shell.ts` 与
  `ShellBindings.cpp` 在区间内零改动。
- **canary 二分钉死**（官方 npm 二进制 + 同款复现脚本 10 万次）：
  `1.4.0`（3516MB）与 canary `20260829.1`（735MB）/`0831.1`（733MB）均漏——
  8/24~8/31 合入的 refcount 重构与 #40788/#40819 全部排除；canary `0903.1`
  （48.9MB）已修，窗口内只剩分配器/WebKit 层变更（#41253 mimalloc bump、
  #41324 WebKit bump→prebuilt 带 `USE_MIMALLOC`）。
- **结论**：泄漏在 JSC 的 libpas 分配器，与 shell/子进程代码无关。

## 3. 修复（对齐上游 1.4.1 分配器状态）

| 文件 | 内容 |
|---|---|
| `scripts/build/deps/webkit.ts` | `WEBKIT_VERSION` → `6119947592b6e1c1faef02a4c2e03174cf05d062`（1.4.1 pin）；本地 cmake WebKit 构建加 `USE_MIMALLOC: "ON"` / `USE_EXTERNAL_MIMALLOC: "ON"`（非 ASAN，上游原句注释一并带入） |
| `scripts/build/deps/mimalloc.ts` | `MIMALLOC_COMMIT` → `6a64e1ba7f5b2130d4efccb67ec87fd0003f0f6a`（1.4.1 pin） |
| `.github/workflows/ohos-{build-github,full-test,container-test,build-rust,release}.yml` | `WEBKIT_REF` 全部 bump 到同一 pin——门禁是 `--webkit=local` 源码编译，老 pin（`0f966e81`/`caad865e`，实测 0 处 MIMALLOC 引用）上开关是静默空操作；release 门禁原默认 ref 指向不存在的分支（404），静默回退 runner 本地 `/home/user/sources/bun/vendor/WebKit`（版本无主），改 pin 后 clone 确定成功、回退路径失效 |

无运行时源码改动。与上游 v1.4.1 逐 hunk 核对：剩余 diff 全为 OHOS 定制块
（OHOS_WEBKIT_ROOT prebuilt 路径、OHOS cmake 交叉参数、`MI_NO_SET_VMA_NAME` 等）。
非 OHOS 平台（linux/windows/darwin 产物）走 prebuilt 下载路径，按 `webkit.ts`
版本号拉取，上游 `6119947592b6` 预编译包本身即带 mimalloc，随 pin 自动覆盖。

## 4. 验证

- 复现脚本（`await $\`echo hello\`` ×50 万、每万次采样 RSS，即设备侧 s3_min_repro3）：
  未修构建 1.4.0 线 linux-x64 / windows-x64 / 官方 1.4.0 FINAL RSS 3443~3518MB、
  线性 +69MB/万；官方 1.4.1/1.4.2 10 万次 ~47MB、2 万次后增量 ~0。**未修复构建
  跑此复现必失败（线性涨）**。
- 本机构建脚本 tsc：改动前后均 28 个既有错误，零新增。
- 待办：CI 门禁编译过绿 → 用 CI 产出 binary 复跑复现确认平台期 → 设备 fulltest 验收。
- OHOS 侧依赖：bun-webkit formula 需在新 pin 重编（`OHOS_WEBKIT_ROOT` 路径），
  开关随 webkit.ts 自动传入。

## 5. 与 social4hyq 实现的对比

social4hyq 的修法是**例行上游 1.4.1 合并**——其台账 commit 20289d7230 记录
"T35 worker-leak 症状随 1.4.1 的 webkit mimalloc 变更消失"并附真机数据
（empty-worker 40/80 轮，每 worker 0.115-0.147MB 平台期，替代历史线性
0.85-1.8MB/worker 不收敛）〔实测〕。与本 PR 是同一修复面的两条路径：

| | social4hyq（1.4.1 合并） | 本 PR（#82） |
|---|---|---|
| 修复面 | 整个 1.4.1（含两 pin + USE_MIMALLOC cmake） | 仅分配器三行（两 pin + cmake 开关） |
| 风险面 | 携带 1.4.1 全部行为变更 | 最小化，冲突面 0（纯 dep pin） |
| 归因一致性 | 一致：JSC libpas→mimalloc〔源码：上游 commit 注释逐字核验〕 | 同左 |

springmin 侧 ohos-aarch64 已含同两 commit（`git branch -r --contains` 实证
79f50aedff6 / b1f7b8e36f5）〔源码〕。
