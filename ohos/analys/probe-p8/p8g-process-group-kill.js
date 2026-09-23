// p8g — 进程组 SIGKILL 后子进程应退出（verdaccio 忙旋 F4 场景）
// 父 bun spawn 一个 8s 的服务器型子进程（保持事件循环）→ 父随即退出；
// 外层再 spawn 一层以便对进程组发信号。判定：子进程 ≤5s 内退出（非忙旋残留）。
import { spawnSync } from "node:child_process";
const t0 = Date.now();
// setsid 起一组：组内一个长跑子进程
const g = Bun.spawn(["sh", "-c", `${process.execPath} -e "setInterval(()=>{},100)" & sleep 0.2; echo group-ready`],
  { stdout: "pipe", stderr: "pipe" });
await new Response(g.stdout).text();
// 杀整组（模拟 runner watchdog）
const killed = spawnSync("sh", ["-c", `pkill -TERM -g $(ps -o pgid= -p ${g.pid} | tr -d ' ') 2>/dev/null; sleep 3; pgrep -f "setInterval" >/dev/null && echo ALIVE || echo GONE`]);
const out = killed.stdout.toString().trim();
const ms = Date.now() - t0;
console.log(`p8g: ${out} in=${ms}ms -> ${out === "GONE" ? "PASS" : "FAIL"}`);
