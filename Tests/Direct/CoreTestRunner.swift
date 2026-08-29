private var failures = 0

private func expect<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    guard actual != expected else { return }
    failures += 1
    print("FAIL: \(message)\n  expected: \(expected)\n  actual:   \(actual)")
}

@main
struct CoreTestRunner {
    static func main() async {
        var english = SentenceAccumulator()
        expect(english.receive("Hello world"), [], "partial sentence stays buffered")
        expect(
            english.receive("."),
            [CompletedSentence(text: "Hello world.", trigger: .punctuation)],
            "English punctuation commits a sentence"
        )
        expect(english.pendingText, "", "buffer clears after commit")

        var cjk = SentenceAccumulator()
        expect(
            cjk.receive("你好世界。"),
            [CompletedSentence(text: "你好世界。", trigger: .punctuation)],
            "CJK punctuation commits a sentence"
        )

        var returnKey = SentenceAccumulator()
        _ = returnKey.receive("How are you")
        expect(
            returnKey.receive("\n"),
            [CompletedSentence(text: "How are you", trigger: .returnKey)],
            "Return commits unfinished text"
        )

        var empty = SentenceAccumulator()
        expect(empty.receive(" \n"), [], "empty sentences are ignored")

        expect(InputHandlingPolicy.shouldConsumeReturn(bufferedText: "  \t"), false, "whitespace-only Return passes through")
        expect(InputHandlingPolicy.shouldConsumeCharacters("مرحبا"), true, "multilingual text is consumed")
        expect(InputHandlingPolicy.shouldConsumeCharacters("👩🏽‍💻"), true, "emoji text is consumed")
        expect(InputHandlingPolicy.shouldConsumeCharacters("\t"), false, "Tab passes through")
        expect(InputHandlingPolicy.shouldConsumeCharacters("\u{001B}"), false, "control characters pass through")
        expect(InputHandlingPolicy.shouldConsumeCharacters("\u{F700}"), false, "function keys pass through")

        var multiple = SentenceAccumulator()
        expect(
            multiple.receive("Hello! How are you? Remaining"),
            [
                CompletedSentence(text: "Hello!", trigger: .punctuation),
                CompletedSentence(text: "How are you?", trigger: .punctuation)
            ],
            "multiple sentences in one chunk are committed"
        )
        expect(multiple.pendingText, " Remaining", "unfinished suffix remains buffered")

        expect(
            BilingualInsertionFormatter.insertion(
                translation: "你好，世界。",
                trigger: .punctuation
            ),
            "\n你好，世界。\n",
            "punctuation translation gets its own line"
        )
        expect(
            BilingualInsertionFormatter.insertion(
                translation: "你好吗？",
                trigger: .returnKey
            ),
            "你好吗？\n",
            "Return translation uses the host-created line"
        )

        let pipeline = BilingualPipeline()
        do {
            let insertion = try await pipeline.insertion(
                for: CompletedSentence(text: "Hello.", trigger: .punctuation),
                translator: StubTranslator(result: "你好。")
            )
            expect(insertion, "\n你好。\n", "pipeline translates then formats the insertion")
        } catch {
            failures += 1
            print("FAIL: pipeline unexpectedly threw \(error)")
        }

        if failures == 0 {
            print("All DualTyperCore direct tests passed")
        } else {
            fatalError("\(failures) DualTyperCore direct test(s) failed")
        }
    }
}

private struct StubTranslator: TextTranslator {
    let result: String

    func translate(_ text: String) async throws -> String {
        result
    }
}
