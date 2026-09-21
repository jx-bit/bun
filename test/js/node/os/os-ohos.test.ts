import os from "node:os";
import { describe, expect, test } from "bun:test";
import { isOHOS } from "harness";

// Exact-value platform semantics for OHOS -- guards the problems the loose
// upstream assertions cannot catch:
//  - os.machine(): the upstream suite only asserts a 12-value membership
//    list (arm64 and aarch64 both pass), and the device reported "arm64"
//    where uname semantics say "aarch64" -- fixed by the os.machine PR
//  - process.platform: the source-lint pins the source branches; this pins
//    the runtime value
// The whole file is skipped outside OHOS; it must run in the device fulltest
// and is registered in test/internal/source-lints/ohos-skip-inventory.json.
describe.skipIf(!isOHOS)("OHOS platform semantics (exact values)", () => {
  test("process.platform === openharmony", () => {
    expect(process.platform).toBe("openharmony");
  });

  test("os.machine() = uname -m = aarch64 on arm64 devices", () => {
    // The device fleet is all aarch64; extend the assertion per-arch if an
    // x64 device ever joins.
    expect(process.arch).toBe("arm64");
    expect(os.machine()).toBe("aarch64");
  });

  test("os.type() = Linux (kernel semantics per Node)", () => {
    expect(os.type()).toBe("Linux");
  });

  test("os.userInfo() does not throw in-process (bun fallback baseline)", () => {
    // bun itself has the "unknown" fallback; the path that actually throws
    // is an exec'd node child, covered on device by
    // spawn-ohos-node-userinfo.test.ts.
    const info = os.userInfo();
    expect(info.username.length).toBeGreaterThan(0);
  });
});
