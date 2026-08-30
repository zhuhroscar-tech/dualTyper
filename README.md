# DualTyper

[![Core CI](https://github.com/zhuhroscar-tech/dualTyper/actions/workflows/core.yml/badge.svg)](https://github.com/zhuhroscar-tech/dualTyper/actions/workflows/core.yml)
[![Release](https://img.shields.io/github/v/release/zhuhroscar-tech/dualTyper?include_prereleases&label=release)](https://github.com/zhuhroscar-tech/dualTyper/releases/tag/v0.3.0)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-111111?logo=apple)

DualTyper is a macOS menu-bar translator for bilingual writing. Select a sentence in an editable app and press **Control–Option–T**. DualTyper preserves the exact selected source and inserts Apple’s on-device translation beneath it.

![DualTyper setup window explaining its explicit Accessibility permission and keyboard shortcut](docs/images/dualtyper-setup.png)

[Download the free v0.3.0 prerelease](https://github.com/zhuhroscar-tech/dualTyper/releases/tag/v0.3.0) · [Architecture](docs/architecture.md) · [Free distribution guide](docs/free-distribution.md)

```text
Hello, how are you?
你好，你好吗？
```

## Free build: no Apple Developer Program required

The primary build is now a normal menu-bar app rather than an InputMethodKit keyboard plugin. This avoids the paid Developer ID requirement that prevented the ad-hoc `.inputmethod` bundle from appearing in macOS Text Input settings.

- No $99/year Apple Developer Program membership is required to build or use it.
- End users do not need Xcode.
- The app uses Apple’s on-device Translation framework and no project-operated server.
- It requests **Accessibility** only so it can read and replace the user’s explicit selection.
- It does not request Input Monitoring or continuously record keystrokes.
- It appears in the normal macOS menu bar, not the keyboard Input Source menu.

The free DMG is deliberately ad-hoc signed and unnotarized. Every user must manually approve the app in **System Settings → Privacy & Security** and then grant Accessibility permission. Managed Macs may prohibit these overrides. See [`docs/free-distribution.md`](docs/free-distribution.md).

## Requirements

- macOS 15 or later
- A standard editable text control that exposes its selection through macOS Accessibility
- Apple translation language assets for the selected language pair
- User permission to open an unknown-developer app and grant Accessibility access

## Install the free build

1. Open `DualTyper-0.3.0-FREE-UNNOTARIZED.dmg`.
2. Drag **DualTyper** to **Applications**.
3. Try to open `/Applications/DualTyper.app`.
4. If macOS blocks it, open **System Settings → Privacy & Security**, scroll to **Security**, and click **Open Anyway** for DualTyper. Authenticate locally if macOS asks. Never share that password with anyone.
5. In DualTyper, click **Allow Accessibility**.
6. In **Privacy & Security → Accessibility**, turn on DualTyper. If it is absent, click **+** and select `/Applications/DualTyper.app`.
7. Quit and reopen DualTyper after changing permission.

An ad-hoc update may reset Accessibility permission because it has no stable Developer ID identity. If that happens, remove the old DualTyper entry from the Accessibility list, add the exact new `/Applications/DualTyper.app`, and turn it on again.

Apple documents both user-controlled steps:

- [Open an app from an unknown developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)
- [Allow accessibility apps to access your Mac](https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac)

## Use DualTyper

1. Choose the target language from the DualTyper menu-bar menu.
2. Keep the DualTyper setup window open or minimized; Apple’s Translation session is owned by that window.
3. In TextEdit, Notes, or another supported editor, select the exact sentence to translate.
4. Press **Control–Option–T**.
5. Keep the same app and selection active while translation completes.
6. DualTyper rechecks the process, selected text, and selection range immediately before editing. If it detects a change, it inserts nothing.

The first request for a language pair may prompt macOS to download Apple’s translation assets.

## Compatibility and limitations

- The free architecture uses an explicit shortcut, not automatic punctuation detection.
- The setup window must remain open or minimized because macOS 15 exposes customizable Translation sessions through a SwiftUI view lifecycle.
- DualTyper refuses macOS secure-input mode and controls exposed with the `AXSecureTextField` subrole.
- Some web editors, Electron apps, terminals, games, remote desktops, and custom text controls do not expose an editable Accessibility selection.
- Accessibility has no atomic compare-and-set operation across processes. DualTyper minimizes the interval between its final recheck and replacement, but a tiny unavoidable race remains if the target app changes its selection at exactly that moment.
- The free build is not notarized. Gatekeeper will reject it until each user grants a local exception.
- There is no legitimate zero-fee way to remove the unknown-developer warning for arbitrary downloads; Developer ID signing and notarization require Apple Developer Program membership.
- A company- or school-managed Mac can disable **Open Anyway** or Accessibility approval. No app can safely bypass those administrator policies.

## Build and test

```bash
xcodegen generate
swift test
./scripts/test-core.sh
xcodebuild \
  -project DualTyper.xcodeproj \
  -scheme DualTyperMenuBar \
  -configuration Release \
  -derivedDataPath .build/release-menubar \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  build
```

Create and verify the free universal DMG:

```bash
./scripts/package-menubar-dmg.sh
```

The script verifies tests, direct tests, a universal `arm64 + x86_64` executable, ad-hoc code integrity, exact DMG contents, image integrity, and a portable SHA-256 sidecar.

## Legacy InputMethodKit prototype

The repository still contains the original `.inputmethod` prototype and its independently testable sentence-accumulation core. An ad-hoc InputMethodKit bundle may copy successfully to `~/Library/Input Methods`, but current macOS does not reliably enumerate it as a selectable Input Source. A broadly distributable keyboard Input Source still requires accepted signing and notarization.

## Privacy

DualTyper does not log, persist, or send selected sentence text to a project-operated server. Selected text is passed to Apple’s Translation framework in memory. macOS manages translation-language downloads. Accessibility is powerful permission; users should install only artifacts obtained from a trusted source and verify the published SHA-256 checksum.

## Architecture

See [`docs/architecture.md`](docs/architecture.md) and [`docs/free-distribution.md`](docs/free-distribution.md).

## License

MIT — see [`LICENSE`](LICENSE).
