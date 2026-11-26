import EventKit
import EventKitUI
import SwiftUI

/// A moment Ayla puts in the calendar for you, such as an open day or a deadline from a plan.
struct AylaCalendarMoment: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let date: Date
    /// Only a day: an all-day event with a reminder the day before.
    let isAllDay: Bool

    /// "2026-12-03" or "2026-12-03T14:30", in the time of the Netherlands.
    init?(title: String, value: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = value.contains("T") ? "yyyy-MM-dd'T'HH:mm" : "yyyy-MM-dd"
        guard let date = formatter.date(from: value) else { return nil }
        self.title = title
        self.date = date
        isAllDay = !value.contains("T")
    }
}

/// The iPhone's own screen for a new event, filled in by Ayla. You save it there yourself; PAVE asks no access to
/// your calendar and does not read it.
struct AylaCalendarEditor: UIViewControllerRepresentable {
    let moment: AylaCalendarMoment
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = context.coordinator.store
        let event = EKEvent(eventStore: store)
        event.title = moment.title
        if moment.isAllDay {
            event.isAllDay = true
            event.startDate = Calendar.current.startOfDay(for: moment.date)
            event.endDate = event.startDate
            // The day before at nine.
            event.addAlarm(EKAlarm(relativeOffset: -15 * 3600))
        } else {
            event.startDate = moment.date
            event.endDate = moment.date.addingTimeInterval(3600)
            event.addAlarm(EKAlarm(relativeOffset: -3600))
        }
        event.notes = AylaMessages.calendarNotes
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let store = EKEventStore()
        let onDone: () -> Void

        init(onDone: @escaping () -> Void) {
            self.onDone = onDone
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onDone()
        }
    }
}
