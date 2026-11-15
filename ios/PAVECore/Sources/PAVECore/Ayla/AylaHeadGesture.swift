import Foundation

/// A nod or a head shake, read from the motion of AirPods: Ja and Nee without a word or a tap.
public enum AylaHeadGesture: Equatable, Sendable {
    case nod
    case shake
}

/// Recognises a nod or a shake in the head's attitude over the last second. A nod moves the head down (or up) and
/// back, a shake left (or right) and back, clearly more around that axis than around the other one. Looking down
/// at the phone and staying there is no nod, and after a gesture the next one waits a moment, so one nod with a
/// bounce counts once.
public struct AylaHeadGestureDetector: Sendable {
    /// How long one gesture may take, in seconds.
    static let window: TimeInterval = 1.1
    /// The smallest turn that counts, in radians: about 10 degrees for a nod and 15 for a shake.
    static let nodAmplitude = 0.17
    static let shakeAmplitude = 0.26
    /// How far the head must come back from the turn, as part of it.
    static let comeBack = 0.6
    /// The other axis may move at most this part of the turn.
    static let otherAxis = 0.6
    static let pause: TimeInterval = 1.0

    private struct Sample {
        let time: TimeInterval
        let pitch: Double
        let yaw: Double
    }

    private var samples: [Sample] = []
    private var lastGestureAt: TimeInterval?

    public init() {}

    /// A new attitude of the head (radians, time in seconds). Returns the gesture it completes, if any.
    public mutating func add(time: TimeInterval, pitch: Double, yaw: Double) -> AylaHeadGesture? {
        // Yaw jumps from pi to -pi; it is kept continuous with the previous sample.
        var yaw = yaw
        if let previous = samples.last {
            while yaw - previous.yaw > .pi { yaw -= 2 * .pi }
            while yaw - previous.yaw < -.pi { yaw += 2 * .pi }
        }
        samples.append(Sample(time: time, pitch: pitch, yaw: yaw))
        samples.removeAll { time - $0.time > Self.window }
        if let lastGestureAt, time - lastGestureAt < Self.pause { return nil }
        guard samples.count >= 4 else { return nil }

        let pitches = samples.map(\.pitch)
        let yaws = samples.map(\.yaw)
        let gesture: AylaHeadGesture? = if Self.isTurnAndBack(pitches, other: yaws, amplitude: Self.nodAmplitude) {
            .nod
        } else if Self.isTurnAndBack(yaws, other: pitches, amplitude: Self.shakeAmplitude) {
            .shake
        } else {
            nil
        }
        if gesture != nil {
            lastGestureAt = time
            samples.removeAll()
        }
        return gesture
    }

    public mutating func reset() {
        samples.removeAll()
        lastGestureAt = nil
    }

    private static func isTurnAndBack(_ values: [Double], other: [Double], amplitude: Double) -> Bool {
        guard let start = values.first, let last = values.last else { return false }
        guard let peak = values.indices.max(by: { abs(values[$0] - start) < abs(values[$1] - start) }) else { return false }
        let turn = abs(values[peak] - start)
        guard turn >= amplitude, peak < values.count - 1, abs(last - values[peak]) >= turn * comeBack else { return false }
        let otherStart = other.first ?? 0
        let otherTurn = other.map { abs($0 - otherStart) }.max() ?? 0
        return otherTurn <= turn * otherAxis
    }
}
