# Bun OHOS aarch64 全量测试指导(新人版)

> 目标读者:第一次接触本项目的测试人员。
> 读完本文 + 按 steps 执行,即可对 ljy9812/bun 构建的 OHOS 版 Bun 跑完整 test suite,产出可对比的通过率报告。
> 维护者注:本文基于 2026-08 已固化的统一测试方案(ohos-fulltest-skill),所有坑都已实测踩过,**不要"优化"流程里的任何参数**。

---

## 0. 你需要准备什么

| 项 | 要求 | 说明 |
|---|---|---|
| Windows 宿主机 | Win10/11,装有 **Git Bash** | 所有宿主机命令在 Git Bash 里执行(PowerShell 有引号陷阱,见 §9) |
| hdc 工具 | HarmonyOS SDK 的 `hdc` 在 PATH | 随 DevEco Studio 或 command-line-tools 安装 |
| 鸿蒙设备 | HarmonyOS PC(aarch64),已开开发者模式 + USB 调试 | 测试机,需 ~3GB 空闲存储 |
| 设备 root 权限 | `hdc root` 可用 | 测试走 root 域,不需要给 binary 签名 |
| 网络 | 能访问 github(国内可走 ghfast.top 镜像) | 下载 release 二进制用 |
| 时间 | 一次全量 **3~6 小时**(PARALLEL=2) | 期间设备会被打满,别干别的 |

**全景图**:

```
Windows 宿主机                          鸿蒙设备(media 域,root 可访问)
─────────────────                      ─────────────────────────────────
git clone ljy9812/bun          ──hdc──▶ /storage/media/100/local/files/
gh release download 二进制      ──hdc──▶   Docs/Desktop/Linux/
                                          ├── bun-aclass      被测二进制
                                          ├── test/           测试树 + node_modules
                                          ├── launch-fulltest.sh   启动器
                                          ├── run-all-official-*.sh runner
                                          ├── result_<run>.txt      stdout 日志
                                          └── all-official-report-*.txt  明细报告
```

**为什么在 media 域测**:`/storage/media/100/local/files/Docs/Desktop/Linux/` 是 hdc root 可访问的存储域,**未签名 ELF chmod 755 后可直接 exec**。不要用 `~/`(currentUser 域,hap uid 20020086,未签名 binary 无法 exec,且易和历史残留混淆)。

---

## 1. 连接设备并确认 root

```bash
hdc list targets          # 应显示设备序列号
hdc root                  # 切 root
hdc shell "whoami"        # 期望 root
```

任何一步失败:检查 USB 调试授权弹窗 / 换数据线 / 重启 hdc(`hdc kill -r`)。

---

## 2. 获取仓库

```bash
git clone -b ohos-aarch64 https://github.com/ljy9812/bun.git
cd bun
git rev-parse HEAD        # 记下这个 commit,后面所有对比都要用它
```

国内网络可加镜像:`git clone -b ohos-aarch64 https://ghfast.top/https://github.com/ljy9812/bun.git`

> **测试树必须与被测 binary 同 commit**。树与 binary 不匹配会导致用例数断崖(实测 56360 → 18406,掉 67%),这是假回归的最大来源。

---

## 3. 获取并部署 Bun 二进制

### 3.0 开发-测试闭环:改代码后如何拿到新 binary(可选,首次测试可跳过)

`ohos-build-github.yml` 会在 **push 到 ohos-aarch64 时自动触发**构建(github-hosted ARM runner,约 30~40 分钟),构建成功后**自动把产物发布到 `ohos-latest` release**。所以完整闭环是:

```
改代码 → git push origin ohos-aarch64 → CI 自动构建(~30min)→ ohos-latest 自动更新 → §3.1 下载的就是新 binary
```

