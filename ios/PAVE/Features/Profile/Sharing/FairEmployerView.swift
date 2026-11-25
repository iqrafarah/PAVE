import PAVECore
import SwiftUI

/// An employer at a fair, opened from their QR code: who they are, their stand, their vacancies to keep, and sharing
/// your profile back with them.
struct FairEmployerView: View {
    let employer: FairEmployer
    let model: SharingModel
    /// Opened from a poster for this vacancy: the quick application opens at once.
    var applyingTo: String?
    let onShareBack: () -> Void

    @State private var applying: Vacancy?
    @State private var didOpen = false

    @Environment(AylaChatModel.self) private var chat
    @Environment(\.vacancyRequest) private var vacancyRequest

    /// Ayla takes it from here in the chat: apply, what you miss, practise, ask.
    private var ask: ((AylaChatModel.VacancyRequest) -> Void)? { chat.isAvailable ? vacancyRequest : nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(employer.name).textStyle(.emptyTitle).foregroundStyle(Color.ink)
                    Text([employer.city, employer.stand].compactMap { $0 }.joined(separator: " · ")).textStyle(.caption).foregroundStyle(Color.inkMuted)
                }
                Text(employer.about).textStyle(.bodyMedium).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                if !employer.vacancies.isEmpty {
                    SharePanel(title: "Vacatures") {
                        ForEach(Array(employer.vacancies.enumerated()), id: \.element.id) { index, vacancy in
                            HStack(alignment: .top, spacing: 12) {
                                NavigationLink {
                                    VacancyDetail(
                                        vacancy: vacancy, isSaved: chat.isSaved(vacancy),
                                        onToggleSave: chat.canSaveVacancies ? { chat.toggleSaved(vacancy) } : nil,
                                        onAsk: ask.map { ask in { ask(.ask(vacancy)) } },
                                        onAskGap: ask.map { ask in { ask(.askGap($0, vacancy)) } },
                                        actions: ask.map { ask in
                                            VacancyActions(isChosen: false, showsCompare: false, onTask: { ask(.task($0, vacancy)) }, onToggleCompare: {})
                                        }
                                    )
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(vacancy.title).textStyle(.bodyMedium).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                                        if let summary = vacancy.summary {
                                            Text(summary).textStyle(.caption).foregroundStyle(Color.inkMuted).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                                        }
                                        Text(SharingMessages.fairOpenVacancy).textStyle(.caption).foregroundStyle(Color.paveAccent)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.pave)
                                if chat.canSaveVacancies {
                                    VacancySaveButton(isSaved: chat.isSaved(vacancy)) { chat.toggleSaved(vacancy) }
                                }
                            }
                            .padding([.horizontal, .top], 14)
                            PaveSecondaryButton(title: SharingMessages.quickApply) { applying = vacancy }
                                .padding([.horizontal, .bottom], 14)
                                .padding(.top, 10)
                            if index < employer.vacancies.count - 1 { ShareRowDivider(inset: 14) }
                        }
                    }
                }
                PavePrimaryButton(title: "Deel je profiel met \(employer.name)", action: onShareBack)
            }
            .padding(20)
        }
        .sheet(item: $applying) { vacancy in
            QuickApplySheet(model: model, employer: employer, vacancy: vacancy) { applying = nil }
        }
        .task {
            guard !didOpen, let applyingTo, let vacancy = employer.vacancies.first(where: { $0.id == applyingTo }) else { return }
            didOpen = true
            try? await Task.sleep(for: .milliseconds(350))
            applying = vacancy
        }
    }
}
