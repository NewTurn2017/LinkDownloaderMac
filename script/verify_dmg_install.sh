#!/usr/bin/env bash
set -euo pipefail

DMG_PATH="${1:-release/LinkDownloader-0.1.3.dmg}"
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
/usr/bin/open -n "$INSTALL_DIR/$APP_NAME.app"
sleep 1
pgrep -x "$APP_NAME" >/dev/null

echo "$INSTALL_DIR/$APP_NAME.app"
