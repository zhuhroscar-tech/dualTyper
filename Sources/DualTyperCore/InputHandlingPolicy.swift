public enum InputHandlingPolicy {
    public static func shouldConsumeReturn(bufferedText: String) -> Bool {
        bufferedText.contains { !$0.isWhitespace }
    }

    public static func shouldConsumeCharacters(_ characters: String) -> Bool {
        !characters.isEmpty && characters.unicodeScalars.allSatisfy { scalar in
            scalar.properties.generalCategory != .control
                && !(0xF700...0xF8FF).contains(scalar.value)
        }
    }

    public static func shouldConsumeChunk(
        completedSentenceCount: Int,
        hasPendingSuffix: Bool
    ) -> Bool {
        completedSentenceCount == 0 || (completedSentenceCount == 1 && !hasPendingSuffix)
    }
}
