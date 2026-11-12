import SwiftUI

/// The box the Watch comes out of: matte off-white like a product box, with PAVE's slash in green and a lid that swings
/// open backwards. The back and the front are separate, so the Watch can rise from between them.
enum WatchGiftBox {
    static let width: CGFloat = 216
    static let frontHeight: CGFloat = 120
    static let lidHeight: CGFloat = 40

    private static let paper = LinearGradient(colors: [Color(white: 0.995), Color(white: 0.93)], startPoint: .top, endPoint: .bottom)

    /// The inside, behind the Watch.
    struct Back: View {
        var body: some View {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.84), Color(white: 0.93)], startPoint: .top, endPoint: .bottom))
                .frame(width: WatchGiftBox.width - 14, height: WatchGiftBox.frontHeight + 26)
        }
    }

    /// The front, over the lower part of the Watch.
    struct Front: View {
        var body: some View {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(WatchGiftBox.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                }
                .overlay(alignment: .top) {
                    // The edge of the opening catches the light.
                    Capsule()
                        .fill(.white)
                        .frame(height: 1.5)
                        .padding(.horizontal, 16)
                        .padding(.top, 1)
                }
                .overlay {
                    PaveMark(size: 10, color: .brandGreen)
                }
                .frame(width: WatchGiftBox.width, height: WatchGiftBox.frontHeight)
                .shadow(color: .brandGreen.opacity(0.14), radius: 30, y: 18)
                .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
        }
    }

    /// The lid on top; it turns around its back edge.
    struct Lid: View {
        let isOpen: Bool

        var body: some View {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(WatchGiftBox.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                }
                .frame(width: WatchGiftBox.width + 8, height: WatchGiftBox.lidHeight)
                .shadow(color: .black.opacity(isOpen ? 0 : 0.08), radius: 4, y: 3)
                .rotation3DEffect(.degrees(isOpen ? 118 : 0), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.45)
                .opacity(isOpen ? 0.7 : 1)
        }
    }
}
