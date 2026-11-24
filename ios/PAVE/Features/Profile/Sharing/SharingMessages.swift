import Foundation
import PAVECore

/// The words of Profiel en delen. Kept in docs/ui-teksten.md under "Profiel en delen".
enum SharingMessages {
    static let title = "Profiel"
    static let intro = "Jij bepaalt wat je deelt, met wie en hoe lang. Je kunt het altijd pauzeren of intrekken."
    static let live = "Nu gedeeld"
    static let earlier = "Eerder gedeeld"
    static let newShare = "Iets delen"
    static let scan = "Scan een QR-code"
    static let scanHint = "Van een werkgever op een beurs, of een gedeeld profiel."
    static let report = "Delen-rapport"
    static let reportHint = "Wie wat de afgelopen 30 dagen heeft bekeken."
    static let howItWorks = "Zo gaan we met je gegevens om"
    static let notSetUp = "Delen is nog niet beschikbaar in dit account."
    static let demoOnly = "Delen werkt alleen met een echt account, niet in de demo."
    static let loadFailed = "Je gedeelde profielen konden niet worden geladen. Probeer het zo opnieuw."
    static let actionFailed = "Dat lukte niet. Probeer het zo opnieuw."
    static let nothingShared = "Je deelt nu niets"
    static let nothingSharedHint = "Kies hieronder voor wie je iets wilt delen. Jij kiest per onderdeel wat erin staat."

    static func template(_ template: ShareTemplate) -> String {
        switch template {
        case .employer: "Werkgever"
        case .education: "Onderwijs"
        case .municipality: "Gemeente"
        case .fair: "Banenbeurs"
        }
    }

    static func templateHint(_ template: ShareTemplate) -> String {
        switch template {
        case .employer: "Cv, brief en wat je hebt gedaan, voor een sollicitatie."
        case .education: "Diploma's, certificaten en projecten, voor een opleiding."
        case .municipality: "Wat je hebt behaald en gewerkt, voor de gemeente."
        case .fair: "Een korte kaart om te laten scannen op een beurs."
        }
    }

    static func remaining(_ share: ProfileShare, now: Date = .now) -> String {
        switch share.state(at: now) {
        case .revoked: return "Ingetrokken"
        case .expired: return "Verlopen"
        case .paused: return "Gepauzeerd"
        case .active:
            let hours = share.expiresAt.timeIntervalSince(now) / 3600
            if hours < 24 { return hours < 1 ? "Nog minder dan een uur" : "Nog \(Int(hours)) uur" }
            let days = Int((hours / 24).rounded(.up))
            return days == 1 ? "Nog 1 dag" : "Nog \(days) dagen"
        }
    }

    static func looks(_ count: Int) -> String {
        switch count {
        case 0: "Nog niet bekeken"
        case 1: "1 keer bekeken"
        default: "\(count) keer bekeken"
        }
    }

    // Composer
    static let stepWhat = "Wat deel je?"
    static let stepWho = "Met wie en waarvoor?"
    static let stepHowLong = "Hoe lang?"
    static let stepCheck = "Controleer en deel"
    static let next = "Volgende"
    static let back = "Terug"
    static let cancel = "Annuleer"
    static let discard = "Weggooien"
    static let discardQuestion = "Wil je stoppen met delen? Er is nog niets gedeeld."
    static let aboutYou = "Over jou"
    static let name = "Naam"
    static let email = "E-mail"
    static let headline = "Regel onder je naam"
    static let application = "Cv en brief"
    static let noApplication = "Geen sollicitatie"
    static let applicationHint = "Uit Mijn sollicitatie, zoals je ze hebt gemaakt."
    static let notNeeded = "Niet nodig voor deze ontvanger"
    static let fromVault = "Uit je kluis"
    static let recipientName = "Naam van de ontvanger"
    static let recipientNamePrompt = "Bijvoorbeeld: Sanne de Vries"
    static let recipientOrganisation = "Organisatie"
    static let recipientOrganisationPrompt = "Bijvoorbeeld: Kade Consultancy"
    static let shareTitle = "Naam van wat je deelt"
    static let purpose = "Waarvoor"
    static let purposePrompt = "Bijvoorbeeld: sollicitatie Junior IT-consultant"
    static let fairRecipient = "Bezoekers van mijn stand"
    static func duration(_ duration: ShareDuration) -> String {
        switch duration {
        case .day: "1 dag"
        case .week: "1 week"
        case .twoWeeks: "2 weken"
        case .month: "1 maand"
        case .threeMonths: "3 maanden"
        }
    }
    static let allowsDownload = "Mag downloaden"
    static let downloadHint = "Zet je dit aan, dan kan de ontvanger je cv en brief als pdf bewaren. Bewaren kun je daarna niet meer terugdraaien. Staat het uit, dan kan de ontvanger alleen kijken; helemaal tegenhouden dat iemand een schermafbeelding maakt, kan geen enkele app."

