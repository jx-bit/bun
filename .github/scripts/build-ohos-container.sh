#!/bin/bash
# Build jy-bun for OHOS aarch64 INSIDE the social4hyq ci-runner container.
#
# Replicates social4hyq bun.rb's install-block environment (Formula/b/bun.rb
# lines 192-256): ohos-cross-libs + ohos-icu scaffolding, LD_LIBRARY_PATH,
# CC/CXX, rust env. Builds OUR jy-bun source (NOT the formula's ohos-bun
# source) with --webkit=local (our pinned WebKit fork at vendor/WebKit).
#
# Why a script, not inline YAML: the env setup is ~80 lines with many brew
# --prefix expansions and symlinks; a heredoc inside docker exec forces
# brittle nested-quoting. A committed script is syntax-checkable (bash -n)
# and mirrors social4hyq's own .github/scripts/build.sh layout.
#
# Preconditions (set up by the workflow before invoking this):
#   - `brew trust social4hyq/core` done → `brew install --only-dependencies`
#     poured llvm@21, ohos-sdk, icu4c@78, bun-bootstrap, openssl@3, cmake, ninja.
#   - rust-nightly resource staged at /data/storage/el2/base/tmp/rust-$RUST_TOOLCHAIN.
#   - WebKit fork checked out at /workspace/bun/vendor/WebKit.
#   - bun install already run (root + src/node-fallbacks).
#
# Signing: NOT done here. The container runs a Linux kernel (not OHOS), so
# unsigned ELFs exec fine (the musl loader does not check .codesign —
# confirmed: cargo reached symbol-relocation before failing on OpenSSL).
# install-bun-ohos.sh signs the final binary on the device at install time.
#
# Run via:
#   docker exec -e RUST_TOOLCHAIN -e NINJA_JOBS "$CONTAINER" \
#     bash /workspace/bun/.github/scripts/build-ohos-container.sh
set -euo pipefail

: "${RUST_TOOLCHAIN:?RUST_TOOLCHAIN must be set (passed via docker exec -e)}"
: "${NINJA_JOBS:=2}"

BREW_PREFIX=$(brew --prefix)
LLVM_PREFIX=$(brew --prefix llvm@21)
SDK_PREFIX=$(brew --prefix ohos-sdk)
ICU_PREFIX=$(brew --prefix icu4c@78)
BUN_BOOT_DIR=$(brew --prefix bun-bootstrap)/bin
RUST_HOME="/data/storage/el2/base/tmp/rust-${RUST_TOOLCHAIN}"
SRC=/workspace/bun
cd "$SRC"

# ── Build environment (bun.rb lines 192-247) ──────────────────────────
# rust cargo NEEDS libssl/libcrypto/libz (git2/registry transport); without
# them the musl loader hits "Error relocating cargo: SSL_get_error/zlibVersion:
# symbol not found" → 127 (bun.rb lines 195-199 document this exact failure).
# lld from llvm@21 also has runtime deps on libxml2/zlib; brew superenv
# strips system lib paths, so inject them explicitly (bun.rb lines 195-199).
# IMPORTANT: brew installs these under opt/<name>/lib (formula_opt_lib), NOT
# lib/<name>/lib — using the wrong path silently leaves libz.so unfound.
export LD_LIBRARY_PATH="$BREW_PREFIX/opt/openssl@3/lib:$BREW_PREFIX/opt/libxml2/lib:$BREW_PREFIX/opt/zlib/lib:${LD_LIBRARY_PATH:-}"
# llvm@21 only ships llvm-strip; bun's build script needs `strip` (bun.rb 201-202).
mkdir -p .bin
ln -sf "$LLVM_PREFIX/bin/llvm-strip" .bin/strip
export PATH="$LLVM_PREFIX/bin:$RUST_HOME/bin:$BUN_BOOT_DIR:$BREW_PREFIX/bin:.bin:${PATH:-}"
# CC/CXX: raw llvm@21 clang (no signing shims — device signs at install time).
export CC="$LLVM_PREFIX/bin/clang"
export CXX="$LLVM_PREFIX/bin/clang++"
export CARGO_HOME=/root/.cargo
export RUSTUP_HOME="$RUST_HOME"
export RUSTUP_TOOLCHAIN="$RUST_TOOLCHAIN"
export OHOS_SDK_ROOT="$SDK_PREFIX"
export OHOS_SYSROOT="$SDK_PREFIX/native/sysroot"
export OHOS_LLVM_PREFIX="$LLVM_PREFIX"      # bun.rb 235
export BUN_INSTALL_IGNORE_SCRIPTS=1
export TMPDIR="/data/storage/el2/base/tmp"  # bun.rb 247 (EL2 tmp, musl tmpfile path)
unset RUSTC_WRAPPER || true                 # bun.rb 230 (clear sccache etc.)
ca_bundle="$BREW_PREFIX/etc/ca-certificates/cert.pem"
[ -f "$ca_bundle" ] && export SSL_CERT_FILE="$ca_bundle" CURL_CA_BUNDLE="$ca_bundle" || true

