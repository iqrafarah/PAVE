import PAVECore
import SwiftUI

/// One choice in Weergave kluis or Tekstgrootte (Figma 1393:5359): an icon and a name; the chosen one has a tint and a
/// border in the accent colour.
struct SettingsOptionCard<Icon: View>: View {
    let title: String
    let isSelected: Bool
    @ViewBuilder let icon: Icon
    let action: () -> Void

    var body: some View {
        Button {
            PaveHaptics.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                icon
                    .foregroundStyle(Color.ink)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                Text(title)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isSelected ? Color.paveAccent.opacity(0.1) : .white, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.paveAccent : Color.cardBorder, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.pave)
        .animation(.snappy(duration: 0.2), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// The eight theme colours as dots; the chosen one gets a ring.
struct ThemeColorPicker: View {
    let selection: PaveThemeColor
    let onSelect: (PaveThemeColor) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52, maximum: 64), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(PaveThemeColor.allCases) { theme in
                Button {
                    PaveHaptics.selection()
                    onSelect(theme)
                } label: {
                    Circle()
                        .fill(Color(uiColor: UIColor(hex: theme.swatch)))
                        .padding(selection == theme ? 6 : 0)
                        .overlay {
                            if selection == theme {
                                Circle().strokeBorder(Color(uiColor: UIColor(hex: theme.accent)), lineWidth: 2)
                            }
                        }
                        .frame(width: 52, height: 52)
                        .contentShape(.circle)
                }
                .buttonStyle(.pave)
                .accessibilityLabel(SettingsMessages.title(theme))
                .accessibilityAddTraits(selection == theme ? [.isSelected] : [])
            }
        }
        .animation(.snappy(duration: 0.2), value: selection)
    }
}

/// Ayla's pixel A for a text size: smaller for Klein, larger for Groot.
struct TextSizeGlyph: View {
    let size: PaveTextSize

    var body: some View {
        AylaLetter(color: .ink)
            .scaleEffect(size == .small ? 0.7 : size == .standard ? 1 : 1.35)
            .frame(width: 24, height: 24)
    }
}
