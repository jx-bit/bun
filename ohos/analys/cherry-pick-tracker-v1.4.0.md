# Cherry-pick 跟踪表: dev ← bun-v1.4.0

> 共 323 个上游 commit（不含 merge），按领域分类，标注 cherry-pick 优先级。
> 生成日期: 2026-08-28 | merge-base: `b7a0431032` (2026-08-12)

## 优先级定义

| 优先级 | 含义 | 行动 |
|---|---|---|
| **P0** | 直接修复 fulltest 回归 | 必须先 cherry-pick |
| **P1** | 重要上游修复（安全/正确性/兼容性） | 推荐按依赖顺序 cherry-pick |
| **P2** | 功能增强、性能优化 | 按需 cherry-pick |
| **P3** | 清理、文档、非关键 | 可选 |
| **SKIP** | Windows 专用或与 OHOS 无关 | 跳过 |

## 状态标记

| 标记 | 含义 |
|---|---|
| ⏳ | 待 cherry-pick |
| ✅ | 已 cherry-pick，测试通过 |
| ⚠️ | 已 cherry-pick，有冲突已解决 |
| ❌ | cherry-pick 失败，需要手动处理 |
| ⏭️ | 跳过 |

---

## P0 — 必须先 cherry-pick（修复 fulltest 回归）

| # | SHA | PR# | 描述 | 修复的回归 | dry-run 冲突 | 状态 |
|---|---|---|---|---|---|---|
| 1 | `88165c6ef2` | #39616 | buffer: restore swap16/32/64 + multi-byte indexOf throughput + highway_dispatch.h | sourcemap-simd(24) + console-iterator(8) = 32 用例 | JSBuffer.cpp (1处, 与OHOS无关) | ⏳ |

**#39616 详情**:
- 新建 `highway_dispatch.h`（缓存 Highway dispatch，省 ~20 指令/调用）
- 所有 highway 文件 `HWY_DYNAMIC_DISPATCH` → `BUN_HWY_DISPATCH`
- 重写 `highway_strings.cpp`（+337 行），修复 Buffer swap16/32/64 + multi-byte indexOf 性能回归
- dry-run: highway 文件全部自动合并，仅 JSBuffer.cpp 1 处冲突
- 命令: `git cherry-pick 88165c6ef2`

---

## SIMD/Highway（3 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `f09ed67339` | #39327 | Remove the undispatched LoaderHooks::resolve hook and lint hook tables for dead fields (#39327) | P2 | ⏳ |
| 2 | `2af91e1b67` | #37332 | Remove dead code from libuv_sys, cares_sys, simdutf FFI, test_runner, and C++ bindings (#37332) | P2 | ⏳ |
| 3 | `5a34f8d466` | #37275 | One termination signal, one fold: Err(Thrown) always means an exception is pending, and each event-loop dispatcher takes it in one place (#37275) | P2 | ⏳ |

## Install/pnpm（44 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `cfa9f8e15b` | #39573 | valkey: add ERR_REDIS_SERVER_ERROR for server error replies (#39573) | P2 | ⏳ |
| 2 | `c6a05c1014` | #39585 | Remove dead code from bun_install, boringssl_sys, orphaned C++ headers, and misc crates (#39585) | P2 | ⏳ |
| 3 | `2219e22abc` | #39484 | drop unused libarchive read formats and filters (#39484) | P2 | ⏳ |
| 4 | `1d1131cf04` | #29339 | redis: add bitmap, HLL, geo, scripting, server, and stream commands (#29339) | P2 | ⏳ |
| 5 | `875c761d5d` | #38867 | install: bound isolated store entry names; tarball URL credentials; file: tarballs relative to their folder package (#38867) | P2 | ⏳ |
| 6 | `7aad387416` | #39446 | ci: move bun-tracestrings out of the root package.json so root installs never download from GitHub (#39446) | P2 | ⏳ |
| 7 | `0002bf8006` | #39416 | JSSink: install the pump controller before the pump runs (HTMLRewriter segfault when a handler throws inside transform()) (#39416) | P2 | ⏳ |
| 8 | `30799d7a1e` | #39420 | Remove dead code from react_compiler, the WebCore/IDL bindings, install_jsc, node-fallbacks, and misc crates (#39420) | P2 | ⏳ |
| 9 | `c2ef43d043` | #39433 | node:http: remove the unused setServerIdleTimeout binding (#39433) | P2 | ⏳ |
| 10 | `d8c7b3643b` | #39310 | test runner: replace diff-match-patch with a work-bounded Myers diff (#39310) | P2 | ⏳ |
| 11 | `aec33f581d` | #39014 | install: leave URL credentials out of isolated store entry names (#39014) | P2 | ⏳ |
| 12 | `23d535a734` | #39313 | docs: remove config entries left over from the previous docs tooling (#39313) | P2 | ⏳ |
| 13 | `0eb355495b` | #39154 | install: read the root package.json through one helper in install_with_manager (#39154) | P2 | ⏳ |
| 14 | `8f8695f4cd` | #39178 | css: add the missing comma before the alpha when downleveling rgb() with an unresolved alpha (#39178) | P2 | ⏳ |
| 15 | `cc53961f55` | #39157 | install: name build_store's timing flag with an enum instead of a bool (#39157) | P2 | ⏳ |
| 16 | `2acfb09ec3` | #39146 | Drop the dead clone flag from Log::add_formatted_msg (#39146) | P2 | ⏳ |
| 17 | `cff3cd0d39` | #39127 | install: name satisfies_dependency_version's range-side arguments after the dependency (#39127) | P2 | ⏳ |
| 18 | `bf1437a1e6` | #39130 | install: rename with_alias_of's version parameter and clear its mordant baseline entry (#39130) | P2 | ⏳ |
| 19 | `e2b31495e5` | #39129 | isolated install: name the entry-hash DFS indices after the table they index (#39129) | P2 | ⏳ |
| 20 | `454b1ca6a2` | #39124 | bun:ffi: remove ABIType::param_typename, a copy of ABIType::typename (#39124) | P2 | ⏳ |
| 21 | `732491c9f4` | #38183 | install: canonical registry URL in Scope; redact secrets in bun audit registry URLs (#38183) | P2 | ⏳ |
| 22 | `8437683324` | #36303 | install: collapse a workspace's same-name dependency slots into one entry so --frozen-lockfile is stable (#36303) | P1 | ⏳ |
| 23 | `95cb6939fa` | #38796 | install: send credentials embedded in --registry and registry env var URLs (#38796) | P2 | ⏳ |
| 24 | `c1ae5ca1db` | #38809 | install: fail `bun outdated` and `bun update -i` when a dependency's manifest cannot be fetched (#38809) | P2 | ⏳ |
| 25 | `9fb606f09d` | #38853 | install: keep optional-peer-held packages when the lockfile is frozen (#38853) | P1 | ⏳ |
| 26 | `d1d256c3a1` | #38851 | install: stop looping on a peer dependency no published version satisfies (#38851) | P2 | ⏳ |
| 27 | `cfd3bea947` | #38828 | url: parse a bare bracketed IPv6 host so .npmrc //[::1]:port/ credential keys match their registry (#38828) | P2 | ⏳ |
| 28 | `71815dd728` | #38870 | install: fix the package id boundary in Lockfile::eql (#38870) | P1 | ⏳ |
| 29 | `7d276b95d0` |  | build: pin local debug git sha and drop --force from the rustup install step | P1 | ⏳ |
| 30 | `44acc3d610` | #38765 | install: fix crash loading a bun.lock with workspaces but no packages object (#38765) | P1 | ⏳ |
| 31 | `6324a589a4` | #38723 | prune: open a workspace's tree at the workspace path, not through node_modules/<name> (#38723) | P1 | ⏳ |
| 32 | `87b26b57fa` | #38736 | install: keep trustedDependencies and patchedDependencies order in bun.lock (#38736) | P2 | ⏳ |
| 33 | `03f9b18645` | #38738 | install: link bins whose target has a trailing slash (#38738) | P2 | ⏳ |
| 34 | `3b38ea25e9` | #38271 | install: let the walker own the cache dir it walks and build InstallDirState in one go (#38271) | P2 | ⏳ |
| 35 | `e9b5e63b4e` | #38806 | install: keep the scope when a yarn.lock npm: alias points at a scoped package (#38806) | P2 | ⏳ |
| 36 | `6028d73917` | #38755 | serve: add ServerConfig.is_node_http_server and key the node:http lifecycle paths on it (#38755) | P2 | ⏳ |
| 37 | `69737b969d` | #38729 | ci: trigger a bun.com deploy when docs, bun-types or install scripts change (#38729) | P2 | ⏳ |
| 38 | `0125363bdb` | #38705 | docs: add voice guidelines to the contributing page (#38705) | P2 | ⏳ |
| 39 | `9805144f6c` | #38686 | docs(pm): make the dedupe / prune / audit fix / licenses / --filter / --catalog docs readable (#38686) | P1 | ⏳ |
| 40 | `302d15da2e` | #38333 | install: pnpm parity — dedupe, prune, pm licenses, audit fix, add --filter/--catalog, nested overrides, transitive update, and workspace fixes (#38333) | P1 | ⏳ |
| 41 | `5638c62153` | #38441 | docs: audit guides and Node.js compatibility page (#38441) | P2 | ⏳ |
| 42 | `9b3b847c00` | #38269 | install: stage git cache folders, require completion markers on hit, fix bun patch for non-npm deps and isolated hang (#38269) | P1 | ⏳ |
| 43 | `a22baa1a97` | #36298 | install(hoisted): defer nested skip until parent tree is installed (#36298) | P2 | ⏳ |
| 44 | `93b7de0964` | #32749 | install: hash patch contents with SHA-1 instead of Wyhash11 (#32749) | P2 | ⏳ |

