import SwiftUI

/// Instellingen › Ayla: what she remembers about you, and the text while you talk with her.
struct SettingsAylaScreen: View {
    @AppStorage(AylaVoiceTextSetting.key) private var showsVoiceText = true
    @Environment(AylaMemoryModel.self) private var memory
    @Environment(PaveCameraControl.self) private var cameraControl

    var body: some View {
        SettingsPage(title: "Ayla") {
            NavigationLink {
                AylaMemoryScreen()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wat Ayla over je weet")
                            .textStyle(.listTitle)
                            .foregroundStyle(Color.ink)
                        Text(Self.memorySummary(memory))
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    Spacer(minLength: 0)
                    Image(.iconChevronRightSolid)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(14)
                        .foregroundStyle(Color.inkMuted)
                        .accessibilityHidden(true)
                }
                .padding(12)
                .background(Color.panel, in: .rect(cornerRadius: 14))
                .contentShape(.rect)
            }
            .buttonStyle(.pave)

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $showsVoiceText) {
                    Text("Tekst bij praten met Ayla")
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                }
                .tint(.paveAccent)
                .onChange(of: showsVoiceText) { WatchBridge.shared.update() }
                Text("Je leest zin voor zin mee met wat Ayla zegt, ook op je Apple Watch. Zet je dit uit, dan zie je alleen de orb.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(12)
            .background(Color.panel, in: .rect(cornerRadius: 14))

            cameraControlRow
        }
    }

    /// Demo: knopmodus, the Camera Control button steering PAVE for a few minutes.
    private var cameraControlRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { _ = cameraControl.enabledChanged; return cameraControl.isEnabled },
                set: { cameraControl.isEnabled = $0 }
            )) {
                Text("Knopmodus (demo)")
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
            }
            .tint(.paveAccent)
            Text("Bedien PAVE met de cameraknop: druk licht voor Ga naar en veeg, druk twee keer licht voor Ayla, druk helemaal in om met Ayla te praten. De camera staat daarvoor aan zolang PAVE open is (het groene bolletje van iOS), maar neemt niets op. Zet het hier weer uit. De volumeknoppen werken zolang als de cameraknop.")
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
            if let problem = cameraControl.problem {
                Text(Self.message(for: problem))
                    .textStyle(.caption)
                    .foregroundStyle(Color.criticalInk)
            }
        }
        .padding(12)
        .background(Color.panel, in: .rect(cornerRadius: 14))
    }

    private static func message(for problem: PaveCameraControl.Problem) -> String {
        switch problem {
        case .notAllowed: "PAVE mag de camera niet gebruiken. Zet het aan in Instellingen › PAVE › Camera."
        case .noCamera: "De camera is nu niet beschikbaar."
        case .noButton: "Deze iPhone heeft geen cameraknop."
        }
    }

    static func memorySummary(_ memory: AylaMemoryModel) -> String {
        switch memory.state {
        case .ready:
            guard memory.memories.isEnabled else { return "Uit: Ayla onthoudt niets" }
            let count = memory.notes.count
            return count == 0 ? "Ayla onthoudt nog niets" : count == 1 ? "Ayla onthoudt 1 ding" : "Ayla onthoudt \(count) dingen"
        case .notSetUp: return "Nog niet beschikbaar"
        default: return "Bekijk, pas aan of wis wat Ayla onthoudt"
        }
    }
}
