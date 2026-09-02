/**
 * Regression guard for the 2026-08-18 shim export-list drift: src/linker.lds
 * re-exports ohos-compat-shim's interposed libc symbols (scripts/build/shims/
 * ohos_compat_shim.c) so dlopen'd native modules (.node/.so — @ohos-ports/*
 * packages) resolve them from the executable, matching LD_PRELOAD's
 * global-scope-first semantics (see the comment block in linker.lds and
 * shims.ts's needsOhosCompatShim doc comment).
 *
 * That list is hand-maintained and had silently drifted: the shim grew from
 * 9 to 16 interposed symbols over several commits, but linker.lds's export
 * block was only updated for some of them — `close`, `poll`, `ppoll`,
 * `epoll_ctl`, `epoll_wait`, `epoll_pwait`, and `getaddrinfo` were compiled
 * in and functional for bun's own internal calls (statically bound) but
 * invisible to dlopen'd addons for months before anyone noticed. Fixed and
 * this guard added 2026-08-18; the shim grew two more (`dup2`/`dup3`) the
 * same day, exported from the start this time.
 *
 * This test extracts every top-level (non-static) function definition from
 * the vendored shim source — which is exactly the set of interposed libc
 * symbols, one-to-one, verified against `nm -D --defined-only
 * libohos_compat.so` in the canonical ohos-compat-shim repo — and asserts
 * each one is either exported in linker.lds's shim block, or explicitly
 * allowlisted below with a reason. A newly-added interposer that isn't
 * exported AND isn't allowlisted fails this test instead of silently
 * shipping unprotected for dlopen'd addons again.
 *
 * Pure source-text parsing — no compiler, no ninja, runs on every host.
 */
import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const REPO_ROOT = join(import.meta.dir, "..", "..");
const SHIM_C_PATH = join(REPO_ROOT, "scripts/build/shims/ohos_compat_shim.c");
const LINKER_LDS_PATH = join(REPO_ROOT, "src/linker.lds");

/**
 * Symbols intentionally NOT re-exported, with the reason. Keep this list
 * short and every entry justified — it is the only sanctioned way for this
 * test to pass without linker.lds actually exporting a symbol.
 *
 * (poll/ppoll were here briefly on 2026-08-18, withheld for their measured
 * O(N) per-idle-fd fstat() cost -- a same-day follow-up added a per-fd
 * fifo-ness cache that cut it to +3.7% at 128 idle fds, so they're exported
 * now. Kept this list's shape/comment so the next entry follows the same
 * pattern.)
 */
const INTENTIONALLY_NOT_EXPORTED: Record<string, string> = {};

/** Extract every top-level (column-0, non-static) C function name defined in `src`. */
function extractTopLevelFunctionNames(src: string): string[] {
  const names: string[] = [];
  // Matches e.g. `int close_range(` or `char *getcwd(` or `long syscall(` at
  // the start of a line -- a return type (letters/digits/underscore/spaces),
  // then a mandatory space-or-`*` right before the function name, then `(`.
  // Excludes `static` (internal helpers, not interposers) and `typedef`
  // (function-pointer typedefs like `typedef long (*real_syscall_fn)(long,
  // ...);` are also column-0/non-static and would otherwise false-positive,
  // capturing the return type word as if it were a function name, since
  // "TYPE (*name)(" superficially matches "TYPE(").
  const re = /^(?!static\b)(?!typedef\b)[A-Za-z_][A-Za-z0-9_ ]*[ *](\w+)\s*\(/gm;
  let m: RegExpExecArray | null;
  while ((m = re.exec(src)) !== null) {
    names.push(m[1]!);
  }
  return names;
}

/** Extract the symbol names listed in linker.lds's `global:` block, up to the first blank-line-delimited section boundary after the shim comment (the `uv_*` block that follows is libuv's own export list, unrelated). */
function extractLdsShimExports(src: string): Set<string> {
  const startMarker = "ohos-compat-shim interposers";
  const start = src.indexOf(startMarker);
  if (start === -1) {
    throw new Error(`linker.lds: could not find the "${startMarker}" comment marker`);
  }
  // The shim's own symbol list runs from the end of that comment block to
  // the first `uv_*;` entry (libuv's list starts immediately after, per the
  // current file layout) -- slice there rather than guessing a line count.
  const afterComment = src.slice(start);
  const uvStart = afterComment.indexOf("uv_accept;");
  const block = uvStart === -1 ? afterComment : afterComment.slice(0, uvStart);
  const names = new Set<string>();
  for (const m of block.matchAll(/^\s*(\w+);/gm)) {
    names.add(m[1]!);
  }
  return names;
}

describe("linker.lds shim export list matches ohos_compat_shim.c interposers", () => {
  test("every top-level interposer function is exported or allowlisted", () => {
    const shimSrc = readFileSync(SHIM_C_PATH, "utf8");
    const ldsSrc = readFileSync(LINKER_LDS_PATH, "utf8");

    const interposers = extractTopLevelFunctionNames(shimSrc);
    // Sanity check on the extractor itself: this file interposes exactly 18
    // libc symbols as of the 2026-08-18 validation pass (confirmed via
    // `nm -D --defined-only libohos_compat.so` in the canonical repo --
    // 16 plus dup2/dup3, added same day to fix fd-reuse staleness in the
    // epoll_pipe registry and the new fifo-ness cache). If this drifts, the
    // extractor's own pattern likely needs revisiting before trusting its
    // output -- fail loudly rather than silently checking a wrong/partial
    // list.
    expect(interposers.length).toBeGreaterThanOrEqual(18);

    const exported = extractLdsShimExports(ldsSrc);

    const missing = interposers.filter(name => !exported.has(name) && !(name in INTENTIONALLY_NOT_EXPORTED));
    expect(missing).toEqual([]);

    // Every allowlist entry must actually correspond to a real interposer
    // (not stale text left behind after a symbol was later exported for
    // real) and must not ALSO appear in linker.lds's export block (that
    // would mean the allowlist comment is now lying about the symbol being
    // withheld).
    for (const name of Object.keys(INTENTIONALLY_NOT_EXPORTED)) {
      expect(interposers).toContain(name);
      expect(exported.has(name)).toBe(false);
    }
  });
});
