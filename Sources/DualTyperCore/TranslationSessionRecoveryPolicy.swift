public enum TranslationSessionInterruption: Sendable {
    case timedOut
    case cancelled
    case invalidated
    case translationFailure
}

public enum TranslationSessionRecoveryPolicy {
    public static func shouldReset(after interruption: TranslationSessionInterruption) -> Bool {
        switch interruption {
        case .timedOut, .cancelled:
            true
        case .invalidated, .translationFailure:
            false
        }
    }
}
