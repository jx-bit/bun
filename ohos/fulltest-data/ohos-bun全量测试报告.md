# ohos-bun 全量测试报告

> - 2001 个测试文件 × A / B 两轮真机结果
> - **A 轮 = brew bun 1.4.0_80**（固定参考基线，185 失败，不随轮滚动）
> - **B 轮 = jx-bit `615b48e95`**（最新轮，当前 182/2001 文件失败）
> - **结果汇总**：A∩B 共同失败 **174**；仅 B 失败 **8**；仅 A 失败 **11**；双轮通过 **1808**；B 轮文件通过率 90.9%、用例通过率 98.65%
> - 图例：✅通过 ❌失败 ⏰超时（数字=用例 pass/fail，⏰附耗时）· 🔧=源码有改动（ohos 适配等）· ⊘a+b=上游树+fork树 skip 门控数
> - 失败集合：B-only-fail=仅 B 轮失败 · both-fail=A、B 两轮共同失败 · A-only-fail=仅 A 轮失败 · both-pass
> - 排序：每类内 B 独有失败 → 两轮都失败 → A 独有失败 → 通过

## Bun.sql（59 文件 / 1 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/js/sql/adapter-env-var-precedence.test.ts` | 🔧other-adapted ⊘3+3 | ❌92/1 | ❌92/1 | both-fail | env-baseline |
| `test/js/sql/adapter-override.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/sql/local-sql.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/postgres-binary-array-bounds.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/sql/postgres-binary-float-nan-box.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/sql/postgres-binary-numeric-digit-range.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/sql/postgres-binary-numeric.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/postgres-datarow-overrun.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/sql/postgres-datestyle.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/sql/postgres-duplicate-auth-request.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/sql/postgres-error-then-datarow.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/sql/postgres-failed-connection-resurrection.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/postgres-finish-request-underflow.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/sql/postgres-frame-boundary.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/sql/postgres-infinity-date.test.ts` |  | ✅18/0 | ✅18/0 | both-pass |  |
| `test/js/sql/postgres-invalid-message-length.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/sql/postgres-listen-notify.test.ts` |  | ✅44/0 | ✅44/0 | both-pass |  |
| `test/js/sql/postgres-multi-statement-fields.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/sql/postgres-pgsslmode-env.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/sql/postgres-prepared-pipeline-reorder.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/postgres-simple-query-pipeline.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/postgres-split-prepare-reorder.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/sql/postgres-tls-ctx-leak.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/sql/sql-close-pending-connection.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/sql/sql-connect-error-reporting.test.ts` |  | ✅15/0 | ✅15/0 | both-pass |  |
| `test/js/sql/sql-empty-column-name.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/sql/sql-helpers-validation.test.ts` |  | ✅28/0 | ✅28/0 | both-pass |  |
| `test/js/sql/sql-mariadb-json.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/sql/sql-mysql-auth-short-nonce.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/sql/sql-mysql-bigint-out-of-range.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql-mysql-binary-null-indexed.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql-mysql-bind-blob-borrow.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/sql/sql-mysql-bind-oob.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/sql/sql-mysql-cached-error.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql-mysql-clean-reentry.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql-mysql-column-name-digits.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql-mysql-columns-realloc-oom.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/sql/sql-mysql-datetime-roundtrip.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/sql/sql-mysql-duplicate-auth-switch.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/sql/sql-mysql-mediumint.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql-mysql-prepare-ok-zero-statement-id.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/sql/sql-mysql-query-string-leak.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql-mysql-raw-length-prefix.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql-mysql-tls-plaintext-injection.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/sql/sql-mysql.auth.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/sql/sql-mysql.helpers.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql-mysql.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/sql/sql-mysql.transactions.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql-onconnect-onclose-throw.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/sql/sql-pool-transaction-isolation.test.ts` |  | ✅18/0 | ✅18/0 | both-pass |  |
| `test/js/sql/sql-postgres-datetime-roundtrip.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/sql/sql-prepare-false.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql-reserve-abort.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql-statement-cache-hash-collision.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/sql/sql.test.ts` |  ⊘1+1 | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/sql/sqlite-sql.test.ts` |  | ✅248/0 | ✅248/0 | both-pass |  |
| `test/js/sql/sqlite-url-parsing.test.ts` |  | ✅176/0 | ✅176/0 | both-pass |  |
| `test/js/sql/tls-sql.test.ts` |  ⊘1+1 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/sql/wire-frames.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |


## CLI 命令（172 文件 / 32 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/cli/install/bun-add-catalog.test.ts` |  | ✅149/0 | ❌148/1 | B-only-fail | verdaccio-rotation |
| `test/cli/install/bun-audit.test.ts` |  | ✅182/0 | ❌76/106 | B-only-fail | verdaccio-rotation |
| `test/cli/install/bun-update.test.ts` |  | ✅156/0 | ❌52/104 | B-only-fail | verdaccio-rotation |
| `test/cli/install/frozen-lockfile-pruned.test.ts` |  | ✅101/0 | ❌21/80 | B-only-fail | verdaccio-rotation |
| `test/cli/create/create-jsx.test.ts` |  | ❌1/4 | ❌1/4 | both-fail | env-baseline |
| `test/cli/init/init.test.ts` | 🔧ohos-adapted | ❌11/4 | ❌11/4 | both-fail | env-baseline |
| `test/cli/install/bad-workspace.test.ts` |  ⊘2+2 | ❌10/3 | ❌10/3 | both-fail | env-baseline |
| `test/cli/install/bun-add-filter.test.ts` |  | ❌123/1 | ❌123/1 | both-fail | env-baseline |
| `test/cli/install/bun-create.test.ts` | 🔧slow-device-timeout ⊘1+1 | ❌17/3 | ❌17/3 | both-fail | env-baseline |
| `test/cli/install/bun-install-lifecycle-scripts.test.ts` |  | ❌63/2 | ❌63/2 | both-fail | env-baseline |
| `test/cli/install/bun-install-native-binlink.test.ts` |  ⊘1+1 | ❌3/13 | ❌3/13 | both-fail | env-baseline |
| `test/cli/install/bun-install-patch.test.ts` |  | ❌4/16 | ❌4/16 | both-fail | env-baseline |
| `test/cli/install/bun-install-registry.test.ts` |  | ❌240/3 | ⏰360.4s | both-fail | env-baseline |
| `test/cli/install/bun-install.test.ts` |  ⊘1+1 | ❌230/8 | ❌237/1 | both-fail | env-baseline |
| `test/cli/install/bun-lock.test.ts` |  ⊘1+1 | ❌39/1 | ❌22/18 | both-fail | env-baseline |
| `test/cli/install/bun-lockb.test.ts` |  | ❌6/1 | ❌6/1 | both-fail | env-baseline |
| `test/cli/install/bun-pack.test.ts` |  ⊘1+1 | ❌77/3 | ❌77/3 | both-fail | env-baseline |
| `test/cli/install/bun-patch.test.ts` |  | ❌25/12 | ❌25/12 | both-fail | env-baseline |
| `test/cli/install/bun-pm-diff.test.ts` |  ⊘3+3 | ❌44/2 | ❌44/2 | both-fail | env-baseline |
| `test/cli/install/bun-prune.test.ts` |  | ❌106/5 | ❌106/5 | both-fail | env-baseline |
| `test/cli/install/bun-security-scanner-matrix-with-node-modules.test.ts` |  | ❌56/11 | ⏰360.3s | both-fail | chronic-timeout |
| `test/cli/install/bun-security-scanner-matrix-without-node-modules.test.ts` |  | ❌44/21 | ⏰360.3s | both-fail | chronic-timeout |
| `test/cli/install/bun-upgrade.test.ts` |  | ❌5/3 | ❌7/1 | both-fail | env-baseline |
| `test/cli/install/bunx.test.ts` | 🔧ohos-adapted ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/cli/install/isolated-install.test.ts` | 🔧ohos-adapted ⊘3+4 | ❌81/1 | ❌27/55 | both-fail | env-baseline |
| `test/cli/install/migrate-bun-lockb-v2.test.ts` |  | ❌1/1 | ❌1/1 | both-fail | env-baseline |
| `test/cli/install/migration/complex-workspace.test.ts` | 🔧ohos-adapted | ❌0/21 | ❌0/21 | both-fail | env-baseline |
| `test/cli/install/migration/migrate.test.ts` |  | ❌121/4 | ❌124/1 | both-fail | env-baseline |
| `test/cli/install/symlink-path-traversal.test.ts` |  ⊘6+6 | ❌9/3 | ❌9/3 | both-fail | env-baseline |
| `test/cli/run/require-cache.test.ts` | 🔧ohos-adapted ⊘2+2 | ❌9/2 | ❌10/1 | both-fail | env-baseline |
| `test/cli/test/bun-test.test.ts` |  ⊘8+8 | ❌93/2 | ❌1/0 | both-fail | env-baseline |
| `test/cli/watch/watch.test.ts` | 🔧ohos-adapted ⊘3+3 | ❌6/1 | ❌6/1 | both-fail | env-baseline |
| `test/cli/hot/hot.test.ts` | 🔧ohos-adapted | ❌11/1 | ✅12/0 | A-only-fail |  |
| `test/cli/install/bun-add.test.ts` | 🔧ohos-adapted | ❌68/2 | ✅70/0 | A-only-fail |  |
| `test/cli/test/parallel.test.ts` |  ⊘4+4 | ❌33/1 | ✅34/0 | A-only-fail |  |
| `test/cli/bun.test.ts` |  ⊘1+1 | ✅35/0 | ✅35/0 | both-pass |  |
| `test/cli/bunfig-test-options.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/cli/console-depth.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/cli/env/bun-options.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/cli/env/ci-info.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/cli/heap-prof.test.ts` |  ⊘2+2 | ✅16/0 | ✅16/0 | both-pass |  |
| `test/cli/hot/watch-many-dirs.test.ts` |  ⊘3+3 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/hot/watch.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/inspect/BunFrontendDevServer.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/inspect/HTTPServerAgent.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/cli/inspect/bun-inspector-protocol.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/inspect/debugger-buntranspiledmodule.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/inspect/inspect-inline-sourcemap.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/inspect/inspect.test.ts` | 🔧ohos-adapted | ✅25/0 | ✅25/0 | both-pass |  |
| `test/cli/inspect/test-reporter.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/cli/install/GHSA-pfwx-36v6-832x.test.ts` | 🔧slow-device-timeout | ✅5/0 | ✅5/0 | both-pass |  |
| `test/cli/install/architecture-match.test.ts` |  | ✅30/0 | ✅30/0 | both-pass |  |
| `test/cli/install/bun-dedupe.test.ts` |  | ✅76/0 | ✅76/0 | both-pass |  |
| `test/cli/install/bun-info.test.ts` | 🔧slow-device-timeout ⊘1+1 | ✅19/0 | ✅19/0 | both-pass |  |
| `test/cli/install/bun-install-cpu-os.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/cli/install/bun-install-git-deps.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/cli/install/bun-install-hardlink-fallback.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/cli/install/bun-install-pathname-trailing-slash.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/install/bun-install-proxy.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/cli/install/bun-install-retry.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/cli/install/bun-install-security-provider.test.ts` |  | ✅43/0 | ✅43/0 | both-pass |  |
| `test/cli/install/bun-install-stalled-tls.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/install/bun-install-streaming-extract.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/cli/install/bun-install-tarball-integrity.test.ts` |  | ✅16/0 | ✅16/0 | both-pass |  |
| `test/cli/install/bun-link.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/cli/install/bun-pm-licenses.test.ts` |  | ✅79/0 | ✅79/0 | both-pass |  |
| `test/cli/install/bun-pm-pkg.test.ts` |  | ✅74/0 | ✅74/0 | both-pass |  |
| `test/cli/install/bun-pm-scan.test.ts` | 🔧slow-device-timeout | ✅17/0 | ✅17/0 | both-pass |  |
| `test/cli/install/bun-pm-version.test.ts` |  | ✅24/0 | ✅24/0 | both-pass |  |
| `test/cli/install/bun-pm-why.test.ts` | 🔧slow-device-timeout | ✅28/0 | ✅28/0 | both-pass |  |
| `test/cli/install/bun-pm.test.ts` |  | ✅18/0 | ✅18/0 | both-pass |  |
| `test/cli/install/bun-publish.test.ts` |  ⊘1+1 | ✅45/0 | ✅45/0 | both-pass |  |
| `test/cli/install/bun-remove.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/cli/install/bun-run-bunfig.test.ts` |  | ✅28/0 | ✅28/0 | both-pass |  |
| `test/cli/install/bun-run-dir.test.ts` | 🔧slow-device-timeout | ✅3/0 | ✅3/0 | both-pass |  |
| `test/cli/install/bun-run.test.ts` | 🔧slow-device-timeout ⊘3+3 | ✅295/0 | ✅295/0 | both-pass |  |
| `test/cli/install/bun-security-scanner-workspaces.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/cli/install/bun-update-lockfile-sync.test.ts` |  | ✅77/0 | ✅77/0 | both-pass |  |
| `test/cli/install/bun-update-security-edge-cases.test.ts` | 🔧slow-device-timeout | ✅6/0 | ✅6/0 | both-pass |  |
| `test/cli/install/bun-update-security-provider.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/install/bun-update-security-scan-all.test.ts` | 🔧slow-device-timeout | ✅5/0 | ✅5/0 | both-pass |  |
| `test/cli/install/bun-update-security-simple.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/install/bun-update-transitive.test.ts` |  | ✅174/0 | ✅174/0 | both-pass |  |
| `test/cli/install/bun-workspaces.test.ts` |  | ✅75/0 | ✅75/0 | both-pass |  |
| `test/cli/install/catalogs.test.ts` |  | ✅89/0 | ✅89/0 | both-pass |  |
| `test/cli/install/config-precedence.test.ts` |  | ✅51/0 | ✅51/0 | both-pass |  |
| `test/cli/install/config-version.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/cli/install/frozen-lockfile-missing-workspace.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/install/hoist.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/install/hosted-git-info/boundary-conditions.test.ts` | 🔧slow-device-timeout | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/install/hosted-git-info/from-url.test.ts` |  ⊘1+1 | ✅649/0 | ✅649/0 | both-pass |  |
| `test/cli/install/hosted-git-info/parse-url.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/cli/install/install-fd-leak.test.ts` |  ⊘1+1 | ✅4/0 | ✅4/0 | both-pass |  |
| `test/cli/install/isolated-relink.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/cli/install/lockfile-only.test.ts` |  | ✅19/0 | ✅19/0 | both-pass |  |
| `test/cli/install/lockfile-version-2.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/cli/install/migration/pnpm-comprehensive.test.ts` | 🔧slow-device-timeout | ✅5/0 | ✅5/0 | both-pass |  |
| `test/cli/install/migration/pnpm-lock-migration.test.ts` | 🔧slow-device-timeout | ✅5/0 | ✅5/0 | both-pass |  |
| `test/cli/install/migration/pnpm-lock-v9.test.ts` |  | ✅81/0 | ✅81/0 | both-pass |  |
| `test/cli/install/migration/pnpm-migration-complete.test.ts` | 🔧slow-device-timeout | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/install/migration/pnpm-migration.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/cli/install/migration/yarn-lock-migration.test.ts` | 🔧slow-device-timeout | ✅18/0 | ✅18/0 | both-pass |  |
| `test/cli/install/minimum-release-age.test.ts` |  | ✅49/0 | ✅49/0 | both-pass |  |
| `test/cli/install/nested-overrides.test.ts` |  | ✅144/0 | ✅144/0 | both-pass |  |
| `test/cli/install/npmrc.test.ts` |  ⊘1+1 | ✅40/0 | ✅40/0 | both-pass |  |
| `test/cli/install/overrides.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/cli/install/public-hoist-pattern.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/cli/install/redacted-config-logs.test.ts` |  | ✅16/0 | ✅16/0 | both-pass |  |
| `test/cli/install/semver.test.ts` |  | ✅28/0 | ✅28/0 | both-pass |  |
| `test/cli/install/shebang-normalize.test.ts` |  ⊘2+2 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/install/test-dev-peer-dependency-priority.test.ts` | 🔧slow-device-timeout | ✅4/0 | ✅4/0 | both-pass |  |
| `test/cli/run/as-node.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/cli/run/autoinstall-cached-manifest.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/run/commonjs-invalid.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/run/commonjs-no-export.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/run/cpu-prof.test.ts` |  ⊘1+1 | ✅12/0 | ✅12/0 | both-pass |  |
| `test/cli/run/crash-report-command-char.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/cli/run/empty-file.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/run/env.test.ts` |  ⊘3+3 | ✅96/0 | ✅96/0 | both-pass |  |
| `test/cli/run/esm-defineProperty.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/cli/run/filter-workspace.test.ts` |  ⊘3+3 | ✅79/0 | ✅79/0 | both-pass |  |
| `test/cli/run/garbage-env.test.ts` | 🔧ohos-adapted | ✅0/0 | ✅0/0 | both-pass |  |
| `test/cli/run/glob-on-fuse.test.ts` | 🔧ohos-adapted ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/cli/run/if-present.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/cli/run/jsx-namespaced-attributes.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/run/jsx-symbol-collision.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/run/log-test.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/run/markdown-entrypoint.test.ts` |  ⊘1+1 | ✅29/0 | ✅29/0 | both-pass |  |
| `test/cli/run/multi-run.test.ts` | 🔧ohos-adapted ⊘2+3 | ✅121/0 | ✅121/0 | both-pass |  |
| `test/cli/run/no-envfile.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/cli/run/no-orphans.test.ts` | 🔧ohos-adapted | ✅0/0 | ✅0/0 | both-pass |  |
| `test/cli/run/preload-test.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/run/require-and-import-trailing.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/run/run-autoinstall-abs-path.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/run/run-autoinstall.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/cli/run/run-cjs.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/run/run-crash-handler.test.ts` |  ⊘1+1 | ✅4/0 | ✅4/0 | both-pass |  |
| `test/cli/run/run-eval.test.ts` |  | ✅37/0 | ✅37/0 | both-pass |  |
| `test/cli/run/run-extensionless.test.ts` |  ⊘1+1 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/run/run-file-on-fuse.test.ts` | 🔧ohos-adapted ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/cli/run/run-process-env.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/run/run-propagate-sigkill.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/cli/run/run-quote.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/cli/run/run-shell.test.ts` |  ⊘1+1 | ✅3/0 | ✅3/0 | both-pass |  |
| `test/cli/run/run-unicode.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/run/run_command.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/run/self-reference.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/run/shell-keepalive.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/run/sql-preconnect.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/run/syntax.test.ts` |  | ✅592/0 | ✅592/0 | both-pass |  |
| `test/cli/run/transpiler-cache.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/cli/run/tsconfig-override.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/cli/run/workspaces.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/cli/test/claudecode-flag.test.ts` |  ⊘2+2 | ✅3/0 | ✅3/0 | both-pass |  |
| `test/cli/test/concurrent-test-glob.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/cli/test/coverage.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/cli/test/expectations.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/test/isolation.test.ts` |  | ✅25/0 | ✅25/0 | both-pass |  |
| `test/cli/test/pass-with-no-tests.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/cli/test/path-ignore-patterns.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/cli/test/rerun-each.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/cli/test/retry-flag.test.ts` |  ⊘1+1 | ✅9/0 | ✅9/0 | both-pass |  |
| `test/cli/test/test-changed.test.ts` |  ⊘1+1 | ✅20/0 | ✅20/0 | both-pass |  |
| `test/cli/test/test-filter-lifecycle-snapshot.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/cli/test/test-randomize.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/cli/test/test-shard.test.ts` |  | ✅29/0 | ✅29/0 | both-pass |  |
| `test/cli/test/test-timeout-behavior.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/update_interactive_formatting.test.ts` |  ⊘1+1 | ✅24/0 | ✅24/0 | both-pass |  |
| `test/cli/update_interactive_install.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/cli/update_interactive_snapshots.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/cli/user-agent.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/cli/watch/watcher-trace.test.ts` | 🔧ohos-adapted | ✅4/0 | ✅4/0 | both-pass |  |


