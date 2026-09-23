// p8f — spawnSync 大输出（128KB 管道回传，SpawnSyncEventLoop 面）
const t0 = Date.now();
const big = "x".repeat(128 * 1024);
const r = Bun.spawnSync([process.execPath, "-e", `process.stdout.write("${big}")`], { stdout: "pipe" });
const ms = Date.now() - t0;
const ok = r.exitCode === 0 && r.stdout.toString().length === 128 * 1024;
console.log(`p8f: exit=${r.exitCode} len=${r.stdout.toString().length} in=${ms}ms -> ${ok && ms < 15000 ? "PASS" : "FAIL"}`);