```bash
# 1) push 后查看/等待构建(也可用 gh run watch 实时盯)
gh run list -R ljy9812/bun --workflow ohos-build-github.yml --limit 3
gh run watch <run-id> -R ljy9812/bun        # 等到 completed

# 2) 手动触发(不动代码也想重构建时;可传 webkit_ref 覆盖 pin)
gh workflow run ohos-build-github.yml -R ljy9812/bun --ref ohos-aarch64

# 3) 确认 ohos-latest 里的 binary 对应哪次构建:看最近一次成功 run 的 commit
gh run list -R ljy9812/bun --workflow ohos-build-github.yml --status success --limit 1
```

**测历史/特定 commit** 的 binary:release 只保留最新一份,但每次构建都留有 90 天的 workflow artifact(名字固定为 `bun-ohos-aarch64-github`):

```bash
# 列出各次构建的 artifact(每个对应一次 run)
gh api repos/ljy9812/bun/actions/artifacts -q '.artifacts[] | [.id, .name, .created_at, .expired] | @tsv' | head
# 下载某次 run 的产物
gh run download <run-id> -R ljy9812/bun -n bun-ohos-aarch64-github -D .
```

> 注意:CI 构建的 binary **未签名**——正好匹配本指导的 media 域测试路径(hdc root 域无需签名)。若要在 currentUser 域(用户终端)使用,走 `ohos/install-bun-ohos.sh`(安装时自动调 binary-sign-tool 签名)。

### 3.1 下载(release 的 ohos-latest 滚动版本)

```bash
# 宿主机直接下载(需 gh CLI),github-hosted 产物:
gh release download ohos-latest -R ljy9812/bun -p 'bun-ohos-aarch64-github' -D .
```

没有 gh / 网络不通时走镜像:

```bash
curl -L -o bun-ohos-aarch64-github \
  https://ghfast.top/https://github.com/ljy9812/bun/releases/download/ohos-latest/bun-ohos-aarch64-github
```

release 里有两种产物,按需选:

| asset | 来源 | 说明 |
|---|---|---|
| `bun-ohos-aarch64-github` | github-hosted CI(ubuntu-24.04-arm) | 推荐,可复现,__n1 libcxx |
| `bun-ohos-aarch64` | self-hosted CI(鸿蒙 PC) | 与 social4hyq 环境一致 |

> release 里另有 `bun-ohos-aarch64-self-v3` 和若干历史版本打包 tarball(`bun-ohos-aarch64-1.4.0-<sha>.tar.gz`)——都是存档,测试用上表两个 binary 之一即可,其余无需理会。

### 3.2 部署 + 冒烟验证

```bash
DEVROOT=/storage/media/100/local/files/Docs/Desktop/Linux

hdc file send ./bun-ohos-aarch64-github "$DEVROOT/bun-aclass"
hdc shell "chmod 755 $DEVROOT/bun-aclass"
hdc shell "$DEVROOT/bun-aclass --version"     # 记录输出,期望 1.4.0 系列
```

> **为什么叫 bun-aclass**:runner 的孤儿进程清理用 `pgrep -f "bun-aclass"` 匹配,改名要同步改 runner。
> 如果 `--version` 报 permission denied:你大概率发到了 currentUser 域,回 §0 检查路径。
> **后续所有章节的命令都假定 `DEVROOT` 仍在当前 shell 里设置**——新开终端(或隔天继续)先重设一遍,值见附录 A 顶部。

---

## 4. 打包并部署测试树

### 4.1 宿主机打包(只打 test/,不含 node_modules)

```bash
cd bun    # §2 的 clone 目录
git sparse-checkout add test/ 2>/dev/null   # 若 clone 时没拉全;普通全量 clone 可跳过此行

tar czf ../test-tree-$(git rev-parse --short HEAD).tar.gz -C test .
```

验证 tar 含 OHOS 修复:

```bash
tar xzf ../test-tree-*.tar.gz -O ./harness.ts | grep -c isOHOS
# 期望 1(唯一一行:export const isOHOS = process.platform === "openharmony";看到 0 才是树不对)
```

### 4.2 部署到设备(保留旧树的 node_modules)

推荐用仓库自带的部署脚本(在宿主机 clone 目录里执行,免去手敲复杂转义):

