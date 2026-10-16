# Install and update

## Choose a download

Open [the latest GitHub release](https://github.com/alialfredji/focused-break/releases/latest). In Apple menu → About This Mac, check whether your Mac lists an Apple chip or an Intel processor.

- **arm64.dmg**: Apple Silicon (M1 or later).
- **x86_64.dmg**: Intel.
- ZIP files contain the same app if you prefer an archive.

macOS 14 or later and Metal support are required. Download an app asset, not GitHub's automatically generated source-code ZIP.

## Install

1. Open the DMG.
2. Drag **Focused Break.app** onto **Applications**.
3. Eject the disk image and open Focused Break from Applications.

For a ZIP, extract it and move the app to Applications before opening it.

## macOS first-open prompt

These releases are ad-hoc signed and are **not notarized by Apple**. After attempting to open the app, macOS may block it because it cannot verify the developer.

If you trust this repository and the downloaded release, open **System Settings → Privacy & Security**, find the message for Focused Break, choose **Open Anyway**, and confirm the app-specific prompt. This is Apple's supported per-app exception; do not disable system-wide security or remove quarantine in Terminal. See [Apple's guide to opening apps safely](https://support.apple.com/102445).

Managed work Macs may prohibit this exception. Use your organization's approved installation process.

## Optional screen access

The basic image and black-hole overlay do not need screen access. **Distort desktop** and **Live desktop** preview use Screen Recording / Screen & System Audio Recording permission (the name varies by macOS version). Only screen video is requested, not audio. Enable Focused Break in Privacy & Security if you want these features, then relaunch if macOS requests it.

## Update

There is no in-app auto-updater. Quit Focused Break, download the latest release, and replace the app in Applications. Your settings and saved image remain. A session in progress does not survive quitting. Screen-access permission may need to be re-enabled after an ad-hoc-signed update.

## Verify the download

Each release includes `SHA256SUMS-arm64.txt` and `SHA256SUMS-x86_64.txt`. Download the matching checksum file, ZIP, and DMG into the same folder and run:

```sh
shasum -a 256 -c SHA256SUMS-arm64.txt
```

Use the Intel filename for Intel downloads. Missing one of the two archives reports that file as missing; compare the checksum for the file you actually downloaded. Checksums confirm file integrity, not Apple notarization.

## Uninstall

Quit the app and move it from Applications to Trash. Your preferences and image remain locally; their paths are listed in [Privacy](PRIVACY.md).
