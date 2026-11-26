import Foundation
import Observation
import PAVECore

/// A CV and a letter for one vacancy: made from the vault on the device first, then written along by Ayla and changed
/// by hand. Every change is kept on this device at once.
@Observable
final class ApplicationStudioModel: Identifiable {
    var id: String { draft.id }

    private(set) var draft: ApplicationDraft
    /// What the pages show: the draft, a moment behind while typing, so the text field never waits for the page.
    private(set) var shown: ApplicationDraft
    /// Why each piece of evidence is on or off in the proposal.
    private(set) var choices: [String: ApplicationProposal.Choice] = [:]
    /// The entries are still as proposed; the user has not turned one round.
    private(set) var isProposal = false
    /// A new application starts in the gallery, then asks what goes in; one made before opens on its overview.
    var stage: Stage
    /// Made before, or begun now: kept on this device. What is chosen in the gallery and the content step before that
    /// is not kept, so closing there leaves nothing behind.
    private(set) var isKept: Bool
    /// When the draft was last written to this device, for the "Bewaard" note in the editor.
    private(set) var savedAt: Date?
    var document = ApplicationDocumentKind.cv
    var selection: ApplicationBlock?
    /// Ayla is writing this block, or the whole letter.
    private(set) var writing: ApplicationBlock?
    private(set) var isWritingLetter = false
    /// The entries Ayla is writing in the words of a CV.
    private(set) var writingEntries: Set<String> = []
    var problem: String?
    /// What a block said before Ayla wrote it again, so it can go back once.
    private(set) var before: (block: ApplicationBlock, text: String)?

    /// The evidence behind the CV, for its status and for Ayla.
    private(set) var items: [VaultItem]
    /// What Ayla asks where the CV is thin, with what the user answered.
    private(set) var questions: [ApplicationQuestion] = []
    private(set) var isAsking = false
    /// Why Ayla asked nothing the last time, when it was not because she had no questions.
    private(set) var questionsProblem: String?
    /// Adds a sentence to a piece of evidence in the vault and gives the vault back as it is then; nil when it failed.
    /// Plans the notifications of all applications again; set where notifications exist.
    var syncReminders: ([ApplicationDraft]) -> Void = { _ in }
    /// Asks the user for permission to notify; true when it may.
    var requestReminderAccess: () async -> Bool = { true }
    var keepInVault: ((_ itemID: String, _ sentence: String) async -> [VaultItem]?)?
    private let service: (any AylaService)?
    /// For looking up the company on Mijn sollicitatie.
    var lookupService: (any AylaService)? { service }
    private let store: ApplicationStore
    /// How many pages a draft takes in its design; the screen that has the page sets it.
    var measure: (ApplicationDraft) -> Int = { _ in 1 }
    /// How long the CV in the editor is now.
    var pages = 1
    private var showing: Task<Void, Never>?
    private var saving: Task<Void, Never>?

    init(vacancy: Vacancy, items: [VaultItem], name: String, email: String, service: (any AylaService)?, store: ApplicationStore = ApplicationStore()) {
        self.items = items
        self.service = service
        self.store = store
        let saved = store.load(vacancy.id)
        var first = saved ?? ApplicationBuilder.draft(for: vacancy, items: items, name: name, email: email)
        // Which entries carry the tick of verified evidence comes from the vault as it is now, not from the file.
        ApplicationVerification.mark(&first, items: items)
        draft = first
        shown = first
        stage = saved == nil ? .gallery : .hub
        isKept = saved != nil
    }

    /// `hub`: an application that was made before opens on its overview.
    enum Stage { case gallery, start, hub, editor }

    /// A design from the gallery: its own palette, and its photo when it is made for one.
    func choose(_ template: ApplicationTemplate) {
        draft = preview(template)
        shown = draft
        if stage == .editor {
            update { _ in }
        } else {
            // What fits on one page differs per design, so the proposal is made for the one that was chosen.
            propose()
            stage = .start
        }
    }

    /// The design with this template, to show in the gallery before it is chosen.
    func preview(_ template: ApplicationTemplate) -> ApplicationDraft {
        var copy = draft
        copy.template = template
        copy.palette = template.palette
        copy.showsPhoto = template.hasPhoto
        return copy
    }

