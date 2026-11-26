import PAVECore
import SwiftUI

/// Vacancies over the chat, as the vault: up from the bottom, pulled up to the full screen, swiped away, with Ayla below
/// to keep asking. A vacancy opens inside it, and "terug" or a swipe goes back to the list.
struct AylaVacancyShelf: View {
    let vacancies: [Vacancy]
    let model: AylaChatModel
    @Binding var tab: VacancyList.Tab
    var search: VacancySearch?
    var usedData: [AylaVaultCategory] = []
    var onChooseData: (() -> Void)?
    /// Picked to compare, in the order they were picked.
    var compareIDs: [String] = []
    var onTask: ((AylaRequest.VacancyTask, Vacancy) -> Void)?
    var onToggleCompare: (Vacancy) -> Void = { _ in }
    var onCompare: () -> Void = {}
    var onClearCompare: () -> Void = {}
    var onOpenApplication: ((Vacancy) -> Void)?
    let onAsk: (Vacancy) -> Void
    let onAskGap: (String, Vacancy) -> Void

    @Environment(AylaPageDriver.self) private var driver

    var body: some View {
        @Bindable var driver = driver
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AylaShelf.vacancies.title)
                            .textStyle(.emptyTitle)
                            .foregroundStyle(Color.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text(AylaShelf.vacancies.hint)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(.top, 4)
                    if !compareIDs.isEmpty {
                        VacancyCompareBar(count: compareIDs.count, onCompare: onCompare, onClear: onClearCompare)
                    }
                    VacancyList(
                        vacancies: vacancies, model: model, tab: $tab, search: search, usedData: usedData, onChooseData: onChooseData,
                        onOpenApplication: onOpenApplication,
                        onOpen: { driver.vacancy = $0 }, onAsk: onAsk
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: 600, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Color.panel.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $driver.vacancy) { vacancy in
                VacancyDetail(
                    vacancy: vacancy,
                    tint: tint(of: vacancy),
                    isSaved: model.isSaved(vacancy),
                    onToggleSave: model.canSaveVacancies ? { model.toggleSaved(vacancy) } : nil,
                    onAsk: model.isAvailable ? { onAsk(vacancy) } : nil,
                    onAskGap: model.isAvailable ? { onAskGap($0, vacancy) } : nil,
                    actions: model.isAvailable ? onTask.map { onTask in
                        VacancyActions(
                            isChosen: compareIDs.contains(vacancy.id),
                            canChoose: compareIDs.count < 3,
                            onTask: { onTask($0, vacancy) },
                            onToggleCompare: { onToggleCompare(vacancy) }
                        )
                    } : nil,
                    compareBar: compareIDs.isEmpty ? nil : VacancyCompareBar(count: compareIDs.count, onCompare: onCompare, onClear: onClearCompare)
                )
            }
        }
        .onChange(of: driver.vacancy, initial: true) { _, vacancy in model.showVacancy(vacancy) }
    }

    /// The same colour as its card in the list.
    private func tint(of vacancy: Vacancy) -> Color {
        let list = VacancyList.shown(tab, found: vacancies, model: model)
        let index = list.firstIndex { $0.id == vacancy.id } ?? 0
        return VacancyCard.tints[index % VacancyCard.tints.count]
    }
}
