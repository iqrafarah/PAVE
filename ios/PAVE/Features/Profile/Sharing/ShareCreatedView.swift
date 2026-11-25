import PAVECore
import SwiftUI

/// Right after sharing: done, and the code to scan or the link to send.
struct ShareCreatedView: View {
    let model: SharingModel
    let share: ProfileShare
    var doneTitle = ApplyMessages.done
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(.iconCheckBadgeSolid)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Color.paveAccent)
                    .accessibilityHidden(true)
                Text(SharingMessages.shared)
                    .textStyle(.emptyTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(SharingMessages.sharedHint(share.recipientName))
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                ShareCodeCard(model: model, share: share)
                PavePrimaryButton(title: doneTitle, action: onDone)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }
}
