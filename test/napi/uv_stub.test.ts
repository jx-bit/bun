import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { bunEnv, bunExe, isASAN, isWindows, makeTree, tempDirWithFiles } from "harness";
import path from "node:path";
import { symbols, test_skipped } from "../../src/jsc/bindings/libuv/generate_uv_posix_stubs_constants";
import goodSource from "./uv-stub-stuff/good_plugin.c";
import source from "./uv-stub-stuff/plugin.c";

const all_symbols_to_test = symbols.filter(s => !test_skipped.includes(s));
// Each per-symbol test spawns a fresh bun subprocess that aborts in the stub.
// Under asan, process startup is ~2.3s and the CI agent exposes 2 vCPUs, so
// the full ~294-symbol set is ~11 minutes of CPU-bound work regardless of
// concurrency and overruns the file timeout. All stubs route through the
// same CrashHandler__unsupportedUVFunction formatter, so a strided sample
// exercises the mechanism on asan while every non-asan lane still runs the
// full set.
//
// OpenHarmony is sampled for the same reason, though it fails a different
// way: not the file timeout, but the per-test one. These are test.concurrent,
// so all ~295 timers start together while the spawns retire at whatever rate
// the container manages. Two runs, one inside the full suite (30179934099)
// and one with this file essentially alone (30184734535), landed on the same
// numbers — 279 pass, 16 fail, 152.52s and 153.92s — so the losses are not
// contention with the rest of the suite; this file alone cannot retire 295
// subprocesses inside one 150s window.
//
// The 16 that lose are a prefix of declaration order, and the two runs shared
// 15 of them with the boundary moving by exactly one symbol
// (uv_cond_broadcast vs uv_clock_gettime). A contiguous prefix with a wobbling
// edge is a scheduling artifact, not a property of those symbols, so nothing
// OHOS-specific is broken in the stubs themselves. The stride keeps 3 of the
// 16 (uv_accept, uv_barrier_destroy, uv_check_init), so if that ever stops
// being true the sample still catches it.
const isSlowSpawnLane = isASAN || process.platform === "openharmony";
const symbols_to_test = isSlowSpawnLane ? all_symbols_to_test.filter((_, i) => i % 6 === 0) : all_symbols_to_test;

// We use libuv on Windows
describe.if(!isWindows)("uv stubs", () => {
  const cwd = process.cwd();
  let tempdir: string = "";
  let outdir: string = "";

  beforeAll(async () => {
    const files = {
      "plugin.c": await Bun.file(source).text(),
      "good_plugin.c": await Bun.file(goodSource).text(),
      "package.json": JSON.stringify({
        "name": "fake-plugin",
        "module": "index.ts",
        "type": "module",
        "devDependencies": {
          "@types/bun": "latest",
        },
        "peerDependencies": {
          "typescript": "^5.0.0",
        },
        "scripts": {
          "build:napi": "node-gyp configure && node-gyp build",
        },
        "dependencies": {
          "node-gyp": "10.2.0",
        },
      }),
      "index.ts": `const symbol = process.argv[2]; const foo = require("./build/Release/xXx123_foo_counter_321xXx.node"); foo.callUVFunc(symbol)`,
      "nocrash.ts": `const foo = require("./build/Release/good_plugin.node");console.log('HI!')`,
      "binding.gyp": `{
  "targets": [
    {
      "target_name": "xXx123_foo_counter_321xXx",
      "sources": [ "plugin.c" ],
      "include_dirs": [ ".", "./libuv" ],
      "cflags": ["-fPIC"],
      "ldflags": ["-Wl,--export-dynamic"]
    },
    {
      "target_name": "good_plugin",
      "sources": [ "good_plugin.c" ],
      "include_dirs": [ ".", "./libuv" ],
      "cflags": ["-fPIC"],
      "ldflags": ["-Wl,--export-dynamic"]
    }
  ]
}
`,
    };

    tempdir = tempDirWithFiles("native-plugins", files);

    await makeTree(tempdir, files);
    outdir = path.join(tempdir, "dist");

    process.chdir(tempdir);

    const libuvDir = path.join(__dirname, "../../src/jsc/bindings/libuv");
    await Bun.$`cp -R ${libuvDir} ${path.join(tempdir, "libuv")}`;
    await Bun.$`${bunExe()} i && ${bunExe()} build:napi`.env(bunEnv).cwd(tempdir);

    if (process.platform === "openharmony") {
      // build:napi runs node-gyp as a generic package.json script, which never
      // goes through bun's own install/build pipeline — nothing signs the
      // resulting .node files, so dlopen later fails with EACCES.
      for (const addon of ["xXx123_foo_counter_321xXx", "good_plugin"]) {
        const built = path.join(tempdir, `build/Release/${addon}.node`);
        await Bun.$`binary-sign-tool sign -selfSign 1 -inFile ${built} -outFile ${built}.signed && cp ${built}.signed ${built} && chmod +x ${built}`;
      }
    }

    console.log("tempdir:", tempdir);
  });

  afterAll(() => {
    process.chdir(cwd);
  });

  // The bodies share no mutable state (tempdir is read-only after
  // beforeAll), so run them concurrently.
  for (const symbol of symbols_to_test) {
    test.concurrent(`unsupported: ${symbol}`, async () => {
      const { stderr } = await Bun.$`BUN_INTERNAL_SUPPRESS_CRASH_ON_UV_STUB=1 ${bunExe()} run index.ts ${symbol}`
        .cwd(tempdir)
        .throws(false)
        .quiet();
      const stderrStr = stderr.toString();
      expect(stderrStr).toContain("Bun encountered a crash when running a NAPI module that tried to call");
      expect(stderrStr).toContain(symbol);
    });
  }

  test("should not crash when calling supported uv functions", async () => {
    const { stdout, exitCode } = await Bun.$`${bunExe()} run nocrash.ts`.cwd(tempdir).throws(false).quiet();
    expect(exitCode).toBe(0);
    expect(stdout.toString()).toContain("HI!");
  });
});
