# DualTyper

DualTyper is a macOS input method for bilingual communication. You type a sentence in your normal language; when you finish it with sentence-ending punctuation or Return, DualTyper places an on-device translation on the next line.

```text
Hello, how are you?
你好，你好吗？
```

## Product decisions for the MVP

- **System-wide input source:** designed for standard macOS text fields.
- **Natural original typing:** the original sentence remains visible while it is composed.
- **Sentence-level translation:** translation starts after `.`, `!`, `?`, `。`, `！`, `？`, or Return so the model has enough context.
- **Two-line output:** original first, translation second, followed by a fresh line for the next sentence.
- **Private by default:** the planned translator uses Apple's on-device Translation framework rather than a third-party cloud API.
- **Selectable language pair:** the target language will be chosen in DualTyper settings; source language may be selected or detected when Apple supports the pair.

## Current status

The repository contains the tested, platform-independent core and a first
buildable InputMethodKit integration:

- multilingual sentence-boundary detection;
- buffering and commit-trigger modeling;
- deterministic two-line output formatting;
- an asynchronous translation-service boundary;
- a translation-to-insertion pipeline;
- a selectable `.inputmethod` bundle with marked-text composition;
- an Apple Translation framework host backed by SwiftUI `translationTask`;
- persisted target-language selection in the input-source menu;
- failure fallback that never drops the original sentence.

## Requirements

- macOS 15 or later for Apple's customizable `TranslationSession` API
- Xcode 16 or later to build the input method bundle
- downloaded Apple translation language assets for the selected pair

## Test the core

On a healthy Xcode/Swift installation:

```bash
swift test
```

A dependency-free direct runner is also included:

```bash
./scripts/test-core.sh
```

## Build the input method

The checked-in Xcode project builds without code signing for local installation:

```bash
xcodebuild \
  -project DualTyper.xcodeproj \
  -scheme DualTyperInputMethod \
  -configuration Release \
  -derivedDataPath .build/xcode-release \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The bundle is produced at:

```text
.build/xcode-release/Build/Products/Release/DualTyper.inputmethod
```

`project.yml` is the maintainable project definition. After changing it,
regenerate `DualTyper.xcodeproj` with XcodeGen 2.46 or newer:

```bash
xcodegen generate
```

## Install and enable locally

Do not run these commands while editing the bundle in place. Copy the completed
artifact, then enable it through macOS:

```bash
mkdir -p "$HOME/Library/Input Methods"
rm -rf "$HOME/Library/Input Methods/DualTyper.inputmethod"
cp -R ".build/xcode-release/Build/Products/Release/DualTyper.inputmethod" \
  "$HOME/Library/Input Methods/"
```

1. Log out and back in (the most reliable way to refresh input sources).
2. Open **System Settings → Keyboard → Text Input → Edit**.
3. Press **+**, find **DualTyper**, and add it.
4. Select **DualTyper** from the menu-bar Input menu.
5. In TextEdit, type `Hello world?`. The source remains visible as marked text;
   after `?`, the translated text is inserted on the following line.
6. Open the DualTyper input-source menu to choose the target language.

The first translation for a language pair may cause macOS to request/download
Apple's on-device language assets. This MVP does not automate or bypass that
system-owned interaction.

To remove the local build, switch to another input source first, then delete
`~/Library/Input Methods/DualTyper.inputmethod` and log out/in.

## MVP limitations

- Translation availability and language-model downloads are controlled by macOS.
- The unsigned local build is for development; distribution requires Developer ID
  signing and notarization.
- Secure fields and apps with custom text systems may reject InputMethodKit input.
- Do not finish a second sentence while the first translation is in flight; queued
  multi-sentence composition is a follow-up integration requirement.

## Architecture

See [`docs/architecture.md`](docs/architecture.md). Release signing, notarization,
DMG, and installer guidance is in
[`docs/release-packaging.md`](docs/release-packaging.md).

## Privacy

Sentence text is intended to be translated by Apple's on-device Translation framework. DualTyper should not log, persist, or send typed sentence content to a project-operated server. Language-model downloads are managed by macOS and may require network access.

## License

MIT — see [`LICENSE`](LICENSE).
