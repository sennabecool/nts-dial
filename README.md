<img width="128" height="128" alt="NTS-Dial" src="https://github.com/user-attachments/assets/dcfe39e5-cd16-4bef-ac1e-73f4b6abccd7" />


# NTS Dial

A compact macOS menu bar player for NTS Radio inspired by the [Atonemo NTS Radio Player](https://shop.nts.live/products/atonemo-nts-radio-player). Tune into NTS 1, NTS 2, or the Infinite Mixtapes from a skeuomorphic SwiftUI dial.

<img width="1406" height="1046" alt="CleanShot 2026-08-12 at 12 00 57" src="https://github.com/user-attachments/assets/7c322c2d-9595-4cee-bdf4-f89db9305258" />


## Features

- Live NTS 1 and NTS 2 playback
- 16 Infinite Mixtape stations playback
- Menu bar controls and Now Playing integration
- Keyboard media key support for play and pause controls
- Persistent station selection with audio and visual feedback

## Requirements

- macOS 14 or later
- Xcode 16 or later

## Run

Open `NTS Dial.xcodeproj` in Xcode, select the **NTS Dial** scheme, and run the app.

## Installation

- Download `NTS.Dial-VERSION.dmg` from the [latest release](https://github.com/sennabecool/nts-dial/releases/latest).
- Open the disk image and drag NTS Dial into the Applications shortcut.
- If macOS blocks the app because "the developer cannot be verified", try opening it once, then go to System Settings → Privacy & Security, scroll down, click Open Anyway, and confirm by clicking Open.

Open NTS Dial.

## Updates

NTS Dial checks GitHub Releases for updates approximately once a day. You can also right-click anywhere in the player and choose **Check for Updates…**. Updates are downloaded, cryptographically verified, and installed by the app after you confirm them.

Version 1.2 is the updater bootstrap release, so users of 1.1 and earlier need to install it manually once. Later releases update in-app.

## Version

v1.2

## Publishing a release

Stable releases are built and published by `.github/workflows/release.yml`. The workflow accepts tags in `vX.Y` or `vX.Y.Z` form, and the tagged commit must already be on `main`.

1. Merge the release commit into `main` and verify the normal test suite.
2. Create and push the version tag, for example: `git tag v1.3 && git push origin v1.3`.
3. The workflow tests and archives a universal Release build, ad-hoc signs the app and Sparkle helpers, runs a packaged-app smoke test, creates the DMG, signs the appcast, and publishes the GitHub release.

Each release contains:

- `NTS.Dial-VERSION.dmg` for both manual and in-app installation
- `appcast.xml`, fetched by installed copies of NTS Dial
- `NTS.Dial-VERSION.md` release notes

The repository Actions secret `SPARKLE_ED_PRIVATE_KEY` contains the private Sparkle signing key. Its matching key is stored in the maintainer Keychain under the account `sennabecool.nts-dial`. Keep an exported copy in an encrypted offline backup; never commit it. To replace the repository secret from an exported key file, run `gh secret set SPARKLE_ED_PRIVATE_KEY --repo sennabecool/nts-dial < /secure/path/nts-dial-private-key`.

Because distribution is ad-hoc signed, the hardened app uses `com.apple.security.cs.disable-library-validation` to load the embedded Sparkle framework. Remove that entitlement if distribution is migrated to a consistently Developer ID-signed and notarized app and framework.

If a workflow failure leaves a draft release behind, inspect its assets, delete only that draft, and re-run the failed workflow. Existing published releases and their `appcast.xml` remain untouched until the final publish step.

## Roadmap

- Widgets ! Already designed (small, medium, large), to implement with WidgetKit, when I have the time. ASAP. 
- iOS port... Only if I can somehow get a greenlight from NTS & Atonemo (because I use their branding & designs after all). On hold.

Disclaimer: This app has been entirely vibe coded with OpenAi Codex, 5.6 models. 

NTS Dial is an independent personal project and is not affiliated with NTS Radio or Atonemo. 
