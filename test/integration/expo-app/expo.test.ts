import { beforeAll, expect, setDefaultTimeout, test } from "bun:test";
import fs from "fs/promises";
import { bunEnv, bunExe, tmpdirSync } from "../../harness";

const tmpdir = tmpdirSync();

// setDefaultTimeout() only affects tests registered after it runs, and test()
// registration happens at module-parse time (before beforeAll ever executes)
// — so calling it inside beforeAll is too late to affect the test below. It
// must be called at the top level.
setDefaultTimeout(1000 * 60 * 4);

beforeAll(async () => {
  await fs.rm(tmpdir, { recursive: true, force: true });
  await fs.cp(import.meta.dir, tmpdir, { recursive: true, force: true });
});

test("expo export works (no ajv issues)", async () => {
  console.log({ tmpdir });
  let { exitCode } = Bun.spawnSync([bunExe(), "install"], {
    stderr: "inherit",
    stdout: "inherit",
    cwd: tmpdir,
    env: bunEnv,
  });
  expect(exitCode).toBe(0);

  ({ exitCode } = Bun.spawnSync([bunExe(), "run", "export"], {
    stdout: "inherit",
    stderr: "inherit",
    stdin: "inherit",
    cwd: tmpdir,
    env: {
      ...bunEnv,
      PORT: "0",
    },
  }));

  // just check exit code for now
  expect(exitCode).toBe(0);
});
