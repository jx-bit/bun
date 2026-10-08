# CI porting notes — official Buildkite pipeline → GitHub Actions

`ci.yml` re-expresses the official bun CI pipeline (`.buildkite/ci.mjs`) on
GitHub-hosted runners. Upstream bun runs its build/test pipeline on Buildkite
agents (baked debian-13 aarch64 images, AWS/Azure fleets); this repository has
no Buildkite infrastructure, so the pipeline semantics are re-expressed as a
GitHub Actions workflow.

This document maps every job to its official step, states what is identical,
and catalogues every deviation with its rationale. **Any change to `ci.yml`
that touches one of these areas must update the corresponding entry here.**

## Job ↔ official step mapping

| ci.yml job    | .buildkite/ci.mjs function                          | Notes |
|---------------|-----------------------------------------------------|-------|
| `build`       | `getBuildBunStep` (L519) via `getBuildCommand`      | Same profile (`ci-build`), same target flags (`--os`/`--arch`), same post-build smoke (`--revision`) |
| `test`        | `getTestBunStep` (L810)                             | Same runner (`scripts/runner.node.mjs`), same `--exclude`s, same deterministic shard partition |
| `binary-size` | `getBinarySizeStep` (L1004)                         | Semantics reduced to record-only — see D-7 |

## What is identical to the official pipeline

- **Build profile and command shape**: `--profile=ci-build --os=<os> --arch=<arch>`
  — the exact `getBuildArgs` output for a linux gnu target (official adds
  `--abi` on linux; `gnu` is the default when omitted).
- **Test runner**: the very same `scripts/runner.node.mjs`, driven through its
  supported non-Buildkite entry points (`--exec-path`, `--shard`, `--max-shards`).
  Its Buildkite-coupled features (artifact download via `--step`, JUnit upload
  to Test Analytics, PR changed-files API) are all env-gated and skip cleanly
  when no `BUILDKITE_*` variables are set.
- **Test excludes**: `integration/bun-types` and `internal/source-lints` are
  excluded for the same reason the official pipeline excludes them — they run
  in their dedicated workflows (`bun-types.yml`, `source-lints.yml`), which
  also run on this repository's PRs.
- **Per-shard process isolation, docker-compose service prestart
  (mysql/postgres/redis/minio …), JUnit generation**: all inside
  `runner.node.mjs`, so we get them unchanged.
- **Platform smoke assertions**: the runner's fail-closed
  `assertExpectedPlatform()` is armed with `EXPECTED_PLATFORM_OS` /
  `EXPECTED_PLATFORM_ARCH` (scope narrowed, see D-8).
- **Build-time ASAN runtime env** (`ASAN_OPTIONS` in the official step) is
  carried on the build job.
- **Concurrency/cancel semantics**: official uses `cancel_on_build_failing` on
  the merge queue; the workflow's `concurrency` group with
  `cancel-in-progress` is the closest Actions equivalent.
- **`nasm` setup for x64** (BoringSSL win-x64, libjpeg-turbo SIMD) — same
  best-effort install as `getBuildBunStep`.

## Deviations

### D-1 — Carrier: Buildkite fleets → GitHub-hosted runners

Official: pre-baked debian-13 aarch64 AWS/Azure images with the full
toolchain, 64+ core agents, Buildkite artifact service.

Ours: `ubuntu-24.04` / `ubuntu-24.04-arm` hosted runners (4 cores, ~16 GB).

Why: no Buildkite organization/agents exist for this repository.

Impact: wall-clock times are longer; sharding and timeouts were re-sized to
compensate (D-6). Nothing in the build/test semantics changes.

### D-2 — Toolchain provisioning: baked images → job-time install (all lanes)

Official: `scripts/bootstrap.sh` bakes clang/rust/bun/nasm into agent images
(`# Version:`-stamped, see the CI image lifecycle note in `ci.mjs`); **build
and test agents boot the same image**, so every lane has the full toolchain.

Ours: each job installs what it needs at job start — build jobs install LLVM
21 from apt.llvm.org (plus ninja/cmake/nasm/pkg-config), Rust via the
`dtolnay/rust-toolchain` action using the repo's `rust-toolchain.toml` pin,
bun via the in-repo `.github/actions/setup-bun`. **Test jobs install LLVM 21
as well**: the built bun embeds the absolute CC path it was compiled with
(`/usr/lib/llvm-21/bin/clang`) and spawns it for N-API addon direct
compilation and the node-gyp fallback, so a test runner without the same
clang fails every N-API compile (`posix_spawn ENOENT`) — which is what the
first CI run demonstrated across all 10 shards.

Version choice: `scripts/build/tools.ts` enforces `>= 21.1.0 < 23.0.0` for
clang; LLVM 21.1.x from apt.llvm.org satisfies the range and matches the
toolchain the OHOS container lane uses (21.1.x), so both lanes compile with
the same compiler family.

### D-3 — Buildkite artifact plumbing disabled (`--buildkite=false`)

Official: `ci-build` sets `buildkite: true` so the build graph emits
Buildkite-agent artifact upload edges (dep libs / archive / rust lib) that the
split-pipeline test lanes download via `getExecPathFromBuildKite`.

Ours: build and test run in the same workflow with `actions/upload-artifact`
/ `download-artifact` as the carrier, so the build runs with
`--buildkite=false` (no `buildkite-agent` binary exists on hosted runners)
and the test job passes `--exec-path` instead of `--step`, which makes
`runner.node.mjs` use the local binary and skip its Buildkite artifact
download entirely.

### D-4 — LTO disabled (`--lto=off`)