## bake/SSR（24 文件 / 17 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/bake/dev-and-prod.test.ts` |  | ❌2/10 | ❌2/10 | both-fail | bake-dev-server |
| `test/bake/dev/bundle.test.ts` |  | ⏰120.4s | ❌5/16 | both-fail | bake-dev-gap |
| `test/bake/dev/css.test.ts` |  | ⏰120.4s | ❌1/14 | both-fail | env-baseline |
| `test/bake/dev/ecosystem.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | bake-dev-gap |
| `test/bake/dev/esm.test.ts` |  | ❌10/6 | ❌10/6 | both-fail | bake-dev-gap |
| `test/bake/dev/hot.test.ts` |  | ⏰120.3s | ❌0/11 | both-fail | env-baseline |
| `test/bake/dev/html.test.ts` |  | ❌6/4 | ❌6/4 | both-fail | bake-dev-gap |
| `test/bake/dev/import-meta-inline.test.ts` |  | ❌5/1 | ❌5/1 | both-fail | bake-dev-gap |
| `test/bake/dev/incremental-graph-edge-deletion.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | bake-dev-gap |
| `test/bake/dev/production.test.ts` |  | ❌1/11 | ❌1/11 | both-fail | bake-dev-gap |
| `test/bake/dev/react-response.test.ts` |  | ❌0/11 | ❌0/11 | both-fail | bake-dev-gap |
| `test/bake/dev/react-spa.test.ts` |  | ❌0/6 | ❌0/6 | both-fail | bake-dev-gap |
| `test/bake/dev/request-cookies.test.ts` |  | ❌0/2 | ❌0/2 | both-fail | bake-dev-gap |
| `test/bake/dev/server-sourcemap.test.ts` |  | ❌0/4 | ❌0/4 | both-fail | bake-dev-gap |
| `test/bake/dev/sourcemap.test.ts` |  | ❌1/1 | ❌1/1 | both-fail | bake-dev-gap |
| `test/bake/dev/ssg-pages-router.test.ts` |  | ❌0/9 | ❌0/9 | both-fail | bake-dev-gap |
| `test/bake/dev/stress.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | bake-dev-gap |
| `test/bake/deinitialization.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/bake/dev/import-meta-inline-negative.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bake/dev/plugins.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/bake/dev/response-to-bake-response.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/bake/dev/vfile.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bake/framework-router.test.ts` |  | ✅35/0 | ✅35/0 | both-pass |  |
| `test/bake/serve-plugins-dev-server.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |


## 打包器（98 文件 / 6 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/bundler/bun-build-api.test.ts` |  ⊘3+3 | ❌51/1 | ❌51/1 | both-fail | env-baseline |
| `test/bundler/bun-build-compile.test.ts` | 🔧ohos-adapted ⊘1+2 | ❌7/1 | ❌7/1 | both-fail | env-baseline |
| `test/bundler/bundler_compile.test.ts` |  | ❌63/7 | ❌68/2 | both-fail | env-baseline |
| `test/bundler/bundler_edgecase.test.ts` | 🔧ohos-adapted | ❌133/1 | ❌133/1 | both-fail | env-baseline |
| `test/bundler/bundler_npm.test.ts` |  | ❌0/2 | ❌1/1 | both-fail | env-baseline |
| `test/bundler/native-plugin.test.ts` | 🔧ohos-adapted ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/bundler/bun-build-compile-sourcemap.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/bundler/bun-build-compile-wasm.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bundler/bundler_allow_unresolved.test.ts` |  | ✅16/0 | ✅16/0 | both-pass |  |
| `test/bundler/bundler_banner.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/bundler/bundler_barrel.test.ts` |  | ✅51/0 | ✅51/0 | both-pass |  |
| `test/bundler/bundler_browser.test.ts` |  ⊘1+1 | ✅17/0 | ✅17/0 | both-pass |  |
| `test/bundler/bundler_bun.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/bundler/bundler_cjs.test.ts` |  | ✅28/0 | ✅28/0 | both-pass |  |
| `test/bundler/bundler_cjs2esm.test.ts` |  | ✅27/0 | ✅27/0 | both-pass |  |
| `test/bundler/bundler_comments.test.ts` |  | ✅45/0 | ✅45/0 | both-pass |  |
| `test/bundler/bundler_compile_autoload.test.ts` |  | ✅23/0 | ✅23/0 | both-pass |  |
| `test/bundler/bundler_compile_splitting.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/bundler/bundler_decorator_metadata.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/bundler/bundler_defer.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/bundler/bundler_drop.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/bundler/bundler_env.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/bundler/bundler_feature_flag.test.ts` |  | ✅41/0 | ✅41/0 | both-pass |  |
| `test/bundler/bundler_files.test.ts` |  | ✅24/0 | ✅24/0 | both-pass |  |
| `test/bundler/bundler_footer.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/bundler/bundler_html.test.ts` |  | ✅22/0 | ✅22/0 | both-pass |  |
| `test/bundler/bundler_html_server.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/bundler/bundler_jsx.test.ts` |  | ✅48/0 | ✅48/0 | both-pass |  |
| `test/bundler/bundler_loader.test.ts` |  | ✅58/0 | ✅58/0 | both-pass |  |
| `test/bundler/bundler_minify.test.ts` |  | ✅43/0 | ✅43/0 | both-pass |  |
| `test/bundler/bundler_minify_symbol_for.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/bundler/bundler_naming.test.ts` |  | ✅27/0 | ✅27/0 | both-pass |  |
| `test/bundler/bundler_plugin.test.ts` |  | ✅55/0 | ✅55/0 | both-pass |  |
| `test/bundler/bundler_plugin_chain.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/bundler/bundler_promiseall_deadcode.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/bundler/bundler_regressions.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/bundler/bundler_splitting.test.ts` |  | ✅22/0 | ✅22/0 | both-pass |  |
| `test/bundler/bundler_string.test.ts` |  | ✅59/0 | ✅59/0 | both-pass |  |
| `test/bundler/cli.test.ts` |  ⊘2+2 | ✅33/0 | ✅33/0 | both-pass |  |
| `test/bundler/compile-argv.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/bundler/compile-asset-bunfs.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/bundler/compile-process-execargv.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/bundler/compile-sourcemap-internal.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bundler/compile-windows-metadata.test.ts` |  ⊘2+2 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/bundler/css/css-modules.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/bundler/css/is-selector-21169.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bundler/css/mask-geometry-box.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/bundler/css/view-transition-23600.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bundler/css/wpt/background-computed.test.ts` |  | ✅24/0 | ✅24/0 | both-pass |  |
| `test/bundler/css/wpt/color-computed-rgb.test.ts` |  | ✅94/0 | ✅94/0 | both-pass |  |
| `test/bundler/css/wpt/color-computed.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/bundler/css/wpt/relative_color_out_of_gamut.test.ts` |  | ✅27/0 | ✅27/0 | both-pass |  |
| `test/bundler/esbuild/css.test.ts` |  | ✅56/0 | ✅56/0 | both-pass |  |
| `test/bundler/esbuild/dce.test.ts` |  | ✅78/0 | ✅78/0 | both-pass |  |
| `test/bundler/esbuild/default.test.ts` |  ⊘5+5 | ✅151/0 | ✅151/0 | both-pass |  |
| `test/bundler/esbuild/extra.test.ts` |  | ✅220/0 | ✅220/0 | both-pass |  |
| `test/bundler/esbuild/importstar.test.ts` |  | ✅75/0 | ✅75/0 | both-pass |  |
| `test/bundler/esbuild/importstar_ts.test.ts` |  | ✅23/0 | ✅23/0 | both-pass |  |
| `test/bundler/esbuild/loader.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/bundler/esbuild/lower.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/bundler/esbuild/metafile.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/bundler/esbuild/packagejson.test.ts` |  | ✅84/0 | ✅84/0 | both-pass |  |
| `test/bundler/esbuild/splitting.test.ts` |  | ✅26/0 | ✅26/0 | both-pass |  |
| `test/bundler/esbuild/ts.test.ts` |  | ✅57/0 | ✅57/0 | both-pass |  |
| `test/bundler/esbuild/tsconfig.test.ts` |  ⊘1+1 | ✅17/0 | ✅17/0 | both-pass |  |
| `test/bundler/html-import-manifest.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/bundler/metafile.test.ts` |  | ✅44/0 | ✅44/0 | both-pass |  |
| `test/bundler/plugin-error-nested-throw.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/bundler/plugin-sync-exception-fallback.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/bundler/resolver/cache-invalidation.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/bundler/resolver/cache-node-compat.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/bundler/resolver/cache-runtime.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/bundler/standalone.test.ts` |  | ✅26/0 | ✅26/0 | both-pass |  |
| `test/bundler/transpiler/assign-to-import.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/bundler/transpiler/bun-pragma.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/bundler/transpiler/decorator-metadata.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/bundler/transpiler/decorators.test.ts` |  | ✅24/0 | ✅24/0 | both-pass |  |
| `test/bundler/transpiler/es-decorators-esbuild.test.ts` |  | ✅147/0 | ✅147/0 | both-pass |  |
| `test/bundler/transpiler/es-decorators.test.ts` |  | ✅59/0 | ✅59/0 | both-pass |  |
| `test/bundler/transpiler/export-default.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bundler/transpiler/function-tostring-require.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bundler/transpiler/jsx-deep-nesting-stack-overflow.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bundler/transpiler/jsx-production.test.ts` |  | ✅32/0 | ✅32/0 | both-pass |  |
| `test/bundler/transpiler/jsx-tsconfig-react-jsx.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/bundler/transpiler/macro-test.test.ts` |  | ✅15/0 | ✅15/0 | both-pass |  |
| `test/bundler/transpiler/preserve-use-strict-cjs.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/bundler/transpiler/property.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bundler/transpiler/react-compiler-fixtures.test.ts` |  | ✅2467/0 | ✅2467/0 | both-pass |  |
| `test/bundler/transpiler/react-compiler.test.ts` |  ⊘1+1 | ✅36/0 | ✅36/0 | both-pass |  |
| `test/bundler/transpiler/runtime-transpiler.test.ts` |  | ✅15/0 | ✅15/0 | both-pass |  |
| `test/bundler/transpiler/scope-mismatch-panic.test.ts` |  | ✅16/0 | ✅16/0 | both-pass |  |
| `test/bundler/transpiler/simplifier-side-effects.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bundler/transpiler/template-literal.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bundler/transpiler/transpiler-stack-overflow.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/bundler/transpiler/transpiler.test.js` |  ⊘1+1 | ✅188/0 | ✅188/0 | both-pass |  |
| `test/bundler/transpiler/ts-enum-redecl-panic.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/bundler/transpiler/ts-use-define-for-class-fields.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/bundler/transpiler_constant_fold_eqeq.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |


## 回归测试(issue)（413 文件 / 16 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/regression/issue/26286.test.ts` |  ⊘2+2 | ✅2/0 | ⏰360.3s | B-only-fail | chronic-timeout |
| `test/regression/issue/10132.test.ts` |  | ❌1/1 | ❌1/1 | both-fail | env-baseline |
| `test/regression/issue/13696.test.ts` |  | ❌2/1 | ❌2/1 | both-fail | env-baseline |
| `test/regression/issue/14945-lifecycle-script-crash.test.ts` |  | ❌1/1 | ❌1/1 | both-fail | env-baseline |
| `test/regression/issue/15276.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/regression/issue/18239/18239.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/regression/issue/20144/20144.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/regression/issue/24364.test.ts` | 🔧ohos-adapted | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/regression/issue/25903.test.ts` |  ⊘1+1 | ❌1/6 | ❌1/6 | both-fail | env-baseline |
| `test/regression/issue/26225.test.ts` |  | ❌1/2 | ❌1/2 | both-fail | env-baseline |
| `test/regression/issue/26249.test.ts` |  ⊘2+2 | ❌0/2 | ❌0/2 | both-fail | env-baseline |
| `test/regression/issue/26657.test.ts` |  | ❌1/1 | ❌1/1 | both-fail | env-baseline |
| `test/regression/issue/27272.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/regression/issue/28159.test.ts` | 🔧ohos-adapted | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/regression/issue/ctrl-c.test.ts` |  ⊘2+2 | ❌2/6 | ❌2/6 | both-fail | env-baseline |
| `test/regression/issue/test-process-stdout-async-iterator.test.ts` |  | ❌1/2 | ❌1/2 | both-fail | env-baseline |
| `test/regression/issue/02499/02499.test.ts` |  | ❌0/1 | ✅1/0 | A-only-fail |  |
| `test/regression/issue/32492.test.ts` |  | ❌0/1 | ✅1/0 | A-only-fail |  |
| `test/regression/issue/00631.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/012039.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/012040.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/012360.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/013880.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/014187.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/01466.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/014865.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/015201.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/02005.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/02367.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/02368.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/02369.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/026039.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/02977.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/03091.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/03216.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/03830.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/03844/03844.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/04011.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/04298/04298.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/04893.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/04947.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/05545.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/05828.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/06443.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/06467.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/06946/06946.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/07001.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/07261.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/07263.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/07324.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/07397.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/07500/07500.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/07736.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/07740.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/07827.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/07917/7917.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/08040.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/08093.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/08095.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/08757.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/08768.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/08794.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/08893.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/08964/08964.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/08965/08965.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/09041.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/09279.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/09340.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/09469.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/09555.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/09559.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/09563/09563.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/09739.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/09748.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/09778.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/10004.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/10139.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/10170.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/10380/spy-matchers-diff.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/10887.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/11029-crypto-verify-null-algorithm.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/11100.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/11297/11297.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/11664.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/11677.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/regression/issue/11793.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/11806.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/11866.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/12034/12034.test.js` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/regression/issue/12042.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/12117.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/12250.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/12548.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/12650.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/12782.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/12910/12910.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/13251.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/13316.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/1365.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/14029.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/14135.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/14338.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/14477/14477.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/14515.test.tsx` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/14624.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/14709.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/14799.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/14976/14976.test.ts` |  ⊘1+1 | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/14982/14982.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/15314.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/15326.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/15753.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/16007.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/16312.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/1632.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/16474.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/16476/16476.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/16702/16702.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/17244.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/17294.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/regression/issue/17327.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/17405.test.ts` |  | ✅22/0 | ✅22/0 | both-pass |  |
| `test/regression/issue/17454/destructure_string.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/17605.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/17766.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/17793.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/18028.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/18159/18159.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/18161.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/18242.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/18413-all-compressions.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/18413-deflate-semantics.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/regression/issue/18413-truncation.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/regression/issue/18413.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/18547.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/18595.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/18820.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/19107.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/19111.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/19219.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/19412.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/19652.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/19661.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/19758.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/19850/19850.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/19875.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/20053.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/20092.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/20100.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/20321.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/20546.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/20753.test.js` |  ⊘1+1 | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/20875.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/20965.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/20980.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/21137-minify-typeof-comma.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/21177.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/21257.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/21274.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/21311.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/21654/21654.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/21677.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/21680.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/21792.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/regression/issue/21830.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/21907.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/22003.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/22157.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/22199.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/22243.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/22317.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/22353.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/22475.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/22481.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/22635/22635.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/22650-shell-crash.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/22656.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/22712.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/22743.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/22929-module-extensions-asi.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/22978-createargv-double-free.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/23022-stack-trace-iterator.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/23077/23077.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/23133.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/23139.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/23183.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/23275.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/23287-array-comma-value.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/23292.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/23314/zstd-async-compress.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/23314/zstd-large-decompression.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/23314/zstd-large-input.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/23316-long-path-spawn-shell.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/23316-long-path-spawn.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/23382.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/23474.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/23489.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/23569.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/23621.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/regression/issue/23649.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/23723.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/23865.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/24007.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/24045.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/24129.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/24131.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/24147.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/24157.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/24191.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/24234.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/24314.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/24329.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/24338.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/regression/issue/24339.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/24374.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/24385.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/regression/issue/24387.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/24388.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/24399.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/24502/bun-pm-ls-all-invalid-package-id.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/24575.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/24593.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/246-child_process_object_assign_compatibility.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/24709.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/24742.test.ts` | 🔧ohos-adapted ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/24806.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/24817.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/24850.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/24924.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/25190.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/25231.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/25398.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/25432.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/25589-frame-size-connect.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/25589-frame-size-grpc.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/25589-write-end.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/25589.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/regression/issue/25609.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/25622.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/25628.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/25639.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/25648.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/25707.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/25716.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/25750.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/regression/issue/25785.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/25794.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/25831.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/25862.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/25869.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/26030.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/26058.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/26063.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/26088.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/26125.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/26142.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/26143.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/26207.test.ts` |  ⊘1+1 | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/26284.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/26298.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/26337.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/26338.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/26358.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/26360.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/26377.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/26387.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/26411.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/26460.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/26631.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/regression/issue/26632.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/26647.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/26669.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/26844.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/26851.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/26915.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/27014.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/27025.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/27049.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/27061.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/27099.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/27117.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/27358.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/27389.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/27428.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/27431.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/27445.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/27458.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/27465.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/27478.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/27526.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/27553.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/27575.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/27598.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/27849.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/27890.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/27974.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/28004.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/28014.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/28017.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/28024.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/28042.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/28083.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/28170.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/28193.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/28431.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/28522.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/28632.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/28706.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/28756.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/28914.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/28948.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/regression/issue/28954.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/29072.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/29073.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/regression/issue/29120.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/29169.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/29181.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/29225.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/29240.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/29242.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/regression/issue/29264.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/29267/29267.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/29268.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/29283.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/29290.test.ts` | 🔧ohos-adapted ⊘2+2 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/29298.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/29371.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/29519.test.ts` |  ⊘1+1 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/29524.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/29585.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/29684.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/regression/issue/29780.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/29787.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/29925.test.ts` |  ⊘1+1 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/2993.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/regression/issue/30205.test.ts` |  ⊘4+4 | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/30429.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/30493.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/30717.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/30887.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/30963.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/31002.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/31401.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/31503.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/31575.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/31611.test.ts` |  ⊘1+1 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/31636.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/31652.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/3179.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/3192.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/32178.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/32489.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/32686.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/regression/issue/32728.test.ts` |  ⊘2+2 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/32734.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/32793.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/33227.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/34415.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/34485.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/3613.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/36450.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/3657.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/36577.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/38087.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/440.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/5228.test.js` |  ⊘2+2 | ✅4/0 | ✅4/0 | both-pass |  |
| `test/regression/issue/5344.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/5738.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/5961.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/8254.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/ENG-24434.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/atomics-waitasync-wtftimer-uaf.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/bundler-plugin-onresolve-entrypoint.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/circular-error-stack-edge-cases.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/circular-error-stack.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/comma-operator-this-binding.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/compile-outfile-subdirs.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/crypto-names.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/css-system-color-contexts.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/css-system-color-mix-crash.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/cyclic-imports-async-bundler.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/fix-bindings-stack-trace.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/fuzzer-ENG-22942.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/hashbang-still-works.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/htmlrewriter-additional-bugs.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/regression/issue/invalid-escape-sequences.test.ts` |  | ✅37/0 | ✅37/0 | both-pass |  |
| `test/regression/issue/isArray-proxy-crash.test.ts` |  ⊘1+1 | ✅9/0 | ✅9/0 | both-pass |  |
| `test/regression/issue/issue-12276.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/issue-1825-jest-mock-functions.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/jsx-template-string-crash.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/malformed-integrity-base64.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/minify-new-array-with-if.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/napi-exception-pending-crash.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/patch-bounds-check.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/pe-codesigning-integrity.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/regression/issue/postgres-null-byte-injection.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/postgres-stringbuilder-assertion-aggressive.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/prepare-stack-trace-crash.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/require-extensions-override.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/regression/issue/s3-header-injection.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/regression/issue/s3-signature-order.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/s3-signature-performance.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/server-stop-with-pending-requests.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/stdin-pause-resume.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/test-21049.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/regression/issue/test_env_loader_threading.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/text-chunk-null-access.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/regression/issue/tty-readstream-ref-unref.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/tty-reopen-after-stdin-eof.test.ts` |  ⊘2+2 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/tui-app-tty-pattern.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/update-interactive-formatting.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/regression/issue/utf16-encoding-crash.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue/yaml-parse-syntax-error.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |


