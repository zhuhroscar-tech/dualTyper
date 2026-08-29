import Foundation

public struct LanguagePair: Equatable, Sendable {
    public let source: String?
    public let target: String

    public init(source: String?, target: String) {
        self.source = source
        self.target = target
    }
}

public protocol LanguageSettings: AnyObject {
    var sourceLanguage: String? { get set }
    var targetLanguage: String { get set }
    var languagePair: LanguagePair { get }
}

public final class InMemoryLanguageSettings: LanguageSettings {
    public var sourceLanguage: String?
    public var targetLanguage: String

    public var languagePair: LanguagePair {
        LanguagePair(source: sourceLanguage, target: targetLanguage)
    }

    public init(sourceLanguage: String? = nil, targetLanguage: String = "es") {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

public final class UserDefaultsLanguageSettings: LanguageSettings {
    private enum Key {
        static let source = "sourceLanguage"
        static let target = "targetLanguage"
    }

    private let defaults: UserDefaults

    public var sourceLanguage: String? {
        get { defaults.string(forKey: Key.source) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.source)
            } else {
                defaults.removeObject(forKey: Key.source)
            }
        }
    }

    public var targetLanguage: String {
        get { defaults.string(forKey: Key.target) ?? "es" }
        set { defaults.set(newValue, forKey: Key.target) }
    }

    public var languagePair: LanguagePair {
        LanguagePair(source: sourceLanguage, target: targetLanguage)
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
}

public enum TranslationCompletion {
    public static func originalInsertion(originalText: String, trigger: CommitTrigger) -> String {
        originalText + (trigger == .returnKey ? "\n" : "")
    }

    /// The source sentence is already visible/committed. On failure, only
    /// advance to the next typing line so no user text is lost.
    public static func failureInsertion(for sentence: CompletedSentence) -> String {
        switch sentence.trigger {
        case .punctuation:
            return "\n"
        case .returnKey:
            return ""
        }
    }
}

public struct TranslationInputGate: Sendable {
    public private(set) var isTranslationInFlight = false

    public init() {}

    public mutating func beginTranslation() -> Bool {
        guard !isTranslationInFlight else { return false }
        isTranslationInFlight = true
        return true
    }

    public mutating func finishTranslation() {
        isTranslationInFlight = false
    }
}
