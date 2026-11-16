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
