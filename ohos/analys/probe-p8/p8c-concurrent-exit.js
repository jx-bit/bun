// p8c — 并发 5 子进程全部退出（multi-run 形态）
const t0 = Date.now();
const procs = Array.from({ length: 5 }, (_, i) =>
  Bun.spawn([process.execPath, "-e", `console.log('c${i}')`], { stdout: "pipe", stdin: "ignore" }));
const outs = await Promise.all(procs.map(p => new Response(p.stdout).text()));
const codes = await Promise.all(procs.map(p => p.exited));
const ms = Date.now() - t0;
const ok = codes.every(c => c === 0) && outs.every((o, i) => o.includes(`c${i}`));
console.log(`p8c: codes=${codes.join(",")} in=${ms}ms -> ${ok && ms < 15000 ? "PASS" : "FAIL"}`);