## TLS/HTTP（40 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `4199361edf` | #39632 | tls: send a bare RST from terminate(), no close_notify (#39632) | P2 | ⏳ |
| 2 | `a35696478d` | #39621 | usockets: skip the poll-error close for a socket a handler already closed (#39621) | P2 | ⏳ |
| 3 | `7da5a09fa4` | #39590 | fetch: park an unread body stream instead of buffering it without bound (#39590) | P2 | ⏳ |
| 4 | `32e87032b9` | #39606 | node:http: check the native writeHead through the caller's exception scope (worker-terminate-funnels http) (#39606) | P2 | ⏳ |
| 5 | `547bc99656` | #39610 | usockets: report a peer reset on a paused socket on kqueue (#39610) | P1 | ⏳ |
| 6 | `152c561cc4` | #39548 | valkey: close at once when a TLS fast shutdown is deferred (#39548) | P2 | ⏳ |
| 7 | `72e37255cb` | #39605 | fetch: set TCP keepalive once per connection instead of once per request (#39605) | P2 | ⏳ |
| 8 | `c4618cd36f` | #39552 | node:dns: treat a third argument to resolve* and reverse as the callback (#39552) | P2 | ⏳ |
| 9 | `b9f509020d` | #39600 | usockets: report a peer reset behind unread data as ECONNRESET, not 'end' (#39600) | P1 | ⏳ |
| 10 | `cac1414fed` | #38900 | Remove dead code from node:http2, the HTTP/2 parser, JSC bindings, uSockets, and the builtin-name tables (#38900) | P2 | ⏳ |
| 11 | `4d00d0bee3` | #39539 | test(node-https-checkServerIdentity): spawn one child instead of four (#39539) | P2 | ⏳ |
| 12 | `619ea140bd` | #39472 | Route ICU, libuv and BoringSSL's remaining allocations through mimalloc (#39472) | P2 | ⏳ |
| 13 | `5cf4e0f768` | #39466 | test: lower the jsresult-swallow inventory entry for h2_frame_parser.rs to 4 (#39466) | P2 | ⏳ |
| 14 | `10a61153bc` | #37673 | tls: deliver application data written before the handshake over a Duplex or named pipe (#37673) | P1 | ⏳ |
| 15 | `5c8725fc5a` | #39469 | node:http2: take inbound header names from the per-VM HTTPHeaderIdentifiers cache (#39469) | P2 | ⏳ |
| 16 | `9f6748857b` | #39448 | Remove dead code from the node:http2 legacy inbound path, the watcher loader column, unused native bindings, builtins.d.ts and misc crates (#39448) | P2 | ⏳ |
| 17 | `6de9f9b35a` | #39435 | ws: load node:http lazily (#39435) | P2 | ⏳ |
| 18 | `1367067163` | #36909 | node:tls: pass the thrown Error, not the internal exception wrapper, to 'error' over a Duplex transport (#36909) | P2 | ⏳ |
| 19 | `6b57f807fb` | #39364 | node:http: stop writing Connection: close into a response body on destroy() (#39364) | P2 | ⏳ |
| 20 | `10bc68b896` | #39387 | tls: convert exportKeyingMaterial arguments before fetching the SSL pointer (#39387) | P2 | ⏳ |
| 21 | `f90b90dc4c` | #39391 | http_parser: reject execute()/finish() on an uninitialised HTTPParser (#39391) | P2 | ⏳ |
| 22 | `b344c26a39` | #37570 | tls: read the pfx option through ArrayBuffer::byte_slice() (#37570) | P2 | ⏳ |
| 23 | `77828e4f28` | #37538 | node:http2: throw ERR_HTTP2_ORIGIN_LENGTH instead of panicking on an oversized origin (#37538) | P2 | ⏳ |
| 24 | `83d65fac0a` | #39139 | http2: resolve BatchSegment to its bytes in one place (#39139) | P2 | ⏳ |
| 25 | `a42889a887` | #39249 | Remove dead code from webcrypto, the node:http binding, the class codegen, build scripts, and misc crates (#39249) | P2 | ⏳ |
| 26 | `e1a4ba70d0` | #39160 | dns: replace the packed CacheConfig with a pending_slot: Option<u8> field (#39160) | P2 | ⏳ |
| 27 | `4d129a0f06` | #38699 | bench: homepage benchmark harness + express/websocket/postgres bench fixes (#38699) | P1 | ⏳ |
| 28 | `da128674b3` | #39148 | node:http2: pass SendDataOptions to send_data instead of three bools (#39148) | P2 | ⏳ |
| 29 | `47fb36e4f3` | #39141 | websocket: return publish_ctx's app and flags as a struct instead of a tuple (#39141) | P2 | ⏳ |
| 30 | `088da62b67` | #33974 | usockets: defer eof for a paused socket that already sent FIN; stop backpressure pauses from holding the loop (#33974) | P2 | ⏳ |
| 31 | `7adb357402` | #38815 | websocket client: treat a buffer that cannot grow as out of memory on every path (#38815) | P2 | ⏳ |
| 32 | `a5c86aec74` | #36411 | fetch(h2): cap CONTINUATION frames per header block (CVE-2024-28182) (#36411) | P1 | ⏳ |
| 33 | `26ec34992a` | #38746 | websocket: drop the write-only ProxyTlsHandshake state (#38746) | P2 | ⏳ |
| 34 | `43afad2dd4` | #38661 | node:http: keep the server wrapper alive while a connection outlives close() (#38661) | P2 | ⏳ |
| 35 | `4c0c674e8d` | #38213 | Remove dead code from the streams bindings, node:http, bun_sys, lsquic_sys, and orphaned files (#38213) | P2 | ⏳ |
| 36 | `f7ad274e3f` | #38044 | node:http2: release streams whose END_STREAM was flushed from the outbound queue (#38044) | P2 | ⏳ |
| 37 | `f9177aaecc` | #37996 | streams: track HTTPServerWritable's done/aborted flags as one state enum (#37996) | P2 | ⏳ |
| 38 | `ada9163f27` | #38243 | websocket: fire close on terminate() of a wss:// socket with a dead peer (#38243) | P2 | ⏳ |
| 39 | `40546a0e91` | #37367 | mimalloc: sync the fork with upstream dev3, fix the Android emulated-TLS crash (#37367) | P1 | ⏳ |
| 40 | `18059646e1` | #37961 | h2: test that a header block spanning HEADERS + two CONTINUATIONs is reassembled (#37961) | P2 | ⏳ |

