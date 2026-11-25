import PAVECore
import SwiftUI

/// What you can do with a vacancy: ask what you miss, get help applying, practise the interview, or pick it to
/// compare. Under a vacancy in the chat and under the card while talking with Ayla.
struct VacancyActions: View {
    /// Picked to compare.
    let isChosen: Bool
    /// False when three others are picked already.
    var canChoose = true
    /// Comparing works in the chat; the vacancies page leaves it out.
    var showsCompare = true
    let onTask: (AylaRequest.VacancyTask) -> Void
    let onToggleCompare: () -> Void

    var body: some View {
        if showsCompare { grid } else { page }
    }

    /// On the vacancy's own page: applying first and full width, the two other tasks under it.
    private var page: some View {
        VStack(spacing: 8) {
            Button { onTask(.prepare) } label: { label(.iconDocumentTextSolid, AylaMessages.vacancyActionPrepare, isOn: true) }
                .buttonStyle(.pave)
            HStack(spacing: 8) {
                action(.iconPlusCircleSolid, AylaMessages.vacancyActionGaps) { onTask(.gaps) }
                action(.iconChatBubbleLeftEllipsisSolid, AylaMessages.vacancyActionPractice) { onTask(.interview) }
            }
        }
    }

    private var grid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                action(.iconPlusCircleSolid, AylaMessages.vacancyActionGaps) { onTask(.gaps) }
                action(.iconDocumentTextSolid, AylaMessages.vacancyActionPrepare) { onTask(.prepare) }
            }
            GridRow {
                action(.iconChatBubbleLeftEllipsisSolid, AylaMessages.vacancyActionPractice) { onTask(.interview) }
                compare
            }
        }
    }

    private var compare: some View {
        Button(action: onToggleCompare) {
            label(
                isChosen ? .iconCheckCircleSolid : .iconArrowsRightLeftSolid,
                isChosen ? AylaMessages.vacancyActionCompareChosen : AylaMessages.vacancyActionCompare,
                isOn: isChosen
            )
        }
        .buttonStyle(.pave)
        .disabled(!isChosen && !canChoose)
        .opacity(!isChosen && !canChoose ? 0.5 : 1)
        .sensoryFeedback(.selection, trigger: isChosen)
        .accessibilityLabel(AylaMessages.vacancyActionCompare)
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
        .accessibilityHint(!isChosen && !canChoose ? AylaMessages.vacancyCompareFull : "")
    }

    private func action(_ icon: ImageResource, _ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) { label(icon, title, isOn: false) }
            .buttonStyle(.pave)
    }

    private func label(_ icon: ImageResource, _ title: String, isOn: Bool) -> some View {
        HStack(spacing: 8) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(15)
                .foregroundStyle(isOn ? Color.white : Color.paveAccent)
                .accessibilityHidden(true)
            Text(title)
                .textStyle(.chip)
                .foregroundStyle(isOn ? Color.white : Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(isOn ? Color.paveAccentFill : Color.panel, in: .capsule)
        .overlay { Capsule().strokeBorder(isOn ? Color.clear : Color.cardBorder, lineWidth: 1) }
        .contentShape(.capsule)
        .animation(.easeOut(duration: 0.15), value: isOn)
    }
}

#Preview {
    VStack(spacing: 16) {
        VacancyActions(isChosen: false, onTask: { _ in }, onToggleCompare: {})
        VacancyActions(isChosen: true, onTask: { _ in }, onToggleCompare: {})
    }
    .padding()
    .background(Color.canvas)
}
