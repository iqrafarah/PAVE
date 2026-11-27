import SwiftUI

extension View {
    /// Right after "Laat Ayla invullen": the fields she filled come in one after the other, so you see what she did and
    /// where to check. `order` is the field's place among those; inactive, the field is simply there.
    func vaultFillReveal(order: Int, isActive: Bool) -> some View {
        modifier(VaultFillReveal(order: order, isActive: isActive))
    }
}

private struct VaultFillReveal: ViewModifier {
    let order: Int
    let isActive: Bool
    @Environment(\.paveReduceMotion) private var reduceMotion
    @State private var shown = false

    /// Waits for the page to slide in, then 40 ms per field.
    private var delay: Duration { .milliseconds(380 + 40 * order) }

    func body(content: Content) -> some View {
        let hidden = isActive && !shown && !reduceMotion
        content
            .opacity(hidden ? 0 : 1)
            .offset(y: hidden ? 6 : 0)
            .task(id: isActive) {
                guard isActive, !shown, !reduceMotion else { return }
                try? await Task.sleep(for: delay)
                withAnimation(.snappy(duration: 0.25)) { shown = true }
            }
    }
}
