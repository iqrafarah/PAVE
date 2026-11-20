import AppIntents
import PAVECore

/// "Hé Siri, vraag Ayla iets in PAVE": Siri asks what you want to know and reads Ayla's answer out loud, without
/// opening the app, so it works with the iPhone in your pocket and AirPods in. The iPhone has to be unlocked (Face ID
/// or its code), because the answer can be about you. The answer is short; the conversation is in your chats.
struct AskAylaIntent: AppIntent {
    static let title: LocalizedStringResource = "Vraag Ayla"
    static let description = IntentDescription("Stel Ayla een vraag en hoor haar antwoord, zonder PAVE te openen.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Vraag", requestValueDialog: IntentDialog("Wat wil je Ayla vragen?"))
    var question: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AppState.isSignedIn() else {
            return .result(dialog: IntentDialog(stringLiteral: AylaMessages.siriSignInFirst))
        }
        let auth = AuthServiceFactory.make()
        guard !asked.isEmpty, let service = AylaServiceFactory.make(auth: auth) else {
            return .result(dialog: IntentDialog(stringLiteral: AylaMessages.siriUnavailable))
        }
        do {
            let reply = try await service.send(AylaRequest(text: asked, device: .phone, input: .voice))
            let choices = AylaVaultOffer.question(for: reply, asked: asked)?.choices.map(\.label) ?? []
            let spoken = AylaSpokenReply.forSiri(reply, choices: choices, goOn: AylaMessages.siriGoOn)
            return .result(dialog: IntentDialog(stringLiteral: spoken))
        } catch {
            return .result(dialog: IntentDialog(stringLiteral: AylaMessages.siriFailed))
        }
    }
}
