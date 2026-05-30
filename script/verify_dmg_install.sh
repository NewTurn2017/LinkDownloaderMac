#!/usr/bin/env bash
set -euo pipefail

DMG_PATH="${1:-release/LinkDownloader-0.1.5.dmg}"
APP_NAME="LinkDownloader"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
MOUNT_DIR="$(mktemp -d)"

cleanup() {
  /usr/bin/hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
  rm -rf "$MOUNT_DIR"
}
trap cleanup EXIT

if [[ ! -f "$DMG_PATH" ]]; then
  echo "missing DMG: $DMG_PATH" >&2
  exit 1
fi

/usr/bin/hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_DIR"

if [[ ! -d "$MOUNT_DIR/$APP_NAME.app" ]]; then
  echo "DMG does not contain $APP_NAME.app" >&2
  exit 1
fi

/usr/bin/codesign --verify --strict --verbose=2 "$MOUNT_DIR/$APP_NAME.app"
/usr/sbin/spctl -a -vvv -t exec "$MOUNT_DIR/$APP_NAME.app"

ICON_FILE="$(/usr/bin/plutil -extract CFBundleIconFile raw -o - "$MOUNT_DIR/$APP_NAME.app/Contents/Info.plist")"
if [[ ! -f "$MOUNT_DIR/$APP_NAME.app/Contents/Resources/$ICON_FILE.icns" ]]; then
  echo "missing bundled app icon: $ICON_FILE.icns" >&2
  exit 1
fi

for icon_png in AppIcon.png DownloadIcon.png FileIcon.png; do
  ICON_PATH="$MOUNT_DIR/$APP_NAME.app/Contents/Resources/$icon_png"
  if [[ ! -f "$ICON_PATH" ]]; then
    echo "missing icon asset: $icon_png" >&2
    exit 1
  fi
  ALPHA="$(/usr/bin/sips -g hasAlpha "$ICON_PATH" 2>/dev/null | awk '/hasAlpha:/ {print $2}')"
  if [[ "$ALPHA" != "yes" ]]; then
    echo "icon asset has no alpha channel: $icon_png" >&2
    exit 1
  fi
done

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

if [[ -d "$INSTALL_DIR/$APP_NAME.app" ]]; then
  if [[ "${REPLACE_EXISTING:-0}" != "1" ]]; then
    echo "$INSTALL_DIR/$APP_NAME.app already exists. Set REPLACE_EXISTING=1 to replace it." >&2
    exit 1
  fi
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

cp -R "$MOUNT_DIR/$APP_NAME.app" "$INSTALL_DIR/$APP_NAME.app"
/usr/bin/codesign --verify --strict --verbose=2 "$INSTALL_DIR/$APP_NAME.app"
/usr/bin/plutil -extract CFBundleIconFile raw -o - "$INSTALL_DIR/$APP_NAME.app/Contents/Info.plist" >/dev/null
/usr/bin/open -n "$INSTALL_DIR/$APP_NAME.app"
sleep 1
pgrep -x "$APP_NAME" >/dev/null

echo "$INSTALL_DIR/$APP_NAME.app"
