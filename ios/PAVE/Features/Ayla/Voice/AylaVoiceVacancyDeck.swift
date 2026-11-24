import PAVECore
import SwiftUI

/// The vacancies Ayla found, large under the small orb while talking: swipe or turn your head for the next one,
/// nod or tap to hear more. Under the card you can ask what you miss, get help applying, practise the interview, or
/// pick two or three to compare. The cards look like the ones in the chat (Figma frame "Vacatures").
struct AylaVoiceVacancyDeck: View {
    let vacancies: [Vacancy]
    @Binding var index: Int
    /// AirPods follow the head, so the hint about turning and nodding shows.
    var followsHead = false
    /// Picked to compare, in the order they were picked.
    let chosenIDs: [String]
    let isSaved: (Vacancy) -> Bool
    /// Nil when vacancies cannot be kept (yet).
    var onToggleSave: ((Vacancy) -> Void)?
    let onOpen: (Vacancy) -> Void
    let onTask: (AylaRequest.VacancyTask, Vacancy) -> Void
    let onToggleCompare: (Vacancy) -> Void
    let onCompare: () -> Void
    let onClearCompare: () -> Void

    @Environment(\.paveReduceMotion) private var reduceMotion
    @State private var position: Int?

    private static let margin: CGFloat = 24

    private var current: Vacancy? {
        vacancies.isEmpty ? nil : vacancies[min(max(index, 0), vacancies.count - 1)]
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(Array(vacancies.enumerated()), id: \.element.id) { offset, vacancy in
                        card(vacancy, tint: VacancyCard.tints[offset % VacancyCard.tints.count])
                            .containerRelativeFrame(.horizontal)
                            .id(offset)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position)
            .contentMargins(.horizontal, Self.margin, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            // As tall as the cards, not all the room there is.
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: position) { _, position in
                guard let position, position != index else { return }
                index = position
                PaveHaptics.selection()
            }
            .onChange(of: index, initial: true) { _, index in
                guard position != index else { return }
                if reduceMotion { position = index } else { withAnimation(.snappy(duration: 0.3)) { position = index } }
            }

            pager

            if let current {
                VacancyActions(
                    isChosen: chosenIDs.contains(current.id),
                    canChoose: chosenIDs.count < 3,
                    onTask: { onTask($0, current) },
                    onToggleCompare: { onToggleCompare(current) }
                )
                .padding(.horizontal, Self.margin)
            }
            if !chosenIDs.isEmpty {
                VacancyCompareBar(count: chosenIDs.count, onCompare: onCompare, onClear: onClearCompare)
                    .padding(.horizontal, Self.margin)
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: chosenIDs)
    }

    private func card(_ vacancy: Vacancy, tint: Color) -> some View {
        let isChosen = chosenIDs.contains(vacancy.id)
        return Button { onOpen(vacancy) } label: {
            VStack(alignment: .leading, spacing: 14) {
                VacancyHeader(vacancy: vacancy)
                    .padding(.trailing, onToggleSave == nil ? 14 : 40)
                if !vacancy.matches.isEmpty || !vacancy.skillGap.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AylaMessages.vacancyFitCount(vacancy.matches.count, of: vacancy.matches.count + vacancy.skillGap.count))
                            .textStyle(.caption)
                            .foregroundStyle(Color.ink)
                        VacancySkillChips(matches: vacancy.matches, gaps: vacancy.skillGap)
                    }
                    .padding(.trailing, 14)
                } else {
                    Text(AylaMessages.vacancyNoMatch)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.trailing, 14)
                }
            }
            .padding(.leading, 13)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { FigmaCardGradient(tint: tint, start: UnitPoint(x: 0.97, y: 1.08), end: UnitPoint(x: 0.03, y: -0.08)) }
            .clipShape(.rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isChosen ? Color.paveAccent : Color.cardBorder, lineWidth: isChosen ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.pave)
        .overlay(alignment: .topTrailing) {
            if let onToggleSave {
                VacancySaveButton(isSaved: isSaved(vacancy)) { onToggleSave(vacancy) }
                    .padding(.top, 6)
                    .padding(.trailing, 6)
            }
        }
        .accessibilityHint("Opent de vacature")
    }

    private var pager: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(vacancies.indices, id: \.self) { offset in
                    Capsule()
                        .fill(offset == index ? Color.paveAccent : Color.railBorder)
                        .frame(width: offset == index ? 16 : 6, height: 6)
                }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: index)
            .accessibilityElement()
            .accessibilityLabel(AylaMessages.vacancyPosition(index, of: vacancies.count))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: if index < vacancies.count - 1 { index += 1 }
                case .decrement: if index > 0 { index -= 1 }
                @unknown default: break
                }
            }
            if followsHead {
                Text(AylaMessages.vacancyHint)
                    .textStyle(.meta)
                    .foregroundStyle(Color.inkMuted)
            }
        }
    }
}

#Preview {
    @Previewable @State var index = 0
    AylaVoiceVacancyDeck(
        vacancies: [
            Vacancy(id: "a", title: "Junior iOS-ontwikkelaar", company: "Appwerk", city: "Eindhoven", employment: .fullTime, source: .adzuna,
                    matches: [.init(skill: "Swift", requirement: "r"), .init(skill: "SwiftUI", requirement: "r")], skillGap: [.init(skill: "CI/CD", requirement: "r")]),
            Vacancy(id: "b", title: "Front-end developer", company: "Pixelwerk", city: "Eindhoven", source: .jooble),
        ],
        index: $index,
        chosenIDs: ["a"],
        isSaved: { _ in false },
        onToggleSave: { _ in },
        onOpen: { _ in },
        onTask: { _, _ in },
        onToggleCompare: { _ in },
        onCompare: {},
        onClearCompare: {}
    )
    .background(Color.canvas)
}
