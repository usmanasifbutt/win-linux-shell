#!/usr/bin/env bash
# win-linux-shell -- single entry point.
#
# Turns a boring Windows PowerShell into a productive Linux-like shell:
#   * GNU coreutils on PATH  (rm -rf, cp -r, grep, sed, awk, nano, curl ...)
#   * oh-my-posh prompt       (builtin minimal theme: "slim")
#   * PSReadLine              (emacs keys, history search, autosuggest)
#   * Windows Terminal        (default profile -> PowerShell 7)
#
# Run from Git Bash on Windows:
#   bash setup.sh [options]
#
# Options:
#   --theme <name|path>   oh-my-posh theme (default: slim)
#   --no-update           don't install/upgrade PowerShell 7 via winget
#   --no-terminal         don't touch Windows Terminal settings.json
#   --no-omp              don't install oh-my-posh
#   -h, --help            show this help
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME="slim"
PS_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --theme)       THEME="${2:?--theme needs a value}"; shift 2 ;;
    --theme=*)     THEME="${1#*=}"; shift ;;
    --no-update)   PS_ARGS+=("-SkipPowerShellUpdate"); shift ;;
    --no-terminal) PS_ARGS+=("-SkipTerminal"); shift ;;
    --no-omp)      PS_ARGS+=("-SkipOhMyPosh"); shift ;;
    -h|--help)     sed -n '2,18p' "$0" | sed 's/^#\{0,1\} \{0,1\}//'; exit 0 ;;
    *) echo "win-linux-shell: unknown option '$1' (try --help)" >&2; exit 2 ;;
  esac
done

# Locate a PowerShell interpreter -- prefer pwsh 7, fall back to Windows PS 5.1.
PWSH=""
for c in pwsh pwsh.exe powershell.exe; do
  if command -v "$c" >/dev/null 2>&1; then PWSH="$c"; break; fi
done
if [ -z "$PWSH" ]; then
  echo "win-linux-shell: no PowerShell found on PATH." >&2
  echo "  Install it with:  winget install Microsoft.PowerShell" >&2
  exit 1
fi

# Hand Windows-native paths to a Windows-native interpreter.
INSTALL="$HERE/powershell/install.ps1"
if command -v cygpath >/dev/null 2>&1; then
  INSTALL="$(cygpath -w "$INSTALL")"
fi

echo "==> win-linux-shell: $PWSH  |  theme: $THEME"
exec "$PWSH" -NoProfile -ExecutionPolicy Bypass -File "$INSTALL" \
  -Theme "$THEME" ${PS_ARGS[@]+"${PS_ARGS[@]}"}
