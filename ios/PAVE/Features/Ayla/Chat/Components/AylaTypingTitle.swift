import SwiftUI

/// The welcome title, typed out with PAVE's slash as the cursor: the slash writes the letters and blinks twice at the
/// end. Then it hands over, square by square: the squares at the end go out from the top, while the real slash in
/// front of the title builds up from the bottom. The full title is laid out from the start, so nothing moves while it
/// types. The slash in front sits against the first line, not the edge of the title: a short, centred first line (a
/// narrow pane on the open iPhone Duo) would otherwise leave it hanging apart. The time counts per frame, so when the
/// app is briefly busy (opening) the typing waits instead of skipping ahead.
struct AylaTypingTitle: View {
    let text: String
    /// Typing starts when this becomes true.
    let isTyping: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isStarted = false
    @State private var isDone = false
    @State private var clock = AylaTypingClock()

    static let markCount = 5
    static let markSize: CGFloat = 6
    static let markSpacing: CGFloat = 10
    /// The squares climb half a square at a time.
    static let markWidth = markSize + CGFloat(markCount - 1) * markSize / 2

    private static let perCharacter = 0.065
    private static let blinks = 0.7
    private static let handOver = 0.55
    /// How long one square takes to fade in or out.
    static let squareFade = 0.1

    var body: some View {
        TimelineView(.animation(paused: isDone || !isStarted)) { context in
            let moment = moment(at: context.date)
            MaxWidthLayout(maxWidth: 289) {
                Text(text)
                    .textStyle(.welcomeTitle)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .textRenderer(AylaTypingRenderer(shown: moment.shown, cursor: moment.cursor, front: moment.front))
            }
            // Room for the slash in front, drawn by the renderer against the first line.
            .padding(.leading, Self.markWidth + Self.markSpacing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .onChange(of: isTyping, initial: true) { _, typing in
            guard typing, !isStarted, !isDone else { return }
            if reduceMotion {
                isDone = true
            } else {
                isStarted = true
                Task {
                    while clock.elapsed < Self.duration(for: text) {
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                    isDone = true
                }
            }
        }
    }

    private struct Moment {
        var shown: Double
        /// The cursor after the last letter: how visible each square is, or nil when it is not there.
        var cursor: ((Int) -> Double)?
        /// The slash in front of the title.
        var front: (Int) -> Double
    }

    private func moment(at date: Date) -> Moment {
        if isDone || reduceMotion { return Moment(shown: .infinity, cursor: nil, front: { _ in 1 }) }
        guard isStarted else { return Moment(shown: 0, cursor: nil, front: { _ in 0 }) }
        let elapsed = clock.tick(date)
        let typing = Double(text.count) * Self.perCharacter
        if elapsed < typing {
            return Moment(shown: elapsed / Self.perCharacter, cursor: { _ in 1 }, front: { _ in 0 })
        }
        let afterTyping = elapsed - typing
        if afterTyping < Self.blinks {
            // Off, on, off, on: two blinks.
            let isOn = Int(afterTyping / (Self.blinks / 4)) % 2 == 1
            return Moment(shown: .infinity, cursor: isOn ? { _ in 1 } : nil, front: { _ in 0 })
        }
        let time = afterTyping - Self.blinks
        let squares = Self.markCount
        return Moment(
            shown: .infinity,
            // Out from the top at the end...
            cursor: { index in 1 - Self.progress(time - Double(squares - 1 - index) * 0.05) },
            // ...and in from the bottom in front.
            front: { index in Self.progress(time - 0.12 - Double(index) * 0.065) }
        )
    }

    private static func progress(_ time: Double) -> Double {
        min(1, max(0, time / squareFade))
    }

    static func duration(for text: String) -> Double {
        Double(text.count) * perCharacter + blinks + handOver
    }
}

/// Time that only moves on while frames are drawn, at most a thirtieth of a second per frame.
final class AylaTypingClock {
    private(set) var elapsed = 0.0
    private var last: Date?

    func tick(_ date: Date) -> Double {
        if let last { elapsed += min(max(0, date.timeIntervalSince(last)), 1.0 / 30) }
        last = date
        return elapsed
    }
}

/// Draws the first `shown` characters, the cursor after them, and the slash in front of the first line.
struct AylaTypingRenderer: TextRenderer {
    let shown: Double
    /// How visible each square of the cursor is; nil draws no cursor.
    let cursor: ((Int) -> Double)?
    /// How visible each square of the slash in front of the first line is.
    var front: (Int) -> Double = { _ in 0 }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var count = 0.0
        var end: CGPoint?
        for line in layout {
            let top = line.typographicBounds.rect.minY
            for run in line {
                for slice in run {
                    guard count < shown else { break }
                    context.draw(slice)
                    count += 1
                    end = CGPoint(x: slice.typographicBounds.rect.maxX + 3, y: top)
                }
            }
        }
        let start = firstLetter(of: layout)
        drawMark(at: CGPoint(x: start.x - AylaTypingTitle.markSpacing - AylaTypingTitle.markWidth, y: start.y), opacity: front, in: &context)
        guard let cursor else { return }
        drawMark(at: end ?? start, opacity: cursor, in: &context)
    }

    /// Where the first letter of the first line starts: a centred line starts further in than the title.
    private func firstLetter(of layout: Text.Layout) -> CGPoint {
        guard let line = layout.first else { return .zero }
        let top = line.typographicBounds.rect.minY
        let x = line.first?.first?.typographicBounds.rect.minX ?? line.typographicBounds.rect.minX
        return CGPoint(x: x, y: top)
    }

    private func drawMark(at origin: CGPoint, opacity: (Int) -> Double, in context: inout GraphicsContext) {
        let size = AylaTypingTitle.markSize
        let squares = AylaTypingTitle.markCount
        for index in 0..<squares {
            let alpha = opacity(index)
            guard alpha > 0 else { continue }
            let square = CGRect(
                x: (origin.x + CGFloat(index) * size / 2).rounded(),
                y: (origin.y + CGFloat(squares - 1 - index) * size).rounded(),
                width: size,
                height: size
            )
            context.fill(Path(square), with: .color(Color.paveAccent.opacity(alpha)))
        }
    }
}

#Preview {
    @Previewable @State var isTyping = false
    VStack(spacing: 40) {
        AylaTypingTitle(text: "Wat wil je vandaag doen, Daaf", isTyping: isTyping)
        Button("Typ") { isTyping = true }
    }
    .padding()
}
