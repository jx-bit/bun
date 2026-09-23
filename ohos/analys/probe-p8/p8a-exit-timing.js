// p8a — 最小子进程退出时序：spawn → 子进程应 <2s 自然退出
// PASS: <2000ms 且 exit 0；FAIL/HANG: 挂起或 >10s
const t0 = Date.now();
const p = Bun.spawn([process.execPath, "-e", "console.log('child-ok')"], {
  stdout: "pipe", stderr: "pipe", stdin: "ignore",
});
const out = await new Response(p.stdout).text();
const code = await p.exited;
const ms = Date.now() - t0;
console.log(`p8a: exit=${code} in=${ms}ms out=${JSON.stringify(out)} -> ${code === 0 && ms < 10000 ? "PASS" : "FAIL"}`);
