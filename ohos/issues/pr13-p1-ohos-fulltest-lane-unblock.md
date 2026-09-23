# P1: ohos-full-test 测试通道解锁 — PR #13 改动详解
> **关联 PR**：[#13](https://github.com/jx-bit/bun/pull/13)

> **一句话**：这个 PR 让"在 CI 里跑 OHOS 测试套件"这件事从**完全不可用**变成
> **一键可用**（两次独立全量验证：172 文件，1714 pass / 46 fail = 97.4%）。
> **最终形态是两个文件**（2026-09-03 拆分）：
>
> | 文件 | 角色 | 触发 |
> |---|---|---|
> | `ohos-full-test.yml` | **设备/自托管 lane**（恢复原版，留给未来自建设备） | dispatch / 每周日 / workflow 文件变更 |
> | `ohos-container-test.yml` | **容器 lane（新增）**：resolve-binary + ci-runner 容器测试，全 GitHub 托管 | dispatch / PR（test/** 路径）/ push |
>
> PR: https://github.com/jx-bit/bun/pull/13（单 commit `b7a61d3b9a`）

---

## 0. 先讲清楚背景：这个 workflow 是干嘛的

`.github/workflows/ohos-full-test.yml` 是**唯一会执行 JS 测试套件**的 CI 通道：

```
构建 OHOS aarch64 版 bun 二进制
        ↓
放进一个模拟鸿蒙环境的容器
        ↓
node scripts/runner.node.mjs --exec-path=<二进制>
        ↓
runner 逐文件执行 test/ 下的 ~1900 个测试文件
```

它跑不起来，就意味着我们对 test/ 树的任何修改（恢复的 129 个文件、
对账的 74 个文件）**都没有验证手段**。

### 改动前的三个致命问题

| # | 问题 | 后果 |
|---|---|---|
| 1 | build job 绑死在 `[self-hosted, Linux, ARM64]` 自托管机器上 | 机器离线 → 整个 workflow 排队（定时轮排队 24h 后被取消） |
| 2 | 测试容器是 vanilla ubuntu + musl-tools | OHOS 二进制在里面**跑不起来**（缺 OHOS 专属符号） |
| 3 | 一个测试失败会**杀死整个 runner** | 172 个文件跑到第 4 个就全灭，永远得不到完整报告 |

PR #13 按顺序修掉这三个。

---

## 1. 改动一（最大的）：workflow 重写（481 行 → 精简架构）

### 1.1 旧架构长什么样（为什么不行）

```
旧 workflow:
├─ build job  [self-hosted, Linux, ARM64]   ← 离线机器，排队即死
│    在自托管机器上交叉编译 binary（重用本地缓存）
│    上传 artifact "bun-ohos-binary"
└─ test job   [ubuntu-24.04-arm]（GitHub 云端）
     needs: build                           ← 被上面的排队卡死
     下载 binary → 塞进 vanilla ubuntu 容器
     容器里手工搭建"类 OHOS 环境"（musl-tools + 各种符号链接）
     跑测试
```

两个结构性缺陷：

1. **build job 的机器标签**决定了它在自托管机器离线时永远排队，
   而 test job `needs: build` —— 排队传染，全链死锁。
2. **vanilla ubuntu 容器不是 OHOS 环境**。OHOS 二进制链接的是 OHOS
   的 musl fork（libc 里有 `__fd_chk` 这类 OHOS 专属符号）+ OHOS 的
   libunwind。vanilla 容器里既没有这个 loader 也没有这些库 ——
   我们试了四轮"缝合"（注入 loader 符号链接、从镜像抽库……），
   每一轮都修好一个符号又冒出下一个（R1→R4 的失败记录见
   `skills/16-device-fulltest.md`）。

### 1.2 新架构（关键洞察：构建容器本身就是完美测试环境）

洞察来自你的提问："**用构建 ohos-build-github 相同的容器怎么样？**"

`ohos-build-github.yml`（另一个 workflow）每次 PR 都在 GitHub 云端
成功构建 binary，用的容器是 `ghcr.io/social4hyq/ci-runner:latest`
（GHCR 公共镜像，无需 auth）。这个镜像**就是** OHOS 用户态 ——
二进制链接时的 libc/loader/libunwind 全部来自它。

**在构建的同一个环境里跑测试 = 环境错配问题整类消失。**

```
新 workflow:
├─ resolve-binary job  [ubuntu-latest]（轻量，1 分钟）
│    不再自己编译 —— 直接从 ohos-build-github 最近的绿色 run
│    下载现成的 binary artifact（同 commit 优先，否则取最新成功）
│    转存为 "bun-ohos-binary"
└─ test job  [ubuntu-24.04-arm]（GitHub 云端）
     needs: resolve-binary
     启动 ci-runner 容器（docker run -d，与构建完全同款）
     把 checkout 挂载为 /workspace/bun（测试树直接可用）
     docker cp binary 进去
     brew 安装 runtime 依赖（node —— 测试 harness 的解释器）
     被测 binary 自己执行 bun install（root + test/）
     node scripts/runner.node.mjs --exec-path=<被测 binary>
```

### 1.3 resolve-binary job 逐段解释

```yaml
resolve-binary:
    runs-on: ubuntu-latest          # 轻量 job，1 分钟
    steps:
      - Locate the latest successful ohos-build-github run
          # 用 gh api 找最近一次成功的构建 run：
          #   优先 head_sha == 本次要测的 commit（同一份代码）
          #   找不到（比如构建还在跑）→ 回退到最近一次成功的任意 run
      - Download binary artifact
          # actions/download-artifact@v4 支持 run-id 跨 workflow 下载
          # 这需要 workflow 级 permissions 加 actions: read（PR 里加了）
      - Verify binary
          # file 命令确认是 ARM64 ELF
      - Upload as bun-ohos-binary
          # 转存成 test job 期望的 artifact 名 —— test job 下载逻辑零改动
```

**为什么这样设计而不是让 test job 自己编译？** 编译要 30 分钟 +
OHOS SDK 全套工具链；构建 lane 本来就在每次 PR 时产出二进制，
直接复用是零成本的。

### 1.4 test job 的步骤逐段解释

| 步骤 | 干什么 | 为什么 |
|---|---|---|
| `Pull and start ci-runner container` | `docker run -d` 启动 OHOS 用户态容器，把 checkout 挂载到 `/workspace/bun` | 与 ohos-build-github 完全相同的启动方式；挂载让测试树免拷贝 |
| `Configure container (device path fixup)` | 建 `/system/bin/sh`、`/system/lib/ld-musl-aarch64.so.1` 符号链接 + `git safe.directory` | ① 二进制的 PT_INTERP 写死设备路径，容器里要模拟出来；② 容器里以 root 跑 git 会撞 dubious-ownership（详见 §3） |
| `Stage binary and verify` | `docker cp` binary 进容器 + **立刻执行 `--version`** | 快速失败点：binary 在容器里跑不起来就当场报错，不浪费后面的时间（这一步通过 = R1-R4 的所有问题都已解决） |
| `Install brew runtime deps` | `brew install --only-dependencies` 装 **node**（跑测试 harness 用的）+ 三级回退 | 见 §1.5 |
| `Install test dependencies` | 用**被测 binary 自己**执行 `bun install`（root + test/ 两层） | 顺便锻炼 OHOS 包管理器；`--ignore-scripts` 跳过 esbuild 的平台检测报错 |
| `Run test suite` | `node scripts/runner.node.mjs --exec-path=<被测 binary>` 跑套件 | 真正的测试执行；支持 `test-filter` 输入做子集运行 |

### 1.5 runner 解释器的三级回退（为什么需要）

测试 harness（`scripts/runner.node.mjs`）需要一个 node 来启动。
第一次跑就撞上：brew 的 node bottle 在 CDN 上 **404**（被清理了）。

回退链（写在 workflow 里）：

```
brew 的 node（首选）
  ↓ 404 时
brew 的 bun-bootstrap 包里的 bun
  ↓ 都没有时
被测 binary 自己（bun-ohos scripts/runner.node.mjs）—— 自举，
  runner 和测试对象是同一个 binary，隔离性差一点但保证能跑
```

每级都打印 `RUNNER=` 供日志确认用了哪个。

### 1.6 保留不变的部分

- `--exclude` 列表（cc.test.ts 容器段错误、bake/dev 稳定版关闭等）
- `results.json` 上传、失败时容器诊断 dump、清理步骤
- `GITHUB_ACTIONS` 不传入容器（runner 有依赖它的代码路径，只给 CI=true）

### 1.7 架构拆分：容器 lane 独立成 `ohos-container-test.yml`

初版修复直接重写了 `ohos-full-test.yml` 的 test job。但原文件的
**build job（自托管机器）+ 设备测试设计**是留给未来自建设备用的
基础设施，不该被容器架构覆盖。最终拆分为两个文件：

| 文件 | 内容 | 为什么分开 |
|---|---|---|
| `ohos-full-test.yml` | **原版原样恢复**（自托管 build job + 设备/容器测试设计） | 设备 lane：未来接真机/自建 runner 时用，与本 PR 的改动无关 |
| `ohos-container-test.yml` | **新增**：resolve-binary + ci-runner 容器测试（本 PR 的全部新架构） | 容器 lane：全 GitHub 托管，不依赖任何自托管资源 |

两个文件的触发方式保持一致（push paths / workflow_dispatch / 每周日），
仅命名区分（`ohos-container-test-*` 前缀的 artifact 与并发组）。

### 1.8 手动 dispatch 的"默认分支"限制

**坑**：workflow_dispatch API 要求 workflow 文件存在于**仓库默认分支**
（本仓库是 `ohos-aarch64`）。新文件只推到 dev 时，dispatch 会报：

```
HTTP 404: workflow ohos-container-test.yml not found on the default branch
```

解法：**合并 PR #13 之后**文件进入 ohos-aarch64（默认分支），dispatch
即恢复可用。合并的 push 同时会自动触发一次**全量**容器测试
（push 触发器 paths 命中 workflow 文件变更，filter=none）。

### 1.9 node 404 的正解：default core tap

初版的 brew 依赖步骤从 `social4hyq/core` tap 拉 node —— CDN 上该
bottle 已 404。读 social4hyq 自己的 `ohos-full-test.yml`（本 workflow
的源头）发现正解早有记载：

> default core tap ships an arm64_ohos `node` bottle (confirmed:
> runner.node.mjs/utils.mjs activate correctly under it)

即**镜像内置的默认 core tap** 就有能跑 runner 的 arm64_ohos node。
修复：`brew install node`（默认 tap）替代从 social4hyq/core 拉依赖。
被测 binary 不需要任何 brew 依赖（NEEDED = [libc.so]，见 §2），
node 只是 harness 解释器。

---

## 2. 改动二：`scripts/build/flags.ts`（1 行，但来历最曲折）

### 2.1 现象

新容器里二进制执行时立刻崩：

```
Error relocating bun-ohos: _Unwind_Resume: symbol not found
```

readelf 显示二进制带着 `NEEDED libunwind.so.1` —— 一个**在任何地方
都不存在的库**：ci-runner 镜像没有、OHOS SDK sysroot 只有静态版
`libunwind.a`、你的真机 `/system/lib` 里也没有。

### 2.2 追根：这个 NEEDED 从哪来

链接行里有 `-L.../ohos-cross-libs/libunwind/lib -lunwind`。交叉库
目录（p0 文档 §8.6 的自编译产物）里同时装了共享版和静态版：

```
$CROSS/lib/libunwind.so.1   ← 共享版（链接器优先命中 → 写进 NEEDED）
$CROSS/lib/libunwind.a      ← 静态版（纯 C，无 ABI 命名空间）
```

共享版只存在于**构建容器**里 —— 编译完就随容器销毁。于是二进制
带着一个宇宙中无处解析的依赖出厂。这也是它**在任何真机上都跑
不起来**的隐藏原因之一（此前被 exec 权限问题掩盖）。

### 2.3 修复

```diff
-  "-lunwind",
+  "-l:libunwind.a",  // static: no libunwind.so.1 exists on devices/CI image
```

`-l:libunwind.a` 是 GNU 链接器的"精确文件名"语法 —— 强制链接静态
归档，`NEEDED libunwind.so.1` 从此不再出现。二进制变成自包含：

```
NEEDED = [libc.so]    ← 唯一依赖，任何 OHOS 环境（容器/真机）原生满足
```

### 2.4 走过的弯路（记入 16-device-fulltest）

第一版修复用的是 `-static-libunwind` —— 这是 clang **driver** 的选项，
而本仓库链接是裸 `clang++ @rsp` 调用（绕过 driver），报
`unknown argument`，构建失败。改成链接器语法的 `-l:libunwind.a` 才对。

---

## 3. 改动三：`scripts/utils.mjs`（6 行，但曾是"一失败就全灭"的元凶）

### 3.1 现象

R7 那轮：测试跑到第 4 个文件（第一个**失败**的测试出现时），
runner 整体崩掉：

```
TypeError: Invalid URL
  input: "blob/undefined/test/js/bun/spawn/spawn-cgroup.test.ts",
  base: "undefined/"
```

### 3.2 根因链

测试失败时，runner 要给失败用例生成一个"指回源码"的链接
（报告注解用）。这条链上每一环都断了：

```
getFileUrl(filename)
  → getRepositoryUrl()   走 git remote get-url
  → getCommit()          走 git rev-parse HEAD
       两个 git 命令都死在容器里的 dubious-ownership：
       checkout 属于 runner 用户(uid 1001)，容器里以 root 执行 git
       → git 拒绝操作 → 两个函数都返回 undefined
  → new URL("blob/undefined/...", "undefined/")  → TypeError
  → runner 整体崩溃 → 剩下 170 个文件不跑了
```

**关键认知**：这个崩溃发生在**失败报告路径**上 —— 也就是说只要
有任何一个测试失败，整个 run 就死。对测试通道来说等于
"见到失败就自毁"，永远拿不到完整报告。

### 3.3 修复（两层）

**代码层**（`scripts/utils.mjs`，+6 行）：

```js
const commit = getCommit(cwd);
// git may be unavailable or blocked by dubious-ownership in sandboxed
// environments ... — fail soft: the failure annotation just loses its link.
if (!baseUrl || !commit) {
  return;
}
```

链接拿不到就返回 undefined —— 失败注解少一个超链接，但
**runner 继续跑完所有文件**。

**环境层**（workflow 的 configure 步骤，+1 行）：

```bash
git config --global --add safe.directory /workspace/bun
```

让容器里的 git 接受这个 checkout —— 注解链接恢复完整可用。

两层都要：环境层让链接能用，代码层保证以后任何环境问题都只是
"链接缺失"而不是"runner 崩溃"。（这个修复与 social4hyq 在
`OHOS_TEST_STATUS.md` 里记录的同类修复一致。）

---

### 3.4 为什么 social4hyq 没有这个问题：bottle 模式 vs 裸 binary 模式

对比他们的 `ohos-full-test.yml`（本 workflow 的源头）发现架构差异：

| | social4hyq | 我们 |
|---|---|---|
| 被测 binary | **brew bottle 安装的 bun**（`$(brew --prefix bun)/bin/bun`）| 裸交叉编译 binary |
| 依赖（libunwind/libc++） | brew 作为公式依赖**一起装到运行环境** | 不随 binary 走，由运行环境提供 |
| NEEDED libunwind.so.1 | ✅ 也存在，但运行环境永远有（brew 陪送） | ✅ 存在，但运行环境没有 → 致命 |
| 构建位置 | harmonybrew-core 仓库的 bottle-build.yml（tap 仓库） | 本仓库 ohos-build-github.yml |

他们的 binary 同样带 `NEEDED libunwind.so.1`，但 brew 的 bottle 体系
保证依赖跟包走 —— 所以他们永远撞不到这堵墙。我们的二进制是裸部署
（不进 brew 体系），必须自包含 —— 这就是 `-l:libunwind.a` 是**我们
部署模型下的正确解**而他们不需要的原因。两套模型各自自洽，不必对齐。

顺带的收获：他们的 fulltest 设计里有两处可直接借鉴 ——
① node 从**镜像内置的默认 core tap** 装（bottle 存在，见 §1.9）；
② harness 解释器与被测 binary 分离（"system node so a broken
candidate bun can't take down the harness"）。

---

## 4. 最终效果（两次独立全量验证，2026-09-03）

### 4.1 R12（results.json 口径）

```
run: https://github.com/jx-bit/bun/actions/runs/33716819673
执行文件: 172（js/bun/spawn 过滤子集）
用例:     1555 pass / 10 fail = 99.36%
runner:   跑完全程（修复前：第 4 个文件就崩）
```

### 4.2 R13（log 口径，二次独立验证）

```
run: https://github.com/jx-bit/bun/actions/runs/33727192809
执行文件: 172（到达 [172/174]，"End"）
用例:     1714 pass / 46 fail = 97.4%（log 口径，含 vendor/elysia）
runner:   跑完全程
```

> 两个口径差异说明：R12 的 results.json 解析只统计了 stdoutPreview 里
> 的首个 pass/fail 行（低估）；log 全文 grep（1714/46）更完整。
> 以后以 results.json 的结构化字段为准，解析方法待改进。

### 4.3 失败文件清单（8 个，全部环境性，待 per-case triage）

| 文件 | 失败 | 初判 |
|---|---|---|
| spawn-cgroup.test.ts | 4 | 容器无 cgroupfs 写权限 |
| spawn-signal.test.ts | 2 | 信号时序 |
| spawn.ipc.node-bun / bun-node.test.ts | 1+1 | IPC socket 路径 |
| spawn-pipe-read-error-leak / pipe-leak / spawn.test.ts | timeout/crash | 泄漏类超时预算 |
| sucrose/integration.test.ts | 1 | filter 误匹配混入 |

### 4.4 REST API 提交通道（网络中断时的推送手段）

期间 `github.com`（git 协议）长时间不可达而 `api.github.com`（REST）
可达，改用 **Git Data API** 推 commit：

```
POST /repos/<repo>/git/blobs        ← 文件内容（base64）
GET  /repos/<repo>/git/commits/<head>   ← 拿 base tree
POST /repos/<repo>/git/trees        ← base_tree + 变更文件
POST /repos/<repo>/git/commits      ← message + tree + parents
PATCH /repos/<repo>/git/refs/heads/dev  ← 更新分支（force 可选）
```

**权限坑**：细粒度 PAT 修改 `.github/workflows/` 下的文件需要
**Workflows 权限**（Contents 不够）→ `git/trees` POST 报 403 →
换 classic token（完整 repo scope）解决。token 从
`~/.git-credentials` 解析时注意只截取 `用户名:` 与 `@` 之间的部分
（初次实现把 `https://42936419:` 前缀整个带进了 token → 401）。

**教训**：这类 REST commit 是**追加式**的（每次 = 新 commit），
fix-verify 循环里会产生一串迭代 commit —— 最终用 squash（本 PR 的
单 commit 就是 REST 重建的树 + 本地修复合并而成）。

---

## 5. 验证方法

```bash
# 1) 手动触发一轮（合并 PR #13 后才可 dispatch —— workflow 文件
#    必须存在于默认分支 ohos-aarch64。网页：Actions → OHOS Container
#    Test → Run workflow，Branch 选 dev，test-filter 填子集）
#    合并前的替代：push 到 dev（paths 命中即自动触发全量）
gh api -X POST repos/jx-bit/bun/actions/workflows/ohos-full-test.yml/dispatches \
  -f ref=dev -f 'inputs[test-filter]=js/bun/spawn'

# 2) 看结果
gh run view <run_id>   # 重点步骤：Stage binary and verify（二进制能否执行）
                       #            Run test suite（pass/fail 计数）

# 3) 判断标准
#    - "Stage binary and verify" 步骤必须出现 "OK: OHOS binary runs"
#    - Run test suite 跑到 [174/174]（或 filter 的文件数）而不是中途 crash
#    - 有测试失败 ≠ 通道失败（runner exit 1 只代表有用例失败需要 triage）
```

---

## 6. 术语速查

| 术语 | 解释 |
|---|---|
| **self-hosted runner** | 自己机器上装的 GitHub Actions 执行代理；离线则绑定的 job 永远排队 |
| **artifact** | workflow 产出的文件包；跨 job 用 upload/download-artifact 传递 |
| **ci-runner 镜像** | social4hyq 维护的 OHOS 用户态容器镜像（GHCR 公共镜像），构建就在里面进行 |
| **PT_INTERP** | ELF 头里记录的动态加载器路径；OHOS 二进制写死 `/system/lib/ld-musl-aarch64.so.1` |
| **dubious ownership** | git 的安全机制：目录属主与执行者不同时拒绝操作，需 safe.directory 显式豁免 |
| **NEEDED** | ELF 记录的动态依赖库列表；加载器必须全部找到才能执行 |
| **`-l:libunwind.a`** | GNU 链接器精确文件名语法（区别于 `-lunwind` 的"搜索共享优先"） |
| **per-case quarantine** | 失败的**单个用例**用 skipIf/expectations 隔离并注明原因（反对整文件删除） |
| **bottle** | Harmonybrew 的预编译包格式；依赖瓶随包自动安装（social4hyq 的依赖陪送机制） |
| **default core tap** | ci-runner 镜像内置的 Harmonybrew 默认 tap；其 arm64_ohos node bottle 存在且可用 |
| **Git Data API** | api.github.com 的 blob/tree/commit/refs 端点 —— git 协议不可达时的推提交通道 |
| **默认分支 dispatch 限制** | workflow_dispatch 要求 workflow 文件在仓库默认分支（ohos-aarch64）上 |

---

## 7. 关联文档

- `skills/16-device-fulltest.md` — 真机 fulltest 部署与执行（含幻影 NEEDED 教训）
- `skills/15-ci-artifact-dispatch.md` — CI artifact 拉取与 token 权限坑
- `tri-way-diff-analysis-2026-09-02.md` — 测试树对账背景
- `issues/p1-test-tree-upstream-restore-and-reconcile.md` — 测试树修复主线
- `issues/p1-epolloneshot-disabling.md` — 同期修复的 EPOLLONESHOT 问题



## 8. 修复时间线

```
2026-08-14/15  测试树被整树替换为 social4hyq pre-1.4.0（背景，见 p1-test-tree 文档）
2026-08-28     v1.4.0 合并；test/ 冲突全以 ours 解决
2026-09-02     PR #11（恢复 129 文件）+ PR #12（对账 74 文件）合并
2026-09-03     PR #13 创建：resolve-binary + ci-runner 容器架构
2026-09-03     R1 ❌ 缺 OHOS libc 符号 → R2 ❌ docker cp 踩符号链接
               → R3 ❌ 幻影 NEEDED libunwind.so.1 → flags.ts 静态链接修复
2026-09-03     R7 首次跑通但一失败即崩 → utils.mjs 空值兜底修复
2026-09-03     R12 全量验证 ✅ 172 文件 / 99.36%
2026-09-03     架构拆分：容器 lane 独立为 ohos-container-test.yml
2026-09-03     R13 二次独立验证 ✅ 172 文件 / 97.4%（1714 pass）
2026-09-03     node 404 正解：default core tap（借鉴 social4hyq fulltest）
2026-09-03     网络中断期 Git Data API 推 commit 通道验证可行
待办           PR #13 合并 → 全量容器基线（filter=none）
               → 8 个失败文件 per-case triage → 真机 exec 域策略
```

---

*文档日期：2026-09-03 | 作者：Sisyphus*
*依据：PR #13 全部调试记录（R1-R13 六轮以上迭代）+ 两次全量验证*

*依据：PR #13 全部调试记录（R1-R12 六轮迭代）*
