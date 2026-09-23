# 探针 p8 套件 — 子进程退出/生命周期定位（设备侧执行）

> 目标：plugins 子进程被 SIGTERM（挂死后看门狗击杀）、verdaccio 忙旋（F4）、
> 26286 挂起——"被 spawn 的子进程不退出"家族的分层定位。
> 方法：延续 p1~p7 的双 binary 对照法。每针 10~30 秒。
> A = social4hyq 1.4.0_80（对照）；B = jx-bit 最新构建。
> 运行：`bun p8*.js`（各探针独立，无依赖）。

## 实验矩阵（预期全 PASS；任何 FAIL/HANG 即定位一层）

| 探针 | 验证层 | 失败含义 |
|---|---|---|
| p8a | 最小子进程退出时序（async spawn + pipe） | 子进程自身的运行/退出路径挂 |
| p8b | stdin EOF 传播（父关写端 → 子进程见 EOF 退出） | 父/子 fd 生命周期：写端 dup 未关 → EOF 永不到达（fd 泄漏家族复发） |
| p8c | 并发 5 子进程全部退出 | 多子并发退出面 |
| p8d | 孙进程持有继承 fd 时父进程退出检测 | 孤儿 fd 继承影响父进程的 wait |
| p8e | IPC 退出消息（bake/plugins harness 的 `proc.send({type:"exit"})`） | IPC 通道 → 子进程 exit(0) 链路 |
| p8f | spawnSync 128KB 输出回传 | SpawnSyncEventLoop 大管道面 |
| p8g | 进程组 SIGKILL 后子进程退出 | watchdog 杀组后的残留（verdaccio 忙旋 F4 的最小化复现）|

## 判定树

```
p8a FAIL → 子进程自身挂（runtime/启动路径）→ 修 binary 子进程退出
p8b FAIL → stdin EOF 未传播 → fd 泄漏/关闭语义（#34 close_range 回归检查）
p8c FAIL → 并发退出面（与 p8a 单发对照定位）
p8d FAIL → 孤儿 fd 继承 → process.rs 的 wait/隔离逻辑
p8e FAIL → IPC 链路 → bake/plugins harness 的根因层
p8f FAIL → SpawnSyncEventLoop 大输出（与 p1 的 pipe 读区分）
p8g FAIL → watchdog 杀组后子进程残留 → F4（verdaccio 忙旋）根因层
```

## 双 binary 对照运行脚本

```bash
# run-p8.sh — 对 A/B 两个 binary 依次跑全套，输出矩阵
A=${A:-/path/to/sys-release-bun}
B=${B:-/path/to/jxbit-bun}
for BIN in "$A" "$B"; do
  echo "===== $BIN ====="
  for probe in p8a-exit-timing p8b-stdin-eof p8c-concurrent-exit p8d-grandchild-fd p8e-ipc-exit p8f-sync-large p8g-process-group-kill; do
    timeout 30 "$BIN" "$probe.js" 2>&1 | tail -1
  done
done
```

## 结果回填

跑完把两个 binary 的 7 行输出贴回（标注 A/B），按判定树出修复 PR。
