import Observation
import QuartzCore

/// How Ayla's orb moves between its two places while talking, measured from ChatGPT's voice mode:
/// - dragging does not carry the orb along: it gives a little, like elastic, and stretches towards the finger;
/// - letting go far enough (or with a flick) makes it jump to its other place in one quick go, its size popping
///   past the new size and back while it flies there;
/// - otherwise it springs back.
/// The springs run here, frame by frame, so they carry on from wherever the orb really is.
@Observable
final class AylaOrbMotion {
    /// A spring as Apple describes it: how quickly it gets there (seconds) and how much it overshoots (1 is none).
    struct Spring: Equatable {
        let response: Double
        let damping: Double

        /// The jump to the other place.
        static let place = Spring(response: 0.32, damping: 0.8)
        /// The size during the jump: quick, past the new size and back.
        static let size = Spring(response: 0.28, damping: 0.45)
        /// Let go too early: the elastic pulls the orb back.
        static let back = Spring(response: 0.3, damping: 0.6)
        /// Round again after being stretched, with a little wobble.
        static let round = Spring(response: 0.2, damping: 0.55)
        /// Moved without a finger (the accessibility action, the first message on iPad).
        static let glide = Spring(response: 0.45, damping: 1)
        static let reduced = Spring(response: 0.2, damping: 1)
    }

    /// How far the orb gives at most, in points, however far the finger goes.
    static let give: CGFloat = 70
    /// How far the finger has to go to send the orb to its other place.
    static let switchDistance: CGFloat = 80
    /// How far a flick has to be heading, in points.
    static let flickDistance: CGFloat = 140

    /// Between the middle (0) and the voice bar (1).
    private(set) var position: CGFloat = 0
    /// Between large (0) and small (1); goes a little past them while it pops.
    private(set) var size: CGFloat = 0
    /// How far the elastic is pulled, in points (down is positive).
    private(set) var pull: CGFloat = 0
    /// How much the orb is stretched towards the finger: 0 is round.
    private(set) var stretch: CGFloat = 0
    /// Where the orb belongs: 0 in the middle, 1 above the voice bar.
    private(set) var place: CGFloat = 0
    /// The orb has reached its place; the conversation only shows once it has.
    private(set) var hasArrived = true
    private(set) var isDragging = false

    var isLow: Bool { place > 0.5 }

    @ObservationIgnored private var positionSpring = Motion(spring: .place, tolerance: 0.0005)
    @ObservationIgnored private var sizeSpring = Motion(spring: .size, tolerance: 0.0005)
    @ObservationIgnored private var pullSpring = Motion(spring: .back, tolerance: 0.1)
    @ObservationIgnored private var stretchSpring = Motion(spring: .round, tolerance: 0.001)
    @ObservationIgnored private var dragStart: CGFloat = 0
    @ObservationIgnored private var onArrive: (() -> Void)?
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var lastFrame: CFTimeInterval?

    func jump(to place: CGFloat) {
        stopFrames()
        isDragging = false
        onArrive = nil
        positionSpring.rest(at: place)
        sizeSpring.rest(at: place)
        pullSpring.rest(at: 0)
        stretchSpring.rest(at: 0)
        self.place = place
        hasArrived = true
        publish()
    }

    /// Takes hold of the orb, also while the elastic is still pulling it back.
    func grab() {
        isDragging = true
        dragStart = Self.unpulled(pullSpring.x)
    }

    /// The finger moved `distance` points from where it took hold; returns where the finger is, without the elastic.
    @discardableResult
    func drag(by distance: CGFloat) -> CGFloat {
        let finger = dragStart + distance
        pullSpring.rest(at: Self.pulled(finger))
        stretchSpring.rest(at: abs(pullSpring.x) / Self.give)
        publish()
        return finger
    }

    /// Lets go far enough: the orb jumps to its other place, carrying on at the finger's `velocity` (points per
    /// second) over `travel` points. `onArrive` runs the moment it gets there, so a haptic lands with it.
    func switchPlace(velocity: CGFloat, travel: CGFloat, reduceMotion: Bool, onArrive: (() -> Void)? = nil) {
        isDragging = false
        let target: CGFloat = isLow ? 0 : 1
        let travel = max(1, travel)
        // The elastic becomes part of the jump, so nothing moves on the first frame.
        positionSpring.x += pullSpring.x / travel
        positionSpring.v = max(-6, min(6, velocity / travel))
        pullSpring.rest(at: 0)
        positionSpring.aim(at: target, spring: reduceMotion ? .reduced : .place)
        sizeSpring.aim(at: target, spring: reduceMotion ? .reduced : .size)
        stretchSpring.aim(at: 0, spring: reduceMotion ? .reduced : .round)
        go(to: target, onArrive: onArrive)
    }

