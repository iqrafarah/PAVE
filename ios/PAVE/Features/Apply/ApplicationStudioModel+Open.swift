import PAVECore

extension ApplicationStudioModel {
    /// The studio for a vacancy, with the vault as it is now: from the chat and from the vacancies page alike.
    static func open(for vacancy: Vacancy, vault: VaultModel, profile: ProfileModel?, firstName: String?, service: (any AylaService)?) async -> ApplicationStudioModel {
        if vault.state != .ready { await vault.load() }
        let person = profile?.profile
        let name = [person?.fullName, person?.preferredName, firstName].compactMap { $0 }.first { !$0.isEmpty } ?? ""
        let studio = ApplicationStudioModel(vacancy: vacancy, items: vault.items, name: name, email: person?.email ?? "", service: service)
        // What you tell Ayla about a job can go to that piece of evidence too, when you say so.
        studio.keepInVault = { itemID, sentence in
            guard let item = vault.items.first(where: { $0.id == itemID }) else { return nil }
            var draft = VaultItemDraft(item: item)
            draft.description = [draft.description, sentence].filter { !$0.isEmpty }.joined(separator: " ")
            guard draft.problem == nil, await vault.save(draft, itemID: itemID) else { return nil }
            return vault.items
        }
        studio.syncReminders = { ApplicationReminderScheduler.sync($0) }
        studio.requestReminderAccess = ApplicationReminderScheduler.requestAccess
        return studio
    }
}
