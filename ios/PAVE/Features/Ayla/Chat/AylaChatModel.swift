import Foundation
import Observation
import PAVECore
import SwiftUI

@Observable
final class AylaChatModel {
    enum Phase: Equatable {
        case idle
        case thinking
        /// Ayla's answer is coming in, word by word.
        case writing
        case failed(String)
    }

    struct Entry: Identifiable, Equatable {
        enum Role {
            case user
            case ayla
        }

        let id: String
        let role: Role
        var text: String
        var reply: AylaReply?
        var attachments: [String] = []
        var sentAt: Date = .now
    }

    private(set) var entries: [Entry] = []
    /// What this conversation is about, such as an item from the vault ("Vraag Ayla over dit bewijs"); it goes with
    /// every question in it, so Ayla knows what "dit" means. Only the id travels; the server reads the item itself and
    /// only when the user allowed Ayla to use it.
    private(set) var context: AylaRequest.Context?
    /// A practice interview for this vacancy is going on: every question goes along with it until it stops.
    private(set) var practice: Vacancy?
    /// A button on a vacancy: the next question goes along with this, once.
    @ObservationIgnored private var nextTask: AylaRequest.Context?
    /// The question that ends the practice is still sent as part of it, so Ayla sums it up.
    @ObservationIgnored private var endsPractice = false
    /// The title of that item, for the chip above the text field.
    private(set) var contextTitle: String?
    private(set) var phase = Phase.idle {
        didSet { if phase != .thinking { activity = nil } }
    }
    /// What Ayla is busy with while she thinks, such as searching vacancies; nil is just thinking.
    private(set) var activity: AylaActivity?
    private(set) var conversationID: String?
    /// A page Ayla opens over the chat after her answer ("open mijn kluis"), as on the web; the id is her answer's.
    struct ScreenRequest: Equatable {
        let id: String
        let navigation: AylaReply.Navigation
    }
    private(set) var screenRequest: ScreenRequest?
    private var opensPageAlready = false

    /// "Nieuwe chat in project": the next question starts the conversation inside this project.
    private(set) var newChatProject: AylaProject?
    /// "Nieuw gesprek in plan": the plan (and the step in it) the next chat belongs to. Any other new chat leaves it.
    private(set) var newChatPlan: (planID: String, stepID: String?)?
    private(set) var firstName: String?

    /// The name changed in Instellingen: the welcome and the menu use it at once.
    func nameChanged(_ name: String?) {
        firstName = name
    }
    /// The welcome waits for the name, so it does not jump when the name comes in.
    private(set) var isGreetingReady: Bool
    private(set) var conversationList = AylaConversationList()
    /// The list is being loaded, the first time or because someone pulled it down.
    private(set) var isLoadingList = false
    /// Loading the list failed and nothing is shown yet.
    private(set) var listFailed = false
    /// The list was asked for at least once; before that an empty list says nothing yet.
    private(set) var hasLoadedList = false
    /// Renaming, deleting or pinning a conversation did not work; the chats screen shows it.
    var chatsProblem: String?
    /// How many conversations are loaded; scrolling to the end loads more.
    private(set) var conversationLimit = 50
    /// Conversations that were just deleted and can still be brought back (`undoDeletion`).
    private(set) var pendingDeletion: [AylaConversation] = []
    @ObservationIgnored private var lastExpiryCheck: Date?
    @ObservationIgnored private var deletionTask: Task<Void, Never>?
    @ObservationIgnored private var refreshAgain = false
    private let undoWindow: Duration
    private(set) var isLoadingConversation = false
    /// Kept per chat (`AylaDrafts`), so a half-typed message waits for you in its own chat.
    var draft = "" {
        didSet { drafts.save(draft, for: conversationID) }
    }
    /// Asked from outside the chat (a keyboard shortcut, Siri, a widget): start talking once the chat is on screen.
    var wantsToTalk = false
    /// Files added with the plus button, sent with the next message.
    private(set) var attachments: [AylaAttachment] = []

    let service: (any AylaService)?
    private let nameWait: Duration
    private let drafts: AylaDrafts
    private let pendingFiles: AylaPendingFiles
    private var lastQuestion: String?
    /// The files sent with the last question, so it can be asked again with them.
    @ObservationIgnored private var lastFiles: [AylaAttachment] = []
    /// The files themselves, by name, for as long as they can still go into the vault: those of the message being
    /// written, and those sent with the last question. They never go to Ayla's chat function.
    @ObservationIgnored private var uploads: [String: VaultUpload] = [:]
    @ObservationIgnored private var lastUploads: [String: VaultUpload] = [:]
    /// Every file sent in this conversation while the app is open, oldest first: evidence built up over several
    /// turns takes them all along.
    @ObservationIgnored private var sentUploads: [VaultUpload] = [] {
        didSet { savePendingFiles() }
    }

    /// What "Laat Ayla invullen" made of the files of an item proposed in the chat: the same reading as in the vault,
    /// so the card and the form know the same, and "Zet in de kluis" does not read them again.
    struct EvidenceAnalysis: Equatable {
        var uploads: [VaultUpload]
        var pictures: [VaultUpload] = []
        var proposals: [VaultEvidenceProposal] = []
        var isReading = true
        var failed = false

        var first: VaultEvidenceProposal? { proposals.first }
    }

    /// Reads files the way the vault does; set by the screen, which has the vault.
    @ObservationIgnored var analyzeEvidence: ((_ uploads: [VaultUpload]) async throws -> (proposals: [VaultEvidenceProposal], pictures: [VaultUpload]))?
    /// By the id of Ayla's reply that proposed the item.
    private(set) var analyses: [String: EvidenceAnalysis] = [:]
    /// The same files read once, however many turns the item takes.
    @ObservationIgnored private var analysisCache: [String: (proposals: [VaultEvidenceProposal], pictures: [VaultUpload])] = [:]
    /// The replies whose item went into the vault, so the card says so and the files are no longer taken along.
    private(set) var addedReplies: Set<String> = []
    /// The vault item each added card made, so the card can ask for its confirmation.
    private(set) var addedItemIDs: [String: String] = [:]
    /// The item that went into the vault last in this conversation, for Ayla's question right after it.
    private(set) var lastAddedItemID: String?

    /// What Ayla offers right after something went into the vault, as a question for Ja or Nee.
    enum FollowUp: Equatable {
        case photos(itemID: String)
        case confirmation(itemID: String)
    }

