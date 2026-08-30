import AppKit
import DualTyperCore

struct TranslationLanguage: Identifiable, Equatable {
    let id: String
    let name: String
}

@MainActor
final class DualTyperController: ObservableObject {
    static let languages = [
        TranslationLanguage(id: "es", name: "Spanish"),
        TranslationLanguage(id: "fr", name: "French"),
        TranslationLanguage(id: "de", name: "German"),
        TranslationLanguage(id: "ja", name: "Japanese"),
        TranslationLanguage(id: "ko", name: "Korean"),
        TranslationLanguage(id: "zh-Hans", name: "Chinese (Simplified)"),
        TranslationLanguage(id: "zh-Hant", name: "Chinese (Traditional)"),
        TranslationLanguage(id: "en", name: "English")
    ]

    @Published private(set) var accessibilityGranted = false
    @Published private(set) var isBusy = false
    @Published private(set) var statusText = "Select a sentence in another app and press Control–Option–T."
    @Published private(set) var selectedTarget: String

    private let accessibility = AccessibilityTextService()
    private let translator = AppleTranslationHost.shared
    private let hotKey = GlobalHotKeyMonitor()

    init() {
        selectedTarget = translator.selectedTarget
        refreshPermission()

        do {
            try hotKey.start { [weak self] in
                Task { @MainActor in
                    self?.translateSelection()
                }
            }
        } catch {
            statusText = error.localizedDescription
        }
    }


    var selectedLanguageName: String {
        Self.languages.first(where: { $0.id == selectedTarget })?.name ?? selectedTarget
    }

    func refreshPermission() {
        accessibilityGranted = accessibility.isTrusted
    }

    func requestAccessibilityPermission() {
        accessibilityGranted = accessibility.requestPermission()
        if accessibilityGranted {
            statusText = "Accessibility is enabled. Select text and press Control–Option–T."
        } else {
            statusText = "Enable DualTyper in Privacy & Security → Accessibility, then reopen it."
        }
    }

    func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func selectTarget(_ identifier: String) {
        guard Self.languages.contains(where: { $0.id == identifier }) else { return }
        selectedTarget = identifier
        statusText = "Target language: \(selectedLanguageName)."
        Task { @MainActor [translator] in
            await translator.selectTarget(identifier)
        }
    }

    func translateSelection() {
        refreshPermission()
        guard accessibilityGranted else {
            statusText = "Accessibility permission is required. Open DualTyper to enable it."
            requestAccessibilityPermission()
            return
        }
        guard !isBusy else {
            statusText = "A translation is already in progress."
            return
        }

        let captured: AccessibleSelection
        do {
            captured = try accessibility.captureSelection()
        } catch {
            statusText = error.localizedDescription
            return
        }

        isBusy = true
        statusText = "Translating the selected text to \(selectedLanguageName)…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isBusy = false }
            do {
                let translation = try await translator.translate(captured.snapshot.selectedText)
                let replacement = SelectionTranslationPlan.replacement(
                    source: captured.snapshot.selectedText,
                    translation: translation
                )
                try accessibility.replaceIfUnchanged(captured, with: replacement)
                statusText = "Translation inserted beneath the original."
            } catch {
                statusText = error.localizedDescription
            }
        }
    }
}
