import SwiftUI

/// A skill you can add to the evidence: a plus while it is not added, a tick once it is (outline icons, as in Figma).
/// Ayla's proposals are dark green until you take them, so you see at once what came from her.
struct VaultSkillRow: View {
    enum Style { case vault, ayla }

    let name: String
    var detail: String?
    var style = Style.vault
    let isChosen: Bool
    let action: () -> Void

    private var isDark: Bool { style == .ayla && !isChosen }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .textStyle(.gapChip)
                        .foregroundStyle(isDark ? Color.white : .ink)
                        .lineLimit(2)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .textStyle(.meta)
                            .foregroundStyle(isDark ? Color.white.opacity(0.8) : .inkMuted)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                Image(isChosen ? .iconCheckCircleOutline : .iconPlusCircleOutline)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isDark ? Color.white : isChosen ? .paveAccent : .ink)
                    .contentTransition(.opacity)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 40)
            .background(background, in: .rect(cornerRadius: 6))
            .contentShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.pave)
        .animation(.snappy(duration: 0.25), value: isChosen)
        .accessibilityLabel(name)
        .accessibilityValue(detail ?? "")
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .accessibilityHint(isChosen ? "Tik om weg te halen" : "Tik om toe te voegen")
    }

    private var background: Color {
        if isDark { return .paveAccent }
        return isChosen ? .paveSurfaceTint : .tileFill
    }
}

#Preview {
    VStack(spacing: 6) {
        VaultSkillRow(name: "Front-end development", isChosen: true) {}
        VaultSkillRow(name: "Coaching", isChosen: false) {}
        VaultSkillRow(name: "Presenteren", detail: "Je gaf een eindpresentatie", style: .ayla, isChosen: false) {}
        VaultSkillRow(name: "Communicatie", style: .ayla, isChosen: true) {}
    }
    .padding(24)
}
