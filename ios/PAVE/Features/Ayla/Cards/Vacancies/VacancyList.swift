import PAVECore
import SwiftUI

/// Ayla's vacancy results and the ones you kept, in the panel over the chat. "Gevonden" are the ones of this answer,
/// "Bewaard" the ones in your account.
struct VacancyList: View {
    enum Tab: Hashable { case found, saved, applications }

    let vacancies: [Vacancy]
    let model: AylaChatModel
    @Binding var tab: Tab
    /// What Ayla searched for and used, above the ones she found.
    var search: VacancySearch?
    var usedData: [AylaVaultCategory] = []
    var onChooseData: (() -> Void)?
    /// What the empty "Gevonden" says; in the chat it points at the text field below.
    var foundEmptyMessage = AylaMessages.vacancyFoundEmpty
    /// Opens the overview of an application that was made before.
    var onOpenApplication: ((Vacancy) -> Void)?
    let onOpen: (Vacancy) -> Void
    let onAsk: (Vacancy) -> Void

    @State private var applications: [ApplicationDraft] = []

    var shown: [Vacancy] { Self.shown(tab, found: vacancies, model: model) }

    static func shown(_ tab: Tab, found: [Vacancy], model: AylaChatModel) -> [Vacancy] {
        switch tab {
        case .found: found
        case .saved: model.savedVacancies.map(\.vacancy)
        case .applications: []
        }
    }

    var body: some View {
        LazyVStack(spacing: 14) {
            // Without an account to keep vacancies in, the applications on this device still have their tab.
            if model.canSaveVacancies || !applications.isEmpty {
                VacancyTabs(tab: $tab, found: vacancies.count, saved: model.savedVacancies.count, applications: applications.count, showsSaved: model.canSaveVacancies)
                    .padding(.bottom, 4)
            }
            if let problem = model.vacancyProblem {
                PaveInlineError(message: problem)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if tab == .found, !vacancies.isEmpty {
                VacancySearchSummary(search: search, usedData: usedData, chosenCount: model.chosenItemCount, onChooseData: onChooseData)
            }
            if tab == .applications {
                ApplicationsList(applications: applications) { onOpenApplication?($0) }
            } else if shown.isEmpty {
                PaveEmptyState(
                    icon: .iconBriefcase,
                    title: tab == .saved ? AylaMessages.vacancySavedEmptyTitle : AylaMessages.vacancyFoundEmptyTitle,
                    message: tab == .saved ? AylaMessages.vacancySavedEmpty : foundEmptyMessage
                )
                .padding(.vertical, 16)
            }
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, vacancy in
                VacancyCard(
                    vacancy: vacancy,
                    tint: VacancyCard.tints[index % VacancyCard.tints.count],
                    isSaved: model.isSaved(vacancy),
                    onOpen: { onOpen(vacancy) },
                    onToggleSave: model.canSaveVacancies ? { model.toggleSaved(vacancy) } : nil,
                    onAsk: model.isAvailable ? { onAsk(vacancy) } : nil
                )
            }
            let sources = shown.map(\.source).reduce(into: [Vacancy.Source]()) { if !$0.contains($1) { $0.append($1) } }.compactMap(AylaMessages.vacancySource)
            if !sources.isEmpty {
                Text(sources.joined(separator: " · "))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
        .animation(.snappy(duration: 0.25), value: tab)
        .task { await model.loadSavedVacancies() }
        // The applications live on this device and change while the studio is open over the panel.
        .task(id: tab) { applications = ApplicationStore().all() }
    }
}
