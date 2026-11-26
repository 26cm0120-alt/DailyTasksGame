import AppCore
import SwiftUI

enum GamePaletteColors {
    // パレット番号順。各行はダーク用とライト用のペア。
    private static let swatches: [(name: String, dark: UInt32, light: UInt32)] = [
        ("レッド",     0xF87171, 0xDC2626),
        ("オレンジ",   0xFB923C, 0xEA580C),
        ("アンバー",   0xFBBF24, 0xD97706),
        ("イエロー",   0xFACC15, 0xCA8A04),
        ("グリーン",   0x4ADE80, 0x16A34A),
        ("ティール",   0x2DD4BF, 0x0D9488),
        ("スカイ",     0x38BDF8, 0x0284C7),
        ("ブルー",     0x60A5FA, 0x2563EB),
        ("バイオレット", 0xA78BFA, 0x7C3AED),
        ("ピンク",     0xF472B6, 0xDB2777)
    ]

    static func name(at index: Int) -> String {
        swatches[GameColorPalette.clampedIndex(index)].name
    }

    static func color(at index: Int, scheme: ColorScheme) -> Color {
        let swatch = swatches[GameColorPalette.clampedIndex(index)]
        let rgb = scheme == .dark ? swatch.dark : swatch.light
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

struct GameColorPicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))]) {
            ForEach(0..<GameColorPalette.count, id: \.self) { index in
                Button {
                    selection = index
                } label: {
                    Circle()
                        .fill(GamePaletteColors.color(at: index, scheme: colorScheme))
                        .frame(width: 28, height: 28)
                        .padding(3)
                        .overlay {
                            if selection == index {
                                Circle().strokeBorder(Color.primary, lineWidth: 2)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(GamePaletteColors.name(at: index))
                .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
    }
}
