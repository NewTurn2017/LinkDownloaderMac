# LinkDownloader

LinkDownloader is a tiny open-source macOS app that downloads media from a URL
through `yt-dlp`. Paste a link, choose a folder, and press Download.

The app was built for quick local use with X/Twitter links, but it delegates
the actual extraction to `yt-dlp`, so any URL supported by `yt-dlp` can work.

## Requirements

- macOS 13 or later
- `yt-dlp`
- `ffmpeg`

Install runtime tools with Homebrew:

```bash
brew install yt-dlp ffmpeg
```

## Install From DMG

1. Download `LinkDownloader-0.1.2.dmg` from the GitHub release.
2. Open the DMG.
3. Drag `LinkDownloader.app` to `Applications`.
4. Launch `LinkDownloader` from Applications.

The release DMG is signed with Developer ID and notarized by Apple.

## Use

1. Paste a URL into the input field.
2. Keep the default destination (`~/Downloads`) or choose another folder.
3. Click `다운로드`.
4. Use the Finder button to reveal the downloaded file.

The Stop button terminates the active `yt-dlp` process and its child processes,
including merge/transcode helpers such as `ffmpeg` when `yt-dlp` starts them as
children.

For each download, the app asks `yt-dlp` to save the video, thumbnail, and
metadata JSON using this filename template:

```text
%(uploader)s_%(id)s.%(ext)s
```

## Build Locally

```bash
swift build
```

Run the local development app bundle:

```bash
./script/build_and_run.sh
```

## Package A Release

Create a signed universal DMG:

```bash
./script/package_release.sh
```

Create a signed, notarized, stapled DMG:

```bash
./script/package_release.sh --notarize
```

The notarization script expects App Store Connect API credentials in this local
layout:

```text
$APPLE_DEVELOPER_DIR/key.md
$APPLE_DEVELOPER_DIR/AuthKey_<KEY_ID>.p8
```

`key.md` contains the issuer ID on line 1 and the key ID on line 2. Do not
commit those credentials. If `APPLE_DEVELOPER_DIR` is not set, the script uses
`$HOME/dev/private/apple_developer`.

## Verify The DMG

After packaging:

```bash
./script/verify_dmg_install.sh release/LinkDownloader-0.1.2.dmg
```

The script mounts the DMG, verifies signatures and Gatekeeper assessment,
copies the app to `/Applications`, launches it, and confirms the process is
running. If `/Applications/LinkDownloader.app` already exists, set
`REPLACE_EXISTING=1` to replace it during verification.

## Project Layout

```text
Sources/LinkDownloader/App        App entry point
Sources/LinkDownloader/Views      SwiftUI views
Sources/LinkDownloader/Stores     Main UI state
Sources/LinkDownloader/Services   yt-dlp process wrapper
Sources/LinkDownloader/Support    Shell helpers
script/                           Build, package, and verification scripts
```

## License

MIT
