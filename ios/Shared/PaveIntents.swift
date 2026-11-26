import AppIntents
import Foundation

/// Hands a request from Siri, Shortcuts, the Action button or Control Center to the app. The intents run in the app
/// itself (they bring it to the front), so the app picks the request up once it is unlocked.
@MainActor
enum PaveLinkInbox {
    static var receive: ((PaveLink) -> Void)?

    static func send(_ link: PaveLink) {
        receive?(link)
    }
}

/// Starts a spoken conversation with Ayla, from Siri, Shortcuts, the Action button or Control Center.
struct TalkToAylaIntent: AppIntent {
    static let title: LocalizedStringResource = "Praat met Ayla"
    static let description = IntentDescription("Open PAVE en begin meteen een gesprek met Ayla.")
    static let supportedModes: IntentModes = .foreground

    func perform() async throws -> some IntentResult {
        await PaveLinkInbox.send(.talk)
        return .result()
    }
}

/// Opens an empty chat with Ayla, ready to type.
struct NewAylaConversationIntent: AppIntent {
    static let title: LocalizedStringResource = "Nieuw gesprek met Ayla"
    static let description = IntentDescription("Open PAVE met een nieuw, leeg gesprek met Ayla.")
    static let supportedModes: IntentModes = .foreground

    func perform() async throws -> some IntentResult {
        await PaveLinkInbox.send(.newConversation)
        return .result()
    }
}

/// "Wie kan mijn gegevens zien?": opens Profiel with what you share now. Nothing is said outside the app, so who can see
/// your data stays behind your PIN.
struct ShowSharesIntent: AppIntent {
    static let title: LocalizedStringResource = "Wie kan mijn gegevens zien?"
    static let description = IntentDescription("Open PAVE op Profiel: wat je nu deelt, met wie en hoe lang nog.")
    static let supportedModes: IntentModes = .foreground

    func perform() async throws -> some IntentResult {
        await PaveLinkInbox.send(.shares)
        return .result()
    }
}

/// Stops sharing in one go: PAVE opens and asks whether to pause or take back everything, confirmed with Face ID.
struct StopSharingIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop met delen"
    static let description = IntentDescription("Open PAVE en pauzeer of trek alles in wat je deelt. Je bevestigt het in de app.")
    static let supportedModes: IntentModes = .foreground

    func perform() async throws -> some IntentResult {
        await PaveLinkInbox.send(.stopSharing)
        return .result()
    }
}
