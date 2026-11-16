import SwiftUI

/// While connecting: small square pixels in PAVE greens stream up from the iPhone (the bottom of the stage) into the
/// Watch, swaying a little, like Ayla's orb is made of.
struct WatchPixelStream: View {
    /// Where the pixels end up, from the top of the view.
    let target: CGFloat

    private static let count = 34
    private static let colors: [Color] = [Color.paveOrbShade(2), Color.paveOrbShade(3), Color.paveOrbShade(4), Color.paveOrbShade(5), .paveAccent]

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { canvas, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for index in 0..<Self.count {
                    let seed = Double(index) * 0.618
                    let speed = 0.55 + (seed.truncatingRemainder(dividingBy: 1)) * 0.5
                    let progress = (time * speed + seed).truncatingRemainder(dividingBy: 1)
                    let start = size.height
                    let y = start - (start - target) * progress
                    let spread = (1 - progress) * size.width * 0.32
                    let x = size.width / 2 + sin(time * 2 + seed * 9) * 10 + cos(seed * 13) * spread
                    let side = 3 + (1 - progress) * 4
                    let rect = CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side)
                    let fade = min(1, progress * 4) * (1 - progress * progress)
                    canvas.fill(Path(rect), with: .color(Self.colors[index % Self.colors.count].opacity(fade)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A ring around the Watch: it spins while connecting and closes when done, then sends one pulse outwards.
struct WatchConnectRing: View {
    let isDone: Bool
    var size: CGFloat = 250

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: isDone ? 1 : 0.72)
                .stroke(
                    AngularGradient(colors: [Color.paveOrbShade(2), Color.paveOrbShade(4), .paveAccent, Color.paveOrbShade(2)], center: .center),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(spin ? 360 : 0))
            Circle()
                .stroke(Color.paveOrbShade(4), lineWidth: 3)
                .scaleEffect(pulse ? 1.45 : 1)
                .opacity(pulse ? 0 : (isDone ? 0.8 : 0))
        }
        .frame(width: size, height: size)
        .animation(.spring(duration: 0.6, bounce: 0.2), value: isDone)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { spin = true }
        }
        .onChange(of: isDone) { _, done in
            guard done, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.9).delay(0.25)) { pulse = true }
        }
        .accessibilityHidden(true)
    }
}
