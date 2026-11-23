import PAVECore
import SwiftUI

/// A status badge that turns into a new status once, so you see what just changed: "Niet bevestigd" becomes "In
/// afwachting" when a request goes out, "In afwachting" becomes "Geverifieerd" when it comes back. The same spring as
/// the checks of the wallet. With less motion it simply shows the new status.
struct VaultStatusMorph: View {
    struct Badge: Equatable {
        let status: VaultItem.Status
        var isAwaitingReview = false
    }

    let from: Badge
    let to: Badge
    /// How long the old status stays before it turns.
    var delay: Duration = .milliseconds(450)
    /// A tick in the hand when it turns, for news that matters (confirmed).
    var hapticOnChange = false

    @Environment(\.paveReduceMotion) private var reduceMotion
    @State private var turned = false

    var body: some View {
        ZStack(alignment: .leading) {
            if turned {
                VaultStatusBadge(status: to.status, isAwaitingReview: to.isAwaitingReview)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
            } else {
                VaultStatusBadge(status: from.status, isAwaitingReview: from.isAwaitingReview)
                    .transition(.opacity)
            }
        }
        .task {
            guard !turned else { return }
            try? await Task.sleep(for: reduceMotion ? .zero : delay)
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.35)) { turned = true }
            if hapticOnChange { PaveHaptics.success() }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        VaultStatusMorph(from: .init(status: .toVerify), to: .init(status: .toVerify, isAwaitingReview: true))
        VaultStatusMorph(from: .init(status: .toVerify, isAwaitingReview: true), to: .init(status: .verified), hapticOnChange: true)
    }
    .padding()
}