    /// "Ayla vult het in" writes the profile, what you did at each job and project, and the letter at once; "Zelf
    /// invullen" leaves the texts to the user, with hints. The data from the vault is in both.
    func begin(withAyla: Bool) async {
        let chosen = draft
        var fresh = ApplicationBuilder.draft(
            for: chosen.vacancy, items: items, name: chosen.cv.name, email: chosen.cv.email, template: chosen.template, writesItself: !withAyla
        )
        fresh.palette = chosen.palette
        fresh.showsPhoto = chosen.showsPhoto
        fresh.focus = chosen.focus
        // What was chosen to go in stays chosen: the new draft has new entries for the same evidence.
        let chosenSources = Dictionary(
            chosen.cv.sections.flatMap(\.entries).compactMap { entry in entry.sourceItemID.map { ($0, entry.isVisible) } },
            uniquingKeysWith: { first, _ in first }
        )
        var newChoices: [String: ApplicationProposal.Choice] = [:]
        for section in fresh.cv.sections.indices {
            for index in fresh.cv.sections[section].entries.indices {
                let entry = fresh.cv.sections[section].entries[index]
                guard let source = entry.sourceItemID else { continue }
                if let isOn = chosenSources[source] { fresh.cv.sections[section].entries[index].isVisible = isOn }
                if let old = chosen.cv.sections.flatMap(\.entries).first(where: { $0.sourceItemID == source }) { newChoices[entry.id] = choices[old.id] }
            }
        }
        choices = newChoices
        ApplicationVerification.mark(&fresh, items: items)
        draft = fresh
        shown = fresh
        isKept = true
        store.save(draft)
        stage = .editor
        guard withAyla, service != nil else { return }
        async let profile: Void = writeProfile(withHeadline: true)
        async let entries: Void = writeEntries()
        async let letter: Void = writeLetter()
        _ = await (profile, entries, letter)
        // Her texts are longer or shorter than what was measured: a proposal that was for one page stays one page.
        if isProposal { fitOnOnePage() }
        // Once the CV stands: what only you can add.
        await askQuestions()
    }

    /// Only evidence Ayla may look at goes to her, and of that only what is on the CV: what the user left out, she
    /// does not write about either.
    var itemsForAyla: [VaultItem] {
        let hidden = Set(draft.cv.sections.flatMap { section in
            section.entries.filter { !$0.isVisible || !section.isVisible }.compactMap(\.sourceItemID)
        })
        return items.filter { $0.aylaAllowedAt != nil && $0.archivedAt == nil && !hidden.contains($0.id) }
    }

    // MARK: Keeping track

    var tracking: ApplicationTracking { draft.progress }

    /// A closing date read from the vacancy text, offered while no deadline is set.
    var suggestedDeadline: VacancyDeadlineFinder.Found? {
        guard tracking.deadline == nil, let text = draft.vacancy.summary else { return nil }
        return VacancyDeadlineFinder.find(in: text, now: .now)
    }

    /// What the vacancy asks for that the CV does not show yet.
    var openRequirements: [ApplicationCoverage.Requirement] { requirements.filter { !$0.isCovered } }

    func setStatus(_ status: ApplicationStatus) {
        let firstSend = status == .sent && tracking.invitation == nil
        update { draft in
            var tracking = draft.progress
            if status == .sent { tracking.send() } else { tracking.set(status) }
            draft.tracking = tracking
        }
        if status == .sent { PlanProgress.report(.applicationSent(vacancyID: draft.vacancy.id)) }
        // The demo invitation arrives as a notification: ask now, when it is about to matter.
        if firstSend {
            Task {
                _ = await requestReminderAccess()
                syncReminders(store.all())
            }
        }
    }

    /// The invitation, once it has arrived.
    var invitation: ApplicationInvitation? {
        guard let invitation = tracking.invitation, invitation.hasArrived() else { return nil }
        return invitation
    }

    func readInvitation() {
        guard let invitation, !invitation.isRead else { return }
        update { draft in
            var tracking = draft.progress
            tracking.invitation?.isRead = true
            draft.tracking = tracking
        }
    }

    func choose(_ slot: Date) {
        update { draft in
            var tracking = draft.progress
            tracking.choose(slot)
            draft.tracking = tracking
        }
    }

