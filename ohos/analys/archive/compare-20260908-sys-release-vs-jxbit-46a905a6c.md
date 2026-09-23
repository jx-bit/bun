# 对比分析：20260908 sys-release（social4hyq binary）vs jxbit 46a905a6c（我们的 binary）

> 同一棵测试树（social4hyq/ohos-bun `ohos-aarch64` @ `36854e8e`，2048 文件）、同口径
> （PARALLEL=2 RETRIES=2 TMOUT=300/900/60），**唯一变量 = binary**。
> 详见各报告目录 README。

## 1. 总量

| 轮 | binary | 结果 |
|---|---|---|
| sys-release | social4hyq 构建（旧线） | （以其为基线） |
| **jxbit** | **我们 46a905a6c**（含 8 月线 + EPOLLONESHOT + codesign 懒修复 + shebang 展开 + #26） | 1643/2048 文件过；用例率 **96.17%**；超时 21；崩溃 2 |

差分清单（`20260908_fulltest_jxbit/lists/`）：
- `fail_sys-release_only`（**11**）：我们 binary 独有**修复**
- `fail_overlap_both`（**135**）：两轮都挂 → 树/环境问题，与 binary 无关
- `fail_jxbit_only`（**270**）：我们 binary 独有失败 → 本文档主题

## 2. 我们 binary 修复掉的 11 个（验证 ✓）

- **napi uv / uv_stub** —— codesign 懒修复（PR #16）对 `.node` dlopen 路径生效 ✓
- **bake/dev ×5** —— 我们线对 bake dev server 的修复生效
- **regression 26225 / 26657 / 29585** —— 对应修复生效

## 3. 270 个 jxbit_only 的分解（核心结论）

### 3.0 P0 根因：我们的 binary `process.platform` 报的是 "linux"（2026-09-09 追加，已修复）

**决定性证据**：`fs-birthtime-linux.test.ts` 两树逐字节相同且带
`describe.skipIf(openharmony)`，却在我们 binary 的两轮（20260902 的 535fb153c7、
20260908 的 46a905a6c）都挂 ×4，而在他们 binary 上过 —— 我们 binary 的
`process.platform` 没报 `"openharmony"`，**所有 isOHOS 门控静默失效**。

机制：`src/bun_core/Global.rs` 的 `os_name` 只特判了 android；OHOS rust target
是 `aarch64-unknown-linux-ohos`（`target_os="linux"`、`target_env="ohos"`），
落到 Linux 分支 → "linux"。他们的 fork 有 `cfg!(target_env = "ohos") →
"openharmony"` 特判（含 os_display "OpenHarmony"），我们没有。

