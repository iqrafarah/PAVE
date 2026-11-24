import CoreGraphics
import Foundation

/// How a long CV or letter is cut into pages. The document is laid out once as one long sheet; its columns
/// ("regions") each flow on to the next page on their own, and a cut never goes through a block: an entry, a
/// paragraph or a title stays whole, and a title stays with what follows it. What is in no region (the header) stays
/// where it is, on the first page.
public enum PageFlow {
    /// A piece that stays whole. A title keeps with the block after it.
    public struct Block: Equatable, Sendable {
        public var frame: CGRect
        public var keepsWithNext: Bool

        public init(frame: CGRect, keepsWithNext: Bool = false) {
            self.frame = frame
            self.keepsWithNext = keepsWithNext
        }
    }

    /// A surface behind blocks (a tile, a tinted column) that is drawn per page, so a cut through it still gets its
    /// corners and its padding on both pages.
    public struct Panel: Equatable, Sendable {
        public var frame: CGRect
        public var padding: CGFloat

        public init(frame: CGRect, padding: CGFloat) {
            self.frame = frame
            self.padding = padding
        }
    }

    /// The part of a region that shows on one page: `from..<to` on the long sheet, drawn with its top at `top`.
    public struct Slice: Equatable, Sendable {
        public var region: Int
        public var page: Int
        public var x: CGFloat
        public var width: CGFloat
        public var from: CGFloat
        public var to: CGFloat
        public var top: CGFloat

        /// How far the long sheet moves so this part lands in its place on the page.
        public var shift: CGFloat { top - from }
        /// Where it shows on its page.
        public var window: CGRect { CGRect(x: x, y: top, width: width, height: to - from) }
    }

    /// The part of a panel on one page, in the page's coordinates.
    public struct Piece: Equatable, Sendable {
        public var panel: Int
        public var page: Int
        public var frame: CGRect
    }

    public struct Layout: Equatable, Sendable {
        public var pages: Int
        public var slices: [Slice]
        public var pieces: [Piece]

        public init(pages: Int = 1, slices: [Slice] = [], pieces: [Piece] = []) {
            self.pages = pages
            self.slices = slices
            self.pieces = pieces
        }

        /// Where a frame on the long sheet shows: its page and its place there. What is in no region is on page one.
        public func place(of frame: CGRect) -> (page: Int, frame: CGRect)? {
            let middle = CGPoint(x: frame.midX, y: frame.midY)
            for slice in slices where middle.x >= slice.x && middle.x <= slice.x + slice.width {
                if middle.y >= slice.from && middle.y < slice.to {
                    return (slice.page, frame.offsetBy(dx: 0, dy: slice.shift).intersection(slice.window))
                }
            }
            let inRegion = slices.contains { middle.x >= $0.x && middle.x <= $0.x + $0.width && middle.y >= $0.from }
            return inRegion ? nil : (0, frame)
        }
    }

    public static func layout(
        regions: [CGRect], blocks: [Block], panels: [Panel], page: CGSize, topMargin: CGFloat, bottomMargin: CGFloat
    ) -> Layout {
        var slices: [Slice] = []
        var pieces: [Piece] = []
        var placed = Set<Int>()
        for (index, region) in regions.enumerated() {
            let mine = blocks
                .filter { region.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
                .sorted { $0.frame.minY < $1.frame.minY }
            let myPanels = panels.enumerated().filter {
                region.insetBy(dx: -1, dy: -1).contains(CGPoint(x: $0.element.frame.midX, y: $0.element.frame.midY))
            }
            placed.formUnion(myPanels.map(\.offset))
            let reserve = myPanels.map(\.element.padding).max() ?? 0
            let contentEnd = max(mine.last?.frame.maxY ?? region.maxY, myPanels.map(\.element.frame.maxY).max() ?? 0)
            var from = region.minY
            var top = region.minY
            var regionSlices: [Slice] = []
            for pageIndex in 0..<maximumPages {
                let room = page.height - bottomMargin - top
                func slice(to: CGFloat) -> Slice {
                    Slice(region: index, page: pageIndex, x: region.minX, width: region.width, from: from, to: to, top: top)
                }
                if contentEnd <= from + room + 0.5 || pageIndex == maximumPages - 1 {
                    regionSlices.append(slice(to: min(region.maxY, from + page.height - top)))
                    break
                }
                let cut = cut(in: mine, from: from, limit: from + room - reserve, pageRoom: page.height - topMargin - bottomMargin - 2 * reserve)
                regionSlices.append(slice(to: cut))
                from = cut
                let continued = myPanels.first { $0.element.frame.minY < cut - 0.5 && $0.element.frame.maxY > cut + 0.5 }
                top = topMargin + (continued?.element.padding ?? 0)
            }
            for slice in regionSlices {
                for (panelIndex, panel) in myPanels where panel.frame.maxY > slice.from + 0.5 && panel.frame.minY < slice.to - 0.5 {
                    let minY = panel.frame.minY >= slice.from - 0.5 ? panel.frame.minY : slice.from - panel.padding
                    let maxY = panel.frame.maxY <= slice.to + 0.5 ? panel.frame.maxY : slice.to + panel.padding
                    pieces.append(Piece(
                        panel: panelIndex, page: slice.page,
                        frame: CGRect(x: panel.frame.minX, y: minY + slice.shift, width: panel.frame.width, height: maxY - minY)
                    ))
                }
            }
            slices += regionSlices
        }
        for (index, panel) in panels.enumerated() where !placed.contains(index) {
            pieces.append(Piece(panel: index, page: 0, frame: panel.frame))
        }
        return Layout(pages: (slices.map(\.page).max() ?? 0) + 1, slices: slices, pieces: pieces)
    }

    /// More than this is no CV; it also stops a layout that cannot be cut from going on for ever.
    static let maximumPages = 6

    /// Where this page of a region ends: between the last block that fits and the first that does not, and above a
    /// title that would be left alone at the bottom. A block taller than a page is cut where the page ends.
    static func cut(in blocks: [Block], from: CGFloat, limit: CGFloat, pageRoom: CGFloat) -> CGFloat {
        guard let first = blocks.firstIndex(where: { $0.frame.minY >= from - 0.5 }),
              let crossing = blocks[first...].firstIndex(where: { $0.frame.maxY > limit }),
              blocks[crossing].frame.height <= pageRoom
        else { return limit }
        var index = crossing
        while index > first, blocks[index - 1].keepsWithNext { index -= 1 }
        // A title and its block that do not fit together at the top of a page: the title stays, the block is cut.
        if index == first, crossing > first { index = crossing }
        let cut = index > first
            ? (blocks[index - 1].frame.maxY + blocks[index].frame.minY) / 2
            : blocks[index].frame.minY - 4
        return cut > from + 8 ? min(cut, limit) : limit
    }
}
