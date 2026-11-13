import PAVECore

extension VaultAddEvidenceModel {
    /// Adding evidence from the chat: the item as Ayla understood it so far, her skills, and the files that were sent
    /// with the question. With files she reads them at once, as "Laat Ayla invullen" does; without, the form opens
    /// with what she knew.
    static func proposed(by reply: AylaReply?, vault: VaultModel, documents: [VaultUpload] = []) -> VaultAddEvidenceModel {
        let proposal = reply?.proposedAction?.vaultItem
        let draft = proposal?.partialDraft
        let flow = VaultAddEvidenceModel(vault: vault, category: draft?.category ?? .projects, folderID: nil)
        if let draft {
            flow.draft.title = draft.title
            flow.draft.organisationName = draft.organisationName
            flow.draft.organisationLocation = draft.organisationLocation
            flow.draft.startDate = draft.startDate
            flow.draft.endDate = draft.endDate
            flow.draft.issuedOn = draft.issuedOn
            flow.draft.isCurrent = draft.isCurrent
            flow.draft.description = draft.description
        }
        flow.skills = VaultSkills.cleaned((proposal?.skills ?? []) + AylaVaultOffer.suggestedSkills(in: reply))
        for upload in documents { flow.pick(.success(upload)) }
        if flow.hasFile { flow.fillWithAyla() }
        return flow
    }
}
