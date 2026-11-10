import PAVECore
import SwiftUI

/// Ayla's orb from the voice demo: a round field of square pixel blocks in PAVE greens, like her stepped slash.
/// Each state moves the blocks differently, driven by how loud the user (listening) or Ayla (speaking) is.
/// While Ayla talks about part of PAVE, the blocks briefly form its icon and then flow back into the orb.
struct AylaPixelOrb: View {
    enum Mode: Int {
        case idle
        case listening
        case thinking
        case speaking
    }

    let mode: Mode
    var meter: VoiceMeter?
    var icon: (Date) -> AylaVoiceIcon? = { _ in nil }
    /// Where the orb is on screen. When it moves (jumping to its other place) its blocks break loose and trail
    /// behind it, and they click back together when it stops.
    var position: CGPoint?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animator = PixelOrbAnimator()

    /// Room around the orb on every side, as a share of its size, for blocks that break loose while it moves.
    private static let overflow = 0.6

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            // A clear view is not touchable by itself; the orb is, so it can be tapped and dragged.
            .contentShape(.circle)
            .overlay {
                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height)
                    let extra = side * Self.overflow
                    TimelineView(.animation) { context in
                        Canvas { graphics, _ in
                            let level: Double = switch mode {
                            case .listening: Double(meter?.microphoneLevel ?? 0)
                            case .speaking: Double(meter?.speakerLevel ?? 0)
                            default: 0
                            }
                            graphics.translateBy(x: extra, y: extra)
                            animator.draw(
                                in: &graphics,
                                side: side,
                                date: context.date,
                                mode: mode,
                                level: level,
                                icon: icon(context.date),
                                position: position,
                                reduceMotion: reduceMotion
                            )
                        }
                    }
                    .frame(width: side + extra * 2, height: side + extra * 2)
                    .offset(x: -extra, y: -extra)
                }
                .allowsHitTesting(false)
            }
            .accessibilityHidden(true)
    }
}

/// The moving parts of the orb between frames: state weights blend instead of jumping, and the loudness is smoothed.
final class PixelOrbAnimator {
    private static let cells = 23
    /// Light to dark PAVE greens, the same as in the voice demo.
    private static let palette: [Color] = [.orbShade0, .orbShade1, .orbShade2, .orbShade3, .orbShade4, .orbShade5, .orbShade6]

    private var mix: [Double] = [1, 0, 0, 0]
    private var smoothLevel = 0.0
    private var listenPhase = 0.0
    private var lastDate: Date?
    private var iconMix = 0.0
    private var smoothScatter = CGVector.zero
    private var lastPosition: CGPoint?
    private var lastMoveDate: Date?
    private var velocity = CGVector.zero
    private var shownIcon: AylaVoiceIcon?

