import CoreGraphics
import Testing
@testable import PAVECore

struct FoldSplitTests {
    private let size = CGSize(width: 800, height: 600)

    @Test func noRegionsMeansNoSplit() {
        #expect(FoldSplit.around([], in: size) == nil)
    }

    @Test func verticalFoldSplitsLeftAndRight() {
        let fold = FoldSplit.Region(frame: CGRect(x: 380, y: 0, width: 40, height: 600), leading: 10, trailing: 10)
        let split = FoldSplit.around([fold], in: size)

        #expect(split?.axis == .sideBySide)
        #expect(split?.first == CGRect(x: 0, y: 0, width: 370, height: 600))
        #expect(split?.second == CGRect(x: 430, y: 0, width: 370, height: 600))
    }

    @Test func horizontalFoldSplitsTopAndBottom() {
        let fold = FoldSplit.Region(frame: CGRect(x: 0, y: 280, width: 800, height: 40), top: 8, bottom: 8)
        let split = FoldSplit.around([fold], in: size)

        #expect(split?.axis == .stacked)
        #expect(split?.first == CGRect(x: 0, y: 0, width: 800, height: 272))
        #expect(split?.second == CGRect(x: 0, y: 328, width: 800, height: 272))
    }

    @Test func nothingIsPlacedInsideTheFold() throws {
        let fold = FoldSplit.Region(frame: CGRect(x: 380, y: 0, width: 40, height: 600), leading: 10, trailing: 10)
        let split = try #require(FoldSplit.around([fold], in: size))
        #expect(!split.first.intersects(fold.frame))
        #expect(!split.second.intersects(fold.frame))
    }

    @Test func panesStayInsideTheScreen() throws {
        let fold = FoldSplit.Region(frame: CGRect(x: 380, y: 0, width: 40, height: 600))
        let split = try #require(FoldSplit.around([fold], in: size))
        let screen = CGRect(origin: .zero, size: size)
        #expect(screen.contains(split.first))
        #expect(screen.contains(split.second))
    }

    @Test func regionThatDoesNotCutAcrossTheScreenIsIgnored() {
        let camera = FoldSplit.Region(frame: CGRect(x: 300, y: 0, width: 100, height: 60))
        #expect(FoldSplit.around([camera], in: size) == nil)
    }

    @Test func panesThatWouldBeTooNarrowAreRejected() {
        let offCenter = FoldSplit.Region(frame: CGRect(x: 100, y: 0, width: 40, height: 600))
        #expect(FoldSplit.around([offCenter], in: size) == nil)
    }

    @Test func emptyRegionsAreIgnored() {
        let flat = FoldSplit.Region(frame: CGRect(x: 400, y: 0, width: 0, height: 600))
        #expect(FoldSplit.around([flat], in: size) == nil)
    }

    @Test func usesTheFirstUsableRegion() {
        let ignored = FoldSplit.Region(frame: CGRect(x: 300, y: 0, width: 100, height: 60))
        let fold = FoldSplit.Region(frame: CGRect(x: 380, y: 0, width: 40, height: 600))
        #expect(FoldSplit.around([ignored, fold], in: size)?.axis == .sideBySide)
    }

    @Test func landscapeSplitKeepsAGapBetweenThePanes() {
        let split = FoldSplit.landscape(in: CGSize(width: 951, height: 640))
        #expect(split.axis == .sideBySide)
        #expect(abs(split.second.minX - split.first.maxX - 48) < 0.001)
        #expect(split.first.minX == 24)
        #expect(abs(split.second.maxX - (951 - 24)) < 0.001)
        #expect(split.first.width <= 380)
    }
}
