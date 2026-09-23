# P0: CI 容器构建门禁对齐上游 tap 重构（ohos-sdk 脱离 bun.rb 直接依赖）— 工作记录

> **关联 PR**：[#35](https://github.com/jx-bit/bun/pull/35)（claude 分支 → ohos-aarch64，
> 单 commit；修 `.github/workflows/ohos-build-github.yml` + `.github/scripts/build-ohos-container.sh`）
> **状态**：🔄 OPEN
> **定位**：2026-09-14 起 `OHOS Build (GitHub-hosted, social4hyq container)` 通道对
> **所有 PR** 必红（PR #34 首次撞上），失败点在 `Install brew deps` 的验证循环：
> `ohos-sdk NOT installed`——发生在编译开始前，与任何 PR 内容无关。

## 1. 根因（证据链完整，GitHub compare API + 双 run 日志对拍）

### 1.1 两次 run 的同口径对拍（同 workflow 内容、同镜像 digest、同 runner 镜像版本）

| | 09-11 09:00（PR #32，绿） | 09-14 03:07（PR #34，红） |
|---|---|---|
| `brew update` 拉到 tap HEAD | `0d1a8ae0`（09-11 00:29） | `423852bb`（09-13 08:03） |
| bun.rb 里的 `ohos-sdk` | `depends_on "ohos-sdk" => :build` **在** | **被删** |
| 验证循环 | `OK ohos-sdk` | `ohos-sdk NOT installed` |
| 镜像 digest | `sha256:38e740c8…` | **完全相同** |

### 1.2 上游变更本体

social4hyq 于 09-12 一天内对 `Formula/b/bun.rb` 连跳 5 个 revision（`_4`→`_8`，
+241/−244），依赖面重构（compare `0d1a8ae0...423852bb`）：

```diff
-  depends_on "bun-bootstrap" => :build
-  depends_on "bun-webkit" => :build
-  depends_on "ohos-sdk" => :build
+  depends_on "node" => :build
+  # bun.rb install 段改为运行时从 llvm@21 的 deps 里解析：
+  sdk = llvm.deps.find { |dep| dep.name.start_with?("ohos-sdk@") }.to_formula.opt_prefix
```

即：**sdk 不再是 bun 的直接依赖**，改挂 llvm@21 的传递依赖（且改名带 `@version`
后缀）；bun-bootstrap/bun-webkit 也退出直接依赖（formula 本体仍在 tap，
`Formula/b/bun-bootstrap.rb`、`Formula/b/bun-webkit.rb` 于 `423852bb` 在）。

### 1.3 我方 CI 撞上它的三个点

1. `brew update` 每次**浮动到 tap HEAD** → 09-14 的 run 自动吃到新依赖合同，
   `--only-dependencies` 不再装 ohos-sdk；而镜像预装的 llvm@21 是旧版
   （没有 ohos-sdk@X 传递依赖，brew 跳过已装项不重解析）→ sdk 无人安装
2. 验证循环硬编码 `for f in llvm@21 ohos-sdk icu4c@78 bun-bootstrap …` →
   `brew --prefix ohos-sdk` 在新 tap 状态下解析失败 → 门禁红（**验证循环本身
   工作正常，这正是它的职责**——否则构建会在 `build-ohos-container.sh` 里
   以更隐晦的方式挂）
3. 真正的构建断点在 `build-ohos-container.sh` L36：
   `SDK_PREFIX=$(brew --prefix ohos-sdk)`——同因必挂

### 1.4 附带发现（一并修）

- **重试逻辑是死代码**：`if docker exec … | tail -40; then` 无 pipefail，
  管道退出码永远是 tail 的 0 → brew 失败被吞、90s 重试从不触发、zlib/lld@21
  的 fallback warning 也从未真正生效
- `brew install $TAP/lld@21` 的 tap 前缀错误：lld@21 在 harmonybrew/core
  （09-08 fork retirement 移交，旧 bun.rb 注释自证），两次 run 都报
  "No available formula social4hyq/core/lld@21"；且新 bun.rb 已把 lld@21
  列为直接 `:build` 依赖，pour 会自动装

## 2. 修复内容（3 文件）

### 2.1 `.github/scripts/build-ohos-container.sh`

SDK_PREFIX 解析动态化（与上游 bun.rb 同款查找）：

```bash
SDK_FORMULA=$(brew deps --include-build llvm@21 2>/dev/null | grep -E '^ohos-sdk' | head -1 || true)
SDK_FORMULA=${SDK_FORMULA:-ohos-sdk}          # 旧 tap 状态回退
# keg 缺失则显式安装；安装失败回退镜像 baked 旧 keg（opt/ohos-sdk）
```

### 2.2 `.github/workflows/ohos-build-github.yml`

- `set -o pipefail`：复活重试逻辑与 fallback warning
- 显式 sdk 补装：从 llvm@21 现行 deps 动态解析 formula 名（旧名兜底），
  `brew install` 失败降级 warning（构建脚本侧还有 keg 兜底）
- **验证清单**：保持代表性子集（llvm@21 / $SDK_FORMULA / icu4c@78 /
  bun-bootstrap / openssl@3 / cmake / ninja / zlib），其中 sdk 名动态解析。
  两次动态化尝试均被 CI 实证否决并回退：①全闭包树
  （`brew deps --include-build`）混入传递依赖的 :build 依赖（autoconf），
  bottle pour 正确不装；②JSON 直接依赖解析依赖 jq，镜像未内置。
  改名跟踪由 L3 canary 兜底；直接依赖级动态化待确认容器内 jq/--1 支持后再上
- bun-bootstrap 显式补装（formula 仍在 tap，仅退出直接依赖）
- lld@21 显式安装改 unqualified（`brew install lld@21`，跨 tap 解析）

### 2.3 `.github/workflows/ohos-brew-deps-canary.yml`（新增，L3 漂移哨兵）

每日 cron（+workflow_dispatch 手动）只跑 pull container → tap trust →
pour → verify 四步（无源码构建，热 runner 数分钟），把上游合同漂移的发现
时间从"下一个 PR 撞上"缩到 ≤24h。与构建通道的 install/verify 逻辑保持
同构，文件头注释要求两者同步修改。默认分支为 ohos-aarch64，合入即生效。

### 2.4 防再犯分层说明

| 层 | 机制 | 覆盖 |
|---|---|---|
| 已修 | pipefail + 门禁前置 + 明确错误 | 静默失败、诊断难 |
| L2（本 PR） | 验证集 = 现行依赖树 | 依赖集增/删/改名整类 |
| L3（本 PR） | 每日 canary | 发现延迟 ≤24h，与 PR 解耦 |
| 未做（可选） | tap pin 冻结合同 | 治本，但引入 CDN prune 旧 bottle 风险；待与 tap 维护者确认升级节奏后再评估 |

## 3. 与 social4hyq 实现的对比

| 维度 | social4hyq（build.sh，设备实证） | 我方 lane → 本 PR |
|---|---|---|
| 安装方式 | `brew install --build-bottle $TAP/bun` **全量构建**——依赖从当前 tap 全新解析（llvm@21 → ohos-sdk@X 传递拉取） | `--only-dependencies`（跳过已装的旧 llvm@21）→ 传递依赖拉不到 ❌ → 显式补装 sdk |
| tap 状态 | tap = 自己的 workspace checkout（bind-mount，update 后 reset 回 checkout SHA） | 镜像 baked tap 浮动 HEAD ❌ → 名字动态解析以跟踪浮动 |
| 装后校验 | `brew info --json=v2` 数 installed kegs | 逐 formula `brew --prefix` + 目录存在性 → 硬编码名随重构失效 ❌ → sdk 名动态化 |

证据类型：〔源码〕compare API 逐字核验（0d1a8ae0…423852bb）+ build.sh/lib.sh 现文；
〔实测〕9/11 与 9/14 两 run 日志对拍（本节 1.1 表）。

## 4. 验证

- 本地：workflow YAML parse ✓；`bash -n` 两处 run 块与 build-ohos-container.sh ✓
- CI：本 PR 自身的 pull_request 构建即用修复后的 workflow（merge ref 取 base
  侧 workflow 文件）——**本 PR 全绿即修复实证**
- 合入后：重跑 PR #34 的 failed job（其 merge ref 将取到修复后的 workflow）
- 残余不确定项：`ohos-sdk@X` 的确切版本名未静态确认（harmonybrew/core tap
  不在 GitHub 公开面；bottle CDN 在 atomgit）——动态解析设计对此免疫，
  若 llvm@21 现行 deps 里 sdk 改用全新名字（非 `ohos-sdk` 前缀），门禁会以
  明确错误信息而非隐晦构建失败报告

## 5. 关联

- 受害 PR：[pr34](pr34-p0-pipe-capture-wave2.md)（容器通道红与其内容无关——
  其 Rust 全部检查 clippy/miri/mordant/Format 均绿）
- 上游证据：social4hyq/homebrew-core `0d1a8ae0...423852bb` compare；
  llvm@21 bottle 构建 run 34024698634（09-06，当时 llvm@21 deps 仍为无后缀
  `ohos-sdk`）
- 方法论：与 [pr32](pr32-p0-epoll-pipe-capture.md) 同款"同基线对拍 + 上游变更
  考古"；CI 门禁属于**浮动上游合同**，验证清单禁止硬编码 formula 名
