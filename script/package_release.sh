#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-package}"

APP_NAME="LinkDownloader"
BUNDLE_ID="com.withgenie.LinkDownloader"
APP_VERSION="${APP_VERSION:-0.1.5}"
MIN_SYSTEM_VERSION="13.0"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: jaehyun jang (2UANJX7ATM)}"
APPLE_DEVELOPER_DIR="${APPLE_DEVELOPER_DIR:-$HOME/dev/private/apple_developer}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$ROOT_DIR/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
DMG_PATH="$RELEASE_DIR/${APP_NAME}-${APP_VERSION}.dmg"
NOTARY_JSON="$RELEASE_DIR/notary-${APP_VERSION}.json"

cd "$ROOT_DIR"

case "$MODE" in
  package|--notarize|notarize)
    ;;
  *)
    echo "usage: $0 [package|--notarize]" >&2
    exit 2
    ;;
esac

rm -rf "$RELEASE_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$DIST_DIR"

swift build -c release --arch arm64 --arch x86_64
BUILD_BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"

cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

./script/build_icons.sh >/dev/null
cp "Assets/AppIcon/$APP_NAME.icns" "$APP_RESOURCES/$APP_NAME.icns"
cp "Assets/AppIcon/AppIcon.png" "$APP_RESOURCES/AppIcon.png"
cp "Assets/AppIcon/DownloadIcon.png" "$APP_RESOURCES/DownloadIcon.png"
cp "Assets/AppIcon/FileIcon.png" "$APP_RESOURCES/FileIcon.png"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>ko</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>LinkDownloader</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_VERSION</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright 2026 WithGenie. Released under the MIT License.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BINARY"
/usr/bin/codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
/usr/bin/codesign --verify --strict --verbose=2 "$APP_BUNDLE"

DMG_STAGING="$(mktemp -d)"
trap 'rm -rf "$DMG_STAGING"' EXIT
cp -R "$APP_BUNDLE" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"

/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

/usr/bin/codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
/usr/bin/codesign --verify --verbose=2 "$DMG_PATH"

if [[ "$MODE" == "--notarize" || "$MODE" == "notarize" ]]; then
  ISSUER_ID="$(sed -n '1p' "$APPLE_DEVELOPER_DIR/key.md" | tr -d '\r\n')"
  KEY_ID="$(sed -n '2p' "$APPLE_DEVELOPER_DIR/key.md" | tr -d '\r\n')"
  KEY_PATH="$APPLE_DEVELOPER_DIR/AuthKey_${KEY_ID}.p8"

  if [[ ! -f "$KEY_PATH" ]]; then
    echo "missing App Store Connect API key: $KEY_PATH" >&2
    exit 1
  fi

  /usr/bin/xcrun notarytool submit "$DMG_PATH" \
    --key "$KEY_PATH" \
    --key-id "$KEY_ID" \
    --issuer "$ISSUER_ID" \
    --wait \
    --output-format json | tee "$NOTARY_JSON"

  NOTARY_STATUS="$(/usr/bin/plutil -extract status raw -o - "$NOTARY_JSON")"
  if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
    SUBMISSION_ID="$(/usr/bin/plutil -extract id raw -o - "$NOTARY_JSON" 2>/dev/null || true)"
    if [[ -n "$SUBMISSION_ID" ]]; then
      /usr/bin/xcrun notarytool log "$SUBMISSION_ID" \
        --key "$KEY_PATH" \
        --key-id "$KEY_ID" \
        --issuer "$ISSUER_ID" || true
    fi
    exit 1
  fi

  /usr/bin/xcrun stapler staple "$DMG_PATH"
  /usr/bin/xcrun stapler validate "$DMG_PATH"
  /usr/sbin/spctl -a -vvv -t open --context context:primary-signature "$DMG_PATH"
fi

echo "$DMG_PATH"
