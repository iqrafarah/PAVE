import SwiftUI

/// The start and end of a spoken conversation, with the blocks of Ayla's orb:
/// - intro: the blocks burst out of the voice button and swirl into place, after which the real orb takes over;
/// - outro: the orb falls apart into its blocks, which swirl back into the button.
/// Everything is drawn in the chat screen's coordinates.
struct AylaVoiceIntro: View {
    enum Phase: Equatable {
        case intro(Date)
        case outro(Date)
    }

    /// When the real orb takes over from the blocks.
    static let introArrival = Duration.seconds(1.2)
    static let introDuration = Duration.seconds(1.5)
    static let outroDuration = Duration.seconds(1.15)

    let phase: Phase
    let buttonCenter: CGPoint
    let orbFrame: CGRect

    @State private var animator = VoiceIntroAnimator()

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphics, _ in
                animator.draw(in: &graphics, date: context.date, phase: phase, buttonCenter: buttonCenter, orbFrame: orbFrame)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

final class VoiceIntroAnimator {
    private struct Block {
        let jitter: CGPoint
        /// How far the path bows to the side, as a share of its length; mostly one way, so the blocks swirl.
        let bend: Double
        let delay: Double
    }

    // Seconds.
    private static let introFlight = 0.75
    private static let introArrival = 1.2
    private static let introEnd = 1.5
    private static let outroFlight = 0.7
    private static let outroEnd = 1.1

    private static let palette: [Color] = [Color.paveOrbShade(0), Color.paveOrbShade(1), Color.paveOrbShade(2), Color.paveOrbShade(3), Color.paveOrbShade(4), Color.paveOrbShade(5), Color.paveOrbShade(6)]

    private var phase: AylaVoiceIntro.Phase?
    private var blocks: [Block] = []
    private var orbKey = CGRect.null
    private var orbTargets: [(point: CGPoint, color: Color)] = []

    func draw(in graphics: inout GraphicsContext, date: Date, phase: AylaVoiceIntro.Phase, buttonCenter: CGPoint, orbFrame: CGRect) {
        guard !orbFrame.isEmpty else { return }
        if orbFrame != orbKey {
            orbKey = orbFrame
            orbTargets = Self.orbTargets(in: orbFrame)
        }
        if self.phase != phase || blocks.count != orbTargets.count {
            self.phase = phase
            blocks = Self.makeBlocks(count: orbTargets.count, delays: phase.isIntro ? 0.45 : 0.4)
        }
        let orbCell = Double(min(orbFrame.width, orbFrame.height)) / Double(PixelOrbGrid.cells)
        let full = orbCell * 0.84

        switch phase {
        case .intro(let start):
            let t = date.timeIntervalSince(start)
            let fade = t > Self.introArrival ? max(0, 1 - (t - Self.introArrival) / (Self.introEnd - Self.introArrival)) : 1
            guard fade > 0 else { return }
            for (block, target) in zip(blocks, orbTargets) {
                let p = Self.easeOut(Self.clamp((t - block.delay) / Self.introFlight))
                guard p > 0 else { continue }
                let from = CGPoint(x: buttonCenter.x + block.jitter.x, y: buttonCenter.y + block.jitter.y)
                let point = Self.curve(from, target.point, bend: block.bend, p)
                Self.fill(&graphics, point, 2 + (full - 2) * p, target.color.opacity(fade))
            }
        case .outro(let start):
            let t = date.timeIntervalSince(start)
            guard t < Self.outroEnd else { return }
            for (block, target) in zip(blocks, orbTargets) {
                let p = Self.easeInOut(Self.clamp((t - block.delay) / Self.outroFlight))
                let to = CGPoint(x: buttonCenter.x + block.jitter.x, y: buttonCenter.y + block.jitter.y)
                let point = Self.curve(target.point, to, bend: -block.bend, p)
                Self.fill(&graphics, point, full + (2 - full) * p, target.color.opacity(1 - p * 0.4))
            }
        }
    }

    private static func makeBlocks(count: Int, delays: Double) -> [Block] {
        (0..<count).map { _ in
            let angle = Double.random(in: 0..<(.pi * 2))
            let radius = Double.random(in: 0..<8)
            return Block(
                jitter: CGPoint(x: cos(angle) * radius, y: sin(angle) * radius),
                bend: Double.random(in: -0.15...0.4),
                delay: Double.random(in: 0..<delays)
            )
        }
    }

    /// The same grid the orb draws, so the hand-over is seamless.
    private static func orbTargets(in frame: CGRect) -> [(point: CGPoint, color: Color)] {
        let side = Double(min(frame.width, frame.height))
        let cells = PixelOrbGrid.cells
        let cell = side / Double(cells)
        let center = Double(cells - 1) / 2
        let originX = Double(frame.midX) - side / 2
        let originY = Double(frame.midY) - side / 2
        var targets: [(point: CGPoint, color: Color)] = []
        for i in 0..<cells {
            for j in 0..<cells {
                let x = (Double(i) - center) / center
                let y = (Double(j) - center) / center
                let r = (x * x + y * y).squareRoot()
                guard r <= PixelOrbGrid.radius else { continue }
                let v = min(1, max(0, 0.62 - r * 0.35 + (y - x) * 0.12))
                let color = palette[min(palette.count - 1, Int(v * Double(palette.count)))]
                targets.append((CGPoint(x: originX + (Double(i) + 0.5) * cell, y: originY + (Double(j) + 0.5) * cell), color))
            }
        }
        return targets
    }

    /// A bowed path from `a` to `b`.
    private static func curve(_ a: CGPoint, _ b: CGPoint, bend: Double, _ t: Double) -> CGPoint {
        let control = CGPoint(
            x: (a.x + b.x) / 2 - (b.y - a.y) * bend,
            y: (a.y + b.y) / 2 + (b.x - a.x) * bend
        )
        let u = 1 - t
        return CGPoint(
            x: u * u * a.x + 2 * u * t * control.x + t * t * b.x,
            y: u * u * a.y + 2 * u * t * control.y + t * t * b.y
        )
    }

    private static func fill(_ graphics: inout GraphicsContext, _ point: CGPoint, _ side: Double, _ color: Color) {
        graphics.fill(Path(CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)), with: .color(color))
    }

    private static func clamp(_ t: Double) -> Double { min(1, max(0, t)) }
    private static func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
    private static func easeInOut(_ t: Double) -> Double { t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }
}

private extension AylaVoiceIntro.Phase {
    var isIntro: Bool {
        if case .intro = self { true } else { false }
    }
}

/// The orb's grid, shared by the orb and the intro.
enum PixelOrbGrid {
    static let cells = 23
    /// Blocks inside this radius (from -1 to 1) make up the orb at rest.
    static let radius = 0.84
}
