import PAVECore
import SwiftUI

/// "Over {bedrijf}" on a vacancy and on Mijn sollicitatie: what PAVE already knows (the place, whether it is an agency,
/// whether they looked at what you shared), and on request what Ayla finds on the web, with its sources.
struct EmployerAboutSection: View {
    let vacancy: Vacancy

    @State private var model: EmployerAboutModel
    @Environment(SharingModel.self) private var sharing: SharingModel?

    init(vacancy: Vacancy, service: (any AylaService)?) {
        self.vacancy = vacancy
        _model = State(initialValue: EmployerAboutModel(company: vacancy.company, city: vacancy.city, service: service))
    }

    /// A share with this company, by its name in the recipient's organisation.
    private var share: ProfileShare? {
        sharing?.shares.first { share in
            guard let organisation = share.recipientOrganisation, !organisation.isEmpty else { return false }
            return organisation.localizedCaseInsensitiveContains(vacancy.company) || vacancy.company.localizedCaseInsensitiveContains(organisation)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            known
            switch model.state {
            case .found(let about): EmployerAboutFound(about: about)
            case .looking: looking
            case .nothing: note(EmployerMessages.nothing(vacancy.company))
            case .failed: lookUpButton(EmployerMessages.tryAgain)
            case .idle: if model.canLookUp { lookUpButton(EmployerMessages.lookUp) }
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.state)
    }

    @ViewBuilder
    private var known: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let city = vacancy.city, !city.isEmpty {
                PaveIconLabel(icon: .iconVaultBuildingOutline, text: "\(vacancy.company) · \(city)")
            }
            if VacancyAgency.isAgency(vacancy.company) {
                PaveIconLabel(icon: .iconVaultBuildingOutline, text: EmployerMessages.agency)
            }
            if let share, share.isLive() {
                Text(EmployerMessages.shared(share))
                    .textStyle(.caption)
                    .foregroundStyle(Color.paveAccent)
            }
        }
    }

    private var looking: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(EmployerMessages.looking(vacancy.company))
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
        }
        .frame(minHeight: 44)
    }

    private func lookUpButton(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PaveSecondaryButton(title: title, icon: .iconMagnifyingGlassSolid) { Task { await model.lookUp() } }
            Text(EmployerMessages.lookUpHint)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .textStyle(.caption)
            .foregroundStyle(Color.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}
