import PAVECore
import SwiftUI

/// Vacancies from the menu: what Ayla found last, what you kept, and your applications, each a tab. A vacancy opens
/// here; asking Ayla about it, applying or practising goes on in the chat.
struct VacanciesScreen: View {
    let model: AylaChatModel
    let onShowMenu: (() -> Void)?
    let onRequest: (AylaChatModel.VacancyRequest) -> Void

    @State private var tab = VacancyList.Tab.found
    @State private var opened: Vacancy?

    private var latest: (vacancies: [Vacancy], search: VacancySearch?, usedData: [AylaVaultCategory]) { model.latestVacancySearch }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(AylaMessages.vacanciesPageHint)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                    VacancyList(
                        vacancies: latest.vacancies, model: model, tab: $tab, search: latest.search, usedData: latest.usedData,
                        foundEmptyMessage: AylaMessages.vacancyFoundEmptyOnPage,
                        onOpenApplication: { onRequest(.application($0)) },
                        onOpen: { opened = $0 },
                        onAsk: { onRequest(.ask($0)) }
                    )
                    if tab == .found, latest.vacancies.isEmpty, model.isAvailable {
                        PavePrimaryButton(title: AylaMessages.vacancySearchWithAyla) { onRequest(.search) }
                            .frame(maxWidth: 420)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: 600, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Color.canvas.ignoresSafeArea())
            .mainScreenToolbar(MainDestination.vacancies.title, onShowMenu: onShowMenu)
            .navigationDestination(item: $opened) { vacancy in
                VacancyDetail(
                    vacancy: vacancy,
                    isSaved: model.isSaved(vacancy),
                    onToggleSave: model.canSaveVacancies ? { model.toggleSaved(vacancy) } : nil,
                    onAsk: model.isAvailable ? { onRequest(.ask(vacancy)) } : nil,
                    onAskGap: model.isAvailable ? { onRequest(.askGap($0, vacancy)) } : nil,
                    actions: model.isAvailable
                        ? VacancyActions(isChosen: false, showsCompare: false, onTask: { onRequest(.task($0, vacancy)) }, onToggleCompare: {})
                        : nil
                )
            }
        }
    }
}
