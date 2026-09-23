# 真机测试指导——交付线补网测试(#52–#55 家族)

> 面向:在鸿蒙真机上执行/验收测试的人。
> 背景:pr52 复盘发现三个漏网机制(松断言、skip 静音、接缝无覆盖),
> 本指南说明补网件在设备上**怎么跑、先决条件是什么、预期输出是什么**。
> 台账:`test/internal/source-lints/ohos-skip-inventory.json`(lint 强制)。

## 一、skip 台账机制(先读这个)

**是什么**:`test/internal/source-lints/ohos-skip-inventory.test.ts` +
`ohos-skip-inventory.json`。扫全测试树的 `skipIf(...isOHOS...)` 位点,
强制每个位点在 JSON 里登记 reason(为什么 skip)与 device_plan(设备上
如何最终覆盖)。漏登 / 过期 / 空字段 → lint 红。

**怎么跑**(本机,秒级):

```sh
USE_SYSTEM_BUN=1 bun test test/internal/source-lints/ohos-skip-inventory.test.ts
```

**新增 OHOS 门控 skip 时的操作**:跑 lint → 按报错把位点补进 JSON →
reason 写真话(不知道就写"未归因,待 triage")→ device_plan 写清最终
覆盖路径。**"未归因"是合法状态,"没登记"不是。**

**与 fulltest 报告交叉核对**:fulltest 的失败清单只含"跑了且挂"的;
skip 位点对照本台账逐条过一遍——`skipIf(isOHOS)` 条件在设备上恒真
的条目 = 本轮没有覆盖的面,按 device_plan 推进。

## 二、逐 PR 设备验收步骤

### #52 node 子进程 os.userInfo preload

**前置(硬性)**:设备 PATH 上要有**真 node**:

```sh
which node   # 必须非空;harmonybrew: brew install node
```

> ⚠️ 不能用 bun-as-node shim 顶替:内嵌 shim 使 preload 的
> probe-then-fallback 变成 no-op,测试会假绿,测不出真链路。

```sh
# 1. 自动用例(守卫条件 !isOHOS || !node,node 就位后自动激活)
bun test test/js/bun/spawn/spawn-ohos-node-userinfo.test.ts

# 2. 手工复现(修复前 stderr 含 ENOENT;修复后打印用户名)
bun -e 'const p=Bun.spawnSync(["node","-e","console.log(require(\"os\").userInfo().username)"]);console.log(p.stdout.toString(),p.stderr.toString())'

# 3. 逃生门(应恢复原始行为:抛 ENOENT)
BUN_OHOS_NO_NODE_USERINFO=1 bun -e '<同上>'
```

### #53 os.machine()

```sh
bun -e "console.log(os.machine())"        # 预期: aarch64(修复前 arm64)
bun -e "console.log(process.platform)"    # 预期: openharmony
bun test test/js/node/os/os-ohos.test.ts  # 4 条精确值断言
```

注意:`os-ohos.test.ts` 的 machine 断言在 **#53 合并前为红(预期行为,
它守的就是这个修复)**,#53 合并后转绿。

### #54 libc 判定 / -ohos 命名

```sh
# 1. upgrade 拼名(修复前空后缀→glibc 包;修复后 -ohos)
bun upgrade --dry-run 2>&1 | grep -o "bun-linux-aarch64[-a-z]*\.zip"
# 预期: bun-linux-aarch64-ohos.zip(当前无此资产→404 诚实失败,保留当前版本;
#       这优于修复前"下载 glibc 包覆盖自己"的变砖路径)

# 2. --target 解析(修复前 UnsupportedTarget)
bun build --compile --target=bun-linux-aarch64-ohos ./fixture.ts

# 3. NAPI glibc 预检(修复前被跳过,现在应给干净诊断)
bun add better-sqlite3   # 已知只发 glibc prebuild 的包 → 预期得到明确的
                         # libc 不匹配报错,而非底层 dlopen 崩溃
```

## 三、已知的覆盖缺口(台账重点条目)

| 条目 | 缺口 | 解锁条件 |
|---|---|---|
| spawn-ohos-node-userinfo | 设备无 node → skip | harmonybrew 装 node(见 §二 #52) |
| bun-build-compile / 24742 / 29290 | patchelf/ld.so 设备不存在 | CI 容器 lane 覆盖,设备永久豁免候选 |
| serve-directory-routes(SNI/EXDEV/readdir/pre-epoch/proxy/pipes 等) | 内核 seccomp(openat2)或未归因 | 逐条 triage,结论记回台账 |

## 四、本机(非设备)快速门禁

```sh
USE_SYSTEM_BUN=1 bun test test/internal/source-lints/
```

台账 lint + libc 判定守卫(#54 的每处承重点:IS_MUSL 加宽、IS_OHOS、
SUFFIX_ABI 顺序、Libc::Ohos 全 match 位点、libc_check 门控)都在这里,
上游 merge 冲掉任何一处先在这里红(pr51 getcwd_honest 被冲掉的教训)。
