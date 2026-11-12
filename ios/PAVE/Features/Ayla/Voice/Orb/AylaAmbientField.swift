import SwiftUI

/// The screen around Ayla's orb during a spoken conversation, made of small pixel blocks, so everything plays along
/// with her (from `AmbientField.vue` in the voice demo, without its loose flying blocks: Daaf's choice):
/// - a soft glow and waves across a block grid: in while listening, diagonal while thinking, out while speaking,
///   an odd twinkle when idle;
/// - a ring of blocks around the orb that follows the voice like an equalizer (yours in sage, Ayla's in green);
/// Until `revealedAt` is set the field is empty; then it appears in a wave rolling out from the orb.
struct AylaAmbientField: View {
    let mode: AylaPixelOrb.Mode
    let meter: VoiceMeter
    /// Where the orb is on screen, every frame (also while it moves), so the field stays exactly around it.
    let orbFrame: CGRect
    /// Where text sits on screen (the line under the orb): no blocks are drawn behind it, so it stays readable.
    var quietFrame = CGRect.null
    let revealedAt: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animator = AmbientFieldAnimator()
    /// Where the field itself is on screen, measured on what it draws: it reaches under the bars, so its
    /// container's frame is not where it draws.
    @State private var origin = CGPoint.zero

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
            Canvas { graphics, size in
                let listening = mode == .listening
                animator.draw(
                    in: &graphics,
                    size: size,
                    date: context.date,
                    mode: mode,
                    level: Double(listening ? meter.microphoneLevel : mode == .speaking ? meter.speakerLevel : 0),
                    bands: listening ? meter.microphoneBands : mode == .speaking ? meter.speakerBands : [],
                    center: CGPoint(x: orbFrame.midX - origin.x, y: orbFrame.midY - origin.y),
                    orbRadius: orbFrame.width / 2 * 0.86,
                    quiet: quietFrame.isNull ? .null : quietFrame.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -16, dy: -12),
                    revealedAt: revealedAt,
                    reduceMotion: reduceMotion
                )
            }
        }
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { origin = $0 }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The moving parts of the field between frames. Speeds are written per frame at 60 frames per second, as in the demo,
/// and scaled by the real time between frames.
final class AmbientFieldAnimator {
    private static let revealDuration = 1.6
    private static let green = Color.paveOrbShade(6)
    private static let sage = Color.paveOrbShade(4)

    private var mix: [Double] = [1, 0, 0, 0]
    private var smoothLevel = 0.0
    private var lastDate: Date?
    private var center = CGPoint.zero
    private var orbRadius = 0.0

    func draw(
        in graphics: inout GraphicsContext,
        size: CGSize,
        date: Date,
        mode: AylaPixelOrb.Mode,
        level: Double,
        bands: [Float],
        center: CGPoint,
        orbRadius: CGFloat,
        quiet: CGRect,
        revealedAt: Date?,
        reduceMotion: Bool
    ) {
        let t = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
        let seconds = lastDate.map { min(date.timeIntervalSince($0), 0.1) } ?? 0
        let dt = lastDate == nil ? 1 : min(seconds * 60, 3)
        lastDate = date
        self.center = center
        self.orbRadius = Double(orbRadius)

        for index in mix.indices {
            mix[index] += ((mode.rawValue == index ? 1 : 0) - mix[index]) * Self.step(0.05, dt)
        }
        smoothLevel += (level - smoothLevel) * Self.step(0.3, dt)
        let (idle, listening, thinking, speaking) = (mix[0], mix[1], mix[2], mix[3])

        // Nothing on screen until the intro reveals it.
        guard let revealedAt else { return }
        let revealT = reduceMotion ? 1 : min(1, date.timeIntervalSince(revealedAt) / Self.revealDuration)
        let reveal = 1 - pow(1 - revealT, 3)
        let width = Double(size.width)
        let height = Double(size.height)
        let cx = Double(self.center.x)
        let cy = Double(self.center.y)

        // A soft green glow around the orb; brighter when active, pulsing with the voice.
        let glow = (listening * (0.08 + smoothLevel * 0.08) + thinking * 0.08 + speaking * (0.1 + smoothLevel * 0.14)) * reveal
        if glow > 0.003 {
            let gradient = Gradient(colors: [Self.green.opacity(glow), Self.green.opacity(0)])
            graphics.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(gradient, center: self.center, startRadius: self.orbRadius * 0.3, endRadius: max(size.width, size.height) * 0.6)
            )
        }

