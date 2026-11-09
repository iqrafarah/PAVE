import SwiftUI

/// The pixel A that stands for Ayla in the menu (Figma "Loopbaan starten").
struct AylaLetter: View {
    var color = Color.white

    private static let square: CGFloat = 4.338
    private static let squares: [CGPoint] = [
        CGPoint(x: 0, y: 13.02), CGPoint(x: 2.17, y: 8.68), CGPoint(x: 4.34, y: 4.34), CGPoint(x: 6.51, y: 0),
        CGPoint(x: 10.85, y: 0), CGPoint(x: 10.85, y: 4.34), CGPoint(x: 10.85, y: 8.68), CGPoint(x: 10.85, y: 13.02),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.squares.indices, id: \.self) { index in
                Rectangle()
                    .fill(color)
                    .frame(width: Self.square, height: Self.square)
                    .offset(x: Self.squares[index].x, y: Self.squares[index].y)
            }
            Rectangle()
                .fill(color)
                .frame(width: Self.square, height: 2.892)
                .offset(x: 6.51, y: 10.12)
        }
        .frame(width: 10.85 + Self.square, height: 13.02 + Self.square, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

#Preview {
    AylaLetter()
        .padding()
        .background(Color.brandGreen)
}
