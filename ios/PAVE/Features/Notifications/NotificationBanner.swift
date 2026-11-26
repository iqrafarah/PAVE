import SwiftUI

/// A new melding while PAVE is open: a small card at the top that opens Meldingen when tapped and goes away by itself.
struct NotificationBanner: View {
    let notification: PaveNotification
    let onOpen: () -> Void
    let onDismiss: () -> Void

    private var isEmail: Bool { notification.kind == .email && !notification.emailPeople.isEmpty }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 11) {
                if isEmail {
                    // As in Messages: their photo, their name, and what they wrote.
                    EmailAvatarStack(people: notification.emailPeople, size: 38)
                } else {
                    Image(notification.kind.icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(notification.kind.tint)
                        .frame(width: 18, height: 18)
                        .frame(width: 36, height: 36)
                        .background(notification.kind.surface, in: .rect(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(isEmail ? notification.personName : notification.title)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if isEmail {
                            Text("nu").textStyle(.meta).foregroundStyle(Color.inkMuted)
                        }
                    }
                    if isEmail {
                        Text(notification.emailPreview ?? notification.title)
                            .textStyle(.caption)
                            .foregroundStyle(Color.ink)
                            .lineLimit(2)
                    } else {
                        // Who or what it is about; "Nieuwe melding" only when the server sent nothing to say.
                        Text(notification.detail.isEmpty ? "Nieuwe melding" : notification.detail)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(1)
                    }
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
        .accessibilityLabel(isEmail
            ? "Nieuw bericht van \(notification.personName): \(notification.emailPreview ?? notification.title)"
            : "Nieuwe melding: \(notification.title)")
        .accessibilityHint(isEmail ? "Opent het gesprek" : "Opent je meldingen")
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

extension AnyTransition {
    /// As iOS's own banners: the card grows out of the Dynamic Island (or the top edge on an iPhone without one) and
    /// shrinks back into it when it goes.
    static var fromIsland: AnyTransition {
        .modifier(active: IslandEmergence(progress: 0), identity: IslandEmergence(progress: 1))
    }
}

/// 0 is tucked into the island: narrow, flat, blurred and pulled up behind it; 1 is the card as it is.
private struct IslandEmergence: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 0.3 + 0.7 * progress, y: 0.15 + 0.85 * progress, anchor: .top)
            .offset(y: -28 * (1 - progress))
            .blur(radius: 10 * (1 - progress))
            .opacity(progress)
    }
}

/// The animation that goes with `fromIsland`: a short spring with a little bounce, as the island has.
extension Animation {
    static let island = Animation.spring(duration: 0.45, bounce: 0.28)
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
                .transition(.fromIsland)
        }
    }
    .animation(.island, value: banner?.id)
}

#Preview("Banner") {
    NotificationBanner(
        notification: .init(id: "1", kind: .verifiedEvidence, title: "Bewijs geverifieerd", personName: "Fontys", date: .now, documentName: "Hbo-ICT propedeuse"),
        onOpen: {}, onDismiss: {}
    )
    .padding()
    .background(Color.canvas)
}