## Spawn/Process（18 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `0a4e3b1e19` | #39654 | process: NUL-terminate the PSI trigger that arms memoryPressure on Linux (#39654) | P1 | ⏳ |
| 2 | `c7eb848e65` | #39602 | mimalloc: don't nanosleep(0) on the JS thread when waking from epoll (#39602) | P2 | ⏳ |
| 3 | `91cdf1595f` | #39593 | process.memoryUsage: report heapUsed from the most recent collection (#39593) | P2 | ⏳ |
| 4 | `23b18ddbc5` | #39536 | worker_threads: don't build fd stdio or reify all of process at worker startup (#39536) | P2 | ⏳ |
| 5 | `dc59d3e740` | #37296 | process.report: check exceptions before putDirect in getReport (worker.terminate race) (#37296) | P1 | ⏳ |
| 6 | `66bbc0c113` | #39423 | webview: implement the Chrome backend's spawn path on Windows (#39423) | P2 | ⏳ |
| 7 | `079cb0a6a8` | #38660 | Worker teardown, round 3: node:vm timeout on TerminationDeadline; take-at-landing termination; exit/streams/serve/valkey/Bun.build fixes (#38660) | P1 | ⏳ |
| 8 | `0bcde258a3` | #39395 | HTMLRewriter: defer freeing the pipe when a pin holds its last ref (#39395) | P2 | ⏳ |
| 9 | `98342ed4ac` | #38883 | spawnSync: don't run the bun:test timeout callback while the isolated loop is active (#38883) | P2 | ⏳ |
| 10 | `8873fb12f3` | #38750 | bun test --isolate: kill module-scope subprocesses of every file at the isolation swap (#38750) | P2 | ⏳ |
| 11 | `bee1be3b7f` | #39126 | cli: keep a script's start and end time on its spawned process record (#39126) | P2 | ⏳ |
| 12 | `9cff2a1ae7` | #38641 | FileSink: release the event loop keep-alive when flush() drains the buffer (#38641) | P2 | ⏳ |
| 13 | `97a4363115` | #38457 | Worker teardown: more fixes from fuzzing terminate()/process.exit() lifetimes; WebKit bump for Atomics.wait (#38457) | P1 | ⏳ |
| 14 | `eabb96de72` | #38483 | worker: wake the loop when a worker stops itself from an immediate (process.exit() / uncaught error) (#38483) | P2 | ⏳ |
| 15 | `baf62f9697` | #38442 | bun test: only run process.on('exit') listeners when node:test APIs were used (#38442) | P2 | ⏳ |
| 16 | `7ba276f943` | #38436 | Worker teardown: fixes from fuzzing terminate()/process.exit() lifetimes (#38436) | P1 | ⏳ |
| 17 | `b555e06414` | #38291 | mimalloc: register fork handlers once per process (fixes macOS abort in astro/vite builds); build: --local-deps (#38291) | P1 | ⏳ |
| 18 | `18391f652b` | #38229 | worker_threads: don't drop stdout/stderr on synchronous worker exit; honor exitCode set in 'exit' listeners (#38229) | P2 | ⏳ |

