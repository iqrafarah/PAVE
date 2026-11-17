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
    /// Only narrows the list of persons (docent, stagebegeleider); the request goes to the one chosen `contact`.
    var contactType: String?
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

    /// "Docent", or "Overig" for a person without a function.
    static func function(of contact: VaultValidationContact) -> String {
        let value = contact.jobTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false ? value : nil) ?? "Overig"
    }
}
