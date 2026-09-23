## Skill 16：真机 fulltest 部署与执行（鸿蒙 PC / aarch64 设备）

### 前提（本仓库 ohos/fulltest/ 工具集设计）

- 宿主机：Git Bash（Windows）或 WSL（经 Skill 14 的 hdc 通道）
- 设备：鸿蒙 PC / aarch64 真机（真 OHOS 内核 —— 容器模拟不了的
  签名/spawn/dlopen 在真机天然成立）
- binary：ohos-build-github 的 artifact（`bun-ohos-aarch64-github`，
  110MB；ELF 画像：`NEEDED = libunwind.so.1 + libc.so`，PT_INTERP
  `/system/lib/ld-musl-aarch64.so.1`，无 .codesign —— 真机原生满足）

### 部署清单（设备全新时）

```
$DEVROOT/bun-aclass          binary（chmod 755）
$DEVROOT/test/               测试树（test/ 全量，不含 node_modules）
$DEVROOT/package.json 等     根配置（bun install 需要）
$DEVROOT/*.sh                ohos/fulltest/ 三脚本
$DEVROOT/node_modules/       设备上 bun install 生成（或宿主构建后回填）
```

根 `bun install` 会拉 workspaces（packages/bun-types、packages/@types/bun）；
`test/package.json` 的 react 走 `file:../node_modules/react`（root 先装）。
bunfig.toml `[install] linker="isolated"`、`globalStore=false`、
`minimumReleaseAge=259200` 对设备同样生效。

### 启动（必须经 launch-fulltest.sh，env 固化勿改）

```bash
# 宿主机侧（注意两组 & 的位置——hdc 会阻塞等 stdout 关闭）
hdc shell "cd $DEVROOT && setsid bash launch-fulltest.sh > result_fulltest_$(date +%Y%m%d_%H%M%S).txt 2>&1 &" &
```

### 口径（与容器/host 差异）

- 设备 3-6 小时全量；`PARALLEL=2`、`RETRIES=2`、
  `BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1` + `BUN_GARBAGE_COLLECTOR_LEVEL=0`
  （嵌套 gate，缺了 ~181 用例假失败）
- 用例率 = CP/(CP+CF)；超时文件剔出分母、崩溃保留 partial
- 跨轮对比必须同 binary commit + 同测试树 commit + 同 node_modules 状态

### 幻影 NEEDED 教训（2026-09-02 实战）

构建容器里 `brew install --only-dependencies` 临时装了 libunwind.so.1 →
binary 带上 `NEEDED libunwind.so.1` → 镜像/SDK（只有 libunwind.a）/真机
（/system/lib 无 unwind）全都无法满足 → 容器和真机双失败。
**修法：flags.ts ohos 链接行 `-lunwind` → `-l:libunwind.a`**（交叉库
p0 自编译产物含静态版，见 ../issues/pr1-p0-symbols-dyn-trimming.md §8.6）。注意
`-static-libunwind` 是 clang driver 选项，本仓库链接是裸 clang++ @rsp
调用，不认该参数（实测报 unknown argument）。幻影 NEEDED 消失后容器
与真机同时解锁。教训：链接期依赖必须核对
"运行环境是否存在同名 .so"，brew 依赖只在构建容器生命周期内存在。

### 待验证项（本 skill 随修复进展更新）

- [x] harness 解析链：`bun test` 内建约定可解析裸导入 "harness"
      （实测：system bun 于 test/ cwd 跑 js/bun/net/socket.test.ts，harness
      正常加载，失败点是预期中的 bun:internal-for-testing 缺失）。设备流程
      同机制，历届 fulltest 已验证，无需额外部署
- [ ] 设备网络到 npm registry 可达性（决定 bun install 在设备做还是
      宿主做后回填 node_modules）
- [ ] HongMeng 1.12 对 /storage 用户态 exec 的签名策略（真机 chmod 755 直跑
      此前可行，535fb153c7 binary 待复验）