    func setPrep(_ step: ApplicationInvitation.PrepStep, done: Bool) {
        update { draft in
            var tracking = draft.progress
            if done { tracking.invitation?.done.insert(step) } else { tracking.invitation?.done.remove(step) }
            draft.tracking = tracking
        }
    }

    /// Turns reminders on (after the user allowed notifications) or off. False when they may not be sent.
    func setReminders(_ isOn: Bool) async -> Bool {
        if isOn, !(await requestReminderAccess()) { return false }
        update { draft in
            var tracking = draft.progress
            tracking.remindsMe = isOn
            draft.tracking = tracking
        }
        return true
    }

    func setDeadline(_ date: Date?) {
        update { draft in
            var tracking = draft.progress
            tracking.deadline = date
            draft.tracking = tracking
        }
    }

    func setNote(_ note: String) {
        update(typing: true) { draft in
            var tracking = draft.progress
            tracking.note = String(note.prefix(1000))
            draft.tracking = tracking
        }
    }

    /// The letter has text of its own: written by Ayla, by hand, or the plain one from the vault. "Zelf invullen" leaves
    /// it empty until the user writes.
    var hasLetter: Bool { draft.letter.paragraphs.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }

    /// From the editor back to the overview of the application.
    func showOverview() {
        settle()
        selection = nil
        stage = .hub
    }

    /// From the overview into the CV or the letter.
    func edit(_ document: ApplicationDocumentKind) {
        selection = nil
        self.document = document
        stage = .editor
    }

    // MARK: What goes in

    /// The proposal for this vacancy in the chosen design: what fits is on, what is old and unrelated is off, and
    /// the least fitting is left out until the CV is one page. `pages` measures a draft.
    func propose() {
        var all = draft
        ApplicationProposal.apply(Dictionary(uniqueKeysWithValues: all.cv.sections.flatMap(\.entries).map { ($0.id, true) }), to: &all)
        let proposal = ApplicationProposal.fitted(all, items: items, today: VaultDay(.now), pages: measureWithProfile)
        choices = proposal.choices
        isProposal = true
        set(proposal.draft)
    }

    /// Leaves out the least fitting of what is on now, until the CV is one page. Returns false when it fitted already.
    @discardableResult
    func fitOnOnePage() -> Bool {
        let off = ApplicationProposal.trimmed(draft, items: items, today: VaultDay(.now), pages: measureWithProfile)
        guard !off.isEmpty else { return false }
        var shorter = draft
        ApplicationProposal.apply(Dictionary(uniqueKeysWithValues: off.map { ($0, false) }), to: &shorter)
        for id in off { choices[id] = .init(isOn: false, reason: .forOnePage) }
        set(shorter)
        return true
    }

    /// Before the profile is written the page is measured with room for one, or the CV would fit only until it is.
    private func measureWithProfile(_ draft: ApplicationDraft) -> Int {
        guard draft.cv.profile.isEmpty else { return measure(draft) }
        var filled = draft
        filled.cv.profile = String(repeating: "Ruimte voor je profiel. ", count: 14)
        return measure(filled)
    }

    func setVisible(_ entryID: String, _ isOn: Bool) {
        var changed = draft
        ApplicationProposal.apply([entryID: isOn], to: &changed)
        isProposal = false
        set(changed)
    }

    func setFocus(_ text: String) {
        let focus = text.isEmpty ? nil : String(text.prefix(200))
        if stage == .editor {
            update(typing: true) { $0.focus = focus }
        } else {
            draft.focus = focus
        }
    }

    /// While choosing, before the editor, nothing is kept yet: a draft only exists once you begin.
    private func set(_ new: ApplicationDraft) {
        if stage == .editor {
            update { $0 = new }
        } else {
            draft = new
            ApplicationVerification.mark(&draft, items: items)
            shown = draft
        }
    }

    /// What the vacancy asks for, set against the CV as it is now.
    var requirements: [ApplicationCoverage.Requirement] { ApplicationCoverage.requirements(of: draft, items: items) }

    var canWrite: Bool { service != nil }

    func item(_ id: String?) -> VaultItem? {
        id.flatMap { id in items.first { $0.id == id } }
    }

    // MARK: Changing

