[![English](https://img.shields.io/badge/English-555555?style=flat)](README.md) [![简体中文](https://img.shields.io/badge/简体中文-555555?style=flat)](README.zh-CN.md)

# DualTyper

A macOS menu-bar translator for bilingual writing. Select text in an editable app and press **Control–Option–T**: DualTyper keeps the selected source and inserts Apple's on-device translation beneath it.

![Setup window with Accessibility permission and shortcut](docs/images/dualtyper-setup.png)

## Requirements

- macOS 15+ on Apple silicon or Intel.
- An editable control exposing a readable and settable Accessibility selection.
- Apple's translation assets for the chosen language pair; macOS may prompt to download them on first use.
- Permission to open an unknown-developer app and grant Accessibility access.

## Install

Download the [v0.3.0 free prerelease](https://github.com/zhuhroscar-tech/dualTyper/releases/tag/v0.3.0) and verify the published SHA-256 checksum. End users do not need Xcode or Apple Developer Program membership.

1. Open `DualTyper-0.3.0-FREE-UNNOTARIZED.dmg` and drag DualTyper to Applications.
2. Try opening `/Applications/DualTyper.app`.
3. If blocked, use **System Settings → Privacy & Security → Open Anyway**. Authenticate locally if asked; never share the password.
4. Click **Allow Accessibility**, then enable DualTyper under **Privacy & Security → Accessibility**. If missing, add the exact app with **+**.
5. Quit and reopen DualTyper after changing permission.

The free build is **ad-hoc signed and unnotarized**. Managed Macs may prohibit either approval; do not bypass administrator policies. An update may reset Accessibility access: remove the old entry, add the new app, and enable it again. See the [distribution guide](docs/free-distribution.md) for verification and permission details.

## Use

Choose a target language from the menu bar. Keep the setup window **open or minimized**, select a sentence in a supported editor, and press **Control–Option–T**. Keep the app and selection unchanged until translation finishes.

DualTyper rechecks the process, text, and selection range before replacement and cancels if they changed. Accessibility has no atomic cross-process compare-and-set operation, so a small race remains between the final check and insertion.

## Privacy and limits

- No Input Monitoring permission or continuous keystroke recording. Selected text is passed to Apple's Translation framework in memory, not logged, persisted, or sent to a project-operated server.
- Secure-input mode and `AXSecureTextField` controls are refused.
- Some web editors, Electron apps, terminals, games, and remote desktops lack usable Accessibility selection support.
- This is a shortcut-driven menu-bar app, not an automatically triggered keyboard input source. The legacy InputMethodKit prototype remains in the repository but ad-hoc registration is unreliable.

## Build and test

Building the app requires Xcode and XcodeGen 2.46+. Start with:

```bash
xcodegen generate
swift test
./scripts/test-core.sh
./scripts/package-menubar-dmg.sh
```

The packaging script builds and checks the universal app and DMG. See [architecture](docs/architecture.md) and [distribution details](docs/free-distribution.md) for the app lifecycle, signing, and packaging checks.

[MIT license](LICENSE).
