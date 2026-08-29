import Testing
@testable import DualTyperCore

@Suite("Sentence accumulator")
struct SentenceAccumulatorTests {
    @Test("commits an English sentence after terminal punctuation")
    func commitsAfterEnglishPunctuation() {
        var accumulator = SentenceAccumulator()

        #expect(accumulator.receive("Hello world") == [])
        #expect(accumulator.receive(".") == [CompletedSentence(text: "Hello world.", trigger: .punctuation)])
        #expect(accumulator.pendingText.isEmpty)
    }

    @Test("commits a CJK sentence after terminal punctuation")
    func commitsAfterCJKPunctuation() {
        var accumulator = SentenceAccumulator()

        #expect(accumulator.receive("你好世界。") == [CompletedSentence(text: "你好世界。", trigger: .punctuation)])
    }

    @Test("commits unfinished text when Return is pressed")
    func commitsOnReturn() {
        var accumulator = SentenceAccumulator()

        #expect(accumulator.receive("How are you") == [])
        #expect(accumulator.receive("\n") == [CompletedSentence(text: "How are you", trigger: .returnKey)])
    }

    @Test("ignores an empty sentence")
    func ignoresEmptySentence() {
        var accumulator = SentenceAccumulator()

        #expect(accumulator.receive(" \n") == [])
    }

    @Test("handles multiple sentences in one input chunk")
    func handlesMultipleSentences() {
        var accumulator = SentenceAccumulator()

        #expect(accumulator.receive("Hello! How are you? Remaining") == [
            CompletedSentence(text: "Hello!", trigger: .punctuation),
            CompletedSentence(text: "How are you?", trigger: .punctuation)
        ])
        #expect(accumulator.pendingText == " Remaining")
    }
}

@Suite("Bilingual insertion formatter")
struct BilingualInsertionFormatterTests {
    @Test("punctuation puts the translation on its own line and leaves a new typing line")
    func formatsPunctuationCommit() {
        let insertion = BilingualInsertionFormatter.insertion(
            translation: "你好，世界。",
            trigger: .punctuation
        )

        #expect(insertion == "\n你好，世界。\n")
    }

    @Test("Return uses the line already inserted by the host application")
    func formatsReturnCommit() {
        let insertion = BilingualInsertionFormatter.insertion(
            translation: "你好吗？",
            trigger: .returnKey
        )

        #expect(insertion == "你好吗？\n")
    }
}

@Suite("Language settings")
struct LanguageSettingsTests {
    @Test("defaults to automatic source detection and Spanish target")
    func defaults() {
        let store = InMemoryLanguageSettings()

        #expect(store.languagePair == LanguagePair(source: nil, target: "es"))
    }

    @Test("persists a selected target language")
    func selection() {
        let store = InMemoryLanguageSettings()

        store.targetLanguage = "ja"

        #expect(store.languagePair == LanguagePair(source: nil, target: "ja"))
    }
}

@Suite("Translation completion")
struct TranslationCompletionTests {
    @Test("translation failure commits the original and leaves a new line")
    func failureFallback() {
        let sentence = CompletedSentence(text: "Hello.", trigger: .punctuation)

        #expect(TranslationCompletion.failureInsertion(for: sentence) == "\n")
    }

    @Test("Return failure does not add a second blank line")
    func returnFailureDoesNotAddBlankLine() {
        let sentence = CompletedSentence(text: "Hello", trigger: .returnKey)

        #expect(TranslationCompletion.failureInsertion(for: sentence) == "")
    }

    @Test("committed original text preserves exact whitespace")
    func originalTextPreservesWhitespace() {
        #expect(TranslationCompletion.originalInsertion(originalText: "  Hello. ", trigger: .punctuation) == "  Hello. ")
        #expect(TranslationCompletion.originalInsertion(originalText: "  Hello  ", trigger: .returnKey) == "  Hello  \n")
    }
}

@Suite("Translation input gate")
struct TranslationInputGateTests {
    @Test("blocks another translation until output order is safe")
    func blocksWhileBusy() {
        var gate = TranslationInputGate()

        let first = gate.beginTranslation()
        let second = gate.beginTranslation()
        gate.finishTranslation()
        let third = gate.beginTranslation()

        #expect(first)
        #expect(!second)
        #expect(third)
    }
}

@Suite("Input handling policy")
struct InputHandlingPolicyTests {
    @Test("empty Return passes through to the host application")
    func emptyReturnPassesThrough() {
        #expect(!InputHandlingPolicy.shouldConsumeReturn(bufferedText: ""))
        #expect(!InputHandlingPolicy.shouldConsumeReturn(bufferedText: "  \t"))
        #expect(InputHandlingPolicy.shouldConsumeReturn(bufferedText: "Hello"))
    }

    @Test("navigation and control characters pass through to the host")
    func navigationCharactersPassThrough() {
        #expect(InputHandlingPolicy.shouldConsumeCharacters("a"))
        #expect(InputHandlingPolicy.shouldConsumeCharacters("你"))
        #expect(InputHandlingPolicy.shouldConsumeCharacters("مرحبا"))
        #expect(InputHandlingPolicy.shouldConsumeCharacters("👩🏽‍💻"))
        #expect(!InputHandlingPolicy.shouldConsumeCharacters(""))
        #expect(!InputHandlingPolicy.shouldConsumeCharacters("\t"))
        #expect(!InputHandlingPolicy.shouldConsumeCharacters("\u{001B}"))
        #expect(!InputHandlingPolicy.shouldConsumeCharacters("\u{F700}"))
        #expect(!InputHandlingPolicy.shouldConsumeCharacters("a\u{F703}"))
    }

    @Test("a chunk with multiple completed sentences passes through intact")
    func multiSentenceChunkPassesThrough() {
        #expect(InputHandlingPolicy.shouldConsumeChunk(completedSentenceCount: 0, hasPendingSuffix: true))
        #expect(InputHandlingPolicy.shouldConsumeChunk(completedSentenceCount: 1, hasPendingSuffix: false))
        #expect(!InputHandlingPolicy.shouldConsumeChunk(completedSentenceCount: 1, hasPendingSuffix: true))
        #expect(!InputHandlingPolicy.shouldConsumeChunk(completedSentenceCount: 2, hasPendingSuffix: false))
    }
}