```bash
bash ohos/fulltest/deploy-test-tree.sh ../test-tree-<commit>.tar.gz
# DEVROOT 不是默认路径时: bash ohos/fulltest/deploy-test-tree.sh ../test-tree-<commit>.tar.gz /your/devroot
```

脚本做的事:发 tar → 备份设备旧树(含 node_modules!)→ 解新树 → 挪回 node_modules → 清备份。等价的手工命令如下(备查,引号转义易错,别手敲):

```bash
TAR=test-tree-<commit>.tar.gz
hdc file send "../$TAR" "$DEVROOT/$TAR"

hdc shell "cd $DEVROOT && \
  if [ -d test ]; then mv test test-old-\$(date +%s) || { echo 'mv failed'; exit 1; }; fi && \
  mkdir -p test && tar xzf $TAR -C test && \
  _nm=\$(ls -d test-old-*/node_modules 2>/dev/null | head -1) && \
  if [ -n \"\$_nm\" ]; then \
    [ -e test/node_modules ] && rm -rf test/node_modules; \
    mv \"\$_nm\" test/node_modules; \
  fi && \
  rm -rf test-old-*"
```

### 4.3 node_modules(关键!最容易翻车的一步)

**缺 node_modules 时,bundler/bake/dev/esbuild 整段(200+ 文件)import 崩溃,每文件只 1 fail 0 用例——是用例数断崖的最大单一原因,不是 binary 回归。**

首次部署(设备上没有旧树)时,三选一:

1. **设备上直接装**(最常用):
   ```bash
   hdc shell "cd $DEVROOT/test && $DEVROOT/bun-aclass install --registry=https://registry.npmmirror.com --ignore-scripts"
   ```
   慢,但依赖解析发生在 OHOS 上,平台 optional deps(@esbuild/openharmony-arm64)拿得对。
2. **从既有设备树迁移**:旧树 `test-old-*/node_modules` 还在就 mv 回来(上面 4.2 的命令已自动做)。
3. **宿主机装好传过去**:不推荐——宿主机(bun install 在 Windows 上)会解析出宿主机平台的二进制,传到 OHOS 上 esbuild 等原生模块平台不符。

### 4.4 完整性校验(必做,不做等于白跑)

```bash
# ① 文件计数:用与 runner 完全相同的 find 规则,记录数字(跨轮次对比用)
hdc shell "cd $DEVROOT && find test/ -type f \( -name '*.test.ts' -o -name '*.test.js' -o -name '*.test.tsx' -o -name '*.test.jsx' -o -name '*.spec.ts' -o -name '*.spec.tsx' -o -name '*.spec.js' -o -name '*.spec.jsx' -o -name '*.spec.cjs' -o -name '*.test.mjs' -o -name '*.test.cjs' -o -name '*.spec.mjs' -o -name '*.test.mts' -o -name '*.spec.mts' -o -name '*.test.cts' -o -name '*.spec.cts' \) ! -path '*/node_modules/*' ! -name '*fuzzy-wuzzy*' ! -path '*/fixtures/*' ! -path '*/snapshots/*' ! -path '*/node-napi-tests/*' | wc -l"

# ② 三个存在性检查
hdc shell "cd $DEVROOT && \
  echo -n 'harness isOHOS: ' && grep -c isOHOS test/harness.ts && \
  echo -n 'expectations OPENHARMONY: ' && grep -c 'OPENHARMONY' test/expectations.txt && \
  echo -n 'esbuild: ' && ls -d test/node_modules/esbuild >/dev/null 2>&1 && echo ok || echo MISSING && \
  echo -n 'verdaccio: ' && ls -d test/node_modules/verdaccio >/dev/null 2>&1 && echo ok || echo MISSING"
```

期望:①记录数字(随树 commit 微变,历史参考 1729~1872);②isOHOS=1、OPENHARMONY=46、esbuild+verdaccio 都 ok。
**任何一项 MISSING,先修复再继续。**

---

## 5. 部署启动器与 runner

需要 3 个脚本(功能见 §8 附录):

