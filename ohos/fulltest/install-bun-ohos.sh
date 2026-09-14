#!/bin/sh
# Bun for HarmonyOS (OHOS) — Quick Install Script
#
# Usage:
#   # Default: self-hosted build (Harmonybrew cross-libs, musl Rust host)
#   curl -fsSL https://ghfast.top/https://github.com/ljy9812/bun/releases/download/ohos-latest/install-bun-ohos.sh | sh
#
#   # github-hosted build (self-built __n1 libcxx+compiler-rt+ICU, glibc Rust host)
#   curl -fsSL https://ghfast.top/https://github.com/ljy9812/bun/releases/download/ohos-latest/install-bun-ohos.sh | sh -s -- github
#
# Or without proxy:
#   curl -fsSL https://github.com/ljy9812/bun/releases/download/ohos-latest/install-bun-ohos.sh | sh -s -- github
#
# Args:  self (default) | github
#   self   → downloads bun-ohos-aarch64       → installs ~/usr/bin/bun
#   github → downloads bun-ohos-aarch64-github → installs ~/usr/bin/bun-github
# Both can coexist for A/B comparison.
#
set -eu

# --- Parse args ---
BUILD="self"   # default: self-hosted build
for arg in "$@"; do
  case "$arg" in
    github|--github) BUILD="github" ;;
    self|--self)     BUILD="self" ;;
    --build=*)       BUILD="${arg#--build=}" ;;
    -h|--help)
      echo "Usage: sh install-bun-ohos.sh [self|github]"
      echo "  self   (default) self-hosted build → bun-ohos-aarch64 → ~/usr/bin/bun"
      echo "  github           github-hosted build → bun-ohos-aarch64-github → ~/usr/bin/bun-github"
      exit 0 ;;
    *) echo "Unknown arg: $arg (use self|github)" >&2; exit 1 ;;
  esac
done

REPO="ljy9812/bun"
RELEASE_TAG="ohos-latest"
INSTALL_DIR="$HOME/usr/bin"
PROXY="${BUN_INSTALL_PROXY:-https://ghfast.top/}"

# BUILD selects both the release asset name and the installed binary name so
# the two builds coexist in ~/usr/bin (bun vs bun-github) for A/B testing.
case "$BUILD" in
  self)
    BINARY_NAME="bun-ohos-aarch64"
    INSTALL_BIN="$INSTALL_DIR/bun"
    ;;
  github)
    BINARY_NAME="bun-ohos-aarch64-github"
    INSTALL_BIN="$INSTALL_DIR/bun-github"
    ;;
  *)
    echo "Unknown build: $BUILD (use self|github)" >&2; exit 1 ;;
esac

# Colors (if terminal supports them)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; exit 1; }

# --- Pre-flight checks ---

info "Bun OHOS Installer"
info "==================="

# Check architecture
ARCH=$(uname -m)
case "$ARCH" in
  aarch64|arm64)
    ok "Architecture: $ARCH"
    ;;
  *)
    error "Unsupported architecture: $ARCH (requires aarch64/arm64)"
    ;;
esac

# Check OS
OS=$(uname -s)
case "$OS" in
  Linux|HarmonyOS)
    ok "Operating System: $OS"
    ;;
  *)
    error "Unsupported OS: $OS (requires Linux or HarmonyOS)"
    ;;
esac

# Check curl or wget
if command -v curl >/dev/null 2>&1; then
  DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
  DOWNLOADER="wget"
else
  error "Neither curl nor wget found. Install one of them first."
fi
ok "Downloader: $DOWNLOADER"

# --- Download ---

DOWNLOAD_URL="${PROXY}https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${BINARY_NAME}"

# Create install directory first, download directly to target
mkdir -p "$INSTALL_DIR"
rm -f "$INSTALL_BIN"

info "Downloading bun from:"
info "  $DOWNLOAD_URL"

if [ "$DOWNLOADER" = "curl" ]; then
  curl -fsSL -o "$INSTALL_BIN" "$DOWNLOAD_URL" 2>/dev/null || {
    warn "Proxy download failed, trying direct..."
    curl -fsSL -o "$INSTALL_BIN" \
      "https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${BINARY_NAME}" 2>/dev/null || \
      error "Download failed. Check your network."
  }
