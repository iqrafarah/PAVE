import SwiftUI

/// Back in Meldingen after judging a verification request: what was done, for a moment, above the list.
struct NotificationResolvedBar: View {
    let message: String

    static let verified = "Je hebt het bewijs geverifieerd."
    static let rejected = "Je hebt de aanvraag afgewezen."

    var body: some View {
        HStack(spacing: 10) {
            Image(.iconCheckCircle)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(18)
                .foregroundStyle(Color.paveAccent)
                .accessibilityHidden(true)
            Text(message)
                .textStyle(.caption)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.panel, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder, lineWidth: 1) }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
        .onAppear { AccessibilityNotification.Announcement(message).post() }
    }
}

#Preview {
    NotificationResolvedBar(message: NotificationResolvedBar.verified)
}
