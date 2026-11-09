import SwiftUI

/// The voice mode icon: a small sound wave of square-ended bars, in the blocky style of Ayla's slash.
struct PixelWaveIcon: View {
    var color = Color.white

    private static let heights: [CGFloat] = [5, 11, 15, 11, 5]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Self.heights.indices, id: \.self) { index in
                Rectangle()
                    .fill(color)
                    .frame(width: 2.5, height: Self.heights[index])
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    PixelWaveIcon()
        .frame(width: 30, height: 30)
        .background(Color.brandGreen, in: .circle)
        .padding()
}
