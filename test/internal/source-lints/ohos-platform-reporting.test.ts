import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import path from "node:path";

// `process.platform` has two independent sources of truth and PR #29
// (ff4f267b, Rust-side Global::os_name) fixed neither of them: the C++ getter
// (constructPlatform) and the bundle-time `--define process.platform=…` that
// TARGET_PLATFORM feeds (os.platform() is that literal after DCE), so OHOS
// builds kept reporting "linux".
//
// OHOS triples (aarch64-unknown-linux-ohos) define BOTH __OHOS__ and
// __linux__, so the C++ branch order is load-bearing, and WebKit has no
// OS(OPENHARMONY), so create-hash-table.ts must map the target back to LINUX.
// This lint pins every piece so a merge that drops one fails CI here instead
// of on a device fulltest.

const root = path.resolve(import.meta.dir, "..", "..", "..");

const read = (file: string) => readFileSync(path.join(root, file), "utf8");

test("constructPlatform reports openharmony on OHOS, above the linux branch", () => {
  const src = read("src/jsc/bindings/BunProcess.cpp");
  const fn = src.slice(
    src.indexOf("static JSValue constructPlatform"),
    src.indexOf("static JSValue constructVersions"),
  );
  const ohos = fn.indexOf("__OHOS__");
  const linux = fn.indexOf("__linux__");
  expect(ohos, "constructPlatform must handle __OHOS__").toBeGreaterThanOrEqual(0);
  expect(fn, 'constructPlatform must return "openharmony"').toContain('"openharmony"_s');
  expect(
    ohos < linux,
    "__OHOS__ branch must stay above __linux__: OHOS triples define both macros, so a branch below __linux__ is dead code and process.platform silently regresses to linux",
  ).toBe(true);
});

test("codegenTarget feeds openharmony as TARGET_PLATFORM for ohos builds", () => {
  const src = read("scripts/build/codegen.ts");
  const fn = src.slice(src.indexOf("function codegenTarget"), src.indexOf("export function registerCodegenRules"));
  const ohos = fn.indexOf("cfg.ohos");
  expect(ohos, "codegenTarget must special-case ohos").toBeGreaterThanOrEqual(0);
  expect(
    fn.indexOf('"openharmony"'),
    "ohos builds must inline process.platform as openharmony (os.platform() is this literal after DCE)",
  ).toBeGreaterThan(ohos);
});

test("create-hash-table maps openharmony back to LINUX for OS() preprocessing", () => {
  const src = read("src/codegen/create-hash-table.ts");
  expect(src).toContain('platform === "openharmony" ? "LINUX"');
});

test("os.type() maps openharmony to Linux", () => {
  const src = read("src/js/node/os.ts");
  expect(src, 'without this branch the OHOS bundle keeps @bundleError("TODO: type") and codegen fails').toMatch(
    /process\.platform === "openharmony"\s*\?\s*"Linux"/,
  );
});

test("net.ts keeps Linux-kernel semantics for openharmony", () => {
  const src = read("src/js/node/net.ts");
  expect(src, "ECONNRESET is errno 104 on the Linux kernel OHOS runs").toMatch(
    /process\.platform === "linux" \|\| process\.platform === "openharmony"\s*\?\s*-104/,
  );
  expect(src, "OHOS supports abstract unix sockets").toMatch(
    /process\.platform === "linux" \|\| process\.platform === "android" \|\| process\.platform === "openharmony";/,
  );
});
