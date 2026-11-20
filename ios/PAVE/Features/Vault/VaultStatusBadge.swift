import PAVECore
import SwiftUI

/// Whether an item is confirmed, with the colours from the design. "In afwachting" while a request is open.
struct VaultStatusBadge: View {
    let status: VaultItem.Status
    var isAwaitingReview = false

    init(status: VaultItem.Status, isAwaitingReview: Bool = false) {
        self.status = status
        self.isAwaitingReview = isAwaitingReview
    }

    init(item: VaultItem) {
        self.init(status: item.status, isAwaitingReview: item.isAwaitingReview)
    }

    private var title: String {
        isAwaitingReview ? VaultMessages.awaitingReviewTitle : status.title
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(isAwaitingReview ? .iconClockSolid : status.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(14)
                .accessibilityHidden(true)
            Text(title)
                .textStyle(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(status.foreground)
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .frame(minHeight: 24)
        .background(status.background, in: .rect(cornerRadius: 6))
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(title)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(VaultItem.Status.allCases, id: \.self) { VaultStatusBadge(status: $0) }
        VaultStatusBadge(status: .toVerify, isAwaitingReview: true)
    }
    .padding()
}
