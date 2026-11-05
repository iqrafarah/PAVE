import SwiftUI

/// A white card in the conversation that opens a panel, like "2 gegevens geselecteerd" in Figma.
struct ChatAttachmentCard: View {
    let icon: ImageResource
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.brandGreen)
                    .frame(width: 23, height: 27)
                    .frame(width: 58, height: 58)
                    .background(Color.surfaceTint, in: .rect(cornerRadius: 12))
                    .accessibilityHidden(true)
                Text(title)
                    .textStyle(.bubble)
                    .foregroundStyle(Color.ink)
                    .padding(.leading, 21)
                Spacer(minLength: 12)
                Image(.iconChevronRight)
                    .accessibilityHidden(true)
                    .padding(.trailing, 27)
            }
            .padding(.leading, 9)
            .frame(maxWidth: .infinity, minHeight: 75, alignment: .leading)
            .background(Color.white, in: .rect(cornerRadius: 18))
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        ChatAttachmentCard(icon: .iconDatabase, title: "2 gegevens geselecteerd") {}
        ChatAttachmentCard(icon: .iconBriefcase, title: "3 vacatures gevonden") {}
    }
    .padding(.leading, 32)
    .padding(.trailing, 33)
    .background(Color.canvas)
}
