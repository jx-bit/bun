# OHOS Bun 全量测试工具(launcher + runner)

对 ljy9812/bun 构建的 OHOS aarch64 版 Bun 在鸿蒙设备上跑完整 test suite 的工具集。
新人从 clone 到出报告的完整流程见本目录 `OHOS-Bun-全量测试指导.md`,
最新一轮测试结果分析见 `bun-test-report-latest.md`,本 README 只覆盖脚本的部署与启动。

## 文件说明

| 文件 | 作用 |
|---|---|
| `launch-fulltest.sh` | 启动器(推荐入口):固化全部测试 env(PARALLEL/RETRIES/超时/语义 flag),前置校验后 `exec` runner。**必须经它启动**,直接跑 runner 会漏设语义 flag 导致结果失真 |
| `launch-fulltest-sh.sh` | 同上的 sh 兼容版,设备没有 bash 时用 |
| `run-all-official-progress-optimized.sh` | runner(执行引擎):per-file 执行 + setsid/PGID 看门狗 + 超时/崩溃区分 + OPENHARMONY expectations 排除 + 孤儿清理 + 汇总报告 |
| `deploy-test-tree.sh` | 测试树部署(宿主机 Git Bash 执行):发 tar → 备份旧树(含 node_modules)→ 解新树 → 挪回 node_modules |

## 快速使用

```bash
# 0) 前提:binary 已部署在 $DEVROOT/bun-aclass(chmod 755),
#    测试树已解包到 $DEVROOT/test/(含 node_modules)

DEVROOT=/storage/media/100/local/files/Docs/Desktop/Linux

# 1) 把脚本发到设备
hdc file send ohos/fulltest/launch-fulltest.sh           "$DEVROOT/"
hdc file send ohos/fulltest/launch-fulltest-sh.sh        "$DEVROOT/"
hdc file send ohos/fulltest/run-all-official-progress-optimized.sh "$DEVROOT/"
hdc shell "chmod 755 $DEVROOT/*.sh $DEVROOT/run-all-official-progress-optimized.sh"

# 2) 启动(在宿主机 Git Bash 执行;注意末尾的 & 在宿主机侧——hdc 会阻塞等 stdout
#    关闭,宿主机不放后台这条命令会一直挂着。全量约 3~6 小时)
hdc shell "cd $DEVROOT && setsid bash launch-fulltest.sh > result_fulltest_\$(date +%Y%m%d_%H%M%S).txt 2>&1 &" &
# 设备无 bash 时:
# hdc shell "cd $DEVROOT && setsid sh launch-fulltest-sh.sh > result_fulltest_\$(date +%Y%m%d_%H%M%S).txt 2>&1 &" &

# 3) 产出两份文件
#    $DEVROOT/result_fulltest_<ts>.txt          进度 + per-file 结果(看汇总)
#    $DEVROOT/all-official-report-<ts>.txt      每文件原始输出 + EXIT_CODE(诊断用)
```

## 固化参数(勿改,改了跨轮数据不可比)

`PARALLEL=2`(3 并发在 leak 类文件同时命中时 OOM 死锁)、`RETRIES=2`、
`BUN_FEATURE_FLAG_INTERNAL_FOR_TESTING=1` + `BUN_GARBAGE_COLLECTOR_LEVEL=0`
(嵌套 gate,缺失时 ~181 个用例假失败)、`GITHUB_ACTIONS=false`、`HOME=$DEVROOT/home`
(设备 root 无 /root)。完整理由见指导文档 §8。

## 口径提醒

- **用例率 = CP / (CP+CF)**;超时文件的用例剔出分母、崩溃文件保留 partial——跨轮对比必须同时看超时数;
- 对比基准必须同条件:同测试树 commit + 同 node_modules + 同 PARALLEL/RETRIES + 同排除规则。
