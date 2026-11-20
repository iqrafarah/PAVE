import PAVECore
import SwiftUI

/// Bewaren and Vraag Ayla under a vacancy; on a narrow screen they stack.
struct VacancyActions: View {
    let vacancy: Vacancy
    let isSaved: Bool
    let onToggleSave: (() -> Void)?
    let onAsk: (() -> Void)?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { buttons }
            VStack(alignment: .leading, spacing: 0) { buttons }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if let onToggleSave {
            Button(action: onToggleSave) {
                VacancyActionLabel(
                    title: isSaved ? AylaMessages.vacancySavedLabel : AylaMessages.vacancySave,
                    symbol: isSaved ? "bookmark.fill" : "bookmark",
                    isOn: isSaved
                )
            }
            .buttonStyle(.pave)
            .accessibilityLabel(isSaved ? "Bewaard, tik om niet meer te bewaren" : "Vacature bewaren")
            .sensoryFeedback(.selection, trigger: isSaved)
        }
        if let onAsk {
            Button(action: onAsk) {
                VacancyActionLabel(title: AylaMessages.vacancyAskButton, symbol: "sparkles")
            }
            .buttonStyle(.pave)
            .accessibilityHint("Ayla vertelt in de chat waarom deze vacature bij je past en wat je nog mist")
        }
    }
}
