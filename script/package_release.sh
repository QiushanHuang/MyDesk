#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MyDesk"
BUNDLE_ID="studio.qiushan.mydesk"
MIN_SYSTEM_VERSION="14.0"
COPYRIGHT="Copyright © 2026 Qiushan Huang. All rights reserved."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"
IFS=. read -r VERSION_MAJOR VERSION_MINOR VERSION_PATCH <<<"$VERSION"
BUILD_NUMBER="${BUILD_NUMBER:-$((VERSION_MAJOR * 10000 + VERSION_MINOR * 100 + VERSION_PATCH))}"
RELEASE_NAME="$APP_NAME-v$VERSION-macOS"
RELEASE_DIR="$ROOT_DIR/dist/release/$RELEASE_NAME"
PAYLOAD_DIR="$RELEASE_DIR/payload"
DMG_ROOT="$RELEASE_DIR/dmg-root"
ARTIFACT_DIR="$RELEASE_DIR/artifacts"
APP_BUNDLE="$PAYLOAD_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
SOURCE_RESOURCES="$ROOT_DIR/Sources/MyDesk/Resources"
RELEASE_NOTES_SOURCE="$ROOT_DIR/docs/releases/v$VERSION.md"

if [[ -e "$RELEASE_DIR" ]]; then
  echo "Release directory already exists: $RELEASE_DIR" >&2
  echo "Move it aside or choose a new VERSION before packaging." >&2
  exit 1
fi

cd "$ROOT_DIR"
swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$ARTIFACT_DIR" "$DMG_ROOT"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$SOURCE_RESOURCES/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHumanReadableCopyright</key>
  <string>$COPYRIGHT</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>MyDesk uses Automation only after confirmation to create Finder aliases and run commands in Terminal.</string>
  <key>NSDesktopFolderUsageDescription</key>
  <string>MyDesk can create Finder aliases in folders you choose.</string>
  <key>NSDocumentsFolderUsageDescription</key>
  <string>MyDesk can create Finder aliases in folders you choose.</string>
</dict>
</plist>
PLIST

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
  SIGNING_STATUS="Signed with Developer ID identity: $CODESIGN_IDENTITY"
else
  codesign --force --sign - "$APP_BUNDLE"
  SIGNING_STATUS="Ad-hoc signed. This release is not notarized."
fi

ditto -c -k --keepParent "$APP_BUNDLE" "$ARTIFACT_DIR/$RELEASE_NAME.zip"

cp -R "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$DMG_ROOT" \
  -format UDZO \
  "$ARTIFACT_DIR/$RELEASE_NAME.dmg" >/dev/null

cat >"$ARTIFACT_DIR/INSTALL.txt" <<TXT
$APP_NAME $VERSION

Install:
1. Open $RELEASE_NAME.dmg.
2. Drag $APP_NAME.app to Applications.
3. Launch $APP_NAME from Applications.

$SIGNING_STATUS

If macOS blocks the first launch because this build is not notarized, open
System Settings > Privacy & Security and allow $APP_NAME, or right-click the app
and choose Open.
TXT

if [[ -f "$RELEASE_NOTES_SOURCE" ]]; then
  cp "$RELEASE_NOTES_SOURCE" "$ARTIFACT_DIR/RELEASE-NOTES.md"
else
  cat >"$ARTIFACT_DIR/RELEASE-NOTES.md" <<TXT
# $APP_NAME $VERSION

macOS release package for MyDesk.

## Current Features

- Native macOS workbench for folders, files, snippets, and visual workflow maps.
- Workspace canvas with resource cards, notes, organization frames, arrow links, and animated flow lines.
- Global and pinned resource libraries with Finder open/reveal and path copy actions.
- SwiftData local storage with JSON import/export support.

## Distribution

- macOS $MIN_SYSTEM_VERSION or newer.
- $SIGNING_STATUS
- License: MIT.
- $COPYRIGHT
TXT
fi

(
  cd "$ARTIFACT_DIR"
  shasum -a 256 "$RELEASE_NAME.zip" "$RELEASE_NAME.dmg" >"SHA256SUMS.txt"
)

codesign --verify --deep --strict "$APP_BUNDLE"
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST" >/dev/null

echo "Release artifacts:"
echo "$ARTIFACT_DIR/$RELEASE_NAME.zip"
echo "$ARTIFACT_DIR/$RELEASE_NAME.dmg"
echo "$ARTIFACT_DIR/SHA256SUMS.txt"
