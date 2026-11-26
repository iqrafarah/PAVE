import PAVECore
import SwiftUI

/// Under the QR code of Snel delen: waiting, then the moment someone opened it, with a tap on the wrist or in the hand.
struct QuickShareLookStatus: View {
    let share: ProfileShare

    @Environment(\.paveReduceMotion) private var reduceMotion
    @State private var pulses = false

    private var latest: ShareLook? { share.looks.max { $0.date < $1.date } }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(latest == nil ? Color.inkMuted : Color.paveAccent)
                .frame(width: 8, height: 8)
                .scaleEffect(pulses && latest == nil ? 1.5 : 1)
                .opacity(pulses && latest == nil ? 0.4 : 1)
                .accessibilityHidden(true)
            Text(latest.map { SharingMessages.quickShareLooked($0.date, by: $0.viewerName) } ?? SharingMessages.quickShareWaiting)
                .textStyle(.bodyMedium)
                .foregroundStyle(latest == nil ? Color.inkMuted : Color.ink)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 40)
        // As round as a pill on one line, a calm card when a long name takes more.
        .background(latest == nil ? Color.panel : Color.paveSurfaceTint, in: .rect(cornerRadius: 20))
        .animation(.spring(duration: 0.4, bounce: 0.2), value: share.looks.count)
        .sensoryFeedback(.success, trigger: share.looks.count)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulses = true }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        QuickShareLookStatus(share: ProfileShare(id: "a", code: "", title: "Snel", recipientName: "Snel gedeeld", template: .employer, content: ShareContent(profile: ShareProfile(name: "Ravi")), expiresAt: .now.addingTimeInterval(86_400)))
        QuickShareLookStatus(share: ProfileShare(id: "b", code: "", title: "Snel", recipientName: "Snel gedeeld", template: .employer, content: ShareContent(profile: ShareProfile(name: "Ravi")), expiresAt: .now.addingTimeInterval(86_400), looks: [ShareLook(id: "l", date: .now, action: .view, viewerName: "Sanne de Vries")]))
    }
    .padding()
    .background(Color.canvas)
}
