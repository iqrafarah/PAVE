import PAVECore

extension VaultAddEvidenceModel {
    /// Adding evidence after Ja to Ayla's "Wil je iets toevoegen?": filled with the item she proposed, if any, and the
    /// skills she suggested. Nothing is saved until the user goes through the steps and confirms, as always.
    static func proposed(by reply: AylaReply?, vault: VaultModel) -> VaultAddEvidenceModel {
        let proposal = reply?.proposedAction?.vaultItem?.draft
        let flow = VaultAddEvidenceModel(vault: vault, category: proposal?.category ?? .projects, folderID: nil)
        if let proposal {
            flow.draft.title = proposal.title
            flow.draft.organisationName = proposal.organisationName
            flow.draft.organisationLocation = proposal.organisationLocation
            flow.draft.startDate = proposal.startDate
            flow.draft.endDate = proposal.endDate
            flow.draft.issuedOn = proposal.issuedOn
            flow.draft.isCurrent = proposal.isCurrent
            flow.draft.description = proposal.description
        }
        flow.skills = AylaVaultOffer.suggestedSkills(in: reply)
        return flow
    }
}
