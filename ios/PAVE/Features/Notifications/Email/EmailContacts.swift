import Contacts

/// The e-mail addresses in your contacts, so mail from people you know shows up in Meldingen. Read on this iPhone only.
nonisolated enum EmailContacts {
    static var isAllowed: Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        return status == .authorized || status == .limited
    }

    static var isUndecided: Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .notDetermined
    }

    static func requestAccess() async -> Bool {
        (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
    }

    /// Everyone in your contacts with an e-mail address, with their name, for the suggestions in "Aan".
    static func people() async -> [EmailAddress] {
        guard isAllowed else { return [] }
        return await Task.detached(priority: .utility) {
            var result: [EmailAddress] = []
            let keys = [CNContactEmailAddressesKey, CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
            try? CNContactStore().enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { contact, _ in
                let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                for email in contact.emailAddresses {
                    result.append(EmailAddress(name: name.isEmpty ? nil : name, address: (email.value as String).lowercased()))
                }
            }
            return result
        }.value
    }

    static func addresses() async -> Set<String> {
        guard isAllowed else { return [] }
        return await Task.detached(priority: .utility) {
            var result = Set<String>()
            let request = CNContactFetchRequest(keysToFetch: [CNContactEmailAddressesKey as CNKeyDescriptor])
            try? CNContactStore().enumerateContacts(with: request) { contact, _ in
                for email in contact.emailAddresses { result.insert((email.value as String).lowercased()) }
            }
            return result
        }.value
    }
}
