import Foundation
import Observation
import PAVECore
import WatchKit

/// Talking with Ayla on the Watch, like the voice mode on the iPhone: tap the orb and talk, Ayla answers out loud,
/// and then the orb listens again until you are quiet for a while. Tapping the orb while she speaks interrupts her.
/// Nothing changes without a Ja: a note Ayla suggests is only saved after you say or tap Ja.
@Observable
final class WatchAylaModel {
    enum Phase: Equatable {
        case ready
        case listening
        case understanding
        case thinking
        case speaking
        /// The answer is on screen and Ayla is quiet.
        case answer
        case failed(String)
    }

    /// Ayla's suggestion to remember something, and what you did with it.
    struct Remember: Equatable {
        enum State: Equatable { case asking, saving, saved, declined, failed }
        var suggestion: AylaReply.MemorySuggestion
        var state: State
    }

    /// Ayla's proposal to change something, such as putting a stage in the vault, and what you did with it.
    struct Proposal: Equatable {
        enum State: Equatable { case asking, saving, done, declined, failed }
        var action: AylaReply.ProposedAction
        var draft: VaultItemDraft
        var state: State
    }

    private(set) var phase = Phase.ready
    private(set) var proposal: Proposal?
    private(set) var question = ""
    private(set) var reply: AylaReply?
    private(set) var remember: Remember?
    /// When Ayla started speaking, so the orb can show the icon of what she talks about at the right moment.
    private(set) var speakingSince: Date?
    /// The most recent conversations for the menu, also those from the iPhone and the web.
    private(set) var conversations: [AylaConversation] = []
    private(set) var conversationsProblem: String?
    private(set) var isLoadingConversations = false

    let sessions: WatchSessionStore
    /// How loud you or Ayla are, read by the orb every frame.
    let meter = VoiceMeter()
    @ObservationIgnored private let recorder = WatchRecorder()
    @ObservationIgnored private lazy var player = WatchVoicePlayer(meter: meter)
    @ObservationIgnored private var conversationID: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var speaking: Task<Void, Never>?
    @ObservationIgnored private var cues: [AylaVoiceCue] = []
    /// Listening again by itself after an answer: quietly back to rest when nothing is said.
    @ObservationIgnored private var isFollowUp = false

    private static let charactersPerSecond = 15.0
    private static let iconDuration: TimeInterval = 2

    init(sessions: WatchSessionStore) {
        self.sessions = sessions
    }

    var isSignedOut: Bool { sessions.isSignedOut && sessions.session == nil }

    var orbMode: AylaPixelOrb.Mode {
        switch phase {
        case .listening: .listening
        case .understanding, .thinking: .thinking
        case .speaking: .speaking
        case .ready, .answer, .failed: .idle
        }
    }

    /// The icon of the part of PAVE Ayla is talking about right now, such as the vault.
    func icon(at date: Date) -> AylaVoiceIcon? {
        guard phase == .speaking, let speakingSince, let reply else { return nil }
        let elapsed = date.timeIntervalSince(speakingSince)
        let duration = max(1, Double(reply.text.count) / Self.charactersPerSecond)
        return cues.last { elapsed >= $0.at * duration && elapsed < $0.at * duration + Self.iconDuration }?.icon
    }

    private var services: (ayla: any AylaService, listen: any AylaListenService, vault: any VaultService)? {
        guard let session = sessions.session else { return nil }
        let store = sessions
        let token: @Sendable () async -> String? = { await store.accessToken() }
        return (
            SupabaseAylaService(projectURL: session.projectURL, publishableKey: session.publishableKey, accessToken: token),
            SupabaseAylaListenService(projectURL: session.projectURL, publishableKey: session.publishableKey, accessToken: token),
            SupabaseVaultService(projectURL: session.projectURL, publishableKey: session.publishableKey, accessToken: token)
        )
    }

    /// The orb was tapped: start listening, send what you said, or interrupt Ayla and listen.
    func tapOrb() {
        switch phase {
        case .listening:
            recorder.finish()
        case .understanding, .thinking:
            break
        case .speaking:
            stopSpeaking()
            listen(followUp: false)
        case .ready, .answer, .failed:
            listen(followUp: false)
        }
    }

    /// Siri or a shortcut asked to talk: listen now, unless Ayla is busy.
    func listenFromShortcut() {
        guard !isSignedOut else { return }
        switch phase {
        case .listening, .understanding, .thinking: break
        case .speaking:
            stopSpeaking()
            listen(followUp: false)
        default: listen(followUp: false)
        }
    }

    private func listen(followUp: Bool) {
        task?.cancel()
        isFollowUp = followUp
        task = Task {
            guard await WatchRecorder.requestPermission() else {
                fail(WatchMessages.noMicrophone)
                return
            }
            do {
                try recorder.start(meter: meter) { [weak self] audio in self?.heard(audio) }
                phase = .listening
                WKInterfaceDevice.current().play(.start)
            } catch {
                fail(WatchMessages.message(for: .unavailable))
            }
        }
    }

    private func heard(_ audio: Data?) {
        guard let audio else {
            if isFollowUp {
                phase = reply == nil ? .ready : .answer
            } else {
                fail(WatchMessages.nothingHeard)
            }
            return
        }
        WKInterfaceDevice.current().play(.stop)
        guard let services else {
            fail(WatchMessages.signedOutMessage)
            return
        }
        phase = .understanding
        task = Task {
            do {
                let text = try await services.listen.transcribe(audio)
                guard !text.isEmpty else {
                    fail(WatchMessages.nothingHeard)
                    return
                }
                // A spoken Ja or Nee answers Ayla's proposal or "Zal ik dit onthouden?" instead of going to Ayla.
                if let yes = AylaSpokenAnswer.interpret(text) {
                    if proposal?.state == .asking, proposal?.action.isOpen() == true {
                        answerProposal(yes)
                        phase = .answer
                        return
                    }
                    if remember?.state == .asking {
                        answerRemember(yes)
                        phase = .answer
                        return
                    }
                }
                await ask(text, ayla: services.ayla)
            } catch {
                fail(WatchMessages.message(for: AylaError(error)))
            }
        }
    }

