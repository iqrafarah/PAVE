import Foundation

/// The pixel icons Ayla's orb forms while she talks about part of PAVE (from the voice demo).
public enum AylaVoiceIcon: String, CaseIterable, Sendable {
    case hand
    case ayla
    case slot
    case toestemming
    case tijdelijk
    case kluis
    case plan
    case profiel
    case cv
    case werk
    case opleiding
    case vaardigheden
}

/// An icon to show at a point in Ayla's answer: `at` runs from 0 (start) to 1 (end).
/// The voice does not report word timings, so a word at 40% of the text shows at 40% of the speaking time.
public struct AylaVoiceCue: Equatable, Sendable {
    public var at: Double
    public var icon: AylaVoiceIcon

    public init(at: Double, icon: AylaVoiceIcon) {
        self.at = at
        self.icon = icon
    }

    /// The words that bring up an icon, as in the voice demo.
    static let words: [(AylaVoiceIcon, String)] = [
        (.hand, #"^\s*(hoi|hallo|hey|hee|goedemorgen|goedemiddag|goedenavond)\b|\b(doei|tot ziens)\b"#),
        (.ayla, #"\bayla\b"#),
        (.slot, #"\b(privacy|veilig\w*|beveilig\w*|afgeschermd|beschermd|gevoelige)\b"#),
        (.toestemming, #"\b(toestemming|akkoord|beslist|beslis\w*|regie)\b"#),
        (.tijdelijk, #"\b(tijdelijk\w*|intrek\w*|ingetrokken)\b"#),
        (.kluis, #"\bkluis\w*"#),
        (.plan, #"\b(plan|plannen|stappenplan|doel|doelen)\b"#),
        (.profiel, #"\bprofiel\w*"#),
        (.cv, #"\b(cv|cv's|sollicit\w*|motivatiebrief\w*)\b"#),
        (.werk, #"\b(vacature\w*|werkgever\w*|baan|banen|werkervaring|stage\w*)\b"#),
        (.opleiding, #"\b(opleiding\w*|diploma\w*|studie\w*|vmbo|mbo|hbo|universiteit)\b"#),
        (.vaardigheden, #"\b(vaardighe\w*|soft skills|talent\w*|sterke punten)\b"#),
    ]

    /// Two icons are at least this far apart (as a share of the answer), so the orb never flickers.
    static let minimumGap = 0.18

    /// The icons for an answer, in order of appearance.
    public static func cues(in text: String) -> [AylaVoiceCue] {
        guard !text.isEmpty else { return [] }
        let length = Double((text as NSString).length)
        var found: [AylaVoiceCue] = []
        for (icon, pattern) in words {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)) {
                found.append(AylaVoiceCue(at: Double(match.range.location) / length, icon: icon))
            }
        }
        var cues: [AylaVoiceCue] = []
        for cue in found.sorted(by: { $0.at < $1.at }) {
            if let last = cues.last, cue.icon == last.icon || cue.at - last.at < minimumGap { continue }
            cues.append(cue)
        }
        return cues
    }
}
