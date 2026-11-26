import SwiftUI

/// The moment a fair's QR code is recognised: a ring draws round, a tick lands with a tap you feel, and the employer's
/// name and stand appear as soon as they are loaded. Without motion it is shown at once.
struct FairFoundView: View {
    /// Nil while the employer is still loading.
    let name: String?
    var stand: String?

    @State private var progress: CGFloat = 0
    @State private var landed = false
    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.paveAccent.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.paveAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(.iconCheck)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(Color.paveAccent)
                    .scaleEffect(landed ? 1 : 0.3)
                    .opacity(landed ? 1 : 0)
            }
            .frame(width: 104, height: 104)
            .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(SharingMessages.fairFound)
                    .textStyle(.label)
                    .foregroundStyle(Color.paveAccent)
                Text(name ?? SharingMessages.fairLoading)
                    .textStyle(.emptyTitle)
                    .foregroundStyle(name == nil ? Color.inkMuted : Color.ink)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                if let stand {
                    Text(stand)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: name)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .onAppear {
            guard !reduceMotion else {
                progress = 1
                landed = true
                return
            }
            withAnimation(.easeOut(duration: 0.5)) { progress = 1 }
        }
        .task(id: name) {
            guard name != nil, !landed else { return }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(200)) }
            PaveHaptics.success()
            withAnimation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.4)) { landed = true }
            AccessibilityNotification.Announcement(SharingMessages.fairFoundAnnouncement(name ?? "")).post()
        }
    }
}

#Preview {
    FairFoundView(name: "OGD ict-diensten", stand: "Stand A")
}
