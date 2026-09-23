# P2: 疑似 v1.4.0 合并回归 — 真机新增失败追踪清单

> 真机全量测试（20260902，binary `535fb153c7-signed`）中，剔除已知
> 设备环境限制与 codesign 类失败后，仍有 **~10 个文件**是 8 月基线
> 没有的新失败 —— 时间点与 v1.4.0 合并（8-28）吻合，疑似合并回归，
> 需逐一源码跟进甄别。
>
> 状态：**追踪清单**（第一轮定性完成，见 §4.5 —— 未发现 src 级回归；
> 剩余待查：HTTP-stdin NaN、intl/cluster）。注意甄别前先区分：
> ①真回归（我们的 src 问题）②设备环境差异（social4hyq 设备能过）
> ③容器/真机口径差异 ④测试本身需要 OHOS 适配。

---

## 1. 基线与判定口径

| 轮 | binary | 测试树 | 失败文件 |
|---|---|---|---|
| 8 月基线 | 9d5d706c9 轮（私有构建） | 1937 文件（旧树） | 190 |
| 本轮 | 535fb153c7-signed | 1988 文件（对账后新树） | 215（唯一） |

对比结论（报告 `lists/`）：

```
重叠已知       166   （8 月就挂，环境限制类）
本轮新增        49   = 旧文件新挂 38 + 新树新文件 11
8 月挂→本轮过   24   （EPOLLONESHOT / Highway SVE / reconcile 修复生效）
```

49 个新增中，72 文件的 codesign 类占大头（与 #1 重叠）；**剔除后
剩 ~10 个 runtime 级新挂**，即本清单主体。

---

## 2. 疑似回归文件与症状

| 文件 | 症状 | 初步假设 |
|---|---|---|
| `test/js/web/intl/intl.test.ts` | Intl locale 子进程 EOF | v1.4.0 的 ICU/Intl 变更 × OHOS libc 差异（rune table / locale 数据） |
| `test/js/node/cluster.test.ts` | cluster fork IPC | v1.4.0 的 cluster/child_process 变更 × seccomp |
| `test/js/valkey/reliability/connection-failures.test.ts` | valkey EPERM | 网络相关 seccomp 限制（8 月轮 valkey 模块在 social4hyq 设备为 100%） |
| `test/js/valkey/valkey-tls-verify.test.ts` | TLS verify | 同上 |
| `test/js/bun/spawn/spawn-stdin-*.test.ts`（3 个） | stdin backpressure：40MB > 16MB 上限 | v1.4.0 的 stdin backpressure 行为变更（40MB 缓冲 vs 旧 16MB） |
| `test/js/node/process/process-stdin.test.ts` | 同域 | 同上 |

> 注：social4hyq 的 `OHOS_TEST_STATUS.md`（08-29）显示他们的
> valkey 模块 **100%**、js/node **99%** —— 需对照他们跑这些文件的
> 方式（环境/参数）判断差异来源。

---

## 3. 几方对比（待补全的证据点）

| 方 | spawn 补签 | stdin backpressure | valkey | intl |
|---|---|---|---|---|
| 我们（dev, 真机） | ✅ 有（!has_codesign 短路） | ❌ 40MB 上限报错 | ❌ EPERM | ❌ 子进程 EOF |
| social4hyq（真机, 08-29 报告） | 无补签（shebang 展开） | ✅ 通过（multi-run 修复轮确认） | ✅ 100%（unquarantine 后） | ✅（js/node 99% 内） |
| 上游 v1.4.0（host CI） | 不适用 | ✅（上游测试矩阵绿） | ✅ | ✅ |
| ljy9812 | 同我们 | 8 月轮同挂？ | 8 月轮状态？ | ？ |

**关键判据**：social4hyq 的真机能过这些文件 —— 说明**不是 OHOS 平台
的本质限制**，而是 (a) 我们的 binary/运行时差异，或 (b) 他们的
测试环境参数差异（EL2 路径、Harmonybrew 依赖、node-ohos 版本）。
他们 08-29 的修复 commits（multi-run 超时、node-ohos 选择、
canvas/rspack unquarantine）值得逐个对照。

---

## 4. 调查方向（每个文件）

1. **stdin backpressure 三兄弟**（40MB>16MB）：
   - 对比 v1.4.0 前后 `spawn` 的 stdin 缓冲实现
     （`src/spawn/` 或 `src/bun_spawning/`）—— 上游是否提高了上限？
   - social4hyq 侧是否 patch 过此行为
2. **cluster fork IPC**：对照 v1.4.0 的 cluster 变更 +
   social4hyq 是否有对应适配 commit
3. **valkey EPERM ×2**：确认是 seccomp 哪条规则
   （EPERM 于 socket/connect?）—— social4hyq 的 seccomp 配置对比
