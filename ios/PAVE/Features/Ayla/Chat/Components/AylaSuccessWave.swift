import SwiftUI

/// A ring of Ayla's pixel blocks that rolls out over the screen from one point, once: the moment something went into
/// the vault. The same blocks and colours as the field around the orb while talking.
struct AylaSuccessWave: View {
    let startedAt: Date
    /// Where the wave starts, in the view's own coordinates.
    let origin: CGPoint

    private static let duration = 1.5
    private static let width = 120.0

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphics, size in
                let progress = min(1, context.date.timeIntervalSince(startedAt) / Self.duration)
                guard progress < 1 else { return }
                let cell = size.width < 600 ? 18.0 : 24.0
                let block = cell * 0.36
                let reach = hypot(max(origin.x, size.width - origin.x), max(origin.y, size.height - origin.y))
                let radius = (1 - pow(1 - progress, 2.2)) * (reach + Self.width)
                let fade = 1 - pow(progress, 2)
                let columns = Int(ceil(size.width / cell))
                let rows = Int(ceil(size.height / cell))
                for column in 0...columns {
                    for row in 0...rows {
                        let x = origin.x + (Double(column) - Double(Int(origin.x / cell))) * cell
                        let y = origin.y + (Double(row) - Double(Int(origin.y / cell))) * cell
                        let distance = hypot(x - origin.x, y - origin.y)
                        let strength = max(0, 1 - abs(distance - radius) / Self.width)
                        let opacity = strength * strength * fade * 0.7
                        guard opacity > 0.01 else { continue }
                        graphics.fill(
                            Path(CGRect(x: x - block / 2, y: y - block / 2, width: block, height: block)),
                            with: .color(Color.paveOrbShade(5).opacity(opacity))
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
