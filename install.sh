#!/usr/bin/env bash
# lemoncheck — local installer (symlinks bin/lemoncheck onto your PATH)
set -euo pipefail

SRC_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/usr/local}"
BINLINK="$PREFIX/bin/lemoncheck"

echo "Installing lemoncheck from $SRC_DIR"

if [[ ! -w "$PREFIX/bin" ]]; then
  echo "→ $PREFIX/bin needs sudo; you may be prompted."
  sudo mkdir -p "$PREFIX/bin"
  sudo ln -sf "$SRC_DIR/bin/lemoncheck" "$BINLINK"
else
  mkdir -p "$PREFIX/bin"
  ln -sf "$SRC_DIR/bin/lemoncheck" "$BINLINK"
fi

chmod +x "$SRC_DIR/bin/lemoncheck"

echo "✔ Installed: $BINLINK -> $SRC_DIR/bin/lemoncheck"
echo
echo "Try it:  lemoncheck --help"
if ! command -v smartctl >/dev/null 2>&1; then
  echo "Tip: 'brew install smartmontools' enables the full SSD SMART / TBW read."
fi
