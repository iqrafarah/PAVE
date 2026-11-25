import PAVECore
import SwiftUI

/// Vacancies from the menu: what Ayla found last, what you kept, and your applications, each a tab. A vacancy and an
/// application open here, and closing them comes back here; asking Ayla or practising goes on in the chat.
struct VacanciesScreen: View {
    let model: AylaChatModel
    let onShowMenu: (() -> Void)?
    let onRequest: (AylaChatModel.VacancyRequest) -> Void

    @State private var tab = VacancyList.Tab.found
    @State private var opened: Vacancy?
    @State private var application: ApplicationStudioModel?
    @State private var reload = 0
    @Environment(VaultModel.self) private var vault: VaultModel?
    @Environment(ProfileModel.self) private var profile: ProfileModel?

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
                        onOpenApplication: openApplication,
                        reload: reload,
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
        .fullScreenCover(item: $application, onDismiss: { reload += 1 }) { studio in
            ApplicationStudioView(
                model: studio, photo: profile?.avatar,
                onClose: { application = nil },
                onTask: { task in
                    let vacancy = studio.draft.vacancy
                    application = nil
                    onRequest(.applicationTask(task, vacancy))
                }
            )
        }
    }

    /// The studio opens over this page, so closing it comes back here and not to the chat.
    private func openApplication(_ vacancy: Vacancy) {
        guard let vault else { return onRequest(.application(vacancy)) }
        PaveHaptics.tap(.medium)
        Task {
            application = await ApplicationStudioModel.open(for: vacancy, vault: vault, profile: profile, firstName: model.firstName, service: model.service)
        }
    }
}
