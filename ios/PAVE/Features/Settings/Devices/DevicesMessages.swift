import Foundation
import PAVECore

enum DevicesMessages {
    static let title = "Ingelogde apparaten"
    static let intro = "Hier zie je waar je met je PAVE-account bent ingelogd. Herken je een apparaat niet? Log het uit en wijzig je wachtwoord."
    static let thisDevice = "Dit apparaat"
    static let otherDevices = "Andere apparaten"
    static let noOthers = "Je bent nergens anders ingelogd."
    static let signOutAllOthers = "Overal anders uitloggen"
    static let signOutAllQuestion = "Uitloggen op alle andere apparaten?"
    static let signOutMessage = "Op dat apparaat moet je daarna opnieuw inloggen. Is PAVE daar nu open, dan kan dat tot een uur duren."
    static let notSetUpTitle = "Nog niet beschikbaar"
    static let notSetUpMessage = "Deze lijst werkt zodra PAVE er klaar voor is. Je kunt hieronder wel alvast overal anders uitloggen."
    static let unavailableTitle = "Geen apparaten in de demo"
    static let unavailableMessage = "Log in met je eigen account om te zien waar je bent ingelogd."
    static let loadFailedTitle = "De lijst kon niet laden"
    static let settingsRowMessage = "Bekijk waar je bent ingelogd en koppel je Apple Watch"

    static func signOutQuestion(_ device: SignedInDevice) -> String {
        "Uitloggen op \(name(of: device))?"
    }

    static func name(of device: SignedInDevice) -> String {
        switch device.client {
        case .paveApp:
            device.kind == .unknown ? "PAVE-app" : "PAVE-app op \(kindName(device.kind))"
        case .browser(let browser):
            device.kind == .unknown ? browser : "\(browser) op \(kindName(device.kind))"
        case .unknown:
            device.kind == .unknown ? "Onbekend apparaat" : kindName(device.kind)
        }
    }

    static func kindName(_ kind: SignedInDevice.Kind) -> String {
        switch kind {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .mac: "Mac"
        case .windows: "Windows"
        case .android: "Android"
        case .linux: "Linux"
        case .unknown: "onbekend apparaat"
        }
    }

    /// "Nu actief" or "Actief 2 uur geleden".
    static func activity(of device: SignedInDevice, now: Date = .now) -> String {
        guard !device.isCurrent, now.timeIntervalSince(device.lastActiveAt) >= 5 * 60 else { return "Nu actief" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.unitsStyle = .full
        return "Actief \(formatter.localizedString(for: device.lastActiveAt, relativeTo: now))"
    }

    /// "Ingelogd op 10 nov".
    static func signedIn(of device: SignedInDevice) -> String {
        "Ingelogd op \(device.signedInAt.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "nl_NL"))))"
    }

    static func message(for error: DevicesError) -> String {
        switch error {
        case .noConnection: "Geen verbinding. Probeer het zo nog een keer."
        case .notSignedIn: "Je bent niet meer ingelogd. Log opnieuw in."
        case .notAllowed: "Dit mag alleen na je tweestapsverificatie. Log opnieuw in."
        case .notSetUp: notSetUpMessage
        case .unavailable: "Dat lukte niet. Probeer het later nog een keer."
        }
    }
}
