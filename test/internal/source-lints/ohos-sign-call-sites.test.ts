import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import path from "node:path";

// The OHOS codesign call sites are fork-private hunks inside functions that
// upstream also refactors. Upstream commit 46557185da ("Android: fix
// --compile executables (PIE load bias)") restructured
// StandaloneModuleGraph::inject() and a merge silently dropped the
// `#[cfg(target_env = "ohos")]` re-sign block — nothing failed until the
// 20260902 device fulltest, where 72 files (33% of failures) died with
// posix_spawn EACCES because `bun build --compile` outputs inherited a stale
// .codesign section from the signed stub.
//
// This lint pins each call site so a merge that loses one fails CI here
// instead of on a device three days later.

const root = path.resolve(import.meta.dir, "..", "..", "..");

const guard = (file: string, needle: string) => {
  const src = readFileSync(path.join(root, file), "utf8");
  expect(
    src.includes(needle),
    `${file} must keep \`${needle}\` — the OHOS kernel refuses to exec/dlopen ELFs whose .codesign section is missing or stale, and this call site is what repairs that. If a refactor moved the code, update this lint in the same PR; if a merge dropped it, re-apply the hunk (see ohos/analys/issues/p1-codesign-stub-inheritance.md).`,
  );
};

test("OHOS codesign call sites survive upstream merges", () => {
  // compile path: the payload-expanded output must be stripped and re-signed
  // at write time (dropped by 46557185da, restored by 88a237b0e3).
  guard("src/standalone_graph/StandaloneModuleGraph.rs", "ohos_sign::sign_selfsign_with_strip");

  // spawn path: kernel refusal (EACCES/EPERM) triggers a lazy repair + single
  // retry — never an eager per-spawn validation (it re-hashes the ~100 MB
  // binary and doubled the 20260903 fulltest wall time).
  guard("src/spawn_sys/spawn_process.rs", "ohos_sign::repair_codesign_if_needed");

  // dlopen path: same lazy-repair contract as spawn.
  guard("src/sys/lib.rs", "ohos_sign::repair_codesign_if_needed");

  // install path: native modules (.so/.node) repaired at install time.
  guard("src/install/PackageInstaller.rs", "ohos_sign::repair_codesign_if_needed");
});

test("OHOS userspace shebang expansion survives upstream merges", () => {
  // Text scripts cannot carry a .codesign section, so the kernel refuses to
  // exec them. The spawn path rewrites `#!` targets to their (signed)
  // interpreter — without this, every direct script spawn fails with
  // EACCES/EPERM on device.
  guard("src/spawn_sys/spawn_process.rs", "ohos_expand_shebang(argv0_cstr, argv)");
  guard("src/spawn_sys/shebang.rs", "pub(crate) fn parse_shebang");
});
