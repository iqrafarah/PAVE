import ActivityKit
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

        var progress: Double {
            totalCount == 0 ? 0 : min(1, Double(doneCount) / Double(totalCount))
        }

        var title: String { planName ?? "Je plan" }

        /// The line under the title: the step, or where you are.
        var line: String {
            if isFinished { return "Alle stappen afgerond" }
            if let stepTitle { return stepTitle }
            let number = "Stap \(stepNumber) van \(totalCount)"
            return kindTitle.map { "\(number) · \($0)" } ?? number
        }

        /// "2/6", next to the camera.
        var short: String { isFinished ? "Klaar" : "\(doneCount)/\(totalCount)" }
    }
}
