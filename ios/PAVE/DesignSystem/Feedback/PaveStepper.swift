import SwiftUI

/// Numbered steps on a line. Going forward, the line first runs on to the next step and then that number fills up from
/// its middle; going back, the number empties first and then the line pulls back. With reduced motion it simply fades.
struct PaveStepper: View {
    let steps: [String]
    /// Zero-based.
    let current: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How far the dark line runs, in steps; animated on its own so it can lead the numbers.
    @State private var line: CGFloat = 0
    @State private var reached = 0
    @State private var move: Task<Void, Never>?

    private static let dot: CGFloat = 30

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, title in
                VStack(spacing: 8) {
                    number(index)
                    Text(title)
                        .textStyle(.railLabel)
                        .foregroundStyle(index <= reached ? Color.brandGreen : .inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(alignment: .topLeading) { track }
        .onAppear {
            line = CGFloat(current)
            reached = current
        }
        .onChange(of: current) { old, new in
            move?.cancel()
            move = Task { await step(from: old, to: new) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stap \(current + 1) van \(steps.count): \(steps[min(current, steps.count - 1)])")
    }

    private func step(from old: Int, to new: Int) async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) {
                line = CGFloat(new)
                reached = new
            }
        } else if new > old {
            withAnimation(.easeInOut(duration: 0.38)) { line = CGFloat(new) }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.45, bounce: 0.4)) { reached = new }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { reached = new }
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.34)) { line = CGFloat(new) }
        }
    }

    private func number(_ index: Int) -> some View {
        let isReached = index <= reached
        return Text("\(index + 1)")
            .textStyle(.gapChip)
            .monospacedDigit()
            .foregroundStyle(isReached ? Color.white : .inkMuted)
            .frame(width: Self.dot, height: Self.dot)
            .background {
                ZStack {
                    Circle().fill(Color.white)
                    Circle().strokeBorder(Color.hairline, lineWidth: 1)
                    // The green fills from the middle, so the number seems to light up when the line arrives.
                    Circle()
                        .fill(Color.brandGreen)
                        .scaleEffect(isReached ? 1 : 0.01)
                        .opacity(isReached ? 1 : 0)
                }
            }
            .scaleEffect(index == reached ? 1.08 : 1)
    }

    /// From the middle of the first number to the middle of the last; the dark part runs to where you are.
    private var track: some View {
        GeometryReader { proxy in
            let column = proxy.size.width / CGFloat(max(steps.count, 1))
            let full = column * CGFloat(max(steps.count - 1, 0))
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.hairline)
                    .frame(width: full, height: 1)
                Rectangle()
                    .fill(Color.ink)
                    .frame(width: full, height: 1)
                    .scaleEffect(x: full > 0 ? min(max(line, 0), CGFloat(steps.count - 1)) * column / full : 0, anchor: .leading)
            }
            .offset(x: column / 2, y: Self.dot / 2)
        }
        .frame(height: Self.dot)
    }
}

#Preview {
    @Previewable @State var current = 0
    VStack(spacing: 32) {
        PaveStepper(steps: ["Basis", "Documenten", "Vaardigheden", "Toestemming"], current: current)
        HStack {
            Button("Terug") { current = max(0, current - 1) }
            Button("Volgende") { current = min(3, current + 1) }
        }
    }
    .padding(24)
}
