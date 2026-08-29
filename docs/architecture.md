# Architecture

## User flow

1. The user enables **DualTyper** in **System Settings → Keyboard → Text Input → Edit**.
2. The user selects DualTyper from the macOS Input menu.
3. InputMethodKit sends keystrokes to a per-client input controller.
4. The original text is maintained as marked composition so it remains visible.
5. A terminal punctuation mark or Return creates a `CompletedSentence`.
6. `TextTranslator` translates the completed sentence using the selected language pair.
7. `BilingualPipeline` formats an atomic insertion containing the original line and translated line.
8. The input controller commits the result and begins a new composition.

## Layers

### `DualTyperCore`

Platform-independent and unit tested. It owns:

- `SentenceAccumulator`
- `CompletedSentence` and `CommitTrigger`
- `BilingualInsertionFormatter`
- `TextTranslator`
- `BilingualPipeline`

It does not import AppKit, InputMethodKit, SwiftUI, or Translation.

### Input method bundle (integration target)

A non-sandboxed or correctly entitled `.inputmethod` bundle hosted by macOS. It will own:

- `IMKServer` startup;
- an `IMKInputController` subclass per client session;
- marked-text updates and atomic insertion;
- keyboard-event handling, cancellation, and focus changes;
- serialized handling while translation is in flight.

The bundle connection name must follow Apple's modern convention:

```text
$(PRODUCT_BUNDLE_IDENTIFIER)_Connection
```

### Settings/translation host

Apple's customizable `TranslationSession` API is tied to SwiftUI's `translationTask`. The implementation therefore needs a small hidden or menu-bar SwiftUI host that owns a session and exposes it to the input controller through a narrow translation service.

## Concurrency rules

- All InputMethodKit client interaction stays on the main actor.
- Translation is asynchronous and must never block the event callback.
- Completed sentences are serialized to preserve typing order.
- Client references are not retained across unsafe concurrency boundaries.
- If translation fails, the original sentence must still be committed and typing must continue.

## Compatibility constraints

Some password fields, secure-input contexts, terminal emulators, games, remote-desktop clients, and custom editors may not provide normal InputMethodKit behavior. The MVP targets standard Cocoa text controls first and will document confirmed app compatibility through integration testing.

## References

- [Apple InputMethodKit](https://developer.apple.com/documentation/inputmethodkit)
- [Apple TranslationSession](https://developer.apple.com/documentation/translation/translationsession)
- [WWDC24: Meet the Translation API](https://developer.apple.com/videos/play/wwdc2024/10117)
