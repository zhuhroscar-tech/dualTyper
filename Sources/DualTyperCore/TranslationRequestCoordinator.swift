import Foundation

public enum TextControlSecurityPolicy {
    public static func isSecure(subrole: String?) -> Bool {
        subrole == "AXSecureTextField"
    }
}

public enum TranslationRequestCoordinatorError: Error, Equatable, Sendable {
    case timedOut
    case invalidated
}

public actor TranslationRequestCoordinator {
    public struct WorkItem: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let text: String

        public init(id: UUID, text: String) {
            self.id = id
            self.text = text
        }
    }

    private struct PendingRequest {
        let continuation: CheckedContinuation<String, Error>
        var timeoutTask: Task<Void, Never>?
    }

    public nonisolated let workItems: AsyncStream<WorkItem>

    private let streamContinuation: AsyncStream<WorkItem>.Continuation
    private var pending: [UUID: PendingRequest] = [:]

    public init() {
        let stream = AsyncStream.makeStream(of: WorkItem.self)
        workItems = stream.stream
        streamContinuation = stream.continuation
    }

    public func request(text: String, timeout: Duration) async throws -> String {
        let id = UUID()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                pending[id] = PendingRequest(
                    continuation: continuation,
                    timeoutTask: nil
                )
                streamContinuation.yield(WorkItem(id: id, text: text))

                let timeoutTask = Task { [weak self] in
                    do {
                        try await Task.sleep(for: timeout)
                    } catch {
                        return
                    }
                    await self?.timeOut(id: id)
                }
                pending[id]?.timeoutTask = timeoutTask
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
    }

    public func succeed(id: UUID, translation: String) {
        finish(id: id, result: .success(translation))
    }

    public func fail(id: UUID, error: any Error) {
        finish(id: id, result: .failure(error))
    }

    public func invalidateAll() {
        let requests = pending
        pending.removeAll(keepingCapacity: false)

        for request in requests.values {
            request.timeoutTask?.cancel()
            request.continuation.resume(
                throwing: TranslationRequestCoordinatorError.invalidated
            )
        }
    }

    private func timeOut(id: UUID) {
        finish(
            id: id,
            result: .failure(TranslationRequestCoordinatorError.timedOut)
        )
    }

    private func cancel(id: UUID) {
        finish(id: id, result: .failure(CancellationError()))
    }

    private func finish(id: UUID, result: Result<String, any Error>) {
        guard let request = pending.removeValue(forKey: id) else { return }
        request.timeoutTask?.cancel()
        request.continuation.resume(with: result)
    }
}
