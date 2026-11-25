import Foundation
import Testing
@testable import PAVECore

struct ApplicationInvitationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return calendar
    }

    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    @Test func itArrivesAFewMinutesAfterSendingWithThreeWorkingDayMoments() {
        // Thursday 26 November 2026, 15:00 in Amsterdam.
        let invitation = ApplicationInvitation.after(sentAt: date("2026-11-26T14:00:00Z"), calendar: calendar)
        #expect(invitation.arrivesAt == date("2026-11-26T14:03:00Z"))
        let days = invitation.slots.map { calendar.component(.weekday, from: $0) }
        #expect(!days.contains(1) && !days.contains(7))
        #expect(invitation.slots.map { calendar.component(.hour, from: $0) } == [10, 14, 11])
        #expect(invitation.slots.first == date("2026-11-30T09:00:00Z"))
    }

    @Test func sendingPlansItOnceAndChoosingMovesToTheTalk() {
        var tracking = ApplicationTracking()
        tracking.send(at: date("2026-11-26T14:00:00Z"), calendar: calendar)
        let first = tracking.invitation
        tracking.set(.concept)
        tracking.send(at: date("2026-11-27T14:00:00Z"), calendar: calendar)
        #expect(tracking.invitation == first)
        let slot = first!.slots[1]
        tracking.choose(slot)
        #expect(tracking.status == .interview)
        #expect(tracking.invitation?.chosen == slot)
        tracking.choose(date("2030-01-01T00:00:00Z"))
        #expect(tracking.invitation?.chosen == slot)
    }

    @Test func theInvitationIsAnnouncedEvenWithoutReminders() {
        var draft = ApplicationDraft(vacancy: Vacancy(id: "v", title: "Junior", company: "Kade", source: .example), template: .sage, cv: CVContent(name: "Ravi"), letter: LetterContent())
        var tracking = draft.progress
        tracking.send(at: date("2026-11-26T14:00:00Z"), calendar: calendar)
        draft.tracking = tracking
        let planned = ApplicationReminders.plan([draft], now: date("2026-11-26T14:01:00Z"), calendar: calendar)
        #expect(planned.map(\.kind) == [.invitation])
        #expect(ApplicationReminders.plan([draft], now: date("2026-11-26T14:05:00Z"), calendar: calendar).isEmpty)
    }

    @Test func olderFilesWithoutAnInvitationStillOpen() throws {
        let old = #"{"status":"sent","note":"x"}"#
        let tracking = try JSONDecoder().decode(ApplicationTracking.self, from: Data(old.utf8))
        #expect(tracking.invitation == nil)
        #expect(tracking.status == .sent)
    }
}