    func draw(
        in graphics: inout GraphicsContext,
        side: CGFloat,
        date: Date,
        mode: AylaPixelOrb.Mode,
        level: Double,
        icon: AylaVoiceIcon?,
        position: CGPoint?,
        reduceMotion: Bool
    ) {
        let t = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
        let dt = lastDate.map { min(date.timeIntervalSince($0), 0.1) } ?? 0
        lastDate = date
        let scatter = reduceMotion ? .zero : motion(to: position, date: date, dt: dt)
        // Follows the movement with a little delay, so the blocks feel loose, and snaps back together once it stops.
        let follow = Self.step(0.22, dt)
        smoothScatter.dx += ((reduceMotion ? 0 : scatter.dx) - smoothScatter.dx) * follow
        smoothScatter.dy += ((reduceMotion ? 0 : scatter.dy) - smoothScatter.dy) * follow
        if abs(smoothScatter.dx) + abs(smoothScatter.dy) < 0.003 { smoothScatter = .zero }
        let pull = min(1.4, (smoothScatter.dx * smoothScatter.dx + smoothScatter.dy * smoothScatter.dy).squareRoot())
        // Behind the finger, and across it.
        let behind = pull > 0 ? CGVector(dx: -smoothScatter.dx / pull, dy: -smoothScatter.dy / pull) : .zero
        let across = CGVector(dx: -behind.dy, dy: behind.dx)

        // The demo smooths per frame at 60 frames per second; iPhones draw up to 120, so it is scaled by time.
        for index in mix.indices {
            mix[index] += ((mode.rawValue == index ? 1 : 0) - mix[index]) * Self.step(0.08, dt)
        }
        smoothLevel += (level - smoothLevel) * Self.step(0.35, dt)
        if !reduceMotion { listenPhase += dt * (4.5 + smoothLevel * 6) }

        if let icon { shownIcon = icon }
        iconMix += ((icon != nil ? 1 : 0) - iconMix) * (reduceMotion ? 1 : Self.step(0.12, dt))
        if iconMix < 0.01, icon == nil { shownIcon = nil }
        let iconRows = shownIcon.map(AylaPixelIcons.rows(for:))

        let (idle, listening, thinking, speaking) = (mix[0], mix[1], mix[2], mix[3])
        let cells = Self.cells
        let cell = side / CGFloat(cells)
        let gap = max(1, cell * 0.16)
        let center = Double(cells - 1) / 2

        // The outline breathes while listening and leans in when the user talks, and swells with Ayla's voice.
        let radius = 0.86
            + listening * (0.04 * sin(t * 2.6) + smoothLevel * 0.08)
            + thinking * 0.03 * sin(t * 5)
            + speaking * smoothLevel * 0.14

        for i in 0..<cells {
            for j in 0..<cells {
                let x = (Double(i) - center) / center
                let y = (Double(j) - center) / center
                let r = (x * x + y * y).squareRoot()
                let h = Self.hash(i, j)

                // A ragged, slowly flickering edge, so the circle feels alive.
                let edge = radius + (h - 0.5) * 0.14 + 0.04 * sin(t * 1.3 + h * 20)
                guard r <= edge else { continue }

                // Darker towards the lower left, like Ayla's slash.
                var v = 0.62 - r * 0.35 + (y - x) * 0.12
                v += idle * 0.16 * sin(t * 1.1 + h * .pi * 2)
                v += listening * (0.22 + smoothLevel * 0.4) * sin(r * 9 + listenPhase)
                v += thinking * 0.4 * sin((x + y) * 4 + t * 7)
                v += speaking * (0.15 + smoothLevel * 0.55) * sin(r * 11 - t * 11)
                v += speaking * smoothLevel * 0.25 * (1 - r)

                // An icon assembles block by block: dark in the icon, very light around it.
                if let iconRows {
                    let offset = (cells - iconRows.count) / 2
                    let wave = shownIcon == .hand && !reduceMotion ? Int((sin(t * 7)).rounded()) : 0
                    let row = j - offset
                    let column = i - offset - wave
                    var inIcon = false
                    if iconRows.indices.contains(row) {
                        let characters = Array(iconRows[row])
                        inIcon = characters.indices.contains(column) && characters[column] == "#"
                    }
                    let local = min(1, max(0, iconMix * 1.6 - h * 0.6))
                    v += ((inIcon ? 1 : 0.05) - v) * local
                }

                v = min(1, max(0, v))
                let index = min(Self.palette.count - 1, Int(v * Double(Self.palette.count)))
                let alpha = min(1, max(0.25, (edge - r) * 7))
                var rect = CGRect(x: CGFloat(i) * cell + gap / 2, y: CGFloat(j) * cell + gap / 2, width: cell - gap, height: cell - gap)
                var looseAlpha = 1.0
                if pull > 0 {
                    // Breaking apart while dragged: blocks trail behind the finger, the outer ones most, they fan out
                    // across the direction and shrink a little, and a few come loose completely.
                    let h2 = Self.hash(j + 7, i + 3)
                    let h3 = Self.hash(i + 31, j + 17)
                    var trail = pull * Double(cell) * (0.5 + r * 2.4) * (0.35 + h * 0.8)
                    let side = x * across.dx + y * across.dy
                    let fan = (side * 0.9 + (h2 - 0.5) * 1.6) * pull * Double(cell) * r
                    if h3 > 1 - min(1, pull) * 0.22 {
                        trail += pull * Double(cell) * (2 + h3 * 4)
                        looseAlpha = 1 - min(1, pull) * 0.45
                    }
                    let shrink = Double(cell - gap) * min(1, pull) * 0.16
                    rect = rect
                        .offsetBy(dx: behind.dx * trail + across.dx * fan, dy: behind.dy * trail + across.dy * fan)
                        .insetBy(dx: shrink / 2, dy: shrink / 2)
                }
                graphics.fill(Path(rect), with: .color(Self.palette[index].opacity(alpha * looseAlpha)))
            }
        }
    }

    /// How the orb moves on screen, from one frame to the next, as a pull of about 1 at a brisk speed. A frame drawn
    /// before the orb moved again counts as standing still only after a moment, so the speed does not flicker.
    private func motion(to position: CGPoint?, date: Date, dt: Double) -> CGVector {
        guard let position else { return .zero }
        defer { lastPosition = position }
        guard let lastPosition, dt > 0 else {
            lastMoveDate = date
            return .zero
        }
        let dx = Double(position.x - lastPosition.x)
        let dy = Double(position.y - lastPosition.y)
        if abs(dx) + abs(dy) > 0.01 {
            let seconds = max(1.0 / 240, date.timeIntervalSince(lastMoveDate ?? date))
            lastMoveDate = date
            let follow = Self.step(0.45, dt)
            velocity.dx += (dx / seconds - velocity.dx) * follow
            velocity.dy += (dy / seconds - velocity.dy) * follow
        } else if date.timeIntervalSince(lastMoveDate ?? date) > 1.0 / 30 {
            velocity = .zero
        }
        let speed = 1300.0
        return CGVector(dx: velocity.dx / speed, dy: velocity.dy / speed)
    }

    /// How far to move towards a target in `dt` seconds, for a smoothing written per frame at 60 frames per second.
    private static func step(_ perFrame: Double, _ dt: Double) -> Double {
        1 - pow(1 - perFrame, dt * 60)
    }

    private static func hash(_ i: Int, _ j: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(j) * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }
}

#Preview {
    VStack(spacing: 24) {
        AylaPixelOrb(mode: .idle)
            .frame(width: 160)
        AylaPixelOrb(mode: .thinking)
            .frame(width: 160)
    }
    .padding()
    .background(Color.canvas)
}
