import SwiftUI

/// The profile photo on a page, round, or nothing when there is none.
struct CVPhotoView: View {
    let photo: UIImage?
    var size: CGFloat = 72
    var ring: Color = .clear

    var body: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.circle)
                .overlay { Circle().strokeBorder(ring, lineWidth: 3) }
                .accessibilityHidden(true)
        }
    }
}
