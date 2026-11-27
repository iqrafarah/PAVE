import ActivityKit
import AppIntents
import Foundation
import SwiftUI

/// A plan you follow on the Lock Screen and in the Dynamic Island: only how far you are, never the timeline. The
/// Lock Screen can be seen by others, so the plan's name and the step's title only show when you chose that; otherwise
/// it says "Je plan" and the kind of step ("Bewijs in je kluis").
nonisolated struct PlanActivityAttributes: ActivityAttributes {
    var planID: String
    /// The theme colour from Instellingen, as "#RRGGBB", like the widgets get it.
    var accentHex = "#355D4C"

    var accent: Color {
        let fallback: UInt32 = 0x355D4C
        let value = accentHex.count == 7 ? UInt32(accentHex.dropFirst(), radix: 16) ?? fallback : fallback
        return Color(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }

    struct ContentState: Codable, Hashable {
        /// The place of the current step among the steps that count (skipped ones do not).
        var stepNumber: Int
        var totalCount: Int
        var doneCount: Int
        var isFinished: Bool
        /// What kind of step it is, in words that say nothing about you.
        var kindTitle: String?
        /// An SF Symbol for the kind of step.
        var symbol: String = "map"
        /// Only when you chose to show them on the Lock Screen.
        var planName: String? = nil
        var stepTitle: String? = nil
        /// The few words on the Lock Screen in the language of the app; the widget has no translations of its own.
        var words: Words? = nil

        struct Words: Codable, Hashable {
            var yourPlan: String
            var allDone: String
            /// "Stap %@ van %@"
            var stepOf: String
            var done: String
            var markDone: String
        }

        var progress: Double {
            totalCount == 0 ? 0 : min(1, Double(doneCount) / Double(totalCount))
        }

        var title: String { planName ?? words?.yourPlan ?? "Je plan" }

        /// The line under the title: the step, or where you are.
        var line: String {
            if isFinished { return words?.allDone ?? "Alle stappen afgerond" }
            if let stepTitle { return stepTitle }
            let number = (words?.stepOf ?? "Stap %@ van %@")
                .replacingOccurrences(of: "%1$@", with: "%@")
                .replacingOccurrences(of: "%2$@", with: "%@")
            let parts = number.components(separatedBy: "%@")
            let filled = parts.count == 3 ? parts[0] + "\(stepNumber)" + parts[1] + "\(totalCount)" + parts[2] : "\(stepNumber)/\(totalCount)"
            return kindTitle.map { "\(filled) · \($0)" } ?? filled
        }

        /// "2/6", next to the camera.
        var short: String { isFinished ? (words?.done ?? "Klaar") : "\(doneCount)/\(totalCount)" }

        var markDone: String { words?.markDone ?? "Stap klaar" }
    }
}

/// "Stap klaar" on the Lock Screen: the step you are on is done, without opening PAVE. The app carries it out; when
/// it is not running, it keeps the plan for when it starts, and the Lock Screen already counts it.
struct CompletePlanStepIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stap afronden"
    static let isDiscoverable = false

    @Parameter(title: "Plan")
    var planID: String

    init() {}

    init(planID: String) {
        self.planID = planID
    }

    func perform() async throws -> some IntentResult {
        await PlanStepCompletion.complete(planID)
        return .result()
    }
}

/// Where the Lock Screen's "Stap klaar" lands. The app sets `handler` once it has its plans; until then the plan waits
/// in `pendingKey`, and the activity moves on by one step at once.
@MainActor
enum PlanStepCompletion {
    static let pendingKey = "planStepsCompletedOnLockScreen"
    static var handler: ((String) -> Void)?

    static func complete(_ planID: String) async {
        if let handler {
            handler(planID)
            return
        }
        let defaults = UserDefaults.standard
        defaults.set((defaults.stringArray(forKey: pendingKey) ?? []) + [planID], forKey: pendingKey)
        for activity in Activity<PlanActivityAttributes>.activities where activity.attributes.planID == planID {
            var state = activity.content.state
            guard !state.isFinished else { continue }
            state.doneCount = min(state.totalCount, state.doneCount + 1)
            state.isFinished = state.doneCount == state.totalCount
            state.stepNumber = min(state.totalCount, state.stepNumber + 1)
            state.kindTitle = nil
            state.stepTitle = nil
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// The steps finished on the Lock Screen while PAVE was not running.
    static func takePending() -> [String] {
        let defaults = UserDefaults.standard
        let pending = defaults.stringArray(forKey: pendingKey) ?? []
        defaults.removeObject(forKey: pendingKey)
        return pending
    }
}

