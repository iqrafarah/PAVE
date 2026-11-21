import PAVECore
import SwiftUI

/// One vacancy at a time under the orb while talking: turn the head to the side for the next or the previous one,
/// nod to have Ayla tell more about it. The arrows and "Kies deze" do the same with a tap.
struct AylaVoiceVacancyCard: View {
    let vacancy: Vacancy
    let index: Int
    let count: Int
    /// AirPods follow the head, so the hint about turning and nodding shows.
    var followsHead = false
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onChoose: () -> Void

    private var place: String {
        [vacancy.company, vacancy.city].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(vacancy.title)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                Text(place)
                    .textStyle(.meta)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
            }
            if let match = vacancy.matches.first?.skill {
                line(icon: .iconCheck, text: "Past: \(match)", color: .paveAccent)
            }
            if let gap = vacancy.skillGap.first?.skill {
                line(icon: .iconPlus, text: "Mist nog: \(gap)", color: .inkMuted)
            }
            HStack(spacing: 2) {
                arrow(isNext: false, label: "Vorige vacature", isEnabled: index > 0, action: onPrevious)
                Text(AylaMessages.vacancyPosition(index, of: count))
                    .textStyle(.meta)
                    .foregroundStyle(Color.inkMuted)
                    .monospacedDigit()
                arrow(isNext: true, label: "Volgende vacature", isEnabled: index < count - 1, action: onNext)
                Spacer(minLength: 4)
                Button(AylaMessages.vacancyChoose, action: onChoose)
                    .textStyle(.label)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Color.paveAccentFill, in: .capsule)
                    .buttonStyle(.pave)
            }
            if followsHead {
                Text(AylaMessages.vacancyHint)
                    .textStyle(.meta)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: 340, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1) }
        .id(vacancy.id)
        .accessibilityElement(children: .contain)
    }

    private func line(icon: ImageResource, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .paveIconFrame(12)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(text)
                .textStyle(.meta)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
        }
    }

    private func arrow(isNext: Bool, label: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(.iconChevronRightSolid)
                .renderingMode(.template)
                .resizable()
                .paveIconFrame(14)
                .scaleEffect(x: isNext ? 1 : -1)
                .foregroundStyle(isEnabled ? Color.ink : Color.inkMuted.opacity(0.4))
                .frame(width: 34, height: 34)
                .background(Color.canvas, in: .circle)
                // A full 44 points to tap, around the 34 you see.
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}