        // A block grid aligned on the orb's centre, so the rings stay round.
        let cell = width < 600 ? 18.0 : 24.0
        let block = cell * 0.36
        let reach = hypot(max(cx, width - cx), max(cy, height - cy))
        let i0 = -Int(ceil(cx / cell))
        let i1 = Int(ceil((width - cx) / cell))
        let j0 = -Int(ceil(cy / cell))
        let j1 = Int(ceil((height - cy) / cell))
        // The reveal: a ring of blocks rolling out from the orb to the corners.
        let waveRadius = reveal * reach * 1.1
        let waveWidth = 70.0

        if i0 <= i1, j0 <= j1 {
            for i in i0...i1 {
                for j in j0...j1 {
                    let x = cx + Double(i) * cell
                    let y = cy + Double(j) * cell
                    let d = hypot(x - cx, y - cy)
                    if d < self.orbRadius * 1.6 || d > waveRadius || quiet.contains(CGPoint(x: x, y: y)) { continue }
                    let h = Self.hash(i, j)
                    let far = d / reach

                    var a = revealT < 1 ? max(0, 1 - abs(d - waveRadius) / waveWidth) * 0.45 * (0.5 + h * 0.5) : 0
                    a += idle * max(0, sin(t * 0.5 + h * 60) - 0.93) * 2.2
                    let inward = pow(max(0, sin(d / 70 + t * 3.2)), 10)
                    a += listening * inward * (0.08 + far * 0.3) * (0.6 + smoothLevel * 1.2)
                    let diagonal = pow(max(0, sin((x - cx + (y - cy)) / 140 + t * 3.5)), 12)
                    a += thinking * diagonal * 0.3 * (0.6 + h * 0.4)
                    let outward = pow(max(0, sin(d / 55 - t * 6)), 8)
                    a += speaking * outward * (0.06 + smoothLevel * 0.5) * (1 - far * 0.8)

                    if a < 0.01 { continue }
                    graphics.fill(
                        Path(CGRect(x: x - block / 2, y: y - block / 2, width: block, height: block)),
                        with: .color(Self.green.opacity(min(a, 0.55)))
                    )
                }
            }
        }

        // The equalizer ring: columns of blocks per frequency band, mirrored so the low tones (usually the loudest)
        // sit at the top on both sides, away from the text under the orb.
        let ringWeight = max(listening, speaking) * reveal
        if ringWeight > 0.02, !bands.isEmpty {
            let count = bands.count
            let segments = count * 2
            let step = cell * 0.55
            let blockSize = cell * 0.36
            let color = speaking > listening ? Self.green : Self.sage
            // Just outside the orb's ragged edge, which swells with the voice (the same sums as in `AylaPixelOrb`).
            let half = self.orbRadius / 0.86
            let swell = listening * (0.04 * sin(t * 2.6) + smoothLevel * 0.08) + speaking * smoothLevel * 0.14
            let ringStart = half * (1.02 + swell)
            for k in 0..<segments {
                let band = k < count ? k : segments - 1 - k
                let value = Double(bands[band]) * ringWeight
                let blocks = min(8, Int((value * 10).rounded()))
                guard blocks > 0 else { continue }
                let angle = -Double.pi / 2 + Double(k) / Double(segments) * Double.pi * 2
                for b in 0..<blocks {
                    let r = ringStart + Double(b) * step
                    let x = (cx + cos(angle) * r - blockSize / 2).rounded()
                    let y = (cy + sin(angle) * r - blockSize / 2).rounded()
                    if quiet.contains(CGPoint(x: x + blockSize / 2, y: y + blockSize / 2)) { continue }
                    graphics.fill(
                        Path(CGRect(x: x, y: y, width: blockSize, height: blockSize)),
                        with: .color(color.opacity(0.8 - Double(b) / 8 * 0.55))
                    )
                }
            }
        }
    }

    /// How far to move towards a target in `dt` frames, for a smoothing written per frame at 60 frames per second.
    private static func step(_ perFrame: Double, _ dt: Double) -> Double {
        1 - pow(1 - perFrame, dt)
    }

    private static func hash(_ i: Int, _ j: Int) -> Double {
        let x = sin(Double(i) * 127.1 + Double(j) * 311.7) * 43758.5453
        return x - x.rounded(.down)
    }
}
