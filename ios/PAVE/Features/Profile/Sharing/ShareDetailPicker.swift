import SwiftUI

/// How much of a piece of evidence a profile shows: briefly (title, organisation, period and status) or in full (also
/// the description and skills).
struct ShareDetailPicker: View {
    @Binding var isBrief: Bool

    var body: some View {
        Menu {
            Picker(SharingMessages.detailTitle, selection: $isBrief) {
                Text(SharingMessages.detailFull).tag(false)
                Text(SharingMessages.detailBrief).tag(true)
            }
        } label: {
            HStack(spacing: 4) {
                Text(isBrief ? SharingMessages.detailBrief : SharingMessages.detailFull)
                    .textStyle(.caption)
                Image(.iconChevronDown)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 8, height: 5)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.paveAccent)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(Color.paveSurfaceTint, in: .capsule)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .accessibilityLabel(SharingMessages.detailTitle)
        .accessibilityValue(isBrief ? SharingMessages.detailBriefHint : SharingMessages.detailFullHint)
    }
}
