import SwiftUI

/// Instellingen › Ayla: what she remembers about you, and the text while you talk with her.
struct SettingsAylaScreen: View {
    @AppStorage(AylaVoiceTextSetting.key) private var showsVoiceText = true
    @Environment(AylaMemoryModel.self) private var memory

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
                .background(Color.white, in: .rect(cornerRadius: 14))
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
                Text("Je leest zin voor zin mee met wat Ayla zegt. Zet je dit uit, dan zie je alleen de orb.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(12)
            .background(Color.white, in: .rect(cornerRadius: 14))
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
