#!/bin/bash
# Builds Headshare.app into ./build.
#   ./build.sh            build for this Mac
#   ./build.sh install    build and copy to /Applications
# Env: UNIVERSAL=1 (Apple Silicon + Intel), VERSION=1.2.0 (overrides Info.plist)
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Headshare.app"
ARCHS=()
[ "${UNIVERSAL:-0}" = "1" ] && ARCHS=(--arch arm64 --arch x86_64)

echo "→ Building (release)…"
swift build -c release ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/Headshare"

echo "→ Creating bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build
cp "$BIN" "$APP/Contents/MacOS/Headshare"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/Localization/*.lproj "$APP/Contents/Resources/"   # 39 localizations (see Localization/)

if [ -n "${VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER:-$VERSION}" "$APP/Contents/Info.plist"
fi

echo "→ Icon…"
# Compiles Resources/AppIcon.icon (made in Icon Composer) exactly as designed:
# Assets.car with light/dark/clear/tinted for macOS 26, AppIcon.icns for macOS 14–15. Needs Xcode 26+.
if ! xcrun actool Resources/AppIcon.icon \
     --compile "$APP/Contents/Resources" \
     --app-icon AppIcon \
     --include-all-app-icons \
     --output-partial-info-plist build/icon-partial.plist \
     --enable-on-demand-resources NO \
     --development-region en \
     --target-device mac \
     --platform macosx \
     --minimum-deployment-target 14.0 \
     --output-format human-readable-text --errors > build/actool.log 2>&1 \
   || [ ! -f "$APP/Contents/Resources/AppIcon.icns" ]; then
  echo "✗ Couldn't compile Resources/AppIcon.icon (Xcode 26 required). Details:"
  cat build/actool.log
  exit 1
fi
/usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :CFBundleIconName AppIcon" "$APP/Contents/Info.plist"

echo "→ Signing…"
# Uses a Developer ID if SIGN_IDENTITY is set, otherwise ad-hoc.
codesign --force --deep --options runtime --timestamp=none --sign "${SIGN_IDENTITY:--}" "$APP"

if [ "${1:-}" = "install" ]; then
  pkill -x Headshare 2>/dev/null || true
  rm -rf /Applications/Headshare.app
  cp -R "$APP" /Applications/Headshare.app
  xattr -dr com.apple.quarantine /Applications/Headshare.app 2>/dev/null || true
  echo "✓ Installed to /Applications/Headshare.app"
  open /Applications/Headshare.app
else
  echo "✓ Ready: $APP"
fi
