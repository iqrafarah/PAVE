import Foundation
import Testing
@testable import PAVECore

@Suite("What the vacancy asks for, set against the CV")
struct ApplicationCoverageTests {
    private let vacancy = Vacancy(
        id: "v", title: "Junior iOS-ontwikkelaar", company: "Appwerk", source: .adzuna,
        matches: [.init(skill: "Swift", requirement: "Kennis van Swift"), .init(skill: "Scrum", requirement: "Je werkt in sprints"), .init(skill: "Git", requirement: "Versiebeheer")],
        skillGap: [.init(skill: "CI/CD", requirement: "Ervaring met pipelines")]
    )

    private var items: [VaultItem] {
        [
            VaultItem(id: "a", category: .internships, title: "Stage", organisationName: "Pixelwerk", status: .verified, skills: ["swift"]),
            VaultItem(id: "b", category: .certificates, title: "PSM I", organisationName: "Scrum.org", skills: ["Scrum"]),
            VaultItem(id: "c", category: .diplomas, title: "HBO-ICT", status: .verified),
        ]
    }

    @Test("Shown by evidence on the CV, left off, only named, or not in the vault")
    func everyRequirementHasItsState() {
        var draft = ApplicationBuilder.draft(for: vacancy, items: items, name: "Daaf")
        draft.cv.skills = ["Swift", "Scrum", "Git"]
        let certificate = draft.cv.sections.flatMap(\.entries).first { $0.sourceItemID == "b" }!
        ApplicationProposal.apply([certificate.id: false], to: &draft)
        let found = ApplicationCoverage.requirements(of: draft, items: items)
        #expect(found.map(\.skill) == ["Swift", "Scrum", "Git", "CI/CD"])
        #expect(found[0].state == .shown(["Stage"]))
        #expect(found[1].state == .available([certificate.id]))
        #expect(found[2].state == .named)
        #expect(found[3].state == .missing)
        #expect(found.filter(\.isCovered).count == 2)
        #expect(found[3].text == "Ervaring met pipelines")
    }

    @Test("The tick is for verified evidence that the entry still describes")
    func verifiedOnlyWhileTheEntrySaysWhatWasVerified() {
        var draft = ApplicationBuilder.draft(for: vacancy, items: items, name: "Daaf")
        ApplicationVerification.mark(&draft, items: items)
        func entry(_ source: String) -> CVEntry { draft.cv.sections.flatMap(\.entries).first { $0.sourceItemID == source }! }
        #expect(entry("a").isVerified)
        #expect(!entry("b").isVerified)
        #expect(ApplicationVerification.showsTick(draft))
        // What was done there is the user's own; the title is what was verified.
        let section = draft.cv.sections.firstIndex { $0.kind == .experience }!
        draft.cv.sections[section].entries[0].description = "Bouwde een app."
        ApplicationVerification.mark(&draft, items: items)
        #expect(entry("a").isVerified)
        draft.cv.sections[section].entries[0].title = "Senior stage"
        ApplicationVerification.mark(&draft, items: items)
        #expect(!entry("a").isVerified)
        draft.showsVerified = false
        #expect(!ApplicationVerification.showsTick(draft))
    }

    @Test("A draft kept before the tick existed still opens, and the tick is never read from the file")
    func olderDraftsOpen() throws {
        var draft = ApplicationBuilder.draft(for: vacancy, items: items, name: "Daaf")
        ApplicationVerification.mark(&draft, items: items)
        let back = try JSONDecoder().decode(ApplicationDraft.self, from: JSONEncoder().encode(draft))
        #expect(back.cv.sections.flatMap(\.entries).allSatisfy { !$0.isVerified })
        #expect(back.marksVerified)
    }
}

