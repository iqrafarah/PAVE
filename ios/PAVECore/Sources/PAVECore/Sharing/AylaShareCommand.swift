import Foundation

/// "Deel mijn cv met Kade voor twee weken", "stop met delen met Kade", "wie kan mijn gegevens zien": said or typed to
/// Ayla. She never shares by herself: she opens the share filled in, and you check it and confirm with Face ID.
public enum AylaShareCommand: Equatable, Sendable {
    case share(organisation: String, duration: ShareDuration?, withApplication: Bool)
    case stop(organisation: String)
    case showShares
    /// A selection Ayla put together: it opens at Profiel with these items on, and you save it yourself.
    case selection(name: String, template: ShareTemplate, itemIDs: [String])

    public static func command(in text: String) -> AylaShareCommand? {
        let asked = text.lowercased()
            .replacingOccurrences(of: #"[?!.,]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^(?:(?:ayla|hey|hoi|kun je|kan je|wil je|graag|alsjeblieft) )+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard !asked.isEmpty, asked.count <= 120 else { return nil }
        func match(_ pattern: String) -> [String]? {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let found = regex.firstMatch(in: asked, range: NSRange(asked.startIndex..., in: asked)) else { return nil }
            return (0..<found.numberOfRanges).map { index in
                Range(found.range(at: index), in: asked).map { String(asked[$0]) } ?? ""
            }
        }

        if match(#"^(?:wie (?:kan|kunnen|mag|mogen) (?:mijn )?(?:gegevens|cv|profiel|brief) (?:zien|bekijken)|wat deel ik(?: nu)?|met wie deel ik(?: iets)?)$"#) != nil {
            return .showShares
        }
        if let parts = match(#"^(?:stop|stoppen) (?:met )?delen met (.+)$|^trek (?:het )?delen met (.+?) in$|^(?:trek|haal) (?:mijn )?(?:gegevens|cv|profiel|toegang) (?:bij|van|voor) (.+?) (?:in|terug|weg)$"#) {
            let name = parts.dropFirst().first { !$0.isEmpty } ?? ""
            return name.isEmpty ? nil : .stop(organisation: Self.name(name))
        }
        if let parts = match(#"^deel (?:mijn |m'n )?(cv|brief|motivatiebrief|cv en (?:mijn )?(?:motivatie)?brief|sollicitatie|profiel|gegevens) met (.+?)(?: (?:voor|gedurende) (een|1|twee|2|drie|3|vier|4) (dag|dagen|week|weken|maand|maanden))?$"#) {
            let what = parts[1]
            let duration = Self.duration(amount: parts[3], unit: parts[4])
            return .share(organisation: Self.name(parts[2]), duration: duration, withApplication: what != "profiel" && what != "gegevens")
        }
        return nil
    }

    /// "kade consultancy" → "Kade Consultancy".
    static func name(_ text: String) -> String {
        text.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    static func duration(amount: String, unit: String) -> ShareDuration? {
        guard !unit.isEmpty else { return nil }
        let count = ["een": 1, "1": 1, "twee": 2, "2": 2, "drie": 3, "3": 3, "vier": 4, "4": 4][amount] ?? 1
        switch unit {
        case "dag", "dagen": return count <= 1 ? .day : .week
        case "week", "weken": return count <= 1 ? .week : count == 2 ? .twoWeeks : .month
        default: return count <= 1 ? .month : .threeMonths
        }
    }
}
