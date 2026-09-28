---
name: buildkite-ci
description: Debug upstream BuildKite CI failures with the repo's ci: scripts. Use when a BuildKite build failed, when asked about ci:errors/ci:status/ci:logs, or for the upstream (non-OHOS) CI pipeline.
---

# BuildKite CI Debugging

The upstream CI (builds, tests, releases) runs on BuildKite. The OHOS builds run on GitHub Actions — see the gh-ci-status / gh-ci-logs skills for those.

## Requirements

- BuildKite CLI: `brew install buildkite/buildkite/bk` + read-scoped token in `BUILDKITE_API_TOKEN`.
- `.bk.yaml` at the repo root sets the org/pipeline (no `-p` flag needed).

## Resolve a build

```bash
bun run ci:find                 # current branch's latest build
bun run ci:find '#<PR>'         # by PR number / URL / branch / build number
```

## Status & watch

```bash
bun run ci:status               # one-screen progress summary
bun run ci:watch                # poll until the build finishes
```

## Failure output

```bash
bun run ci:errors               # rendered test-failure annotations, [new] vs [also on main]
bun run ci:errors --all         # include warning/info annotations
bun run ci:errors --no-compare  # skip the pre-existing check
bun run ci:logs                 # full logs of every failed job → ./tmp/ci-<build>/
```

## Compose with bk directly

```bash
bk build view $(bun run ci:find)
bk job log <job-uuid> -b $(bun run ci:find)
bk api /pipelines/<pipeline>/builds/$(bun run ci:find)/annotations
```

## Troubleshooting

If the parsed output looks wrong (mis-parsed annotation HTML, a field BuildKite changed), fix `scripts/find-build.ts` directly — it is a thin presenter over `bk`, not something to work around.
