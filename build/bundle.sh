#!/usr/bin/env bash
# Build a single self-contained lemoncheck script by inlining lib/*.sh into
# bin/lemoncheck (replacing the module-sourcing block). Output: dist/lemoncheck.
set -euo pipefail

ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="dist/lemoncheck"
mkdir -p dist

LIBS="util tier1_dealbreakers tier2_wear tier3_components tier4_extras report"

awk -v libs="$LIBS" '
  /BUNDLE:STRIP_START/ {
    n = split(libs, a, " ")
    print "# ---- libraries inlined by build/bundle.sh (single-file build) ----"
    for (i = 1; i <= n; i++) {
      f = "lib/" a[i] ".sh"
      print ""
      print "# ===== " f " ====="
      while ((getline line < f) > 0) {
        if (line !~ /^#!/) print line   # drop each lib shebang
      }
      close(f)
    }
    skip = 1
    next
  }
  /BUNDLE:STRIP_END/ { skip = 0; next }
  !skip { print }
' bin/lemoncheck > "$OUT"

chmod +x "$OUT"

# Sanity: it must parse and report a version.
bash -n "$OUT"
ver="$(bash "$OUT" --version 2>/dev/null)"
echo "Built $OUT  ($(wc -l < "$OUT" | tr -d ' ') lines)  →  $ver"