## Bundler（21 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `4673c48bb8` | #39591 | bundler: don't emit chunks for import() targets referenced only from dead code (#39591) | P2 | ⏳ |
| 2 | `81e9ec5691` | #39501 | share one calc parser body per css value type (#39501) | P2 | ⏳ |
| 3 | `695e2c7142` | #38228 | node:vm: keep lineOffset/columnOffset from overflowing JSC parser positions (#38228) | P2 | ⏳ |
| 4 | `2a707c0dda` | #35644 | bun build --no-bundle: write output files when --outdir is set (#35644) | P2 | ⏳ |
| 5 | `92ebcce58b` | #39429 | js_parser: write a substituted child back to its parent in one place (#39429) | P2 | ⏳ |
| 6 | `0774dedb5f` | #38296 | error printer: remap frames when the original source is unavailable, and not twice after error.stack (#38296) | P1 | ⏳ |
| 7 | `30fa519703` | #39368 | Bump WebKit: URL parser table-lookup SIMD + host:port fast path (#39368) | P2 | ⏳ |
| 8 | `3cf314956b` | #39273 | Bump WebKit: faster URL parser; don't re-run ICU on parser-produced punycode (#39273) | P2 | ⏳ |
| 9 | `1d230e2ef1` | #39166 | bundler: replace IntermediateOutput::code's two bool parameters with enums (#39166) | P2 | ⏳ |
| 10 | `22d87802f2` | #39142 | shell_parser: replace break_word_impl's three bools with an AddDelimiter enum (#39142) | P2 | ⏳ |
| 11 | `dfb31d8d5b` | #39164 | node/types: replace the StringOrBuffer parser bool flags with enums (#39164) | P2 | ⏳ |
| 12 | `bcba4722b8` | #39169 | js_parser: type RequireString.unwrapped_id as an optional index (#39169) | P2 | ⏳ |
| 13 | `0bfeade53f` | #39161 | js_parser: pass visit_decl its flags as a VisitDeclOpts struct (#39161) | P2 | ⏳ |
| 14 | `c8f8a2f17f` | #39153 | sql: replace the datetime text parser's two bool parameters with enums (#39153) | P2 | ⏳ |
| 15 | `8c4749620e` | #39134 | pack: name the scope and dependency locals in iterate_bundled_deps (#39134) | P2 | ⏳ |
| 16 | `a22befc4d9` | #39132 | transpiler cache: convert the cache file length to i64 once in save (#39132) | P2 | ⏳ |
| 17 | `92ad4496ac` | #38819 | bundler: name the entry point flag at every construction and drop the unread is_html bit (#38819) | P2 | ⏳ |
| 18 | `75f7be6d3a` | #38429 | bundler: shift source maps past the spliced HTML import manifest (#38429) | P2 | ⏳ |
| 19 | `d2e5359b96` | #38294 | sourcemap: update the remaining mentions of ParseResult::Fail (#38294) | P1 | ⏳ |
| 20 | `f2c0327696` | #38280 | sourcemap: make mapping::parse return a Result instead of a hand-rolled two-variant enum (#38280) | P1 | ⏳ |
| 21 | `508ee60d54` | #38263 | sourcemap: derive the parse failure message from the error instead of storing both (#38263) | P1 | ⏳ |

## JSC/VM（17 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `35f46628dc` | #39541 | Don't request a GC before waiting on the entry point (#39541) | P1 | ⏳ |
| 2 | `1b881a9d2f` | #38040 | vm.Script: compile the source once and link that compile in every context it runs in (#38040) | P2 | ⏳ |
| 3 | `7beafc21ec` | #39529 | node:vm: fix crash creating a ShadowRealm inside a context (#39529) | P1 | ⏳ |
| 4 | `54784dcefd` | #39482 | napi: export uv_tty_reset_mode on posix (#39482) | P2 | ⏳ |
| 5 | `2693494b69` | #39418 | napi_get_prototype: return null for a Proxy without running its trap, like Node (#39418) | P2 | ⏳ |
| 6 | `6fe59cb4bc` | #39468 | URL: reuse input string for href, per-VM base cache, judge literal punycode without full ICU (#39468) | P2 | ⏳ |
| 7 | `5261ca6303` | #39051 | node:inspector: derive scriptParsed isModule and scriptLanguage from JSC's scriptType (#39051) | P2 | ⏳ |
| 8 | `f4925954f5` | #37450 | Error.prepareStackTrace: index source URLs by visible frame, not by JSC frame (#37450) | P2 | ⏳ |
| 9 | `3d369b435c` | #39110 | bun-inspector-protocol: regenerate the JSC protocol snapshot from the pinned WebKit (#39110) | P2 | ⏳ |
| 10 | `4ba20033bf` | #36869 | bun:jsc: profile() accepts any callable, not just JSFunction cells (#36869) | P2 | ⏳ |
| 11 | `8a09cf7ecf` | #39152 | jsc: name the line:column flag at source_url_formatter call sites (#39152) | P2 | ⏳ |
| 12 | `69f56e88f0` | #39099 | bun test --parallel: kill a worker whose IPC stream is corrupt on Windows too, and report the cause (#39099) | P2 | ⏳ |
| 13 | `2d3b1eed18` | #38711 | types: document the bun:jsc declarations (#38711) | P2 | ⏳ |
| 14 | `60f6e186c4` | #38381 | node:vm: reject array and function options like Node's validateObject (#38381) | P2 | ⏳ |
| 15 | `a0921e1608` | #38299 | One door out of a VM's thread: tickets + a teardown that waits (#38299) | P1 | ⏳ |
| 16 | `abe300778c` | #38330 | threading: finish a WaitGroup without holding a reference into it past the release (#38330) | P2 | ⏳ |
| 17 | `54f027194f` | #38300 | napi: don't deliver terminations inside ungated functions (#38300) | P2 | ⏳ |

