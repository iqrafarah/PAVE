import PAVECore
import SwiftUI

/// How a project shows (web projectLook): its own icon and colour, or the folder in the theme colour.
extension AylaProject {
    var iconImage: ImageResource { (icon ?? .folder).solidImage }
    var tint: Color { color?.color ?? .paveAccent }
    var tintSurface: Color { color?.surface ?? .paveSurfaceTint }
}

/// The icon of a project in a round tile of its colour, as on top of its page and in the chip of a new chat.
struct AylaProjectBadge: View {
    let project: AylaProject
    var size: CGFloat = 44

    var body: some View {
        Image(project.iconImage)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .paveIconFrame(size * 0.48)
            .foregroundStyle(project.tint)
            .frame(width: size, height: size)
            .background(project.tintSurface, in: .circle)
            .accessibilityHidden(true)
    }
}

/// Choosing a colour and an icon, from the same set as the vault folders. Used for projects; the selected icon shows in
/// the chosen colour.
struct AylaLookPicker: View {
    @Binding var icon: VaultFolderIcon?
    @Binding var color: VaultFolderColor?
    @State private var picksOwnColor = false
    @State private var ownColor: UInt32?

    private var shownColor: VaultFolderColor? { color }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Kleur")
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
                HStack(spacing: 0) {
                    themeButton
                        .frame(maxWidth: .infinity)
                    ForEach(VaultFolderColor.presets.filter { $0 != .green }, id: \.self) { option in
                        colorButton(option)
                            .frame(maxWidth: .infinity)
                    }
                    ownColorButton
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Icoon")
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 64), spacing: 8)], spacing: 8) {
                    ForEach(VaultFolderIcon.allCases, id: \.self) { option in
                        iconButton(option)
                    }
                }
            }
        }
        .onAppear { if case .custom(let hex) = color { ownColor = hex } }
        .sheet(isPresented: $picksOwnColor) {
            OwnColorPicker(initial: ownColor ?? 0xC2410C, title: VaultMessages.ownFolderColor) { hex in
                ownColor = hex
                color = .custom(hex)
            } onFinish: {
                picksOwnColor = false
            }
            .presentationDetents([.medium, .large])
            .ignoresSafeArea()
        }
    }

    /// No colour of its own: the project follows the theme colour of Instellingen.
    private var themeButton: some View {
        let isOn = color == nil
        return Button {
            color = nil
            PaveHaptics.selection()
        } label: {
            Circle()
                .fill(Color.paveAccentFill)
                .padding(4)
                .overlay { Circle().strokeBorder(isOn ? Color.paveAccent : .clear, lineWidth: 2) }
                .frame(minWidth: 28, maxWidth: 44)
                .aspectRatio(1, contentMode: .fit)
                .frame(minHeight: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .accessibilityLabel("Themakleur")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func colorButton(_ option: VaultFolderColor) -> some View {
        let isOn = option == color
        return Button {
            color = option
            PaveHaptics.selection()
        } label: {
            Circle()
                .fill(option.color)
                .padding(4)
                .overlay { Circle().strokeBorder(isOn ? option.color : .clear, lineWidth: 2) }
                .frame(minWidth: 28, maxWidth: 44)
                .aspectRatio(1, contentMode: .fit)
                .frame(minHeight: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var ownColorButton: some View {
        let isOn = color?.isCustom == true
        return Button {
            PaveHaptics.selection()
            if let ownColor, !isOn { color = .custom(ownColor) } else { picksOwnColor = true }
        } label: {
            ZStack {
                if isOn, let ownColor {
                    Circle().fill(Color(uiColor: UIColor(hex: ownColor)))
                } else {
                    Circle().fill(AngularGradient.colorWheel)
                }
            }
            .padding(4)
            .overlay { Circle().strokeBorder(isOn ? (color?.color ?? .clear) : .clear, lineWidth: 2) }
            .frame(minWidth: 28, maxWidth: 44)
            .aspectRatio(1, contentMode: .fit)
            .frame(minHeight: 44)
            .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(VaultMessages.ownFolderColor)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func iconButton(_ option: VaultFolderIcon) -> some View {
        let isOn = option == (icon ?? .folder)
        let tint = color?.color ?? .paveAccentFill
        let onTint = color?.foreground ?? .white
        return Button {
            icon = option == .folder ? nil : option
            PaveHaptics.selection()
        } label: {
            Image(option.solidImage)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(20)
                .foregroundStyle(isOn ? onTint : Color.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isOn ? tint : Color.paveSurfaceTint, in: .rect(cornerRadius: 10))
                .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.pave)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
