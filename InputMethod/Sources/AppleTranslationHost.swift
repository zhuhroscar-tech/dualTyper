import AppKit
import SwiftUI
import Translation
import DualTyperCore

@available(macOS 15.0, *)
@MainActor
final class AppleTranslationHost: ObservableObject {
    static let shared = AppleTranslationHost()

    struct Request {
        let text: String
        let continuation: CheckedContinuation<String, Error>
    }

    @Published private(set) var configuration: TranslationSession.Configuration
    private let settings = UserDefaultsLanguageSettings()
    private let continuation: AsyncStream<Request>.Continuation
    private let requests: AsyncStream<Request>
    private var panel: NSPanel?

    private init() {
        let pair = settings.languagePair
        configuration = Self.makeConfiguration(pair)
        let stream = AsyncStream<Request>.makeStream()
        requests = stream.stream
        continuation = stream.continuation
    }

    var selectedTarget: String { settings.targetLanguage }

    func start() {
        guard panel == nil else { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: TranslationSessionView(host: self))
        panel.isReleasedWhenClosed = false
        panel.alphaValue = 0
        panel.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        // translationTask starts only for an appeared SwiftUI view. Keep this
        // transparent one-pixel host ordered in without showing user-facing UI.
        panel.orderFront(nil)
        self.panel = panel
    }

    func selectTarget(_ identifier: String) {
        guard identifier != settings.targetLanguage else { return }
        settings.targetLanguage = identifier
        configuration = Self.makeConfiguration(settings.languagePair)
    }

    func translate(_ text: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation.yield(Request(text: text, continuation: continuation))
        }
    }

    func serve(using session: TranslationSession) async {
        for await request in requests {
            do {
                let response = try await session.translate(request.text)
                request.continuation.resume(returning: response.targetText)
            } catch {
                request.continuation.resume(throwing: error)
            }
        }
    }

    private static func makeConfiguration(_ pair: LanguagePair) -> TranslationSession.Configuration {
        TranslationSession.Configuration(
            source: Locale.Language(identifier: pair.source),
            target: Locale.Language(identifier: pair.target)
        )
    }
}

@available(macOS 15.0, *)
private struct TranslationSessionView: View {
    @ObservedObject var host: AppleTranslationHost

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(host.configuration) { session in
                await host.serve(using: session)
            }
    }
}
