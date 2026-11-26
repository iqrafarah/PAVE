import CoreGraphics
import Testing
@testable import PAVECore

@Suite("Pages of a CV or a letter")
struct PageFlowTests {
    private let page = CGSize(width: 595, height: 842)

    private func blocks(_ heights: [CGFloat], x: CGFloat = 40, width: CGFloat = 300, from start: CGFloat = 100, gap: CGFloat = 10, titles: Set<Int> = []) -> [PageFlow.Block] {
        var y = start
        return heights.enumerated().map { index, height in
            defer { y += height + gap }
            return PageFlow.Block(frame: CGRect(x: x, y: y, width: width, height: height), keepsWithNext: titles.contains(index))
        }
    }

    private func layout(_ regions: [CGRect], _ blocks: [PageFlow.Block], panels: [PageFlow.Panel] = []) -> PageFlow.Layout {
        PageFlow.layout(regions: regions, blocks: blocks, panels: panels, page: page, topMargin: 44, bottomMargin: 44)
    }

    @Test("What fits stays on one page")
    func onePage() {
        let all = blocks([100, 100, 100])
        let result = layout([CGRect(x: 0, y: 0, width: 595, height: 500)], all)
        #expect(result.pages == 1)
        #expect(result.slices == [PageFlow.Slice(region: 0, page: 0, x: 0, width: 595, from: 0, to: 500, top: 0)])
    }

    @Test("A block that does not fit moves to the next page whole")
    func cutsBetweenBlocks() {
        let all = blocks([300, 300, 300])
        let result = layout([CGRect(x: 0, y: 0, width: 595, height: 1100)], all)
        #expect(result.pages == 2)
        // The third block ends at 1020, past 842 - 44: the cut is half-way the gap before it.
        #expect(result.slices[0].to == 715)
        #expect(result.slices[1].from == 715)
        #expect(result.slices[1].top == 44)
        for block in all {
            let place = result.place(of: block.frame)
            #expect(place?.frame.height == block.frame.height)
        }
        #expect(result.place(of: all[2].frame)?.page == 1)
    }

    @Test("A title goes along with the block under it")
    func titleKeepsWithNext() {
        let all = blocks([300, 300, 20, 300], titles: [2])
        let result = layout([CGRect(x: 0, y: 0, width: 595, height: 1200)], all)
        #expect(result.place(of: all[2].frame)?.page == 1)
        #expect(result.place(of: all[3].frame)?.page == 1)
        #expect(result.slices[0].to == 715)
    }

    @Test("Two columns flow apart, the header stays on the first page")
    func columnsFlowOnTheirOwn() {
        let left = CGRect(x: 0, y: 200, width: 350, height: 1000)
        let right = CGRect(x: 350, y: 200, width: 245, height: 300)
        let all = blocks([250, 250, 250, 150], from: 210) + blocks([100, 100], x: 380, width: 180, from: 210)
        let result = layout([left, right], all)
        #expect(result.pages == 2)
        #expect(result.slices.filter { $0.region == 1 }.count == 1)
        #expect(result.slices.filter { $0.region == 0 }.count == 2)
        let header = CGRect(x: 40, y: 40, width: 500, height: 100)
        #expect(result.place(of: header)?.page == 0)
        #expect(result.place(of: header)?.frame == header)
    }

    @Test("Space under the last block makes no empty page")
    func trailingSpaceIsNoPage() {
        let all = blocks([300, 300], from: 100)
        let result = layout([CGRect(x: 0, y: 0, width: 595, height: 900)], all)
        #expect(result.pages == 1)
        #expect(result.slices[0].to == 842)
    }

    @Test("A tile cut in two keeps its padding on both pages")
    func panelIsDrawnPerPage() {
        let all = blocks([300, 300, 300], from: 116)
        let tile = PageFlow.Panel(frame: CGRect(x: 24, y: 100, width: 332, height: 952), padding: 16)
        let result = layout([CGRect(x: 0, y: 0, width: 595, height: 1100)], all, panels: [tile])
        #expect(result.pages == 2)
        let first = result.pieces.first { $0.page == 0 }
        let second = result.pieces.first { $0.page == 1 }
        let cut = result.slices[0].to
        #expect(first?.frame.minY == 100)
        #expect(first?.frame.maxY == cut + 16)
        #expect((first?.frame.maxY ?? .infinity) <= 842 - 44)
        // On the next page the tile starts at the margin and its text a padding lower.
        #expect(second?.frame.minY == 44)
        #expect(result.slices[1].top == 60)
    }

    @Test("A block taller than a page is cut where the page ends")
    func tallBlock() {
        let all = blocks([1500], from: 50)
        let result = layout([CGRect(x: 0, y: 0, width: 595, height: 1600)], all)
        #expect(result.pages == 2)
        #expect(result.slices[0].to == 798)
    }
}
