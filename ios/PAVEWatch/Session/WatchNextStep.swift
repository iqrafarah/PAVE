import Foundation
import PAVECore

/// The next step with your applications, as the iPhone sent it: kept until it passes or the iPhone sends another.
enum WatchNextStep {
    private static let key = "watchNextStep"

    /// From what the iPhone sent: a step, nil to clear it, or no change.
    enum Update { case show(NextStep), clear }

    static func update(from userInfo: [String: Any]) -> Update? {
        guard let value = userInfo["nextStep"] as? [String: Any] else { return nil }
        if value["clear"] as? Bool == true { return .clear }
        guard let data = value["step"] as? Data, let step = try? JSONDecoder().decode(NextStep.self, from: data) else { return nil }
        return .show(step)
    }

    static func load(now: Date = .now) -> NextStep? {
        guard let data = UserDefaults.standard.data(forKey: key), let step = try? JSONDecoder().decode(NextStep.self, from: data) else { return nil }
        return step.date > now ? step : nil
    }

    static func save(_ step: NextStep?) {
        if let step, let data = try? JSONEncoder().encode(step) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// "Gesprek bij Jumbo", "Geef antwoord aan Jumbo", "Deadline Kade".
    static func title(_ step: NextStep) -> String {
        switch step.kind {
        case .talk: "Gesprek bij \(step.company)"
        case .answer: "Uitnodiging van \(step.company)"
        case .deadline: "Deadline \(step.company)"
        }
    }

    static func when(_ step: NextStep) -> String {
        let dutch = Locale(identifier: "nl_NL")
        let time = step.date.formatted(.dateTime.hour().minute().locale(dutch))
        let calendar = Calendar.current
        let day = calendar.isDateInToday(step.date) ? "Vandaag" : calendar.isDateInTomorrow(step.date) ? "Morgen"
            : step.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(dutch))
        let base = "\(day) \(time)"
        return step.kind == .answer ? "\(base) · antwoord op je iPhone" : base
    }
}
