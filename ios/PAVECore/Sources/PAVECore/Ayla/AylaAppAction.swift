import Foundation

/// Something Ayla does in the app with her answer, chosen by her brain from a fixed list (see `ACTIONS` in the Ayla
/// function): any wording, several in a row, typed or spoken. The app carries it out and says so when it cannot.
/// Names of folders, evidence and chats are your own words; the app looks them up.
public struct AylaAppAction: Codable, Equatable, Sendable {
    public var kind: String
    public var value: String?
    public var target: String?
    /// What cannot be undone: carried out only after you said Ja to her question.
    public var confirm: Bool?

    private enum CodingKeys: String, CodingKey {
        case kind = "do"
        case value, target, confirm
    }

    public init(_ kind: String, value: String? = nil, target: String? = nil, confirm: Bool? = nil) {
        self.kind = kind
        self.value = value
        self.target = target
        self.confirm = confirm
    }

    public var needsConfirmation: Bool { confirm == true }

    /// "on" or "off" as a choice; nil when the value is something else.
    public var isOn: Bool? {
        switch value?.lowercased() {
        case "on", "aan", "true", "ja": true
        case "off", "uit", "false", "nee": false
        default: nil
        }
    }

    /// A place in a list as she counts it ("1" is the first, "last" the last one), as the app counts it (0, -1).
    public var place: Int? {
        guard let value = value?.lowercased() else { return nil }
        if value == "last" || value == "laatste" { return -1 }
        guard let number = Int(value), number >= 1 else { return nil }
        return number - 1
    }

    /// Days until a chat is deleted: a number, `.never` or what the account chose.
    public var expiry: AylaConversation.Expiry? {
        switch value?.lowercased() {
        case "never", "nooit", "0": .never
        case "default", "standaard": .followsAccount
        case let value?: Int(value).flatMap { (1...365).contains($0) ? .days($0) : nil }
        case nil: nil
        }
    }

    /// The fixed command this action is, for what the app could already do when asked in so many words; nil for the
    /// rest, and when a name or value is not one the app knows.
    public func command(folders: [AylaAppCommand.Named] = []) -> AylaAppCommand? {
        let value = value?.lowercased() ?? ""
        switch kind {
        case "openSettingsPage": return AylaAppCommand.SettingsPage(rawValue: value).map(AylaAppCommand.settingsPage)
        case "setTheme":
            guard let theme = PaveThemeColor(rawValue: value), theme != .custom else { return nil }
            return .theme(theme)
        case "setTextSize":
            if value == "bigger" { return .textSizeStep(1) }
            if value == "smaller" { return .textSizeStep(-1) }
            return PaveTextSize(rawValue: value).map(AylaAppCommand.textSize)
        case "setDisplayMode": return PaveDisplayMode(rawValue: value).map(AylaAppCommand.displayMode)
        case "setVaultLayout": return PaveVaultLayout(rawValue: value).map(AylaAppCommand.vaultLayout)
        case "setVoiceText": return isOn.map(AylaAppCommand.voiceText)
        case "setChatsInSearch": return isOn.map(AylaAppCommand.chatsInSearch)
        case "openFolder": return Self.best(target, in: folders).map { .vaultFolder(id: $0.id) }
        case "openSavedVacancies": return .openSavedVacancies
        case "openVacancy": return place.map(AylaAppCommand.openVacancy)
        case "saveVacancy": return place.map { .saveVacancy($0) }
        case "back": return .back
        case "close": return .close
        default: return nil
        }
    }

    /// The thing a name means: the same name first, then a name that contains it or is contained in it, then one that
    /// has all its words. Nil when nothing or more than one thing fits equally well.
    public static func best(_ name: String?, in things: [AylaAppCommand.Named]) -> AylaAppCommand.Named? {
        guard let name else { return nil }
        let asked = plain(name)
        guard asked.count >= 2 else { return nil }
        let named = things.map { (thing: $0, name: plain($0.name)) }
        if let same = named.first(where: { $0.name == asked }) { return same.thing }
        // Small words say nothing about which one is meant ("mijn stage bij LiveWall" is "Stage LiveWall").
        let small: Set<String> = ["bij", "van", "voor", "in", "op", "de", "het", "een", "en", "mijn", "over", "met"]
        let words = asked.split(separator: " ").map(String.init).filter { !small.contains($0) }
        let rounds: [((thing: AylaAppCommand.Named, name: String)) -> Bool] = [
            { $0.name.contains(asked) },
            { entry in !words.isEmpty && words.allSatisfy { entry.name.contains($0) } },
            { $0.name.count >= 3 && asked.contains($0.name) },
        ]
        for fits in rounds {
            let found = named.filter(fits)
            if found.count == 1 { return found[0].thing }
            // Several fit: the shortest name is the closest one, unless two are as close.
            if let shortest = found.min(by: { $0.name.count < $1.name.count }),
               found.filter({ $0.name.count == shortest.name.count }).count == 1 {
                return shortest.thing
            }
            if !found.isEmpty { return nil }
        }
        return nil
    }

    /// Lowercase, without punctuation, accents or a leading "de map" and the like.
    private static func plain(_ text: String) -> String {
        AylaScreenRequest.normalized(text)
            .folding(options: .diacriticInsensitive, locale: nil)
            .replacingOccurrences(of: #"["'“”‘’]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[-–/]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"^(?:(?:de|het|mijn|mn|map|bewijs|bewijsstuk|chat|gesprek|over) )+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
