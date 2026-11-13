import Foundation
import PAVECore
import SwiftUI

/// "Laat Ayla invullen": Ayla reads the documents and fills in the evidence, its folder, skills, logo and cover. Only
/// after the user taps it, for these documents. She fills in only what the documents say, and the user checks
/// everything before it is saved. When she sees more than one item, it stays one item unless the user adds them apart.
extension VaultAddEvidenceModel {
    func fillWithAyla() {
        guard hasFile, aylaFill != .reading else { return }
        fillTask?.cancel()
        aylaFill = .reading
        problem = nil
        let uploads = documents
        let vault = vault
        fillTask = Task { [weak self] in
            let reading = await VaultEvidenceReader.read(uploads)
            do {
                let proposals = try await vault.proposeEvidence(from: reading.documents)
                guard !Task.isCancelled else { return }
                self?.receive(proposals, documents: uploads, pictures: reading.pictures)
            } catch {
                guard !Task.isCancelled, let self else { return }
                let message = VaultMessages.withDetail(VaultMessages.aylaFill(VaultError(error)))
                aylaFill = .failed(message)
                problem = message
                PaveHaptics.error()
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }

    /// Zelf invullen: Ayla stops at once, and a late answer changes nothing.
    func stopFilling() {
        fillTask?.cancel()
        fillTask = nil
        if aylaFill == .reading { aylaFill = .idle }
    }

    /// Other documents than Ayla read: what she is reading now no longer fits, a failed try may be tried again, and
    /// her split into several items no longer matches, so it stays one item with the documents you chose.
    func documentsChangedByUser() {
        if aylaFill == .reading { stopFilling() }
        if case .failed = aylaFill { aylaFill = .idle }
        guard aylaProposals.count > 1 else { return }
        aylaProposals = []
        addsApart = false
        nextEvidence = []
    }

    private func receive(_ proposals: [VaultEvidenceProposal], documents uploads: [VaultUpload], pictures: [VaultUpload]) {
        fillTask = nil
        guard let first = proposals.first else {
            aylaFill = .failed(VaultMessages.aylaFillEmpty)
            problem = VaultMessages.aylaFillEmpty
            PaveHaptics.error()
            AccessibilityNotification.Announcement(VaultMessages.aylaFillEmpty).post()
            return
        }
        aylaDocuments = uploads
        aylaProposals = proposals
        addsApart = false
        nextEvidence = []
        apply(first, documents: uploads, pictures: pictures)
        aylaFill = .filled
        PaveHaptics.success()
        AccessibilityNotification.Announcement(VaultMessages.aylaFilledAnnouncement).post()
        go(to: .details)
    }

    /// Fills the form with one of Ayla's items. `uploads` are the documents in the order she numbered them, followed by
    /// `pictures` from Word files, which she may use for the logo or the cover but which are no documents of the item.
    func apply(_ proposal: VaultEvidenceProposal, documents uploads: [VaultUpload], pictures: [VaultUpload] = []) {
        draft = proposal.applied(to: draft)
        categoryChanged()
        if let name = proposal.folder,
           let folder = folders.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }),
           !draft.folderIDs.contains(folder.id) {
            draft.folderIDs.append(folder.id)
        }
        skills = VaultSkills.cleaned(proposal.skills.map(\.name))
        ayla.use(proposal.skills, lookedAtFiles: uploads.count)
        if logo == nil {
            useLogo(of: proposal, documents: uploads + pictures)
        }
        if cover == nil, let image = Self.part(of: uploads + pictures, at: proposal.coverDocument, box: proposal.coverBox).flatMap(VaultAylaImages.cover(from:)) {
            setCover(image)
            aylaChoseCover = true
        }
        aylaProposal = proposal
        aylaDraft = draft
    }

    /// A photo that is only the logo is the sharpest; then the logo from the organisation's website; then the logo cut
    /// from the page where Ayla saw it.
    private func useLogo(of proposal: VaultEvidenceProposal, documents uploads: [VaultUpload]) {
        let wholeImage = proposal.logoBox == nil ? Self.part(of: uploads, at: proposal.logoDocument, box: nil) : nil
        let website = proposal.logo.flatMap { Data(base64Encoded: $0.data) }
        let cut = proposal.logoBox != nil ? Self.part(of: uploads, at: proposal.logoDocument, box: proposal.logoBox) : nil
        for (data, source) in [(wholeImage, nil), (website, proposal.logo?.source), (cut, nil)] {
            guard let data, let image = VaultAylaImages.logo(from: data) else { continue }
            setLogo(image)
            aylaChoseLogo = true
            aylaLogoSource = source
            return
        }
    }

