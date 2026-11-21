import SwiftUI

/// The bookmark in the corner of a vacancy: filled once you kept it.
struct VacancySaveButton: View {
    let isSaved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSaved ? Color.paveAccent : Color.inkMuted)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(isSaved ? "Bewaard, tik om niet meer te bewaren" : "Vacature bewaren")
        .sensoryFeedback(.selection, trigger: isSaved)
    }
}