Official: the `ci-build` profile resolves `lto = on` for linux release builds
(`ltoDefault` in `scripts/build/config.ts`) — upstream's agents have the RAM
for the ThinLTO link.

Ours: hosted runners have ~16 GB; the ThinLTO link of bun does not fit, so the
build passes `--lto=off` explicitly.

Impact: CI artifacts are larger and marginally slower than official release
artifacts; test results are unaffected. The binary-size record (D-7) is
therefore not comparable to official release sizes.

### D-5 — Platform matrix scope

Official builds 13 platform targets and tests 12 platform lanes (darwin ×2
build / ×3 test, windows ×2 / ×2, linux gnu ×2 / ×2 distros, linux asan,
linux musl ×2, android ×2, freebsd ×2), plus QEMU/SDE baseline verification,
canary and release steps.

Ours: **linux-x64 and linux-aarch64 (gnu) only** — build + test + size record.

Rationale per excluded lane:

| Excluded lane | Why excluded |
|---|---|
| darwin build/test | macOS agents (built-in hosted macOS runners) are 10× the minute multiplier and the fork's delivery targets do not include darwin; official's darwin tests need a real mac fleet |
| windows build/test | needs the cross-clang-cl toolchain + Windows test fleet; delivery targets do not include windows |
| linux musl (alpine 3.23) | glibc is the delivery baseline; musl coverage on this fork is provided by the OHOS (musl) container lane |
| linux asan | valuable, but doubles compute for a lane whose leaks/UB findings this fork triages on the OHOS lanes first; easy to add later (profile exists: `--asan=on`) |
| linux ubuntu-25.04 lane | official runs debian-13 **and** ubuntu-25.04 test lanes; hosted runners only offer ubuntu — one distro is carried (D-10) |
| android / freebsd builds | not delivery targets; official cross-builds them from the same debian-13 hosts |
| verify-baseline (QEMU/SDE) | guards SIMD baseline encodings for release artifacts; no release artifacts ship from this lane today |
| canary / release steps | releases run through this repository's existing release lanes |

### D-6 — Shard counts and timeouts

Official: linux test lanes run `parallelism: 20` with a 30-minute timeout on
high-core agents; the full suite on one box is ~35 minutes (the beta tier's
single-box measurement).

Ours: **6 shards for linux-x64, 4 for linux-aarch64**, 90-minute job timeout
on 4-core hosted runners. The runner's deterministic file partition means
total coverage is identical to running 20 shards; per-shard wall time is
longer.

Maintenance invariant: every shard index in `0..max-shards-1` must have a
matrix entry — a missing entry silently removes part of the suite from CI.

### D-7 — binary-size gate is record-only

Official: `scripts/binary-size.ts` diffs built artifact sizes against the
canary baseline stored in Buildkite meta-data and fails a PR whose binary
grew by more than 0.5 MB.

Ours: `scripts/binary-size.ts` has no GitHub-side baseline store to compare
against (and its Buildkite/meta-data retrieval paths do not apply here), so
the job records absolute artifact sizes into the job summary and always
passes. Flipping on the official fail-gate requires standing up a baseline
store (e.g. a branch holding the last-recorded sizes) and teaching the job to
diff against it — deliberately deferred.

### D-8 — Platform smoke assertions narrowed

Official: each test lane asserts `os`/`arch`/`abi`/`distro`/`release` (e.g.
debian-13, ubuntu-25.04, alpine 3.23, windows-2019) so a shard that lands on
the wrong agent fails fast.

Ours: asserts `os=linux` and `arch` only. Hosted `ubuntu-24.04` matches
neither of the official test distros, and asserting a distro we do not
actually target would just produce noise. Fail-closed behavior for the
asserted keys is preserved.

### D-9 — Triggers and queue semantics

Official: Buildkite runs on PRs, `main` pushes, the merge queue, and canary
tag builds; commit-tag conventions (`[skip tests]`, `[build images]`,
`[publish images]`) select pipeline features.

Ours: `pull_request` + `push` (delivery branch) + `workflow_dispatch`. No
merge queue exists on GitHub here; no commit-tag conventions are wired
(`[skip tests]` is trivially addable later by conditioning the test job on
the commit message).

### D-10 — Runner distro

Official test lanes run on debian-13 and ubuntu-25.04 agents (and alpine 3.23
for musl). Ours run on ubuntu-24.04 — a third distro that official does not
target. Kernel/libc differences vs the official lanes are possible for
distro-sensitive tests; if such a test surfaces, the right fix is to keep the
test environment-robust (as upstream does for its two distros), not to pin
the runner image.

## What runs where

- **OHOS targets** keep their dedicated container build/test lanes (unchanged
  by this workflow).
- **`ci.yml`** gates the non-OHOS linux targets (x64 + aarch64): build,
  sharded test suite, size record.
- Lint/format/types/source-lints coverage comes from the workflows upstream
  already ships for those (`format.yml`, `lint.yml`, `bun-types.yml`,
  `source-lints.yml`, `rust-lints.yml`), which run on this repository's PRs.

## Known risks / iteration policy

- First runs on any new runner environment tend to surface environment-
  sensitive tests (timing, filesystem layout, installed tooling). The policy
  matches upstream's: make the test environment-robust or gate it on the
  capability it actually needs — do not delete tests to get green.
- The docker-compose service prestart path (`test/docker/prestart-map.mjs`)
  is exercised on hosted runners (docker is available); if a service proves
  flaky there, it gets the same treatment as any other failing dependency.
- ThinLTO link can be re-enabled when a runner with enough RAM is available
  (a `ubuntu-24.04` runner with `--lto` on is a one-line change); the size
  record should be re-baselined at that point.
