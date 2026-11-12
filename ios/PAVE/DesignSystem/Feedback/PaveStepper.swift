import SwiftUI

/// Numbered steps on a line: the steps you reached are green, the line fills up to where you are.
struct PaveStepper: View {
    let steps: [String]
    /// Zero-based.
    let current: Int

    private static let dot: CGFloat = 30

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, title in
                VStack(spacing: 8) {
                    number(index)
                    Text(title)
                        .textStyle(.railLabel)
                        .foregroundStyle(index <= current ? Color.brandGreen : .inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(alignment: .topLeading) { line }
        .animation(.snappy(duration: 0.4), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stap \(current + 1) van \(steps.count): \(steps[min(current, steps.count - 1)])")
    }

    private func number(_ index: Int) -> some View {
        let isReached = index <= current
        return Text("\(index + 1)")
            .textStyle(.gapChip)
            .monospacedDigit()
            .foregroundStyle(isReached ? Color.white : .inkMuted)
            .frame(width: Self.dot, height: Self.dot)
            .background {
                Circle()
                    .fill(isReached ? Color.brandGreen : .white)
                    .overlay { Circle().strokeBorder(isReached ? Color.brandGreen : .hairline, lineWidth: 1) }
            }
            .scaleEffect(index == current ? 1.06 : 1)
    }

    /// From the middle of the first number to the middle of the last; the dark part runs to the current step.
    private var line: some View {
        GeometryReader { proxy in
            let column = proxy.size.width / CGFloat(max(steps.count, 1))
            let full = column * CGFloat(max(steps.count - 1, 0))
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.hairline)
                    .frame(width: full, height: 1)
                Rectangle()
                    .fill(Color.ink)
                    .frame(width: column * CGFloat(min(max(current, 0), steps.count - 1)), height: 1)
            }
            .offset(x: column / 2, y: Self.dot / 2)
        }
        .frame(height: Self.dot)
    }
}

#Preview {
    @Previewable @State var current = 1
    VStack(spacing: 32) {
        PaveStepper(steps: ["Basis", "Documenten", "Vaardigheden", "Toestemming"], current: current)
        Button("Volgende") { current = (current + 1) % 4 }
    }
    .padding(24)
}
