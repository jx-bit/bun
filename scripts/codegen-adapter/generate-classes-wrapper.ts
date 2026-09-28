// OHOS-line adapter (S4): the official 1.4.2 build graph invokes
// generate-classes.ts with a two-dir signature (<classes...> <outBase>
// <typesDir>), while the local 1.4.0 generator (kept for compatibility with
// the local C++ tree — the 1.4.2 generator emits C++ requiring 1.4.2 runtime
// infrastructure) takes a single outBase. This wrapper bridges the two and
// mirrors the .d.ts twin into typesDir. Revisit when the C++ tree upgrades
// to the 1.4.2 generator contract.
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const argv = process.argv.slice(2);
const typesDir = argv.pop();
const script = join(import.meta.dirname, "..", "..", "src", "codegen", "generate-classes.ts");

const r = spawnSync(process.execPath, [script, ...argv], { stdio: "inherit" });
if (r.status !== 0) process.exit(r.status ?? 1);

const outBase = argv[argv.length - 1];
const twin = join(outBase, "ZigGeneratedClasses.d.ts");
if (typesDir && existsSync(twin)) {
  mkdirSync(typesDir, { recursive: true });
  copyFileSync(twin, join(typesDir, "ZigGeneratedClasses.d.ts"));
}
