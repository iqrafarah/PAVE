import SwiftUI

/// "Aa" in one of the typefaces, so you see what you choose before you choose it.
struct FontStyleGlyph: View {
    let style: PaveFontStyle

    var body: some View {
        Text("Aa")
            .font(font)
            .foregroundStyle(Color.ink)
            .frame(width: 30, height: 24)
            .accessibilityHidden(true)
    }

    private var font: Font {
        switch style {
        case .pave: .custom("Sora-Regular_SemiBold", fixedSize: 17)
        case .system: .system(size: 17, weight: .semibold)
        case .rounded: .system(size: 17, weight: .semibold, design: .rounded)
        case .serif: .system(size: 17, weight: .semibold, design: .serif)
        case .readable: .custom(PaveFontStyle.readableBold, fixedSize: 17)
        }
    }
}
