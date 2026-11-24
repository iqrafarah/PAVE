import SwiftUI

/// The bookmark in the corner of a vacancy: filled once you kept it.
struct VacancySaveButton: View {
    let isSaved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // The line icons of PAVE, as on the rest of the card; filled once kept.
            Image(isSaved ? .iconBookmarkSolid : .iconBookmarkOutline)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(20)
                .foregroundStyle(isSaved ? Color.paveAccent : Color.inkMuted)
                .scaleEffect(isSaved ? 1 : 0.94)
                .animation(.spring(duration: 0.3, bounce: 0.4), value: isSaved)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(isSaved ? "Bewaard, tik om niet meer te bewaren" : "Vacature bewaren")
        .sensoryFeedback(.selection, trigger: isSaved)
    }
}
