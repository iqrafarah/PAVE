import SwiftUI

/// A skill you can add to the evidence: a plus while it is not added, a green tick once it is.
struct VaultSkillRow: View {
    let name: String
    let isChosen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(name)
                    .textStyle(.gapChip)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(isChosen ? .iconCheckCircleSolid : .iconPlusCircleSolid)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isChosen ? Color.brandGreen : .inkMuted)
                    .contentTransition(.opacity)
                    .scaleEffect(isChosen ? 1 : 0.92)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background(isChosen ? Color.surfaceTint : .tileFill, in: .rect(cornerRadius: 6))
            .contentShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.pave)
        .animation(.snappy(duration: 0.25), value: isChosen)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .accessibilityHint(isChosen ? "Tik om weg te halen" : "Tik om toe te voegen")
    }
}

#Preview {
    VStack(spacing: 6) {
        VaultSkillRow(name: "Front-end development", isChosen: true) {}
        VaultSkillRow(name: "Coaching", isChosen: false) {}
    }
    .padding(24)
}