4. **intl EOF**：ICU 数据差异（v1.4.0 的 ICU bump × OHOS locale）——
   子进程 EOF 指向 spawn 的 stdio 管道问题，可能与 stdin 系同源

---

### 4.5 第一轮调查结论（2026-09-03）

对 4 个失败簇逐一取证后的分类：

**① skipIf(isOHOS) 未生效类（40MB>16MB + readable-stream progress）— 平台差异，适配已存在**

- `process-stdin.test.ts` 的失败用例自带 `test.concurrent.skipIf(isOHOS)`
  （line 463），注释明载根因："实测单次 read 合入 40 次写入，阈值 <16"
  —— OHOS 管道把 40 次 1MB 写入合并进单次 read，RSS +40MB。
- 设备轮它却跑了 → 断言执行 → isOHOS 运行时为 false → 指向**私有
  binary（5c0a93130）的 process.platform 行为**（构建自私有 commit
  5c0a93130，revision 与文件名 535fb153c 不同）。
- 我们的 ohos-build-github binary 报 `process.platform = "openharmony"`
  （容器实测：esbuild 平台检测、OHOS 专属代码路径均命中）→ 换用
  我们的 binary 后此类自动 skip，**无需 src 修改**。

**② large-buffer +0/-5 — 四方代码逐字节一致，排除 src 回归**

- `src/spawn/static_pipe_writer.rs` 在 bun-v1.4.0 / 我们 / social4hyq
  三方均为 304 行零差异；测试守护的">1MB 截断修复"也非本文件专属。
- 全 5 用例失败（子进程 JSON 输出缺失）指向设备/内核层的管道行为
  或内存时序 —— 需要设备侧逐用例日志（all-official-report 已有，
  诊断优先级低：5 用例）。

**③ FIFO mkfifo 缺失 — 夹具环境问题**

- `Bun.which("mkfifo")` 在设备 PATH 返回 null → 夹具建 FIFO 即挂，
  backpressure 断言根本没执行。修法：测试加
  `skipIf(!Bun.which("mkfifo"))` 或改用 socketpair 夹具。

**④ HTTP-response-as-stdin NaN + html-rewriter ByteStream — 待诊断**

- HTTP Response 管道给子进程 stdin，子进程 readline 计数 NaN ——
  HTTP 客户端 → stdin writer 的数据流在真机断链，需单独复现。
- html-rewriter ByteStream 计数差 8 —— 同域待查。

**结论**：stdin/spawn 失败簇**未发现 src 级回归** —— 全部是
平台差异适配（①③）、设备环境（②）、待诊断（④）三类。
#5 的 v1.4.0 回归嫌疑大幅下降（原 ~10 个 → 待查 2 个：④ + intl/cluster）。

## 5. 与其他问题的关系

- **与 codesign 问题（pr14-p1-codesign-stub-inheritance.md）的关系**：
  38 个回归候选里 compile 类（约 30 个）属于 codesign 类，
  剩余 ~8-10 个才是本清单主体 —— 甄别时先剥离 codesign 类
- **与容器 lane 的关系**：容器 lane（R12）的 8 个失败文件与本清单
  **不重叠**（容器是 cgroup/IPC 环境；真机是 seccomp/行为差异）——
  两套环境各自 triage
- **与 social4hyq 对账的关系**：他们的测试树修复 commits
  （08-29 前后）可能包含这些文件的适配 —— 逐个对照后再决定
  是修 src 还是适配测试

---

## 6. 术语速查

| 术语 | 解释 |
|---|---|
| 回归候选 | 8 月基线通过、本轮失败的文件（需甄别真伪） |
| EL2 路径 | HarmonyOS 应用第二级加密存储；social4hyq 用它规避 socket/硬链接 EPERM |
| node-ohos | Harmonybrew 的 OHOS 原生 node（reports openharmony）；harness 优先选它 |
| multi-run | runner 的重复执行机制（超时预算敏感） |

---

## 7. 待办

- [ ] 逐文件甄别（对照 social4hyq 的同名文件状态与修复 commits）
- [ ] stdin backpressure：定位 v1.4.0 的行为变更点
- [ ] valkey：seccomp 规则定位（对比 social4hyq 的 seccomp 配置）
- [ ] intl：ICU 数据差异定位
- [ ] 甄别结论回写本清单（真回归 → 修 src；环境差异 → 测试适配）

---

*文档日期：2026-09-03 | 分析者：Sisyphus*
*依据：20260902 真机全量报告（lists/fail_535_regression_candidates.txt 38 候选、
fail_classified_535.txt 分类）+ social4hyq OHOS_TEST_STATUS.md（08-29）*
*关联：pr14-p1-codesign-stub-inheritance.md、pr13-p1-ohos-fulltest-lane-unblock.md*
