import PAVECore
import SwiftUI
import WatchKit

/// What just happened on the iPhone, over whatever is on the wrist: who looked at what you shared, the stand you
/// scanned, something Ayla set up on the iPhone, or an invitation to answer with Ja or Nee. It goes by itself after a
/// few seconds, except an invitation, which waits for your answer.
struct WatchEventCard: View {
    let event: WatchEvent
    let sessions: WatchSessionStore
    let onDone: () -> Void

    @State private var answering = false
    @State private var answered: String?

    private var accent: Color { WatchPreferences.shared.accentColor }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(accent)
                Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                if let detail { Text(detail).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                if case .invitation(let id, _, _, _) = event {
                    if let answered {
                        Text(answered).font(.footnote).foregroundStyle(accent)
                    } else {
                        HStack(spacing: 6) {
                            Button("Nee") { answer(id, accepted: false) }
                            Button("Ja") { answer(id, accepted: true) }
                                .tint(accent)
                        }
                        .disabled(answering)
                    }
                }
                Button("Sluit", action: onDone)
                    .buttonStyle(.plain)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: event) {
            // Everything but a question goes by itself.
            if case .invitation = event { return }
            try? await Task.sleep(for: .seconds(7))
            if !Task.isCancelled { onDone() }
        }
    }

    private var label: String {
        switch event {
        case .look: "Er kijkt iemand"
        case .invitation: "Uitnodiging"
        case .standTip: "Gescand"
        case .handoff: "Op je iPhone"
        case .plan: "Plan"
        }
    }

    private var title: String {
        switch event {
        case .look(let who, _): who
        case .invitation(_, let employer, let vacancy, _): "\(employer): \(vacancy)"
        case .standTip(let employer, _): employer
        case .handoff(let title, _): title
        case .plan(let name, _, _, _): name
        }
    }

    private var detail: String? {
        switch event {
        case .look(_, let what): "Opent nu \(what)"
        case .invitation(_, _, _, let at):
            at.map { $0.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute().locale(Locale(identifier: "nl_NL"))) }
                .map { "Gesprek \($0). Kom je?" } ?? "Kom je?"
        case .standTip(_, let line): line
        case .handoff(_, let detail): detail
        case .plan(_, let done, let total, let current): "\(done) van \(total)" + (current.map { " · nu: \($0)" } ?? "")
        }
    }

    /// Your answer goes to the iPhone, which tells the employer. Without the iPhone in reach it waits there.
    private func answer(_ id: String, accepted: Bool) {
        answering = true
        Task {
            let said = await sessions.send(.answerInvitation(id: id, accepted: accepted))
            WKInterfaceDevice.current().play(said == nil ? .retry : .success)
            answered = said == nil ? "Gaat mee zodra je iPhone in de buurt is." : (accepted ? "Je komt. Het staat op je iPhone." : "Doorgegeven dat je niet kunt.")
            answering = false
            try? await Task.sleep(for: .seconds(2.5))
            onDone()
        }
    }
}