## Bun API（509 文件 / 39 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/js/bun/io/bun-write.test.js` |  ⊘4+4 | ✅44/0 | ❌43/1 | B-only-fail | parked-data-correctness |
| `test/js/bun/bun-object/write.spec.ts` |  | ❌20/3 | ❌20/3 | both-fail | env-baseline |
| `test/js/bun/dns/resolve-dns.test.ts` | 🔧ohos-adapted ⊘1+1 | ❌69/11 | ❌67/13 | both-fail | env-baseline |
| `test/js/bun/ffi/cc.test.ts` | 🔧ohos-adapted ⊘16+16 | ❌4/16 | ❌4/16 | both-fail | env-baseline |
| `test/js/bun/glob/path-length.test.ts` |  ⊘2+2 | ❌3/2 | ❌3/2 | both-fail | env-baseline |
| `test/js/bun/glob/scan.test.ts` | 🔧ohos-adapted ⊘5+6 | ❌193/1 | ❌193/1 | both-fail | env-baseline |
| `test/js/bun/http/bun-listen-connect-args.test.ts` | 🔧ohos-adapted | ❌0/5 | ❌0/5 | both-fail | env-baseline |
| `test/js/bun/http/bun-serve-args.test.ts` | 🔧ohos-adapted ⊘1+1 | ❌50/9 | ❌50/9 | both-fail | env-baseline |
| `test/js/bun/http/bun-serve-file.test.ts` |  ⊘3+3 | ❌103/2 | ❌103/2 | both-fail | env-baseline |
| `test/js/bun/http/serve-http3.test.ts` |  ⊘1+1 | ❌49/1 | ❌49/1 | both-fail | env-baseline |
| `test/js/bun/http/serve-listen.test.ts` |  ⊘1+1 | ❌24/0 | ❌24/0 | both-fail | env-baseline |
| `test/js/bun/http/serve.test.ts` | 🔧ohos-adapted ⊘1+1 | ❌292/2 | ❌292/2 | both-fail | env-baseline |
| `test/js/bun/http/server-url-invalid.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/bun/net/socket.test.ts` |  ⊘9+9 | ❌86/4 | ❌86/4 | both-fail | env-baseline |
| `test/js/bun/net/unix-socket-unlink.test.ts` |  ⊘2+2 | ❌1/7 | ❌1/7 | both-fail | env-baseline |
| `test/js/bun/patch/patch.test.ts` |  | ❌26/1 | ❌13/14 | both-fail | env-baseline |
| `test/js/bun/repl/repl.test.ts` |  ⊘1+1 | ⏰360.4s | ⏰360.5s | both-fail | env-baseline |
| `test/js/bun/resolve/resolve.test.ts` |  ⊘6+6 | ❌9/0 | ❌9/0 | both-fail | env-baseline |
| `test/js/bun/resolve/resolver-permission-denied-ancestor.test.ts` |  ⊘1+1 | ❌1/1 | ❌0/2 | both-fail | env-baseline |
| `test/js/bun/s3/s3-list-objects.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/bun/s3/s3.leak.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/bun/s3/s3.test.ts` |  ⊘5+5 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/bun/shell/bunshell-instance.test.ts` |  | ❌16/1 | ❌16/1 | both-fail | env-baseline |
| `test/js/bun/shell/bunshell.test.ts` |  ⊘1+1 | ❌421/1 | ❌421/1 | both-fail | env-baseline |
| `test/js/bun/shell/commands/rm.test.ts` | 🔧ohos-adapted ⊘3+3 | ❌7/2 | ❌7/2 | both-fail | env-baseline |
| `test/js/bun/shell/pipeline_stack.test.ts` | 🔧ohos-adapted | ❌61/2 | ❌61/2 | both-fail | env-baseline |
| `test/js/bun/shell/shell-load.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/bun/spawn/spawn-cgroup.test.ts` |  ⊘3+3 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/bun/spawn/spawn-maxbuf.test.ts` |  ⊘1+1 | ❌12/4 | ❌14/2 | both-fail | env-baseline |
| `test/js/bun/spawn/spawn-pipe-leak.test.ts` | 🔧ohos-adapted | ❌0/3 | ❌2/1 | both-fail | env-baseline |
| `test/js/bun/spawn/spawn-stdin-readable-stream.test.ts` | 🔧ohos-adapted ⊘1+1 | ❌35/1 | ❌35/1 | both-fail | env-baseline |
| `test/js/bun/spawn/spawn.test.ts` | 🔧ohos-adapted ⊘15+15 | ⏰360.4s | ❌135/1 | both-fail | env-baseline |
| `test/js/bun/spawn/spawnSync.test.ts` |  ⊘5+5 | ❌3/2 | ❌4/1 | both-fail | env-baseline |
| `test/js/bun/terminal/terminal-platform-gaps.test.ts` |  | ❌16/3 | ⏰360.4s | both-fail | env-baseline |
| `test/js/bun/terminal/terminal-spawn.test.ts` |  ⊘5+5 | ❌12/4 | ⏰360.3s | both-fail | env-baseline |
| `test/js/bun/terminal/terminal.test.ts` |  ⊘6+6 | ❌89/7 | ⏰360.3s | both-fail | env-baseline |
| `test/js/bun/util/filesink.test.ts` | 🔧ohos-adapted ⊘11+11 | ❌34/18 | ❌34/18 | both-fail | env-baseline |
| `test/js/bun/util/mmap.test.js` | 🔧ohos-adapted ⊘1+1 | ❌20/1 | ❌20/1 | both-fail | env-baseline |
| `test/js/bun/websocket/websocket-server.test.ts` |  | ❌86/31 | ❌116/1 | both-fail | env-baseline |
| `test/js/bun/shell/shell-hang.test.ts` |  | ❌0/6 | ✅6/0 | A-only-fail |  |
| `test/js/bun/spawn/spawn-streaming-stdin.test.ts` |  | ❌0/1 | ✅1/0 | A-only-fail |  |
| `test/js/bun/util/sleep.test.ts` |  | ❌1/1 | ✅2/0 | A-only-fail |  |
| `test/js/bun/archive.test.ts` |  ⊘3+3 | ✅106/0 | ✅106/0 | both-pass |  |
| `test/js/bun/binary/tls-segment-size.test.ts` | 🔧ohos-adapted ⊘2+2 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/bun-object/deep-equals-temporal.test.ts` |  | ✅77/0 | ✅77/0 | both-pass |  |
| `test/js/bun/bun-object/deep-equals.test.ts` |  ⊘2+2 | ✅44/0 | ✅44/0 | both-pass |  |
| `test/js/bun/bun-object/deep-match.spec.ts` |  ⊘1+1 | ✅47/0 | ✅47/0 | both-pass |  |
| `test/js/bun/bundler/yaml-bundler.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/compile/standalone-madvise-tla.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/console/bun-inspect-table.test.ts` |  | ✅35/0 | ✅35/0 | both-pass |  |
| `test/js/bun/console/console-iterator.test.ts` |  | ✅17/0 | ✅17/0 | both-pass |  |
| `test/js/bun/console/console-table.test.ts` |  ⊘1+1 | ✅32/0 | ✅32/0 | both-pass |  |
| `test/js/bun/console/console-write.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/cookie/cookie-exotic-inputs.test.ts` |  | ✅24/0 | ✅24/0 | both-pass |  |
| `test/js/bun/cookie/cookie-expires-validation.test.ts` |  | ✅22/0 | ✅22/0 | both-pass |  |
| `test/js/bun/cookie/cookie-map.test.ts` |  | ✅33/0 | ✅33/0 | both-pass |  |
| `test/js/bun/cookie/cookie-security-fuzz.test.ts` |  | ✅47/0 | ✅47/0 | both-pass |  |
| `test/js/bun/cookie/cookie.test.ts` |  | ✅35/0 | ✅35/0 | both-pass |  |
| `test/js/bun/cron/cron-local-time.test.ts` |  | ✅30/0 | ✅30/0 | both-pass |  |
| `test/js/bun/cron/cron-parse.test.ts` |  | ✅23/0 | ✅23/0 | both-pass |  |
| `test/js/bun/cron/cron.test.ts` |  ⊘11+11 | ✅54/0 | ✅54/0 | both-pass |  |
| `test/js/bun/cron/in-process-cron.test.ts` |  | ✅27/0 | ✅27/0 | both-pass |  |
| `test/js/bun/crypto/cipheriv-decipheriv.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/bun/crypto/wpt-webcrypto.generateKey.test.ts` |  | ✅10226/0 | ✅10226/0 | both-pass |  |
| `test/js/bun/crypto/x25519-derive-bits.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/bun/css/angle-serialization-hang.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/css/atan2-backtracking-hang.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/css/attr-selector-namespace-star.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/css/color.test.ts` |  ⊘1+1 | ✅1023/0 | ✅1023/0 | both-pass |  |
| `test/js/bun/css/css-fuzz.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/css/css-loader.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/css/css.test.ts` |  ⊘1+1 | ✅1181/0 | ✅1181/0 | both-pass |  |
| `test/js/bun/css/custom-pseudo-ident-escape.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/bun/css/doesnt_crash.test.ts` |  | ✅61/0 | ✅61/0 | both-pass |  |
| `test/js/bun/css/duplicate-declaration-merge-hang.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/css/invalid-utf8-column.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/css/nested-function-backtracking.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/css/nested-selector-expansion.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/css/nested-selector-list-expansion.test.ts` |  | ✅24/0 | ✅24/0 | both-pass |  |
| `test/js/bun/css/nested-vendor-prefix-duplication.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/bun/css/nth-anplusb-ident.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/css/selector-list-error-recovery.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/bun/css/small-list-grow.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/css/supports-condition-newline.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/css/token-list-backtracking.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/dns/dns-interleave.test.ts` |  ⊘1+1 | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/dns/dns-prefetch.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/empty-file.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/fetch/node-use-system-ca.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/ffi/addr32.test.ts` | 🔧ohos-adapted ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/ffi/ffi-error-messages.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/ffi/ffi-viewSource-non-object.test.ts` |  | ✅28/0 | ✅28/0 | both-pass |  |
| `test/js/bun/ffi/ffi.test.js` |  ⊘6+6 | ✅147/0 | ✅147/0 | both-pass |  |
| `test/js/bun/ffi/mh-execute-header.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/gc/gc-controller-cadence.test.ts` |  ⊘1+1 | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/glob/leak.test.ts` | 🔧ohos-adapted | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/glob/match.test.ts` |  | ✅29/0 | ✅29/0 | both-pass |  |
| `test/js/bun/glob/proto.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/glob/stress.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/globals.test.js` |  | ✅20/0 | ✅20/0 | both-pass |  |
| `test/js/bun/http/async-iterator-stream.test.ts` |  | ✅91/0 | ✅91/0 | both-pass |  |
| `test/js/bun/http/bun-connect-x509.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/http/bun-serve-body-json-async.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/bun-serve-cookies.test.ts` |  | ✅25/0 | ✅25/0 | both-pass |  |
| `test/js/bun/http/bun-serve-date.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/bun-serve-fetch-invalid-args.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/bun-serve-headers.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/http/bun-serve-html-405.test.ts` |  ⊘2+2 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/bun-serve-html-build-holds-server.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/http/bun-serve-html-entry.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/bun/http/bun-serve-html-hot-reload-drop.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/bun-serve-html-manifest.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/http/bun-serve-html.test.ts` |  | ✅21/0 | ✅21/0 | both-pass |  |
| `test/js/bun/http/bun-serve-propagate-errors.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/bun-serve-routes.test.ts` |  | ✅61/0 | ✅61/0 | both-pass |  |
| `test/js/bun/http/bun-serve-ssl.test.ts` |  | ✅18/0 | ✅18/0 | both-pass |  |
| `test/js/bun/http/bun-serve-static-stress-access-body.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/bun/http/bun-serve-static-stress-no-body.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/bun/http/bun-serve-static.test.ts` |  | ✅46/0 | ✅46/0 | both-pass |  |
| `test/js/bun/http/bun-server.test.ts` |  ⊘1+1 | ✅78/0 | ✅78/0 | both-pass |  |
| `test/js/bun/http/decodeURIComponentSIMD.test.ts` |  | ✅229/0 | ✅229/0 | both-pass |  |
| `test/js/bun/http/fetch-abort-ssl-context-eviction.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/fetch-file-upload.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/bun/http/fetch-header-count-limit.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/http/form-data-set-append.test.js` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/http/getIfPropertyExists.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/http/hspec.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/http-server-chunking.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/http/leaks-test.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/http/listener-getsockname.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/http/node-http-halfclose-midupload.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/http/node-http2-ping-flood-staged.test.ts` |  ⊘1+1 | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/http/proxy-stress-adversarial.test.ts` |  | ✅151/0 | ✅151/0 | both-pass |  |
| `test/js/bun/http/proxy-stress-concurrent.test.ts` |  | ✅43/0 | ✅43/0 | both-pass |  |
| `test/js/bun/http/proxy-stress-errors.test.ts` |  | ✅53/0 | ✅53/0 | both-pass |  |
| `test/js/bun/http/proxy-stress-headers.test.ts` |  | ✅76/0 | ✅76/0 | both-pass |  |
| `test/js/bun/http/proxy-stress-lifecycle.test.ts` |  ⊘1+1 | ✅92/0 | ✅92/0 | both-pass |  |
| `test/js/bun/http/proxy-stress-matrix.test.ts` |  | ✅335/0 | ✅335/0 | both-pass |  |
| `test/js/bun/http/proxy-stress-protocol.test.ts` |  ⊘1+1 | ✅102/0 | ✅102/0 | both-pass |  |
| `test/js/bun/http/proxy.test.js` |  | ✅16/0 | ✅16/0 | both-pass |  |
| `test/js/bun/http/proxy.test.ts` |  ⊘1+1 | ✅67/0 | ✅67/0 | both-pass |  |
| `test/js/bun/http/req-url-leak.test.ts` | 🔧ohos-adapted | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/request-smuggling.test.ts` |  | ✅87/0 | ✅87/0 | both-pass |  |
| `test/js/bun/http/serve-async-stream-client-abort.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/http/serve-body-leak.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/bun/http/serve-close-delimited-framing.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/http/serve-direct-readable-stream.test.ts` |  ⊘4+4 | ✅20/0 | ✅20/0 | both-pass |  |
| `test/js/bun/http/serve-directory-routes.test.ts` | 🔧ohos-adapted ⊘3+3 | ✅28/0 | ✅28/0 | both-pass |  |
| `test/js/bun/http/serve-epoll-add-fail.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/http/serve-error-handler-stream.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/bun/http/serve-file-slice-read-error.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/http/serve-if-none-match.test.ts` |  | ✅28/0 | ✅28/0 | both-pass |  |
| `test/js/bun/http/serve-pending-promise-abort-leak.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/http/serve-protocols.test.ts` |  | ✅20/0 | ✅20/0 | both-pass |  |
| `test/js/bun/http/serve-request-extra-memory.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/serve-response-gc-backpressure-abort.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/http/serve-response-stream-sink-leak.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/serve-reused-response.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/bun/http/serve-stream-body-error.test.ts` |  ⊘1+1 | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/bun/http/serve-stream-reject-flush-leak.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/serve-syscall-fault.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/http/tls-bunfile-leak.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/http/tls-keepalive.test.ts` |  ⊘1+1 | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/image/image-adversarial.test.ts` |  | ✅61/0 | ✅61/0 | both-pass |  |
| `test/js/bun/image/image-kernels.test.ts` |  | ✅37/0 | ✅37/0 | both-pass |  |
| `test/js/bun/image/image-vs-sharp.test.ts` |  | ✅29/0 | ✅29/0 | both-pass |  |
| `test/js/bun/image/image.test.ts` |  ⊘2+2 | ✅95/0 | ✅95/0 | both-pass |  |
| `test/js/bun/import-attributes/import-attributes.test.ts` | 🔧slow-device-timeout | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/bun/ini/ini.test.ts` |  | ✅62/0 | ✅62/0 | both-pass |  |
| `test/js/bun/io/bun-write-leak.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/io/fetch/fetch-abort-slow-connect.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/jsc-stress/jsc-stress.test.ts` |  ⊘1+1 | ✅83/0 | ✅83/0 | both-pass |  |
| `test/js/bun/jsc-stress/testFFI.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/jsc/bun-jsc.test.ts` |  | ✅38/0 | ✅38/0 | both-pass |  |
| `test/js/bun/jsc/domjit.test.ts` |  | ✅50/0 | ✅50/0 | both-pass |  |
| `test/js/bun/jsc/heapStats-mimalloc.test.ts` |  ⊘1+1 | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/jsc/native-constructor-identity.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/jsc/shadow.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/jsc/string-noAtomize.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/jsc/temporal-global.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/jsc/webkit-upgrade-3722912f.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/json5/json5-test-suite.test.ts` |  | ✅113/0 | ✅113/0 | both-pass |  |
| `test/js/bun/json5/json5.test.ts` |  | ✅321/0 | ✅321/0 | both-pass |  |
| `test/js/bun/jsonc/json-differential-fuzz.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/jsonc/json-test-suite.test.ts` |  | ✅319/0 | ✅319/0 | both-pass |  |
| `test/js/bun/jsonc/jsonc.test.ts` |  | ✅48/0 | ✅48/0 | both-pass |  |
| `test/js/bun/jsonl/jsonl-parse.test.ts` |  | ✅269/0 | ✅269/0 | both-pass |  |
| `test/js/bun/md/gfm-compat.test.ts` |  | ✅62/0 | ✅62/0 | both-pass |  |
| `test/js/bun/md/md-edge-cases.test.ts` |  | ✅84/0 | ✅84/0 | both-pass |  |
| `test/js/bun/md/md-heading-ids.test.ts` |  | ✅17/0 | ✅17/0 | both-pass |  |
| `test/js/bun/md/md-react.test.ts` |  | ✅73/0 | ✅73/0 | both-pass |  |
| `test/js/bun/md/md-render-callback.test.ts` |  | ✅40/0 | ✅40/0 | both-pass |  |
| `test/js/bun/md/md-spec.test.ts` |  | ✅792/0 | ✅792/0 | both-pass |  |
| `test/js/bun/memfd-disabled.test.ts` |  ⊘2+2 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/namespace-prototype-pollution.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/net/localhost-loopback-contract.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/net/named-pipe-listen-error.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/net/socket-dns-error.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/net/socket-retention.test.ts` |  ⊘1+1 | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/net/socket-syscall-fault.test.ts` |  ⊘4+4 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/net/tcp-server.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/bun/net/unix-socket-long-path.test.ts` | 🔧other-adapted ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/perf/linker-order.test.ts` |  ⊘6+6 | ✅23/0 | ✅23/0 | both-pass |  |
| `test/js/bun/perf/static-initializers.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/perf_hooks/histogram.test.ts` |  | ✅38/0 | ✅38/0 | both-pass |  |
| `test/js/bun/plugin/plugin-namespace-drive-letter.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/plugin/plugins.test.ts` |  | ✅42/0 | ✅42/0 | both-pass |  |
| `test/js/bun/resolve/build-error.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/resolve/builtin-esm-lazy-exports.test.ts` |  | ✅15/0 | ✅15/0 | both-pass |  |
| `test/js/bun/resolve/bun-lock.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/resolve/bun-main-entry-point.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/resolve/concurrent-dynamic-import.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/resolve/dynamic-import-tla-cycle.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/resolve/esModule-annotation.test.js` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/bun/resolve/esModule.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/resolve/import-custom-condition.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/bun/resolve/import-defer.test.ts` |  | ✅20/0 | ✅20/0 | both-pass |  |
| `test/js/bun/resolve/import-empty.test.js` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/bun/resolve/import-meta-resolve.test.mjs` |  | ✅15/0 | ✅15/0 | both-pass |  |
| `test/js/bun/resolve/import-meta.test.js` |  | ✅32/0 | ✅32/0 | both-pass |  |
| `test/js/bun/resolve/import-query.test.ts` |  | ✅15/0 | ✅15/0 | both-pass |  |
| `test/js/bun/resolve/json5/json5.test.js` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/resolve/jsonc.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/resolve/load-file-loader-a-lot.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/resolve/load-same-js-file-a-lot.test.ts` | 🔧ohos-adapted | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/resolve/lower-using-bun-target.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/bun/resolve/non-english-import.test.js` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/resolve/png/test-png-import.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/resolve/require-esm-gc-roots.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/resolve/require-esm-microtask-order.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/resolve/require-esm-transitive-tla.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/resolve/require.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/bun/resolve/resolve-autoinstall-invalid-name.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/resolve/resolve-autoinstall-log-dangling.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/resolve/resolve-bad-parent.test.mjs` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/resolve/resolve-error.test.ts` |  | ✅22/0 | ✅22/0 | both-pass |  |
| `test/js/bun/resolve/resolve-ts.test.ts` |  | ✅27/0 | ✅27/0 | both-pass |  |
| `test/js/bun/resolve/star-export-namespace.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/resolve/toml/crash/toml-crash.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/resolve/toml/toml-parse.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/bun/resolve/toml/toml.test.js` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/bun/resolve/tsconfig-extends-leak.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/resolve/xml/xml.test.js` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/bun/resolve/yaml/yaml.test.js` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/runtime-error.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/s3/s3-argument-validation.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/js/bun/s3/s3-connection-close.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/bun/s3/s3-fd-validation.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/s3/s3-insecure.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/s3/s3-list-checksum-algorithm.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/s3/s3-list-encode-overflow.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/bun/s3/s3-numeric-options-coerce.test.ts` |  | ✅17/0 | ✅17/0 | both-pass |  |
| `test/js/bun/s3/s3-queueSize-validation.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/s3/s3-requester-pays.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/bun/s3/s3-storage-class.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/bun/s3/s3-stream-cancel-leak.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/s3/s3-stream-error-gc.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/s3/s3-write-to-file-sync-close.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/secrets-error-codes.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/secrets.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/shell/assignments-in-pipeline.test.ts` |  | ✅38/0 | ✅38/0 | both-pass |  |
| `test/js/bun/shell/brace.test.ts` |  | ✅43/0 | ✅43/0 | both-pass |  |
| `test/js/bun/shell/bunshell-default.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/shell/bunshell-file.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/shell/commands/basename.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/bun/shell/commands/cp.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/shell/commands/dirname.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/bun/shell/commands/echo.test.ts` |  | ✅22/0 | ✅22/0 | both-pass |  |
| `test/js/bun/shell/commands/exit.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/bun/shell/commands/false.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/shell/commands/ls.test.ts` | 🔧other-adapted | ✅22/0 | ✅22/0 | both-pass |  |
| `test/js/bun/shell/commands/mkdir.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/shell/commands/mv.test.ts` | 🔧ohos-adapted ⊘7+8 | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/shell/commands/seq.test.ts` |  ⊘1+1 | ✅31/0 | ✅31/0 | both-pass |  |
| `test/js/bun/shell/commands/touch.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/shell/commands/true.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/shell/commands/which.test.ts` |  ⊘1+1 | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/shell/commands/yes.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/shell/env.positionals.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/shell/epipe.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/shell/exec.test.ts` |  | ✅19/0 | ✅19/0 | both-pass |  |
| `test/js/bun/shell/file-io.test.ts` |  | ✅26/0 | ✅26/0 | both-pass |  |
| `test/js/bun/shell/lazy.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/shell/leak.test.ts` | 🔧ohos-adapted | ✅35/0 | ✅35/0 | both-pass |  |
| `test/js/bun/shell/lex.test.ts` |  | ✅43/0 | ✅43/0 | both-pass |  |
| `test/js/bun/shell/parse.test.ts` |  | ✅18/0 | ✅18/0 | both-pass |  |
| `test/js/bun/shell/shell-blocking-pipe.test.ts` |  ⊘2+2 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/shell/shell-cmdsub-crash.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/shell/shell-leak-args.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/shell/shell-pipe-read-fault.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/shell/shell-sentinel-hardening.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/shell/shell-seq-condexpr.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/shell/shell-worker-terminate-leak.test.ts` |  ⊘7+7 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/shell/shell-write-fault.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/shell/shelloutput.test.ts` |  ⊘1+1 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/shell/throw.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/shell/yield.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/sourcemap/internal-sourcemap-roundtrip.test.ts` |  | ✅22/0 | ✅22/0 | both-pass |  |
| `test/js/bun/sourcemap/internal-sourcemap.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/sourcemap/negative-vlq-mapping.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/bun/spawn/bun-ipc-inherit.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/exit-code.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/spawn/job-object-bug.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/null-byte-injection.test.ts` |  | ✅20/0 | ✅20/0 | both-pass |  |
| `test/js/bun/spawn/pidfd-exit-nested-tick.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/spawn/readablestream-helpers.test.ts` |  | ✅30/0 | ✅30/0 | both-pass |  |
| `test/js/bun/spawn/spawn-empty-arrayBufferOrBlob.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/spawn/spawn-env.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn-ipc-gc.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn-kill-signal.test.ts` |  | ✅16/0 | ✅16/0 | both-pass |  |
| `test/js/bun/spawn/spawn-large-array-length.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/spawn/spawn-many-teardown.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn-noread-leak.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn-path.test.ts` |  ⊘2+2 | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/spawn/spawn-pipe-read-error-leak.test.ts` | 🔧ohos-adapted ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn-pipe-stale-fd-unregister.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn-pipe-start-error.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/spawn/spawn-renamed-cwd.test.ts` |  ⊘2+2 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/spawn/spawn-signal.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/bun/spawn/spawn-socketpair-shutdown.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/spawn/spawn-stdin-destroy.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn-stdin-pipe-fd-leak.test.ts` |  ⊘3+3 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn-stdin-readable-stream-edge-cases.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/bun/spawn/spawn-stdin-readable-stream-integration.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/spawn/spawn-stdin-readable-stream-sync.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn-stdout-filereader-gc-uaf.test.ts` |  ⊘3+3 | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/spawn/spawn-stdout-iterate-leak.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/spawn/spawn-stream-serve.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn-streaming-stdout.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn-stress.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn-unread-stdout-gc.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn.ipc.bun-node.test.ts` |  ⊘2+2 | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/spawn/spawn.ipc.node-bun.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawn.ipc.test.ts` |  ⊘2+2 | ✅15/0 | ✅15/0 | both-pass |  |
| `test/js/bun/spawn/spawn_waiter_thread.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/spawn/spawnsync-isolated-event-loop.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/spawn/spawnsync-no-microtask-drain.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/sqlite/column-types.test.js` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/bun/sqlite/sql-timezone.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/sqlite/sqlite.test.js` |  ⊘1+1 | ✅122/0 | ✅122/0 | both-pass |  |
| `test/js/bun/stream/direct-readable-stream.test.tsx` |  ⊘3+3 | ✅269/0 | ✅269/0 | both-pass |  |
| `test/js/bun/symbols.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/sys/error-name-from-libuv.test.ts` |  ⊘2+2 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/sys/fstat-windows-crt-fd-leak.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/test/bun-test.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/test/bun_test.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/bun/test/ci-restrictions.test.ts` |  ⊘1+1 | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/bun/test/concurrent.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/test/concurrent_immediate.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/test/describe.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/js/bun/test/done-async.test.ts` |  | ✅0/7 | ✅0/7 | both-pass |  |
| `test/js/bun/test/dots.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/test/expect-assertions.test.ts` |  | ✅0/5 | ✅0/5 | both-pass |  |
| `test/js/bun/test/expect-extend-asymmetric-match-throw.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/expect-extend-preload.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/expect-extend.test.js` |  | ✅28/0 | ✅28/0 | both-pass |  |
| `test/js/bun/test/expect-failure-message-angle-brackets.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/test/expect-formdata-tojson-crash.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/expect-label.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/test/expect-stack-overflow-crash.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/expect-symbol-toPrimitive-crash.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/expect-toHaveReturnedWith.test.js` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/js/bun/test/expect-type-doctest.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/test/expect-type-global.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/expect-type.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/expect-unreaachable.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/expect.test.js` |  | ✅415/0 | ✅415/0 | both-pass |  |
| `test/js/bun/test/expect/huge-failure-message.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/expect/toHaveReturnedWith.test.ts` |  | ✅42/0 | ✅42/0 | both-pass |  |
| `test/js/bun/test/failure-skip.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/bun/test/fake-timers/fake-timers.test.ts` |  | ✅47/0 | ✅47/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/fake-timers.test.ts` |  ⊘38+38 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-1852.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-187.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-207.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-2086.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-2449.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-276.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-315.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-347.test.ts` |  ⊘1+1 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-368.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-437.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-504.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-516.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-59.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-67.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/test/fake-timers/sinonjs/issue-73.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/jest-each-gc-root.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/jest-each.test.ts` |  | ✅25/0 | ✅25/0 | both-pass |  |
| `test/js/bun/test/jest-extended.test.js` |  | ✅58/0 | ✅58/0 | both-pass |  |
| `test/js/bun/test/jest-hooks.test.ts` |  | ✅17/0 | ✅17/0 | both-pass |  |
| `test/js/bun/test/mock-disposable.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/test/mock-fn.test.js` |  | ✅83/0 | ✅83/0 | both-pass |  |
| `test/js/bun/test/mock/6874/A.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/mock/6874/B.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/mock/6879/6879.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/test/mock/mock-module-non-string.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/test/mock/mock-module-resolve-log.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/mock/mock-module.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/bun/test/nested-describes.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/test/only-failures.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/test/only-inside-only.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/preload-test.test.js` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/test/pretty-format-overflow.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/printing/diffexample.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/test/snapshot-tests/bun-snapshots.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/test/snapshot-tests/existing-snapshots.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/snapshot-tests/new-snapshot.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/spyMatchers.test.ts` |  | ✅150/0 | ✅150/0 | both-pass |  |
| `test/js/bun/test/stack.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/test/test-auto-import-jest-globals.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/test/test-error-code-done-callback.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/test-failing.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/bun/test/test-on-test-finished.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/bun/test/test-only.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/test-retry-repeats-basic.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/test/test-test.test.ts` |  ⊘11+11 | ✅24/0 | ✅24/0 | both-pass |  |
| `test/js/bun/test/test-timers.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/bun/toml/toml-test-suite.test.ts` |  | ✅708/0 | ✅708/0 | both-pass |  |
| `test/js/bun/toml/toml.test.ts` |  | ✅99/0 | ✅99/0 | both-pass |  |
| `test/js/bun/transpiler/parse-error-column.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/bun/transpiler/repl-transform.test.ts` |  | ✅36/0 | ✅36/0 | both-pass |  |
| `test/js/bun/transpiler/source-too-large.test.ts` |  ⊘1+1 | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/transpiler/transpiler-comma-chain-oom.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/transpiler/transpiler-error-gc-uaf.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/transpiler/transpiler-radix-bigint.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/transpiler/transpiler-truncated-utf8.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/transpiler/transpiler-tsconfig-uaf.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/transpiler/transpiler-unsupported-loader.test.ts` |  | ✅33/0 | ✅33/0 | both-pass |  |
| `test/js/bun/transpiler/transpiler-utf16-loader.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/typescript/type-export.test.ts` |  | ✅70/0 | ✅70/0 | both-pass |  |
| `test/js/bun/udp/dgram.test.ts` |  ⊘11+11 | ✅61/0 | ✅61/0 | both-pass |  |
| `test/js/bun/udp/udp_socket.test.ts` | 🔧ohos-adapted | ✅207/0 | ✅207/0 | both-pass |  |
| `test/js/bun/udp/udp_socket_recv_flags.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/util/BunObject.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/util/arraybuffersink.test.ts` |  ⊘1+1 | ✅13/0 | ✅13/0 | both-pass |  |
| `test/js/bun/util/base64-url-safe-encode.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/util/bun-cryptohasher.test.ts` |  | ✅403/0 | ✅403/0 | both-pass |  |
| `test/js/bun/util/bun-file-exists.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/util/bun-file-fd-read.test.ts` |  ⊘1+1 | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/util/bun-file-read.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/util/bun-file-windows.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/util/bun-file.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/util/bun-isMainThread.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/util/bun-main.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/util/bun-stdin-slice.test.ts` |  ⊘2+2 | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/bun/util/bunstring-tothreadsafe.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/util/concat.test.js` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/util/cookie.test.js` |  ⊘3+3 | ✅101/0 | ✅101/0 | both-pass |  |
| `test/js/bun/util/csrf.test.ts` |  | ✅25/0 | ✅25/0 | both-pass |  |
| `test/js/bun/util/error-code-mirror.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/util/error-gc-test.test.js` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/util/error-name-preservation.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/util/escapeHTML.test.js` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/bun/util/escapeRegExp.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/util/exotic-global-mutable-prototype.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/util/file-type.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/util/fileUrl.test.js` |  | ✅20/0 | ✅20/0 | both-pass |  |
| `test/js/bun/util/filesystem_router.test.ts` |  ⊘2+2 | ✅33/0 | ✅33/0 | both-pass |  |
| `test/js/bun/util/fuzzilli-reprl.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/util/hash.test.js` |  | ✅20/0 | ✅20/0 | both-pass |  |
| `test/js/bun/util/heap-snapshot.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/bun/util/highlighter.test.ts` |  | ✅16/0 | ✅16/0 | both-pass |  |
| `test/js/bun/util/highway-strings.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/bun/util/index-of-line.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/util/inspect-error-leak.test.js` | 🔧ohos-adapted | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/util/inspect-error.test.js` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/bun/util/inspect.test.js` |  ⊘1+1 | ✅78/0 | ✅78/0 | both-pass |  |
| `test/js/bun/util/open-in-editor-gc.test.ts` |  ⊘3+3 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/util/password.test.ts` |  ⊘3+3 | ✅84/0 | ✅84/0 | both-pass |  |
| `test/js/bun/util/pathToFileURL-invalid.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/util/peek.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/util/randomUUIDv5.test.ts` |  | ✅40/0 | ✅40/0 | both-pass |  |
| `test/js/bun/util/randomUUIDv7.test.ts` |  | ✅20/0 | ✅20/0 | both-pass |  |
| `test/js/bun/util/readablestreamtoarraybuffer.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/util/reportError.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/util/sleepSync.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/util/sliceAnsi-fuzz.test.ts` |  | ✅48/0 | ✅48/0 | both-pass |  |
| `test/js/bun/util/sliceAnsi.test.ts` |  | ✅166/0 | ✅166/0 | both-pass |  |
| `test/js/bun/util/socket-fault-injection.test.ts` |  ⊘3+3 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/util/stringWidth.test.ts` |  | ✅173/0 | ✅173/0 | both-pass |  |
| `test/js/bun/util/stripANSI.test.ts` |  | ✅296/0 | ✅296/0 | both-pass |  |
| `test/js/bun/util/text-loader.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/bun/util/toUTF16Alloc.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/util/unsafe.test.js` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/bun/util/v8-heap-snapshot.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/bun/util/which.test.ts` |  ⊘1+1 | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/util/wrapAnsi.npm.test.ts` |  | ✅23/0 | ✅23/0 | both-pass |  |
| `test/js/bun/util/wrapAnsi.test.ts` |  | ✅248/0 | ✅248/0 | both-pass |  |
| `test/js/bun/util/zstd.test.ts` |  ⊘1+1 | ✅88/0 | ✅88/0 | both-pass |  |
| `test/js/bun/wasm/wasi.test.js` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/websocket/websocket-server-backpressure-buffer.test.ts` |  ⊘1+1 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/websocket/websocket-server-reload-leak.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/websocket/websocket-server-rsv-frames.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/bun/websocket/websocket-server-stop-retained-ws.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/websocket/websocket-server-unmasked-frames.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/websocket/websocket-server-upgrade-reentrant.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/bun/websocket/websocket-upgrade-signal-gc.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/bun/webview/webview-chrome-disconnect.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/bun/webview/webview-chrome-pipe.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/bun/webview/webview-chrome-ws.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/webview/webview-chrome.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/bun/webview/webview.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/bun/windows/appcontainer.test.ts` |  ⊘2+2 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/bun/xml/xml-test-suite.test.ts` |  | ✅1995/0 | ✅1995/0 | both-pass |  |
| `test/js/bun/xml/xml.test.ts` |  | ✅58/0 | ✅58/0 | both-pass |  |
| `test/js/bun/yaml/yaml-block-scalar-matrix.test.ts` |  | ✅1084/0 | ✅1084/0 | both-pass |  |
| `test/js/bun/yaml/yaml-test-suite.test.ts` |  | ✅402/0 | ✅402/0 | both-pass |  |
| `test/js/bun/yaml/yaml.test.ts` |  | ✅643/0 | ✅643/0 | both-pass |  |


