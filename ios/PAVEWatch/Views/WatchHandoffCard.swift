import PAVECore
import SwiftUI

/// What Ayla wants to do for you on the iPhone, such as a plan step, your answer to an invitation or your CV, with Ja
/// and Nee. Nothing happens without Ja; then the iPhone carries it out and says what came of it.
struct WatchHandoffCard: View {
    let handoff: WatchAylaModel.Handoff
    let onAnswer: (Bool) -> Void

    private var accent: Color { WatchPreferences.shared.accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Op je iPhone")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(accent)
            ForEach(Array(handoff.actions.prefix(3).enumerated()), id: \.offset) { _, action in
                Text(Self.describe(action))
                    .font(.footnote.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            switch handoff.state {
            case .asking:
                HStack(spacing: 6) {
                    Button("Nee") { onAnswer(false) }
                    Button("Ja") { onAnswer(true) }
                        .tint(accent)
                }
                .buttonStyle(.borderedProminent)
            case .sending:
                ProgressView()
            case .done(let said):
                Text(said).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            case .declined:
                Text("Niets gedaan").font(.caption2).foregroundStyle(.secondary)
            case .queued:
                Text(WatchMessages.handoffQueued).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.18), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    /// What Ja does, in a few words.
    static func describe(_ action: AylaAppAction) -> String {
        let target = action.target ?? ""
        let value = action.value ?? ""
        switch action.kind {
        case "addPlanStep": return "Stap \(value) toevoegen"
        case "markPlanStep": return value == "done" ? "Stap \(target) afronden" : "Stap \(target) bijwerken"
        case "answerInvitation": return ["yes", "ja"].contains(value.lowercased()) ? "\(target) laten weten dat je komt" : "\(target) laten weten dat je niet kunt"
        case "openApplication": return "Je cv en brief\(target.isEmpty ? "" : " voor \(target)") klaarzetten"
        case "makeVacancyPlan": return "Een plan\(target.isEmpty ? "" : " voor \(target)") maken"
        case "openPlan": return "Plan \(target) openen"
        case "addToCalendar": return "\(target) in je agenda zetten"
        default: return "Op je iPhone afmaken"
        }
    }
}