    /// One of Ayla's choices, such as Ja or Nee, sent as your answer.
    func choose(_ choice: AylaReply.Choice) {
        guard let services else { return }
        WKInterfaceDevice.current().play(.click)
        stopSpeaking()
        task?.cancel()
        task = Task { await ask(choice.label, ayla: services.ayla) }
    }

    private func ask(_ text: String, ayla: any AylaService) async {
        question = text
        phase = .thinking
        do {
            let reply = try await ayla.send(AylaRequest(conversationId: conversationID, text: text, device: .watch, input: .voice))
            guard !Task.isCancelled else { return }
            conversationID = reply.conversationId
            self.reply = reply
            cues = AylaVoiceCue.cues(in: reply.text)
            remember = reply.suggestedMemories.first { !$0.text.isEmpty && $0.replaces == nil }.map { Remember(suggestion: $0, state: .asking) }
            proposal = reply.proposedAction.flatMap { action in
                guard action.kind == .addVaultItem, action.isOpen(), let draft = action.vaultItem?.draft else { return nil }
                return Proposal(action: action, draft: draft, state: .asking)
            }
            WKInterfaceDevice.current().play(.success)
            speak(reply.text, ayla: ayla)
        } catch {
            fail(WatchMessages.message(for: AylaError(error)))
        }
    }

    private func speak(_ text: String, ayla: any AylaService) {
        speaking?.cancel()
        phase = .speaking
        speakingSince = .now
        let player = player
        speaking = Task {
            await player.speak(text, service: ayla)
            guard !Task.isCancelled else { return }
            speakingSince = nil
            phase = .answer
            // Like the voice mode on the iPhone: listen again, and rest when nothing is said.
            listen(followUp: true)
        }
    }

    func stopSpeaking() {
        speaking?.cancel()
        speaking = nil
        player.stop()
        speakingSince = nil
        if phase == .speaking { phase = .answer }
    }

    /// Ja: put the item in your vault with your own session, as added by you and not yet confirmed. Nee: nothing happens.
    func answerProposal(_ yes: Bool) {
        guard var proposal, proposal.state == .asking else { return }
        guard yes, proposal.action.isOpen(), let services else {
            proposal.state = .declined
            self.proposal = proposal
            WKInterfaceDevice.current().play(.click)
            return
        }
        proposal.state = .saving
        self.proposal = proposal
        let draft = proposal.draft
        Task {
            do {
                try await services.vault.add(draft)
                self.proposal?.state = .done
                WKInterfaceDevice.current().play(.success)
            } catch {
                self.proposal?.state = .failed
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    /// Ja: save the note with your session. Nee: nothing is saved.
    func answerRemember(_ yes: Bool) {
        guard var remember, remember.state == .asking else { return }
        guard yes, let services else {
            remember.state = .declined
            self.remember = remember
            WKInterfaceDevice.current().play(.click)
            return
        }
        remember.state = .saving
        self.remember = remember
        let suggestion = remember.suggestion
        let conversationID = conversationID
        Task {
            do {
                _ = try await services.ayla.remember(suggestion.text, categories: [suggestion.category], source: .ayla, conversationID: conversationID)
                self.remember?.state = .saved
                WKInterfaceDevice.current().play(.success)
            } catch {
                self.remember?.state = .failed
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    // MARK: Menu

    func loadConversations() async {
        guard let services else { return }
        isLoadingConversations = conversations.isEmpty
        defer { isLoadingConversations = false }
        do {
            conversations = Array(try await services.ayla.conversations(limit: 10).conversations.prefix(10))
            conversationsProblem = nil
        } catch {
            conversationsProblem = WatchMessages.message(for: AylaError(error))
        }
    }

    func memories() async throws -> AylaMemories {
        guard let services else { throw AylaError.notSignedIn }
        return try await services.ayla.memories()
    }

    func messages(in conversation: AylaConversation) async throws -> [AylaStoredMessage] {
        guard let services else { throw AylaError.notSignedIn }
        return try await services.ayla.messages(in: conversation.id)
    }

    /// Back to the orb in this conversation: Ayla's last answer is on screen and your next question continues it.
    func continueConversation(_ conversation: AylaConversation, messages: [AylaStoredMessage]) {
        task?.cancel()
        recorder.cancel()
        stopSpeaking()
        conversationID = conversation.id
        let lastAnswer = messages.last { $0.role == .ayla }
        question = messages.last { $0.role == .user }?.text ?? conversation.title
        reply = lastAnswer?.reply ?? lastAnswer.map { stored in
            AylaReply(id: stored.id, conversationId: conversation.id, text: stored.text)
        }
        remember = nil
        proposal = nil
        cues = []
        phase = reply == nil ? .ready : .answer
    }

    var currentConversationID: String? { conversationID }

    /// A new conversation.
    func startOver() {
        task?.cancel()
        recorder.cancel()
        stopSpeaking()
        conversationID = nil
        reply = nil
        remember = nil
        proposal = nil
        question = ""
        phase = .ready
    }

    /// Leaving the app: stop listening and talking.
    func pause() {
        recorder.cancel()
        stopSpeaking()
        if phase == .listening { phase = reply == nil ? .ready : .answer }
    }

    private func fail(_ message: String) {
        meter.reset()
        phase = .failed(message)
        WKInterfaceDevice.current().play(.failure)
    }
}