# ── Git SHA for build_options.rs ──────────────────────────────────────
# config.ts getGitRevision() reads GITHUB_SHA first, then `git rev-parse HEAD`,
# then falls back to the literal "unknown". The container has no git
# (Harmonybrew musl), so rev-parse throws and getGitRevision returns "unknown"
# (7 chars). That lands in build_options::SHA; env.rs:58 then does
# const_str_slice(SHA, 0, 9) → split_at(9) → const-eval panic "mid > len"
# (E0080) during `cargo build`. The workflow passes GITHUB_SHA via docker exec
# -e; mirror it into GIT_SHA (the third env var getGitRevision checks) so the
# bun configure subprocess definitely sees a 40-char SHA regardless of how the
# runtime reshuffles env. If somehow empty, derive from the checkout dir.
if [ -z "${GITHUB_SHA:-}" ]; then
  GITHUB_SHA=$(git -C "$SRC" rev-parse HEAD 2>/dev/null || true)
fi
if [ -n "$GITHUB_SHA" ]; then
  export GITHUB_SHA GIT_SHA="$GITHUB_SHA"
  echo "=== build SHA: $GITHUB_SHA ==="
else
  echo "::warning::no GITHUB_SHA and git rev-parse failed; build_options::SHA will be 'unknown' (env.rs const_str_slice panic risk)"
fi

echo "=== toolchain ==="
rustc --version
cargo --version
clang --version | head -1
"$BUN_BOOT_DIR/bun" --version

# ── esbuild OHOS platform fix ──────────────────────────────────────────
# esbuild's npm shim (node_modules/.bin/esbuild, shebang #!/usr/bin/env
# node) locates its native binary via process.platform. OHOS node reports
# "openharmony", which esbuild's knownPlatformPackages map doesn't list →
# "Unsupported platform: openharmony arm64 LE". (Self-hosted dodges this
# only because its build dir persists across runs, so ninja skips already-
# generated esbuild outputs; our ephemeral container re-runs every rule.)
#
# ESBUILD_BINARY_PATH bypasses ALL platform detection — esbuild's
# generateBinPath checks it first and returns it directly (esbuild@0.21.5
# bin/esbuild:116, confirmed via source). Point it at the @esbuild/linux-arm64
# native binary: a statically-linked Go binary that runs on musl (CGO_ENABLED=0).
#
# @esbuild/linux-arm64 is an optionalDependency filtered by {os:linux}.
# bun-bootstrap reports process.platform="openharmony" → bun skips it. So
# force-install it explicitly; if bun still refuses (os filtering on explicit
# installs), extract the tarball directly from the npm registry (the runner is
# GitHub-hosted, not behind the China network — registry.npmjs.org is direct).
ESBUILD_BIN="$SRC/node_modules/@esbuild/linux-arm64/bin/esbuild"
if [ ! -x "$ESBUILD_BIN" ]; then
  echo "=== @esbuild/linux-arm64 missing (bun skipped: openharmony≠linux), force-installing ==="
  "$BUN_BOOT_DIR/bun" add @esbuild/linux-arm64@0.21.5 --no-save 2>&1 | tail -3 || true
fi
if [ ! -x "$ESBUILD_BIN" ]; then
  echo "=== bun add refused (os filtering); extracting tarball directly ==="
  mkdir -p "$SRC/node_modules/@esbuild"
  curl -fsSL "https://registry.npmjs.org/@esbuild/linux-arm64/-/linux-arm64-0.21.5.tgz" -o /tmp/esbuild-arm64.tgz
  mkdir -p /tmp/esbuild-arm64-x
  tar xzf /tmp/esbuild-arm64.tgz -C /tmp/esbuild-arm64-x
  mv /tmp/esbuild-arm64-x/package "$SRC/node_modules/@esbuild/linux-arm64"
  rm -rf /tmp/esbuild-arm64.tgz /tmp/esbuild-arm64-x
fi
if [ ! -x "$ESBUILD_BIN" ]; then
  echo "ERROR: $ESBUILD_BIN not found after force-install; esbuild rules will fail"
  exit 1
