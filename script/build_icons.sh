#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LinkDownloader"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_DIR="$ROOT_DIR/Assets/AppIcon"
SOURCE_PNG="${ICON_SOURCE:-$ASSET_DIR/${APP_NAME}-nobg.png}"
ICONSET_DIR="$ASSET_DIR/${APP_NAME}.iconset"
ICNS_PATH="$ASSET_DIR/${APP_NAME}.icns"

if [[ ! -f "$SOURCE_PNG" ]]; then
  echo "missing icon source: $SOURCE_PNG" >&2
  exit 1
fi

ALPHA="$(/usr/bin/sips -g hasAlpha "$SOURCE_PNG" 2>/dev/null | awk '/hasAlpha:/ {print $2}')"
if [[ "$ALPHA" != "yes" ]]; then
  echo "icon source must have an alpha channel: $SOURCE_PNG" >&2
  exit 1
fi

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

make_png() {
  local pixels="$1"
  local output="$2"
  /usr/bin/sips -s format png -z "$pixels" "$pixels" "$SOURCE_PNG" --out "$output" >/dev/null
}

make_png 16 "$ICONSET_DIR/icon_16x16.png"
make_png 32 "$ICONSET_DIR/icon_16x16@2x.png"
make_png 32 "$ICONSET_DIR/icon_32x32.png"
make_png 64 "$ICONSET_DIR/icon_32x32@2x.png"
make_png 128 "$ICONSET_DIR/icon_128x128.png"
make_png 256 "$ICONSET_DIR/icon_128x128@2x.png"
make_png 256 "$ICONSET_DIR/icon_256x256.png"
make_png 512 "$ICONSET_DIR/icon_256x256@2x.png"
make_png 512 "$ICONSET_DIR/icon_512x512.png"
make_png 1024 "$ICONSET_DIR/icon_512x512@2x.png"

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
make_png 256 "$ASSET_DIR/AppIcon.png"
make_png 256 "$ASSET_DIR/DownloadIcon.png"
make_png 256 "$ASSET_DIR/FileIcon.png"

echo "$ICNS_PATH"
