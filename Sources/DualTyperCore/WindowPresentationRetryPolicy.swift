public enum WindowPresentationRetryPolicy {
    public static func shouldRetry(
        attempt: Int,
        windowFound: Bool,
        maximumAttempts: Int = 10
    ) -> Bool {
        !windowFound && attempt < maximumAttempts
    }
}
