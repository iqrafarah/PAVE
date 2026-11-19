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
                    .paveIconFrame(24)
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
            .background(isSelected ? Color.paveAccent.opacity(0.1) : Color.panel, in: .rect(cornerRadius: 14))
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

/// The theme colours as dots in one row that scrolls, like the folders in the vault; the chosen one gets a ring. The
/// last dot is a colour wheel for a colour of your own.
struct ThemeColorPicker: View {
    let selection: PaveThemeColor
    let customColor: UInt32?
    let onSelect: (PaveThemeColor) -> Void
    let onCustomColor: (UInt32) -> Void
    let onCustomColorDone: () -> Void

    @State private var picksOwnColor = false

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(PaveThemeColor.presets) { theme in
                    Button {
                        PaveHaptics.selection()
                        onSelect(theme)
                    } label: {
                        dot(fill: Color(uiColor: UIColor(hex: theme.swatch)), ring: Color(uiColor: UIColor(hex: theme.accent)), isSelected: selection == theme)
                    }
                    .buttonStyle(.pave)
                    .accessibilityLabel(SettingsMessages.title(theme))
                    .accessibilityAddTraits(selection == theme ? [.isSelected] : [])
                }
                ownColorButton
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 12, for: .scrollContent)
        .padding(.horizontal, -12)
        .animation(.snappy(duration: 0.2), value: selection)
        .sheet(isPresented: $picksOwnColor, onDismiss: onCustomColorDone) {
            OwnColorPicker(initial: customColor ?? PaveThemeColor.green.swatch, title: SettingsMessages.customColorHint, onChange: onCustomColor) {
                picksOwnColor = false
            }
            .presentationDetents([.medium, .large])
            .ignoresSafeArea()
        }
    }

    private var ownColorButton: some View {
        let isSelected = selection == .custom
        return Button {
            PaveHaptics.selection()
            picksOwnColor = true
        } label: {
            ZStack {
                Circle().fill(AngularGradient.colorWheel)
                Circle().fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: 24))
                if isSelected, let customColor {
                    Circle()
                        .fill(Color(uiColor: UIColor(hex: customColor)))
                        .padding(8)
                        .overlay {
                            Circle().strokeBorder(.white, lineWidth: 2).padding(8)
                        }
                }
            }
            .frame(width: 52, height: 52)
            .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(SettingsMessages.title(PaveThemeColor.custom))
        .accessibilityHint(SettingsMessages.customColorHint)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func dot(fill: Color, ring: Color, isSelected: Bool) -> some View {
        Circle()
            .fill(fill)
            .padding(isSelected ? 6 : 0)
            .overlay {
                if isSelected {
                    Circle().strokeBorder(ring, lineWidth: 2)
                }
            }
            .frame(width: 52, height: 52)
            .contentShape(.circle)
    }
}

/// Ayla's pixel A for a text size: smaller for Klein, larger for Groot.
struct TextSizeGlyph: View {
    let size: PaveTextSize

    var body: some View {
        AylaLetter(color: .ink)
            .paveIconScale()
            .scaleEffect(size == .small ? 0.7 : size == .standard ? 1 : 1.35)
            .paveIconFrame(24)
    }
}
