import Foundation

public enum SelectionTranslationPlan {
    public static func isValidSource(_ source: String) -> Bool {
        source.contains { !$0.isWhitespace }
    }

    public static func replacement(source: String, translation: String) -> String {
        source + "\n" + translation
    }
}

public struct TranslationSelectionSnapshot: Equatable, Sendable {
    public let processIdentifier: Int32
    public let selectedText: String
    public let location: Int
    public let length: Int

    public init(
        processIdentifier: Int32,
        selectedText: String,
        location: Int,
        length: Int
    ) {
        self.processIdentifier = processIdentifier
        self.selectedText = selectedText
        self.location = location
        self.length = length
    }
}

public enum SelectionTranslationGuard {
    public static func canApply(
        original: TranslationSelectionSnapshot,
        current: TranslationSelectionSnapshot
    ) -> Bool {
        original == current
    }
}
