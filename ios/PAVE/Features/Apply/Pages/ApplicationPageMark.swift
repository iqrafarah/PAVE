import PAVECore
import SwiftUI

/// What a part of the long sheet is to the page cutter (`PageFlow`), with where it is.
nonisolated struct ApplicationPageMark {
    enum Kind {
        /// A column that flows on to the next page on its own.
        case region
        /// A piece that stays whole; a title keeps with what follows.
        case block(keepsWithNext: Bool)
        /// A surface behind blocks, drawn per page so a cut still has its corners and padding.
        case panel(fill: Color, cornerRadius: CGFloat, padding: CGFloat)
        /// A block that can be tapped to change it.
        case tap(ApplicationBlock)
    }

    let kind: Kind
    let bounds: Anchor<CGRect>
}

nonisolated struct ApplicationPageMarks: PreferenceKey {
    static var defaultValue: [ApplicationPageMark] { [] }

    static func reduce(value: inout [ApplicationPageMark], nextValue: () -> [ApplicationPageMark]) {
        value += nextValue()
    }
}

extension View {
    func pageMark(_ kind: ApplicationPageMark.Kind) -> some View {
        transformAnchorPreference(key: ApplicationPageMarks.self, value: .bounds) { marks, bounds in
            marks.append(ApplicationPageMark(kind: kind, bounds: bounds))
        }
    }

    /// A column of the page: it goes on to the next page by itself when it is full.
    func pageRegion() -> some View { pageMark(.region) }

    /// A tile or a tinted column behind this content. The pages draw it, so one that runs over two pages is whole on
    /// both.
    func pagePanel(_ fill: Color, cornerRadius: CGFloat, padding: CGFloat) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pageMark(.panel(fill: fill, cornerRadius: cornerRadius, padding: padding))
    }
}
