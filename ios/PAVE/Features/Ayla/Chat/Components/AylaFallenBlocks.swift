import SwiftUI

/// The same blocks in red, tumbling over once when something went wrong (from Figma).
struct AylaFallenBlocks: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasFallen = false

    private struct Block {
        let origin: CGPoint
        var fall = CGSize.zero
        var rotation: Double = 0
    }

    private static let size: CGFloat = 11.936
    private static let blocks: [Block] = [
        Block(origin: CGPoint(x: 0, y: 47.74)),
        Block(origin: CGPoint(x: 4.88, y: 35.81), fall: CGSize(width: 6.35, height: 6.42), rotation: 0.5448),
        Block(origin: CGPoint(x: 21.16, y: 47.74)),
        Block(origin: CGPoint(x: 27.13, y: 35.81), fall: CGSize(width: 3.33, height: 4.65), rotation: 0.7368),
        Block(origin: CGPoint(x: 33.1, y: 23.87), fall: CGSize(width: 8.66, height: 10.89), rotation: 0.3718),
        Block(origin: CGPoint(x: 42.32, y: 47.74)),
        Block(origin: CGPoint(x: 48.29, y: 35.81), fall: CGSize(width: 5.46, height: 5.93), rotation: 0.3665),
        Block(origin: CGPoint(x: 54.26, y: 23.87), fall: CGSize(width: 5.74, height: 7.13)),
        Block(origin: CGPoint(x: 60.22, y: 11.94), fall: CGSize(width: -13.22, height: 10.07), rotation: -0.4506),
        Block(origin: CGPoint(x: 66.19, y: 47.74)),
        Block(origin: CGPoint(x: 72.16, y: 35.81), fall: CGSize(width: 6.24, height: 9.59), rotation: 0.6563),
        Block(origin: CGPoint(x: 78.13, y: 23.87), fall: CGSize(width: -6.51, height: 9.75), rotation: -0.3327),
        Block(origin: CGPoint(x: 84.1, y: 11.94), fall: CGSize(width: 9.89, height: 31.05), rotation: 0.7247),
        Block(origin: CGPoint(x: 90.06, y: 0), fall: CGSize(width: -5.06, height: 32)),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.blocks.indices, id: \.self) { index in
                let block = Self.blocks[index]
                Rectangle()
                    .fill(Color.criticalInk)
                    .frame(width: Self.size, height: Self.size)
                    .rotationEffect(.radians(hasFallen ? block.rotation : 0))
                    .offset(
                        x: block.origin.x + (hasFallen ? block.fall.width : 0),
                        y: block.origin.y + (hasFallen ? block.fall.height : 0)
                    )
            }
        }
        .frame(width: 102, height: 60, alignment: .topLeading)
        .onAppear {
            if reduceMotion {
                hasFallen = true
            } else {
                withAnimation(.timingCurve(0.5, 0, 0.5, 1, duration: 0.415)) { hasFallen = true }
            }
        }
    }
}

#Preview {
    AylaFallenBlocks()
        .padding()
}