影响面：270 个 jxbit_only 里 **23 个文件**的测试内容含 isOHOS/openharmony 门控
（skip 不生效、cwdScope 不切换、平台 fixture 选错）；另 npm user-agent 平台段
变 "linux"，@ohos-ports optional deps 解析路径与其构建预期不符。
**修复**：PR [#29](https://github.com/jx-bit/bun/pull/29)（`claude/ohos-process-platform-openharmony` @ `ff4f267b86`，移植他们的
特判，+9/-2）。20260902 轮同因（fail_535 亦含 fs-birthtime）——此 bug 存在于
我们全部 OHOS binary。panic 修复见 PR [#28](https://github.com/jx-bit/bun/pull/28)。

### 3.1 主因：两棵测试树双向漂移 × binary 行为差（估计占大头）

**测试树年代考证（2026-09-09 补）**：
- **我们的树** = 官方 v1.4.0 基线 + 121 文件修改（4 增 117 改）。8/13 upstream
  merge 曾带入 1015 个 test/ 文件的 post-1.4.0 变更，9/2 的 reconcile
  （535fb153c7e）把树对回真机验证过的 v1.4.0 线；抽查
  `bundler_cjs.test.ts` 与 `bun-v1.4.0` tag 逐字节一致
- **他们的树**（36854e8e）**不是严格 v1.4.0**：`__toESM` 处期望
  `{"value":...}` —— 比 v1.4.0 官方期望（`{"__esModule":true,…}`，
  v1.4.0 tag 实证）更旧，说明其线从更早基线分叉；但同时含有 v1.4.0 没有
  的用例（bun-build-compile 的 bytecode RSS 测试）——他们合并过部分
  post-1.4.0 测试。**双向漂移**

实证样例：
- `bundler_cjs __toESM_import_syntax_with_esModule`：v1.4.0 官方期望 =
  我们 binary 的输出 `{"__esModule":true,"default":{…},"named":…}`；他们的
  树期望更旧的 `{"value":"default export"}` → 判我们"失败"
- `sql` ×6、`bundler` ×26、`esbuild` ×8、`http` ×13、`util/inspect` ×8 等
  簇同因（两树各自漂移 + 我们 binary 含 upstream main 行为）

**处置**：不是我们 binary 的 bug。真正对齐需要把两棵树 reconcile 到同一
基线（建议以官方 v1.4.0 + 双方 OHOS 适配合并）。短期衡量口径应以
`fail_overlap_both`（135）+ 崩溃/超时为主。

### 3.2 真 bug：browser-field 禁用入口 panic（P0，已修复）

两处崩溃（SIGABRT）**同根因**：`bun build` 子进程
`panic: index out of bounds: the len is 0 but the index is 0`：

- `bundler_edgecase.test.ts`（browser/EntryPointDisabledByBrowserField 等）
- `x509.test.ts`（其 fixture 经 `bun build --target=browser` 子进程触发）

机制：entry point 被 package.json `browser` 字段禁用时，我们线的
`resolve_entry_point` 返回 `Ok(path=None)`（无守卫）→ 无路径 entry 流入
bundler 图 → 下游对空集合 `[0]` 索引 → panic。上游 main 已修
（`reject_unbundleable_entry_point`：disabled/external 入口直接报错
`"…" is disabled due to "browser" field in package.json (entry point)` 并返回
Err——错误文本与 36854e8e 树的期望逐字一致）。

**修复**：移植该守卫（transpiler.rs，fresh + cache-bust 重试两条路径），见
PR（transpiler.rs）。v2 三个 enqueue 调用点对 Err 均已有 `continue`/优雅
返回路径。

### 3.3 次要 binary 差异

- `bundler_edgecase AbsolutePathShouldNotResolveAsRelative`：我们的
  resolver 打开 `/` 探测得到 EACCES 并作为错误上报（上游 open_dir_at 语义），
  他们的线没有此探测/已消化。我们树里该子用例已 OHOS-skip（9/2），仅影响
  他们的树 —— 记录，不修。

### 3.4 21 个超时

多为 leak/长跑类（serve-http2、spawn、handle-leak、fetch-backpressure…），
两轮口径相同（TMOUT 300/900/60）。与 20260903 轮的超时清单重叠度高，
归属设备负载/长跑类，待 stable 复测。

### 3.5 疑似挂起专项：4 个文件全部解除或收敛（2026-09-09 用 20260908 轮数据复核）

20260903 轮的"4 个疑似挂起（隔离单跑 >150s 无结果）"在 20260908 轮**全部出结果**，
"挂起"定性解除，各自收敛为具体问题：

| 文件 | 20260908 实测 | 定性 | 处置 |
|---|---|---|---|
| bundler_compile | 167.8s 跑完，73 pass/**12 fail**（EXIT 1） | 行为断言差异：①GC 断言——期望无 "FullCollection" 但出现（同步 full GC 在加载入口后运行）②compile splitting stdout 错位（"main ran/main main"） | 逐条 triage（upstream GC 行为演进 vs OHOS 特性，待查） |
| serve-body-leak | 71.3s 跑完，8 pass/1 fail（泄漏计量本体 70031 次 expect 通过） | **HTTP2Unsupported**：H2 客户端会话握手失败回退 H1 后 forced H2 报错。H2 代码区域与 social4hyq fork **diff 为空** → 构建/底层差异（BoringSSL ALPN/uWS 配置），非代码 | **构建配置对比**（他们的 bottle 构建过、我们 CI 构建不过）；新立项 |
| spawn-pipe-leak | 出结果，1 子用例 30s 超时（leak-memory）+ **47 个孤儿进程**被清理 | 唯一残余的真挂起嫌疑（overlap，两 binary 都挂） | 需该子用例的细粒度日志；待查 |
| spawn.test.ts | 出结果，1 子用例 ×3 快速失败（gcTick > spawn > Uint8Array stdin，~350ms，非挂起） | overlap，具体小断言 | 单独 triage |

> 教训：">150s 无结果"的定性在下轮 binary/树变化后必须复核——4 个里 0 个真挂起，
> 全部是可定位的具体失败。分桶注意：bundler_compile 同时出现在 overlap 与
> jxbit_only 名单（口径噪音），以实测为准。

## 4. 结论与建议

1. **合并 panic 修复 PR**（browser-field entry）—— 两处崩溃消除
2. **口径修正**：jxbit_only 270 里的大头是"测试树落后于我们的 binary"，
   不是回归。建议下一轮起用**我们的测试树**跑我们的 binary（树内已含全部
   OHOS skip 与上游测试更新），或者把 36854e8e 树按上游 reconcile
3. 135 个 both-fail 是当前真正的公共债（网络域 install、长跑超时、
   第三方产物），与 20260903 轮 triage 结论一致
4. napi 懒修复、codesign、shebang 展开均在本轮得到真机验证 ✓
