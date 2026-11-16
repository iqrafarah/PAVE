import Foundation

enum WatchConnectMessages {
    /// The Watch stays out of sight until it is presented; turn this on to show it in Ingelogde apparaten again.
    static let isShown = false

    static let title = "Apple Watch koppelen"
    static let message = "Praat met Ayla vanaf je pols. Je Watch krijgt toegang via deze iPhone en je kunt hem altijd weer ontkoppelen."
    static let connectingTitle = "Koppelen…"
    static let connectingMessage = "Je iPhone geeft je Watch toegang tot PAVE."
    static let connectedTitle = "Je Watch is gekoppeld"
    static let noWatchTitle = "Geen Apple Watch gevonden"
    static let noWatchMessage = "Koppel eerst een Apple Watch aan deze iPhone in de Watch-app."
    static let appMissingTitle = "Zet PAVE op je Apple Watch"
    static let appMissingMessage = "Open de Watch-app op je iPhone, ga naar Beschikbare apps en installeer PAVE. Kom daarna terug."
    static let signInFirst = "Log eerst in op deze iPhone."
    static let disconnectQuestion = "Apple Watch ontkoppelen?"
    static let disconnectMessage = "Je Watch heeft dan geen toegang meer tot PAVE. Je kunt hem later weer koppelen."
    static let rowTitle = "Apple Watch"
    static let rowDisconnected = "Koppel je Watch om met Ayla te praten"
    static let rowNoWatch = "Geen Apple Watch gekoppeld aan deze iPhone"
    static let rowAppMissing = "Zet PAVE op je Watch om te koppelen"
    /// The same texts as on the Watch itself (WatchMessages), for the Watch screen in the connect animation.
    static let watchNotConnectedTitle = "Koppel je Watch"
    static let watchNotConnectedMessage = "Open PAVE op je iPhone en kies Instellingen › Ingelogde apparaten."
    static let watchTapToTalk = "Tik op Ayla en praat"

    static func connectedMessage(since date: Date?) -> String {
        "Tik op Ayla op je Watch en stel je vraag. Je ziet je Watch ook bij Ingelogde apparaten."
    }

    /// The line under Apple Watch in Instellingen.
    static func rowDetail(_ model: WatchConnectionModel, now: Date = .now) -> String {
        if let connection = model.connection { return activity(connection, now: now) }
        switch model.availability {
        case .noWatch: return rowNoWatch
        case .appMissing: return rowAppMissing
        case .ready: return rowDisconnected
        }
    }

    /// "Nu actief", "Actief 5 minuten geleden", or "Nog niet gebruikt" before the Watch asked for anything.
    static func activity(_ connection: WatchConnection, now: Date = .now) -> String {
        guard let lastActive = connection.lastActiveAt else { return "Nog niet gebruikt" }
        guard now.timeIntervalSince(lastActive) >= 5 * 60 else { return "Nu actief" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.unitsStyle = .full
        return "Actief \(formatter.localizedString(for: lastActive, relativeTo: now))"
    }

    /// "Via deze iPhone, gekoppeld op 12 nov".
    static func connectedVia(_ connection: WatchConnection) -> String {
        "Via deze iPhone, gekoppeld op \(connection.connectedAt.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "nl_NL"))))"
    }
}
