import CoreGraphics

/// Two panes on either side of a fold, or of a landscape split, so that nothing is placed in the fold.
public struct FoldSplit: Equatable, Sendable {
    public enum Axis: Equatable, Sendable {
        /// First pane on the leading side, second on the trailing side.
        case sideBySide
        /// First pane on top, second below.
        case stacked
    }

    public struct Region: Equatable, Sendable {
        public var frame: CGRect
        public var top: CGFloat
        public var leading: CGFloat
        public var bottom: CGFloat
        public var trailing: CGFloat

        public init(frame: CGRect, top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
            self.frame = frame
            self.top = top
            self.leading = leading
            self.bottom = bottom
            self.trailing = trailing
        }
    }

    public static let minimumPaneLength: CGFloat = 240
    public static let minimumCrossLength: CGFloat = 200

    public let axis: Axis
    public let first: CGRect
    public let second: CGRect

    public init(axis: Axis, first: CGRect, second: CGRect) {
        self.axis = axis
        self.first = first
        self.second = second
    }

    /// Splits `size` around the first active region that cuts across the whole width or height.
    /// Returns nil when there is no usable fold, so the caller can use its normal layout.
    public static func around(_ regions: [Region], in size: CGSize) -> FoldSplit? {
        let tolerance: CGFloat = 1
        for region in regions {
            let frame = region.frame
            guard frame.width > 0, frame.height > 0 else { continue }
            let spansHeight = frame.minY <= tolerance && frame.maxY >= size.height - tolerance
            let spansWidth = frame.minX <= tolerance && frame.maxX >= size.width - tolerance

            if spansHeight && !spansWidth {
                let firstWidth = frame.minX - region.leading
                let secondX = frame.maxX + region.trailing
                let secondWidth = size.width - secondX
                guard firstWidth >= minimumPaneLength, secondWidth >= minimumPaneLength, size.height >= minimumCrossLength else { continue }
                return FoldSplit(
                    axis: .sideBySide,
                    first: CGRect(x: 0, y: 0, width: firstWidth, height: size.height),
                    second: CGRect(x: secondX, y: 0, width: secondWidth, height: size.height)
                )
            }

            if spansWidth && !spansHeight {
                let firstHeight = frame.minY - region.top
                let secondY = frame.maxY + region.bottom
                let secondHeight = size.height - secondY
                guard firstHeight >= minimumCrossLength, secondHeight >= minimumCrossLength, size.width >= minimumPaneLength else { continue }
                return FoldSplit(
                    axis: .stacked,
                    first: CGRect(x: 0, y: 0, width: size.width, height: firstHeight),
                    second: CGRect(x: 0, y: secondY, width: size.width, height: secondHeight)
                )
            }
        }
        return nil
    }

    /// A normal side-by-side split for wide landscape screens without a fold.
    public static func landscape(in size: CGSize, inset: CGFloat = 24, spacing: CGFloat = 48) -> FoldSplit {
        let firstWidth = min(380, (size.width - inset * 2 - spacing) * 0.42)
        let secondX = inset + firstWidth + spacing
        return FoldSplit(
            axis: .sideBySide,
            first: CGRect(x: inset, y: 0, width: firstWidth, height: size.height),
            second: CGRect(x: secondX, y: 0, width: max(0, size.width - secondX - inset), height: size.height)
        )
    }
}
