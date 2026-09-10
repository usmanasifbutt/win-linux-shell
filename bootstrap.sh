#!/usr/bin/env bash
# win-linux-shell -- no-clone bootstrap.
#
# Fetches win-linux-shell into a stable location and hands off to setup.sh.
# Designed to be piped straight from GitHub:
#
#   curl -fsSL https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/usmanasifbutt/win-linux-shell/main/bootstrap.sh | bash -s -- --theme atomic --no-terminal
#
# Environment overrides:
#   WLS_DIR   where to install   (default: ~/.win-linux-shell)
#   WLS_REF   branch or tag      (default: main)
set -euo pipefail

REPO="usmanasifbutt/win-linux-shell"
WLS_DIR="${WLS_DIR:-$HOME/.win-linux-shell}"
WLS_REF="${WLS_REF:-main}"

# Never operate on a home/root/empty path.
case "${WLS_DIR%/}" in
  "" | "$HOME" | "$(cd / && pwd)" ) echo "bootstrap: refusing unsafe WLS_DIR='$WLS_DIR'" >&2; exit 1 ;;
esac

echo "==> win-linux-shell bootstrap -> $WLS_DIR  (ref: $WLS_REF)"

if command -v git >/dev/null 2>&1; then
  if [ -d "$WLS_DIR/.git" ]; then
    git -C "$WLS_DIR" fetch --depth 1 origin "$WLS_REF"
    git -C "$WLS_DIR" checkout -q -B "$WLS_REF" FETCH_HEAD
    echo "    updated existing checkout"
  elif [ -e "$WLS_DIR" ] && [ -n "$(ls -A "$WLS_DIR" 2>/dev/null || true)" ]; then
    echo "bootstrap: '$WLS_DIR' exists and is not a win-linux-shell checkout." >&2
    echo "           remove it, or set WLS_DIR to another path, then retry." >&2
    exit 1
  else
    git clone --depth 1 --branch "$WLS_REF" "https://github.com/$REPO.git" "$WLS_DIR"
  fi
else
  echo "    git not found -- downloading a tarball instead"
  mkdir -p "$WLS_DIR"
  tgz="$WLS_DIR/.src.tgz"
  if ! curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$WLS_REF" -o "$tgz" 2>/dev/null; then
    curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/tags/$WLS_REF" -o "$tgz"
  fi
  tar -xzf "$tgz" -C "$WLS_DIR" --strip-components=1
  rm -f "$tgz"
fi

exec bash "$WLS_DIR/setup.sh" "$@"
