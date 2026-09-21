import { expect, test } from "bun:test";
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";

// OHOS-gated skip ledger (lint).
//
// Both directions are enforced, for different reasons:
//  1. `skipIf(isOHOS)`: the case never runs on a device. A skip is not a
//     failure in the fulltest reports, so without a ledger the coverage loss
//     is silent (post-mortem: we synced the reference test tree's
//     node-userinfo test without porting the runtime feature, and the skip
//     hid that gap completely).
//  2. `skipIf(!isOHOS)`: device-only cases. They are always skipped in CI,
//     so the ledger must record what the device needs for them to actually
//     run (e.g. spawn-ohos-node-userinfo needs a real `node` on the device
//     PATH -- the bun-as-node shim would make the preload probe a no-op).
//
// Rules:
//  a. every `skip*(...)` condition mentioning isOHOS must be registered in
//     ohos-skip-inventory.json -- an unregistered site fails this lint
//  b. every ledger entry must still point at an existing site (renames and
//     deletions make entries stale, which also fails)
//  c. every entry needs a non-empty reason and device_plan
//
// When adding a new OHOS-gated skip: run this lint and register the site in
// the JSON per the failure output. "untriaged" is a legal reason; "missing
// from the ledger" is not.

const root = path.resolve(import.meta.dir, "..", "..", "..");
const ledger = JSON.parse(readFileSync(path.join(import.meta.dir, "ohos-skip-inventory.json"), "utf8")) as {
  entries: Array<{
    file: string;
    conditions: string[];
    direction: "skipped-on-device" | "device-only";
    reason: string;
    device_plan: string;
  }>;
};

function* walkTestFiles(dir: string): Generator<string> {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === "node_modules" || entry.name === "internal") continue;
      yield* walkTestFiles(p);
    } else if (/\.(ts|js|tsx|mts|cts|mjs|cjs)$/.test(entry.name)) {
      yield p;
    }
  }
}

// Only matches skip sites whose condition mentions isOHOS. Conditions in this
// tree are simple boolean expressions (no nested parens), so stopping at the
// first `)` is the correct boundary.
const SITE_RE = /skip(?:If)?\s*\(\s*[^)]*isOHOS[^)]*\)/g;

test("every isOHOS-gated skip site is registered in the inventory", () => {
  const sites = new Map<string, Set<string>>();
  for (const file of walkTestFiles(path.join(root, "test"))) {
    const rel = path.relative(root, file).replaceAll("\\", "/");
    const src = readFileSync(file, "utf8");
    for (const match of src.matchAll(SITE_RE)) {
      const condition = match[0]
        .slice(match[0].indexOf("(") + 1, match[0].lastIndexOf(")"))
        .replace(/\s+/g, " ")
        .trim();
      if (!sites.has(rel)) sites.set(rel, new Set());
      sites.get(rel)!.add(condition);
    }
  }

  const missing: string[] = [];
  for (const [file, conditions] of sites) {
    const entry = ledger.entries.find(e => e.file === file);
    if (!entry) {
      missing.push(`${file}: file not registered at all (conditions: ${[...conditions].join(" | ")})`);
      continue;
    }
    for (const condition of conditions) {
      if (!entry.conditions.includes(condition)) {
        missing.push(`${file}: condition "${condition}" not registered`);
      }
    }
  }
  expect(missing.join("\n") || "all registered").toBe("all registered");
});

test("no stale inventory entries (file gone or condition no longer present)", () => {
  const stale: string[] = [];
  for (const entry of ledger.entries) {
    const abs = path.join(root, entry.file);
    let src: string;
    try {
      src = readFileSync(abs, "utf8");
    } catch {
      stale.push(`${entry.file}: file does not exist, entry is stale`);
      continue;
    }
    for (const condition of entry.conditions) {
      const compact = condition.replace(/\s+/g, " ");
      const present = src.matchAll(/skip(?:If)?\s*\(\s*[^)]*isOHOS[^)]*\)/g).some(m =>
        m[0]
          .slice(m[0].indexOf("(") + 1, m[0].lastIndexOf(")"))
          .replace(/\s+/g, " ")
          .trim()
          .includes(compact),
      );
      // Substring match on purpose: combined conditions like
      // `isWindows || isOHOS` may appear at several sites in one file;
      // one ledger entry covers all of them.
      if (!present) stale.push(`${entry.file}: condition "${condition}" no longer present in file`);
    }
  }
  expect(stale.join("\n") || "no stale entries").toBe("no stale entries");
});

test("every inventory entry has a reason and a device plan", () => {
  const bad: string[] = [];
  for (const entry of ledger.entries) {
    if (!entry.reason?.trim()) bad.push(`${entry.file}: empty reason`);
    if (!entry.device_plan?.trim()) bad.push(`${entry.file}: empty device_plan`);
    if (entry.direction !== "skipped-on-device" && entry.direction !== "device-only") {
      bad.push(`${entry.file}: invalid direction (${entry.direction})`);
    }
  }
  expect(bad.join("\n") || "all entries documented").toBe("all entries documented");
});
