import { CString, dlopen, FFIType } from "bun:ffi";
import { jscDescribe } from "bun:jsc";
import { expect, test } from "bun:test";
import { join } from "node:path";
import { isLinux } from "../../../harness";

// Only runs on Linux because that is where we can most reliably allocate a 32-bit pointer.
// addr32.c's mmap(..., MAP_FIXED_NOREPLACE, ...) loop (1MB-26MB range) fails
// every one of its 400 attempts on OHOS/HongMeng — verified with a standalone
// C repro (mmap returns MAP_FAILED for all tries) — so symbols.addr32()
// returns a NULL pointer there instead of a low address. This is a genuine
// kernel memory-layout difference, not a bun/FFI bug; harness.ts's isLinux
// intentionally includes openharmony for most purposes, so skip just here.
test.skipIf(!isLinux || process.platform === "openharmony")("can use addresses encoded as int32s", async () => {
  const compiler = Bun.spawn(["cc", "-shared", "-o", "libaddr32.so", "addr32.c"], {
    cwd: __dirname,
  });
  await compiler.exited;
  expect(compiler.exitCode).toBe(0);

  const { symbols } = dlopen(join(__dirname, "libaddr32.so"), { addr32: { args: [], returns: FFIType.pointer } });
  const addr = symbols.addr32()!;
  expect(addr).toBeGreaterThan(0);
  expect(addr).toBeLessThan(2 ** 31);
  const addrIntEncoded = addr | 0;
  expect(jscDescribe(addrIntEncoded)).toContain("Int32");
  // @ts-expect-error
  expect(new CString(addrIntEncoded).toString()).toBe("hello world");
});
