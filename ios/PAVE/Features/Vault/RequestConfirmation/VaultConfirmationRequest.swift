import Foundation
import PAVECore

/// What a request to confirm evidence would hold: who confirms it, at which organisation and how to reach them. Only the
/// form for now: nothing is sent or stored yet.
struct VaultConfirmationRequest: Equatable {
    enum Recipient: CaseIterable, Identifiable {
        case school
        case employer
        case mentor

        var id: Self { self }

        /// Who usually confirms this kind of evidence: a school for a diploma, an employer for an internship.
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
        case email
    }

    var recipient: Recipient
    var organisation: String
    var email = ""
    var message = ""

    init(item: VaultItem) {
        recipient = .suggested(for: item.category)
        organisation = item.organisationName ?? ""
    }

    var missingFields: [Field] {
        var fields = [Field]()
        if organisation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append(.organisation) }
        if !Self.looksLikeEmail(email) { fields.append(.email) }
        return fields
    }

    /// A rough check, as in a mail app: something before and after the @, and a dot in the domain.
    static func looksLikeEmail(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).wholeMatch(of: /[^@\s]+@[^@\s]+\.[^@\s]{2,}/) != nil
    }
}
