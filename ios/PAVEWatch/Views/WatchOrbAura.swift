import SwiftUI

/// The life around Ayla's orb on the Watch, in the same square pixels and PAVE greens as the orb. Ready: pixels drift
/// slowly around her and twinkle. Listening: they gather close and a ring of pixels goes out with every word you say.
/// Thinking: they swirl inwards while a comet of pixels circles her. Speaking: rings go out on her voice like sound.
/// Nothing moves with Reduce Motion or on the dimmed always-on screen; then only a soft glow stays.
struct WatchOrbAura: View {
    let phase: WatchAylaModel.Phase
    let meter: VoiceMeter

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var animator = WatchOrbAuraAnimator()

    var body: some View {
        if reduceMotion || isLuminanceReduced {
            RadialGradient(colors: [Color.brandGreen.opacity(isLuminanceReduced ? 0.15 : 0.35), .clear], center: .center, startRadius: 0, endRadius: 80)
                .accessibilityHidden(true)
        } else {
            TimelineView(.animation) { context in
                Canvas { graphics, size in
                    let level: Double = switch phase {
                    case .listening: Double(meter.microphoneLevel)
                    case .speaking: Double(meter.speakerLevel)
                    default: 0
                    }
                    animator.draw(in: &graphics, size: size, date: context.date, phase: phase, level: level)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// The state of the aura between frames: how fast and how close the pixels move blends from one phase to the next,
/// the loudness is smoothed, and rings live for a moment after they are sent out.
final class WatchOrbAuraAnimator {
    private struct Ring {
        let born: Date
        let strength: Double
    }

    private static let moteCount = 22
    private static let palette: [Color] = [.orbShade1, .orbShade2, .orbShade3, .orbShade4, .brandGreen]

    private var lastDate: Date?
    private var angle = 0.0
    private var speed = 0.15
    private var pull = 1.0
    private var glow = 0.35
    private var thinking = 0.0
    private var smoothLevel = 0.0
    private var rings: [Ring] = []
    private var lastRing = Date.distantPast

    func draw(in graphics: inout GraphicsContext, size: CGSize, date: Date, phase: WatchAylaModel.Phase, level: Double) {
        let dt = min(1.0 / 20, lastDate.map { date.timeIntervalSince($0) } ?? 0)
        lastDate = date
        smoothLevel += (min(1, level * 1.6) - smoothLevel) * min(1, dt * 12)

        // Where each phase wants the pixels: speed in turns per second, distance from the orb, glow, swirl.
        let target: (speed: Double, pull: Double, glow: Double, thinking: Double) = switch phase {
        case .ready, .answer: (0.05, 1.0, 0.32, 0)
        case .listening: (0.09, 0.82 + smoothLevel * 0.22, 0.45 + smoothLevel * 0.45, 0)
        case .understanding, .thinking: (0.42, 0.9, 0.5, 1)
        case .speaking: (0.07, 1.0 + smoothLevel * 0.18, 0.42 + smoothLevel * 0.5, 0)
        case .failed: (0.03, 1.05, 0.25, 0)
        }
        let blend = min(1, dt * 4)
        speed += (target.speed - speed) * blend
        pull += (target.pull - pull) * blend
        glow += (target.glow - glow) * blend
        thinking += (target.thinking - thinking) * blend
        angle += speed * dt * .pi * 2

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2
        let tint: Color = if case .failed = phase { .errorGlow } else { .brandGreen }
        let time = date.timeIntervalSinceReferenceDate

        // Glow behind everything, breathing slowly when nothing happens.
        let breathe = 0.85 + sin(time * 1.4) * 0.15
        graphics.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [tint.opacity(glow * breathe), tint.opacity(glow * 0.25), .clear]),
                center: center,
                startRadius: radius * 0.3,
                endRadius: radius
            )
        )

        // Rings of pixels going out with the voice.
        if case .listening = phase, smoothLevel > 0.22, date.timeIntervalSince(lastRing) > 0.32 { addRing(date) }
        if case .speaking = phase, smoothLevel > 0.18, date.timeIntervalSince(lastRing) > 0.28 { addRing(date) }
        rings.removeAll { date.timeIntervalSince($0.born) > 1.1 }
        for ring in rings {
            let age = date.timeIntervalSince(ring.born) / 1.1
            let ringRadius = radius * (0.62 + age * 0.4)
            let dots = 36
            let side = 2.2
            for index in 0..<dots {
                let theta = Double(index) / Double(dots) * .pi * 2 + angle * 0.5
                let point = CGPoint(x: center.x + cos(theta) * ringRadius, y: center.y + sin(theta) * ringRadius)
                graphics.fill(
                    Path(CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)),
                    with: .color(Color.orbShade2.opacity((1 - age) * ring.strength * 0.9))
                )
            }
        }

        // The pixels around the orb: two loose orbits, twinkling; while thinking they spiral in and out.
        for index in 0..<Self.moteCount {
            let seed = Double(index) * 2.399
            let lane = index % 2 == 0 ? 0.78 : 0.94
            let wobble = sin(time * (0.7 + seed.truncatingRemainder(dividingBy: 0.6)) + seed) * 0.04
            let spiral = thinking * sin(time * 3 + seed) * 0.12
            let distance = radius * (lane + wobble + spiral) * pull
            let direction = index % 2 == 0 ? 1.0 : -0.7
            let theta = seed + angle * direction * (1 + thinking * 0.6)
            let point = CGPoint(x: center.x + cos(theta) * distance, y: center.y + sin(theta) * distance)
            let twinkle = 0.45 + 0.55 * max(0, sin(time * 2.2 + seed * 3))
            let side = 2 + (seed.truncatingRemainder(dividingBy: 1)) * 1.8
            let color: Color = if case .failed = phase { .errorGlow } else { Self.palette[index % Self.palette.count] }
            graphics.fill(
                Path(CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)),
                with: .color(color.opacity(twinkle * 0.85))
            )
        }

        // While thinking: a comet of pixels circling the orb, its tail fading.
        if thinking > 0.02 {
            let head = time * 4.2
            for step in 0..<14 {
                let theta = head - Double(step) * 0.11
                let distance = radius * 0.7
                let point = CGPoint(x: center.x + cos(theta) * distance, y: center.y + sin(theta) * distance)
                let side = 3.4 - Double(step) * 0.17
                graphics.fill(
                    Path(CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)),
                    with: .color(Color.thinkingGlow.opacity((1 - Double(step) / 14) * thinking))
                )
            }
        }
    }

    private func addRing(_ date: Date) {
        rings.append(Ring(born: date, strength: min(1, 0.4 + smoothLevel)))
        lastRing = date
        if rings.count > 4 { rings.removeFirst() }
    }
}

#Preview {
    ZStack {
        WatchOrbAura(phase: .thinking, meter: VoiceMeter())
            .frame(width: 180, height: 180)
        AylaPixelOrb(mode: .thinking)
            .frame(width: 110, height: 110)
    }
}