## Node 兼容（314 文件 / 22 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/js/node/child_process/child-process-exec.test.ts` |  | ✅11/0 | ❌10/1 | B-only-fail | rotation-single-case |
| `test/js/node/child_process/child-process-rlimit-nofile.test.ts` | 🔧ohos-adapted | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/node/child_process/child_process.test.ts` | 🔧ohos-adapted ⊘11+11 | ❌56/3 | ❌56/3 | both-fail | env-baseline |
| `test/js/node/cluster.test.ts` |  ⊘10+10 | ❌25/6 | ❌25/6 | both-fail | env-baseline |
| `test/js/node/fs/cp.test.ts` |  ⊘8+8 | ❌41/4 | ❌41/4 | both-fail | env-baseline |
| `test/js/node/fs/fs-mkdir.test.ts` |  ⊘2+2 | ❌20/1 | ❌20/1 | both-fail | env-baseline |
| `test/js/node/fs/fs.test.ts` | 🔧ohos-adapted ⊘20+26 | ❌493/11 | ❌498/6 | both-fail | env-baseline |
| `test/js/node/http/node-http-connect.test.ts` |  ⊘2+2 | ❌7/0 | ❌7/0 | both-fail | env-baseline |
| `test/js/node/http/node-http.test.ts` | 🔧ohos-adapted ⊘1+2 | ❌143/2 | ❌143/2 | both-fail | env-baseline |
| `test/js/node/module/node-module-module.test.js` |  ⊘5+5 | ❌35/6 | ❌35/6 | both-fail | env-baseline |
| `test/js/node/net/handle-leak.test.ts` |  | ⏰360.3s | ⏰360.3s | both-fail | env-baseline |
| `test/js/node/net/node-net-allowHalfOpen.test.js` |  ⊘1+1 | ❌2/1 | ❌2/1 | both-fail | env-baseline |
| `test/js/node/net/node-net-server.test.ts` |  | ❌19/3 | ❌19/3 | both-fail | env-baseline |
| `test/js/node/net/node-net.test.ts` |  ⊘8+8 | ❌69/7 | ❌69/7 | both-fail | env-baseline |
| `test/js/node/net/server.spec.ts` | 🔧ohos-adapted ⊘4+6 | ❌36/2 | ❌36/2 | both-fail | env-baseline |
| `test/js/node/os/os.test.js` | 🔧ohos-adapted | ❌52/1 | ❌52/1 | both-fail | env-baseline |
| `test/js/node/process/dlopen-duplicate-load.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/node/process/process-stdin.test.ts` | 🔧ohos-adapted ⊘1+1 | ❌17/1 | ❌17/1 | both-fail | env-baseline |
| `test/js/node/process/process.test.js` | 🔧ohos-adapted ⊘10+10 | ❌162/7 | ❌163/6 | both-fail | env-baseline |
| `test/js/node/tls/node-tls-server.test.ts` | 🔧ohos-adapted ⊘0+1 | ❌73/1 | ❌73/1 | both-fail | env-baseline |
| `test/js/node/tty.test.ts` |  ⊘3+3 | ❌6/1 | ⏰360.2s | both-fail | env-baseline |
| `test/js/node/watch/fs.watch.test.ts` | 🔧ohos-adapted ⊘13+13 | ❌38/3 | ❌36/5 | both-fail | env-baseline |
| `test/js/node/module/sourcemap-simd.test.ts` |  | ❌23/1 | ✅24/0 | A-only-fail |  |
| `test/js/node/assert/assert-doesNotMatch.test.cjs` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/assert/assert-match.test.cjs` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/assert/assert-promise.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/node/assert/assert-typedarray-deepequal.test.ts` |  | ✅45/0 | ✅45/0 | both-pass |  |
| `test/js/node/assert/assert.spec.ts` |  | ✅28/0 | ✅28/0 | both-pass |  |
| `test/js/node/assert/assert.test.cjs` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/node/assert/deep-equal.test.ts` |  | ✅305/0 | ✅305/0 | both-pass |  |
| `test/js/node/async_hooks/AsyncLocalStorage-tracking.test.ts` |  | ✅74/0 | ✅74/0 | both-pass |  |
| `test/js/node/async_hooks/AsyncLocalStorage.test.ts` |  | ✅47/0 | ✅47/0 | both-pass |  |
| `test/js/node/async_hooks/EventEmitterAsyncResource.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/async_hooks/async-local-storage-thenable.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/async_hooks/async_hooks.node.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/buffer-compare-bounds.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/js/node/buffer-concat.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/node/buffer-copy-fill-detach.test.ts` |  | ✅23/0 | ✅23/0 | both-pass |  |
| `test/js/node/buffer-from-encoding-leak.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/buffer-from-symbol-to-primitive.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/buffer-indexOf-detach.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/js/node/buffer-indexof-worstcase.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/node/buffer-inspectmaxbytes.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/buffer-resolveObjectURL.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/buffer-utf16.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/buffer.test.js` |  ⊘3+3 | ✅673/0 | ✅673/0 | both-pass |  |
| `test/js/node/child_process/child-process-socket-inherit.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/child_process/child-process-stdio.test.js` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/node/child_process/child_process-node.test.js` |  | ✅30/0 | ✅30/0 | both-pass |  |
| `test/js/node/child_process/child_process_ipc.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/child_process/child_process_ipc_handle.test.ts` |  ⊘1+1 | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/node/child_process/child_process_ipc_large_disconnect.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/child_process/child_process_send_cb.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/console/console-constructor-exception.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/console/console-table-iterators.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/console/console.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/node/crypto/crypto-extra-memory.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/node/crypto/crypto-hmac-algorithm.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/crypto/crypto-invalid-this.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/crypto/crypto-lazyhash.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/crypto/crypto-oneshot.test.ts` |  | ✅35/0 | ✅35/0 | both-pass |  |
| `test/js/node/crypto/crypto-pqc.test.ts` |  | ✅23/0 | ✅23/0 | both-pass |  |
| `test/js/node/crypto/crypto-random.test.ts` |  ⊘1+1 | ✅17/0 | ✅17/0 | both-pass |  |
| `test/js/node/crypto/crypto-rsa.test.js` |  | ✅22/0 | ✅22/0 | both-pass |  |
| `test/js/node/crypto/crypto-sign-regression.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/crypto/crypto.hmac.test.ts` |  | ✅74/0 | ✅74/0 | both-pass |  |
| `test/js/node/crypto/crypto.key-objects.test.ts` |  ⊘2+2 | ✅86/0 | ✅86/0 | both-pass |  |
| `test/js/node/crypto/crypto.test.ts` |  ⊘1+1 | ✅403/0 | ✅403/0 | both-pass |  |
| `test/js/node/crypto/ecdh.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/node/crypto/hkdf-callback-null.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/crypto/node-crypto.test.js` |  | ✅208/0 | ✅208/0 | both-pass |  |
| `test/js/node/crypto/pbkdf2.test.ts` |  | ✅45/0 | ✅45/0 | both-pass |  |
| `test/js/node/crypto/scrypt.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/crypto/sign-jwk-ieee-p1363.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/crypto/x509-subclass.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/node/crypto/x509.test.ts` |  | ✅19/0 | ✅19/0 | both-pass |  |
| `test/js/node/dgram/node-dgram.test.js` |  ⊘1+1 | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/diagnostics_channel/diagnostics_channel.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/node/dirname.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/dns/dns-lookup-keepalive.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/dns/dns-resolver-concurrent-timeout.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/dns/dns-tcp-bidirectional-poll.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/dns/node-dns.test.js` |  ⊘3+3 | ✅164/0 | ✅164/0 | both-pass |  |
| `test/js/node/domexception-node.test.js` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/node/env-windows.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/errors/error-code-toString-receiver.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/events/event-emitter.test.ts` |  | ✅75/0 | ✅75/0 | both-pass |  |
| `test/js/node/fs/abort-signal-leak-read-write-file.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/fs/cp-symlink-target.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/fs/dir.test.ts` |  ⊘1+1 | ✅23/0 | ✅23/0 | both-pass |  |
| `test/js/node/fs/fs-birthtime-linux.test.ts` | 🔧ohos-adapted ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/fs/fs-leak.test.js` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/fs/fs-oom.test.ts` |  ⊘2+2 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/fs/fs-path-length.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/fs/fs-promises-writeFile-async-iterator.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/fs/fs-stat-seccomp-linux.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/fs/fs-stats-constructor.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/node/fs/fs-stats-truncate.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/fs/fs-write-offset-bound.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/node/fs/fs-writeSync-stdio-windows.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/fs/glob.test.ts` |  | ✅34/0 | ✅34/0 | both-pass |  |
| `test/js/node/fs/promises.test.js` |  ⊘5+5 | ✅30/0 | ✅30/0 | both-pass |  |
| `test/js/node/fs/readdir-windows-ntstatus.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/fs/readdirSync-recursive-error-leak.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/fs/rm-windows-ntstatus.test.ts` |  ⊘3+3 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/fs/translate-uv-error-windows.test.ts` |  ⊘2+2 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/harness.test.js` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/http/client-timeout-error.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/http/early-hints-crlf-injection.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/http/node-fetch-cjs.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/http/node-fetch-primordials.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/http/node-fetch.test.js` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/node/http/node-http-agent-tls-options.test.mts` |  | ✅15/0 | ✅15/0 | both-pass |  |
| `test/js/node/http/node-http-backpressure-max.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/http/node-http-backpressure.test.ts` | 🔧ohos-adapted | ✅19/0 | ✅19/0 | both-pass |  |
| `test/js/node/http/node-http-client-request-gc.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/http/node-http-maxHeaderSize.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/http/node-http-nested-cork.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/node/http/node-http-ondata-reregister-leak.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/http/node-http-parser.test.ts` |  | ✅16/0 | ✅16/0 | both-pass |  |
| `test/js/node/http/node-http-pinned-write.test.ts` |  ⊘4+4 | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/node/http/node-http-primoridals.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/http/node-http-proxy-url.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/http/node-http-req-socket-pause.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/http/node-http-res-settimeout-unref.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/http/node-http-server-abort-events.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/http/node-http-server-socket-end-drain.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/http/node-http-server-timeouts.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/node/http/node-http-syscall-fault.test.ts` |  ⊘2+2 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/http/node-http-transfer-encoding.test.ts` |  | ✅30/0 | ✅30/0 | both-pass |  |
| `test/js/node/http/node-http-uaf.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/node/http/node-http-with-ws.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/http/node-http.compress.leak.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/http/node-https-checkServerIdentity.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/http/numeric-header.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/http2/h2-conformance.test.ts` |  | ✅67/0 | ✅67/0 | both-pass |  |
| `test/js/node/http2/h2-late-rst-staged.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/http2/h2-push-refusal-staged.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/http2/node-http2-continuation.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/node/http2/node-http2-invalid-padding.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/node/http2/node-http2-streams-rehash.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/http2/node-http2-syscall-fault.test.ts` |  ⊘3+3 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/http2/node-http2-upgrade.test.mts` |  | ✅15/0 | ✅15/0 | both-pass |  |
| `test/js/node/http2/node-http2.test.js` | 🔧ohos-adapted ⊘1+1 | ✅368/0 | ✅368/0 | both-pass |  |
| `test/js/node/inspector/inspector-profiler.test.ts` |  | ✅45/0 | ✅45/0 | both-pass |  |
| `test/js/node/inspector/inspector.test.ts` |  | ✅24/0 | ✅24/0 | both-pass |  |
| `test/js/node/missing-module.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/module/esm-registry-concurrent-gc.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/module/module-children-concurrent-gc.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/module/module-resolve-filename-paths.test.js` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/node/module/module-sourcemap.test.js` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/module/require-extensions.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/node/module/sourcemap.test.js` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/node/net/blocklist-gc.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/net/connect-autoselectfamily-stale-timer.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/net/double-connect.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/net/net-mongodb-pattern-leak.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/net/net-syscall-fault.test.ts` |  ⊘3+3 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/net/socket-reconnect-live.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/net/socketaddress.spec.ts` |  ⊘1+1 | ✅66/0 | ✅66/0 | both-pass |  |
| `test/js/node/no-addons.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/nodettywrap.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/path/15704.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/path/basename.test.js` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/path/browserify.test.js` |  | ✅52/0 | ✅52/0 | both-pass |  |
| `test/js/node/path/dirname.test.js` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/path/extname.test.js` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/path/is-absolute.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/path/join.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/path/matches-glob.test.ts` |  | ✅31/0 | ✅31/0 | both-pass |  |
| `test/js/node/path/normalize.test.js` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/path/parse-format.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/path/path.test.js` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/path/posix-exists.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/path/posix-relative-on-windows.test.js` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/path/relative.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/path/resolve-long-cwd.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/path/resolve.test.js` |  ⊘2+2 | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/path/to-namespaced-path.test.js` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/path/win32-exists.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/path/zero-length-strings.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/perf_hooks/perf_hooks.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/node/process-binding.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/process/call-constructor.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/process/process-args.test.js` |  ⊘1+1 | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/node/process/process-array-accessor-crash.test.ts` |  ⊘1+1 | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/process/process-execve.test.ts` |  ⊘10+10 | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/node/process/process-memory-pressure.test.ts` |  ⊘2+2 | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/process/process-nexttick.test.js` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/node/process/process-on.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/process/process-signal-listener-count.test.ts` |  ⊘3+3 | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/process/process-signal-windows.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/process/process-stdio-invalid-utf16.test.ts` |  | ✅24/0 | ✅24/0 | both-pass |  |
| `test/js/node/process/process-stdio-stack-overflow.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/process/process-stdio.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/node/process/process-stdout-write-after-end.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/process/stdin/process-stdin-stale-hup.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/process/stdin/stdin-fixtures.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/promise/reject-tostring.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/quic/quic-endpoint.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/node/quic/quic-sni.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/node/quic/quic-stream.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/readline/getStringWidth.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/readline/pause_stdin_should_exit.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/readline/readline.node.test.ts` |  | ✅80/0 | ✅80/0 | both-pass |  |
| `test/js/node/readline/readline_never_unrefs.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/readline/readline_promises.node.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/readline/stdin-pause-pty.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/readline/stdin_fell_asleep.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/sqlite/node-sqlite.test.ts` |  ⊘14+14 | ✅115/0 | ✅115/0 | both-pass |  |
| `test/js/node/stream/node-stream-uint8array.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/stream/node-stream.test.js` |  | ✅103/0 | ✅103/0 | both-pass |  |
| `test/js/node/string-module.test.js` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/node/string_decoder/string-decoder.test.js` |  | ✅98/0 | ✅98/0 | both-pass |  |
| `test/js/node/stubs.test.js` |  | ✅378/0 | ✅378/0 | both-pass |  |
| `test/js/node/test_runner/node-test.test.ts` |  ⊘2+2 | ✅45/0 | ✅45/0 | both-pass |  |
| `test/js/node/timers.promises/timers.promises.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/node/timers/node-timers.test.ts` |  | ✅23/0 | ✅23/0 | both-pass |  |
| `test/js/node/tls/fetch-tls-cert.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/node/tls/node-tls-cert.test.ts` |  | ✅28/0 | ✅28/0 | both-pass |  |
| `test/js/node/tls/node-tls-connect-hostname-verification.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/node/tls/node-tls-connect.test.ts` |  ⊘2+2 | ✅60/0 | ✅60/0 | both-pass |  |
| `test/js/node/tls/node-tls-context.test.ts` |  | ✅17/0 | ✅17/0 | both-pass |  |
| `test/js/node/tls/node-tls-create-secure-context-args.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/node/tls/node-tls-duplex-close-throw-uaf.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/tls/node-tls-duplex-write-throw-error-value.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/tls/node-tls-ecdh-curve.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/node/tls/node-tls-getpeercert-leak.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/tls/node-tls-internals.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/tls/node-tls-namedpipes.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/tls/node-tls-no-cipher-match-error.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/tls/node-tls-root-certs-concurrent-init.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/tls/node-tls-rootcertificates-immutable.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/tls/node-tls-socket-allow-half-open-option.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/tls/node-tls-upgrade.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/tls/renegotiation.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/node/tls/ssl-ctx-cache.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/node/tls/test-node-extra-ca-certs.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/tls/test-system-ca-https.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/tls/test-use-system-ca.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/tls/tls-connect-socket-churn.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/tls/tls-syscall-fault.test.ts` |  ⊘4+4 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/trace_events/trace-events.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/url/pathToFileURL.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/url/url-canParse-whatwg.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/url/url-domain-ascii-unicode.test.js` |  | ✅130/0 | ✅130/0 | both-pass |  |
| `test/js/node/url/url-fileurltopath.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/url/url-fileurltopathbuffer.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/node/url/url-format-invalid-input.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/url/url-format-whatwg.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/url/url-format.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/url/url-is-url.test.js` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/url/url-null-char.test.js` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/url/url-parse-format.test.js` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/node/url/url-parse-invalid-input.test.js` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/url/url-parse-ipv6.test.ts` |  | ✅34/0 | ✅34/0 | both-pass |  |
| `test/js/node/url/url-parse-query.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/url/url-pathtofileurl.test.js` |  ⊘1+1 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/url/url-relative.test.js` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/url/url-revokeobjecturl.test.js` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/url/url.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/node/util/bun-inspect.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/node/util/custom-inspect.test.js` |  | ✅44/0 | ✅44/0 | both-pass |  |
| `test/js/node/util/mime-api.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/node/util/node-inspect-tests/import.test.mjs` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/util/node-inspect-tests/internal-inspect.test.js` |  ⊘1+1 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/util/node-inspect-tests/parallel/util-format.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/util/node-inspect-tests/parallel/util-inspect-getters-accessing-this.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/util/node-inspect-tests/parallel/util-inspect-long-running.test.mjs` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/util/node-inspect-tests/parallel/util-inspect-proxy.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/util/node-inspect-tests/parallel/util-inspect.test.js` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/util/parse_args/default-args.test.mjs` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/node/util/parse_args/parse-args-null-config.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/node/util/parse_args/parse-args-token-key-order.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/util/parse_args/parse-args.test.mjs` |  | ✅108/0 | ✅108/0 | both-pass |  |
| `test/js/node/util/test-aborted.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/node/util/test-util-types.test.js` |  | ✅53/0 | ✅53/0 | both-pass |  |
| `test/js/node/util/util-callbackify.test.js` |  | ✅90/0 | ✅90/0 | both-pass |  |
| `test/js/node/util/util-promisify.test.js` |  ⊘1+1 | ✅16/0 | ✅16/0 | both-pass |  |
| `test/js/node/util/util.test.js` |  | ✅209/0 | ✅209/0 | both-pass |  |
| `test/js/node/v8/capture-stack-trace.test.js` |  | ✅44/0 | ✅44/0 | both-pass |  |
| `test/js/node/v8/v8-date-parser.test.js` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/v8/v8-module.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/node/v8/v8-serdes-buffer.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/node/vm/happy-dom-vm-16277.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/vm/script-leak.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/vm/sourcetextmodule-leak.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/vm/sourcetextmodule-link-gc.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/vm/vm-script-fetcher-leak.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/vm/vm-sourceUrl.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/vm/vm.test.ts` |  ⊘3+3 | ✅276/0 | ✅276/0 | both-pass |  |
| `test/js/node/watch/fs.watch.close-exit.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/watch/fs.watch.deadlock.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/watch/fs.watch.events-cb-race.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/watch/fs.watch.rewrite.test.ts` |  ⊘4+4 | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/watch/fs.watchFile.test.ts` |  ⊘1+1 | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/node/worker_threads/15787.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/worker_threads/worker-async-dispose.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/worker_threads/worker-shutdown-post-leak.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/node/worker_threads/worker-top-level-await.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/node/worker_threads/worker-transfer-list.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/node/worker_threads/worker-transfer-terminate-stress.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/worker_threads/worker_destruction.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/worker_threads/worker_heap_snapshot_gc.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/worker_threads/worker_threads.test.ts` |  | ✅137/0 | ✅137/0 | both-pass |  |
| `test/js/node/zlib/bytesWritten.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/zlib/deflate-streaming.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/node/zlib/leak.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/node/zlib/zlib-estimated-size-gc.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/node/zlib/zlib-handle-bounds-check.test.ts` |  | ✅39/0 | ✅39/0 | both-pass |  |
| `test/js/node/zlib/zlib-onerror-reentrancy.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/node/zlib/zlib-reset-race.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/node/zlib/zlib.kMaxLength.global.test.js` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/node/zlib/zlib.test.js` |  ⊘1+1 | ✅388/0 | ✅388/0 | both-pass |  |