    /// The part of a document Ayla pointed at. Without a box only a photo counts as a whole: a whole PDF page is a
    /// document, never a logo or a cover.
    static func part(of uploads: [VaultUpload], at index: Int?, box: VaultEvidenceProposal.Box?) -> Data? {
        guard let index, uploads.indices.contains(index) else { return nil }
        let upload = uploads[index]
        guard box != nil || upload.isImage else { return nil }
        return VaultAylaImages.region(of: upload, box: box)
    }

    // MARK: More than one item

    /// The titles of all items Ayla saw, when there is more than one.
    var aylaSplitTitles: [String]? {
        aylaProposals.count > 1 ? aylaProposals.map(\.title) : nil
    }

    /// Apart: this item keeps its own documents, and the others follow one by one. Not apart (the default): one item
    /// with all documents.
    func setAddsApart(_ apart: Bool) {
        guard aylaProposals.count > 1, apart != addsApart, let first = aylaProposals.first else { return }
        addsApart = apart
        if apart {
            let mine = first.documents.filter(aylaDocuments.indices.contains).map { aylaDocuments[$0] }
            setDocuments(mine.isEmpty ? aylaDocuments : mine)
            nextEvidence = aylaProposals.dropFirst().map { proposal in
                let indexes = proposal.documents.filter(aylaDocuments.indices.contains)
                return NextEvidence(proposal: Self.renumbered(proposal, to: indexes), documents: indexes.map { aylaDocuments[$0] })
            }
        } else {
            setDocuments(aylaDocuments)
            nextEvidence = []
        }
    }

    /// The next item Ayla saw, as its own flow that starts at the details, already filled in.
    func nextFlow() -> VaultAddEvidenceModel? {
        guard let next = nextEvidence.first else { return nil }
        let flow = VaultAddEvidenceModel(vault: vault, category: next.proposal.category, folderID: nil)
        flow.setDocuments(next.documents)
        flow.aylaDocuments = next.documents
        flow.apply(next.proposal, documents: next.documents)
        flow.aylaFill = .filled
        flow.nextEvidence = Array(nextEvidence.dropFirst())
        flow.go(to: .details)
        return flow
    }

    /// The proposal with its documents counted again within `indexes`, the documents it keeps.
    static func renumbered(_ proposal: VaultEvidenceProposal, to indexes: [Int]) -> VaultEvidenceProposal {
        var result = proposal
        result.documents = Array(indexes.indices)
        result.coverDocument = proposal.coverDocument.flatMap { indexes.firstIndex(of: $0) }
        result.logoDocument = proposal.logoDocument.flatMap { indexes.firstIndex(of: $0) }
        return result
    }

    // MARK: Marks in the form

    /// "Door Ayla · pagina 1" under a field she filled in, as long as it is still as she left it.
    func aylaNote(for field: VaultItemDraft.Field) -> String? {
        guard let proposal = aylaProposal, let filled = aylaDraft, proposal.filledFields.contains(field), Self.isSame(field, draft, filled) else {
            return nil
        }
        return VaultMessages.filledByAyla(source: proposal.source(of: field))
    }

    var aylaNotes: [VaultItemDraft.Field: String] {
        var notes: [VaultItemDraft.Field: String] = [:]
        for field in VaultItemDraft.Field.allCases {
            if let note = aylaNote(for: field) { notes[field] = note }
        }
        return notes
    }

    var aylaLogoNote: String? {
        aylaChoseLogo && logo != nil ? VaultMessages.aylaLogoNote(source: aylaLogoSource) : nil
    }

    var aylaCoverNote: String? {
        aylaChoseCover && cover != nil ? VaultMessages.aylaCoverNote : nil
    }

    static func isSame(_ field: VaultItemDraft.Field, _ draft: VaultItemDraft, _ filled: VaultItemDraft) -> Bool {
        switch field {
        case .title: draft.title == filled.title
        case .organisation: draft.organisationName == filled.organisationName && draft.organisationLocation == filled.organisationLocation
        case .period:
            draft.isPeriod == filled.isPeriod && draft.startDate == filled.startDate && draft.endDate == filled.endDate
                && draft.issuedOn == filled.issuedOn && draft.isCurrent == filled.isCurrent
        case .description: draft.description == filled.description
        }
    }
}
