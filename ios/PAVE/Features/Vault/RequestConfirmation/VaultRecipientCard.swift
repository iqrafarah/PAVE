import SwiftUI

/// One choice of who confirms the evidence, such as "School of opleiding": a card with an icon, ticked like a radio button.
struct VaultRecipientCard: View {
    let recipient: VaultConfirmationRequest.Recipient
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            PaveHaptics.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(recipient.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isSelected ? Color.white : .paveAccent)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? Color.paveAccent : .paveDropZone, in: .rect(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(recipient.title)
                        .textStyle(.label)
                        .foregroundStyle(Color.ink)
                    Text(recipient.example)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Circle()
                    .strokeBorder(isSelected ? Color.paveAccent : .railBorder, lineWidth: isSelected ? 6 : 1.5)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(isSelected ? Color.paveDropZone : .white, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.paveFocusRing : .railBorder, lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.pave)
        .animation(.snappy(duration: 0.25), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    VStack(spacing: 10) {
        VaultRecipientCard(recipient: .school, isSelected: true) {}
        VaultRecipientCard(recipient: .employer, isSelected: false) {}
    }
    .padding(24)
}