## Web 标准 API（175 文件 / 6 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/js/web/fetch/fetch.test.ts` |  ⊘4+4 | ❌357/5 | ❌357/5 | both-fail | env-baseline |
| `test/js/web/fetch/fetch.unix.test.ts` | 🔧ohos-adapted | ❌1/5 | ❌1/5 | both-fail | env-baseline |
| `test/js/web/streams/streams.test.js` |  | ❌174/1 | ❌174/1 | both-fail | env-baseline |
| `test/js/web/websocket/websocket-unix.test.ts` |  ⊘1+1 | ❌2/5 | ❌2/5 | both-fail | env-baseline |
| `test/js/web/workers/message-port-context-destroy-leak.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/web/workers/worker-late-completion.test.ts` |  ⊘3+3 | ❌0/4 | ❌0/4 | both-fail | env-baseline |
| `test/js/web/fetch/fetch.tls.test.ts` |  | ❌29/1 | ✅30/0 | A-only-fail |  |
| `test/js/web/abort/abort-controller-gc-reason.test.ts` |  ⊘2+2 | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/web/abort/abort-signal-event-listener-leak.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/web/abort/abort.test.ts` |  | ✅16/0 | ✅16/0 | both-pass |  |
| `test/js/web/atomics.test.ts` |  | ✅28/0 | ✅28/0 | both-pass |  |
| `test/js/web/broadcastchannel/broadcast-channel-worker-gc.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/web/broadcastchannel/broadcast-channel.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/web/broadcastchannel/message-event-init-gc.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/console/console-log-utf16.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/console/console-log.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/web/console/console-recursive.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/console/console-timeLog.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/web/crypto/web-crypto-sha3.test.ts` |  | ✅17/0 | ✅17/0 | both-pass |  |
| `test/js/web/crypto/web-crypto.test.ts` |  | ✅94/0 | ✅94/0 | both-pass |  |
| `test/js/web/encoding/encode-bad-chunks.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/web/encoding/text-decoder-cjk.test.ts` |  | ✅58/0 | ✅58/0 | both-pass |  |
| `test/js/web/encoding/text-decoder-single-byte.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/web/encoding/text-decoder-stream.test.ts` |  | ✅51/0 | ✅51/0 | both-pass |  |
| `test/js/web/encoding/text-decoder-wpt.test.ts` |  | ✅281/0 | ✅281/0 | both-pass |  |
| `test/js/web/encoding/text-decoder.test.js` |  | ✅125/0 | ✅125/0 | both-pass |  |
| `test/js/web/encoding/text-encoder-stream.test.ts` |  | ✅24/0 | ✅24/0 | both-pass |  |
| `test/js/web/encoding/text-encoder.test.js` |  | ✅42/0 | ✅42/0 | both-pass |  |
| `test/js/web/explicit-resource-management.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/web/fetch/abort-signal-leak.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/web/fetch/blob-array-fast-path.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/web/fetch/blob-cow.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/web/fetch/blob-file-name-ownership.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/fetch/blob-oom.test.ts` |  ⊘2+2 | ✅20/0 | ✅20/0 | both-pass |  |
| `test/js/web/fetch/blob-write.test.ts` |  | ✅15/0 | ✅15/0 | both-pass |  |
| `test/js/web/fetch/blob.test.ts` |  ⊘1+1 | ✅102/0 | ✅102/0 | both-pass |  |
| `test/js/web/fetch/body-async-iterator.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/fetch/body-clone.test.ts` |  | ✅63/0 | ✅63/0 | both-pass |  |
| `test/js/web/fetch/body-mixin-errors.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/web/fetch/body-stream-excess.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/web/fetch/body-stream.test.ts` |  | ✅9086/0 | ✅9086/0 | both-pass |  |
| `test/js/web/fetch/body.test.ts` |  | ✅459/0 | ✅459/0 | both-pass |  |
| `test/js/web/fetch/chunked-trailing.test.js` |  | ✅23/0 | ✅23/0 | both-pass |  |
| `test/js/web/fetch/client-fetch.test.ts` |  | ✅34/0 | ✅34/0 | both-pass |  |
| `test/js/web/fetch/content-length.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/fetch/cookies.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/web/fetch/encoding.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/web/fetch/exiting.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/fetch/fetch-abort-queued.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/fetch/fetch-abort-socket-close-race.test.ts` |  ⊘2+2 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/web/fetch/fetch-abort-stream-body.test.ts` |  ⊘1+1 | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/web/fetch/fetch-args.test.ts` |  | ✅61/0 | ✅61/0 | both-pass |  |
| `test/js/web/fetch/fetch-backpressure.test.ts` |  ⊘2+2 | ✅53/0 | ✅53/0 | both-pass |  |
| `test/js/web/fetch/fetch-compress.test.ts` |  ⊘1+1 | ✅32/0 | ✅32/0 | both-pass |  |
| `test/js/web/fetch/fetch-connection-header.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/web/fetch/fetch-cyclic-reference.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/fetch/fetch-gzip.test.ts` |  | ✅80/0 | ✅80/0 | both-pass |  |
| `test/js/web/fetch/fetch-header-str-bounds.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/fetch/fetch-http2-adversarial.test.ts` |  | ✅20/0 | ✅20/0 | both-pass |  |
| `test/js/web/fetch/fetch-http2-client.test.ts` |  | ✅62/0 | ✅62/0 | both-pass |  |
| `test/js/web/fetch/fetch-http2-leak.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/web/fetch/fetch-http3-adversarial.test.ts` |  | ✅27/0 | ✅27/0 | both-pass |  |
| `test/js/web/fetch/fetch-http3-client.test.ts` |  | ✅53/0 | ✅53/0 | both-pass |  |
| `test/js/web/fetch/fetch-http3-cold-post.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/fetch/fetch-http3-syscall-fault.test.ts` |  ⊘3+3 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/web/fetch/fetch-keepalive.test.ts` |  | ✅36/0 | ✅36/0 | both-pass |  |
| `test/js/web/fetch/fetch-leak.test.ts` |  | ✅29/0 | ✅29/0 | both-pass |  |
| `test/js/web/fetch/fetch-preconnect.test.ts` |  ⊘1+1 | ✅13/0 | ✅13/0 | both-pass |  |
| `test/js/web/fetch/fetch-proxy-connect-tunnel-split-envelope.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/web/fetch/fetch-proxy-tls-intern-race.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/fetch/fetch-redirect.test.ts` |  | ✅30/0 | ✅30/0 | both-pass |  |
| `test/js/web/fetch/fetch-response-finalizer-sweep.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/fetch/fetch-retry-chunked.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/fetch/fetch-stream-cancel-leak.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/web/fetch/fetch-syscall-fault.test.ts` |  ⊘3+3 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/web/fetch/fetch-tcp-keepalive.test.ts` |  ⊘2+2 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/web/fetch/fetch-tcp-stress.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/web/fetch/fetch-tls-abortsignal-timeout.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/web/fetch/fetch-url-after-redirect.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/fetch/fetch.brotli.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/fetch/fetch.stream.test.ts` |  ⊘1+1 | ✅117/0 | ✅117/0 | both-pass |  |
| `test/js/web/fetch/fetch.tls.wildcard.test.ts` |  | ✅72/0 | ✅72/0 | both-pass |  |
| `test/js/web/fetch/fetch.upgrade.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/fetch/fetch_headers.test.js` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/web/fetch/form-data-boundary-crash.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/web/fetch/headers-case.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/web/fetch/headers.test.ts` |  | ✅99/0 | ✅99/0 | both-pass |  |
| `test/js/web/fetch/headers.undici.test.ts` |  | ✅51/0 | ✅51/0 | both-pass |  |
| `test/js/web/fetch/request-cyclic-reference.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/fetch/response-cyclic-reference.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/fetch/response.test.ts` |  | ✅23/0 | ✅23/0 | both-pass |  |
| `test/js/web/fetch/server-response-stream-leak.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/fetch/stream-fast-path.test.ts` |  | ✅75/0 | ✅75/0 | both-pass |  |
| `test/js/web/fetch/utf8-bom.test.ts` |  | ✅21/0 | ✅21/0 | both-pass |  |
| `test/js/web/fetch/wasm-streaming.test.ts` |  | ✅33/0 | ✅33/0 | both-pass |  |
| `test/js/web/fetch/wpt/textstream-wpt.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/web/html/FormData-file-error-leak.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/html/FormData-multipart-serialization.test.ts` |  ⊘1+1 | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/web/html/FormData.test.ts` |  | ✅149/0 | ✅149/0 | both-pass |  |
| `test/js/web/html/URLSearchParams.test.ts` |  | ✅17/0 | ✅17/0 | both-pass |  |
| `test/js/web/html/html-rewriter-doctype.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/intl/intl.test.ts` |  ⊘1+1 | ✅32/0 | ✅32/0 | both-pass |  |
| `test/js/web/nationalized.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/request/request-clone-leak.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/web/request/request-method-getter.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/web/request/request-subclass.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/request/request.test.ts` |  | ✅19/0 | ✅19/0 | both-pass |  |
| `test/js/web/streams/compression.test.ts` |  ⊘1+1 | ✅64/0 | ✅64/0 | both-pass |  |
| `test/js/web/streams/native-source-onclose-leak.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/web/streams/pipeTo-shutdown-gc.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/streams/pipeTo-signal-leak.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/streams/readable-stream-blob-consumed.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/streams/readable-stream-terminal-barrier-release.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/streams/streams-leak.test.ts` |  ⊘2+2 | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/web/streams/streams-string-limit.test.ts` |  ⊘1+1 | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/web/streams/sync-pull-fast-path.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/web/streams/transform-stream-leak.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/web/structured-clone-blob-file.test.ts` |  ⊘1+1 | ✅42/0 | ✅42/0 | both-pass |  |
| `test/js/web/structured-clone-fastpath.test.ts` |  | ✅92/0 | ✅92/0 | both-pass |  |
| `test/js/web/structured-clone-shared-array-buffer.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/web/temporal/temporal.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/web/timers/clearImmediate-gc.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/timers/microtask.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/timers/performance-entries.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/timers/performance.test.js` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/web/timers/setImmediate.test.js` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/web/timers/setImmediate2.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/timers/setInterval.test.js` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/web/timers/setTimeout.test.js` |  ⊘3+3 | ✅33/0 | ✅33/0 | both-pass |  |
| `test/js/web/timers/timer-gc-roots.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/web/timers/timer-heap-race.test.ts` |  ⊘2+2 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/url/url-wpt-constructor.test.ts` |  | ✅870/0 | ✅870/0 | both-pass |  |
| `test/js/web/url/url.test.ts` | 🔧other-adapted ⊘1+1 | ✅27/0 | ✅27/0 | both-pass |  |
| `test/js/web/url/url.windows.test.js` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/web/urlpattern/urlpattern.test.ts` |  | ✅408/0 | ✅408/0 | both-pass |  |
| `test/js/web/util/atob.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/web-globals.test.js` |  | ✅23/0 | ✅23/0 | both-pass |  |
| `test/js/web/websocket/autobahn.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/web/websocket/error-event.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/websocket/test-ws-bidir-proxy.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/websocket/websocket-accept-header-validation.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/websocket/websocket-blob.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/web/websocket/websocket-client-short-read.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/web/websocket/websocket-client.test.ts` |  | ✅37/0 | ✅37/0 | both-pass |  |
| `test/js/web/websocket/websocket-close-async-dispatch.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/web/websocket/websocket-close-code.test.ts` |  | ✅24/0 | ✅24/0 | both-pass |  |
| `test/js/web/websocket/websocket-close-connecting.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/web/websocket/websocket-close-fragmented.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/websocket/websocket-custom-headers.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/web/websocket/websocket-handshake-event.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/websocket/websocket-permessage-deflate-edge-cases.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/web/websocket/websocket-permessage-deflate-simple.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/web/websocket/websocket-permessage-deflate.test.ts` |  ⊘1+1 | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/web/websocket/websocket-pong-fragmented.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/web/websocket/websocket-proxy-close-reentrancy.test.ts` |  ⊘1+1 | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/websocket/websocket-proxy-tunnel-client-leak.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/web/websocket/websocket-proxy-tunnel-upgrade-leak.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/web/websocket/websocket-proxy.test.ts` |  ⊘1+1 | ✅34/0 | ✅34/0 | both-pass |  |
| `test/js/web/websocket/websocket-subprotocol-strict.test.ts` |  | ✅19/0 | ✅19/0 | both-pass |  |
| `test/js/web/websocket/websocket-syscall-fault.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/web/websocket/websocket-upgrade.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/web/websocket/websocket-utf16-headers.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/web/websocket/websocket.test.js` |  | ✅48/0 | ✅48/0 | both-pass |  |
| `test/js/web/workers/message-channel.test.ts` |  | ✅17/0 | ✅17/0 | both-pass |  |
| `test/js/web/workers/message-event.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/web/workers/message-port-closed-leak.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/web/workers/message-port-pipe.test.ts` |  ⊘3+3 | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/web/workers/performance-observer-leak.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/web/workers/structured-clone.test.ts` |  | ✅231/0 | ✅231/0 | both-pass |  |
| `test/js/web/workers/structuredClone-classes.test.ts` |  | ✅57/0 | ✅57/0 | both-pass |  |
| `test/js/web/workers/worker-postmessage-transfer.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/web/workers/worker-terminate-funnels.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/web/workers/worker-terminate-lifetime.test.ts` |  ⊘10+10 | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/web/workers/worker.test.ts` |  | ✅37/0 | ✅37/0 | both-pass |  |
| `test/js/web/workers/worker_blob.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |


