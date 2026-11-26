import Foundation
import Observation
import PAVECore

/// Looking up a company: from the device first, otherwise once from the web through Ayla, and only when asked.
@Observable
final class EmployerAboutModel {
    enum State: Equatable { case idle, looking, found(CompanyAbout), nothing, failed }

    let company: String
    let city: String?
    private(set) var state = State.idle
    private let service: (any AylaService)?
    private let store: CompanyAboutStore

    init(company: String, city: String?, service: (any AylaService)?, store: CompanyAboutStore = CompanyAboutStore()) {
        self.company = company
        self.city = city
        self.service = service
        self.store = store
        if let kept = store.load(company: company, city: city) { state = .found(kept) }
    }

    /// Ayla can look up a real company; not a job site's "Via …".
    var canLookUp: Bool { service != nil && !company.isEmpty && !company.hasPrefix("Via ") }

    func lookUp() async {
        guard let service, canLookUp, state != .looking else { return }
        state = .looking
        do {
            if let found = try await service.companyAbout(company: company, city: city) {
                store.save(found, company: company, city: city)
                state = .found(found)
            } else {
                state = .nothing
            }
        } catch {
            state = .failed
        }
    }
}
