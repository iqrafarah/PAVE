import SwiftUI

/// A new melding while PAVE is open: a small card at the top that opens Meldingen when tapped and goes away by itself.
struct NotificationBanner: View {
    let notification: PaveNotification
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 11) {
                Image(notification.kind.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.paveAccent)
                    .frame(width: 18, height: 18)
                    .frame(width: 36, height: 36)
                    .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Text("Nieuwe melding")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: 420)
            .background(Color.panel, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.pave)
        .accessibilityLabel("Nieuwe melding: \(notification.title)")
        .accessibilityHint("Opent je meldingen")
        .accessibilityAction(named: "Sluiten", onDismiss)
        .gesture(DragGesture(minimumDistance: 12).onEnded { value in
            if value.translation.height < -10 { onDismiss() }
        })
        .task(id: notification.id) {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }
}

#Preview {
    NotificationBanner(
        notification: .init(id: "1", kind: .verifiedEvidence, title: "Bewijs geverifieerd", personName: "Fontys", date: .now),
        onOpen: {}, onDismiss: {}
    )
    .padding()
    .background(Color.canvas)
}