fi
# Verify the native binary actually runs on this musl userspace (it must —
# esbuild execs it; a glibc-linked binary would fail here).
"$ESBUILD_BIN" --version || { echo "ERROR: esbuild native binary won't execute (not static?)"; exit 1; }
export ESBUILD_BINARY_PATH="$ESBUILD_BIN"
echo "=== ESBUILD_BINARY_PATH=$ESBUILD_BINARY_PATH ==="

# ── Self-compile __n1 libcxx from LLVM source ────────────────────────
# The OHOS device's libc++_shared.so uses _LIBCPP_ABI_NAMESPACE=__n1.
# llvm@21's prebuilt cross-libs use __1. With full symbol export (方案B),
# v8 symbols mangled as __1 would mismatch the device's __n1 → crash.
# Self-compile libcxx/libcxxabi/libunwind with -DLIBCXX_ABI_NAMESPACE=__n1
# so headers AND .a symbols are __n1 — matches the device.
#
# Strategy mirrors social4hyq llvm@21.rb build_multiarch_runtimes,
# with the single change __h → __n1. Cached: only first run pays ~10min.
CROSS="$SRC/build/ohos-cross-libs"
LLVM_SRC_TARBALL="llvm-project-21.1.8.src.tar.xz"
LLVM_SRC_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-21.1.8/${LLVM_SRC_TARBALL}"
LIBCXX_N1_STAMP="$CROSS/.N1_BUILT_OK"

if [ -f "$LIBCXX_N1_STAMP" ]; then
  echo "=== cross-libs cache hit (ABI __n1) ==="
