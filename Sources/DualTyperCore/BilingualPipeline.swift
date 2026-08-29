public protocol TextTranslator: Sendable {
    func translate(_ text: String) async throws -> String
}

public struct BilingualPipeline: Sendable {
    public init() {}

    public func insertion(
        for sentence: CompletedSentence,
        translator: any TextTranslator
    ) async throws -> String {
        let translation = try await translator.translate(sentence.text)
        return BilingualInsertionFormatter.insertion(
            translation: translation,
            trigger: sentence.trigger
        )
    }
}
