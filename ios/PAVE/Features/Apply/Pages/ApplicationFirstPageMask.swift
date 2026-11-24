import SwiftUI

/// The first page of the long sheet: all of it, minus what a full column pushed on to the next page.
nonisolated struct ApplicationFirstPageMask: Shape {
    let size: CGSize
    let moved: [CGRect]

    func path(in rect: CGRect) -> Path {
        var path = Path(CGRect(origin: .zero, size: size))
        for rect in moved { path.addRect(rect) }
        return path
    }
}
