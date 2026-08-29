import AppKit
import InputMethodKit
import DualTyperCore

@objc(DualTyperInputController)
final class DualTyperInputController: IMKInputController {
    private var accumulator = SentenceAccumulator()
    private var markedText = ""
    private var translationGate = TranslationInputGate()
    private var activationGeneration: UInt = 0
    private var activeTranslation: Task<Void, Never>?

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown,
              let client = sender as? IMKTextInput else { return false }

        // Never swallow keys while an asynchronous translation is pending.
        // Continuing to type moves the selection, which causes the stale
        // translation to be discarded by the context checks below.
        guard !translationGate.isTranslationInFlight else { return false }

        if event.keyCode == 53 { // Escape
            guard !markedText.isEmpty else { return false }
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
            guard InputHandlingPolicy.shouldConsumeReturn(bufferedText: markedText) else {
                commitComposition(client)
                return false
            }
            input = "\n"
        } else if event.modifierFlags.intersection([.command, .control, .function]).isEmpty,
                  let characters = event.characters,
                  InputHandlingPolicy.shouldConsumeCharacters(characters) {
            input = characters
        } else {
            commitComposition(client)
            return false
        }

        var candidateAccumulator = accumulator
        let completed = candidateAccumulator.receive(input)
        guard InputHandlingPolicy.shouldConsumeChunk(
            completedSentenceCount: completed.count,
            hasPendingSuffix: !candidateAccumulator.pendingText.isEmpty
        ) else {
            commitComposition(client)
            return false
        }
        accumulator = candidateAccumulator
        if input != "\n" && input != "\r" {
            markedText.append(input)
        }
        updateMarkedText(client)

        guard let sentence = completed.first else { return true }
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

    override func activateServer(_ sender: Any!) {
        activationGeneration &+= 1
        super.activateServer(sender)
    }

    override func deactivateServer(_ sender: Any!) {
        activationGeneration &+= 1
        activeTranslation?.cancel()
        activeTranslation = nil
        translationGate.finishTranslation()
        commitComposition(sender)
        super.deactivateServer(sender)
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
        guard translationGate.beginTranslation() else { return }
        let original = TranslationCompletion.originalInsertion(
            originalText: markedText,
            trigger: sentence.trigger
        )
        client.insertText(original, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        markedText = ""
        let generation = activationGeneration
        let clientIdentifier = ObjectIdentifier(client as AnyObject)
        let expectedSelection = client.selectedRange()

        activeTranslation = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if generation == self.activationGeneration {
                    self.translationGate.finishTranslation()
                    self.activeTranslation = nil
                }
            }
            let insertion: String
            do {
                let translation = try await AppleTranslationHost.shared.translate(sentence.text)
                insertion = BilingualInsertionFormatter.insertion(translation: translation, trigger: sentence.trigger)
            } catch {
                insertion = TranslationCompletion.failureInsertion(for: sentence)
            }
            guard !Task.isCancelled,
                  generation == self.activationGeneration,
                  let currentClient = self.client(),
                  ObjectIdentifier(currentClient as AnyObject) == clientIdentifier,
                  currentClient.selectedRange() == expectedSelection else { return }
            currentClient.insertText(insertion, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
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
