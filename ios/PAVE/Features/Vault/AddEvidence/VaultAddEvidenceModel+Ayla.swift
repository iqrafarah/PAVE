import PAVECore

extension VaultAddEvidenceModel {
    /// "Zelf invullen" in the chat, as on the web: the form with the chat's files attached, empty, and Ayla reads
    /// nothing.
    static func filledByYou(vault: VaultModel, category: VaultCategory, documents: [VaultUpload]) -> VaultAddEvidenceModel {
        let flow = VaultAddEvidenceModel(vault: vault, category: category, folderID: nil)
        for upload in documents { flow.pick(.success(upload)) }
        flow.go(to: .details)
        return flow
    }

    /// Adding evidence from the chat: the item as Ayla understood it so far, her skills, and the files that belong to
    /// it. When the chat already read those files (the same reading as "Laat Ayla invullen"), the form opens filled in
    /// with that, logo and cover included, without reading them again; otherwise with files she reads them now, and
    /// without files the form opens at the details with what she knew.
    static func proposed(
        by reply: AylaReply?, vault: VaultModel, documents: [VaultUpload] = [], analysis: AylaChatModel.EvidenceAnalysis? = nil
    ) -> VaultAddEvidenceModel {
        let proposal = reply?.proposedAction?.vaultItem
        let draft = proposal?.partialDraft
        let flow = VaultAddEvidenceModel(vault: vault, category: draft?.category ?? .projects, folderID: nil)
        if let draft {
            flow.draft.filledByAyla = true
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
        let readBefore = analysis.flatMap { analysis -> AylaChatModel.EvidenceAnalysis? in
            !analysis.isReading && !analysis.proposals.isEmpty && analysis.uploads == documents ? analysis : nil
        }
        if let readBefore, let first = readBefore.first {
            flow.aylaDocuments = documents
            flow.aylaProposals = readBefore.proposals
            flow.apply(proposal.map(first.merged(with:)) ?? first, documents: documents, pictures: readBefore.pictures)
            flow.aylaFill = .filled
            flow.revealsAylaFill = true
            flow.go(to: .details)
        } else if flow.hasFile {
            flow.fillWithAyla()
        } else if proposal != nil {
            flow.go(to: .details)
        }
        return flow
    }
}