    /// `typing`: a change per keystroke. The pages follow a moment later and the file is written once the typing
    /// stops, so the text field stays quick; anything else shows and is kept at once.
    func update(typing: Bool = false, _ change: (inout ApplicationDraft) -> Void) {
        let before = draft.progress
        change(&draft)
        draft.updatedAt = .now
        // An entry that no longer says what was verified loses its tick at once.
        ApplicationVerification.mark(&draft, items: items)
        guard typing else {
            settle()
            let now = draft.progress
            if (before.status, before.deadline, before.changedAt, before.remindsMe) != (now.status, now.deadline, now.changedAt, now.remindsMe) {
                syncReminders(store.all())
            }
            return
        }
        if showing == nil {
            showing = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(140))
                guard let self, !Task.isCancelled else { return }
                self.showing = nil
                self.shown = self.draft
            }
        }
        saving?.cancel()
        saving = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard let self, !Task.isCancelled else { return }
            self.saving = nil
            if self.isKept {
                self.store.save(self.draft)
                self.savedAt = .now
            }
        }
    }

    /// Shows and keeps what was typed, now: before a pdf, when a block is closed, when the screen goes away.
    func settle() {
        showing?.cancel()
        showing = nil
        saving?.cancel()
        saving = nil
        if shown != draft { shown = draft }
        if isKept {
            store.save(draft)
            if stage == .editor { savedAt = .now }
        }
    }

    func entry(_ id: String) -> CVEntry? {
        draft.cv.sections.lazy.flatMap(\.entries).first { $0.id == id }
    }

    func updateEntry(_ id: String, typing: Bool = false, _ change: (inout CVEntry) -> Void) {
        update(typing: typing) { draft in
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

    /// `withHeadline`: also the line under the name, when Ayla fills a new CV; later it is the user's.
    func writeProfile(withHeadline: Bool = false) async {
        guard let service, writing == nil else { return }
        writing = .profile
        defer { writing = nil }
        do {
            let answer = try await service.writeApplication(.init(kind: .profile, vacancy: draft.vacancy, name: draft.cv.name, items: itemsForAyla, focus: draft.focus))
            guard let profile = answer.profile, !profile.isEmpty else { throw AylaError.unavailable }
            before = (.profile, draft.cv.profile)
            setText(profile, of: .profile)
            if withHeadline, let headline = answer.headline, !headline.isEmpty { update { $0.cv.headline = headline } }
        } catch {
            problem = ApplyMessages.aylaFailed
        }
    }

    /// The vault says what you did in its own words, often to you ("Je bouwde…"); a CV says it short and without a
    /// subject. Ayla rewrites each from its own piece of evidence. When she cannot, what the vault says stays.
    func writeEntries() async {
        guard let service, writingEntries.isEmpty else { return }
        let entries = draft.cv.sections
            .filter { [.experience, .projects].contains($0.kind) }
            .flatMap(\.entries)
            .filter { $0.isVisible && !$0.description.isEmpty && $0.sourceItemID != nil }
        let sources = itemsForAyla.filter { item in entries.contains { $0.sourceItemID == item.id } }
        guard !sources.isEmpty else { return }
        writingEntries = Set(entries.filter { entry in sources.contains { $0.id == entry.sourceItemID } }.map(\.id))
        defer { writingEntries = [] }
        guard let answer = try? await service.writeApplication(.init(kind: .entries, vacancy: draft.vacancy, name: draft.cv.name, items: sources)),
              let written = answer.entries, !written.isEmpty
        else { return }
        update { draft in
            for section in draft.cv.sections.indices {
                for index in draft.cv.sections[section].entries.indices where writingEntries.contains(draft.cv.sections[section].entries[index].id) {
                    let source = draft.cv.sections[section].entries[index].sourceItemID
                    if let text = written.first(where: { $0.sourceItemID == source })?.text, !text.isEmpty {
                        draft.cv.sections[section].entries[index].description = text
                    }
                }
            }
        }
    }

    func writeLetter() async {
        guard let service, !isWritingLetter else { return }
        isWritingLetter = true
        defer { isWritingLetter = false }
        do {
            let answer = try await service.writeApplication(.init(kind: .letter, vacancy: draft.vacancy, name: draft.cv.name, items: itemsForAyla, focus: draft.focus))
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

    // MARK: Ayla asks on

    var openQuestions: Int { questions.count { $0.state == .open } }

    /// The visible work and projects that came from evidence Ayla may see.
    private var entriesAylaKnows: [(entry: CVEntry, item: VaultItem)] {
        let allowed = itemsForAyla
        return draft.cv.sections
            .filter { [.experience, .projects].contains($0.kind) && $0.isVisible }
            .flatMap(\.entries)
            .filter(\.isVisible)
            .compactMap { entry in allowed.first { $0.id == entry.sourceItemID }.map { (entry, $0) } }
    }

    /// Asks Ayla where the CV misses something only the user can tell. Quiet when she has nothing or cannot now.
    func askQuestions() async {
        guard !isAsking else { return }
        guard let service else {
            questionsProblem = ApplyMessages.aylaUnavailable
            return
        }
        let known = entriesAylaKnows
        guard !known.isEmpty else {
            questionsProblem = ApplyMessages.aylaUses(0)
            return
        }
        isAsking = true
        questionsProblem = nil
        defer { isAsking = false }
        guard let answer = try? await service.writeApplication(.init(kind: .questions, vacancy: draft.vacancy, name: draft.cv.name, items: known.map(\.item))) else {
            questionsProblem = ApplyMessages.aylaFailed
            return
        }
        questions = (answer.questions ?? []).compactMap { question in
            known.first { $0.item.id == question.sourceItemID }.map {
                ApplicationQuestion(entryID: $0.entry.id, sourceItemID: question.sourceItemID, title: $0.entry.title, text: question.text)
            }
        }
    }

    func setAnswer(_ id: String, _ text: String) {
        guard let index = questions.firstIndex(where: { $0.id == id }) else { return }
        questions[index].answer = String(text.prefix(400))
    }

    /// Works the answer into the entry it is about: Ayla writes that entry again with what was said.
    func answer(_ id: String) async {
        guard let service, let index = questions.firstIndex(where: { $0.id == id }), questions[index].state == .open else { return }
        let question = questions[index]
        let said = question.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !said.isEmpty, let entry = entry(question.entryID), let item = itemsForAyla.first(where: { $0.id == question.sourceItemID }) else { return }
        questions[index].state = .working
        do {
            let written = try await service.writeApplication(.init(
                kind: .answer, vacancy: draft.vacancy, name: draft.cv.name, items: [item], text: entry.description, question: question.text, answer: said
            ))
            guard let text = written.text, !text.isEmpty else { throw AylaError.unavailable }
            updateEntry(question.entryID) { $0.description = text }
            if let now = questions.firstIndex(where: { $0.id == id }) { questions[now].state = .done(before: entry.description) }
        } catch {
            if let now = questions.firstIndex(where: { $0.id == id }) { questions[now].state = .open }
            problem = ApplyMessages.aylaFailed
        }
    }

    func skip(_ id: String) {
        guard let index = questions.firstIndex(where: { $0.id == id }) else { return }
        questions[index].state = .skipped
    }

    func undoAnswer(_ id: String) {
        guard let index = questions.firstIndex(where: { $0.id == id }), case .done(let before) = questions[index].state else { return }
        updateEntry(questions[index].entryID) { $0.description = before }
        questions[index].state = .open
    }

    /// Adds what the user answered to the evidence in the vault too, in their own words. Only on their say-so:
    /// evidence that was verified has to be verified again after it.
    func keep(_ id: String) async {
        guard let keepInVault, let index = questions.firstIndex(where: { $0.id == id }), !questions[index].isKept else { return }
        let said = questions[index].answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !said.isEmpty else { return }
        questions[index].isKeeping = true
        let kept = await keepInVault(questions[index].sourceItemID, said)
        guard let now = questions.firstIndex(where: { $0.id == id }) else { return }
        questions[now].isKeeping = false
        guard let kept else {
            problem = ApplyMessages.keepFailed
            return
        }
        questions[now].isKept = true
        // The vault changed, so what is verified is looked at again.
        items = kept
        update { _ in }
    }

    func undoAyla() {
        guard let before else { return }
        setText(before.text, of: before.block)
        self.before = nil
    }
}
