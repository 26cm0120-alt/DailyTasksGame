public enum GameColorPalette {
    public static let count = 10

    public static func clampedIndex(_ index: Int) -> Int {
        min(max(index, 0), count - 1)
    }

    public static func defaultIndex(existingGameCount: Int) -> Int {
        max(existingGameCount, 0) % count
    }
}
