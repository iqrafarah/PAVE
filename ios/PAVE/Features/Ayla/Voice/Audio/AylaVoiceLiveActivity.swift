import ActivityKit

/// Starts, updates and ends the Live Activity of a spoken conversation with Ayla. When Live Activities are off in
/// Settings nothing happens, and the conversation simply goes on. Only the id is kept: the activity itself is looked up
/// where it is updated, off the main actor.
@MainActor
final class AylaVoiceLiveActivity {
    typealias Attributes = AylaVoiceActivityAttributes
    private var activityID: String?
    private var status: Attributes.ContentState.Status?

    func start(status: Attributes.ContentState.Status) {
        guard activityID == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        self.status = status
        let content = ActivityContent(state: Attributes.ContentState(status: status), staleDate: nil)
        activityID = (try? Activity.request(attributes: Attributes(), content: content))?.id
    }

    func update(status: Attributes.ContentState.Status) {
        guard let activityID, status != self.status else { return }
        self.status = status
        Task.detached {
            let content = ActivityContent(state: Attributes.ContentState(status: status), staleDate: nil)
            for activity in Activity<Attributes>.activities where activity.id == activityID {
                await activity.update(content)
            }
        }
    }

    func end() {
        guard let activityID else { return }
        self.activityID = nil
        status = nil
        Task.detached {
            for activity in Activity<Attributes>.activities where activity.id == activityID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
