#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP="Slouch.app"
BIN_SRC=".build/release/Slouch"

echo "Building release binary…"
swift build -c release

echo "Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_SRC" "$APP/Contents/MacOS/Slouch"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

VERSION="${SLOUCH_VERSION:-0.1.0}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>Slouch</string>
	<key>CFBundleIdentifier</key>
	<string>com.slouch.app</string>
	<key>CFBundleName</key>
	<string>Slouch</string>
	<key>CFBundleDisplayName</key>
	<string>Slouch</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${BUILD}</string>
	<key>SlouchGitCommit</key>
	<string>${COMMIT}</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSAppleEventsUsageDescription</key>
	<string>Slouch uses System Events to put your Mac to sleep.</string>
</dict>
</plist>
PLIST

IDENTITY="${SLOUCH_SIGN_IDENTITY:-Slouch Code Signing}"
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
  echo "Code-signing with '$IDENTITY'…"
  codesign --force --deep --sign "$IDENTITY" "$APP"
else
  echo "Identity '$IDENTITY' not found — falling back to ad-hoc signing."
  echo "  (Ad-hoc signed builds lose the Accessibility grant on every rebuild.)"
  codesign --force --deep --sign - "$APP"
fi

echo ""
echo "Done. The app is at ./$APP"
echo "  • Optionally move it to /Applications."
echo "  • On first run, grant Accessibility in System Settings ▸ Privacy & Security ▸ Accessibility."
