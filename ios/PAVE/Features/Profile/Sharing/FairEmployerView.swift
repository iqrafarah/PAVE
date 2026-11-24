import PAVECore
import SwiftUI

/// An employer at a fair, opened from their QR code: who they are, their stand, their vacancies to keep, and sharing
/// your profile back with them.
struct FairEmployerView: View {
    let employer: FairEmployer
    let onShareBack: () -> Void

    @Environment(AylaChatModel.self) private var chat

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if employer.isExample {
                    PaveNotice(message: "Voorbeeldwerkgever: verzonnen voor de demo van de banenbeurs.")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(employer.name).textStyle(.emptyTitle).foregroundStyle(Color.ink)
                    Text([employer.city, employer.stand].compactMap { $0 }.joined(separator: " · ")).textStyle(.caption).foregroundStyle(Color.inkMuted)
                }
                Text(employer.about).textStyle(.bodyMedium).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                if !employer.vacancies.isEmpty {
                    SharePanel(title: "Vacatures") {
                        ForEach(Array(employer.vacancies.enumerated()), id: \.element.id) { index, vacancy in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(vacancy.title).textStyle(.bodyMedium).foregroundStyle(Color.ink)
                                    if let summary = vacancy.summary {
                                        Text(summary).textStyle(.caption).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer(minLength: 8)
                                if chat.canSaveVacancies {
                                    VacancySaveButton(isSaved: chat.isSaved(vacancy)) { chat.toggleSaved(vacancy) }
                                }
                            }
                            .padding(14)
                            if index < employer.vacancies.count - 1 { Divider().padding(.leading, 14) }
                        }
                    }
                }
                PavePrimaryButton(title: "Deel je profiel met \(employer.name)", action: onShareBack)
            }
            .padding(20)
        }
    }
}
