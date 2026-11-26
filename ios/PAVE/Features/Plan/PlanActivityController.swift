import ActivityKit
import Foundation
import Observation
import PAVECore

/// Follows one plan on the Lock Screen and in the Dynamic Island (Live Activity): only how far you are and one line
/// about the step. It follows every change of the plan while PAVE runs, ends when the plan is finished or deleted, and
/// picks up an activity that was still there when PAVE started again. With Live Activities off in Settings nothing
/// happens. The activity itself is looked up where it is changed, off the main actor, as for the voice activity.
@MainActor @Observable
final class PlanActivityController {
    typealias Attributes = PlanActivityAttributes
    /// Whether the plan's name and the step's title may show on the Lock Screen, where others can see it.
    static let showsNamesKey = "planActivityShowsNames"

    private(set) var followedPlanID: String?
    @ObservationIgnored private var activityID: String?
    @ObservationIgnored private var lastState: Attributes.ContentState?

    init() {
        if let existing = Activity<Attributes>.activities.first(where: { $0.activityState == .active || $0.activityState == .stale }) {
            activityID = existing.id
            followedPlanID = existing.attributes.planID
        }
    }

    var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    private var showsNames: Bool { UserDefaults.standard.bool(forKey: Self.showsNamesKey) }

    func follow(_ plan: PavePlan) {
        stop()
        guard isAvailable, !plan.isFinished else { return }
        let state = Self.state(for: plan, showsNames: showsNames)
        let accent = PaveThemeColor.hex(PaveHomeScreen.widgetAccent(theme: PaveAppearance.theme, customColor: PaveAppearance.customColor))
        let content = ActivityContent(state: state, staleDate: nil)
        guard let activity = try? Activity.request(attributes: Attributes(planID: plan.id, accentHex: accent), content: content) else { return }
        activityID = activity.id
        followedPlanID = plan.id
        lastState = state
    }

    func stop() {
        let id = activityID
        activityID = nil
        followedPlanID = nil
        lastState = nil
        guard let id else { return }
        Task.detached {
            for activity in Activity<Attributes>.activities where activity.id == id {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// The plans as they are now. A finished plan shows "Klaar" once more and then goes; a deleted one goes at once.
    func sync(_ plans: [PavePlan], force: Bool = false) {
        guard let followedPlanID, let id = activityID else { return }
        guard let plan = plans.first(where: { $0.id == followedPlanID }) else { return stop() }
        let state = Self.state(for: plan, showsNames: showsNames)
        guard force || state != lastState else { return }
        lastState = state
        let content = ActivityContent(state: state, staleDate: nil)
        if plan.isFinished {
            activityID = nil
            self.followedPlanID = nil
            lastState = nil
            Task.detached {
                for activity in Activity<Attributes>.activities where activity.id == id {
                    await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(60 * 60)))
                }
            }
        } else {
            Task.detached {
                for activity in Activity<Attributes>.activities where activity.id == id {
                    await activity.update(content)
                }
            }
        }
    }

    /// Only what fits next to the camera: numbers, the kind of step, and the names only when allowed.
    static func state(for plan: PavePlan, showsNames: Bool) -> Attributes.ContentState {
        let step = plan.currentStep
        return Attributes.ContentState(
            stepNumber: plan.currentNumber,
            totalCount: plan.totalCount,
            doneCount: plan.doneCount,
            isFinished: plan.isFinished,
            kindTitle: step?.kind.title,
            symbol: step?.kind.symbol ?? "map",
            planName: showsNames ? plan.name : nil,
            stepTitle: showsNames ? step?.title : nil
        )
    }
}
