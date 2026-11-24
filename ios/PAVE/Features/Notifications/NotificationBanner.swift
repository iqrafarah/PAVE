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
                    .foregroundStyle(notification.kind.tint)
                    .frame(width: 18, height: 18)
                    .frame(width: 36, height: 36)
                    .background(notification.kind.surface, in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    // Who or what it is about; "Nieuwe melding" only when the server sent nothing to say.
                    Text(notification.detail.isEmpty ? "Nieuwe melding" : notification.detail)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
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

/// The banner as it arrives in the app: tap "Stuur melding" and it slides in over the screen, then leaves after 5 seconds.
#Preview("Banner · in de app") {
    @Previewable @State var banner: PaveNotification?
    @Previewable @State var next = 0
    // A fresh id each time, so the banner slides in again.
    let samples: [(Int) -> PaveNotification] = [
        { .init(id: "a\($0)", kind: .verifiedEvidence, title: "Bewijs geverifieerd", personName: "Fontys", date: .now, documentName: "Hbo-ICT propedeuse") },
        { .init(id: "b\($0)", kind: .rejectedEvidence, title: "Bewijs afgewezen", personName: "Albeda", date: .now, documentName: "Stage bij Rabobank") },
        { .init(id: "c\($0)", kind: .verificationRequest, title: "Verificatie aanvraag", personName: "Gianna Beenen", date: .now, learnerName: "Gianna Beenen", documentName: "Toets Nederlands grammatica") },
        { .init(id: "d\($0)", kind: .conversation, title: "Ik doe een cursus over design en wil dat in mijn kluis", personName: "Ayla", date: .now) },
    ]
    VStack(spacing: 12) {
        Spacer()
        Text("Hier staat het scherm waar je op dat moment bent.")
            .textStyle(.caption)
            .foregroundStyle(Color.inkMuted)
        Button("Stuur melding") {
            banner = samples[next % samples.count](next)
            next += 1
        }
        .buttonStyle(.borderedProminent)
        .tint(.paveAccent)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.canvas.ignoresSafeArea())
    .overlay(alignment: .top) {
        if let shown = banner {
            NotificationBanner(notification: shown) { banner = nil } onDismiss: { banner = nil }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    .animation(.snappy, value: banner?.id)
}

#Preview("Banner") {
    NotificationBanner(
        notification: .init(id: "1", kind: .verifiedEvidence, title: "Bewijs geverifieerd", personName: "Fontys", date: .now, documentName: "Hbo-ICT propedeuse"),
        onOpen: {}, onDismiss: {}
    )
    .padding()
    .background(Color.canvas)
}
