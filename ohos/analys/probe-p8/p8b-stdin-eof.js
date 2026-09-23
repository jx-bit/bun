// p8b — stdin EOF 传播：父写 5 字节后关闭写端，子进程读到 EOF 应退出
// FAIL/HANG: 子进程等不到 EOF（父侧写端 dup 未关/泄漏）
const t0 = Date.now();
const p = Bun.spawn([process.execPath, "-e", "const s = await Bun.stdin.text(); console.log('stdin-bytes:', s.length)"], {
  stdin: "pipe", stdout: "pipe", stderr: "pipe",
});
p.stdin.write("hello");
p.stdin.end();
const out = await new Response(p.stdout).text();
const code = await p.exited;
const ms = Date.now() - t0;
console.log(`p8b: exit=${code} in=${ms}ms out=${JSON.stringify(out)} -> ${code === 0 && out.includes("stdin-bytes: 5") && ms < 10000 ? "PASS" : "FAIL"}`);
