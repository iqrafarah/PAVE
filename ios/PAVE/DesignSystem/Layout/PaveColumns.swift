import SwiftUI

/// Two columns side by side where both get at least `minColumnWidth` (open Duo, iPad), else one under the other
/// (iPhone, closed Duo). The first column is the main one; the second column holds what you look at next.
/// Like a CSS grid with `grid-template-columns: repeat(auto-fit, minmax(min, 1fr))`, capped at two. An empty column
/// takes no place, so the other one gets the whole width.
struct PaveColumns: Layout {
    var minColumnWidth: CGFloat = 320
    var spacing: CGFloat = 20

    private func isSideBySide(_ width: CGFloat?, count: Int) -> Bool {
        guard count == 2, let width else { return false }
        return width >= minColumnWidth * 2 + spacing
    }

    private func columnWidth(_ width: CGFloat) -> CGFloat { (width - spacing) / 2 }

    private func shown(_ subviews: Subviews) -> [LayoutSubview] {
        subviews.filter { $0.sizeThatFits(.unspecified).height > 0 }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews all: Subviews, cache: inout ()) -> CGSize {
        let subviews = shown(all)
        let width = proposal.width
        if isSideBySide(width, count: subviews.count), let width {
            let column = ProposedViewSize(width: columnWidth(width), height: nil)
            let height = subviews.map { $0.sizeThatFits(column).height }.max() ?? 0
            return CGSize(width: width, height: height)
        }
        let row = ProposedViewSize(width: width, height: nil)
        let sizes = subviews.map { $0.sizeThatFits(row) }
        let height = sizes.map(\.height).reduce(0, +) + spacing * CGFloat(max(sizes.count - 1, 0))
        return CGSize(width: width ?? sizes.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews all: Subviews, cache: inout ()) {
        let subviews = shown(all)
        for hidden in all where !subviews.contains(hidden) {
            hidden.place(at: bounds.origin, proposal: .zero)
        }
        if isSideBySide(bounds.width, count: subviews.count) {
            let width = columnWidth(bounds.width)
            for (index, subview) in subviews.enumerated() {
                let x = bounds.minX + CGFloat(index) * (width + spacing)
                subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: nil))
            }
            return
        }
        var y = bounds.minY
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: nil))
            y += size.height + spacing
        }
    }
}

#Preview {
    ScrollView {
        PaveColumns {
            VStack(alignment: .leading, spacing: 12) {
                Text("Eerste kolom").textStyle(.calloutTitle)
                RoundedRectangle(cornerRadius: 16).fill(Color.panel).frame(height: 240)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Tweede kolom").textStyle(.calloutTitle)
                RoundedRectangle(cornerRadius: 16).fill(Color.panel).frame(height: 160)
            }
        }
        .padding(20)
    }
    .background(Color.canvas)
}