## SQL/Valkey（26 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `24c0063335` | #39544 | valkey: fix null array, null CRLF, big number and blob error replies (#39544) | P1 | ⏳ |
| 2 | `e19faeb527` | #39595 | sql: drop preReserved marks that outlive their reservation (#39595) | P2 | ⏳ |
| 3 | `e5b534d8a1` | #39598 | sql: keep the reservation's pool slot when reserved.begin() rejects before BEGIN (#39598) | P1 | ⏳ |
| 4 | `8df7fe073c` | #39547 | valkey: reject subscribe() on a failed client before storing the listener (#39547) | P1 | ⏳ |
| 5 | `681a49bee1` | #39575 | valkey: a duplicate starts with no close history (#39575) | P1 | ⏳ |
| 6 | `254b0656e0` | #33743 | sql: keep pool slot queryCount balanced across connection death (#33743) | P2 | ⏳ |
| 7 | `13845e1b43` | #39546 | valkey: cancel the retry timer on close() and connect() (#39546) | P1 | ⏳ |
| 8 | `85c898338a` | #39543 | valkey: release the socket keep-alive ref at the close-event entry (#39543) | P1 | ⏳ |
| 9 | `5ebcafff1e` | #39570 | valkey: use VecDeque for the command queues; LinearFifo rejects droppable items (#39570) | P1 | ⏳ |
| 10 | `891c1c7221` | #39530 | valkey: tolerate a dead JS wrapper in update_poll_ref (#39530) | P2 | ⏳ |
| 11 | `4c689909e6` | #38281 | valkey: count idle time from connect and restart it on incoming data (#38281) | P2 | ⏳ |
| 12 | `4ad4a3e185` | #39513 | valkey: run a dial that fails before there is a socket through the deferred close (#39513) | P1 | ⏳ |
| 13 | `39fde480e9` | #39511 | valkey: close the socket on every fail() and mark the client disconnected before onclose runs (#39511) | P1 | ⏳ |
| 14 | `486e78ca9f` | #39454 | sql: support AbortSignal in reserve() so a pending reservation can be cancelled (#39454) | P2 | ⏳ |
| 15 | `ddf829cea0` | #37212 | bun:sqlite: fix stale Structure reads when a getter mutates the params object during bind (#37212) | P1 | ⏳ |
| 16 | `ff5fc1ffe2` | #39441 | sql(postgres): floor binary timestamp microseconds to ms instead of truncating toward zero (#39441) | P2 | ⏳ |
| 17 | `79f2b92809` | #38143 | sql: decode a result column named "" instead of crashing (#38143) | P1 | ⏳ |
| 18 | `10cdfe6ada` | #37211 | bun:sqlite: fix crash on missing unnamed parameter in strict mode (#37211) | P1 | ⏳ |
| 19 | `f0f6b2cbb6` | #39271 | Lint the RedisClient class in redis.d.ts against the valkey.classes.ts tables (#39271) | P2 | ⏳ |
| 20 | `371d938a94` | #39135 | sql: set a cell's column index and kind in one place (#39135) | P2 | ⏳ |
| 21 | `c2fa121086` | #35950 | sql(sqlite): pass positional bindings to bun:sqlite as one array, not spread (#35950) | P2 | ⏳ |
| 22 | `008d700575` | #38619 | sql: run onconnect/onclose in the async context the SQL instance was created in (#38619) | P1 | ⏳ |
| 23 | `b9ef885a77` | #32089 | sql: fix the build after #32089 × #37275 (LISTEN/NOTIFY error path) (#38628) | P1 | ⏳ |
| 24 | `2f5c1804ef` | #32089 | Add sql.listen() and sql.notify() for PostgreSQL LISTEN/NOTIFY (#32089) | P2 | ⏳ |
| 25 | `032b8dbf13` | #38451 | sql(mysql): explain the remedy when public key retrieval is refused (#38451) | P2 | ⏳ |
| 26 | `c0804701e3` | #38000 | postgres: record which connection counter a request bumped as one enum (#38000) | P2 | ⏳ |

## CSS/HTML（15 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `8226b3d6e8` | #39577 | css: keep the lower bound when simplifying clamp() (#39577) | P2 | ⏳ |
| 2 | `bc66d49f4e` | #39586 | Restore bun_css dependency of bun_runtime (#39586) | P2 | ⏳ |
| 3 | `6c37d21436` | #39567 | dev server: report a route whose html file cannot be read instead of crashing (#39567) | P1 | ⏳ |
| 4 | `3926aff707` | #39394 | HTMLRewriter: decode content-op string arguments into owned slices (#39394) | P2 | ⏳ |
| 5 | `eff1f3e4b4` | #39145 | HTMLRewriter: store each on() registration as one struct instead of two parallel vecs (#39145) | P2 | ⏳ |
| 6 | `291c5469ac` | #39171 | bake: name both flags at every insert_stale_extra call (#39171) | P2 | ⏳ |
| 7 | `458dcad3e3` | #39170 | css: return named component structs from the color helpers instead of tuples (#39170) | P2 | ⏳ |
| 8 | `2f941ed4c3` | #39173 | css: return RGBA from parse_hash_color instead of a tuple (#39173) | P2 | ⏳ |
| 9 | `dc7800c98a` | #39122 | css: pass SelectorFlags to SelectorBuilder::build instead of three bools (#39122) | P2 | ⏳ |
| 10 | `c21d95a467` | #39138 | bake: write the prerender route walk and the collision noun once (#39138) | P2 | ⏳ |
| 11 | `921129ab04` | #39151 | dev server: keep a file's two edge list heads in one Vec (#39151) | P2 | ⏳ |
| 12 | `d97b0a7825` | #39121 | css: name merge_style_rules's parameters by role (#39121) | P2 | ⏳ |
| 13 | `18970eb48d` | #39133 | bake: resize the graph trace bits through GraphTraceState::bits (#39133) | P2 | ⏳ |
| 14 | `fd9a307d63` | #38747 | css: drop the var() tracking that nothing ever turned on (#38747) | P2 | ⏳ |
| 15 | `ada2a67ef1` | #38656 | HTMLRewriter: don't read a streamed input ahead of its reader (#38656) | P2 | ⏳ |

## Shell（7 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `e878e03343` | #39540 | windows: delay-load user32/shell32/oleaut32/userenv, parse argv without shell32 (#39540) | P2 | ⏳ |
| 2 | `8000230105` | #39578 | shell(rm): stop the recursive walk from aborting on entries deeper than PATH_MAX (#39578) | P2 | ⏳ |
| 3 | `bd2c1b397c` | #38379 | shell(mkdir, touch): report operands longer than the path buffers instead of aborting (#38379) | P2 | ⏳ |
| 4 | `ddcb199909` | #37521 | shell(rm): stop panicking on operands longer than the path scratch buffers (#37521) | P2 | ⏳ |
| 5 | `20d04673b9` | #37921 | shell: widen the brace expansion output slot counter (#37921) | P2 | ⏳ |
| 6 | `c014fc48d4` | #39147 | shell(cat): map Step to a Yield in one place (#39147) | P2 | ⏳ |
| 7 | `b1e6c59026` | #39131 | shell: return which's PATH and cwd lookup as a struct instead of a tuple (#39131) | P2 | ⏳ |

## Test（12 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `ec7a24ba6c` | #39509 | bun:test: convert scope receivers to undefined in mock host functions (#39509) | P2 | ⏳ |
| 2 | `256b6fb7d1` | #35863 | bun test: stop panicking on a path argument or tree entry longer than the path buffer (#35863) | P2 | ⏳ |
| 3 | `c97a68fff9` |  | Delete unnecessary test | P2 | ⏳ |
| 4 | `c3995e43d5` | #39236 | Revert "ci: qualify test files for the parallel bucket per file, not per directory (#39236)" (#39369) | P2 | ⏳ |
| 5 | `619a88db33` | #39236 | ci: qualify test files for the parallel bucket per file, not per directory (#39236) | P2 | ⏳ |
| 6 | `486af281cf` | #39143 | test runner: drop the allow_in_preload flag from GetActiveCfg (#39143) | P2 | ⏳ |
| 7 | `e18296ac71` | #39218 | ci: run Miri crates concurrently, and shrink the one 7-minute test under Miri (#39218) | P2 | ⏳ |
| 8 | `e02946df69` | #39215 | ci: skip the slowest 1% of test files on the PR darwin lane (#39215) | P2 | ⏳ |
| 9 | `5998546aeb` | #39195 | ci: give PR builds one darwin aarch64 test lane that any mac agent can take (#39195) | P2 | ⏳ |
| 10 | `b8610b9892` | #39191 | ci: run all darwin test lanes on main / opt-in only for now (#39191) | P2 | ⏳ |
| 11 | `3753c8bfc6` | #38242 | Fix FreeBSD runtime issues found by running the test suite (#38242) | P2 | ⏳ |
| 12 | `347d291446` | #38293 | ci: bring the darwin x64 test lane back (main only for now) (#38293) | P2 | ⏳ |

