import Foundation

/// Turning the head to one side and holding it there a moment, to go through cards one by one, such as vacancies
/// Ayla found. A quick look away and back, or a head shake, is no turn; after a turn the head first comes back to
/// the middle before the next one counts. The middle follows slowly, so sitting a little sideways is no turn either.
public struct AylaHeadTurnDetector: Sendable {
    public enum Turn: Equatable, Sendable {
        case left
        case right
    }

    /// About 20 degrees to the side, held for a sixth of a second.
    static let angle = 0.35
    static let hold: TimeInterval = 0.16
    /// Back within this of the middle before the next turn.
    static let middle = 0.15
    /// How fast the middle follows a head that stays turned a little, per second.
    static let follow = 0.5
    /// Coming back from a turn, the head often swings on past the middle to the other side: that rebound is no turn.
    /// The other side counts again only after the head was this long in the middle.
    static let rebound: TimeInterval = 0.7

    private var center: Double?
    private var lastYaw: Double?
    private var lastTime: TimeInterval?
    private var sideSince: TimeInterval?
    private var side: Turn?
    private var waitsForMiddle = false
    private var lastTurn: Turn?
    /// When the head came back to the middle after the last turn.
    private var backInMiddleSince: TimeInterval?

    public init() {}

    /// A new yaw of the head (radians; positive is turned to the left), time in seconds.
    public mutating func add(time: TimeInterval, yaw: Double) -> Turn? {
        var yaw = yaw
        if let lastYaw {
            while yaw - lastYaw > .pi { yaw -= 2 * .pi }
            while yaw - lastYaw < -.pi { yaw += 2 * .pi }
        }
        defer {
            lastYaw = yaw
            lastTime = time
        }
        guard var center else {
            self.center = yaw
            return nil
        }
        let offset = yaw - center
        if abs(offset) < Self.middle {
            if waitsForMiddle || backInMiddleSince == nil { backInMiddleSince = time }
            waitsForMiddle = false
            if let lastTime { center += offset * min(1, Self.follow * (time - lastTime)) }
            self.center = center
            side = nil
            sideSince = nil
            return nil
        }
        guard !waitsForMiddle, abs(offset) >= Self.angle else {
            side = nil
            sideSince = nil
            return nil
        }
        let now: Turn = offset > 0 ? .left : .right
        // The swing back past the middle right after a turn.
        if let lastTurn, now != lastTurn, let backInMiddleSince, time - backInMiddleSince < Self.rebound {
            side = nil
            sideSince = nil
            return nil
        }
        if side != now {
            side = now
            sideSince = time
            return nil
        }
        guard let sideSince, time - sideSince >= Self.hold else { return nil }
        waitsForMiddle = true
        side = nil
        self.sideSince = nil
        lastTurn = now
        backInMiddleSince = nil
        return now
    }

    public mutating func reset() {
        self = AylaHeadTurnDetector()
    }
}