## 第三方库兼容（120 文件 / 17 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/js/third_party/@azure/service-bus/azure-service-bus.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/@napi-rs/canvas/napi-rs-canvas.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/astro/astro-post.test.js` |  | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/esbuild/esbuild-child_process.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/grpc-js/test-idle-timer.test.ts` |  | ❌7/1 | ❌7/1 | both-fail | env-baseline |
| `test/js/third_party/grpc-js/test-resolver.test.ts` |  ⊘6+6 | ❌18/2 | ❌18/2 | both-fail | env-baseline |
| `test/js/third_party/mongodb/mongodb.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/next-auth/next-auth.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/nodemailer/nodemailer.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/pg/pg.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/pnpm/pnpm.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/postgres/postgres.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/prisma/prisma.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/resvg/bbox.test.js` |  | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/rollup-v4/rollup-v4.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/stripe/stripe.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/js/third_party/vitest/vitest.test.ts` |  | ❌0/2 | ❌0/2 | both-fail | env-baseline |
| `test/js/third_party/@electric-sql/pglite/pglite.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/@fastify/websocket/fastity-test-websocket.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/body-parser/express-body-parser-test.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/third_party/body-parser/express-bun-build-compile.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/body-parser/express-memory-leak.test.ts` |  ⊘1+1 | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/third_party/comlink/comlink.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/es-module-lexer/es-module-lexer.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/express/app.router.test.ts` |  ⊘1+1 | ✅77/0 | ✅77/0 | both-pass |  |
| `test/js/third_party/express/express.json.test.ts` |  ⊘1+1 | ✅47/0 | ✅47/0 | both-pass |  |
| `test/js/third_party/express/express.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/express/express.text.test.ts` |  | ✅33/0 | ✅33/0 | both-pass |  |
| `test/js/third_party/express/res.json.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/js/third_party/express/res.location.test.ts` |  | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/third_party/express/res.redirect.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/third_party/express/res.send.test.ts` |  ⊘1+1 | ✅65/0 | ✅65/0 | both-pass |  |
| `test/js/third_party/express/res.sendFile.test.ts` |  | ✅39/0 | ✅39/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-call-credentials.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-call-propagation.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-certificate-provider.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-channel-credentials.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-channelz.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-client.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-confg-parsing.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-deadline.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-duration.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-end-to-end.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-global-subchannel-pool.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-local-subchannel-pool.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-logging.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-metadata.test.ts` |  | ✅29/0 | ✅29/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-outlier-detection.test.ts` |  | ✅26/0 | ✅26/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-pick-first.test.ts` |  | ✅22/0 | ✅22/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-prototype-pollution.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-retry-config.test.ts` |  | ✅28/0 | ✅28/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-retry.test.ts` |  | ✅15/0 | ✅15/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-server-credentials.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-server-deadlines.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-server-errors.test.ts` |  | ✅34/0 | ✅34/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-server-interceptors.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-server.test.ts` |  ⊘2+2 | ✅45/0 | ✅45/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-status-builder.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-tonic.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/third_party/grpc-js/test-uri-parser.test.ts` |  | ✅15/0 | ✅15/0 | both-pass |  |
| `test/js/third_party/hono/hello-world-fixture.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/hono/hello-world.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/http2-wrapper/http2-wrapper.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/async_sign.test.js` |  ⊘1+1 | ✅16/0 | ✅16/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/buffer.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/claim-aud.test.js` |  | ✅60/0 | ✅60/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/claim-exp.test.js` |  | ✅58/0 | ✅58/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/claim-iat.test.js` |  | ✅39/0 | ✅39/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/claim-iss.test.js` |  | ✅28/0 | ✅28/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/claim-jti.test.js` |  | ✅24/0 | ✅24/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/claim-nbf.test.js` |  | ✅58/0 | ✅58/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/claim-private.test.js` |  | ✅19/0 | ✅19/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/claim-sub.test.js` |  | ✅24/0 | ✅24/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/decoding.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/encoding.test.js` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/expires_format.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/header-kid.test.js` |  | ✅20/0 | ✅20/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/invalid_exp.test.js` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/issue_147.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/issue_304.test.js` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/issue_70.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/jwt.asymmetric_signing.test.js` |  | ✅36/0 | ✅36/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/jwt.hs.test.js` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/jwt.malicious.test.js` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/noTimestamp.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/non_object_values.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/option-complete.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/option-maxAge.test.js` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/option-nonce.test.js` |  | ✅18/0 | ✅18/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/rsa-public-key.test.js` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/schema.test.js` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/set_headers.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/undefined_secretOrPublickey.test.js` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/validateAsymmetricKey.test.js` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/verify.test.js` |  | ✅19/0 | ✅19/0 | both-pass |  |
| `test/js/third_party/jsonwebtoken/wrong_alg.test.js` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/third_party/msw/msw.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/pg-gateway/pglite.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/pino/pino.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/prompts/prompts.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/remix/remix.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/socket.io/socket.io-close.test.ts` |  ⊘4+4 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/third_party/socket.io/socket.io-connection-state-recovery.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/js/third_party/socket.io/socket.io-handshake.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/third_party/socket.io/socket.io-messaging-many.test.ts` |  ⊘12+12 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/third_party/socket.io/socket.io-middleware.test.ts` |  ⊘2+2 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/third_party/socket.io/socket.io-namespaces.test.ts` |  ⊘12+12 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/third_party/socket.io/socket.io-server-attachment.test.ts` |  ⊘2+2 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/third_party/socket.io/socket.io-socket-middleware.test.ts` |  ⊘2+2 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/third_party/socket.io/socket.io-socket-timeout.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/third_party/socket.io/socket.io-utility-methods.test.ts` |  ⊘9+9 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/third_party/socket.io/socket.io.test.ts` |  ⊘21+21 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/third_party/solc/solc.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/st/st.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/third_party/svelte/svelte.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/js/third_party/undici-h2/run.test.ts` |  | ✅11/0 | ✅11/0 | both-pass |  |
| `test/js/third_party/webpack/webpack.test.ts` |  ⊘2+2 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/third_party/wpt-h2/run.test.ts` |  | ✅20/0 | ✅20/0 | both-pass |  |
| `test/js/third_party/wpt-streams/wpt-streams.test.ts` |  | ✅1175/0 | ✅1175/0 | both-pass |  |
| `test/js/third_party/yargs/yargs-cjs.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |


