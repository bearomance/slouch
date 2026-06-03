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

cat > "$APP/Contents/Info.plist" <<'PLIST'
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
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSAppleEventsUsageDescription</key>
	<string>Slouch uses System Events to put your Mac to sleep.</string>
</dict>
</plist>
PLIST

echo "Ad-hoc code-signing…"
codesign --force --deep --sign - "$APP"

echo ""
echo "Done. The app is at ./$APP"
echo "  • Optionally move it to /Applications."
echo "  • On first run, grant Accessibility in System Settings ▸ Privacy & Security ▸ Accessibility."
echo "  • Because it is ad-hoc signed, macOS may re-prompt for Accessibility after a rebuild."
