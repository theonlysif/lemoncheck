#!/usr/bin/env bash
# Build LemonCheck.app (a double-clickable wrapper that runs the bundled
# lemoncheck script in Terminal) and package it as LemonCheck.dmg.
#
# The app is an AppleScript applet: it opens Terminal and runs the copy of
# lemoncheck embedded in its own Contents/Resources. No dependencies beyond
# what macOS ships. NOTE: the app is unsigned — see README for the first-run
# right-click ▸ Open step that gets past Gatekeeper.
set -euo pipefail

ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="dist/LemonCheck.app"
DMG="dist/LemonCheck.dmg"
VERSION="$(awk -F'"' '/^LEMONCHECK_VERSION=/{print $2; exit}' bin/lemoncheck)"

# 1. Make sure the single-file script is fresh.
./build/bundle.sh >/dev/null

# 2. Compile the AppleScript applet.
rm -rf "$APP" "$DMG"
osacompile -o "$APP" build/app_main.applescript

# 3. Embed the bundled script + a plain-text README into the app bundle.
mkdir -p "$APP/Contents/Resources"
cp dist/lemoncheck "$APP/Contents/Resources/lemoncheck"
chmod +x "$APP/Contents/Resources/lemoncheck"

# 4. Fill in Info.plist metadata (name, version, high-res, no dock clutter).
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName LemonCheck" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string studio.riffle.lemoncheck" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier studio.riffle.lemoncheck" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 11.0" "$PLIST" 2>/dev/null || true

# 5. Ad-hoc sign so it at least has a stable identity (still not notarized).
codesign --force --deep -s - "$APP" 2>/dev/null || echo "  (codesign skipped)"

# 6. Stage a drag-to-install layout and build the DMG.
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp docs/APP-README.txt "$STAGE/READ ME FIRST.txt" 2>/dev/null || true
hdiutil create -quiet -volname "LemonCheck $VERSION" -srcfolder "$STAGE" \
  -ov -format UDZO "$DMG"
rm -rf "$STAGE"

echo "Built:"
echo "  $APP"
echo "  $DMG  ($(du -h "$DMG" | awk '{print $1}'))"
