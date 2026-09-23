# CI 构建对比 — social4hyq（蓝本）vs 我们（jx-bit 容器通道）

> 数据源：social4hyq/ohos-bun `ohos-aarch64` 的 `.github/workflows/ohos-full-test.yml`
> （514 行，自带完整设计注释）× 本仓库 `ohos-container-test.yml` / `ohos-build-github.yml`。
> 结论先行：**我们的容器通道就是从他们的 ohos-full-test 派生的**（其注释自认
> "almost verbatim: GitHub-hosted ubuntu-24.04-arm runner + the same OHOS container
> image"），但派生时丢了他们的三个关键设计 —— 本次 brew 漂移断点是其中之一的代价。

---

## 1. 他们的通道结构（ohos-full-test.yml）

```
runs-on: ubuntu-24.04-arm（GitHub 托管，与我们相同）
镜像：swr.cn-north-4.myhuaweicloud.com/harmonybrew/ci-runner@sha256:57ce4ca8...
      └─ SWR 镜像源（anon-pullable）+ 按 digest pin！
分片：单 job 串行（明确拒绝 --parallel，理由见下）
依赖：node ← Harmonybrew 默认 core tap（外科手术式 brew update）
      llvm@21 bottle ← social4hyq/core（napi 的 C++20 工具链）
      排除：integration/bun-types、internal/source-lints
测试：runner.node.mjs（同我们）~5200 文件，实测 ~46 分钟（串行）
哲学者：红分片不取消其他分片（run 的意义是全量画面）
```

## 2. 我们 vs 他们：逐维度

| 维度 | 他们（蓝本） | 我们（派生时丢了/改了什么） |
|---|---|---|
| **镜像** | **按 digest pin**（SWR mirror，anon-pullable） | `:latest` 从 ghcr 拉 —— **未 pin**（漂移通道，ci-forensics 早标记） |
| **brew update** | **外科手术式**：只为 node 刷新默认 tap 索引；social4hyq/core 用 HOMEBREW_NO_AUTO_UPDATE=1 **钉死**（"we want exactly what we just tapped, not whatever else brew update might touch"） | **全局 update** → 把 tap 的 llvm@21 重构（lld 拆分）拉了进来 → cargo/ld.lld 双断 |
| **--parallel** | **明确拒绝**（"Deliberately NOT passed"——BuildKite 的并行是机器级分片，每分片串行；忠实等价 = 单 job 串行；实测 ~46 分钟/5200 文件） | PR#19 加了 `--parallel`（吞吐需要：我们实测串行 8.1s/文件）；与他们哲学相悖但有实测依据 |
| **node-gyp 工具链** | 显式装 llvm@21 bottle（"node-gyp 测试需要 libc++ 有 C++20 头"） | ❌ 未装（容器轮 31 个 napi 失败同根因，他们已解） |
| **docker 服务** | "docker in this container and never will be"——接受服务类测试失败 | 同（25589 gRPC 类失败同因） |
| **vendor/elysia** | 也跑（其 4751 计数含 vendor） | 跑，但 build 失败曾杀死 runner（已修：记录后继续） |
| **签名** | CI 内无签名（容器无内核强制） | 同（懒修复在容器内不触发） |
| **失败哲学** | 红分片不取消其他（run 的意义是全量画面） | 同（fulltest 通道；门禁通道除外） |

## 3. 三个关键差异详解

### 3.1 镜像 digest pin（他们有，我们缺）— 防 drift 的第一道墙

```yaml
# 他们：
IMAGE: swr.cn-north-4.myhuaweicloud.com/harmonybrew/ci-runner@sha256:57ce4ca8...
#      "SWR mirror, anon-pullable" — 匿名可拉，按 digest 钉死
# 我们：
CONTAINER_IMAGE: ghcr.io/social4hyq/ci-runner:latest   # 浮动 tag
```

### 3.2 外科手术式 brew update（他们有，我们缺）— 本次断点的直接对照

他们的场景与做法（原注释）：

