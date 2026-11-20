import SwiftUI

extension View {
    /// "Animaties uitzetten" in Instellingen › Weergave: with it on, every change shows at once, also where a view asks
    /// for an animation, and what moves on its own (the orb, loaders, waves) stands still, as on the web.
    func paveAnimationsSwitch() -> some View {
        modifier(PaveAnimationsSwitch())
    }
}

private struct PaveAnimationsSwitch: ViewModifier {
    @AppStorage(PaveAppearance.animationsOffKey) private var isOff = false

    func body(content: Content) -> some View {
        content
            .environment(\.paveAnimationsOff, isOff)
            .transaction { transaction in
                guard isOff else { return }
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }
}