| 脚本 | 作用 |
|---|---|
| `launch-fulltest.sh` | 启动器:固化全部 env(并发/重试/超时/语义 flag),单一事实源 |
| `launch-fulltest-sh.sh` | 同上的 sh 兼容版(设备没有 bash 时用,见 §6) |
| `run-all-official-progress-optimized.sh` | runner:per-file 执行 + 进程组 kill + 超时/崩溃区分 + 汇总 |

**获取方式**:仓库 `ohos/fulltest/` 目录(2026-08-25 已入库,clone 即得,含 3 个脚本 + README)。launcher 和 runner **务必用现成文件,勿手抄**——语义 flag 漏一个整轮数据作废。

```bash
# 在 §2 的 clone 目录里执行
hdc file send ohos/fulltest/launch-fulltest.sh                   "$DEVROOT/launch-fulltest.sh"
hdc file send ohos/fulltest/launch-fulltest-sh.sh                "$DEVROOT/launch-fulltest-sh.sh"
hdc file send ohos/fulltest/run-all-official-progress-optimized.sh "$DEVROOT/run-all-official-progress-optimized.sh"
hdc shell "chmod 755 $DEVROOT/launch-fulltest.sh $DEVROOT/launch-fulltest-sh.sh $DEVROOT/run-all-official-progress-optimized.sh"
```

> runner 版本必须包含:**setsid + PGID kill**(防孙进程泄漏)、**超时/崩溃区分**(134/139 是崩溃不是超时)、**`./` 路径前缀**(无前缀会被当 filter → 全文件 0 用例全挂)。旧版 runner 缺任一特性都会产生错误数据。

---

## 6. 启动全量测试

```bash
# 宿主机 Git Bash 里执行。注意有两个 &:倒数第二个 & 在设备 shell 内(detach 测试进程),
# 末尾的 & 在宿主机侧——hdc 会阻塞等 stdout 关闭,宿主机不后台跑这条命令会一直挂着
hdc shell "cd $DEVROOT && setsid bash launch-fulltest.sh > result_fulltest_\$(date +%Y%m%d_%H%M%S).txt 2>&1 &" &
```

要点:
- **必须经 launcher 启动**,不要直接跑 runner——launcher 固化了语义 flag,漏设结果失真;
- **必须 bash**(runner 用 `$BASHPID`/`${var:offset:len}`,sh 会崩)。设备无 bash 时用 `launch-fulltest-sh.sh`(sh 兼容版);
- **hdc 命令本身放宿主机后台**跑(加 `&` 或终端后台),否则 hdc 等流关闭会一直挂着;
- launcher 自带前置校验:binary/runner/测试树缺失会 `exit 1`;**esbuild 缺失只 WARN 不中止**,看到 WARN 必须回去补 node_modules 再跑。

启动器固化的关键 env(**勿改**,理由见 §8):

```
PARALLEL=2  RETRIES=2  TMOUT=300  TMOUT_BUNDLER=900  BUN_TIMEOUT=300000
BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1  BUN_GARBAGE_COLLECTOR_LEVEL=0
GITHUB_ACTIONS=false  CI=1  BUN_DEBUG_QUIET_LOGS=1  NO_COLOR=1  HOME=$DEVROOT/home
```

---

## 7. 监控与收尾

### 7.1 监控(跑 3~6 小时,期间隔段时间看一眼)

```bash
# 最新进度行
hdc shell "tail -c 400 $DEVROOT/result_fulltest_*.txt | tr '\r' '\n' | grep Files: | tail -1"

# 进程数(正常 2~5;>10 说明有泄漏,查孤儿)
hdc shell "ps -ef | grep -E 'bun-aclass test|run-all-official' | grep -v grep | wc -l"

# 泄漏排查:大量 PPID=1 = 孤儿泄漏;大量同 PPID = 某测试 spawn 循环(watchdog 会兜住)
hdc shell "ps -ef | grep bun-aclass | grep -v grep | awk '{print \$3}' | sort | uniq -c"
```

