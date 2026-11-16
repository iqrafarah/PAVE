import SwiftUI

/// A live sound wave of pixel blocks while you dictate, like the waveform in ChatGPT's dictation:
/// every bar is a moment, the newest on the right, and louder means taller.
struct PixelLevelWave: View {
    let meter: VoiceMeter
    var bars = 24

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var history = LevelHistory()

    private static let block: CGFloat = 3
    private static let gap: CGFloat = 1.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            Canvas { graphics, size in
                history.sample(meter.microphoneLevel, at: context.date, keeping: bars)
                let maxBlocks = max(1, Int((size.height + Self.gap) / (Self.block + Self.gap)))
                let barWidth = size.width / CGFloat(bars)
                let levels = history.levels
                let start = bars - levels.count
                for (offset, level) in levels.enumerated() {
                    let blocks = max(1, min(maxBlocks, Int((Double(level) * Double(maxBlocks) * 1.5).rounded(.up))))
                    let x = CGFloat(start + offset) * barWidth + (barWidth - Self.block) / 2
                    let height = CGFloat(blocks) * Self.block + CGFloat(blocks - 1) * Self.gap
                    var y = (size.height - height) / 2
                    for _ in 0..<blocks {
                        graphics.fill(
                            Path(CGRect(x: x, y: y, width: Self.block, height: Self.block)),
                            with: .color(blocks > 1 ? .paveAccent : Color.paveOrbShade(2))
                        )
                        y += Self.block + Self.gap
                    }
                }
            }
        }
        .frame(height: 22)
        .accessibilityHidden(true)
    }
}

/// The recent loudness, one value about every 80 ms.
final class LevelHistory {
    private(set) var levels: [Float] = []
    private var lastSample: Date?

    func sample(_ level: Float, at date: Date, keeping count: Int) {
        if let lastSample, date.timeIntervalSince(lastSample) < 0.08 { return }
        lastSample = date
        levels.append(level)
        if levels.count > count { levels.removeFirst(levels.count - count) }
    }
}

#Preview {
    PixelLevelWave(meter: VoiceMeter())
        .padding()
}
