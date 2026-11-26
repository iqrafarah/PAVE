import Foundation

/// The closing date of a vacancy, when the text PAVE has of it says one ("reageren vóór 12 december",
/// "sluitingsdatum: 12-12-2026"). Read on the device from that text only: no guess, and nothing when the text does not
/// say it. The sentence it comes from goes along, so the user sees where it was read.
public enum VacancyDeadlineFinder {
    public struct Found: Equatable, Sendable {
        public let date: Date
        /// The words around it, as they are in the vacancy.
        public let quote: String
    }

    /// Words that make a date a closing date when they come just before it.
    static let keywords = ["sluitingsdatum", "deadline", "reageer", "reageren", "solliciteer", "solliciteren", "uiterlijk", "vóór", "voor", "t/m", "tot en met", "tot"]

    static let months: [String: Int] = [
        "januari": 1, "jan": 1, "februari": 2, "feb": 2, "maart": 3, "mrt": 3, "april": 4, "apr": 4, "mei": 5,
        "juni": 6, "jun": 6, "juli": 7, "jul": 7, "augustus": 8, "aug": 8, "september": 9, "sep": 9, "sept": 9,
        "oktober": 10, "okt": 10, "november": 11, "nov": 11, "december": 12, "dec": 12,
    ]

    private static let numeric = try! NSRegularExpression(pattern: #"\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})\b"#)
    private static let written = try! NSRegularExpression(
        pattern: #"\b(\d{1,2})\s+(januari|februari|maart|april|mei|juni|juli|augustus|september|oktober|november|december|sept|jan|feb|mrt|apr|jun|jul|aug|sep|okt|nov|dec)\.?(?:\s+(\d{4}))?\b"#,
        options: .caseInsensitive
    )

    public static func find(in text: String, now: Date, calendar: Calendar = .current) -> Found? {
        let source = text as NSString
        var candidates: [(range: NSRange, date: Date)] = []
        let whole = NSRange(location: 0, length: source.length)
        for match in numeric.matches(in: text, range: whole) {
            guard let day = Int(source.substring(with: match.range(at: 1))), let month = Int(source.substring(with: match.range(at: 2))),
                  var year = Int(source.substring(with: match.range(at: 3))) else { continue }
            if year < 100 { year += 2000 }
            if let date = makeDate(day: day, month: month, year: year, calendar: calendar) { candidates.append((match.range, date)) }
        }
        for match in written.matches(in: text, range: whole) {
            guard let day = Int(source.substring(with: match.range(at: 1))),
                  let month = months[source.substring(with: match.range(at: 2)).lowercased()] else { continue }
            let yearRange = match.range(at: 3)
            if yearRange.location != NSNotFound, let year = Int(source.substring(with: yearRange)) {
                if let date = makeDate(day: day, month: month, year: year, calendar: calendar) { candidates.append((match.range, date)) }
            } else {
                // Without a year: the first time that day comes, from today on.
                let thisYear = calendar.component(.year, from: now)
                if let date = makeDate(day: day, month: month, year: thisYear, calendar: calendar) {
                    let isPast = date < calendar.startOfDay(for: now)
                    if let next = isPast ? makeDate(day: day, month: month, year: thisYear + 1, calendar: calendar) : date {
                        candidates.append((match.range, next))
                    }
                }
            }
        }
        let today = calendar.startOfDay(for: now)
        for candidate in candidates.sorted(by: { $0.range.location < $1.range.location }) where candidate.date >= today {
            let start = max(0, candidate.range.location - 40)
            let before = source.substring(with: NSRange(location: start, length: candidate.range.location - start)).lowercased()
            guard keywords.contains(where: { before.contains($0) }) else { continue }
            return Found(date: candidate.date, quote: sentence(around: candidate.range, in: source))
        }
        return nil
    }

    private static func makeDate(day: Int, month: Int, year: Int, calendar: Calendar) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day), (2000...2100).contains(year) else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components), calendar.component(.day, from: date) == day else { return nil }
        return date
    }

    /// The sentence the date is in, at most about 140 characters.
    private static func sentence(around range: NSRange, in text: NSString) -> String {
        let ends = CharacterSet(charactersIn: ".!?\n")
        var start = range.location
        while start > 0, start > range.location - 100 {
            let character = text.substring(with: NSRange(location: start - 1, length: 1))
            if character.rangeOfCharacter(from: ends) != nil, start < range.location - 1 { break }
            start -= 1
        }
        var end = range.location + range.length
        while end < text.length, end < range.location + range.length + 60 {
            let character = text.substring(with: NSRange(location: end, length: 1))
            if character.rangeOfCharacter(from: ends) != nil { break }
            end += 1
        }
        return text.substring(with: NSRange(location: start, length: end - start)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
