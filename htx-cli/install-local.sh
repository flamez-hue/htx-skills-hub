#!/bin/sh
set -e

# ──────────────────────────────────────────────────────────────
# htx-cli LOCAL installer (macOS / Linux)
#
# Installs htx-cli from a local dist/ directory produced by
# ./build.sh. No network, no GitHub API calls.
#
# Usage:
#   ./install-local.sh                    # install from ./dist
#   ./install-local.sh ./dist             # explicit dist path
#   ./install-local.sh --prefix ~/bin     # custom install dir
#   ./install-local.sh --uninstall        # remove installed binary
#   ./install-local.sh --force            # overwrite without checksum fail-stop
#
# Environment overrides:
#   HTX_INSTALL_DIR   install directory (default: $HOME/.local/bin)
#   HTX_LOCAL_DIST    dist directory    (default: ./dist, then script_dir/dist)
#
# Supported platforms:
#   macOS  : x86_64 (Intel), arm64 (Apple Silicon)
#   Linux  : x86_64, i686, aarch64, armv7l
#   Windows: use install-local.ps1
# ──────────────────────────────────────────────────────────────

BINARY="htx-cli"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
INSTALL_DIR="${HTX_INSTALL_DIR:-$HOME/.local/bin}"
DIST_DIR=""
UNINSTALL=false
FORCE=false

# ── Parse arguments ──────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall|-u)
      UNINSTALL=true
      shift
      ;;
    --prefix|-p)
      [ $# -lt 2 ] && { echo "Error: --prefix requires a path" >&2; exit 1; }
      INSTALL_DIR="$2"
      shift 2
      ;;
    --force|-f)
      FORCE=true
      shift
      ;;
    -h|--help)
      sed -n '3,22p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "Error: unknown option: $1" >&2
      exit 1
      ;;
    *)
      DIST_DIR="$1"
      shift
      ;;
  esac
done

# ── Resolve DIST_DIR ─────────────────────────────────────────
if [ -z "$DIST_DIR" ] && [ -n "$HTX_LOCAL_DIST" ]; then
  DIST_DIR="$HTX_LOCAL_DIST"
fi
if [ -z "$DIST_DIR" ]; then
  if [ -d "./dist" ]; then
    DIST_DIR="./dist"
  elif [ -d "$SCRIPT_DIR/dist" ]; then
    DIST_DIR="$SCRIPT_DIR/dist"
  fi
fi

# ── Platform detection ───────────────────────────────────────
detect_target() {
  os=$(uname -s)
  arch=$(uname -m)
  case "$os" in
    Darwin)
      case "$arch" in
        x86_64) echo "x86_64-apple-darwin" ;;
        arm64)  echo "aarch64-apple-darwin" ;;
        *) echo "Error: unsupported macOS architecture: $arch" >&2; exit 1 ;;
      esac
      ;;
    Linux)
      case "$arch" in
        x86_64)  echo "x86_64-unknown-linux-gnu" ;;
        i686)    echo "i686-unknown-linux-gnu" ;;
        aarch64) echo "aarch64-unknown-linux-gnu" ;;
        armv7l)  echo "armv7-unknown-linux-gnueabihf" ;;
        *) echo "Error: unsupported Linux architecture: $arch" >&2; exit 1 ;;
      esac
      ;;
    *)
      echo "Error: unsupported OS: $os (use install-local.ps1 on Windows)" >&2
      exit 1
      ;;
  esac
}

# ── sha256 helper ────────────────────────────────────────────
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo ""
  fi
}

# ── Uninstall path ───────────────────────────────────────────
if [ "$UNINSTALL" = true ]; then
  target_path="$INSTALL_DIR/$BINARY"
  if [ -e "$target_path" ]; then
    rm -f "$target_path"
    echo "Removed $target_path"
  else
    echo "Not installed at $target_path, nothing to do."
  fi
  exit 0
fi

# ── Pre-flight checks ────────────────────────────────────────
if [ -z "$DIST_DIR" ] || [ ! -d "$DIST_DIR" ]; then
  echo "Error: dist directory not found." >&2
  echo "  Tried: \$1, \$HTX_LOCAL_DIST, ./dist, $SCRIPT_DIR/dist" >&2
  echo "  Run ./build.sh first, or pass a path: ./install-local.sh /path/to/dist" >&2
  exit 1
fi
DIST_DIR=$(cd "$DIST_DIR" && pwd)

TARGET=$(detect_target)
BIN_FILE="$DIST_DIR/${BINARY}-${TARGET}"