## 端到端集成（22 文件 / 10 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/integration/expo-app/expo.test.ts` | 🔧slow-device-timeout | ✅1/0 | ⏰366.5s | B-only-fail | chronic-timeout |
| `test/integration/bun-types/bun-types.test.ts` |  ⊘2+2 | ❌5/10 | ❌5/10 | both-fail | env-baseline |
| `test/integration/bun-types/fixture/serve-types.test.ts` |  ⊘1+1 | ❌44/9 | ❌44/9 | both-fail | env-baseline |
| `test/integration/datadog-pprof/datadog-pprof.test.ts` | 🔧ohos-adapted ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/integration/esbuild/esbuild.test.ts` | 🔧ohos-adapted ⊘1+1 | ❌0/2 | ❌0/2 | both-fail | env-baseline |
| `test/integration/next-pages/test/dev-server-ssr-100.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/integration/next-pages/test/dev-server.test.ts` |  ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/integration/next-pages/test/next-build.test.ts` |  | ❌0/1 | ⏰360.4s | both-fail | env-baseline |
| `test/integration/sharp/sharp.test.ts` |  | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/integration/vite-build/vite-build.test.ts` | 🔧ohos-adapted | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/integration/bun-lambda/bun-lambda.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/integration/bun-types/fixture/23347.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/integration/bun-types/fixture/5396.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/integration/jsdom/jsdom.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/integration/mysql2/mysql2.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/integration/nest/nest_metadata.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/integration/sass/sass.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/integration/svelte/client-side.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/integration/svelte/server-side.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/integration/typegraphql/src/ts_example.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/integration/typegraphql/src/typegraphql.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/integration/typegraphql/src/unsolvable.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |


## 构建系统/内部（41 文件 / 9 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/internal/build-codegen-declared-outputs.test.ts` |  | ❌0/4 | ❌0/4 | both-fail | env-baseline |
| `test/internal/build-debug-info-flags.test.ts` |  ⊘1+1 | ❌0/4 | ❌0/4 | both-fail | env-baseline |
| `test/internal/build-post-link-ordering.test.ts` |  ⊘1+1 | ❌0/3 | ❌0/3 | both-fail | env-baseline |
| `test/internal/build-rust-toolchain-probe.test.ts` | 🔧ohos-adapted ⊘1+1 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/internal/macos-cross-config.test.ts` |  ⊘1+1 | ❌5/15 | ❌5/15 | both-fail | env-baseline |
| `test/internal/oxlint-plugin-bun.test.ts` |  | ❌0/6 | ❌0/6 | both-fail | env-baseline |
| `test/internal/source-lints/build-rust.test.ts` | 🔧ohos-adapted | ❌2/6 | ❌2/6 | both-fail | env-baseline |
| `test/internal/source-lints/webkit-prebuilt-url.test.ts` |  | ❌1/6 | ❌1/6 | both-fail | env-baseline |
| `test/internal/source-lints/windows-cross-config.test.ts` |  ⊘1+1 | ❌0/8 | ❌0/8 | both-fail | env-baseline |
| `test/internal/bindgen.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/internal/build-download-retry.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/internal/fifo.test.ts` |  | ✅26/0 | ✅26/0 | both-pass |  |
| `test/internal/highlighter.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/internal/int_from_float.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/internal/internal-module-blob.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/internal/linear-fifo.test.ts` |  ⊘1+1 | ✅2/0 | ✅2/0 | both-pass |  |
| `test/internal/parallel-allowlist.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/internal/powershell-escape.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/internal/rust-check-all.test.ts` |  ⊘1+1 | ✅4/0 | ✅4/0 | both-pass |  |
| `test/internal/rust-windows-sys-link.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/internal/sigaction-layout.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/internal/source-lints/byte-search.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/internal/source-lints/ci-annotations.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/internal/source-lints/dead-code-escapes.test.ts` |  | ✅23/0 | ✅23/0 | both-pass |  |
| `test/internal/source-lints/empty-jsvalue-laundering.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/internal/source-lints/expect-call-counter.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/internal/source-lints/fn-long-mut-reborrow.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/internal/source-lints/frozen-nonnull-reborrow.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/internal/source-lints/jsresult-swallow.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/internal/source-lints/lockfile-registry-only.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/internal/source-lints/no-iostream-include.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/internal/source-lints/port-era-markers.test.ts` |  | ✅7/0 | ✅7/0 | both-pass |  |
| `test/internal/source-lints/pre-port-identifiers.test.ts` |  | ✅17/0 | ✅17/0 | both-pass |  |
| `test/internal/source-lints/primordials-exports.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/internal/source-lints/redis-client-types.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/internal/source-lints/self-receiver-reclaim.test.ts` |  | ✅4/0 | ✅4/0 | both-pass |  |
| `test/internal/source-lints/shim-stdint-includes.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/internal/source-lints/unsafe-refcount-exports.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/internal/source-lints/unsound-erased-box.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/internal/source-lints/vm-thread-door.test.ts` |  | ✅47/0 | ✅47/0 | both-pass |  |
| `test/internal/source-lints/windows-sys-link-cfg.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |


