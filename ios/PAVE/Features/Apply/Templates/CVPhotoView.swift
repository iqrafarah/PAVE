import SwiftUI

/// The profile photo on a page, round or in a rounded square, or nothing when there is none.
struct CVPhotoView: View {
    let photo: UIImage?
    var size: CGFloat = 96
    var cornerRadius: CGFloat?
    var ring: Color = .clear
    var ringWidth: CGFloat = 4

    var body: some View {
        if let photo {
            let shape = cornerRadius.map { AnyShape(RoundedRectangle(cornerRadius: $0)) } ?? AnyShape(Circle())
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(shape)
                .overlay { shape.stroke(ring, lineWidth: ringWidth) }
                .accessibilityHidden(true)
        }
    }
}