else
  echo "=== self-compiling __n1 libcxx from LLVM 21.1.8 source ==="
  rm -rf "$CROSS"
  mkdir -p "$CROSS"

  # Download LLVM source (host runner has better network than container)
  if [ ! -f "/tmp/${LLVM_SRC_TARBALL}" ]; then
    echo "=== downloading ${LLVM_SRC_TARBALL} ==="
    curl -fsSL "$LLVM_SRC_URL" -o "/tmp/${LLVM_SRC_TARBALL}" || {
      echo "ERROR: failed to download LLVM source"
      exit 1
    }
  fi
  echo "=== extracting LLVM source ==="
  rm -rf /tmp/llvm-project-src
  mkdir -p /tmp/llvm-project-src
  tar xf "/tmp/${LLVM_SRC_TARBALL}" -C /tmp/llvm-project-src --strip-components=1

  LLVM_SRC=/tmp/llvm-project-src
  BUILD_DIR=/tmp/libcxx-n1-build

  # Patch: musl doesn't provide strtoll_l/strtoull_l (glibc extensions).
  # Replace with non-locale versions (locale arg ignored).
  LINUX_H="$LLVM_SRC/libcxx/include/__locale_dir/support/linux.h"
  if [ -f "$LINUX_H" ]; then
    sed -i 's/strtoll_l(\([^,]*\),\([^,]*\),\([^,]*\),[^)]*)/strtoll(\1,\2,\3)/g; s/strtoull_l(\([^,]*\),\([^,]*\),\([^,]*\),[^)]*)/strtoull(\1,\2,\3)/g' "$LINUX_H"
    echo "=== patched linux.h: strtoll_l/strtoull_l → strtoll/strtoull (dropped locale arg) ==="
  fi

  # Temporarily hide llvm@21 cmake config: the brew bottle ships
  # LLVMExports.cmake that references missing static libs (e.g.
  # libLLVMDemangle.a). find_package(LLVM) loads it and fails.
  # The runtimes build is standalone and doesn't need it.
  LLVM_CMAKE_DIR="$LLVM_PREFIX/lib/cmake"
  if [ -d "$LLVM_CMAKE_DIR" ]; then
    mv "$LLVM_CMAKE_DIR" "${LLVM_CMAKE_DIR}.bak"
    echo "=== temporarily hiding llvm@21 cmake config ==="
  fi

  # Stage 1: libunwind standalone
  echo "=== Stage 1: libunwind ==="
  cmake -G Ninja -S "$LLVM_SRC/runtimes" -B "$BUILD_DIR/libunwind" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="--target=aarch64-linux-ohos --sysroot=$OHOS_SYSROOT -D__MUSL__ -D__OHOS__ -nostdinc++ -I$LLVM_PREFIX/include/aarch64-linux-ohos/c++/v1" \
    -DCMAKE_CXX_FLAGS="--target=aarch64-linux-ohos --sysroot=$OHOS_SYSROOT -D__MUSL__ -D__OHOS__ -nostdinc++ -I$LLVM_PREFIX/include/aarch64-linux-ohos/c++/v1" \
    -DLLVM_ENABLE_RUNTIMES="libunwind" \
    -DLIBUNWIND_USE_COMPILER_RT=ON \
    -DCMAKE_INSTALL_PREFIX="$CROSS/libunwind" \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
  ninja -C "$BUILD_DIR/libunwind" install -j"$NINJA_JOBS"

  # Stage 2: libcxx + libcxxabi + libunwind with __n1 ABI
  echo "=== Stage 2: libcxx + libcxxabi with -DLIBCXX_ABI_NAMESPACE=__n1 ==="
  cmake -G Ninja -S "$LLVM_SRC/runtimes" -B "$BUILD_DIR/libcxx" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="--target=aarch64-linux-ohos --sysroot=$OHOS_SYSROOT -D__MUSL__ -D__OHOS__ -D_LIBCPP_PROVIDES_DEFAULT_RUNE_TABLE -D_LIBCPP_HAS_NO_LOCALIZATION -nostdinc++ -I$CROSS/libunwind/include/c++/v1" \
    -DCMAKE_CXX_FLAGS="--target=aarch64-linux-ohos --sysroot=$OHOS_SYSROOT -D__MUSL__ -D__OHOS__ -D_LIBCPP_PROVIDES_DEFAULT_RUNE_TABLE -D_LIBCPP_HAS_NO_LOCALIZATION -nostdinc++ -I$CROSS/libunwind/include/c++/v1" \
    -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
    -DLIBCXX_ABI_NAMESPACE=__n1 \
    -DLIBCXX_ENABLE_SHARED=OFF \
    -DLIBCXXABI_ENABLE_SHARED=OFF \
    -DLIBUNWIND_ENABLE_SHARED=OFF \
    -DLIBCXX_USE_COMPILER_RT=ON \
    -DLIBCXXABI_USE_COMPILER_RT=ON \
    -DLIBUNWIND_USE_COMPILER_RT=ON \
    -DLIBCXX_LIBDIR_SUFFIX="" \
    -DCMAKE_INSTALL_PREFIX="$CROSS" \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
  ninja -C "$BUILD_DIR/libcxx" install -j"$NINJA_JOBS"

  # Restore llvm@21 cmake config
  if [ -d "${LLVM_CMAKE_DIR}.bak" ]; then
    mv "${LLVM_CMAKE_DIR}.bak" "$LLVM_CMAKE_DIR"
    echo "=== restored llvm@21 cmake config ==="
  fi

  # Symlink into the layout flags.ts expects.
  # cmake installs headers to $CROSS/include/c++/v1/ and libs to $CROSS/lib/.
  # flags.ts reads $CROSS/libcxx/include/v1/ and $CROSS/libcxx/lib/libc++.a.
  mkdir -p "$CROSS/libcxx/include" "$CROSS/libcxxabi/include" \
           "$CROSS/libcxx/lib" "$CROSS/libcxxabi/lib" "$CROSS/libunwind/lib"
  ln -sfn "$CROSS/include/c++/v1" "$CROSS/libcxx/include/v1"
  ln -sfn "$CROSS/include/c++/v1" "$CROSS/libcxxabi/include/v1"
  ln -sfn "$CROSS/lib/libc++.a"      "$CROSS/libcxx/lib/libc++.a"
  ln -sfn "$CROSS/lib/libc++abi.a"   "$CROSS/libcxxabi/lib/libc++abi.a"
  ln -sfn "$CROSS/lib/libunwind.a"   "$CROSS/libunwind/lib/libunwind.a"

  echo "=== verifying headers exist ==="
  ls "$CROSS/libcxx/include/v1/cstddef" "$CROSS/libcxx/include/v1/__config_site" 2>/dev/null || {
    echo "ERROR: libcxx headers not at $CROSS/libcxx/include/v1/"
    echo "  $CROSS/include/ contents:"; ls "$CROSS/include/" 2>/dev/null | head -10
    echo "  $CROSS/include/c++/ contents:"; ls "$CROSS/include/c++/" 2>/dev/null | head -10
    exit 1
  }
  grep '_LIBCPP_ABI_NAMESPACE' "$CROSS/libcxx/include/v1/__config_site"

  # Patch __config_site: add musl compatibility defines so all downstream
  # consumers (WebKit, bun C++, etc.) get them automatically via the header.
  CONFIG_SITE="$CROSS/libcxx/include/v1/__config_site"
  if ! grep -q '_LIBCPP_PROVIDES_DEFAULT_RUNE_TABLE' "$CONFIG_SITE"; then
    echo '#define _LIBCPP_PROVIDES_DEFAULT_RUNE_TABLE' >> "$CONFIG_SITE"
    echo '#define _LIBCPP_HAS_NO_LOCALIZATION' >> "$CONFIG_SITE"
    echo "=== patched __config_site: added musl compat defines ==="
  fi

  # Self-check: verify __n1 symbols present, __h absent
  echo "=== verifying __n1 ABI ==="
  NM="$LLVM_PREFIX/bin/llvm-nm"
  for lib in libc++.a libc++abi.a; do
    n1=$("$NM" "$CROSS/lib/$lib" 2>/dev/null | grep -c '__n1' || true)
    h_sym=$("$NM" "$CROSS/lib/$lib" 2>/dev/null | grep -c '__h' || true)
    echo "  $lib: __n1=$n1 __h=$h_sym"
    [ "$n1" -gt 0 ] || { echo "ERROR: $lib has no __n1 symbols"; exit 1; }
  done

  touch "$LIBCXX_N1_STAMP"
  echo "=== cross-libs OK (ABI __n1, self-compiled from LLVM 21.1.8) ==="

  # Cleanup build artifacts to save cache space
  rm -rf "$BUILD_DIR" /tmp/llvm-project-src "/tmp/${LLVM_SRC_TARBALL}"