> 镜像是固定日期烘焙的快照 —— 其内置索引可能引用已被 CDN 淘汰的 bottle
> （实锤：内置索引说 node 26.4.0，live tap 已是 26.5.0，26.4.0 bottle 404）。
> 解法：**只对默认 tap 跑 `brew update`**（node 所在），social4hyq/core 用
> `HOMEBREW_NO_AUTO_UPDATE=1` 钉死（"we want exactly what we just tapped"）。

我们的构建通道做了**全局** `brew update` → 把 tap 的 llvm@21 重构（09-07，
lld 拆分）拉进依赖树 → cargo 丢 libz、构建丢 ld.lld。**外科手术式更新 +
显式补装受影响公式（PR#19 已做的 zlib/lld@21）= 他们的防漂移组合拳。**

### 3.3 串行 vs --parallel（哲学分歧，双向都有理）

他们的理由（文档原文）：BuildKite 的 parallel 是**机器级分片**（20 个 agent
各领一个 `--shard`，片内串行）—— 忠实等价于 GitHub 上"单 job 串行"；
matrix 分片会让容器安装成本 × 分片数。

我们的实测：串行 8.1s/文件（12.3h，超 4h 上限）→ 必须并行。
**未解之谜**：他们串行 ~0.53s/文件（46 分钟/5200），我们串行实测 8.1s/文件
—— 15× 差距待查（首批文件构成？bucket 顺序？runner 解释器 bun-ohos vs node？）。
并行 4 是当前约束下的务实解；若查清串行慢因，两者的分歧可以收敛。

## 4. 行动清单 —— 实施状态（2026-09-07 对齐落地，PR #21）

| # | 行动 | 状态 | 落点 |
|---|---|---|---|
| 1 | 镜像 digest pin（三通道 + 变量化路由） | ✅ 已实施 | 三个工作流的 `CONTAINER_IMAGE`/`OHOS_CI_IMAGE` 改为 `vars.OHOS_CI_IMAGE`（digest `38e740c8...`，即历次成功 run 实际使用的 digest）；fork 名同步移出代码（repo 变量 `OHOS_TAP`/`OHOS_TAP_IN_CONTAINER`）|
| 2 | 外科手术式 brew update（测试通道 node 前 `brew update`） | ✅ 已实施 | ohos-container-test.yml |
| 3 | napi 工具链 llvm@21 bottle | ✅ 已实施 | 同上（node-gyp 的 C++20 头需求，31 napi 失败的根因修复）|
| 4 | 串行慢因调查（8.1s vs 0.53s） | ⬜ 待查 | 若是我们的 tree/binary 问题，串行哲学可复用 |
| 5 | vendor 崩溃的 runner 修复 | ✅ 已实施（记录失败 + continue） | runner.node.mjs |

对齐验证：run 34179941938（对齐后首跑）确认 digest pin 生效
（`Digest: sha256:38e740c8...` ✓）、node 装上（`RUNNER: node` ✓，
此前为 SELF 回退）、llvm@21 浇注 ✓ —— 并暴露 openharmony parseOs 崩溃
（已修复，见 PR #21 utils.mjs 部分）。

### 附：BuildKite 是什么（ runner 里的集成层从哪来）

上游 oven-sh/bun 用 BuildKite 跑重型测试基建（~150 分片、junit 上传、
coredump 收集）—— `runner.node.mjs` 是上游脚本，天然带 BuildKite 集成层：
`isBuildkite = BUILDKITE env === "true"`（agent 自动注入），衍生的专属路径
包括 PR 文件列表缓存（避免 150 分片打爆 token 限速）、flaky 分组注释、
`BUILDKITE_TIMEOUT` 预算、分片参数等。

**不建议伪装 `BUILDKITE=true`**：会激活上述全部 BuildKite 专属路径
（artifact 上传、metadata 读取）—— 在没有 BuildKite 后端的环境里全部走错。
正解 = 显式传 `--parallel`（我们的做法，PR #21 已落地）。

**勘误**：此前误将 `coredump-upload` 行的 `isBuildkite && isLinux` 读到
`--parallel` 上（实际 `default: false` 无条件）—— 已在 PR #21 的 commit
message 与本文件修正。

---

*对比：Sisyphus | 2026-09-07 | 数据：hyq/ohos-aarch64 ohos-full-test.yml（514 行）× 本仓库工作流*
