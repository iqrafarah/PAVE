import Foundation
import Observation
import PAVECore

/// A CV and a letter for one vacancy: made from the vault on the device first, then written along by Ayla and changed
/// by hand. Every change is kept on this device at once.
@Observable
final class ApplicationStudioModel: Identifiable {
    var id: String { draft.id }

    private(set) var draft: ApplicationDraft
    var document = ApplicationDocumentKind.cv
    var selection: ApplicationBlock?
    /// Ayla is writing this block, or the whole letter.
    private(set) var writing: ApplicationBlock?
    private(set) var isWritingLetter = false
    var problem: String?
    /// What a block said before Ayla wrote it again, so it can go back once.
    private(set) var before: (block: ApplicationBlock, text: String)?

    /// The evidence behind the CV, for its status and for Ayla.
    let items: [VaultItem]
    private let service: (any AylaService)?
    private let store: ApplicationStore

    init(vacancy: Vacancy, items: [VaultItem], name: String, email: String, service: (any AylaService)?, store: ApplicationStore = ApplicationStore()) {
        self.items = items
        self.service = service
        self.store = store
        draft = store.load(vacancy.id) ?? ApplicationBuilder.draft(for: vacancy, items: items, name: name, email: email)
    }

    /// Only evidence Ayla may look at goes to her.
    var itemsForAyla: [VaultItem] { items.filter { $0.aylaAllowedAt != nil && $0.archivedAt == nil } }

    var canWrite: Bool { service != nil }

    func item(_ id: String?) -> VaultItem? {
        id.flatMap { id in items.first { $0.id == id } }
    }

    // MARK: Changing

    func update(_ change: (inout ApplicationDraft) -> Void) {
        change(&draft)
        draft.updatedAt = .now
        store.save(draft)
    }

    func entry(_ id: String) -> CVEntry? {
        draft.cv.sections.lazy.flatMap(\.entries).first { $0.id == id }
    }

    func updateEntry(_ id: String, _ change: (inout CVEntry) -> Void) {
        update { draft in
            for s in draft.cv.sections.indices {
                if let e = draft.cv.sections[s].entries.firstIndex(where: { $0.id == id }) { change(&draft.cv.sections[s].entries[e]) }
            }
        }
    }

    func paragraphIndex(_ id: String) -> Int? {
        draft.letter.paragraphs.firstIndex { $0.id == id }
    }

    func addParagraph() {
        let new = LetterParagraph(text: "")
        update { $0.letter.paragraphs.insert(new, at: max(0, $0.letter.paragraphs.count - 1)) }
        selection = .paragraph(new.id)
    }

    func removeParagraph(_ id: String) {
        update { $0.letter.paragraphs.removeAll { $0.id == id } }
        selection = nil
    }

    func moveSection(from: IndexSet, to: Int) {
        update { $0.cv.sections.move(fromOffsets: from, toOffset: to) }
    }

    // MARK: Ayla

    /// The text of a block Ayla can write again.
    func text(of block: ApplicationBlock) -> String? {
        switch block {
        case .profile: draft.cv.profile
        case .paragraph(let id): paragraphIndex(id).map { draft.letter.paragraphs[$0].text }
        default: nil
        }
    }

    private func setText(_ text: String, of block: ApplicationBlock) {
        update { draft in
            switch block {
            case .profile: draft.cv.profile = text
            case .paragraph(let id):
                if let index = draft.letter.paragraphs.firstIndex(where: { $0.id == id }) { draft.letter.paragraphs[index].text = text }
            default: break
            }
        }
    }

    func writeProfile() async {
        guard let service, writing == nil else { return }
        writing = .profile
        defer { writing = nil }
        do {
            let answer = try await service.writeApplication(.init(kind: .profile, vacancy: draft.vacancy, name: draft.cv.name, items: itemsForAyla))
            guard let profile = answer.profile, !profile.isEmpty else { throw AylaError.unavailable }
            before = (.profile, draft.cv.profile)
            setText(profile, of: .profile)
        } catch {
            problem = ApplyMessages.aylaFailed
        }
    }

    func writeLetter() async {
        guard let service, !isWritingLetter else { return }
        isWritingLetter = true
        defer { isWritingLetter = false }
        do {
            let answer = try await service.writeApplication(.init(kind: .letter, vacancy: draft.vacancy, name: draft.cv.name, items: itemsForAyla))
            guard let paragraphs = answer.paragraphs, !paragraphs.isEmpty else { throw AylaError.unavailable }
            update { draft in
                if let salutation = answer.salutation { draft.letter.salutation = salutation }
                if let closing = answer.closing { draft.letter.closing = closing }
                draft.letter.paragraphs = paragraphs.map { LetterParagraph(text: $0.text, sourceItemIDs: $0.sourceItemIDs) }
            }
            before = nil
            selection = nil
        } catch {
            problem = ApplyMessages.aylaFailed
        }
    }

    func rewrite(_ block: ApplicationBlock, _ how: ApplicationWritingRequest.Rewrite) async {
        guard let service, writing == nil, let original = text(of: block), !original.isEmpty else { return }
        writing = block
        defer { writing = nil }
        do {
            let answer = try await service.writeApplication(.init(kind: .rewrite, vacancy: draft.vacancy, name: draft.cv.name, items: itemsForAyla, text: original, rewrite: how))
            guard let text = answer.text, !text.isEmpty else { throw AylaError.unavailable }
            before = (block, original)
            setText(text, of: block)
        } catch {
            problem = ApplyMessages.aylaFailed
        }
    }

    func undoAyla() {
        guard let before else { return }
        setText(before.text, of: before.block)
        self.before = nil
    }
}
