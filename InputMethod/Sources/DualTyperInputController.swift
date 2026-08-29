import AppKit
import InputMethodKit
import DualTyperCore

@objc(DualTyperInputController)
final class DualTyperInputController: IMKInputController {
    private var accumulator = SentenceAccumulator()
    private var markedText = ""
    private var translationInFlight = false

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown,
              let client = sender as? IMKTextInput else { return false }

        if event.keyCode == 53 { // Escape
            cancelComposition(client)
            return true
        }

        if event.keyCode == 51 { // Delete
            guard !markedText.isEmpty else { return false }
            markedText.removeLast()
            accumulator.reset()
            _ = accumulator.receive(markedText)
            updateMarkedText(client)
            return true
        }

        let input: String
        if event.keyCode == 36 || event.keyCode == 76 {
            input = "\n"
        } else if event.modifierFlags.intersection([.command, .control]).isEmpty,
                  let characters = event.characters, !characters.isEmpty {
            input = characters
        } else {
            return false
        }

        let completed = accumulator.receive(input)
        if input != "\n" && input != "\r" {
            markedText.append(input)
        }
        updateMarkedText(client)

        guard let sentence = completed.first, !translationInFlight else { return true }
        beginTranslation(sentence, client: client)
        return true
    }

    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput else { return }
        if !markedText.isEmpty {
            client.insertText(markedText, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }
        resetState()
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "DualTyper target language")
        let selectedTarget = MainActor.assumeIsolated {
            AppleTranslationHost.shared.selectedTarget
        }
        let languages = [
            ("Spanish", "es"), ("French", "fr"), ("German", "de"),
            ("Japanese", "ja"), ("Korean", "ko"),
            ("Chinese (Simplified)", "zh-Hans"), ("Chinese (Traditional)", "zh-Hant"),
            ("English", "en")
        ]
        for (name, identifier) in languages {
            let item = NSMenuItem(title: "Translate to \(name)", action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = identifier
            item.state = selectedTarget == identifier ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        MainActor.assumeIsolated {
            AppleTranslationHost.shared.selectTarget(identifier)
        }
    }

    private func beginTranslation(_ sentence: CompletedSentence, client: IMKTextInput) {
        translationInFlight = true
        let original = sentence.text + (sentence.trigger == .returnKey ? "\n" : "")
        client.insertText(original, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        markedText = ""

        Task { @MainActor [weak self] in
            guard let self else { return }
            let insertion: String
            do {
                let translation = try await AppleTranslationHost.shared.translate(sentence.text)
                insertion = BilingualInsertionFormatter.insertion(translation: translation, trigger: sentence.trigger)
            } catch {
                insertion = TranslationCompletion.failureInsertion(for: sentence)
            }
            client.insertText(insertion, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            self.translationInFlight = false
        }
    }

    private func updateMarkedText(_ client: IMKTextInput) {
        client.setMarkedText(
            markedText,
            selectionRange: NSRange(location: (markedText as NSString).length, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
    }

    private func cancelComposition(_ client: IMKTextInput) {
        client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        resetState()
    }

    private func resetState() {
        accumulator.reset()
        markedText = ""
    }
}