## Windows（4 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `6dfa8f4227` | #39614 | Bump libuv and WebKit for the Windows startup work (#39614) | SKIP | ⏳ |
| 2 | `1f4eaa05b8` | #37745 | build: trace the symbol order file on windows x64 and arm64 (#37745) | SKIP | ⏳ |
| 3 | `6c076d4908` | #39615 | socket: report a peer reset on Windows as close(socket, ECONNRESET) instead of a code-less error (#39615) | SKIP | ⏳ |
| 4 | `d2654d347d` | #39355 | fs: writeFile with flag "a+" overwrites from offset 0 on Windows (#39355) | SKIP | ⏳ |

## Dead code（3 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `a1da88c23d` | #37301 | Remove dead code from bun_ast, bun_runtime, and unused Cargo dependency edges (#37301) | P3 | ⏳ |
| 2 | `6948a122ca` | #39574 | Remove dead code from the libuv stub headers, bun-error, bun_zlib_sys and misc crates (#39574) | P3 | ⏳ |
| 3 | `a2496de447` | #32357 | getcwd: report CurrentWorkingDirectoryUnlinked from a deleted cwd again (#32357) | P3 | ⏳ |

## Docs/CI/Build（24 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `94c3eceb8b` | #39371 | Upgrade WebKit to 47f7250137c6 (#39371) | P3 | ⏳ |
| 2 | `4fd5048170` | #39462 | ci: drop the [1m] model suffix from the issue-triage workflows (#39462) | P3 | ⏳ |
| 3 | `8d9cbbdb3b` | #39425 | build: pin the build-std feature set and disallow std::backtrace (#39425) | P3 | ⏳ |
| 4 | `1dd66afde2` | #39326 | build rust std without the backtrace symbolizer (#39326) | P3 | ⏳ |
| 5 | `5bae64f427` | #39324 | share one sort instance across cold rust sort sites (#39324) | P3 | ⏳ |
| 6 | `fea1829e71` | #39373 | ci: re-land the per-file parallel allowlist with a denylist of every file that has failed in the batch (#39373) | P3 | ⏳ |
| 7 | `11678f515b` | #39013 | docs: corrections from re-verifying the fact-fix pass (#39013) | P3 | ⏳ |
| 8 | `7592a6bb51` | #38982 | Fix abort when a native error message exceeds 1 GiB of non-ASCII UTF-8 (#38982) | P3 | ⏳ |
| 9 | `7b9a569a98` | #39026 | Pin follow-ups: init `pinned` in asBunArrayBuffer, release zlib async-write pins, sync borrow docs (#39026) | P3 | ⏳ |
| 10 | `d3f975bd0e` | #38899 | docs: fix the factual errors found while rewording the docs (#38899) | P3 | ⏳ |
| 11 | `df4a04003d` | #38930 | build, ci: rustc annotation bodies, full CI target list, string-map autofix, arm64 rust CPU baseline (#38930) | P3 | ⏳ |
| 12 | `d558a50393` | #38929 | ci: pin mordant at the plain-language messages (#38929) | P3 | ⏳ |
| 13 | `c418051447` | #38863 | build: pass --locked to cargo (#38863) | P3 | ⏳ |
| 14 | `3542216ceb` | #38875 | ci: pin mordant at the renamed lints; rename the disabled list and baseline keys to match (#38875) | P3 | ⏳ |
| 15 | `b44b2c4b7d` | #38865 | ci: one Rust lints workflow with a shared setup; run mordant without the wrapper script (#38865) | P3 | ⏳ |
| 16 | `3f8b7e10cb` | #38852 | ci: mordant reports findings over the baseline instead of aborting the crate (#38852) | P3 | ⏳ |
| 17 | `39fb3c103e` | #38846 | ci: bump the mordant pin (sixteen new lints) and record their baseline (#38846) | P3 | ⏳ |
| 18 | `f89d3709ad` | #38760 | docs: voice pass over docs/ (#38760) | P3 | ⏳ |
| 19 | `e7460e3c77` | #38718 | landing-prs: point docs prose at the voice rules on the contributing page (#38718) | P3 | ⏳ |
| 20 | `d4ccab469b` | #38603 | docs: restore the Remix guide (for Remix 3) and the blob.stream chunk-size sections (#38603) | P3 | ⏳ |
| 21 | `7cf62962b6` | #38246 | Android: fix --compile executables (PIE load bias) and Intl's default locale (WebKit bump) (#38246) | P3 | ⏳ |
| 22 | `c1fe6c136c` | #38459 | ci: cache the dylint binaries and driver in the mordant job (#38459) | P3 | ⏳ |
| 23 | `9c629a4d4b` | #38440 | docs: update Vercel guide for Bun.serve() deployments (#38440) | P3 | ⏳ |
| 24 | `1cf8af0a1e` | #38320 | ci: run the mordant lint pack as an advisory ratchet (#38320) | P3 | ⏳ |

## Other（88 个）

