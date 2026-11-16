import SwiftUI

/// Your account as a round badge: your photo, else the first letter of your name, else a person.
struct AccountBadge: View {
    let name: String?
    var image: UIImage?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let initial = name?.trimmingCharacters(in: .whitespaces).first {
                Text(String(initial).uppercased())
                    .textStyle(.action)
                    .foregroundStyle(Color.paveAccent)
            } else {
                Image(.iconUserSolid)
                    .renderingMode(.template)
                    .foregroundStyle(Color.paveAccent)
            }
        }
        .frame(width: size, height: size)
        .background(Color.paveSurfaceTint, in: .circle)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        AccountBadge(name: "Daaf")
        AccountBadge(name: nil)
    }
}
