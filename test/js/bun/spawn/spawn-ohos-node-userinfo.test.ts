import { $ } from "bun";
import { describe, expect, test } from "bun:test";
import { execFileSync } from "child_process";
import { existsSync, unlinkSync } from "fs";
import { bunEnv, isOHOS, nodeExe } from "harness";

// src/runtime/api/bun/ohos_node_userinfo.rs: an exec'd node child gets the
// real musl libc (not the ohos-compat-shim symbols linked into bun itself),
// so os.userInfo() throws ERR_SYSTEM_ERROR (uv_os_get_passwd -> ENOENT) for
// HarmonyOS app-sandbox uids. Bun.spawn/node:child_process/the shell
// interpreter transparently inject a `--require` preload via NODE_OPTIONS to
// fix this without any change on the spawned tool's side.
const node = nodeExe();

describe.skipIf(!isOHOS || !node)("os.userInfo() for a bun-spawned node child (OHOS)", () => {
  // $USER/$LOGNAME/$NODE_OPTIONS are cleared so every test starts from a
  // known baseline instead of whatever this dev machine's shell profile set
  // (bunEnv deliberately does not clear these -- see harness.ts).
  const cleanEnv = { ...bunEnv, USER: undefined, LOGNAME: undefined, NODE_OPTIONS: undefined };
  // Captured before clearing: ask the OS-account NDK directly via ffi. The
  // parent bun's own os.userInfo() can't serve as ground truth — the
  // embedded shim's dlopen("libos_account_ndk.so") fails under the OHOS
  // dlopen namespace isolation, so bun falls back to $USER which may
  // disagree with the account name in agent/CI shells (e.g. USER=100),
  // while the spawned node child's preload shim resolves the real name.
  const groundTruth = (() => {
    try {
      const { dlopen, FFIType, ptr } = require("bun:ffi");
      const buf = new Uint8Array(256);
      const lib = dlopen("libos_account_ndk.so", {
        OH_OsAccount_GetName: { args: [FFIType.ptr, FFIType.u64], returns: FFIType.i32 },
      });
      if (lib.symbols.OH_OsAccount_GetName(ptr(buf), 256) !== 0) return undefined;
      const name = Buffer.from(buf.subarray(0, buf.indexOf(0))).toString();
      return name || undefined;
    } catch {
      return undefined;
    }
  })();

  const userInfoScript =
    "try { console.log(JSON.stringify(require('os').userInfo())); }" +
    " catch (e) { console.log('THROW:' + e.code); }";

  test("node child does not throw and gets a non-placeholder username", () => {
    const out = execFileSync(node!, ["-e", userInfoScript], { env: cleanEnv }).toString().trim();
    expect(out.startsWith("THROW:")).toBe(false);
    const info = JSON.parse(out);
    expect(typeof info.username).toBe("string");
    expect(info.username.length).toBeGreaterThan(0);
    expect(info.username).not.toBe("unknown");
  });

  test.skipIf(!groundTruth)("username matches the shim-resolved ground truth", () => {
    const out = execFileSync(node!, ["-e", userInfoScript], { env: cleanEnv }).toString().trim();
    const info = JSON.parse(out);
    expect(info.username).toBe(groundTruth);
  });

  test("NODE_OPTIONS is merged, not clobbered, and the caller's value stays first", () => {
    const env = { ...cleanEnv, NODE_OPTIONS: "--max-old-space-size=256" };
    const out = execFileSync(node!, ["-p", "process.env.NODE_OPTIONS"], { env }).toString().trim();
    expect(out.startsWith("--max-old-space-size=256")).toBe(true);
    expect(out).toContain("--require");
  });

  test("non-node spawn targets get zero injection", () => {
    const out = execFileSync("/bin/sh", ["-c", "echo [$NODE_OPTIONS]"], { env: cleanEnv }).toString().trim();
    expect(out).toBe("[]");
  });

  test("node spawning node does not duplicate --require", () => {
    const script =
      "const { execFileSync } = require('child_process');" +
      `const out = execFileSync(${JSON.stringify(node)}, ['-p', 'process.env.NODE_OPTIONS'], { env: process.env });` +
      "console.log(out.toString());";
    const out = execFileSync(node!, ["-e", script], { env: cleanEnv }).toString();
    const count = (out.match(/--require/g) || []).length;
    expect(count).toBe(1);
  });

  test("deleting the preload file self-heals on the next spawn", () => {
    const first = execFileSync(node!, ["-p", "process.env.NODE_OPTIONS"], { env: cleanEnv }).toString().trim();
    const match = first.match(/--require\s+"([^"]+)"/);
    expect(match).not.toBeNull();
    const preloadPath = match![1];
    expect(existsSync(preloadPath)).toBe(true);

    unlinkSync(preloadPath);
    expect(existsSync(preloadPath)).toBe(false);

    const out = execFileSync(node!, ["-e", userInfoScript], { env: cleanEnv }).toString().trim();
    expect(out.startsWith("THROW:")).toBe(false);
    expect(existsSync(preloadPath)).toBe(true);
  });

  test("Bun.spawn and node:child_process agree (same injection point)", async () => {
    await using proc = Bun.spawn({ cmd: [node!, "-e", userInfoScript], env: cleanEnv, stdout: "pipe" });
    const viaSpawnOut = (await proc.stdout.text()).trim();
    expect(viaSpawnOut.startsWith("THROW:")).toBe(false);

    const viaChildProcessOut = execFileSync(node!, ["-e", userInfoScript], { env: cleanEnv }).toString().trim();
    expect(viaChildProcessOut.startsWith("THROW:")).toBe(false);

    expect(JSON.parse(viaSpawnOut).username).toBe(JSON.parse(viaChildProcessOut).username);
  });

  test("Bun.$ (shell interpreter) spawning node also gets the injection", async () => {
    const out = (await $`${node!} -e ${userInfoScript}`.env(cleanEnv).text()).trim();
    expect(out.startsWith("THROW:")).toBe(false);
    expect(JSON.parse(out).username).not.toBe("unknown");
  });

  // Reverse check: with the escape hatch on, node's real ENOENT should
  // surface again. In a container where the sandbox uid happens to resolve
  // via /etc/passwd this won't reproduce -- assert "no injection" instead,
  // which is the actually-guaranteed half of the contract everywhere.
  test("BUN_OHOS_NO_NODE_USERINFO disables the injection", () => {
    const env = { ...cleanEnv, BUN_OHOS_NO_NODE_USERINFO: "1" };
    const out = execFileSync(node!, ["-p", "process.env.NODE_OPTIONS || ''"], { env }).toString().trim();
    expect(out).not.toContain("--require");
  });
});