if [ ! -f "$BIN_FILE" ]; then
  echo "Error: binary not found for this platform." >&2
  echo "  Expected: $BIN_FILE" >&2
  echo "  Available in $DIST_DIR:" >&2
  ls "$DIST_DIR" | grep "^${BINARY}-" | grep -v '\.tar\.gz$\|\.zip$' | sed 's/^/    /' >&2
  exit 1
fi

echo "htx-cli local installer"
echo "  target : $TARGET"
echo "  source : $BIN_FILE"
echo "  dest   : $INSTALL_DIR/$BINARY"
echo ""

# ── Checksum verification ────────────────────────────────────
if [ -f "$DIST_DIR/checksums.txt" ]; then
  expected=$(grep " ${BINARY}-${TARGET}\$" "$DIST_DIR/checksums.txt" | awk '{print $1}')
  if [ -n "$expected" ]; then
    actual=$(sha256_of "$BIN_FILE")
    if [ -z "$actual" ]; then
      echo "Warning: sha256sum/shasum not available, skipping checksum verification."
    elif [ "$actual" = "$expected" ]; then
      echo "Checksum verified (sha256: ${expected%????????????????????????????????????????????????????????}…)"
    else
      echo "Error: checksum mismatch!" >&2
      echo "  Expected: $expected" >&2
      echo "  Got:      $actual" >&2
      if [ "$FORCE" = true ]; then
        echo "  (--force given, continuing anyway)"
      else
        echo "  Re-run with --force to install anyway, or rebuild with ./build.sh." >&2
        exit 1
      fi
    fi
  else
    echo "Warning: no checksum entry for ${BINARY}-${TARGET} in checksums.txt"
  fi
else
  echo "Warning: $DIST_DIR/checksums.txt not found, skipping checksum verification."
fi

# ── Install ──────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"

# Atomic install via tmp file in the same dir (handles busy binary, noexec /tmp, etc.)
tmp="$INSTALL_DIR/.${BINARY}.$$.tmp"
trap 'rm -f "$tmp"' EXIT INT TERM
cp "$BIN_FILE" "$tmp"
chmod +x "$tmp"
mv -f "$tmp" "$INSTALL_DIR/$BINARY"
trap - EXIT INT TERM

echo "Installed $BINARY → $INSTALL_DIR/$BINARY"

# ── PATH setup ───────────────────────────────────────────────
ensure_in_path() {
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) return 0 ;;
  esac

  # Only auto-edit profile for the default install dir. For custom --prefix,
  # just print a hint — don't assume the user wants us to touch their rc.
  default_dir="$HOME/.local/bin"
  if [ "$INSTALL_DIR" != "$default_dir" ]; then
    echo ""
    echo "Note: $INSTALL_DIR is not in your PATH."
    echo "Add this line to your shell profile to use '$BINARY' directly:"
    echo ""
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    return 0
  fi

  export_line='export PATH="$HOME/.local/bin:$PATH"'
  shell_name=$(basename "${SHELL:-sh}")
  case "$shell_name" in
    zsh)  profile="$HOME/.zshrc" ;;
    bash)
      if   [ -f "$HOME/.bash_profile" ]; then profile="$HOME/.bash_profile"
      elif [ -f "$HOME/.bashrc" ];       then profile="$HOME/.bashrc"
      else profile="$HOME/.profile"; fi
      ;;
    fish)
      # fish uses its own syntax; just print an instruction.
      echo ""
      echo "Detected fish. Add this to ~/.config/fish/config.fish:"
      echo "  set -gx PATH \$HOME/.local/bin \$PATH"
      return 0
      ;;
    *)    profile="$HOME/.profile" ;;
  esac

  if [ -f "$profile" ] && grep -qF '$HOME/.local/bin' "$profile" 2>/dev/null; then
    return 0
  fi

  {
    echo ""
    echo "# Added by htx-cli installer"
    echo "$export_line"
  } >> "$profile"

  echo ""
  echo "Added $INSTALL_DIR to PATH in $profile"
  echo "Run the following, or open a new terminal:"
  echo ""
  echo "  source $profile"
}

ensure_in_path

# ── Post-install verification ────────────────────────────────
echo ""
echo "Verifying install..."
if "$INSTALL_DIR/$BINARY" --help >/dev/null 2>&1; then
  echo "OK: $("$INSTALL_DIR/$BINARY" --help 2>&1 | head -1)"
else
  echo "Warning: '$INSTALL_DIR/$BINARY --help' did not exit cleanly."
  exit 1
fi

echo ""
echo "Done."
