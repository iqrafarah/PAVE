import SwiftUI

/// The soft corner tint of cards in Figma: white from the middle, the tint towards the top left.
/// Figma draws it as a CSS gradient at an angle that reaches past the corner, so the tint is never full strength.
struct FigmaCardGradient: View {
    let tint: Color
    var start = UnitPoint(x: 0.97, y: 1.08)
    var end = UnitPoint(x: 0.03, y: -0.08)

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0.5076),
                .init(color: tint.mix(with: .white, by: 0.12), location: 1),
            ],
            startPoint: start,
            endPoint: end
        )
    }
}
