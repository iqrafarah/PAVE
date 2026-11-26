import EventKit
import EventKitUI
import PAVECore
import SwiftUI

/// The iPhone's own screen for a new calendar event, filled with the deadline or with the talk you chose. You save it
/// there yourself; PAVE asks no access to your calendar and does not read it.
struct ApplicationCalendarEditor: UIViewControllerRepresentable {
    let vacancy: Vacancy
    let deadline: Date
    /// A talk at this moment instead of a deadline: timed, with a reminder an hour before.
    var isTalk = false
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = context.coordinator.store
        let event = EKEvent(eventStore: store)
        if isTalk {
            event.title = ApplyMessages.talkCalendarTitle(vacancy)
            event.startDate = deadline
            event.endDate = deadline.addingTimeInterval(TimeInterval(ApplicationInvitation.talkMinutes * 60))
            event.location = vacancy.city.map { "\(vacancy.company), \($0)" } ?? vacancy.company
            event.notes = ApplyMessages.talkCalendarNotes
            event.addAlarm(EKAlarm(relativeOffset: -3600))
        } else {
            event.title = ApplyMessages.calendarTitle(vacancy)
            event.isAllDay = true
            event.startDate = Calendar.current.startOfDay(for: deadline)
            event.endDate = event.startDate
            event.notes = ApplyMessages.calendarNotes
            // The day before at nine.
            event.addAlarm(EKAlarm(relativeOffset: -15 * 3600))
        }
        event.url = vacancy.url
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
