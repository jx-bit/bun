// p8d — 孙进程持有继承 fd 时父进程的退出检测（孤儿 fd 继承面）
// 子进程再 spawn 一个 5s 的孙进程后立即退出；父进程的 exited 仍应及时 resolve
const t0 = Date.now();
const p = Bun.spawn([process.execPath, "-e", `
  const g = Bun.spawn([process.execPath, "-e", "setTimeout(()=>{}, 5000)"], { stdout: "ignore", stdin: "ignore" });
  console.log("child ok, grandchild", g.pid);
`], { stdout: "pipe", stderr: "pipe", stdin: "ignore" });
const out = await new Response(p.stdout).text();
const code = await p.exited;
const ms = Date.now() - t0;
console.log(`p8d: exit=${code} in=${ms}ms out=${JSON.stringify(out.slice(0, 40))} -> ${code === 0 && ms < 10000 ? "PASS" : "FAIL"}`);
