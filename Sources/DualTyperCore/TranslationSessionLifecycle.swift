import Foundation

public struct TranslationSessionLifecycle: Sendable {
    public private(set) var activeSession: UUID?

    public init() {}

    public var isAvailable: Bool {
        activeSession != nil
    }

    public mutating func begin(_ session: UUID) {
        activeSession = session
    }

    public mutating func end(_ session: UUID) {
        guard activeSession == session else { return }
        activeSession = nil
    }
}
