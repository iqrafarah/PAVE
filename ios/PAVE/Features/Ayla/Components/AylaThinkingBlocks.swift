import SwiftUI

/// Fourteen blocks that build up Ayla's four slashes one by one, in a 7-second loop (from Figma).
struct AylaThinkingBlocks: View {
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

#Preview {
    AylaThinkingBlocks()
        .padding()
}