> **"卡死"误判**:设备 CPU 打满时 hdc 命令响应 30-60s 超时,runner 其实在正常跑。先看 result 文件 mtime 是否在更新,再决定要不要 kill。

### 7.2 收集报告(两份都要拉)

| 文件 | 内容 | 用途 |
|---|---|---|
| `result_fulltest_<ts>.txt` | 进度行 + per-file ✅/❌/⏰/💥 | 看汇总、超时/崩溃计数 |
| `all-official-report-<ts>.txt` | 每文件原始输出 + `EXIT_CODE:N` | 诊断用例数、崩溃码、import 错误 |

```bash
hdc shell "cat $DEVROOT/result_fulltest_<ts>.txt"      > ./result_<run>.txt
hdc shell "cat $DEVROOT/all-official-report-*.txt"     > ./report_<run>.txt
```

### 7.3 关键指标

报告末尾汇总块:

```
Duration: HH:MM:SS
Files:    N total | P passed | F failed
Cases:    CP passed | CF failed
Timeouts: T | Crashes: C
```

- **用例率 = CP / (CP + CF)**,核心可比指标;
- **分母口径**:超时文件的用例被剔出分母(会抬高率),崩溃文件保留 partial 计入分母。**跨轮次对比必须同时看超时数**——超时数差很大(如 9 vs 340)时用例率不可直接比;
- 历史基准(同条件才可比;前两行来自 **social4hyq 的测试树**,你无法用自己的 ljy9812 clone 复现这两个 commit,仅供通过率量级参考——你本次的树 commit 以 §2 `git rev-parse HEAD` 为准):

| 轮次 | 树 | binary | 文件数 | 用例率 | 超时 |
|---|---|---|---|---|---|
| baseline | social4hyq 7780f3e42 | github(JIT on) | 1872 | **98.48%**(56360/871) | 9 |
| 0338f88 | social4hyq 0338f88 | github 1.4.0 | 1872 | 97.25%(22779/645) | 340(不可直接比) |
| cu 域 | media envfix 系列 | self fix2 | — | 95.7%~98.58% | — |

### 7.4 诊断命令(报告在 `report_<run>.txt` 上执行)

```bash
# 崩溃文件计数(134=SIGABRT, 139=SIGSEGV)
grep -ac 'EXIT_CODE:134\|EXIT_CODE:139' report_<run>.txt

# 全部异常退出码
grep -a 'EXIT_CODE:' report_<run>.txt | grep -av 'EXIT_CODE:0\|EXIT_CODE:1' | head -20

# 用例数异常时:查哪些文件只跑了 1 个用例(多为 import 崩溃缺依赖)
grep -a 'Ran 1 test ' report_<run>.txt | wc -l
```

---

## 8. 为什么是这些参数(改之前必读)

| 参数 | 值 | 原因 |
|---|---|---|
| PARALLEL | 2 | 设备无 swap,3 个 worker 同时抽中 handle-leak/fetch-leak/websocket 类文件即 OOM 死锁 |
| RETRIES | 2 | 跨轮次必须同值,否则超时/失败文件数不同,用例率不可比 |
| 路径参数 `./` 前缀 | 必须 | 新 binary 把无 `./` 前缀的路径当 filter → "had no matches" → 全文件 0 用例 |
| setsid + PGID kill | 必须 | `timeout` 只杀直接子进程,泄漏孙进程(verdaccio/fixture server)导致 OOM |
| BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1 | 必须 | 启用测试内部 flag,缺失部分用例行为不同 |
| BUN_GARBAGE_COLLECTOR_LEVEL=0 | 必须 | 该 gate 嵌套在 GC_LEVEL 块内(VM.rs),单设上面那个不生效;=0 只解锁不触发 aggressive GC;缺失时 `bun:internal-for-testing` import 报 ENOENT(~181 fail) |
| GITHUB_ACTIONS=false | 必须 | CI=1 但非真 GHA,避免触发 GHA 专属断言 |
| HOME=$DEVROOT/home | 必须 | 设备 root 用户 /root 不存在,写 $HOME 的操作必失败 |
| OPENHARMONY Skip 排除 | runner 内置 | expectations.txt 中 `[Skip]` 类移出分母(46 条中 ~15 条);`[Failure]/[Flaky]` 保留运行用于追踪 |

