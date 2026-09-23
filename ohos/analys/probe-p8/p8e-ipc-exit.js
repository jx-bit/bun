// p8e — IPC 退出消息（bake/plugins harness 的 proc.send({type:"exit"}) 路径）
// 父发 {type:"exit"} → 子进程应 process.exit(0) → exited 及时 resolve
const t0 = Date.now();
let resolveExited;
const exited = new Promise(r => (resolveExited = r));
const p = Bun.spawn([process.execPath, "-e", `
  process.on("message", m => { if (m && m.type === "exit") process.exit(0); });
  console.log("ipc-ready");
`], {
  stdout: "pipe", stderr: "pipe", stdin: "ignore",
  ipc: message => { if (message === "ready") p.send({ type: "exit" }); },
});
p.exited.then(c => resolveExited(c));
let out = "";
p.stdout?.on?.("data", d => (out += d));
const race = await Promise.race([exited.then(() => "exited"), Bun.sleep(8000).then(() => "HANG")]);
const ms = Date.now() - t0;
console.log(`p8e: ${race} in=${ms}ms -> ${race === "exited" && ms < 8000 ? "PASS" : "FAIL"}`);
try { p.kill(); } catch {}