else
  wget -q -O "$INSTALL_BIN" "$DOWNLOAD_URL" 2>/dev/null || {
    warn "Proxy download failed, trying direct..."
    wget -q -O "$INSTALL_BIN" \
      "https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${BINARY_NAME}" 2>/dev/null || \
      error "Download failed. Check your network."
  }
fi

# Verify download
if [ ! -s "$INSTALL_BIN" ]; then
  rm -f "$INSTALL_BIN"
  error "Downloaded file is empty"
fi

FILE_SIZE=$(wc -c < "$INSTALL_BIN" | tr -d ' ')
if [ "$FILE_SIZE" -lt 1000000 ]; then
  rm -f "$INSTALL_BIN"
  error "Downloaded file too small (${FILE_SIZE} bytes), likely corrupted"
fi

ok "Downloaded $((FILE_SIZE / 1048576)) MB"

# --- Install ---

chmod +x "$INSTALL_BIN"
ok "Installed to $INSTALL_BIN"

# --- PATH setup (永久写入) ---

# Resolve to absolute path (e.g. /storage/Users/currentUser/usr/bin)
BIN_DIR="$INSTALL_DIR"
BIN_DIR_ABS=$(cd "$BIN_DIR" 2>/dev/null && pwd || echo "$BIN_DIR")

# Try all common profile files to ensure PATH persists
PROFILE_FILES="$HOME/.bashrc $HOME/.bash_profile $HOME/.profile $HOME/.zshrc $HOME/.mkshrc"
PATH_LINE="export PATH=\"$BIN_DIR_ABS:\$PATH\""

WRITTEN=0
for f in $PROFILE_FILES; do
  if [ -f "$f" ]; then
    if ! grep -qF "$BIN_DIR_ABS" "$f" 2>/dev/null; then
      echo "" >> "$f"
      echo "# Bun OHOS" >> "$f"
      echo "$PATH_LINE" >> "$f"
      ok "Added PATH to $f"
    fi
    WRITTEN=1
  fi
done

# If no profile files exist, create .profile
if [ "$WRITTEN" = "0" ]; then
  echo "$PATH_LINE" > "$HOME/.profile"
  ok "Created $HOME/.profile with PATH"
fi

# Export PATH for current session
export PATH="$BIN_DIR_ABS:$PATH"

# --- Verify & Sign ---

info "Verifying installation..."
if [ -x "$INSTALL_BIN" ]; then
  # Try to auto-sign if binary-sign-tool is available (OHOS device only)
  SIGN_TOOL=""
  for p in \
    "/system/bin/binary-sign-tool" \
    "/usr/bin/binary-sign-tool" \
    "$(command -v binary-sign-tool 2>/dev/null)"; do
    if [ -n "$p" ] && [ -x "$p" ]; then SIGN_TOOL="$p"; break; fi
  done

  if [ -n "$SIGN_TOOL" ]; then
    info "Signing binary with $SIGN_TOOL..."
    SIGNED="${INSTALL_BIN}.signed"
    rm -f "$SIGNED"
    "$SIGN_TOOL" sign -inFile "$INSTALL_BIN" -outFile "$SIGNED" -selfSign 1 2>/dev/null && {
      mv -f "$SIGNED" "$INSTALL_BIN"
      chmod +x "$INSTALL_BIN"
      ok "Binary signed successfully"
    } || {
      rm -f "$SIGNED"
      warn "Auto-signing failed, you may need to sign manually:"
      warn "  binary-sign-tool sign -inFile \"$INSTALL_BIN\" -outFile \"$INSTALL_BIN\" -selfSign 1"
    }
  else
    warn "binary-sign-tool not found (not on OHOS device?)"
    warn "To run bun on OHOS, sign it first:"
    warn "  binary-sign-tool sign -inFile \"$INSTALL_BIN\" -outFile \"$INSTALL_BIN\" -selfSign 1"
  fi

  VERSION=$("$INSTALL_BIN" --version 2>/dev/null || echo "unknown (may need signing)")
  ok "bun $VERSION installed successfully! ($BUILD build → $(basename "$INSTALL_BIN"))"
else
  error "Installation failed: binary not found at $INSTALL_BIN"
fi

echo ""
echo "  Installed: $INSTALL_BIN  ($BUILD build)"
echo "  PATH permanently added to: $BIN_DIR_ABS"
echo ""
echo "  Run: $(basename "$INSTALL_BIN") --version"
echo ""