fi

# ── Scaffold ohos-icu (bun.rb lines 119-135) ───────────────────────────
# config.ts:1013 defaults ohosIcuDir=<cwd>/build/ohos-icu/target;
# webkit.ts:472 resolves hostBin=<ohosIcuDir>/../host/bin for ICU data tools
# (genrb/genccode/gencmn/pkgdata) — WebKit CMake needs these under
# --webkit=local (from-source WebKit, not the bun-webkit bottle).
ICU_TARGET=build/ohos-icu/target
ICU_HOST=build/ohos-icu/host
mkdir -p "$ICU_TARGET/include" "$ICU_TARGET/lib" "$ICU_HOST/bin"
ln -sf "$ICU_PREFIX/include/unicode" "$ICU_TARGET/include/unicode"
for a in libicudata.a libicui18n.a libicuuc.a; do
  ln -sf "$ICU_PREFIX/lib/$a" "$ICU_TARGET/lib/$a"
done
for t in genrb genccode gencmn pkgdata; do
  [ -x "$ICU_PREFIX/bin/$t" ] && ln -sf "$ICU_PREFIX/bin/$t" "$ICU_HOST/bin/$t" || true
done
echo "=== ohos-icu OK (from icu4c@78) ==="

# ── Configure (webkit=local, --configure-only) ────────────────────────
echo "=== configure (webkit=local, --configure-only) ==="
"$BUN_BOOT_DIR/bun" scripts/build.ts \
  --profile=release \
  --os=ohos \
  --arch=aarch64 \
  --webkit=local \
  --build-dir=build/release-ohos \
  --ohos-sdk-root="$OHOS_SDK_ROOT" \
  --ohos-sysroot="$OHOS_SYSROOT" \
  --configure-only 2>&1 | tee /tmp/build.log

# ── Generate WebKit build.ninja ───────────────────────────────────────
echo "=== configure-WebKit ==="
ninja -C build/release-ohos configure-WebKit -j1 2>&1 | tee -a /tmp/build.log

# WebKit CMake FindThreads bug: -lpthreads → -lpthread. Universal (not
# llvm-22-specific); the from-source WebKit build under --webkit=local hits it.
if [ -f build/release-ohos/deps/WebKit/build.ninja ]; then
  sed -i 's/-lpthreads/-lpthread/g' build/release-ohos/deps/WebKit/build.ninja
fi

# ── Build ─────────────────────────────────────────────────────────────
echo "=== build (ninja bun, -j${NINJA_JOBS}) ==="
set +e
ninja -C build/release-ohos bun -j"${NINJA_JOBS}" 2>&1 | tee -a /tmp/build.log
rc=${PIPESTATUS[0]}
set -e
if [ "$rc" -ne 0 ]; then
  echo "=== build failed (rc=$rc) ==="
  grep -inE 'error\[|error:|fatal error|undefined reference|ld: error|FAILED:' /tmp/build.log | head -50 || true
  tail -80 /tmp/build.log || true
  exit 1
fi

echo "=== build OK ==="
OUT=build/release-ohos/bun
[ -f "$OUT" ] || OUT=build/release-ohos/bun-profile
ls -lh "$OUT"