| # | SHA | PR# | 描述 | 优先级 | 状态 |
|---|---|---|---|---|---|
| 1 | `34cbb9a40b` |  | Fix edgecase in v8 CPU profiler | P2 | ⏳ |
| 2 | `6ee3009e66` |  | Read BUN_FEATURE_FLAG_EXPERIMENTAL_BAKE and BUN_FEATURE_FLAG_NO_LIBDEFLATE from the environment again | P2 | ⏳ |
| 3 | `118154c867` | #39523 | libjpeg-turbo: use the clz intrinsic and enable the x86_64 SIMD kernels (#39523) | P2 | ⏳ |
| 4 | `ddc9b3e0a4` | #39611 | FileSink, ByteStream: do not end a native sink while its last bytes are still buffered (#39611) | P2 | ⏳ |
| 5 | `a8861fc0a3` | #39596 | Bun.password: verify argon2 hashes with memoryCost below 8 again (#39596) | P2 | ⏳ |
| 6 | `8e421ab802` | #39597 | verify-baseline-static: allowlist llint_op_wide16_wide16 decode false positive (#39597) | P2 | ⏳ |
| 7 | `87ac50c414` | #34929 | node:crypto: fix SIGABRT on shake128/256 digest with outputLength >= 2^31 (#34929) | P2 | ⏳ |
| 8 | `1336918870` | #39525 | Convert scope-object receivers in StringDecoder, node error toString, fs.Stats, Node-API and V8 callbacks (#39525) | P2 | ⏳ |
| 9 | `b938280cdd` | #39557 | Buffer#copy: keep offsets above MAX_SAFE_INTEGER instead of turning them into 0 (#39557) | P2 | ⏳ |
| 10 | `f12696ffe4` | #29587 | Dedupe extracted embedded native modules in compiled binaries (#29587) | P2 | ⏳ |
| 11 | `4855666a5b` | #39097 | webview: close the views orphaned by a browser death (#39097) | P2 | ⏳ |
| 12 | `7cbd1c8430` | #39535 | node:module: non-enumerable Module.prototype; setting Module.wrapper to its default is not an override (unblocks jest under --bun) (#39535) | P2 | ⏳ |
| 13 | `9ee60cb22f` | #39485 | decode legacy encodings with encoding_rs instead of the webkit codecs (#39485) | P2 | ⏳ |
| 14 | `92fa5e49ff` | #39558 | Bun.file().arrayBuffer(): stop panicking at 4 GiB, throw above the ArrayBuffer limit (#39558) | P2 | ⏳ |
| 15 | `5a94459b2a` | #39564 | Throw instead of aborting when child output does not fit in a Buffer (#39564) | P2 | ⏳ |
| 16 | `260120b3da` | #38368 | cli: stop aborting on --cwd and --tsconfig-override values longer than the path join buffer (#38368) | P2 | ⏳ |
| 17 | `d02226b0e5` | #39521 | keep the out of memory throw out of every host function (#39521) | P2 | ⏳ |
| 18 | `df4fe1e7b6` | #39510 | Bun.serve: arm the streaming response's uWS callbacks before attaching the stream (#39510) | P2 | ⏳ |
| 19 | `e66ebb8325` | #39489 | Pin the invariants the shared string table init lambdas rely on (#39489) | P2 | ⏳ |
| 20 | `13c0f044ba` | #29642 | Fix crash and dropped properties in Bun.inspect when a property lookup or getPrototypeOf throws during the property walk (#29642) | P2 | ⏳ |
| 21 | `a53ac0c0ef` | #39197 | watcher: free the owned path of evicted watchlist entries (#39197) | P2 | ⏳ |
| 22 | `6e35c79cd1` | #39486 | share one lazy init lambda per string table (#39486) | P2 | ⏳ |
| 23 | `09f1ca492f` | #38360 | fs.watch: do not panic on directories deeper than PATH_MAX in recursive watches (#38360) | P2 | ⏳ |
| 24 | `99905536cb` | #37237 | Throw instead of aborting when stream text() consumers accumulate more than 2^31-1 bytes (#37237) | P2 | ⏳ |
| 25 | `dc11a69a74` | #36913 | node:util: fix isError crash on revoked proxies and getPrototypeOf traps (#36913) | P2 | ⏳ |
| 26 | `977f3b50d5` | #39081 | webview: settle every view's pending promises when Chrome dies (#39081) | P2 | ⏳ |
| 27 | `258517aa19` | #39229 | Add `bun pm diff` (#39229) | P2 | ⏳ |
| 28 | `c238a29bdf` | #39393 | Read sink.start() options before resolving the native sink (#39393) | P2 | ⏳ |
| 29 | `4fa055c323` | #39389 | server.publish()/ws.publish(): convert topic and message before reading server state (#39389) | P2 | ⏳ |
| 30 | `922f373eb1` | #39465 | JSSink: drop the unmatched unprotect() of the pump controller in detach() (#39465) | P2 | ⏳ |
| 31 | `7a8ce75359` | #39460 | buffer: decode hex from the low byte of each UTF-16 code unit like node (#39460) | P2 | ⏳ |
| 32 | `c09b847323` | #39406 | node:buffer: treat a detached view as empty in compare, equals, swapNN and as a fill value (#39406) | P2 | ⏳ |
| 33 | `8bc4d2a882` | #39417 | Stop zero-filling buffers that are overwritten anyway (compressors, image, text encoding, I/O, networking, paths) and make the compressors' allocations fallible (#39417) | P2 | ⏳ |
| 34 | `290d28bc46` | #39430 | bun:ffi: propagate a failure to read the viewSource descriptors (#39430) | P2 | ⏳ |
| 35 | `5c050bc338` | #39409 | Bun.serve: don't finalize the request again when error() upgraded or ended it (#39409) | P2 | ⏳ |
| 36 | `771c7e67e0` | #39388 | node:path: stringify String-object arguments before borrowing any argument (#39388) | P2 | ⏳ |
| 37 | `1de3d37118` | #32261 | Bun.plugin.clearAll(): clear namespaces and groups together (#32261) | P2 | ⏳ |
| 38 | `8326d1bd39` |  | Better URL snippet | P2 | ⏳ |
| 39 | `07d38c1716` | #39334 | Drop the DOMWrapperWorld wrapper HashMap (#39334) | P2 | ⏳ |
| 40 | `1726b144a0` | #39341 | init: use TypeScript 7 in every template (#39341) | P2 | ⏳ |
| 41 | `669bd826d4` | #39296 | BufferedReader: enforce the blob slice window at the read instead of after it (#39296) | P2 | ⏳ |
| 42 | `75fad5b142` | #39080 | node:buffer: writing into a detached Buffer returns 0 like Node instead of aborting (#39080) | P2 | ⏳ |
| 43 | `8c5296ac45` | #39277 | Drop the trailing period from the node-shaped AbortError message (#39277) | P2 | ⏳ |
| 44 | `eec9c8b736` | #39201 | FileReader: apply the slice window on the read_into pull path and end the stream when it is used up (#39201) | P2 | ⏳ |
| 45 | `22494bc820` | #39144 | text formats: name the input flags passed to with_text_format_source (#39144) | P2 | ⏳ |
| 46 | `f81643299b` | #39172 | server: write the AnyResponse pointer erasure and the deferred-body protect once (#39172) | P2 | ⏳ |
| 47 | `cdd2d05c64` | #38701 | Don't write Content-Length into the body when ending a close-delimited streamed response (#38701) | P2 | ⏳ |
| 48 | `dd30363869` | #39187 | Bun.Image: reject a byte-backed Blob passed to write(dest) instead of panicking (#39187) | P2 | ⏳ |
| 49 | `bd52ae6968` | #39155 | react_compiler: name the nesting passed to get_context_reassignment (#39155) | P2 | ⏳ |
| 50 | `668caf3da6` | #39095 | Reject sources of 2 GiB or more before parsing instead of aborting in usize2loc (#39095) | P2 | ⏳ |
| 51 | `d9ef7474c4` | #39158 | Blob: drop is_bun_file, a duplicate of needs_to_read_file (#39158) | P2 | ⏳ |
| 52 | `aeca7bc68e` | #39176 | Body: state the AnyBlob -> Value and DrainResult -> ByteStream mappings once (#39176) | P2 | ⏳ |
| 53 | `c1fcdb8615` | #39159 | Bun.serve: map RouteMethod to Option<Method> in one place (#39159) | P2 | ⏳ |
| 54 | `ab302f5adf` | #39136 | run: name the flags passed to configure_env_for_run (#39136) | P2 | ⏳ |
| 55 | `5448c1e603` | #39149 | publish: report a PublishError from one place (#39149) | P2 | ⏳ |
| 56 | `28a438d3cd` | #39117 | completions: name the bunx symlink path after the symlink parameter it feeds (#39117) | P2 | ⏳ |
| 57 | `c19cab407b` | #39118 | cli/open: name the editor binary lookup after what it holds (#39118) | P2 | ⏳ |
| 58 | `7d50fe5a91` | #39137 | ast: name BabyString::r#in's parameters for what they are (#39137) | P2 | ⏳ |
| 59 | `a962ffd46d` | #39119 | linker: name the relative import path locals after the Path fields they fill (#39119) | P2 | ⏳ |
| 60 | `99158b409b` | #39125 | node:path: name relative()'s buffers by role instead of by position (#39125) | P2 | ⏳ |
| 61 | `bcab5edce1` | #39140 | csrf: parse the encoding option in one place (#39140) | P2 | ⏳ |
| 62 | `967112c14d` | #39123 | ipc: convert JsError to IPCSerializationError through one From impl (#39123) | P2 | ⏳ |
| 63 | `7a09cfe0a0` | #39116 | yaml: map StringifyError to JsError in one place (#39116) | P2 | ⏳ |
| 64 | `88a6398836` | #38886 | Streams: one PipeReader loop with owned chunks, hold-not-adopt buffer pins, right-sized native pulls (#38886) | P2 | ⏳ |
| 65 | `957384105a` | #38824 | bunfig: send credentials written into the url of a registry object (#38824) | P2 | ⏳ |
| 66 | `63ffef8555` | #38943 | Make 13 hand-written extern "C" declarations agree between Rust and C++ (#38943) | P2 | ⏳ |
| 67 | `cf93e6d1ac` | #38695 | CompressionStream/DecompressionStream: emit each chunk's output in bounded steps (#38695) | P2 | ⏳ |
| 68 | `60dc7bd810` | #37648 | crypto: store PBKDF2's key length as usize (#37648) | P2 | ⏳ |
| 69 | `253d8770a8` | #38743 | pack: fill every placeholder in multi-argument error messages (#38743) | P2 | ⏳ |
| 70 | `0def73166f` | #38841 | Tidy: fold duplicated matches into one method, drop dead state (no behavior change) (#38841) | P2 | ⏳ |
| 71 | `41f848b109` | #38697 | serve: reload() refuses a config that would leave the server with no handler (#38697) | P2 | ⏳ |
| 72 | `2c2ef7cbff` | #30413 | repl: inline ghost-text suggestions for symbol autocomplete (#30413) | P2 | ⏳ |
| 73 | `4bf3f36456` | #38724 | XML: settle the Bun.XML contract — exact text, arrays, comments/PIs (#38724) | P2 | ⏳ |
| 74 | `7be23fd3eb` | #38693 | impl_field_parent!: stop reaching parents through readonly &self (#38693) | P2 | ⏳ |
| 75 | `056491fc37` | #37018 | TOML: map date/time values to Temporal, round-trip them through stringify (#37018) | P2 | ⏳ |
| 76 | `0b041cba13` | #38726 | PipeReader: don't re-deliver streamed bytes after a re-entrant read (#38726) | P2 | ⏳ |
| 77 | `c04101b414` |  | Fix merge issue | P2 | ⏳ |
| 78 | `326177306e` | #38604 | ThreadPool: wait for the batch you scheduled, not for the whole pool to go idle (#38604) | P2 | ⏳ |
| 79 | `27419b4d3d` | #38460 | Bump mordant to 3bcf116 (#38460) | P2 | ⏳ |
| 80 | `385aee693f` | #38444 | Remove the bun feedback command (#38444) | P2 | ⏳ |
| 81 | `840eac2ec3` | #38437 | Fix require() of an embedded CommonJS entry point in compiled executables (#38437) | P2 | ⏳ |
| 82 | `01aa7cd8d3` | #38384 | Bump mordant to 18a5734 (#38384) | P2 | ⏳ |
| 83 | `6855f522e2` | #38374 | Bump mordant to 4e08693 (#38374) | P2 | ⏳ |
| 84 | `e6978042a1` | #34317 | cli: restore `<name>`/`<package>` placeholders in package-manager `--help` (#34317) | P2 | ⏳ |
| 85 | `1b7bbd682a` | #34304 | macOS: export __mh_execute_header so flat-namespace dylibs can load (#34304) | P2 | ⏳ |
| 86 | `42d698e43c` | #33371 | Set has_loaded on every path that produces the entry point's source (#33371) | P2 | ⏳ |
| 87 | `9dc1c4bc0e` | #38106 | Make custom inspect on web platform prototypes writable (#38106) | P2 | ⏳ |
| 88 | `b5afcacd71` | #37625 | Update SAFETY comments that still named pre-port identifiers (#37625) | P2 | ⏳ |

