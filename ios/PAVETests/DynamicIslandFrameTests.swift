import CoreGraphics
import Testing
@testable import PAVE

@MainActor
struct DynamicIslandFrameTests {
    @Test func theClosedDuoHasItsIslandAtTheCameraInTheColumn() throws {
        // Measured on Daaf's closed iPhone Duo: 382 pt beside an 84 pt status column, no status bar on top.
        let frame = try #require(DynamicIslandFrame.sideFrame(topInset: 0, trailingInset: 84, width: 382))
        #expect(abs(frame.midX - 418) < 1)
        #expect(abs(frame.midY - 57) < 1)
        #expect(frame.size == CGSize(width: 37, height: 63))
        #expect(DynamicIslandFrame.frame(topInset: 0, width: 382) == nil)
    }

    @Test func anIPhoneKeepsItsIslandOnTopAndTheOpenDuoKeepsThePill() {
        #expect(DynamicIslandFrame.frame(topInset: 62, width: 402) != nil)
        #expect(DynamicIslandFrame.sideFrame(topInset: 62, trailingInset: 0, width: 402) == nil)
        // The open Duo: a status bar on top like an iPad, no column, and too wide for an island.
        #expect(DynamicIslandFrame.sideFrame(topInset: 24, trailingInset: 0, width: 669) == nil)
        #expect(DynamicIslandFrame.frame(topInset: 24, width: 669) == nil)
    }
}