    /// Ayla's question right after "Toegevoegd aan mijn kluis": a Ja to a photo or file opens the photos for that
    /// item, a Ja to a confirmation opens asking someone for it.
    var followUp: FollowUp? {
        guard !isAnswering, let itemID = lastAddedItemID, entries.count >= 2, let last = entries.last, last.role == .ayla else { return nil }
        let before = entries[entries.count - 2]
        guard before.role == .user, before.text.contains(AylaMessages.addedToVault(nil).dropLast()),
              AylaVaultOffer.endsWithYesNoQuestion(last.text),
              let question = AylaVaultOffer.lastQuestionSentence(in: last.text)?.lowercased() else { return nil }
        if question.contains("bevestig") || question.contains("verifi") { return .confirmation(itemID: itemID) }
        if ["foto", "bestand", "afbeelding", "document"].contains(where: question.contains) { return .photos(itemID: itemID) }
        return nil
    }
    /// The last question and answer are being removed on the server; the next question waits for that.
    @ObservationIgnored private var removal: Task<Bool, Never>?
    @ObservationIgnored private var answerTask: Task<Void, Never>?

    /// `nameWait`: how long the welcome waits for the name; after that it shows without it.
    /// `undoWindow`: how long a deleted conversation can be brought back before it is really deleted.
    init(
        service: (any AylaService)?,
        drafts: AylaDrafts = AylaDrafts(),
        pendingFiles: AylaPendingFiles = AylaPendingFiles(),
        nameWait: Duration = .seconds(1.5),
        undoWindow: Duration = .seconds(5)
    ) {
        self.service = service
        self.drafts = drafts
        self.pendingFiles = pendingFiles
        self.nameWait = nameWait
        self.undoWindow = undoWindow
        isGreetingReady = service == nil
        draft = drafts[nil]
        if let service {
            CompanyLogos.shared.finder = { company, city in try? await service.companyLogo(company: company, city: city) }
        }
    }

    var isAvailable: Bool { service != nil }

    /// Choices from Ayla's last reply, shown instead of the text field. Like on the web, an answer about the vault
    /// without a question of her own gets "Wil je iets toevoegen?" with Ja and Nee.
    var pendingQuestion: AylaReply.Question? {
        guard !isAnswering, let last = entries.last, last.role == .ayla else { return nil }
        return question(for: last)
    }

    /// Ja to the pending question opens adding evidence to the vault.
    var pendingOffersEvidence: Bool {
        guard !isAnswering, let last = entries.last, last.role == .ayla else { return false }
        return AylaVaultOffer.offersToAddEvidence(last.reply, asked: askedText(before: last))
    }

    /// Ayla's newest answer, for what she proposed or suggested in it.
    var lastReply: AylaReply? {
        entries.last { $0.role == .ayla }?.reply
    }

    func question(for entry: Entry) -> AylaReply.Question? {
        AylaVaultOffer.question(for: entry.reply, asked: askedText(before: entry))
    }

    /// The offer to add evidence is answered on the card with "Zet in de kluis", so the question and its Ja and Nee are
    /// not shown as well. A spoken Ja still counts.
    func questionIsOnCard(for entry: Entry) -> Bool {
        entry.reply?.proposedAction?.vaultItem != nil && AylaVaultOffer.offersToAddEvidence(entry.reply, asked: askedText(before: entry))
    }

    /// Ayla's last question can be answered with Ja or Nee: her choices are Ja and Nee (also when she asks whether she
    /// may look at your data), or she asked a question for either in her words.
    var pendingYesNo: Bool {
        guard !isAnswering, let last = entries.last, last.role == .ayla else { return false }
        if let choices = question(for: last)?.choices, !choices.isEmpty {
            return choices.contains { AylaVaultOffer.isYes($0.label) } && choices.contains { AylaVaultOffer.isNo($0.label) }
        }
        return last.reply?.accessRequest == nil && AylaVaultOffer.endsWithYesNoQuestion(last.text)
    }

    var pendingQuestionIsOnCard: Bool {
        guard let last = entries.last, last.role == .ayla else { return false }
        return questionIsOnCard(for: last)
    }

