import Foundation
import PAVECore

/// A verification request binds the evidence to trusted directory IDs, never learner-entered names.
/// Only the organisation and the person are chosen; location and department follow from the person.
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
        case contact
    }

    /// How the organisation got there: by ID, or picked by the learner. A name is never more than a suggestion.
    enum OrganizationSource: Equatable {
        case evidence
        case earlierRequest
        case chosen
    }

    var recipient: Recipient
    /// The kind of evidence: who may confirm it depends on it.
    let category: VaultCategory
    var organization: VaultValidationOrganization?
    var organizationSource: OrganizationSource?
    var contact: VaultValidationPerson?
    /// Optional; they only narrow the search and are never sent.
    var filters = VaultValidationFilters()
    var search = ""
    var message = ""

    init(item: VaultItem) {
        recipient = .suggested(for: item.category)
        category = item.category
    }

    var missingFields: [Field] {
        var fields = [Field]()
        if organization == nil { fields.append(.organisation) }
        if contact == nil { fields.append(.contact) }
        return fields
    }

    /// Another organisation: the person and the filters belong to the old one, so they go. The evidence stays as it is.
    mutating func choose(_ organization: VaultValidationOrganization, source: OrganizationSource = .chosen) {
        guard organization.id != self.organization?.id else { return }
        self.organization = organization
        organizationSource = source
        contact = nil
        filters = VaultValidationFilters()
        search = ""
    }

    /// The organisations the evidence is known to belong to, by ID: the one that issued it, then the one of the
    /// latest request for it.
    static func knownOrganizationIDs(for item: VaultItem) -> [(id: String, source: OrganizationSource)] {
        var known = [(id: String, source: OrganizationSource)]()
        if let id = item.organizationID { known.append((id, .evidence)) }
        if let id = item.lastRequest?.organizationID, id != item.organizationID { known.append((id, .earlierRequest)) }
        return known
    }

    /// A suggestion from the name the learner typed: only when exactly one of the results has that name.
    static func suggestion(for item: VaultItem, among organizations: [VaultValidationOrganization]) -> VaultValidationOrganization? {
        guard let name = normalised(item.organisationName) else { return nil }
        let found = organizations.filter { normalised($0.name) == name }
        return found.count == 1 ? found[0] : nil
    }

    static func normalised(_ text: String?) -> String? {
        let value = text?
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "nl_NL"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return value?.isEmpty == false ? value : nil
    }

    /// "Docent", or "Overig" for a person without a function.
    static func function(of contact: VaultValidationContact) -> String {
        let value = contact.jobTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false ? value : nil) ?? "Overig"
    }
}

extension VaultModel {
    /// Sends the request by the IDs of the chosen person; the server checks again that this person may confirm it.
    func requestValidation(for item: VaultItem, _ request: VaultConfirmationRequest) async -> String? {
        guard let organization = request.organization, let contact = request.contact else {
            return VaultMessages.requestMissing(request.missingFields.first ?? .contact)
        }
        return await requestValidation(
            for: item,
            organizationID: organization.id,
            locationID: contact.locationId,
            departmentID: contact.departmentId,
            contactID: contact.id,
            message: request.message
        )
    }
}
