import PAVECore
import SwiftUI
import WatchKit

/// Right before a talk: three rounds of calm breathing, guided by taps on the wrist, and then three points to mention,
/// from Ayla, built on what she may see of you.
struct WatchCoachView: View {
    let company: String
    let model: WatchAylaModel

    private enum Breath { case breathingIn, holding, breathingOut }

    @State private var breath: Breath?
    @State private var round = 0
    @State private var points: String?
    @State private var failed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { WatchPreferences.shared.accentColor }
    private static let rounds = 3

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if round < Self.rounds {
                    Text(WatchMessages.coachBreathe).font(.footnote).foregroundStyle(.secondary)
                    Circle()
                        .fill(accent.opacity(0.35))
                        .overlay { Circle().strokeBorder(accent, lineWidth: 2) }
                        .frame(width: 96, height: 96)
                        .scaleEffect(reduceMotion ? 1 : breath == .breathingOut || breath == nil ? 0.55 : 1)
                        .animation(.easeInOut(duration: breath == .holding ? 0.2 : 4), value: breath)
                        .accessibilityHidden(true)
                    Text(label).font(.headline)
                    Text("\(round + 1) van \(Self.rounds)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                } else {
                    Text(WatchMessages.coachPoints).font(.caption2.weight(.semibold)).foregroundStyle(accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let points {
                        Text(points).font(.footnote).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(WatchMessages.coachGo).font(.footnote.weight(.semibold)).foregroundStyle(accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if failed {
                        Text(WatchMessages.coachFailed).font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                        Text(WatchMessages.coachThinking).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(WatchMessages.coachTitle)
        .task { await breathe() }
        .task {
            // The points load while you breathe, so they are there when you are done.
            if let found = await model.coachPoints(for: company) { points = found } else { failed = true }
        }
    }

    private var label: String {
        switch breath {
        case .breathingIn, nil: WatchMessages.coachIn
        case .holding: WatchMessages.coachHold
        case .breathingOut: WatchMessages.coachOut
        }
    }

    /// In for four seconds, hold for two, out for four; a tap marks each change.
    private func breathe() async {
        let device = WKInterfaceDevice.current()
        while round < Self.rounds, !Task.isCancelled {
            breath = .breathingIn
            device.play(.directionUp)
            try? await Task.sleep(for: .seconds(4))
            breath = .holding
            device.play(.click)
            try? await Task.sleep(for: .seconds(2))
            breath = .breathingOut
            device.play(.directionDown)
            try? await Task.sleep(for: .seconds(4))
            round += 1
        }
        device.play(.success)
    }
}
