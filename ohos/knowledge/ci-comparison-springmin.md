# CI 架构对比 — springmin/ohos-aarch64 vs jx-bit（容器通道）

> 数据源：springmin/bun `ohos-aarch64` 分支（36 个 workflow）× 本仓库
> `ohos-build-github.yml` / `ohos-container-test.yml` / `runner.node.mjs`。
> 结论先行：**两条线是同源分叉后的两种哲学** —— springmin = "设备即构建机"
> （原生构建 + 环境手动固化），我们 = "CI 托管构建"（每次浇注最新依赖）。
> 本次 brew 漂移断点正是后者的固有风险，前者以手动维护环境为代价规避了它。

---

## 1. springmin 的方案：鸿蒙 PC 本体就是自托管构建机

`build-bun-ohos-native.yml`（609 行，单 job）：

```
runs-on: self-hosted          ← GitHub runner 跑在鸿蒙 PC 本体上
环境（全部预装在设备上）：
  - harmonybrew: llvm@21 / ohos-sdk / icu4c（OHOS 二进制，已签名）
  - rust nightly 2026-07-20（rustc/cargo 也经 binary-sign-tool 签名）
  - binary-sign-tool 在 PATH（OHOS 内核拒绝 exec 未签名 ELF）
流程：增量克隆 → 依赖校验 → 原生构建 → binary-sign-tool 签名产物
      → smoke test（--version + 2**32）→ 打包上传 release tarball
触发：push [ohos-aarch64, claude/ohos-*] + paths [scripts/build/** …]
```

要点：

1. **runner 能跑在鸿蒙 PC 上** —— 使用第三方 `github-act-runner`（其文档记录了
   该 runner 的一个 quirk：首个 artifact 上传后 job 即标记完成，二次上传 403）。
   工具链全部经 binary-sign-tool 签名（rustc/cargo/clang 都要签）—— 之前
   "鸿蒙用户态是 musl、runner 是 glibc .NET 跑不了"的判断需要修正：harmonybrew
   生态提供了完整的 OHOS 原生工具链，第三方 runner 亦可在其上运行。
2. **环境手动固化 = 零漂移**：llvm@21/ohos-sdk/icu4c/rust 预装在设备上，
   不随 tap 索引漂移 —— 我们这次遇到的 brew bottle 漂移在他们的方案里
   **结构性不存在**（工具链手动更新，更新即可测）。
3. **CI 不跑测试套件**：只有 smoke test（--version + 2**32）。测试套件走
   手动 fulltest 轮（`OHOS_TEST_STATUS.md` 方法论：4751 文件 / 20 核 /
   三阶段复核）。
4. 特殊处理：esbuild 的 npm 原生 ELF 无法被 binary-sign-tool 签名 →
   专门 workaround；`sign_build_scripts()` 给构建脚本补签名。

## 2. 我们的方案：CI 托管构建 + 容器测试

```
ohos-build-github：GitHub ARM runner + ci-runner 容器交叉构建
  （依赖 = 每次 brew update 后从 tap 浇注的 bottle 集合）
ohos-container-test：容器内跑测试套件（门禁，红=回归）
ohos-container-fulltest（PR#18，已关）：全量跑 + 只报告（缓行）
ohos-full-test：build 在自托管 ARM64 机器（离线中）+ 容器测试
```

## 3. 逐维度对比

| 维度 | springmin（设备原生） | 我们（CI 托管容器） |
|---|---|---|
| 构建位置 | 鸿蒙 PC 本体（原生） | GitHub ARM runner + ci-runner 容器（交叉） |
| 工具链来源 | 设备上预装（手动维护、已签名） | 每次 run 从 tap 浇注（`brew update` 刷新索引） |
| 环境漂移 | **结构性不存在**（手动固化） | **暴露**（09-07 tap 重构 llvm@21 → zlib/lld 断裂） |
| 签名 | binary-sign-tool 全签（含 rustc/cargo/脚本） | ohos_sign 自签（运行时懒修复，PR#16） |
| 设备依赖 | 设备必须在线（离线 = CI 停摆） | 不依赖设备 |
| CI 内测试 | ❌ 仅 smoke | ✅ 测试套件（5967 文件，95.31%） |
| runner 实现 | github-act-runner（第三方，有 artifact quirk） | GitHub 官方 runner（托管 + 自托管） |
| 测试执行环境 | 手动真机轮（20 核、三阶段复核） | ci-runner 容器（无真机内核策略） |

## 4. 互相可借鉴的点

> **状态（2026-09-07）**：对齐方向调整 —— 本仓库转向与 social4hyq 的容器
> 通道对齐（见 [ci-comparison-social4hyq.md](ci-comparison-social4hyq.md) §4，
> digest pin / 外科 update / llvm@21 已落地，PR #21）。下述 native 通道的
> 移植暂缓 —— 移植蓝本（本文件 §1 的结构）与设备前置条件保留，需要
> "真机原生构建"能力时按 §1 实施。

**从 springmin 可移植到我们**：

1. **设备原生构建通道**：若希望 CI 直接产出"真机可执行"的 binary（当前容器
   交叉构建的产物在真机上还需要签名/适配验证），可复刻其 native lane ——
   runner 装在鸿蒙 PC 上（github-act-runner + harmonybrew），构建即产物。
2. **binary-sign-tool 的全量签名实践**：rustc/cargo/esbuild/构建脚本的签名
   处理清单（esbuild 无法签名的 workaround）—— 对我们的真机通道有参考价值。
3. **环境预装 + 校验清单**：他们的依赖校验步骤（逐命令/逐库检查 + 明确报错）
   与我们 PR#19 的校验清单思路一致，可对照补全。

**从我们可移植到 springmin**（若他们想要）：

1. **容器测试通道**：他们 CI 只有 smoke —— 我们的 runner.node.mjs 容器跑法
   （5967 文件 / 37 分钟）可直接复用其树上跑。
2. **results.json / lint 守卫 / 并行修复**：PR#19 的三修同样适用（同源脚本）。

## 5. 对"brew 漂移"问题的启示（承接 PR#19）

springmin 规避漂移的方式 = **环境手动固化在设备上**（tap 重构对他们无感，
因为工具链不随索引漂移）。我们在 CI 托管模式下无法复制"手动固化"，等价物是
**环境版本化**：

- 短期（已做）：zlib/lld@21 显式安装 + 安装时校验清单（漂移大声失败）
- 中期：自建镜像（Dockerfile 进仓库 + 镜像重建工作流 + 冒烟门禁 + pin tag）
  —— tap 漂移只影响镜像重建那一刻，可测试可回滚
- 长期可选：fork tap（jx-bit/homebrew-core）控制更新节奏

---

*对比：Sisyphus | 2026-09-07 | 数据：springmin/bun ohos-aarch64 @ 421a6bbd370e*