    /// The user's question that an answer is about.
    private func askedText(before entry: Entry) -> String {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }), index > 0, entries[index - 1].role == .user else { return "" }
        return entries[index - 1].text
    }

    var lastAylaEntryID: String? {
        entries.last { $0.role == .ayla }?.id
    }

    /// The last question can be asked again or changed: it has an answer and is saved in a conversation.
    var canRedoLastTurn: Bool {
        guard phase == .idle, conversationID != nil, entries.count >= 2 else { return false }
        return entries[entries.count - 1].role == .ayla && entries[entries.count - 2].role == .user
    }

    var lastQuestionID: String? {
        canRedoLastTurn ? entries[entries.count - 2].id : nil
    }

    func start() async {
        guard let service else { return }
        let wait = nameWait
        let timeout = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            self?.isGreetingReady = true
        }
        let name = await service.firstName()
        timeout.cancel()
        // A name that comes in after the welcome is shown is left out, so the welcome does not jump.
        if !isGreetingReady {
            firstName = name
            isGreetingReady = true
        }
        await refreshConversations()
    }

    /// Ayla is thinking or writing; the send button is a stop button meanwhile.
    var isAnswering: Bool { phase == .thinking || phase == .writing }

    /// Something Ayla does in the app herself ("zet het thema op blauw"): the screen carries it out and returns what
    /// she says, or nil when the words are a question for Ayla after all.
    @ObservationIgnored var appCommand: ((String) -> String?)?

    /// How the app is set right now, sent along with every question so Ayla knows what she would change.
    @ObservationIgnored var appState: (() -> AylaRequest.AppState?)?

    func send(_ text: String) {
        if !isAnswering, attachments.isEmpty, appCommand?(text) != nil {
            draft = ""
            return
        }
        guard let turn = prepare(text, input: .text) else { return }
        answerTask = Task { await stream(turn) }
    }

    /// Stops Ayla: what she wrote so far stays, as in ChatGPT, and is saved by the server too.
    func stopAnswer() {
        answerTask?.cancel()
    }

    /// Sends a question and waits for Ayla's answer, for the voice conversation. Nil when it failed;
    /// the chat then shows what went wrong, just like after a typed question.
    func ask(_ text: String, input: AylaInput) async -> AylaReply? {
        // Spoken, she says what she did; nothing goes to the brain.
        if pendingResults == nil, !isAnswering, attachments.isEmpty, let said = appCommand?(text) {
            return AylaReply(id: UUID().uuidString, conversationId: conversationID ?? "", text: said)
        }
        guard let turn = prepare(text, input: input) else { return nil }
        let reply = await complete(turn)
        // A round of her own that could not be made does not end the conversation: the app says what there is to say.
        if reply == nil, turn.isFollowUp {
            let words = followUpFallback ?? AylaMessages.actionCouldNotContinue
            say(words)
            return AylaReply(id: UUID().uuidString, conversationId: conversationID ?? "", text: words)
        }
        return reply
    }

    private struct Turn {
        let service: any AylaService
        let request: AylaRequest
        let text: String
        let files: [AylaAttachment]
        /// A round of her own after her actions: nothing you typed, so nothing goes back into the text field.
        var isFollowUp = false
    }

    /// Shows the question at once and returns what to send, or nil when nothing can be sent now.
    private func prepare(_ text: String, input: AylaInput) -> Turn? {
        if let results = pendingResults {
            pendingResults = nil
            return followUpTurn(results, input: input)
        }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let service, !text.isEmpty, !isAnswering else { return nil }
        followUpRounds = 0
        // "Met alles uit mijn kluis" or "kijk niet meer in mijn kluis": the items picked earlier no longer count.
        if chosenItemCount != nil, AylaVaultOffer.usesWholeVault(text) || AylaVaultOffer.takesVaultBack(text) { clearContext() }
        let files = attachments
        // "Ja" or "Graag" to her own "Wil je naar je instellingen gaan?" opens that page too.
        let offered = pendingOffersEvidence || followUp != nil ? nil : AylaScreenRequest.screen(confirmedBy: text, after: entries.last?.reply)
        draft = ""
        attachments = []
        if case .failed = phase, lastQuestion == text, entries.last?.role == .user, entries.last?.attachments == files.map(\.name) {
            // Retrying the same question: keep the message that is already shown.
        } else {
            entries.append(Entry(id: UUID().uuidString, role: .user, text: text, attachments: files.map(\.name)))
        }
        lastQuestion = text
        lastFiles = files
        openProject = nil
        // "Open instellingen": the page opens at once, while Ayla answers, as on the web. Not when she is also asked to
        // change something ("zet donker uit en open je kluis"): then it opens once she has done that.
        if let navigation = AylaScreenRequest.screenToOpenAtOnce(askedIn: text).map({ AylaReply.Navigation(screen: $0) }) ?? offered {
            opensPageAlready = true
            openedAtOnce = navigation
            screenRequest = ScreenRequest(id: UUID().uuidString, navigation: navigation)
        } else {
            opensPageAlready = false
            openedAtOnce = nil
        }
        lastUploads = uploads
        sentUploads += files.compactMap { uploads[$0.name] }.filter { upload in !sentUploads.contains(upload) }
        uploads = [:]
        phase = .thinking
        let request = AylaRequest(
            conversationId: conversationID, text: text, device: .phone, input: input, context: requestContext(for: text), attachments: files,
            projectId: newChatProject?.id, planId: newChatPlan?.planID, planStepId: newChatPlan?.stepID, app: appState?()
        )
        return Turn(service: service, request: request, text: text, files: files)
    }

    /// The answer while it is written. The words grow in a message of their own, which becomes the real answer once
    /// it is complete.
    private func stream(_ turn: Turn) async {
        if let removal {
            self.removal = nil
            guard await removal.value else {
                phase = .failed(AylaMessages.redoFailed)
                if draft.isEmpty, !turn.isFollowUp { draft = turn.text }
                return
            }
        }
        var writingIndex: Int?
        do {
            for try await event in turn.service.stream(turn.request) {
                switch event {
                case .started(let id):
                    conversationID = id
                    newChatProject = nil
                    savePendingFiles()
                case .activity(let activity):
                    self.activity = activity
                    phase = .thinking
                case .text(let text):
                    if let writingIndex, entries.indices.contains(writingIndex) {
                        entries[writingIndex].text = text
                        phase = .writing
                    } else {
                        entries.append(Entry(id: "writing-\(UUID().uuidString)", role: .ayla, text: text))
                        writingIndex = entries.count - 1
                        phase = .writing
                    }
                case .reply(let reply):
                    conversationID = reply.conversationId
                    savePendingFiles()
                    let entry = Entry(id: reply.id, role: .ayla, text: reply.text, reply: reply)
                    if let writingIndex, entries.indices.contains(writingIndex) {
                        entries[writingIndex] = entry
                    } else {
                        entries.append(entry)
                    }
                    phase = .idle
                    analyzeEvidenceIfNeeded(for: reply)
                    openPage(after: reply, asked: turn.text)
                    requestActions(of: reply)
                }
            }
            if Task.isCancelled { phase = .idle }
            answerTask = nil
            await refreshConversations()
        } catch {
            answerTask = nil
            if Task.isCancelled || error is CancellationError {
                phase = .idle
                await refreshConversations()
                return
            }
            if let writingIndex, entries.indices.contains(writingIndex) { entries.remove(at: writingIndex) }
            phase = turn.isFollowUp ? .idle : .failed(Self.message(for: AylaError(error)))
            if draft.isEmpty, !turn.isFollowUp { draft = turn.text }
            if attachments.isEmpty { attachments = turn.files }
        }
    }

    @discardableResult
    private func complete(_ turn: Turn) async -> AylaReply? {
        if let removal {
            self.removal = nil
            guard await removal.value else {
                phase = .failed(AylaMessages.redoFailed)
                if draft.isEmpty, !turn.isFollowUp { draft = turn.text }
                return nil
            }
        }
        do {
            let reply = try await turn.service.send(turn.request)
            conversationID = reply.conversationId
            newChatProject = nil
            savePendingFiles()
            entries.append(Entry(id: reply.id, role: .ayla, text: reply.text, reply: reply))
            phase = .idle
            analyzeEvidenceIfNeeded(for: reply)
            openPage(after: reply, asked: turn.text)
            requestActions(of: reply)
            await refreshConversations()
            return reply
        } catch {
            phase = turn.isFollowUp ? .idle : .failed(Self.message(for: AylaError(error)))
            if draft.isEmpty, !turn.isFollowUp { draft = turn.text }
            if attachments.isEmpty { attachments = turn.files }
            return nil
        }
    }

    /// What she points to herself; a page asked for in so many words is already open. One item from the vault still
    /// opens: only her answer knows which.
    private func openPage(after reply: AylaReply, asked: String) {
        let hasActions = reply.actions.map { !$0.isEmpty && !$0.contains(where: \.needsConfirmation) } ?? false
        // A page that opened at once and her actions push away (a setting opens Instellingen for a moment) comes back.
        if hasActions, let openedAtOnce { navigationAfterActions = openedAtOnce }
        guard let navigation = AylaScreenRequest.screenToOpen(after: reply, asked: asked) else { return }
        if opensPageAlready, navigation.itemId == nil { return }
        // Her actions come first: the page opens once they are done, so it is what stays in view.
        if hasActions {
            navigationAfterActions = navigation
            return
        }
        screenRequest = ScreenRequest(id: reply.id, navigation: navigation)
    }

    /// The page that opened while she answered, to bring back after her actions.
    @ObservationIgnored private var openedAtOnce: AylaReply.Navigation?

    /// The page her answer opens, waiting for her actions in that answer to be done.
    @ObservationIgnored private var navigationAfterActions: AylaReply.Navigation?

    /// Her actions are done: the page to open now, once.
    func takeNavigationAfterActions() -> AylaReply.Navigation? {
        defer { navigationAfterActions = nil }
        return navigationAfterActions
    }

    // MARK: What Ayla does in the app herself

    struct ActionRequest: Equatable {
        let id: String
        let actions: [AylaAppAction]
        /// She wants to hear what came of them, to go on.
        var continues = false
    }

    /// The words that stand in for a round of her own; they are never shown or stored as yours.
    static let followUpText = "(vervolg)"
    /// As many steps as one answer carries; a job with more goes on in a next round.
    static let stepsPerRound = 4
    /// At most this many rounds of her own per question, so she cannot keep going in circles.
    static let maxFollowUpRounds = 3
    private var pendingResults: [AylaRequest.ActionResult]?
    private var followUpRounds = 0

    /// Whether she may take another round after her actions.
    var canContinue: Bool { followUpRounds < Self.maxFollowUpRounds && conversationID != nil && service != nil }

    /// What came of her actions is ready for her next round. Typed, that round starts here; spoken, the voice
    /// conversation starts it (so she says her answer) by asking with `followUpText`.
    /// `otherwise`: what the app says itself when she cannot be reached for that round, so a step that failed is
    /// never left unsaid.
    func continueAfter(_ results: [AylaRequest.ActionResult], spoken: Bool, otherwise: String?) {
        guard canContinue, !results.isEmpty, !isAnswering else {
            if let otherwise { say(otherwise) }
            return
        }
        pendingResults = results
        followUpFallback = otherwise
        guard !spoken else { return }
        guard let turn = prepare(Self.followUpText, input: .text) else { return }
        answerTask = Task {
            await stream(turn)
            if case .idle = phase, entries.last?.reply == nil || entries.last?.role == .user, let otherwise { say(otherwise) }
        }
    }
    private var followUpFallback: String?

    private func followUpTurn(_ results: [AylaRequest.ActionResult], input: AylaInput) -> Turn? {
        guard let service, !isAnswering, canContinue else { return nil }
        followUpRounds += 1
        phase = .thinking
        activity = .continuing
        let request = AylaRequest(
            conversationId: conversationID, text: Self.followUpText, device: .phone, input: input, context: context,
            app: appState?(), results: results
        )
        return Turn(service: service, request: request, text: Self.followUpText, files: [], isFollowUp: true)
    }
    /// The actions of her newest answer, for the screen to carry out. What needs your Ja first is not in here.
    private(set) var actionRequest: ActionRequest?
    private var confirmedActionReplies: Set<String> = []

    private func requestActions(of reply: AylaReply) {
        guard let actions = reply.actions, !actions.isEmpty, !actions.contains(where: \.needsConfirmation) else { return }
        actionRequest = ActionRequest(id: reply.id, actions: actions, continues: reply.continues == true)
    }

    /// What her newest answer wants to do once you say Ja (deleting, signing out); nil when that is done or not asked.
    var actionsWaitingForYes: (replyID: String, actions: [AylaAppAction])? {
        guard !isAnswering, let last = entries.last, last.role == .ayla, let reply = last.reply, let actions = reply.actions,
              actions.contains(where: \.needsConfirmation), !confirmedActionReplies.contains(reply.id) else { return nil }
        return (reply.id, actions)
    }

    /// You said Ja: your answer and what she then did show in the chat, and the same Ja cannot do it twice.
    func confirmActions(replyID: String, saying yes: String, done: String) {
        confirmedActionReplies.insert(replyID)
        entries.append(Entry(id: "local-\(UUID().uuidString)", role: .user, text: yes))
        entries.append(Entry(id: "local-\(UUID().uuidString)", role: .ayla, text: done))
    }

    /// Something the app says itself in Ayla's place: what she tried to do and could not.
    func say(_ text: String) {
        entries.append(Entry(id: "local-\(UUID().uuidString)", role: .ayla, text: text))
    }

    /// The conversation that is open, once it is in the list.
    var currentConversation: AylaConversation? {
        conversationID.flatMap { id in conversationList.conversations.first { $0.id == id } }
    }

    func analysis(for reply: AylaReply?) -> EvidenceAnalysis? {
        reply.flatMap { analyses[$0.id] }
    }

    /// Ayla proposed an item and there are files for it: read them as the vault would, while the conversation goes on.
    private func analyzeEvidenceIfNeeded(for reply: AylaReply) {
        guard let analyzeEvidence, let item = reply.proposedAction?.vaultItem, reply.accessRequest == nil else { return }
        let uploads = self.uploads(for: item)
        guard !uploads.isEmpty else { return }
        let key = uploads.map(\.checksum).joined(separator: "+")
        if let cached = analysisCache[key] {
            analyses[reply.id] = EvidenceAnalysis(uploads: uploads, pictures: cached.pictures, proposals: cached.proposals, isReading: false, failed: cached.proposals.isEmpty)
            return
        }
        analyses[reply.id] = EvidenceAnalysis(uploads: uploads)
        Task { [weak self] in
            do {
                let result = try await analyzeEvidence(uploads)
                guard let self else { return }
                analysisCache[key] = result
                analyses[reply.id] = EvidenceAnalysis(uploads: uploads, pictures: result.pictures, proposals: result.proposals, isReading: false, failed: result.proposals.isEmpty)
            } catch {
                self?.analyses[reply.id]?.isReading = false
                self?.analyses[reply.id]?.failed = true
            }
        }
    }

    /// The item of this reply is in the vault: the card says so, its files are done, and Ayla hears it so the next
    /// item starts clean.
    /// `deliver` sends the notice another way, such as out loud in a spoken conversation.
    func markAdded(replyID: String, itemID: String? = nil, title: String, uploads: [VaultUpload], saying words: String? = nil, deliver: ((String) -> Void)? = nil) {
        addedReplies.insert(replyID)
        addedItemIDs[replyID] = itemID
        if let itemID { lastAddedItemID = itemID }
        sentUploads.removeAll { upload in uploads.contains(upload) }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let notice = AylaMessages.addedToVault(name.isEmpty ? nil : name)
        let message = words.map { "\($0)\n\(notice)" } ?? notice
        if let deliver { deliver(message) } else { send(message) }
    }

    /// Adds a file to the next message, with the file itself when the vault can keep it. Returns false when there is
    /// no room for another one.
    @discardableResult
    func attach(_ file: AylaAttachment, upload: VaultUpload? = nil) -> Bool {
        guard attachments.count < AylaAttachment.maxCount else { return false }
        attachments.removeAll { $0.name == file.name }
        attachments.append(file)
        uploads[file.name] = upload
        return true
    }

    /// A name no attachment of this message has yet: photos from the library all get the same name, and a second one
    /// must not take the place of the first.
    func uniqueAttachmentName(_ name: String) -> String {
        let taken = Set(attachments.map(\.name))
        guard taken.contains(name) else { return name }
        let url = URL(filePath: name)
        let stem = url.deletingPathExtension().lastPathComponent
        let suffix = url.pathExtension.isEmpty ? "" : ".\(url.pathExtension)"
        var number = 2
        while taken.contains("\(stem) \(number)\(suffix)") { number += 1 }
        return "\(stem) \(number)\(suffix)"
    }

    func removeAttachment(_ file: AylaAttachment) {
        attachments.removeAll { $0.name == file.name }
        uploads[file.name] = nil
    }

    /// The files sent with the last question, as the vault can keep them.
    var lastTurnUploads: [VaultUpload] {
        lastFiles.compactMap { lastUploads[$0.name] }
    }

    /// The files sent in this conversation, newest last. Files from before the app was opened are no longer on the device.
    var conversationUploads: [VaultUpload] {
        sentUploads
    }

    /// The files that go with an item Ayla proposed: all files sent while this item was built up, newest last. Her own
    /// list of names is no filter: she tends to name the photos and leave out the pdfs, and a file left out would
    /// silently stay behind. A file that does not belong can be taken out in the form. Files of an item that went into
    /// the vault are no longer among them.
    func uploads(for proposal: AylaReply.VaultItemProposal?) -> [VaultUpload] {
        Array(sentUploads.suffix(VaultAddEvidenceModel.maximumDocuments))
    }

    /// Ayla answers the last question again, as if it was asked for the first time.
    func askAgain() {
        guard canRedoLastTurn, let service, let conversationID else { return }
        let question = entries[entries.count - 2]
        let answer = entries.removeLast()
        let files = question.attachments == lastFiles.map(\.name) ? lastFiles : []
        lastQuestion = question.text
        phase = .thinking
        answerTask = Task {
            do {
                try await service.removeLastTurn(in: conversationID)
            } catch {
                entries.append(answer)
                phase = .failed(AylaMessages.redoFailed)
                return
            }
            let request = AylaRequest(
                conversationId: conversationID, text: question.text, device: .phone, input: .text, context: context, attachments: files,
                projectId: newChatProject?.id, planId: newChatPlan?.planID, planStepId: newChatPlan?.stepID, app: appState?()
            )
            await stream(Turn(service: service, request: request, text: question.text, files: files))
        }
    }

    /// Takes the last question and its answer away and puts the question back in the text field, to change it.
    func editLastQuestion() {
        guard canRedoLastTurn, let service, let conversationID else { return }
        let turn = Array(entries.suffix(2))
        let question = turn[0]
        let draftBefore = draft
        entries.removeLast(2)
        draft = question.text
        if question.attachments == lastFiles.map(\.name) {
            attachments = lastFiles
            uploads = lastUploads
        }
        removal = Task {
            do {
                try await service.removeLastTurn(in: conversationID)
                return true
            } catch {
                guard self.conversationID == conversationID, phase == .idle else { return false }
                entries += turn
                draft = draftBefore
                attachments = []
                phase = .failed(AylaMessages.redoFailed)
                removal = nil
                return false
            }
        }
    }

    /// A new conversation about one item from the vault.
    func ask(about item: VaultItem) {
        guard !isAnswering else { return }
        newConversation()
        context = AylaRequest.Context(screen: .vaultItem, itemId: item.id)
        contextTitle = item.title
    }

    /// Items from the vault chosen with the plus button: the conversation is about them from here on.
    func attach(_ items: [VaultItem]) {
        guard let first = items.first else { return }
        // Chosen items are all Ayla uses in this conversation, also when it is one: she sees nothing else of the vault.
        context = AylaRequest.Context(screen: .vault, itemIds: items.map(\.id), vacancy: context?.vacancy)
        contextTitle = items.count == 1 ? first.title : AylaMessages.contextItems(items.count)
    }

    func clearContext() {
        context = nil
        contextTitle = nil
    }

    // MARK: Doing something with a vacancy

    /// A button on one vacancy, or on two or three picked to compare: the question for the chat, which goes to Ayla
    /// with what she needs to answer it. Nil when the vacancies do not fit the task.
    func question(for task: AylaRequest.VacancyTask, about vacancies: [Vacancy]) -> String? {
        guard let first = vacancies.first else { return nil }
        let chosen = context?.itemIds
        switch task {
        case .compare:
            guard (2...3).contains(vacancies.count) else { return nil }
            nextTask = AylaRequest.Context(screen: .vacancies, itemIds: chosen, compare: vacancies.map(AylaRequest.OpenVacancy.init), task: .compare)
            return AylaMessages.vacancyCompareQuestion(vacancies)
        case .gaps, .prepare:
            nextTask = AylaRequest.Context(screen: .vacancies, itemIds: chosen, vacancy: .init(first), task: task)
            return task == .gaps ? AylaMessages.vacancyGapsQuestion(first) : AylaMessages.vacancyPrepareQuestion(first)
        case .interview:
            practice = first
            endsPractice = false
            return AylaMessages.vacancyPracticeQuestion(first)
        }
    }

    /// "Stoppen" on the practice: the last question still belongs to it, so Ayla ends with a summary.
    func stopPracticeQuestion() -> String? {
        guard practice != nil else { return nil }
        endsPractice = true
        return AylaMessages.practiceStopQuestion
    }

    /// Ends the practice at once, such as when the conversation changes.
    func endPractice() {
        practice = nil
        endsPractice = false
        nextTask = nil
    }

    /// What goes along with this question: a task from a button, the practice interview, or what is open.
    private func requestContext(for text: String) -> AylaRequest.Context? {
        if let task = nextTask {
            nextTask = nil
            return task
        }
        guard let practice else { return context }
        let sent = AylaRequest.Context(screen: .vacancies, itemIds: context?.itemIds, vacancy: .init(practice), task: .interview)
        if endsPractice || AylaMessages.endsPractice(text) {
            self.practice = nil
            endsPractice = false
        }
        return sent
    }

    /// Kluis, Plan or Profiel is open over the chat: questions are about that place, unless they are about one item.
    func showScreen(_ screen: AylaScreen) {
        guard contextTitle == nil, AylaScreenRequest.knownToBrain.contains(screen) else { return }
        context = AylaRequest.Context(screen: screen)
    }

    /// A vacancy is open in the vacancies panel: "past deze bij mij?" is about that one; nil is the list again.
    func showVacancy(_ vacancy: Vacancy?) {
        let open = vacancy.map(AylaRequest.OpenVacancy.init)
        // With items chosen for the conversation, the vacancy goes along with them.
        if let chosen = context, chosen.itemIds?.isEmpty == false {
            context = AylaRequest.Context(screen: chosen.screen, itemIds: chosen.itemIds, vacancy: open)
            return
        }
        guard contextTitle == nil, context == nil || context?.screen == .vacancies else { return }
        context = AylaRequest.Context(screen: .vacancies, vacancy: open)
    }

    /// How many items you chose for this conversation; nil when Ayla uses everything she may see.
    var chosenItemCount: Int? {
        context?.itemIds.flatMap { $0.isEmpty ? nil : $0.count }
    }

    func hideScreen(_ screen: AylaScreen) {
        guard context?.screen == screen, context?.itemId == nil else { return }
        context = nil
    }

    /// "Plan toevoegen" before the chat has begun: its first message starts it in this plan (nil: in none). What was
    /// typed and added stays.
    func startInPlan(_ planID: String?) {
        guard conversationID == nil else { return }
        newChatPlan = planID.map { ($0, nil) }
    }

    func newConversation(in project: AylaProject? = nil, plan planID: String? = nil, step stepID: String? = nil) {
        guard !isAnswering else { return }
        openProject = nil
        newChatProject = project
        newChatPlan = planID.map { ($0, stepID) }
        clearContext()
        endPractice()
        entries = []
        conversationID = nil
        lastQuestion = nil
        removal = nil
        phase = .idle
        draft = drafts[nil]
        attachments = []
        sentUploads = []
        analyses = [:]
        addedReplies = []
        addedItemIDs = [:]
        lastAddedItemID = nil
    }

    /// Writes the files still meant for the vault to this device, as soon as the chat has an id to keep them under.
    private func savePendingFiles() {
        guard let conversationID else { return }
        pendingFiles.save(sentUploads, for: conversationID)
    }

    func open(_ conversation: AylaConversation) async {
        openProject = nil
        newChatPlan = nil
        guard let service, !isAnswering else { return }
        clearContext()
        endPractice()
        isLoadingConversation = true
        defer { isLoadingConversation = false }
        do {
            let messages = try await service.messages(in: conversation.id)
            entries = messages.map { message in
                Entry(
                    id: message.id, role: message.role == .user ? .user : .ayla, text: message.text, reply: message.reply,
                    attachments: message.attachments, sentAt: message.sentAt
                )
            }
            conversationID = conversation.id
            lastQuestion = nil
            removal = nil
            phase = .idle
            draft = drafts[conversation.id]
            attachments = []
            sentUploads = pendingFiles.load(for: conversation.id)
            analyses = [:]
            addedReplies = []
        addedItemIDs = [:]
        lastAddedItemID = nil
        } catch {
            phase = .failed(Self.message(for: AylaError(error)))
        }
    }

    func refreshConversations() async {
        guard let service else { return }
        // A change that comes in while loading is fetched right after, so it is never missed.
        guard !isLoadingList else {
            refreshAgain = true
            return
        }
        isLoadingList = true
        defer { isLoadingList = false }
        // Chats whose time is up go first, for good; at most every ten minutes.
        if lastExpiryCheck.map({ Date.now.timeIntervalSince($0) > 600 }) ?? true {
            lastExpiryCheck = .now
            _ = try? await service.expireChats()
        }
        repeat {
            refreshAgain = false
            do {
                var list = try await service.conversations(limit: conversationLimit)
                // Deleted ones that can still be brought back are not on the server's side yet.
                let pending = Set(pendingDeletion.map(\.id))
                list.conversations.removeAll { pending.contains($0.id) }
                // A refresh that shows nothing new (often the echo of your own change) leaves the list alone, so the
                // rows are not drawn again.
                if !list.looksTheSame(as: conversationList) { conversationList = list }
                listFailed = false
            } catch {
                listFailed = conversationList.conversations.isEmpty
            }
        } while refreshAgain
        hasLoadedList = true
    }

    /// Keeps the list up to date while the app is open: a chat started or changed on the web or the Watch shows up
    /// by itself.
    func followConversationChanges() async {
        guard let service else { return }
        for await _ in service.conversationChanges() {
            await refreshConversations()
        }
    }

    /// There may be older conversations than the ones loaded.
    var canLoadMore: Bool {
        conversationList.conversations.count >= conversationLimit
    }

    func loadMoreConversations() async {
        guard canLoadMore, !isLoadingList else { return }
        conversationLimit += 50
        await refreshConversations()
    }

    /// Archives chats or puts them back. The list changes at once and goes back if Supabase refuses. The open chat
    /// starts afresh when it goes into the archive.
    func setArchived(_ isArchived: Bool, _ conversations: [AylaConversation]) {
        guard let service, conversationList.canArchive, !conversations.isEmpty else { return }
        let before = conversationList
        for conversation in conversations { conversationList.setArchived(isArchived, id: conversation.id) }
        if isArchived, conversations.contains(where: { $0.id == conversationID }) { newConversation() }
        Task {
            do {
                for conversation in conversations {
                    try await service.setArchived(isArchived, conversationID: conversation.id)
                }
            } catch {
                conversationList = before
                chatsProblem = isArchived ? AylaMessages.archiveFailed : AylaMessages.unarchiveFailed
            }
        }
    }

    /// The chat's own choice for when it is deleted.
    func setExpiry(_ expiry: AylaConversation.Expiry, _ conversation: AylaConversation) {
        guard let service, conversationList.canArchive, expiry != conversation.expiry else { return }
        let before = conversationList
        conversationList.setExpiry(expiry, id: conversation.id)
        Task {
            do {
                try await service.setExpiry(expiry, conversationID: conversation.id)
            } catch {
                conversationList = before
                chatsProblem = AylaMessages.expiryFailed
            }
        }
    }

    /// Pins or unpins a conversation. The list changes at once and goes back if Supabase refuses.
    func togglePin(_ conversation: AylaConversation) {
        guard let service, conversationList.canPin else { return }
        let isPinned = !conversation.isPinned
        let before = conversationList
        conversationList.setPinned(isPinned, id: conversation.id)
        Task {
            do {
                try await service.setPinned(isPinned, conversationID: conversation.id)
            } catch {
                conversationList = before
                chatsProblem = AylaMessages.pinFailed
            }
        }
    }

    /// Gives a conversation another name. The list changes at once and goes back if Supabase refuses.
    func rename(_ conversation: AylaConversation, to text: String) {
        guard let service, let title = AylaConversation.cleanTitle(text), title != conversation.title else { return }
        let before = conversationList
        conversationList.rename(id: conversation.id, to: title)
        Task {
            do {
                try await service.rename(title, conversationID: conversation.id)
            } catch {
                conversationList = before
                chatsProblem = AylaMessages.renameFailed
            }
        }
    }

    /// Removes conversations from the list at once; they are really deleted after `undoWindow`, unless
    /// `undoDeletion` brings them back first. When the open conversation is one of them, the chat starts afresh.
    func delete(_ conversations: [AylaConversation]) {
        guard service != nil, !conversations.isEmpty else { return }
        commitPendingDeletion()
        let ids = Set(conversations.map(\.id))
        conversationList.conversations.removeAll { ids.contains($0.id) }
        if let conversationID, ids.contains(conversationID) { newConversation() }
        pendingDeletion = conversations
        let wait = undoWindow
        deletionTask = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            self?.commitPendingDeletion()
        }
    }

    func delete(_ conversation: AylaConversation) {
        delete([conversation])
    }

    /// Brings the conversations that were just deleted back.
    func undoDeletion() {
        deletionTask?.cancel()
        deletionTask = nil
        let present = Set(conversationList.conversations.map(\.id))
        conversationList.conversations += pendingDeletion.filter { !present.contains($0.id) }
        pendingDeletion = []
    }

    /// Deletes the pending conversations now, for instance when another one is deleted or the app goes away.
    func commitPendingDeletion() {
        guard let service, !pendingDeletion.isEmpty else { return }
        deletionTask?.cancel()
        deletionTask = nil
        let conversations = pendingDeletion
        pendingDeletion = []
        drafts.remove(conversations.map(\.id))
        pendingFiles.remove(conversations.map(\.id))
        Task {
            var failed: [AylaConversation] = []
            for conversation in conversations {
                do {
                    try await service.delete(conversationID: conversation.id)
                } catch {
                    failed.append(conversation)
                }
            }
            guard !failed.isEmpty else { return }
            let present = Set(conversationList.conversations.map(\.id))
            conversationList.conversations += failed.filter { !present.contains($0.id) }
            chatsProblem = AylaMessages.deleteFailed
        }
    }

    /// Pins several conversations at once, or unpins them when they all were pinned already.
    func togglePin(_ conversations: [AylaConversation]) {
        let pin = !conversations.allSatisfy(\.isPinned)
        for conversation in conversations where conversation.isPinned != pin {
            togglePin(conversation)
        }
    }

    // MARK: Projects

    /// "Nieuw project": the list shows it at once; nil when it could not be made.
    func createProject(name: String, instructions: String, icon: VaultFolderIcon? = nil, color: VaultFolderColor? = nil) async -> AylaProject? {
        guard let service else { return nil }
        do {
            let project = try await service.createProject(
                name: name, instructions: instructions, icon: icon, color: color, withLook: conversationList.canStyleProjects
            )
            conversationList.projects.insert(project, at: 0)
            PaveHaptics.success()
            return project
        } catch {
            return nil
        }
    }

    func updateProject(_ project: AylaProject) async -> Bool {
        guard let service, let index = conversationList.projects.firstIndex(where: { $0.id == project.id }) else { return false }
        let before = conversationList
        let openBefore = openProject
        conversationList.projects[index] = project
        if openProject?.id == project.id { openProject = project }
        do {
            try await service.updateProject(project, withLook: conversationList.canStyleProjects)
            PaveHaptics.success()
            return true
        } catch {
            conversationList = before
            openProject = openBefore
            return false
        }
    }

    func toggleProjectPin(_ project: AylaProject) {
        guard let service, let index = conversationList.projects.firstIndex(where: { $0.id == project.id }) else { return }
        let before = conversationList
        conversationList.projects[index].pinnedAt = project.isPinned ? nil : .now
        PaveHaptics.tap(.medium)
        Task {
            do {
                try await service.setProjectPinned(!project.isPinned, projectID: project.id)
            } catch {
                conversationList = before
                chatsProblem = AylaMessages.pinFailed
            }
        }
    }

    // MARK: Saved vacancies

    /// "Bewaarde vacatures", kept in the account; the newest first.
    private(set) var savedVacancies: [SavedVacancy] = []
    /// False until the table exists (migration 20261120170000); then there is nothing to save to.
    private(set) var canSaveVacancies = true
    var vacancyProblem: String?

    func isSaved(_ vacancy: Vacancy) -> Bool {
        savedVacancies.contains { $0.id == vacancy.id }
    }

    func loadSavedVacancies() async {
        guard let service else { return }
        do {
            savedVacancies = try await service.savedVacancies()
            canSaveVacancies = true
        } catch AylaError.notSetUp {
            canSaveVacancies = false
        } catch {
            vacancyProblem = AylaMessages.vacancySavedLoadFailed
        }
    }

    /// Saves it, or takes it out again. The list changes at once and goes back if it did not work.
    func toggleSaved(_ vacancy: Vacancy) {
        guard let service, canSaveVacancies else { return }
        let before = savedVacancies
        let isSaving = !isSaved(vacancy)
        if isSaving {
            savedVacancies.insert(SavedVacancy(vacancy: vacancy, savedAt: .now), at: 0)
        } else {
            savedVacancies.removeAll { $0.id == vacancy.id }
        }
        PaveHaptics.tap(isSaving ? .medium : .light)
        AccessibilityNotification.Announcement(isSaving ? AylaMessages.vacancySaved : AylaMessages.vacancyUnsaved).post()
        Task {
            do {
                if isSaving {
                    _ = try await service.saveVacancy(vacancy)
                } else {
                    try await service.removeSavedVacancy(id: vacancy.id)
                }
            } catch {
                savedVacancies = before
                vacancyProblem = isSaving ? AylaMessages.vacancySaveFailed : AylaMessages.vacancyUnsaveFailed
                PaveHaptics.error()
            }
        }
    }

    // MARK: The page of a project

    /// The start page of a project (web /project/<id>): its chats and its sources, with a box to start a chat in it.
    var openProject: AylaProject?
    /// The sources of each project that was opened: vault item ids, newest first.
    private(set) var projectSources: [String: [String]] = [:]
    /// False until the table of the sources exists (migration 20261119160000); then there is no Bronnen tab.
    private(set) var canUseSources = true
    /// Loading, adding or removing a source did not work; the project page says so where it happened.
    var sourcesProblem: String?

    /// Its sources load when the page shows; while Ayla is still answering the page waits.
    func openPage(of project: AylaProject) {
        guard !isAnswering else { return }
        newConversation(in: project)
        openProject = project
    }

    func loadSources(of project: AylaProject) async {
        guard let service else { return }
        sourcesProblem = nil
        do {
            projectSources[project.id] = try await service.projectSources(projectID: project.id)
            canUseSources = true
        } catch AylaError.notSetUp {
            canUseSources = false
        } catch {
            if projectSources[project.id] == nil { projectSources[project.id] = [] }
            sourcesProblem = AylaMessages.sourcesFailed
        }
    }

    func addSources(_ itemIDs: [String], to project: AylaProject) async {
        guard let service else { return }
        let known = projectSources[project.id] ?? []
        let fresh = itemIDs.filter { !known.contains($0) }
        guard !fresh.isEmpty else { return }
        projectSources[project.id] = fresh + known
        do {
            try await service.addProjectSources(fresh, projectID: project.id)
            PaveHaptics.success()
        } catch {
            projectSources[project.id] = known
            sourcesProblem = AylaMessages.sourcesFailed
        }
    }

    func removeSource(_ itemID: String, from project: AylaProject) {
        guard let service else { return }
        let before = projectSources[project.id] ?? []
        projectSources[project.id] = before.filter { $0 != itemID }
        Task {
            do {
                try await service.removeProjectSource(itemID, projectID: project.id)
            } catch {
                projectSources[project.id] = before
                sourcesProblem = AylaMessages.sourcesFailed
            }
        }
    }

    /// The chats stay; they only no longer belong to a project.
    func deleteProject(_ project: AylaProject) {
        guard let service else { return }
        if openProject?.id == project.id { openProject = nil }
        let before = conversationList
        conversationList.projects.removeAll { $0.id == project.id }
        for chat in conversationList.conversations where chat.projectID == project.id {
            conversationList.setProject(nil, id: chat.id)
        }
        if newChatProject?.id == project.id { newChatProject = nil }
        PaveHaptics.tap(.heavy)
        Task {
            do {
                try await service.deleteProject(id: project.id)
            } catch {
                conversationList = before
                chatsProblem = AylaMessages.projectFailed
            }
        }
    }

    /// Puts a chat in a project, or takes it out with nil. The list changes at once and goes back if Supabase refuses.
    func move(_ conversation: AylaConversation, to project: AylaProject?) {
        guard let service, conversation.projectID != project?.id else { return }
        let before = conversationList
        conversationList.setProject(project?.id, id: conversation.id)
        PaveHaptics.success()
        AccessibilityNotification.Announcement(project.map { AylaMessages.movedToProject($0.name) } ?? AylaMessages.removedFromProject).post()
        Task {
            do {
                try await service.move(conversationID: conversation.id, toProject: project?.id)
            } catch {
                conversationList = before
                chatsProblem = AylaMessages.moveFailed
            }
        }
    }

    // MARK: Locked chats

    /// The locked chats show while this is true: after the right PIN, until "Nu vergrendelen" or leaving the app.
    var showsLockedChats = false

    /// "Chat vergrendelen": it leaves the list and the search. The open chat closes, as it now needs the PIN.
    func setLocked(_ isLocked: Bool, _ conversation: AylaConversation) async -> Bool {
        guard let service else { return false }
        do {
            try await service.setLocked(isLocked, conversationID: conversation.id)
            conversationList.setLocked(isLocked, id: conversation.id)
            if isLocked, conversation.id == conversationID { newConversation() }
            PaveHaptics.success()
            return true
        } catch {
            chatsProblem = isLocked ? AylaMessages.lockFailed : AylaMessages.unlockFailed
            return false
        }
    }

    func chatPinExists() async -> Bool? {
        guard let service else { return nil }
        return try? await service.chatPinExists()
    }

    /// Nil when it worked, otherwise what to tell the user.
    func setChatPin(_ pin: String) async -> String? {
        guard let service else { return AylaMessages.pinCodeFailed }
        do {
            try await service.setChatPin(pin)
            return nil
        } catch {
            return AylaMessages.pinCodeFailed
        }
    }

    /// Nil when the PIN is right; otherwise what to tell the user.
    func checkChatPin(_ pin: String) async -> String? {
        guard let service else { return AylaMessages.pinCodeFailed }
        do {
            if try await service.checkChatPin(pin) {
                showsLockedChats = true
                return nil
            }
            return AylaMessages.pinWrong
        } catch AylaChatPinError.tooManyAttempts {
            return AylaMessages.pinBlocked
        } catch {
            return AylaMessages.pinCodeFailed
        }
    }

    /// The current PIN before a new one is chosen, without opening the locked chats; wrong tries count as at the door.
    func verifyChatPin(_ pin: String) async -> String? {
        guard let service else { return AylaMessages.pinCodeFailed }
        do {
            return try await service.checkChatPin(pin) ? nil : AylaMessages.pinWrong
        } catch {
            return Self.pinMessage(for: error)
        }
    }

    /// "Pincode wijzigen". Nil when it worked, otherwise what to tell the user.
    func changeChatPin(from pin: String, to newPin: String) async -> String? {
        guard let service else { return AylaMessages.pinCodeFailed }
        do {
            try await service.changeChatPin(from: pin, to: newPin)
            return nil
        } catch {
            return Self.pinMessage(for: error)
        }
    }

    /// "Pincode vergeten" after a fresh code from the authenticator app: a new PIN, and the locked chats stay.
    func recoverChatPin(_ newPin: String) async -> String? {
        guard let service else { return AylaMessages.pinCodeFailed }
        do {
            try await service.recoverChatPin(newPin)
            showsLockedChats = true
            return nil
        } catch {
            return Self.pinMessage(for: error)
        }
    }

    static func pinMessage(for error: any Error) -> String {
        switch error {
        case AylaChatPinError.wrong: AylaMessages.pinWrong
        case AylaChatPinError.tooManyAttempts: AylaMessages.pinBlocked
        case AylaChatPinError.needsRecentVerification: AylaMessages.accountPinVerifyAgain
        case AylaError.notSetUp: AylaMessages.accountPinNotReady
        default: AylaMessages.pinCodeFailed
        }
    }

    /// "Alles verwijderen en opnieuw beginnen": every locked chat is deleted for good, then a new PIN can be chosen.
    func resetChatPin() async -> Bool {
        guard let service else { return false }
        do {
            try await service.resetChatPin()
            let locked = Set(conversationList.locked.map(\.id))
            conversationList.conversations.removeAll { locked.contains($0.id) }
            if let conversationID, locked.contains(conversationID) { newConversation() }
            showsLockedChats = false
            return true
        } catch {
            chatsProblem = AylaMessages.pinCodeFailed
            return false
        }
    }

    /// Messages that contain `text`, with the conversation each is in. Only conversations in the list are shown, and
    /// never a locked one.
    func searchMessages(_ text: String) async -> [(hit: AylaSearchHit, conversation: AylaConversation)] {
        guard let service, let hits = try? await service.searchMessages(text) else { return [] }
        var seen = Set<String>()
        return hits.compactMap { hit in
            guard !seen.contains(hit.conversationID),
                  let conversation = conversationList.visible.first(where: { $0.id == hit.conversationID })
            else { return nil }
            seen.insert(hit.conversationID)
            return (hit, conversation)
        }
    }

    /// The last messages of a conversation, for the preview when you press and hold it.
    func preview(of conversation: AylaConversation) async -> [AylaStoredMessage] {
        guard let service, let messages = try? await service.messages(in: conversation.id) else { return [] }
        return Array(messages.suffix(4))
    }

    static func message(for error: AylaError) -> String {
        switch error {
        case .noConnection: AylaMessages.noConnection
        case .notSignedIn, .insufficientAssurance: AylaMessages.signInAgain
        case .conversationNotFound: AylaMessages.conversationGone
        case .unavailable, .notSetUp: AylaMessages.unavailable
        }
    }
}
