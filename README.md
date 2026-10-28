<p align="center">
  <img src="tools/bootanimation_preview.png" width="540" alt="BananaOS boot screen">
</p>

# BananaOS

A keyboard-first Android 15 ROM for the **BlackBerry KEY2 LE** (`luna`), styled after BlackBerry 10.

Based on PixelOS (`fifteen`) with the [Lineage-BBKey2](https://github.com/Lineage-BBKey2) 4.19 kernel,
device trees and BlackBerry keyboard patches.

## Features

- **BananaLauncher** — BB10-style home screen
  - **Active Frames**: live, closeable cards of your running apps
  - **Banana Hub**: one inbox for notifications, texts, calls and email, with inline reply,
    swipe actions (flag / read / delete) and per-account filters
  - Type anywhere on the keyboard to search apps; **long-press a letter** to launch its app
  - BB10 Hub keyboard shortcuts: `R` reply · `T`/`B` top/bottom · `N`/`P` next/previous day ·
    `U` unread · `F` flag · `D` delete · `S` search · `C` compose · `Space` page down
- **BB10-style lock screen** — clock top-left, notification icons with counts, camera bottom-right
- **Quick settings** with four compact tiles per row and sharper corners
- **BananaOS Setup** — BB10-style first-boot welcome (replaces Google's setup wizard)
- **OTA updates** from this repository — no wipe, no reflash

## Install

> Coming from another ROM (e.g. LineageOS)? You **must format data** the first time,
> because the signing keys differ. Back up first.

1. Download the latest `BananaOS_luna-15.0-*.zip` (and `recovery.img` for the first install)
   from [Releases](https://github.com/iamtheretronerd/banana-os/releases).
2. Boot to fastboot and flash the recovery: `fastboot flash recovery recovery.img`
3. Boot into recovery → **Factory reset → Format data** (first install only).
4. **Apply update → Apply from ADB**, then on the PC: `adb sideload BananaOS_luna-15.0-*.zip`
5. Reboot.

## Updates

Open **Settings → System → System update** and tap **Check for updates**.
Phones read [`ota/fifteen/luna.json`](ota/fifteen/luna.json); the zip itself is a release asset.

## Repository layout

| Path | Purpose |
|---|---|
| `ota/fifteen/luna.json` | OTA metadata the phone polls (written by `publish_github_ota.sh`) |
| `ota/fifteen/luna.md` | Changelog shown in the updater |
| `tools/bmake.sh` | Build helper (`bmake.sh bacon` builds the flashable zip) |
| `tools/publish_github_ota.sh` | Uploads a build as a release, then publishes the OTA metadata |
| `tools/make_bootanimation.py` | Regenerates the boot animation from the logo |

## Publishing an update (maintainers)

```bash
tools/bmake.sh bacon
tools/publish_github_ota.sh "What changed" "Another change"
```

The script uploads the zip to a new release **first**, and only then pushes `luna.json`,
so phones never see an update whose download doesn't exist yet.
