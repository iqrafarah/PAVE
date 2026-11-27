import Foundation
import PAVECore

/// The words of Profiel en delen. Kept in docs/ui-teksten.md under "Profiel en delen".
enum SharingMessages {
    static let title = "Profiel"
    static let intro = "Jij bepaalt wat je deelt, met wie en hoe lang. Je kunt het altijd pauzeren of intrekken."
    static let live = "Nu gedeeld"
    static let earlier = "Eerder gedeeld"
    static let scan = "Scan een QR-code"
    static let scanHint = "Van een werkgever op een beurs, of een gedeeld profiel."
    static let report = "Wie keek er"
    static let reportHint = "Wie wat van je zag en wanneer, en wat nog te zien is."
    static let whoLookedActive = "Nu gedeeld"
    static let whoLookedViews = "Bekeken"
    static let whoLookedDownloads = "Gedownload"
    static let whoLookedIntro = "Iedere keer dat iemand iets opende wat je deelde, de afgelopen 30 dagen. Wat nog te zien is, stop je hier in één tik."
    static let whoLookedEmptyTitle = "Nog niemand keek"
    static let whoLookedEmpty = "Zodra iemand opent wat je deelde, zie je hier wie, wat en wanneer."
    static let whoLookedStillVisible = "Nog te zien"
    static let whoLookedStop = "Stop"
    static let whoLookedStopQuestion = "Stoppen met delen?"
    static func whoLookedStopLabel(_ who: String) -> String { "Stop delen met \(who)" }
    static func whoLookedStopHint(_ who: String) -> String { "\(who) kan het daarna niet meer openen. Wat al gedownload is, kan PAVE niet terughalen." }
    static func whoLookedWhat(_ downloaded: Bool, title: String) -> String { downloaded ? "Downloadde je cv of brief · \(title)" : "Bekeek \(title)" }
    static func whoLookedSaid(_ recipient: String) -> String { "Noemde zichzelf zo; je deelde dit met \(recipient)." }
    static func whoLookedUntil(_ date: Date, looks: Int) -> String {
        "Tot \(date.formatted(.dateTime.day().month(.wide).locale(PaveLanguageStore.current.locale))) · \(looks == 0 ? "nog niet bekeken" : looks == 1 ? "1 keer bekeken" : "\(looks) keer bekeken")"
    }
    static func whoLookedDay(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Vandaag" }
        if calendar.isDateInYesterday(date) { return "Gisteren" }
        let text = date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(PaveLanguageStore.current.locale))
        return text.prefix(1).uppercased() + text.dropFirst()
    }
    static let howItWorks = "Zo gaan we met je gegevens om"
    static let notSetUp = "Delen is nog niet beschikbaar in dit account."
    static let demoOnly = "Delen werkt alleen met een echt account."
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

    /// How often it was looked at, and when last: "2 keer bekeken · laatst 9:49".
    static func looksLine(_ share: ProfileShare) -> String {
        guard let last = share.looks.first?.date else { return looks(0) }
        return "\(looks(share.looks.count)) · laatst \(NotificationInboxRow.when(last))"
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
    static let backToAyla = "Terug naar Ayla"
    static let manage = "Beheren"
    static let fairOpenVacancy = "Bekijk de vacature"
    static let fairFound = "Gevonden"
    static let fairDay = "Mijn beursdag"
    static let fairDayHint = "Wat je vandaag scande en waar je solliciteerde"
    static let dayInvitations = "Uitnodigingen"
    static let dayLeft = "Hier liet je je kaartje achter"
    static let dayNext = "Nog te doen"
    static func dayNotApplied(_ name: String, stand: String?) -> String { "Je scande \(name)\(stand.map { " (\($0))" } ?? ""), maar solliciteerde nog niet" }
    static let dayEmpty = "Nog niets vandaag"
    static let dayEmptyHint = "Scan een stand of een poster met je camera of in PAVE. Alles van vandaag komt hier."
    static func dayInvitedFor(_ vacancy: String) -> String { "Gesprek: \(vacancy)" }
    static let dayAccept = "Ik kom"
    static let dayDecline = "Kan niet"
    static let dayAccepted = "Je hebt gezegd dat je komt."
    static let dayDeclined = "Je hebt laten weten dat je niet kunt."
    static let dayPractise = "Oefen met Ayla"
    static func dayStatus(_ application: FairApplication) -> String {
        switch (application.status, application.answer) {
        case (.invited, .accepted?): "Je komt"
        case (.invited, .declined?): "Afgezegd"
        case (.invited, nil): "Uitgenodigd"
        case (.declined, _): "Niet gekozen"
        default: "Achtergelaten"
        }
    }
    static let inboxTitle = "Werkgever-modus"
    static let inboxHint = "Zo ziet de werkgever wie er bij de stand solliciteerde. Hier speelt een medespeler de recruiter."
    static let inboxEmpty = "Nog niemand"
    static let inboxEmptyHint = "Laat iemand de poster of de stand scannen en snel solliciteren."
    static let inboxWrongKey = "Deze werkgeverssleutel klopt niet."
    static let inboxInvite = "Uitnodigen voor een gesprek"
    static func inboxInvited(_ date: Date?) -> String { "Uitgenodigd" + (date.map { " voor \(ApplyMessages.slot($0))" } ?? "") + ", wacht op antwoord" }
    static func inboxAccepted(_ date: Date?) -> String { "Komt" + (date.map { " op \(ApplyMessages.slot($0))" } ?? "") }
    static let inboxDeclined = "Kan niet op dat moment"
    static func inviteTitle(_ name: String) -> String { "\(name) uitnodigen" }
    static let inviteWhen = "Wanneer"
    static let inviteMessage = "Bericht"
    static let inviteMessagePrompt = "Bijvoorbeeld: meld je bij de servicebalie"
    static let inviteSend = "Verstuur"
    static let inviteFailed = "De uitnodiging kon niet worden verstuurd. Probeer het opnieuw."
    static let quickApply = "Snel solliciteren"
    static let quickApplyHeadline = "School of opleiding"
    static let quickApplyHeadlinePrompt = "Bijvoorbeeld: havo 4, Lorentz Casimir Lyceum"
    static let quickApplyWhy = "Waarom deze bijbaan"
    static let quickApplyWhyPrompt = "Twee of drie zinnen, in je eigen woorden"
    static let quickApplyAylaWrites = "Ayla schrijft mee"
    static let quickApplyWriting = "Ayla schrijft…"
    static let quickApplyFocus = "Dit is een korte reactie op een bijbaan, geen cv: twee korte zinnen in de ik-vorm over waarom ik deze bijbaan wil en wat ik meebreng."
    static let quickApplyPitch = "Vertel het liever? (niet verplicht)"
    static let quickApplyPitchStart = "Spreek je pitch in"
    static let quickApplyPitchStop = "Stop"
    static let quickApplyPitchHint = "Vertel in een halve minuut wie je bent. Het wordt tekst die je kunt aanpassen; de opname zelf wordt niet bewaard."
    static func quickApplyHonest(_ employer: String) -> String {
        "Je kaartje blijft in PAVE. \(employer) doet niet echt mee: een medespeler bekijkt het als werkgever."
    }
    static let quickApplySend = "Laat je kaartje achter"
    static let quickApplyAlso = "Wat ze verder mogen zien"
    static let quickApplyProfile = "Je profiel met bewijs"
    static func quickApplyProfileHint(_ count: Int) -> String {
        count == 0
            ? "Je kluis is nog leeg, dus er is geen profiel om te laten zien."
            : "Ze kunnen je \(count == 1 ? "bewijsstuk" : "\(count) bewijsstukken") en de bestanden inzien, twee weken lang. Stoppen kan altijd bij Profiel."
    }
    static func quickApplyShareTitle(_ employer: String) -> String { "Kaartje bij \(employer)" }
    static let inboxOpenProfile = "Bekijk profiel"
    static let notificationsFair = "Van de beurs"
    static let fairOpenApplication = "Opent je sollicitatie"
    static let fairDetailTitle = "Sollicitatie van de beurs"
    static let fairDetailInvitation = "Uitnodiging"
    static let fairDetailLeft = "Wat je achterliet"
    static let fairDetailPitch = "Je pitch"
    static let fairDetailWithProfile = "Meegestuurd. Stoppen kan bij Profiel, onder wat je deelt."
    static let fairDetailNoProfile = "Niet meegestuurd."
    static func fairDetailFooter(_ date: Date) -> String {
        "Achtergelaten op \(date.formatted(.dateTime.day().month(.wide).locale(PaveLanguageStore.current.locale))). Alles van je beursdag staat bij Profiel › Mijn beursdag."
    }
    static let fairDetailGone = "Niet meer gevonden"
    static let fairDetailGoneHint = "Deze sollicitatie staat niet meer in je lijst."
    static let quickApplyNeedsName = "Vul je naam in."
    static let quickApplyNeedsWhy = "Schrijf kort waarom je hier wilt werken, of spreek het in."
    static let fairVacancies = "Vacatures"
    static let fairShareBack = "Deel je profiel"
    static let leaveProfile = "Laat je profiel achter"
    static func leaveProfileHint(_ employer: String) -> String { "\(employer) ziet je kaartje en je profiel in de postbus van de stand, ook zonder vacature." }
    static let leaveProfileTitle = "Profiel achterlaten"
    static let leaveProfileWhy = "Wat zoek je? (niet verplicht)"
    static func leaveProfileSend(_ employer: String) -> String { "Laat achter bij \(employer)" }
    static let shareByCode = "Of deel met een QR-code"
    static let quickApplySentTitle = "Achtergelaten"
    static func quickApplySentText(_ employer: String, vacancy: String) -> String {
        "Je kaartje voor \(vacancy) staat klaar bij \(employer). Je krijgt een melding als je wordt uitgenodigd; alles staat in Mijn beursdag."
    }
    static let availability = "Wanneer kun je werken"
    static let maxHours = "Hoeveel uur per week, hoogstens"
    static func hours(_ value: Int) -> String { "\(value) uur" }
    /// What you chose, said back in one line under the cells.
    static func availabilitySummary(_ availability: Availability) -> String {
        if availability.isEmpty { return "Tik op de dagen dat je kunt en kies hoeveel uur." }
        let days = availability.days.count == 7 ? "Alle dagen" : availability.days.map { $0.rawValue }.joined(separator: ", ")
        let hours = availability.maxHours.map { "hoogstens \($0) uur per week" }
        return [days.isEmpty ? nil : days.prefix(1).uppercased() + days.dropFirst(), hours].compactMap(\.self).joined(separator: " · ")
    }
    static func day(_ day: Availability.Day) -> String {
        switch day {
        case .maandag: "ma"
        case .dinsdag: "di"
        case .woensdag: "wo"
        case .donderdag: "do"
        case .vrijdag: "vr"
        case .zaterdag: "za"
        case .zondag: "zo"
        }
    }
    static let applyFailed = "Je sollicitatie kon niet worden achtergelaten. Probeer het opnieuw."
    static let fairInvitedTitle = "Je bent uitgenodigd"
    static func fairInvitedBody(_ application: FairApplication, employer: String?) -> String {
        let when = application.invitedFor.map { " op \(ApplyMessages.slot($0))" } ?? ""
        guard let employer else { return "Voor een gesprek over \(application.vacancyTitle)\(when)." }
        return "\(employer) wil je spreken over \(application.vacancyTitle)\(when)."
    }
    static let fairLoading = "Even laden…"
    static func fairFoundAnnouncement(_ name: String) -> String { "Gevonden: \(name)" }
    static let fairNotFound = "Niet gevonden"
    static let fairLoadFailed = "Deze werkgever kon niet worden geladen. Probeer het opnieuw."
    static let fairNoService = "De beurs werkt alleen met een echt account."
    static let saving = "Bewaren…"
    static let detailTitle = "Hoeveel laat je zien"
    static let detailFull = "Uitgebreid"
    static let detailBrief = "Kort"
    static let detailFullHint = "Met beschrijving en vaardigheden"
    static let detailBriefHint = "Alleen titel, organisatie, periode en status"
    static let detailExplained = "Kort: alleen titel, organisatie, periode en status. Uitgebreid: ook de beschrijving en vaardigheden. Bestanden uit je kluis deel je niet."
    static let profiles = "Selecties"
    static let profilesHint = "Een selectie is wat je één keer kiest voor een soort ontvanger. Tik op een rij om hem samen te stellen of aan te passen, met Delen deel je hem."
    static let newProfile = "Nieuwe selectie"
    static let editProfile = "Selectie aanpassen"
    static let profileName = "Naam van de selectie"
    static let profileFor = "Voor wie"
    static let profileItems = "Wat erin staat"
    static let vaultEmptyTitle = "Je kluis is nog leeg"
    static let vaultEmpty = "Voeg eerst bewijs toe, zoals een diploma, stage of project. Daarna kies je hier wat je deelt."
    static let toVault = "Naar je kluis"
    static let more = "Meer"
    static func withFile(_ count: Int) -> String { count > 1 ? "Met de \(count) bestanden" : "Met bestand" }
    static func fileGoes(_ name: String) -> String { "Bestand \(name) meesturen" }
    static func filesGoing(_ names: [String]) -> String { "Bestanden die ze kunnen openen: \(names.joined(separator: ", "))" }
    static let checkFiles = "Bestanden"
    static func applicationOption(_ title: String) -> String { "\(title) · cv en brief" }
    static func applicationShareTitle(_ vacancy: Vacancy) -> String { "Sollicitatie \(vacancy.title) bij \(vacancy.company)" }
    static let moreOptions = "Meer opties"
    static let orApplication = "Of een sollicitatie"
    static func showAllApplications(_ count: Int) -> String { "Toon alle \(count)" }
    static let selectionSummary = "Over jou (niet verplicht)"
    static let selectionSummaryPrompt = "Twee of drie zinnen die ze als eerste lezen"
    static let filesNone = "Er gaan geen bestanden mee. Ze zien alleen wat er over je bewijs staat."
    static let tryAgain = "Opnieuw proberen"
    static let scanUnknown = "Dit is geen code van PAVE. Scan de QR-code op de stand of de poster."
    static let scanNoWeb = "Dit gedeelde profiel kan hier niet worden geopend. Open de link in je browser."
    static let scanUnavailable = "Scannen lukt hier niet. Geef PAVE toegang tot je camera bij Instellingen, of gebruik de Camera-app."
    static let documentsFailed = "Gedeeld, maar je cv of brief kon niet mee. Deel opnieuw vanuit Mijn sollicitatie als je ze erbij wilt."
    static let chooseSomething = "Kies minstens één bewijsstuk, of je cv of brief."
    static let fillWho = "Vul de naam van de ontvanger en de naam van wat je deelt in."
    static func profileProblem(_ problem: SavedProfile.Problem) -> String {
        switch problem {
        case .noName: "Geef je selectie een naam."
        case .nothingChosen: "Kies minstens één bewijsstuk."
        }
    }
    static let shareProfile = "Delen"
    static let saveProfile = "Bewaar selectie"
    static let deleteProfile = "Verwijder selectie"
    static func deleteProfileQuestion(_ name: String) -> String { "\(name) verwijderen?" }
    static let deleteProfileHint = "Wat je met deze selectie al deelde, blijft gedeeld tot je het intrekt."
    static func profileSummary(_ profile: SavedProfile) -> String {
        let count = profile.itemIDs.count
        let items = count == 1 ? "1 onderdeel" : "\(count) onderdelen"
        let files = profile.files.isEmpty ? nil : "\(profile.files.count) met bestand"
        let brief = profile.brief.isEmpty ? nil : "\(profile.brief.count) kort"
        return [items, files, brief].compactMap(\.self).joined(separator: " · ")
    }
    static let profileSaveFailed = "De selectie kon niet worden bewaard. Probeer het opnieuw."
    static let you = "Jij"
    static let quickShare = "Snel delen"
    static let quickShareIntro = "Laat iemand een QR-code scannen of stuur een link. Het werkt meteen en stopt vanzelf."
    static let quickShareWhat = "Wat deel je?"
    static let quickShareWhole = "Je profiel"
    static func quickShareWholeDetail(_ count: Int) -> String { count == 1 ? "1 bewijsstuk, kort" : "\(count) bewijsstukken, kort" }
    static let quickShareWho = "Met wie? (mag leeg)"
    static let quickShareWhoPrompt = "Bijvoorbeeld: Sanne van Jumbo"
    static let quickShareHowLong = "Hoe lang?"
    static let quickShareMake = "Maak QR-code"
    static let quickShareRecipient = "Snel gedeeld"
    static func quickShareTitle(_ what: String) -> String { "\(what), snel gedeeld" }
    static let quickShareSeesLink = "Bekijk wat zij zien"
    static let quickShareWaiting = "Nog niet bekeken"
    static func quickShareLooked(_ date: Date, by name: String?) -> String {
        let time = date.formatted(.dateTime.hour().minute().locale(PaveLanguageStore.current.locale))
        return name.map { "Bekeken door \($0) om \(time)" } ?? "Bekeken om \(time)"
    }
    static func quickShareEnds(_ date: Date) -> String {
        "Stopt vanzelf op \(date.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute().locale(PaveLanguageStore.current.locale)))"
    }
    static let quickShareStop = "Stop met delen"
    static func quickShareGoes(_ items: Int, files: Int) -> String {
        let evidence = items == 1 ? "1 bewijsstuk" : "\(items) bewijsstukken"
        return files == 0 ? "Je deelt \(evidence)." : "Je deelt \(evidence), \(files) met bestand."
    }
    static let quickShareAdjust = "Pas aan"
    static let quickShareAdjustTitle = "Wat deel je?"
    static let quickShareAdjustHint = "Zet aan wat ze mogen zien. Met bestand kunnen ze het bewijs zelf openen, zoals je cijferlijst of diploma."
    static func recipientVerified(_ count: Int) -> String { "\(count) geverifieerd" }
    static func recipientItems(_ count: Int) -> String { count == 1 ? "1 bewijsstuk" : "\(count) bewijsstukken" }
    static func recipientFor(_ share: ProfileShare) -> String {
        "Gedeeld met \(share.recipient) · \(remaining(share).lowercased()) · \(share.allowsDownload ? "mag downloaden" : "alleen bekijken")"
    }
    static let recipientHasFile = "Bestand"
    static let photo = "Je profielfoto"
    static let recipientFiles = "Bestanden"
    static let recipientOpen = "Open"
    static let recipientPdf = "pdf"
    static let recipientNoFile = "Hier gaat geen bestand mee. Vraag het aan degene die dit deelde als je meer wilt zien."
    static func recipientVerifiedBy(_ organisation: String?) -> String {
        organisation.map { "Geverifieerd door \($0)" } ?? "Geverifieerd door de organisatie zelf"
    }
    static let recipientFooter = "Geverifieerd betekent: bevestigd door de organisatie zelf, in PAVE. Niet geverifieerd is zelf toegevoegd. Bestanden open je alleen zolang er gedeeld wordt."
    static let quickShareStoppedTitle = "Gestopt met delen"
    static let quickShareAgain = "Opnieuw delen"
    static let quickShareStopped = "De link en de QR-code werken niet meer. Wie ze nu opent, ziet niets van je."
    static let quickShareEmpty = "Er is nog niets om te delen. Voeg eerst bewijs toe aan je kluis."
    static func evidenceCount(_ count: Int, verified: Int) -> String {
        let items = count == 1 ? "1 bewijsstuk" : "\(count) bewijsstukken"
        return verified == 0 ? items : "\(items) · \(verified) geverifieerd"
    }
    static let scanAgain = "Opnieuw scannen"
    static let showShare = "Bekijk wat je deelt"
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
    static let applicationNoneHint = "Je hebt nog geen cv of brief. Maak een sollicitatie, dan deel je hem daarna vanuit Mijn sollicitatie."
    static let notNeeded = "Niet nodig voor deze ontvanger"
    static let fromVault = "Uit je kluis"
    static let recipientName = "Naam van de ontvanger"
    static let recipientNamePrompt = "Bijvoorbeeld: Sanne de Vries"
    static let recipientOrganisation = "Organisatie"
    static let recipientOrganisationPrompt = "Bijvoorbeeld: Kade Consultancy"
    static let shareTitle = "Naam van wat je deelt"
    static let purpose = "Waarvoor"
    static let purposePrompt = "Bijvoorbeeld: sollicitatie Junior IT-consultant"
    static let shareTitlePrompt = "Bijvoorbeeld: mijn cv voor Kade"
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

    static let nameMissing = "Nog niet ingevuld bij Instellingen › Account"
    static let headlinePrompt = "Bijvoorbeeld: student HBO-ICT"
    static let recipientMay = "Wat de ontvanger mag"
    static let checkWhat = "Wat"
    static let checkWho = "Met wie"
    static let checkPurpose = "Waarvoor"
    static let checkUntil = "Tot en met"
    static let checkRights = "Mag"
    static let checkFooter = "Je ziet wanneer iemand kijkt, en je kunt het altijd pauzeren of intrekken."
    static func checkWhatValue(_ draft: ShareDraft, items: Int) -> String {
        var parts: [String] = []
        if items > 0 { parts.append(items == 1 ? "1 bewijsstuk" : "\(items) bewijsstukken") }
        if draft.content.cv != nil { parts.append("je cv") }
        if draft.content.letter != nil { parts.append("je brief") }
        let text = parts.isEmpty ? "je gegevens" : parts.joined(separator: ", ").replacingLast(", ", with: " en ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }
    static func checkWhoValue(_ draft: ShareDraft) -> String {
        [draft.recipientName, draft.recipientOrganisation == draft.recipientName ? "" : draft.recipientOrganisation]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: ", ")
    }
    static func checkUntilValue(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(PaveLanguageStore.current.locale))
    }
    static func checkRightsValue(_ allowsDownload: Bool) -> String { allowsDownload ? "Bekijken en downloaden" : "Alleen bekijken" }

    static func summary(_ draft: ShareDraft, items: Int, until: Date) -> String {
        var parts: [String] = []
        if items > 0 { parts.append(items == 1 ? "1 bewijsstuk" : "\(items) bewijsstukken") }
        if draft.content.cv != nil { parts.append("je cv") }
        if draft.content.letter != nil { parts.append("je brief") }
        let what = parts.isEmpty ? "je gegevens" : parts.joined(separator: ", ").replacingLast(", ", with: " en ")
        let who = draft.recipientOrganisation.isEmpty ? draft.recipientName : "\(draft.recipientName) van \(draft.recipientOrganisation)"
        let when = until.formatted(.dateTime.day().month(.wide).locale(PaveLanguageStore.current.locale))
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
    static let stopAllQuestion = "Stoppen met delen?"
    static func stopAllHint(_ count: Int) -> String {
        count == 1 ? "Je deelt nu 1 keer iets. Pauzeren kun je terugdraaien, intrekken niet." : "Je deelt nu \(count) keer iets. Pauzeren kun je terugdraaien, intrekken niet."
    }
    static let pauseAll = "Alles pauzeren"
    static let revokeAll = "Alles intrekken"
    static let pauseAllReason = "Bevestig dat je alles pauzeert wat je deelt"
    static let revokeAllReason = "Bevestig dat je alles intrekt wat je deelt"
    static let nothingToStop = "Je deelt nu niets."
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