    /// Lets go too early: the elastic pulls the orb back.
    func letGo(velocity: CGFloat, reduceMotion: Bool) {
        isDragging = false
        pullSpring.v = velocity
        pullSpring.aim(at: 0, spring: reduceMotion ? .reduced : .back)
        stretchSpring.aim(at: 0, spring: reduceMotion ? .reduced : .round)
        startFrames()
    }

    /// Glides to `place` without a finger.
    func glide(to place: CGFloat, reduceMotion: Bool, onArrive: (() -> Void)? = nil) {
        positionSpring.aim(at: place, spring: reduceMotion ? .reduced : .glide)
        sizeSpring.aim(at: place, spring: reduceMotion ? .reduced : .glide)
        go(to: place, onArrive: onArrive)
    }

    /// One frame of the springs; the display calls this every frame.
    func advance(by duration: CFTimeInterval) {
        let duration = min(duration, 1.0 / 20)
        let wasBefore = positionSpring.x < positionSpring.target
        positionSpring.advance(by: duration)
        sizeSpring.advance(by: duration)
        if !isDragging {
            pullSpring.advance(by: duration)
            stretchSpring.advance(by: duration)
        }
        publish()
        if !hasArrived, positionSpring.isDone || wasBefore != (positionSpring.x < positionSpring.target) {
            hasArrived = true
            let action = onArrive
            onArrive = nil
            action?()
        }
        if positionSpring.isDone, sizeSpring.isDone, isDragging || (pullSpring.isDone && stretchSpring.isDone) {
            stopFrames()
        }
    }

    private func go(to place: CGFloat, onArrive: (() -> Void)?) {
        self.place = place
        self.onArrive = onArrive
        hasArrived = false
        if positionSpring.isDone, positionSpring.x == place {
            hasArrived = true
            self.onArrive = nil
            onArrive?()
        }
        startFrames()
    }

    private func publish() {
        position = positionSpring.x
        size = sizeSpring.x
        pull = pullSpring.x
        stretch = stretchSpring.x
    }

    private func startFrames() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(frame))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
        lastFrame = nil
    }

    private func stopFrames() {
        link?.invalidate()
        link = nil
        lastFrame = nil
    }

    @objc private func frame(_ link: CADisplayLink) {
        let now = link.targetTimestamp
        let duration = lastFrame.map { now - $0 } ?? (link.targetTimestamp - link.timestamp)
        lastFrame = now
        advance(by: duration)
    }

    /// Where the orb is for a finger `distance` points away: it gives less and less, up to `give`.
    static func pulled(_ distance: CGFloat) -> CGFloat {
        let amount = abs(distance)
        return (distance < 0 ? -1 : 1) * give * amount / (amount + give)
    }

    /// Where the finger would be for an orb pulled `offset` points, so catching it does not make it jump.
    static func unpulled(_ offset: CGFloat) -> CGFloat {
        let amount = min(abs(offset), give * 0.99)
        return (offset < 0 ? -1 : 1) * amount * give / (give - amount)
    }
}

/// One value that a spring moves.
private struct Motion {
    var x: CGFloat = 0
    var v: CGFloat = 0
    var target: CGFloat = 0
    var spring: AylaOrbMotion.Spring
    let tolerance: CGFloat

    init(spring: AylaOrbMotion.Spring, tolerance: CGFloat) {
        self.spring = spring
        self.tolerance = tolerance
    }

    var isDone: Bool { x == target && v == 0 }

    mutating func rest(at value: CGFloat) {
        x = value
        v = 0
        target = value
    }

    mutating func aim(at value: CGFloat, spring: AylaOrbMotion.Spring) {
        target = value
        self.spring = spring
    }

    mutating func advance(by duration: Double) {
        guard !isDone else { return }
        let stiffness = pow(2 * .pi / spring.response, 2)
        let friction = 4 * .pi * spring.damping / spring.response
        var x = Double(self.x)
        var v = Double(self.v)
        var left = duration
        while left > 0 {
            let dt = min(left, 1.0 / 240)
            v += (-stiffness * (x - Double(target)) - friction * v) * dt
            x += v * dt
            left -= dt
        }
        if abs(x - Double(target)) < Double(tolerance), abs(v) < Double(tolerance) * 20 {
            self.x = target
            self.v = 0
        } else {
            self.x = CGFloat(x)
            self.v = CGFloat(v)
        }
    }
}
