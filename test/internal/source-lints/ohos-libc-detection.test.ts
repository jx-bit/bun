import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import path from "node:path";

// Guards for the OHOS libc detection work.
//
// `aarch64-linux-ohos` is a musl target, but IS_MUSL only matched
// target_env = "musl", so three call sites were all wrong for OHOS:
// bun upgrade built its download asset name with an empty ABI suffix
// (pointing at the official glibc archive -- downloading it would brick the
// install), `bun build --compile` tagged the embedded target metadata as
// glibc, and the NAPI glibc-dependency precheck was skipped on device.
//
// This lint pins every load-bearing site of that fix so an upstream merge
// dropping any of them fails here instead of on a device fulltest round
// (precedent: pr51 lost getcwd_honest to an upstream merge).

const root = path.resolve(import.meta.dir, "..", "..", "..");
const read = (file: string) => readFileSync(path.join(root, file), "utf8");

test("env.rs: IS_MUSL covers the ohos target", () => {
  const src = read("src/bun_core/env.rs");
  expect(src).toContain('pub const IS_MUSL: bool = cfg!(any(target_env = "musl", target_env = "ohos"))');
});

test("env.rs: IS_OHOS / IS_GLIBC constants exist", () => {
  const src = read("src/bun_core/env.rs");
  expect(src).toContain('pub const IS_OHOS: bool = cfg!(target_env = "ohos")');
  expect(src).toContain('pub const IS_GLIBC: bool = IS_LINUX && cfg!(target_env = "gnu")');
});

test("upgrade_command.rs: SUFFIX_ABI checks IS_OHOS before android/musl", () => {
  const src = read("src/runtime/cli/upgrade_command.rs");
  const blockStart = src.indexOf("const SUFFIX_ABI");
  const blockEnd = src.indexOf("const SUFFIX:", blockStart);
  const block = src.slice(blockStart, blockEnd);
  // The order is load-bearing: IS_MUSL now covers ohos, so if IS_OHOS were
  // checked after IS_MUSL the device would land in the "-musl" branch
  // instead of "-ohos".
  const ohos = block.indexOf("IS_OHOS");
  expect(ohos, "SUFFIX_ABI must special-case IS_OHOS").toBeGreaterThanOrEqual(0);
  expect(block, 'SUFFIX_ABI must emit "-ohos"').toContain('"-ohos"');
  expect(ohos < block.indexOf("IS_MUSL")).toBe(true);
});

test("compile_target.rs: Libc::Ohos variant wired through all match sites", () => {
  const src = read("src/options_types/compile_target.rs");
  // enum variant
  expect(src, "Libc enum must declare Ohos").toMatch(/Android,\s*\n\s*\/\/\/ HarmonyOS \(OHOS\)[^\n]*\n\s*Ohos,/);
  // default host target on OHOS
  expect(src).toContain("libc: if Environment::IS_OHOS {\n                Libc::Ohos");
  // npm/package name suffix
  expect(src).toContain('Libc::Ohos => "-ohos"');
  // --target=...-ohos parsing
  expect(src).toContain('token == b"ohos"');
  // unsupported-token whitelist (the error message can name ohos)
  expect(src).toContain('token != b"ohos"');
  // process.platform inlined into compiled output
  expect(src).toContain('Libc::Ohos => b"\\"openharmony\\""');
});

test("libc_check.rs: NAPI glibc precheck stays keyed on IS_MUSL", () => {
  const src = read("src/runtime/napi/libc_check.rs");
  const fn = src.slice(src.indexOf("fn check_enabled"), src.indexOf("fn elf_glibc_needed"));
  expect(
    fn,
    "check_enabled must keep IS_MUSL in its gate: the IS_MUSL widening (ohos) is what enables the NAPI glibc precheck on device",
  ).toContain("Environment::IS_MUSL");
});
