import { expect, test } from "bun:test";
import fs from "fs";
import { bunExe, bunEnv as env, isASAN, tmpdirSync } from "harness";
import path from "path";

const ASAN_MULTIPLIER = isASAN ? 3 : 1;
// This build routinely takes 110-120s on OHOS, right at the edge of the
// 120s budget below — any system jitter tips it into a timeout even though
// the build itself succeeds (verified: 116.69s wall clock, 1 pass, 0 fail).
// 1.5x (180s) still wasn't enough on a later, more loaded run (180001ms).
const OHOS_MULTIPLIER = process.platform === "openharmony" ? 2 : 1;

test(
  "vite build works",
  async () => {
    const testDir = tmpdirSync();

    fs.cpSync(path.join(import.meta.dir, "the-test-app"), testDir, { recursive: true, force: true });

    const { exited: installExited } = Bun.spawn({
      cmd: [bunExe(), "install", "--ignore-scripts"],
      cwd: testDir,
      env,
    });

    expect(await installExited).toBe(0);

    if (process.platform === "openharmony") {
      // bun's install-time auto-sign pass (PackageInstaller.rs
      // ohos_sign_native_binaries) still misses some optional native
      // bindings in a dependency tree this large — verified against a
      // build with the destination_dir-based path fix in place (see this
      // repo's PackageInstaller.rs history): that fix covers the isolated
      // .bun-store case, but @rollup/rollup-openharmony-arm64 here lands at
      // a perfectly flat, non-isolated node_modules path and is *still*
      // left unsigned, so there's at least one more gap in that pass that
      // hasn't been root-caused yet. Sign both known-affected bindings
      // explicitly until that's tracked down.
      for (const binding of [
        "node_modules/@rolldown/binding-openharmony-arm64/rolldown-binding.openharmony-arm64.node",
        "node_modules/@rollup/rollup-openharmony-arm64/rollup.openharmony-arm64.node",
      ]) {
        const p = path.join(testDir, binding);
        if (fs.existsSync(p)) {
          await Bun.$`binary-sign-tool sign -selfSign 1 -inFile ${p} -outFile ${p}.signed && cp ${p}.signed ${p} && chmod +x ${p}`;
        }
      }
    }

    const { stdout, stderr, exited } = Bun.spawn({
      cmd: [bunExe(), "node_modules/vite/bin/vite.js", "build"],
      cwd: testDir,
      stdout: "pipe",
      stderr: "inherit",
      env,
    });

    expect(await exited).toBe(0);

    const out = await stdout.text();
    expect(out).toContain("done");
  },
  120_000 * ASAN_MULTIPLIER * OHOS_MULTIPLIER,
);
