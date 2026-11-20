import Foundation
import PAVECore

/// The words for keeping, expiring and archiving, the same in Instellingen, the chats and the vault.
enum RetentionMessages {
    static let title = "Gegevens bewaren"
    static let archive = "Archiveren"
    static let archiveTitle = "Archief"
    static let restore = "Terugzetten"
    static let expiry = "Verval"
    static let noExpiry = "Geen verval"
    static let followsSettings = "Zoals in Instellingen"
    static let never = "Nooit"

    static let expiryHint = "Na deze tijd verdwijnt een chat vanzelf. Verwijderd is definitief: je kunt een chat daarna niet terughalen."
    static let neverExpires = "Chats in een project en chats in je archief vervallen nooit."
    static let archiveHint = "Wat je archiveert verdwijnt uit beeld, maar blijft bewaard tot je het terugzet of verwijdert. Gearchiveerde bewijsstukken kun je niet delen."
    static let aylaArchiveHint = "Staat dit uit, dan gebruikt Ayla niets uit je archief, ook niet als ze een bewijsstuk eerder mocht zien."
    static let notAvailable = "Dit komt beschikbaar zodra PAVE is bijgewerkt."
    static let loading = "Laden…"
    static let loadFailed = "Je keuze kon niet worden geladen. Probeer het opnieuw."
    static let saveFailed = "De keuze is niet opgeslagen. Probeer het opnieuw."
    static let confirmTitle = "Chats verwijderen?"
    static let confirmButton = "Ja, verwijderen"

    /// Before a choice that can delete chats at once, as the web asks before a shorter time.
    static func confirmMessage(_ expiry: ChatExpiry) -> String {
        let period = expiry.days.map { $0 == 1 ? "1 dag" : "\($0) dagen" } ?? ""
        let since = expiry.start == .created ? "geleden zijn aangemaakt" : "niet zijn gebruikt"
        return "Chats die langer dan \(period) \(since) worden verwijderd, ook de bestaande. Dit kan niet ongedaan worden gemaakt."
    }

    static func chatExpiresMessage(_ title: String, at date: Date, now: Date = .now) -> String {
        let when = date <= now ? "meteen" : expires(date, now: now).replacingOccurrences(of: "Verdwijnt ", with: "")
        return "De chat “\(title)” wordt dan \(when) voorgoed verwijderd. Dit kan niet ongedaan worden gemaakt."
    }

    static let deleteChatMessage = "Deze chat wordt voorgoed verwijderd. Dit kun je niet ongedaan maken."

    static func period(_ days: Int?) -> String {
        switch days {
        case nil: noExpiry
        case 1?: "Na 1 dag"
        case let days?: "Na \(days) dagen"
        }
    }

    static func start(_ start: ChatExpiry.Start) -> String {
        switch start {
        case .lastMessage: "Het laatste bericht"
        case .created: "Het aanmaken van de chat"
        }
    }

    static func title(_ expiry: AylaConversation.Expiry) -> String {
        switch expiry {
        case .followsAccount: followsSettings
        case .never: never
        case .days(let days): period(days)
        }
    }

    /// "Verdwijnt over 3 dagen", "Verdwijnt vandaag".
    static func expires(_ date: Date, now: Date = .now) -> String {
        let days = Int(ceil(date.timeIntervalSince(now) / 86_400))
        switch days {
        case ...0: return "Verdwijnt vandaag"
        case 1: return "Verdwijnt morgen"
        default: return "Verdwijnt over \(days) dagen"
        }
    }
}
