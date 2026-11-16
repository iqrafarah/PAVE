import SwiftUI

extension View {
    /// Shares a frame with the view with the same id in `namespace`: when one replaces the other inside an
    /// animation, it grows or shrinks from where the other was. Without a namespace nothing changes.
    @ViewBuilder
    func matchedFrame(_ id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedGeometryEffect(id: id, in: namespace)
        } else {
            self
        }
    }
}
