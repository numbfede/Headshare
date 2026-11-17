#!/bin/bash
# Packages build/Headshare.app into a drag-to-Applications DMG: build/Headshare-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")"

[ -d build/Headshare.app ] || ./build.sh
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' build/Headshare.app/Contents/Info.plist)"
DMG="build/Headshare-$VERSION.dmg"
rm -f "$DMG"

if command -v create-dmg >/dev/null 2>&1; then
  # Nicer window: big icons, app on the left, Applications on the right.
  create-dmg \
    --volname "Headshare" \
    --volicon build/Headshare.app/Contents/Resources/AppIcon.icns \
    --window-size 560 340 \
    --icon-size 128 \
    --icon "Headshare.app" 140 160 \
    --app-drop-link 420 160 \
    --hide-extension "Headshare.app" \
    --no-internet-enable \
    "$DMG" build/Headshare.app
else
  STAGE="build/dmg"
  rm -rf "$STAGE" && mkdir -p "$STAGE"
  cp -R build/Headshare.app "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "Headshare" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
fi

echo "✓ $DMG"
