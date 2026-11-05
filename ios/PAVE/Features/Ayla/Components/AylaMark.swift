import SwiftUI

/// Ayla's pixel slash: squares that climb to the right, half a square at a time.
struct AylaMark: View {
    var count = 4
    var size: CGFloat = 4.25
    var color = Color.brandGreen

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<count, id: \.self) { index in
                Rectangle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .offset(x: CGFloat(index) * size / 2, y: CGFloat(count - 1 - index) * size)
            }
        }
        .frame(width: size + CGFloat(count - 1) * size / 2, height: CGFloat(count) * size, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        AylaMark()
        AylaMark(count: 5, size: 5.333)
        AylaMark(count: 5, size: 6)
    }
    .padding()
}