---

## 9. 常见坑速查

| 症状 | 根因 | 处理 |
|---|---|---|
| 用例数断崖(5 万 → 1.8 万) | 树残缺 / node_modules 丢失 | 重部署完整树 + 恢复 node_modules(§4.3) |
| 全文件 0 用例 "had no matches" | 路径参数无 `./` | 用现行 runner(已内置) |
| 卡死不动 + 进程数暴涨 | 孙进程泄漏 | 确认 runner 是 setsid+PGID 版(§5) |
| 并行 worker 假超时翻倍 | 全局 pkill 误杀兄弟 | 现行 runner 已删全局 pkill |
| 崩溃被算成超时 | 旧 runner 不区分退出码 | 现行 runner 已区分(124/137/143=超时;134/139=崩溃) |
| sh 跑 runner 语法崩 | bash 专属语法 | 用 `bash launch-fulltest.sh` |
| hdc 命令挂住不返回 | hdc 等 stdout 关闭 | 宿主机侧后台跑 hdc |
| PowerShell 里命令错乱 | 引号/glob 被吞 | 全程用 Git Bash;复杂命令写成 .sh 文件 file send 进去执行 |
| 看似卡死 | 设备 CPU 满,hdc 响应慢 | 看 result 文件 mtime,别急 kill |
| binary exec 报权限 | 发到了 currentUser 域 | 用 media 域 DEVROOT(§0) |

---

## 附录 A:一页速查(全部命令按序)

```bash
DEVROOT=/storage/media/100/local/files/Docs/Desktop/Linux

# 1. 连设备
hdc list targets && hdc root && hdc shell whoami

# 2. 拿仓库
git clone -b ohos-aarch64 https://ghfast.top/https://github.com/ljy9812/bun.git && cd bun

# 3. 拿 binary + 部署
gh release download ohos-latest -R ljy9812/bun -p 'bun-ohos-aarch64-github' -D .
hdc file send ./bun-ohos-aarch64-github "$DEVROOT/bun-aclass"
hdc shell "chmod 755 $DEVROOT/bun-aclass && $DEVROOT/bun-aclass --version"

# 4. 打树 + 部署
tar czf ../tree.tar.gz -C test .
hdc file send ../tree.tar.gz "$DEVROOT/tree.tar.gz"
hdc shell "cd $DEVROOT && ... (§4.2 部署命令)"
# node_modules 首次:设备上 bun install(§4.3)

# 5. 校验(§4.4)
# 6. 传脚本 + 启动(§5、§6;注意末尾宿主机侧 & )
bash ohos/fulltest/deploy-test-tree.sh ../tree.tar.gz   # §4.2
hdc shell "cd $DEVROOT && setsid bash launch-fulltest.sh > result_fulltest_\$(date +%Y%m%d_%H%M%S).txt 2>&1 &" &
# 7. 监控(§7.1)
# 8. 拉报告 + 算用例率(§7.2、§7.3)
```

## 附录 B:launch-fulltest.sh 说明(勿手写)

从仓库 `ohos/fulltest/` 取(clone 即得),**不要凭记忆重写**。其内容 = §6 关键 env 的固化 + 前置校验(binary/runner/测试树缺失即 `exit 1`,esbuild 缺失 WARN)+ `exec bash run-all-official-progress-optimized.sh`。语义 flag 漏一个整轮数据作废,所以永远用仓库里的现成文件。

## 附录 C:结果记录模板

```
日期:
binary:  <asset 名 + bun --version 输出>
树:      <repo commit>
文件数:  <runner-find 计数>
Duration / Files / Cases / Timeouts / Crashes:
用例率:
异常项:  (崩溃数、超时数、新 fail 模块)
```
