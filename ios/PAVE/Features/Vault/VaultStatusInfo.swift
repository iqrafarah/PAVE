import PAVECore
import SwiftUI

/// "Wat betekent dit?": what you see after tapping the status of a piece of evidence. The three steps every piece of
/// evidence goes through, with where this one stands, one sentence about it, and what you can do next. Feedback from a
/// test round: the labels alone did not say what they mean or how to get further.
struct VaultStatusInfo: View {
    let item: VaultItem
    /// "Laten verifiëren", when that is the next step; nil hides the button.
    var onRequest: (() -> Void)?

    private enum Step: Int, CaseIterable {
        case added, checking, done
    }

    /// Where this item stands: the step it reached, and whether the last one went wrong.
    private var current: Step {
        if item.status == .verified || item.status == .rejected { return .done }
        return item.isAwaitingReview ? .checking : .added
    }

    private var explanation: String {
        item.isAwaitingReview ? VaultMessages.awaitingReviewExplanation(item.lastRequest?.organisationName) : item.status.explanation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                VaultStatusBadge(item: item)
                Text(explanation)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Step.allCases, id: \.self) { step in
                    row(step, isLast: step == .done)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(VaultMessages.statusStepsTitle)
            if let onRequest, item.status != .verified, !item.isAwaitingReview {
                PavePrimaryButton(title: item.status == .rejected ? VaultMessages.requestAgainAction : VaultMessages.requestAction, action: onRequest)
            }
        }
        .padding(20)
        .frame(width: 320, alignment: .leading)
        .background(Color.panel)
    }

    private func row(_ step: Step, isLast: Bool) -> some View {
        let reached = step.rawValue <= current.rawValue
        let isCurrent = step == current
        let rejected = step == .done && item.status == .rejected
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(reached ? (rejected ? Color.statusRejected : Color.paveAccentFill) : Color.panel)
                    Circle()
                        .strokeBorder(reached ? Color.clear : Color.railBorder, lineWidth: 1.5)
                    if reached && isCurrent && step != .done {
                        // Where it stands now: a dot, not a tick, because this step is not finished.
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    } else if reached {
                        Image(rejected ? .iconXMark : .iconCheck)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 11, height: 11)
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
                if !isLast {
                    Rectangle()
                        .fill(step.rawValue < current.rawValue ? Color.paveAccentFill : Color.railBorder)
                        .frame(width: 2)
                        .frame(minHeight: 18)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title(step))
                    .textStyle(.label)
                    .foregroundStyle(reached ? Color.ink : Color.inkMuted)
                Text(detail(step))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isCurrent ? "Hier staat je bewijs nu" : reached ? "Gedaan" : "Nog niet")
    }

    private func title(_ step: Step) -> String {
        switch step {
        case .added: VaultItem.Status.toVerify.title
        case .checking: VaultMessages.awaitingReviewTitle
        case .done: item.status == .rejected ? VaultItem.Status.rejected.title : VaultItem.Status.verified.title
        }
    }

    private func detail(_ step: Step) -> String {
        switch step {
        case .added: VaultMessages.statusStepAdded
        case .checking: VaultMessages.statusStepChecking
        case .done: item.status == .rejected ? VaultMessages.statusStepRejected : VaultMessages.statusStepVerified
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        VaultStatusInfo(item: VaultItem(id: "a", category: .internships, title: "Eindstage", status: .toVerify)) {}
        VaultStatusInfo(item: VaultItem(id: "b", category: .diplomas, title: "Propedeuse", status: .verified))
    }
}
