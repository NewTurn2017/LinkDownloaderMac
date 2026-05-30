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

1. Download `LinkDownloader-0.1.6.dmg` from the GitHub release.
2. Open the DMG.
3. Drag `LinkDownloader.app` to `Applications`.
4. Launch `LinkDownloader` from Applications.

The release DMG is signed with Developer ID and notarized by Apple.

## Use

1. Paste a URL into the input field. If the clipboard already has an `http` or
   `https` URL, the app fills it in at launch.
2. Keep the default destination (`~/Downloads`) or choose another folder.
3. Leave the default options on for one video, or enable `플레이리스트 전체`.
4. Enable `MP3도 함께 저장` when you also want a separate audio file.
5. Click `다운로드`.
6. Use the Finder button to reveal the downloaded file.

Videos are saved as MP4. The app asks `yt-dlp` to prefer H.264/AAC streams,
merge to MP4, and recode to MP4 when the source would otherwise end as WebM.

The Stop button launches each download in its own process group, then terminates
that group. This covers the active `yt-dlp` process and helpers such as `ffmpeg`
when they stay in the same group.

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

The packaging scripts build the transparent app icon assets first, then embed
`LinkDownloader.icns` for Finder, DMG, and Dock display. The release bundle also
contains transparent PNG assets for the in-app download and file icons.

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
./script/verify_dmg_install.sh release/LinkDownloader-0.1.6.dmg
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
