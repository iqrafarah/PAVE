import Foundation
import PAVECore

/// The words of "Over de werkgever". Kept in docs/ui-teksten.md.
enum EmployerMessages {
    static func title(_ company: String) -> String { "Over \(company)" }
    static let lookUp = "Laat Ayla opzoeken"
    static let tryAgain = "Opnieuw opzoeken"
    static let lookUpHint = "Ayla zoekt op het web wat er voor een sollicitant toe doet. Alleen de naam en de plaats van het bedrijf gaan mee, niets over jou."
    static func looking(_ company: String) -> String { "Ayla zoekt op wat er over \(company) te vinden is…" }
    static func nothing(_ company: String) -> String { "Ayla vond niets betrouwbaars over \(company). Kijk anders op de website van het bedrijf." }
    static let agency = "Uitzendbureau of bemiddelaar (herkend aan de naam)"
    static func shared(_ share: ProfileShare) -> String {
        let looks = share.looks.count
        return looks == 0 ? "Je deelt met \(share.recipientName), nog niet bekeken" : "Je deelt met \(share.recipientName), \(looks == 1 ? "1 keer" : "\(looks) keer") bekeken"
    }
    static let sources = "Bronnen"
    static let opensOutside = "Opent de website van het bedrijf, buiten PAVE"
    static func foundBy(_ date: Date) -> String {
        "Opgezocht door Ayla op \(date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "nl_NL")))). Controleer het bij de bronnen."
    }
}