---

## 使用方法

### 1. P0 先行
```bash
git cherry-pick 88165c6ef2
# 解决 JSBuffer.cpp 冲突（保留上游版本）
git add src/jsc/bindings/JSBuffer.cpp
git cherry-pick --continue
bun bd test test/js/node/module/sourcemap-simd.test.ts
bun bd test test/js/bun/util/highway-strings.test.ts
```

### 2. P1 按领域分组
按领域（Install/pnpm → TLS/HTTP → Spawn/Process → JSC/VM → ...）顺序 cherry-pick P1 commit。
每领域完成后运行相关测试验证。

### 3. P2/P3 按需
根据实际需要选择性 cherry-pick。SKIP 类跳过（Windows 专用）。

### 批量操作
```bash
# 查看某领域所有 P1 commit
grep '| P1 |' ohos/analys/cherry-pick-tracker-v1.4.0.md | grep 'Install'

# cherry-pick 多个
git cherry-pick <sha1> <sha2> <sha3>

# cherry-pick 失败时跳过继续
git cherry-pick --skip

# 放弃整个序列
git cherry-pick --abort
```

### 搜索特定 PR
```bash
# 按 PR 号搜索
git log --oneline dev..bun-v1.4.0 | grep 39616

# 按关键词搜索
git log --oneline dev..bun-v1.4.0 | grep -iE 'highway|simd'
```
