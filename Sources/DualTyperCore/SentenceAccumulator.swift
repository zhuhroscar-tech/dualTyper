public enum CommitTrigger: Equatable, Sendable {
    case punctuation
    case returnKey
}

public struct CompletedSentence: Equatable, Sendable {
    public let text: String
    public let trigger: CommitTrigger

    public init(text: String, trigger: CommitTrigger) {
        self.text = text
        self.trigger = trigger
    }
}

public struct SentenceAccumulator: Sendable {
    public private(set) var pendingText = ""

    private static let terminalPunctuation: Set<Character> = [
        ".", "!", "?", "。", "！", "？"
    ]

    public init() {}

    public mutating func receive(_ input: String) -> [CompletedSentence] {
        var completed: [CompletedSentence] = []

        for character in input {
            if character == "\n" || character == "\r" {
                if let sentence = makeCompletedSentence(trigger: .returnKey) {
                    completed.append(sentence)
                }
                pendingText = ""
                continue
            }

            pendingText.append(character)
            if Self.terminalPunctuation.contains(character) {
                if let sentence = makeCompletedSentence(trigger: .punctuation) {
                    completed.append(sentence)
                }
                pendingText = ""
            }
        }

        return completed
    }

    public mutating func reset() {
        pendingText = ""
    }

    private func makeCompletedSentence(trigger: CommitTrigger) -> CompletedSentence? {
        let trimmed = String(pendingText.drop(while: { $0.isWhitespace }))
            .dropTrailingWhitespace()
        guard !trimmed.isEmpty else { return nil }
        return CompletedSentence(text: trimmed, trigger: trigger)
    }
}

public enum BilingualInsertionFormatter {
    public static func insertion(
        translation: String,
        trigger: CommitTrigger
    ) -> String {
        switch trigger {
        case .punctuation:
            return "\n\(translation)\n"
        case .returnKey:
            return "\(translation)\n"
        }
    }
}

private extension String {
    func dropTrailingWhitespace() -> String {
        String(reversed().drop(while: { $0.isWhitespace }).reversed())
    }
}
