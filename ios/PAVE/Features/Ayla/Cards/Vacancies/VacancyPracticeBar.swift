import PAVECore
import SwiftUI

/// A practice interview is going on: for which vacancy, and a way to stop with a summary.
struct VacancyPracticeBar: View {
    let vacancy: Vacancy
    let onStop: () -> Void
    /// The practice ended: the bar offers its report instead of stopping.
    var onReport: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(.iconChatBubbleLeftEllipsisOutline)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(14)
                .foregroundStyle(Color.paveAccent)
                .accessibilityHidden(true)
            Text(onReport == nil ? AylaMessages.practiceTitle(vacancy) : ApplyMessages.practiceDone)
                .textStyle(.caption)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
            Button(onReport == nil ? AylaMessages.practiceStop : ApplyMessages.practiceReportReady, action: onReport ?? onStop)
                .textStyle(.label)
                .foregroundStyle(Color.paveAccent)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .contentShape(.rect)
                .buttonStyle(.pave)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .background(Color.panel, in: .capsule)
        .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VacancyPracticeBar(vacancy: Vacancy(id: "a", title: "iOS-ontwikkelaar", company: "Appwerk", source: .adzuna), onStop: {})
        .padding()
        .background(Color.canvas)
}
