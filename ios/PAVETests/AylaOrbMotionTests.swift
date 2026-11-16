import SwiftUI
import Testing
@testable import PAVE

@MainActor
struct AylaOrbMotionTests {
    private func run(_ motion: AylaOrbMotion, seconds: Double, each: () -> Void = {}) {
        for _ in 0..<Int(seconds * 120) {
            motion.advance(by: 1.0 / 120)
            each()
        }
    }

    @Test func draggingGivesLikeElasticAndStretches() {
        let motion = AylaOrbMotion()
        motion.grab()
        motion.drag(by: 40)
        let little = motion.pull
        motion.drag(by: 400)
        #expect(little > 0 && little < 40)
        #expect(motion.pull > little && motion.pull < AylaOrbMotion.give)
        #expect(motion.stretch > 0.8)
        #expect(motion.position == 0)
        #expect(motion.size == 0)
    }

    @Test func pulledAndUnpulledAreEachOthersInverse() {
        for distance in [-300, -20, 0, 15, 80, 500] as [CGFloat] {
            let back = AylaOrbMotion.unpulled(AylaOrbMotion.pulled(distance))
            #expect(abs(back - distance) < 0.01)
        }
    }

    @Test func lettingGoEarlySpringsBackRound() {
        let motion = AylaOrbMotion()
        motion.grab()
        motion.drag(by: 50)
        motion.letGo(velocity: 0, reduceMotion: false)
        run(motion, seconds: 2)
        #expect(motion.pull == 0)
        #expect(motion.stretch == 0)
        #expect(!motion.isLow)
    }

    @Test func switchingPlaceDoesNotMoveTheOrbOnTheFirstFrame() {
        let motion = AylaOrbMotion()
        let stage = CGRect(x: 80, y: 200, width: 240, height: 240)
        let bar = CGRect(x: 130, y: 600, width: 140, height: 140)
        motion.grab()
        motion.drag(by: 150)
        let before = AylaOrbTrack<EmptyView>.frame(of: motion, stage: stage, bar: bar)
        motion.switchPlace(velocity: 0, travel: bar.midY - stage.midY, reduceMotion: false)
        let after = AylaOrbTrack<EmptyView>.frame(of: motion, stage: stage, bar: bar)
        #expect(abs(before.midY - after.midY) < 0.01)
    }

    @Test func switchingPlaceLandsOnceAndShowsTheConversationAfterwards() {
        let motion = AylaOrbMotion()
        motion.grab()
        motion.drag(by: 150)
        var landings = 0
        motion.switchPlace(velocity: 800, travel: 400, reduceMotion: false) { landings += 1 }
        #expect(motion.isLow)
        #expect(!motion.hasArrived)
        run(motion, seconds: 2)
        #expect(motion.hasArrived)
        #expect(landings == 1)
        #expect(motion.position == 1)
        #expect(motion.size == 1)
        #expect(motion.pull == 0)
    }

    @Test func theSizePopsPastTheNewSizeAndBack() {
        let motion = AylaOrbMotion()
        motion.grab()
        motion.drag(by: 150)
        motion.switchPlace(velocity: 0, travel: 400, reduceMotion: false)
        var smallest: CGFloat = 0
        run(motion, seconds: 1.5) { smallest = max(smallest, motion.size) }
        #expect(smallest > 1.1)
        #expect(motion.size == 1)
    }

    @Test func goingBackUpWorksTheSameWay() {
        let motion = AylaOrbMotion()
        motion.jump(to: 1)
        motion.grab()
        motion.drag(by: -150)
        #expect(motion.pull < 0)
        motion.switchPlace(velocity: -800, travel: 400, reduceMotion: false)
        #expect(!motion.isLow)
        run(motion, seconds: 2)
        #expect(motion.position == 0)
        #expect(motion.size == 0)
    }

    @Test func glidingNeedsNoFinger() {
        let motion = AylaOrbMotion()
        var landed = false
        motion.glide(to: 1, reduceMotion: false) { landed = true }
        run(motion, seconds: 2)
        #expect(landed)
        #expect(motion.position == 1)
    }

    @Test func jumpPutsTheOrbInPlaceAtOnce() {
        let motion = AylaOrbMotion()
        motion.jump(to: 1)
        #expect(motion.position == 1)
        #expect(motion.size == 1)
        #expect(motion.isLow)
        #expect(motion.hasArrived)
        #expect(!motion.isDragging)
    }
}
