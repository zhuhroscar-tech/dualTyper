import Foundation
import Testing
import os
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

@Suite("Selection translation plan")
struct SelectionTranslationPlanTests {
    @Test("preserves the selected source exactly and adds translation beneath it")
    func preservesSourceExactly() {
        let replacement = SelectionTranslationPlan.replacement(
            source: "  Hello, how are you?  ",
            translation: "你好，你好吗？"
        )

        #expect(replacement == "  Hello, how are you?  \n你好，你好吗？")
    }

    @Test("rejects empty selected text")
    func rejectsEmptySelection() {
        #expect(SelectionTranslationPlan.isValidSource("") == false)
        #expect(SelectionTranslationPlan.isValidSource(" \n\t") == false)
        #expect(SelectionTranslationPlan.isValidSource("Hello") == true)
    }
}

@Suite("Selection translation guard")
struct SelectionTranslationGuardTests {
    private let original = TranslationSelectionSnapshot(
        processIdentifier: 42,
        selectedText: "Hello.",
        location: 10,
        length: 6
    )

    @Test("allows insertion only when app text and range are unchanged")
    func acceptsUnchangedSelection() {
        #expect(SelectionTranslationGuard.canApply(original: original, current: original))
    }

    @Test("rejects a different frontmost application")
    func rejectsDifferentApplication() {
        let current = TranslationSelectionSnapshot(
            processIdentifier: 99,
            selectedText: "Hello.",
            location: 10,
            length: 6
        )

        #expect(!SelectionTranslationGuard.canApply(original: original, current: current))
    }

    @Test("rejects changed text or selection range")
    func rejectsChangedSelection() {
        let changedText = TranslationSelectionSnapshot(
            processIdentifier: 42,
            selectedText: "Goodbye.",
            location: 10,
            length: 8
        )
        let changedRange = TranslationSelectionSnapshot(
            processIdentifier: 42,
            selectedText: "Hello.",
            location: 11,
            length: 6
        )

        #expect(!SelectionTranslationGuard.canApply(original: original, current: changedText))
        #expect(!SelectionTranslationGuard.canApply(original: original, current: changedRange))
    }
}

@Suite("Translation session recovery policy")
struct TranslationSessionRecoveryPolicyTests {
    @Test("resets after timeout or caller cancellation")
    func resetsInterruptedSessions() {
        #expect(TranslationSessionRecoveryPolicy.shouldReset(after: .timedOut))
        #expect(TranslationSessionRecoveryPolicy.shouldReset(after: .cancelled))
    }

    @Test("does not reset for invalidation or a normal translation error")
    func keepsHealthySessions() {
        #expect(!TranslationSessionRecoveryPolicy.shouldReset(after: .invalidated))
        #expect(!TranslationSessionRecoveryPolicy.shouldReset(after: .translationFailure))
    }
}

@Suite("Window presentation retry policy")
struct WindowPresentationRetryPolicyTests {
    @Test("retries until the setup window exists")
    func retriesWhileMissing() {
        #expect(WindowPresentationRetryPolicy.shouldRetry(attempt: 0, windowFound: false))
        #expect(WindowPresentationRetryPolicy.shouldRetry(attempt: 9, windowFound: false))
    }

    @Test("stops when found or retry budget is exhausted")
    func stopsAppropriately() {
        #expect(!WindowPresentationRetryPolicy.shouldRetry(attempt: 0, windowFound: true))
        #expect(!WindowPresentationRetryPolicy.shouldRetry(attempt: 10, windowFound: false))
    }
}

@Suite("Translation session lifecycle")
struct TranslationSessionLifecycleTests {
    @Test("requires a live session")
    func requiresLiveSession() {
        var state = TranslationSessionLifecycle()
        let session = UUID()

        #expect(!state.isAvailable)
        state.begin(session)
        #expect(state.isAvailable)
        state.end(session)
        #expect(!state.isAvailable)
    }

    @Test("ending a stale session does not deactivate its replacement")
    func ignoresStaleSessionEnd() {
        var state = TranslationSessionLifecycle()
        let oldSession = UUID()
        let newSession = UUID()

        state.begin(oldSession)
        state.begin(newSession)
        state.end(oldSession)

        #expect(state.isAvailable)
        #expect(state.activeSession == newSession)
    }
}

@Suite("Thread-safe callback relay")
struct SendableCallbackRelayTests {
    @Test("invokes the current callback and stops after clear")
    func invokesAndClears() {
        let relay = SendableCallbackRelay()
        let state = OSAllocatedUnfairLock(initialState: 0)

        relay.set {
            state.withLock { value in value += 1 }
        }
        relay.invoke()
        relay.clear()
        relay.invoke()

        #expect(state.withLock { $0 } == 1)
    }
}

@Suite("Text control security policy")
struct TextControlSecurityPolicyTests {
    @Test("rejects the macOS secure text-field subrole")
    func rejectsSecureTextField() {
        #expect(TextControlSecurityPolicy.isSecure(subrole: "AXSecureTextField"))
    }

    @Test("allows ordinary and unavailable subroles")
    func allowsOrdinaryTextFields() {
        #expect(!TextControlSecurityPolicy.isSecure(subrole: "AXStandardTextField"))
        #expect(!TextControlSecurityPolicy.isSecure(subrole: nil))
    }
}

@Suite("Translation request coordinator")
struct TranslationRequestCoordinatorTests {
    @Test("delivers work and resumes its requester")
    func completesRequest() async throws {
        let coordinator = TranslationRequestCoordinator()
        let resultTask = Task {
            try await coordinator.request(text: "Hello", timeout: .seconds(1))
        }

        var iterator = coordinator.workItems.makeAsyncIterator()
        let item = await iterator.next()
        #expect(item?.text == "Hello")

        if let item {
            await coordinator.succeed(id: item.id, translation: "Hola")
        }
        #expect(try await resultTask.value == "Hola")
    }

    @Test("times out when no translation session serves the request")
    func timesOutRequest() async {
        let coordinator = TranslationRequestCoordinator()

        do {
            _ = try await coordinator.request(text: "Hello", timeout: .milliseconds(20))
            Issue.record("Expected the request to time out")
        } catch let error as TranslationRequestCoordinatorError {
            #expect(error == .timedOut)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("invalidating a language session resumes all waiters")
    func invalidatesWaiters() async {
        let coordinator = TranslationRequestCoordinator()
        let resultTask = Task {
            try await coordinator.request(text: "Hello", timeout: .seconds(1))
        }

        var iterator = coordinator.workItems.makeAsyncIterator()
        _ = await iterator.next()
        await coordinator.invalidateAll()

        do {
            _ = try await resultTask.value
            Issue.record("Expected invalidation")
        } catch let error as TranslationRequestCoordinatorError {
            #expect(error == .invalidated)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
