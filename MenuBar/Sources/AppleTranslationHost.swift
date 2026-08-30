import SwiftUI
@preconcurrency import Translation
import DualTyperCore

@available(macOS 15.0, *)
enum AppleTranslationHostError: LocalizedError {
    case sessionUnavailable

    var errorDescription: String? {
        switch self {
        case .sessionUnavailable:
            return "Translation engine is not active. Keep the DualTyper setup window open or minimized, then try again."
        }
    }
}

@available(macOS 15.0, *)
@MainActor
final class AppleTranslationHost: ObservableObject {
    static let shared = AppleTranslationHost()

    @Published private(set) var configuration: TranslationSession.Configuration?
    @Published private(set) var sessionAvailable = false

    private let settings = UserDefaultsLanguageSettings()
    private var coordinator = TranslationRequestCoordinator()
    private var lifecycle = TranslationSessionLifecycle()

    private init() {
        configuration = Self.makeConfiguration(settings.languagePair)
    }

    var selectedTarget: String { settings.targetLanguage }

    func selectTarget(_ identifier: String) async {
        guard identifier != settings.targetLanguage else { return }

        settings.targetLanguage = identifier
        await replaceSession()
    }

    func translate(_ text: String) async throws -> String {
        guard sessionAvailable else {
            throw AppleTranslationHostError.sessionUnavailable
        }

        do {
            return try await coordinator.request(text: text, timeout: .seconds(120))
        } catch {
            let interruption: TranslationSessionInterruption
            if error is CancellationError {
                interruption = .cancelled
            } else if let coordinatorError = error as? TranslationRequestCoordinatorError {
                switch coordinatorError {
                case .timedOut:
                    interruption = .timedOut
                case .invalidated:
                    interruption = .invalidated
                }
            } else {
                interruption = .translationFailure
            }

            if TranslationSessionRecoveryPolicy.shouldReset(after: interruption) {
                await replaceSession()
            }
            throw error
        }
    }

    func serve(using session: TranslationSession) async {
        let sessionID = UUID()
        let activeCoordinator = coordinator
        lifecycle.begin(sessionID)
        sessionAvailable = true

        defer {
            lifecycle.end(sessionID)
            sessionAvailable = lifecycle.isAvailable
        }

        for await request in activeCoordinator.workItems {
            guard !Task.isCancelled else {
                await activeCoordinator.fail(id: request.id, error: CancellationError())
                return
            }

            do {
                let response = try await session.translate(request.text)
                await activeCoordinator.succeed(
                    id: request.id,
                    translation: response.targetText
                )
            } catch {
                await activeCoordinator.fail(id: request.id, error: error)
            }
        }
    }

    private static func makeConfiguration(_ pair: LanguagePair) -> TranslationSession.Configuration {
        TranslationSession.Configuration(
            source: pair.source.map(Locale.Language.init(identifier:)),
            target: Locale.Language(identifier: pair.target)
        )
    }

    private func replaceSession() async {
        let previousCoordinator = coordinator

        if var staleConfiguration = configuration {
            staleConfiguration.invalidate()
            configuration = staleConfiguration
        }
        configuration = nil
        sessionAvailable = false
        coordinator = TranslationRequestCoordinator()
        lifecycle = TranslationSessionLifecycle()

        await previousCoordinator.invalidateAll()
        await Task.yield()
        configuration = Self.makeConfiguration(settings.languagePair)
    }
}

@available(macOS 15.0, *)
struct TranslationSessionHostModifier: ViewModifier {
    @ObservedObject var host: AppleTranslationHost

    func body(content: Content) -> some View {
        content.translationTask(host.configuration) { session in
            await host.serve(using: session)
        }
    }
}
