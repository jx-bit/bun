# P2: 测试补网——skip 台账、libc 判定守卫、平台语义断言 — 归档文档

> **关联 PR**:[#55](https://github.com/jx-bit/bun/pull/55)（单 commit
> `2a831e4664`，5 文件 +345，rebase 到含 #52/#53/#54 的 tip `6ba99e7085`）
> **状态**：✅ 合并（f21748c2e9）
> **一句话**：复盘 #52/#53/#54 为什么漏网（pr52 文档 §6 / 对话记录），
> 把三个漏网机制逐一堵上：skip 静音 → 台账强制登记；常量无守护 →
> source-lint 钉死；松断言 → 设备语义精确值测试。
> **§后续(2026-09-21)**：#52/#53/#54 合并后已按规范 rebase(soft reset +
> 单 commit 重写 + force-with-lease),依赖期 CI 红解除,lint 全绿
> 37/37;PR 内注释与台账字段全文英文化(初版中文违反 PR 规范,自查发现
> `IS_OHOS/IS_GLIBC` 字面量还会误伤 check-pr 的 `ohos/` 正则,body/commit
> 已改写为 "IS_OHOS and IS_GLIBC");重建 commit 时两次踩坑记录:
> pathspec commit 后 index 不自动更新,多余的 `--amend` 把旧 index 提交
> 进去导致 #54 修复被静默回退——重建必须 soft reset + checkout 对齐 +
> pathspec commit,严禁无 pathspec 的 amend。

## 1. 漏网复盘（为什么之前的测试没查出来）

| 漏网 bug | 机制 | 实证 |
|---|---|---|
| #53 os.machine 误报 | 上游套件只做 12 值 membership 断言（`os.test.js:219`），`arm64`/`aarch64` 都在名单里 → 错值照过；且上游代码自带同 bug | 〔源码〕os.test.js:205-219 |
| #52 node 子进程 ENOENT | A 的 device-only 测试随测试树同步进来（`91054212c8d`），但 `nodeExe()=which("node")\|\|null` 在设备为空 → **skip 而非 fail**；615b48e95 轮失败清单 grep 不到它 | 〔源码〕harness.ts:150 + fulltest fail 清单 |
| #54 libc 判定 | upgrade/compile/NAPI 三个面均在测试语料之外：upgrade 无测试、--target 解析无用例、NAPI 诊断需要 glibc .node 夹具而语料刻意配套（dedupe 到有 openharmony 构建的版本） | 〔源码〕+ knowledge 台账 |

系统性根因：①测试参照系=上游套件而非 API 语义契约；②skip 与失败
不同价、无人追 skip；③测试环境配套完好，bug 住在接缝里。

## 2. 补网件（3 件套 + 触发器）

### 2.1 skip 台账（`ohos-skip-inventory.test.ts` + `.json`）

- 扫全测试树 `skipIf(...isOHOS...)` 位点（双向：`skipIf(isOHOS)`=
  设备上失去覆盖;`skipIf(!isOHOS)`=device-only,记录设备成立条件）,
  强制登记 (file, conditions, direction, reason, device_plan)。
- 三个检查:漏登即红 / 条目过期(文件没了或条件消失)即红 /
  reason+device_plan 非空。
- **当前台账:13 文件 17 位点**。诚实分级:openat2 SIGSYS 类=永久豁免
  候选(内核限制);patchelf/ld.so 类=CI lane 覆盖;其余早期 skip=
  "未归因,待 triage"(合法状态,"没登记"不是)。
- **关键条目**:`spawn-ohos-node-userinfo` 标注 device_plan——设备需
  harmonybrew 装**真 node**;不能用 bun-as-node shim 顶替(内嵌 shim 令
  preload probe no-op,测试假绿)。

### 2.2 libc 判定守卫(`ohos-libc-detection.test.ts`)

钉死 #54 的每个承重点,上游 merge 冲掉任何一处先在这里红
(pr51 getcwd_honest 被冲掉的教训):IS_MUSL 加宽串、IS_OHOS/IS_GLIBC
常量、SUFFIX_ABI 中 IS_OHOS 先于 IS_MUSL(顺序承重:IS_MUSL 加宽后
落错分支)、Libc::Ohos 全 match 位点(枚举/default/npm_name/parse/
白名单/platform 映射)、libc_check 的 IS_MUSL 门控。

### 2.3 设备语义断言(`test/js/node/os/os-ohos.test.ts`)

`describe.skipIf(!isOHOS)` 整文件 device-only:machine()=aarch64
(精确值,守 #53)、process.platform=openharmony、os.type()=Linux
(守 #30)、userInfo() in-process 基线(守 #52 的 bun 侧面)。
**machine 断言在 #53 合并前为红是预期——它守的就是这个修复。**

### 2.4 触发器补洞(`source-lints.yml`)

paths 原来不含测试树 glob——测试树新增 skip 不会触发台账 lint。
push/pull_request 两侧补 `test/js|cli|bundler|integration|regression/**`。

## 3. 验证

- 〔本机〕台账 lint 3/3 + libc 守卫 5/5 + dead-code-escapes 24/24 ✅。
  libc 守卫在 #54 合并前对 tip 树为红(预期,证明守卫在位)。
- 〔设备〕验收步骤汇总于 `ohos/knowledge/device-test-guide.md`
  (工作区):每 PR 的命令、前置(node 安装)、预期输出、逃生门验证;
  台账与 fulltest 报告的交叉核对方法。

## 4. 与参照实现的对比

**本 PR 无参照实现**——三个漏网机制是测试基建问题,参照线同样存在
(其 machine 断言同样松、其测试树同样有 skip)。补网是我方基于复盘的
自建守护,不涉及移植。参照线角色:其测试树同步产物(spawn-ohos-node-
userinfo)是"skip 静音"现象的载体,本 PR 让这类载体可见化。