## N-API（5 文件 / 4 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/napi/napi-value-ffi.test.ts` |  ⊘3+3 | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/napi/napi.test.ts` | 🔧ohos-adapted ⊘2+2 | ❌0/0 | ❌0/0 | both-fail | env-baseline |
| `test/napi/uv.test.ts` | 🔧ohos-adapted | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/napi/uv_stub.test.ts` | 🔧ohos-adapted | ❌0/1 | ❌0/1 | both-fail | env-baseline |
| `test/napi/napi-finalizer-delete-ref.test.ts` |  ⊘1+1 | ❌0/1 | ✅1/0 | A-only-fail |  |


## V8 C++ 兼容（1 文件 / 1 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/v8/v8.test.ts` |  ⊘7+7 | ❌0/0 | ❌0/0 | both-fail | env-baseline |


## 其他（48 文件 / 2 失败）

| 文件 | 改动 | A 轮 | 615b48e95 轮 | 失败集合 | 根因簇 |
|---|---|---|---|---|---|
| `test/js/valkey/reliability/connection-failures.test.ts` |  ⊘11+11 | ❌37/9 | ❌37/9 | both-fail | env-baseline |
| `test/js/valkey/valkey-tls-verify.test.ts` |  ⊘2+2 | ❌6/1 | ❌6/1 | both-fail | env-baseline |
| `test/config/bunfig/bunfig-errors.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/config/bunfig/preload.test.ts` |  ⊘2+2 | ✅18/0 | ✅18/0 | both-pass |  |
| `test/js/deno/abort/abort-controller.test.ts` |  | ✅6/0 | ✅6/0 | both-pass |  |
| `test/js/deno/crypto/random.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/deno/crypto/webcrypto.test.ts` |  | ✅37/0 | ✅37/0 | both-pass |  |
| `test/js/deno/encoding/encoding.test.ts` |  | ✅21/0 | ✅21/0 | both-pass |  |
| `test/js/deno/event/custom-event.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/deno/event/event-target.test.ts` |  | ✅14/0 | ✅14/0 | both-pass |  |
| `test/js/deno/event/event.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/deno/fetch/blob.test.ts` |  | ✅9/0 | ✅9/0 | both-pass |  |
| `test/js/deno/fetch/body.test.ts` |  | ✅3/0 | ✅3/0 | both-pass |  |
| `test/js/deno/fetch/headers.test.ts` |  | ✅26/0 | ✅26/0 | both-pass |  |
| `test/js/deno/fetch/request.test.ts` |  | ✅5/0 | ✅5/0 | both-pass |  |
| `test/js/deno/fetch/response.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/deno/performance/performance.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/js/deno/url/url.test.ts` |  | ✅33/0 | ✅33/0 | both-pass |  |
| `test/js/deno/url/urlsearchparams.test.ts` |  | ✅32/0 | ✅32/0 | both-pass |  |
| `test/js/deno/v8/error.test.ts` |  | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/first_party/undici/undici-primordials.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/first_party/undici/undici.test.ts` |  | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/first_party/utf-8-validate/utf-8-validate.test.ts` |  | ✅1/0 | ✅1/0 | both-pass |  |
| `test/js/first_party/ws/ws-proxy.test.ts` |  | ✅19/0 | ✅19/0 | both-pass |  |
| `test/js/first_party/ws/ws-syscall-fault.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/first_party/ws/ws-upgrade-events.test.ts` |  | ✅13/0 | ✅13/0 | both-pass |  |
| `test/js/first_party/ws/ws.test.ts` |  | ✅48/0 | ✅48/0 | both-pass |  |
| `test/js/junit-reporter/junit.test.js` |  ⊘4+4 | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/valkey/integration/complex-operations.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/valkey/reliability/error-handling.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/valkey/reliability/protocol-handling.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/valkey/reliability/recovery.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/valkey/reliability/resp-nesting-depth.test.ts` |  | ✅8/0 | ✅8/0 | both-pass |  |
| `test/js/valkey/unit/basic-operations.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/valkey/unit/buffer-operations.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/valkey/unit/hash-operations.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/valkey/unit/list-operations.test.ts` |  ⊘2+2 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/valkey/unit/ping.test.ts` |  ⊘1+1 | ✅0/0 | ✅0/0 | both-pass |  |
| `test/js/valkey/valkey-gc.test.ts` |  ⊘1+1 | ✅10/0 | ✅10/0 | both-pass |  |
| `test/js/valkey/valkey-incremental-scan.test.ts` |  | ✅41/0 | ✅41/0 | both-pass |  |
| `test/js/valkey/valkey.test.ts` |  ⊘2+2 | ✅61/0 | ✅61/0 | both-pass |  |
| `test/js/workerd/html-rewriter-end-error.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/js/workerd/html-rewriter-leak.test.ts` |  ⊘2+2 | ✅12/0 | ✅12/0 | both-pass |  |
| `test/js/workerd/html-rewriter.test.js` |  ⊘1+1 | ✅172/0 | ✅172/0 | both-pass |  |
| `test/package-json-lint.test.ts` |  | ✅21/0 | ✅21/0 | both-pass |  |
| `test/regression/brotli-reset-leak.test.ts` |  | ✅2/0 | ✅2/0 | both-pass |  |
| `test/regression/issue23966.test.ts` |  | ✅20/0 | ✅20/0 | both-pass |  |
| `test/snippets/segfault-todo.test.js` |  | ✅1/0 | ✅1/0 | both-pass |  |
