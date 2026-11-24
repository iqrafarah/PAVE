import SwiftUI

/// Gevonden and Bewaard, in PAVE's own shapes: a tinted track with the chosen one on a white capsule that slides over.
struct VacancyTabs: View {
    @Binding var tab: VacancyList.Tab
    let found: Int
    let saved: Int
    var applications = 0

    @Namespace private var track
    @Environment(\.paveReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            button(.found, AylaMessages.vacancyFound, found)
            button(.saved, AylaMessages.vacancySavedTab, saved)
            button(.applications, AylaMessages.vacancyApplicationsTab, applications)
        }
        .padding(4)
        .background(Color.paveSurfaceTint, in: .capsule)
    }

    private func button(_ value: VacancyList.Tab, _ title: String, _ count: Int) -> some View {
        let isChosen = tab == value
        return Button {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.3, bounce: 0.15)) { tab = value }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .foregroundStyle(isChosen ? Color.ink : Color.inkMuted)
                if count > 0 {
                    Text("\(count)")
                        .monospacedDigit()
                        .foregroundStyle(isChosen ? Color.paveAccent : Color.inkMuted)
                }
            }
            .textStyle(.chip)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background {
                if isChosen {
                    Capsule().fill(Color.panel).matchedGeometryEffect(id: "chosen", in: track)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(count > 0 ? "\(title), \(count)" : title)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}
