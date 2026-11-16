import SwiftUI

/// PAVE's pixel slash, also Ayla's mark: squares that climb to the right, half a square at a time.
struct PaveMark: View {
    var count = 4
    var size: CGFloat = 4.25
    /// Nil takes the accent of the app.
    var color: Color?
    @Environment(\.paveAccentColor) private var accent
    /// How visible each square is; square 0 is the bottom one. Used to build the slash up square by square.
    var squareOpacity: (Int) -> Double = { _ in 1 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<count, id: \.self) { index in
                Rectangle()
                    .fill(color ?? accent)
                    .frame(width: size, height: size)
                    .opacity(squareOpacity(index))
                    .offset(x: CGFloat(index) * size / 2, y: CGFloat(count - 1 - index) * size)
            }
        }
        .frame(width: size + CGFloat(count - 1) * size / 2, height: CGFloat(count) * size, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        PaveMark()
        PaveMark(count: 5, size: 5.333)
        PaveMark(count: 5, size: 6)
    }
    .padding()
}

extension EnvironmentValues {
    /// The accent of the app. The iPhone sets the theme colour from Instellingen; elsewhere it is PAVE green.
    @Entry var paveAccentColor: Color = .brandGreen
}
