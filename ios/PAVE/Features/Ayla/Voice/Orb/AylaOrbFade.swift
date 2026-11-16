import SwiftUI

/// Fades a view with the orb's movement. Only this modifier reads the movement, so the view itself is not rebuilt
/// every frame while the orb moves.
struct AylaOrbFade: ViewModifier {
    let motion: AylaOrbMotion?
    let opacity: (AylaOrbMotion) -> Double

    func body(content: Content) -> some View {
        content.opacity(motion.map(opacity) ?? 1)
    }
}
