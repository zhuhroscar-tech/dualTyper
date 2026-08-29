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

The repository currently contains the tested, platform-independent core:

- multilingual sentence-boundary detection;
- buffering and commit-trigger modeling;
- deterministic two-line output formatting;
- an asynchronous translation-service boundary;
- a translation-to-insertion pipeline.

The InputMethodKit bundle and Apple Translation adapter are the next integration layer. Building and signing that layer requires full Xcode 16 or newer; this Mac currently has only mismatched Command Line Tools.

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

## Architecture

See [`docs/architecture.md`](docs/architecture.md).

## Privacy

Sentence text is intended to be translated by Apple's on-device Translation framework. DualTyper should not log, persist, or send typed sentence content to a project-operated server. Language-model downloads are managed by macOS and may require network access.

## License

MIT — see [`LICENSE`](LICENSE).
