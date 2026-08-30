import Foundation

public final class SendableCallbackRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var callback: (@Sendable () -> Void)?

    public init() {}

    public func set(_ callback: @escaping @Sendable () -> Void) {
        lock.lock()
        self.callback = callback
        lock.unlock()
    }

    public func clear() {
        lock.lock()
        callback = nil
        lock.unlock()
    }

    public func invoke() {
        lock.lock()
        let callback = callback
        lock.unlock()
        callback?()
    }
}
