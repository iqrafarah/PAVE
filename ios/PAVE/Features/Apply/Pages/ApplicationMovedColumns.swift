import SwiftUI

/// The parts of the first page that a full column left for the next page.
nonisolated struct ApplicationMovedColumns: Shape {
    let rects: [CGRect]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for rect in rects { path.addRect(rect) }
        return path
    }
}