    static func summary(_ draft: ShareDraft, items: Int, until: Date) -> String {
        var parts: [String] = []
        if items > 0 { parts.append(items == 1 ? "1 bewijsstuk" : "\(items) bewijsstukken") }
        if draft.content.cv != nil { parts.append("je cv") }
        if draft.content.letter != nil { parts.append("je brief") }
        let what = parts.isEmpty ? "je gegevens" : parts.joined(separator: ", ").replacingLast(", ", with: " en ")
        let who = draft.recipientOrganisation.isEmpty ? draft.recipientName : "\(draft.recipientName) van \(draft.recipientOrganisation)"
        let when = until.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "nl_NL")))
        let rights = draft.allowsDownload ? "mag ze bekijken en downloaden" : "mag ze alleen bekijken"
        return "\(who) kan \(what) zien tot en met \(when), en \(rights). Je ziet wanneer iemand kijkt, en je kunt het altijd intrekken."
    }
    static let confirm = "Deel"
    static func confirmWith(_ kind: String) -> String { "Deel met \(kind)" }
    static func biometricReason(_ recipient: String) -> String { "Bevestig dat je deelt met \(recipient)" }
    static let sharing = "Bezig met delen…"
    static let shared = "Gedeeld"
    static func sharedHint(_ recipient: String) -> String { "Laat \(recipient) de QR-code scannen of stuur de link." }

    // Detail
    static let link = "Link"
    static let copy = "Kopieer link"
    static let sendLink = "Stuur link"
    static let showOnWatch = "Toon op Apple Watch"
    static let shownOnWatch = "Staat op je Apple Watch"
    static let pause = "Pauzeer"
    static let resume = "Hervat"
    static let extend = "Verleng"
    static let revoke = "Intrekken"
    static func revokeQuestion(_ recipient: String) -> String { "Delen met \(recipient) intrekken?" }
    static let revokeHint = "De link werkt dan niet meer, ook niet als je opnieuw deelt. Wat de ontvanger al heeft gedownload, kan PAVE niet terughalen."
    static let preview = "Zo ziet de ontvanger het"
    static let previewLabel = "Voorbeeld: zo ziet de ontvanger je gegevens op de webpagina."
    static let looksTitle = "Wie keek er"
    static let noLooks = "Nog niemand heeft gekeken."
    static func look(_ look: ShareLook) -> String {
        let who = [look.viewerName, look.viewerOrganisation].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        let what = look.action == .download ? "Gedownload" : "Bekeken"
        return who.isEmpty ? what : "\(what) door \(who)"
    }
    static let lookUnchecked = "Een naam die de bezoeker zelf heeft ingevuld, niet gecontroleerd."
    static let localOnly = "De webpagina draait nu alleen op deze computer. Zodra de site online staat, werkt de link ook voor anderen."
    static let noWebsite = "De webpagina voor ontvangers staat nog niet online, dus de link werkt nog niet buiten PAVE."

    // Advice
    static func advice(_ reason: ShareAdvice.Suggestion.Reason) -> String {
        switch reason {
        case .applicationEnded(.rejected): "Je sollicitatie is afgewezen. Toegang intrekken?"
        case .applicationEnded: "Je sollicitatie is afgerond. Toegang intrekken?"
        case .deadlinePassed: "De deadline is voorbij en je sollicitatie is niet verstuurd. Toegang intrekken?"
        case .endsSoon: "Verloopt binnen een dag. Verlengen?"
        }
    }

    // Report
    static func reportSummary(_ report: ShareAdvice.Report) -> String {
        "\(report.active) actief, \(report.paused) gepauzeerd. \(report.looks) keer bekeken en \(report.downloads) keer gedownload in de afgelopen 30 dagen."
    }

    // Privacy
    static let privacyText = [
        ("Wat delen betekent", "De ontvanger krijgt tijdelijk toegang tot alleen wat jij aanzet. Na de einddatum, na pauzeren of na intrekken ziet de ontvanger niets meer."),
        ("Wat de ontvanger mag", "Kijken, en alleen als jij het toestaat ook je cv en brief downloaden. Een download kan PAVE niet terughalen."),
        ("Wat er bewaard blijft", "Je bewijs blijft in je kluis; de ontvanger ziet het zoals het daar nu staat. Wat je apart deelt, zoals je cv, wist PAVE zodra delen stopt."),
        ("Wie er keek", "Elke keer dat iemand kijkt of downloadt, zie je dat in het logboek. Een naam die een bezoeker invult, controleren we niet."),
        ("Ayla en delen zijn twee dingen", "Dat Ayla iets uit je kluis mag bekijken, betekent niet dat je het met anderen deelt. Delen doe je altijd hier, zelf."),
        ("Wie PAVE maakt", "PAVE is een prototype van een Fontys-studententeam voor Npuls en SURF, geen bestaand product. Gebruik voorbeeldgegevens, geen echte persoonsgegevens."),
    ]
}

private extension String {
    func replacingLast(_ target: String, with replacement: String) -> String {
        guard let range = range(of: target, options: .backwards) else { return self }
        return replacingCharacters(in: range, with: replacement)
    }
}
