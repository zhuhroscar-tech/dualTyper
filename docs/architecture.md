# Architecture

DualTyper contains two front ends over a testable Swift core. The zero-fee menu-bar app is the primary path; the InputMethodKit bundle remains a legacy prototype.

## Primary zero-fee user flow

1. The user opens the ad-hoc-signed app through macOS **Open Anyway** and grants Accessibility permission.
2. The app registers **Control–Option–T** with Carbon’s global-hotkey API. It does not continuously monitor keyboard events.
3. The user explicitly selects a sentence in an editable app and presses the shortcut.
4. `AccessibilityTextService` captures the focused AX element, process identifier, exact selected text, and selected range.
5. `AppleTranslationHost` translates the selection with Apple’s on-device Translation framework.
6. Before editing, the service reacquires the focused element and selection.
7. `SelectionTranslationGuard` requires the AX element, process identifier, exact text, location, and length to remain unchanged.
8. The selected source is replaced with `source + "\n" + translation` through `kAXSelectedTextAttribute` immediately after the final recheck.
9. If the selection is observed to have changed, secure-input mode is active, the control has the `AXSecureTextField` subrole, or the selection is not editable through Accessibility, nothing is inserted.

macOS Accessibility does not expose an atomic compare-and-set primitive for another process's selection. The final recheck and the AX replacement are therefore separate cross-process operations. DualTyper removes unnecessary IPC between them and fails closed on every detectable change, but it cannot eliminate the tiny residual race if a target changes at the exact boundary.

## Layers

### `DualTyperCore`

Platform-independent and unit tested. It owns:

- `SentenceAccumulator`
- `CompletedSentence` and `CommitTrigger`
- `BilingualInsertionFormatter`
- `TextTranslator` and `BilingualPipeline`
- `SelectionTranslationPlan`
- `TranslationSelectionSnapshot` and `SelectionTranslationGuard`
- language settings and translation concurrency gates

It does not import AppKit, ApplicationServices, InputMethodKit, SwiftUI, or Translation.

### Menu-bar app

A standard non-sandboxed macOS application. It owns:

- setup and permission UI;
- a menu-bar status item and target-language menu;
- the Carbon global shortcut;
- Accessibility selection capture and guarded replacement;
- the SwiftUI-owned Apple Translation session.

The app requests Accessibility because AX APIs are not supported for this use in the App Sandbox. It does not request Input Monitoring because the explicit global hotkey does not require continuous event capture.

### Translation host

Apple’s customizable `TranslationSession` API is tied to SwiftUI’s `translationTask`. The modifier is attached to the visible setup window so macOS can present required language-asset download UI. The window must remain open or minimized while DualTyper is used. If no live session exists, requests fail immediately instead of waiting indefinitely. If a request times out or its caller cancels, DualTyper explicitly invalidates and disables the old task configuration, invalidates its coordinator, and starts a new session so stale work cannot block later requests. Target-language preferences are stored with `UserDefaultsLanguageSettings`.

### Legacy Input Method bundle

The `.inputmethod` prototype owns `IMKServer`, `IMKInputController`, marked-text composition, sentence-triggered translation, and Input Source language menus. Its ad-hoc build is not reliably enumerated by current macOS. It is retained for a future accepted-signing path, not used by the free DMG.

## Security and privacy rules

- Never log or persist selected sentence text.
- Never insert after the focused AX element, process, selected text, or selected range changes.
- Never operate in secure fields that do not expose a normal editable selection.
- Never bypass Gatekeeper, TCC, administrator policy, or user approval programmatically.
- Keep source text byte-for-byte/character-for-character identical in the replacement.
- Use no project-operated translation server or API credential.

## Distribution model

The free artifact is ad-hoc signed for structural code integrity and is intentionally not notarized. Gatekeeper rejection is expected. Each user must approve the exact downloaded app through Privacy & Security and separately grant Accessibility permission. This can work without a developer subscription, but it is not equivalent to Developer ID distribution and may be prohibited on managed Macs.

## Compatibility constraints

Standard Cocoa editors such as TextEdit and Notes are the first acceptance targets. Some browser editors, Electron apps, terminals, games, remote-desktop clients, password fields, and custom text systems may not expose `kAXSelectedTextAttribute` as readable and settable.

## References

- [Apple TranslationSession](https://developer.apple.com/documentation/translation/translationsession)
- [Apple: Open an app from an unknown developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)
- [Apple: Allow accessibility apps](https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac)
- [Apple InputMethodKit](https://developer.apple.com/documentation/inputmethodkit)
