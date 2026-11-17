import Foundation
import PAVECore

/// A verification request binds the evidence to trusted directory IDs, never learner-entered names.
struct VaultConfirmationRequest: Equatable {
    enum Recipient: CaseIterable, Identifiable {
        case school
        case employer
        case mentor

        var id: Self { self }

        static func suggested(for category: VaultCategory) -> Recipient {
            switch category {
            case .diplomas, .certificates, .badges: .school
            case .workExperience, .internships: .employer
            case .projects, .skills, .feedback, .reflections, .other: .mentor
            }
        }
    }

    enum Field: Equatable {
        case organisation
        case location
        case contact
    }

    var recipient: Recipient
    var organization: VaultValidationOrganization?
    var location: VaultValidationLocation?
    var department: VaultValidationDepartment?
    var contact: VaultValidationContact?
    var message = ""

    init(item: VaultItem) {
        recipient = .suggested(for: item.category)
    }

    var missingFields: [Field] {
        var fields = [Field]()
        if organization == nil { fields.append(.organisation) }
        if location == nil { fields.append(.location) }
        if contact == nil { fields.append(.contact) }
        return fields
    }
}