@Suite("Keeping track of an application")
struct ApplicationTrackingTests {
    @Test("A draft kept before tracking existed opens as a concept, and tracking survives being stored")
    func trackingIsStoredAndOptional() throws {
        let vacancy = Vacancy(id: "v", title: "Dev", company: "Appwerk", source: .adzuna)
        var draft = ApplicationBuilder.draft(for: vacancy, items: [], name: "Daaf")
        #expect(draft.progress == ApplicationTracking())
        draft.tracking = ApplicationTracking(status: .interview, deadline: Date(timeIntervalSince1970: 1_800_000_000), note: "Bellen op dinsdag")
        let back = try JSONDecoder().decode(ApplicationDraft.self, from: JSONEncoder().encode(draft))
        #expect(back.progress.status == .interview)
        #expect(back.progress.note == "Bellen op dinsdag")
        let unknown = try JSONDecoder().decode(ApplicationStatus.self, from: Data("\"onbekend\"".utf8))
        #expect(unknown == .concept)
    }
}

@Suite("Deadlines and reminders of applications")
struct ApplicationReminderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return calendar
    }
    private func date(_ day: Int, _ hour: Int = 12, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
    private func draft(_ id: String, _ tracking: ApplicationTracking) -> ApplicationDraft {
        var draft = ApplicationBuilder.draft(for: Vacancy(id: id, title: "Dev", company: "Appwerk", source: .adzuna), items: [], name: "Daaf")
        draft.tracking = tracking
        return draft
    }

    @Test("A deadline is overdue, today or so many days away")
    func deadlineDistance() {
        let now = date(24, 15)
        #expect(ApplicationDeadline.of(date(21, 9), now: now, calendar: calendar) == .overdue(days: 3))
        #expect(ApplicationDeadline.of(date(24, 23), now: now, calendar: calendar) == .today)
        #expect(ApplicationDeadline.of(date(27, 1), now: now, calendar: calendar) == .upcoming(days: 3))
    }

    @Test("A concept with a deadline reminds the day before and on the day; sent reminds a week later")
    func plan() {
        let now = date(24, 8)
        let concept = draft("a", ApplicationTracking(deadline: date(30, 17), remindsMe: true))
        let sent = draft("b", ApplicationTracking(status: .sent, changedAt: date(20, 14), history: [], remindsMe: true))
        let found = ApplicationReminders.plan([concept, sent], now: now, calendar: calendar)
        #expect(found.map(\.id) == ["application.b.followUp", "application.a.deadlineTomorrow", "application.a.deadlineToday"])
        #expect(found[0].date == date(27, 10))
        #expect(found[1].date == date(29, 9))
        #expect(found[2].date == date(30, 9))
    }

    @Test("Nothing without the user's say-so, nothing in the past and nothing for what is done")
    func quiet() {
        let now = date(24, 8)
        let off = draft("a", ApplicationTracking(deadline: date(30), remindsMe: false))
        let past = draft("b", ApplicationTracking(deadline: date(24, 17), remindsMe: true))
        let done = draft("c", ApplicationTracking(status: .interview, deadline: date(30), changedAt: date(1), remindsMe: true))
        let found = ApplicationReminders.plan([off, past, done], now: now, calendar: calendar)
        // The day before is past; the day itself is still ahead.
        #expect(found.map(\.id) == ["application.b.deadlineToday"])
    }

    @Test("Setting a status keeps when, and the same status again changes nothing")
    func history() {
        var tracking = ApplicationTracking()
        tracking.set(.sent, at: date(20))
        tracking.set(.sent, at: date(21))
        tracking.set(.interview, at: date(25))
        #expect(tracking.history.map(\.status) == [.sent, .interview])
        #expect(tracking.changedAt == date(25))
    }

    @Test("Tracking kept by the first version, without history or reminders, still opens")
    func olderTracking() throws {
        let old = Data(#"{"status":"sent","note":"Bellen"}"#.utf8)
        let tracking = try JSONDecoder().decode(ApplicationTracking.self, from: old)
        #expect(tracking.status == .sent)
        #expect(tracking.note == "Bellen")
        #expect(tracking.history.isEmpty)
        #expect(!tracking.remindsMe)
    }
}
