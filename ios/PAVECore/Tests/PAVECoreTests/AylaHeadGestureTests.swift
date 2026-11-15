import Foundation
import Testing
@testable import PAVECore

struct AylaHeadGestureTests {
    /// Samples at 25 per second, as AirPods send them.
    private func feed(_ detector: inout AylaHeadGestureDetector, seconds: Double, from start: Double = 0, pitch: (Double) -> Double, yaw: (Double) -> Double = { _ in 0 }) -> [AylaHeadGesture] {
        var found: [AylaHeadGesture] = []
        var time = 0.0
        while time <= seconds {
            if let gesture = detector.add(time: start + time, pitch: pitch(time), yaw: yaw(time)) { found.append(gesture) }
            time += 0.04
        }
        return found
    }

    @Test func aNodIsDownAndBack() {
        var detector = AylaHeadGestureDetector()
        let found = feed(&detector, seconds: 0.8, pitch: { -0.3 * sin(.pi * $0 / 0.6) * ($0 < 0.6 ? 1 : 0) })
        #expect(found == [.nod])
    }

    @Test func aShakeIsLeftRightAndBack() {
        var detector = AylaHeadGestureDetector()
        let found = feed(&detector, seconds: 1.0, pitch: { _ in 0.01 }, yaw: { 0.4 * sin(2 * .pi * $0 / 0.8) * ($0 < 0.8 ? 1 : 0) })
        #expect(found == [.shake])
    }

    @Test func lookingDownAtThePhoneAndStayingIsNoNod() {
        var detector = AylaHeadGestureDetector()
        let found = feed(&detector, seconds: 2, pitch: { -0.5 * min(1, $0 / 0.4) })
        #expect(found.isEmpty)
    }

    @Test func aSmallMovementIsNothing() {
        var detector = AylaHeadGestureDetector()
        let found = feed(&detector, seconds: 1, pitch: { -0.08 * sin(.pi * $0 / 0.5) }, yaw: { 0.1 * sin(.pi * $0 / 0.5) })
        #expect(found.isEmpty)
    }

    @Test func oneNodWithABounceCountsOnce() {
        var detector = AylaHeadGestureDetector()
        let found = feed(&detector, seconds: 1.2, pitch: { -0.3 * sin(.pi * $0 / 0.4) * ($0 < 0.8 ? 1 : 0) })
        #expect(found == [.nod])
    }

    @Test func yesNoQuestionsAndAnswers() {
        #expect(AylaVaultOffer.endsWithYesNoQuestion("Zo zet ik het erin. Zal ik deze stage in je kluis zetten?"))
        #expect(AylaVaultOffer.endsWithYesNoQuestion("Klopt dat?"))
        #expect(!AylaVaultOffer.endsWithYesNoQuestion("Wat wil je toevoegen aan je kluis?"))
        #expect(!AylaVaultOffer.endsWithYesNoQuestion("Wil je een diploma of een stage toevoegen?"))
        #expect(!AylaVaultOffer.endsWithYesNoQuestion("Dat staat erin."))
        #expect(AylaVaultOffer.isNo("Nee"))
        #expect(AylaVaultOffer.isNo("liever niet"))
        #expect(!AylaVaultOffer.isNo("Ja"))
    }
}
