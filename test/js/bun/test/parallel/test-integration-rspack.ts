import { expect } from "bun:test";
import { bunEnv, bunExe, isOHOS, tmpdirSync } from "harness";
import { join } from "path";

const cwd = tmpdirSync();
console.log([0, cwd]);

let proc = Bun.spawn({
  // Pinned: rsbuild 2.0.x bundles mimalloc v3 inside @rspack/binding-win32-arm64-msvc.
  // Two static mimalloc instances in one process deterministically segfault in ntdll
  // during ExitProcess on Windows arm64 (FLS / process-detach cleanup). Tracked
  // separately; this test exists to guard the napi TSFN finalizer, not rsbuild HEAD.
  cmd: [bunExe(), "create", "rsbuild@1", "app", "--template", "solid-ts"],
  stdio: ["ignore", "inherit", "inherit"],
  cwd,
  env: bunEnv,
});
await proc.exited;
console.log([1]);
expect(proc.signalCode).toBeNull();
expect(proc.exitCode).toBe(0);

if (isOHOS) {
  // rsbuild@1 pulls @rspack/core ~1.7.10, whose upstream @rspack/binding has no
  // OHOS build. The community port @ohos-ports/rspack-binding is a native
  // (real-machine verified) OHOS build of the 1.7.11 release; the scaffolded
  // app's own package.json has no override slot, so patch one in before install.
  // @rspack/core must be pinned to the exact matching 1.7.11 too -- rspack's
  // own runtime check rejects a core/binding version mismatch (the `~1.7.10`
  // range otherwise floats core up to whatever newer 1.7.x patch is current).
  const pkgPath = join(cwd, "app", "package.json");
  const pkg = await Bun.file(pkgPath).json();
  pkg.resolutions = {
    ...pkg.resolutions,
    "@rspack/core": "1.7.11",
    "@rspack/binding": "npm:@ohos-ports/rspack-binding@1.7.11-beta.0",
  };
  await Bun.write(pkgPath, JSON.stringify(pkg, null, 2));
}

proc = Bun.spawn({
  cmd: [bunExe(), "install"],
  stdio: ["ignore", "inherit", "inherit"],
  cwd: join(cwd, "app"),
  env: bunEnv,
});
await proc.exited;
console.log([2]);
expect(proc.signalCode).toBeNull();
expect(proc.exitCode).toBe(0);

proc = Bun.spawn({
  cmd: [bunExe(), "--bun", "run", "build"],
  stdio: ["ignore", "inherit", "inherit"],
  cwd: join(cwd, "app"),
  env: bunEnv,
});
await proc.exited;
console.log([3]);
expect(proc.signalCode).toBeNull();
expect(proc.exitCode).toBe(0);
