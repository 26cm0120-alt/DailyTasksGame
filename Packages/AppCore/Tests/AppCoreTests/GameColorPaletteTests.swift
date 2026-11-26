import AppCore
import Testing

struct GameColorPaletteTests {
    @Test func defaultIndexRotatesAtPaletteCount() {
        #expect(GameColorPalette.count == 10)
        #expect(GameColorPalette.defaultIndex(existingGameCount: 0) == 0)
        #expect(GameColorPalette.defaultIndex(existingGameCount: 9) == 9)
        #expect(GameColorPalette.defaultIndex(existingGameCount: 10) == 0)
        #expect(GameColorPalette.defaultIndex(existingGameCount: 11) == 1)
    }

    @Test func indexClampsToPaletteBounds() {
        #expect(GameColorPalette.clampedIndex(Int.min) == 0)
        #expect(GameColorPalette.clampedIndex(5) == 5)
        #expect(GameColorPalette.clampedIndex(9) == 9)
        #expect(GameColorPalette.clampedIndex(Int.max) == 9)
    }
}
