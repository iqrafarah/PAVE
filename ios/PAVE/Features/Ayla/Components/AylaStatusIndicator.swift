import SwiftUI

/// The pixel blocks from Figma. While Ayla thinks they build up four slashes one by one;
/// when something goes wrong they tumble over in red.
struct AylaStatusIndicator: View {
    enum State: Equatable {
        case thinking
        case failed
    }

    let state: State
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Group {
                switch state {
                case .thinking: ThinkingBlocks()
                case .failed: FallenBlocks()
                }
            }
            .accessibilityHidden(true)
            Text(message)
                .textStyle(.status)
                .foregroundStyle(state == .thinking ? Color.brandGreen : .criticalInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct ThinkingBlocks: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let size: CGFloat = 11.6
    private static let duration = 7.052
    private static let blocks: [CGPoint] = [
        CGPoint(x: 0, y: 46.4), CGPoint(x: 4.75, y: 34.8),
        CGPoint(x: 20.56, y: 46.4), CGPoint(x: 26.36, y: 34.8), CGPoint(x: 32.16, y: 23.2),
        CGPoint(x: 41.13, y: 46.4), CGPoint(x: 46.93, y: 34.8), CGPoint(x: 52.73, y: 23.2), CGPoint(x: 58.53, y: 11.6),
        CGPoint(x: 64.33, y: 46.4), CGPoint(x: 70.13, y: 34.8), CGPoint(x: 75.93, y: 23.2), CGPoint(x: 81.73, y: 11.6), CGPoint(x: 87.53, y: 0),
    ]
    /// When the last four blocks fade out again, as a fraction of the loop (start, end).
    private static let fadeOuts: [Int: (Double, Double)] = [
        10: (0.96755, 1.0), 11: (0.90664, 0.97584), 12: (0.84411, 0.91208), 13: (0.78444, 0.84825),
    ]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let progress = reduceMotion ? 0.7 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.duration) / Self.duration
            ZStack(alignment: .topLeading) {
                ForEach(Self.blocks.indices, id: \.self) { index in
                    Rectangle()
                        .fill(Color.brandGreen)
                        .frame(width: Self.size, height: Self.size)
                        .offset(x: Self.blocks[index].x, y: Self.blocks[index].y)
                        .opacity(Self.opacity(of: index, at: progress))
                }
            }
            .frame(width: 99.13, height: 58, alignment: .topLeading)
        }
    }

    static func opacity(of index: Int, at progress: Double) -> Double {
        let fadeInStart = Double(index) * 0.04963
        let fadeIn = min(max((progress - fadeInStart) / 0.0575, 0), 1)
        guard let (start, end) = fadeOuts[index], progress > start else { return fadeIn }
        return fadeIn * (1 - min((progress - start) / (end - start), 1))
    }
}

private struct FallenBlocks: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasFallen = false

    private struct Block {
        let origin: CGPoint
        var fall = CGSize.zero
        var rotation: Double = 0
    }

    private static let size: CGFloat = 11.936
    private static let blocks: [Block] = [
        Block(origin: CGPoint(x: 0, y: 47.74)),
        Block(origin: CGPoint(x: 4.88, y: 35.81), fall: CGSize(width: 6.35, height: 6.42), rotation: 0.5448),
        Block(origin: CGPoint(x: 21.16, y: 47.74)),
        Block(origin: CGPoint(x: 27.13, y: 35.81), fall: CGSize(width: 3.33, height: 4.65), rotation: 0.7368),
        Block(origin: CGPoint(x: 33.1, y: 23.87), fall: CGSize(width: 8.66, height: 10.89), rotation: 0.3718),
        Block(origin: CGPoint(x: 42.32, y: 47.74)),
        Block(origin: CGPoint(x: 48.29, y: 35.81), fall: CGSize(width: 5.46, height: 5.93), rotation: 0.3665),
        Block(origin: CGPoint(x: 54.26, y: 23.87), fall: CGSize(width: 5.74, height: 7.13)),
        Block(origin: CGPoint(x: 60.22, y: 11.94), fall: CGSize(width: -13.22, height: 10.07), rotation: -0.4506),
        Block(origin: CGPoint(x: 66.19, y: 47.74)),
        Block(origin: CGPoint(x: 72.16, y: 35.81), fall: CGSize(width: 6.24, height: 9.59), rotation: 0.6563),
        Block(origin: CGPoint(x: 78.13, y: 23.87), fall: CGSize(width: -6.51, height: 9.75), rotation: -0.3327),
        Block(origin: CGPoint(x: 84.1, y: 11.94), fall: CGSize(width: 9.89, height: 31.05), rotation: 0.7247),
        Block(origin: CGPoint(x: 90.06, y: 0), fall: CGSize(width: -5.06, height: 32)),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.blocks.indices, id: \.self) { index in
                let block = Self.blocks[index]
                Rectangle()
                    .fill(Color.criticalInk)
                    .frame(width: Self.size, height: Self.size)
                    .rotationEffect(.radians(hasFallen ? block.rotation : 0))
                    .offset(
                        x: block.origin.x + (hasFallen ? block.fall.width : 0),
                        y: block.origin.y + (hasFallen ? block.fall.height : 0)
                    )
            }
        }
        .frame(width: 102, height: 60, alignment: .topLeading)
        .onAppear {
            if reduceMotion {
                hasFallen = true
            } else {
                withAnimation(.timingCurve(0.5, 0, 0.5, 1, duration: 0.415)) { hasFallen = true }
            }
        }
    }
}

#Preview {
    VStack(spacing: 60) {
        AylaStatusIndicator(state: .thinking, message: "Ayla denkt na")
        AylaStatusIndicator(state: .failed, message: "Ayla kon nu geen antwoord geven.")
    }
}
