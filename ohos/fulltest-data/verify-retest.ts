// 复测对账：新 fulltest 结果 × 0e0fd1559 基线
//
// 用法：bun ohos/fulltest-data/verify-retest.ts <新result_fulltest_*.txt> <旧lists目录>
//   旧lists目录 = 20260911_fulltest_official-v140-jxbit-0e0fd1559.zip 解包后的 lists/
//   （含 fail_0e0fd1559.txt 全量失败189 与 fail_0e0fd1559_only.txt jxbit独有39）
//
// 基线一律从真实清单文件读取（不内置转录副本）；预期转绿集 = jxbit39 − PARKED
// 程序推导，唯一人工输入是 PARKED（暂不投入修复、不纳入预期的项）。

import { readFileSync, existsSync } from "node:fs";

const [resultPath, listsDir] = process.argv.slice(2);
if (!resultPath || !listsDir || !existsSync(resultPath) || !existsSync(listsDir)) {
  console.error("usage: bun verify-retest.ts <result_fulltest_*.txt> <old-lists-dir>");
  process.exit(1);
}

const readList = (p: string) => readFileSync(p, "utf8").trim().split("\n").filter(Boolean);

const baselineFail = new Set(readList(`${listsDir}/fail_0e0fd1559.txt`));
const jxbitOnly = new Set(readList(`${listsDir}/fail_0e0fd1559_only.txt`));

// PARKED：本轮明确不投入、不纳入预期的项（其余 39 项全部预期转绿）
// - bun-write: blob/Body 与 A 零差异无锚点，待设备日志
// - expo: 第三方长跑集成
// - verdaccio 命中 4 项：本地 registry 被外部 SIGKILL（环境/基建），二进制修复无法保证
const PARKED = new Set(`
test/js/bun/io/bun-write.test.js
test/integration/expo-app/expo.test.ts
test/cli/install/bun-add-catalog.test.ts
test/cli/install/bun-audit.test.ts
test/cli/install/bun-update-lockfile-sync.test.ts
test/cli/update_interactive_formatting.test.ts
`
  .trim()
  .split("\n"));

const badParked = [...PARKED].filter((f) => !jxbitOnly.has(f));
if (badParked.length) {
  console.error("PARKED 中有不在 jxbit39 基线里的项（检查文件名）:", badParked);
  process.exit(1);
}
const expectedGreen = new Set([...jxbitOnly].filter((f) => !PARKED.has(f)));

// ── 解析新结果 ─────────────────────────────────────────────────────────
const results = new Map<string, string>();
for (const line of readFileSync(resultPath, "utf8").split("\n")) {
  const m = line.match(/\] (PASS|FAIL|TIMEOUT) [\d.]+s (\S+) \(cases/);
  if (m) results.set(m[2], m[1]);
}
if (results.size === 0) {
  console.error("no per-file results found — is this the result_fulltest_*.txt?");
  process.exit(1);
}

const fixed: string[] = [];
const residualJxbit: string[] = [];
const residualOverlap: string[] = [];
const newRegression: string[] = [];

for (const [file, r] of results) {
  const wasFail = baselineFail.has(file);
  const nowFail = r !== "PASS";
  if (!wasFail && nowFail) newRegression.push(file);
  else if (wasFail && !nowFail) fixed.push(file);
  else if (wasFail && nowFail) {
    (jxbitOnly.has(file) ? residualJxbit : residualOverlap).push(file);
  }
}

console.log(`files parsed: ${results.size} | baseline fail: ${baselineFail.size} | jxbit-only: ${jxbitOnly.size}`);
console.log(`\n== FIXED（基线挂 → 现在过）: ${fixed.length}`);
for (const f of fixed.sort()) {
  console.log(`  ${expectedGreen.has(f) ? "✓预期" : "☆超预期"} ${f}`);
}
const missed = [...expectedGreen].filter((f) => (results.get(f) ?? "MISSING") !== "PASS");
console.log(`\n== 预期转绿未兑现: ${missed.length}`);
for (const f of missed.sort()) console.log(`  ✗ ${f} [${results.get(f) ?? "不在结果中"}]`);
const parkedNow = [...PARKED].filter((f) => results.get(f) === "PASS");
console.log(`\n== PARKED 项转绿（超预期，回收投入）: ${parkedNow.length}`);
for (const f of parkedNow.sort()) console.log(`  ☆ ${f}`);
console.log(`\n== RESIDUAL jxbit-only: ${residualJxbit.length}`);
for (const f of residualJxbit.sort()) console.log(`  • ${f} [${results.get(f)}]`);
console.log(`\n== RESIDUAL overlap（环境基线）: ${residualOverlap.length}`);
for (const f of residualOverlap.sort()) console.log(`  · ${f} [${results.get(f)}]`);
console.log(`\n== NEW-REGRESSION（基线过 → 现在挂）: ${newRegression.length}`);
for (const f of newRegression.sort()) console.log(`  ‼ ${f} [${results.get(f)}]`);
