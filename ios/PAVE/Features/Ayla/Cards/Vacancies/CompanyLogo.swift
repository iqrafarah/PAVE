import SwiftUI

/// The company's logo in the round badge of a vacancy, or the first letter of its name while the logo loads and when
/// there is none. Logos are drawn for a white ground, so the badge stays white in dark mode too.
struct CompanyLogo: View {
    let name: String
    let url: URL?
    var size: CGFloat = 64

    @State private var logo: UIImage?

    private var isSmall: Bool {
        guard let logo else { return false }
        return min(logo.size.width, logo.size.height) * logo.scale < 64
    }

    var body: some View {
        ZStack {
            if let logo {
                Image(uiImage: logo)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    // A small icon is drawn smaller, so it stays as sharp as it can be.
                    .frame(width: size * (isSmall ? 0.44 : 0.56), height: size * (isSmall ? 0.44 : 0.56))
                    .frame(width: size, height: size)
                    .background(Color.white, in: .circle)
                    .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
                    .transition(.opacity)
                    .accessibilityHidden(true)
            } else {
                CompanyIconBadge(size: size)
            }
        }
        .animation(.easeOut(duration: 0.2), value: logo != nil)
        .task(id: url) { logo = await CompanyLogos.shared.logo(at: url) }
    }
}

/// Loads company logos once and keeps them while the app runs.
final class CompanyLogos {
    static let shared = CompanyLogos()

    private let cache = NSCache<NSURL, UIImage>()
    /// Smaller than this (in pixels) is the service's placeholder or too blurry to show: the icon is better.
    private static let minimumSide: CGFloat = 32

    func logo(at url: URL?) async -> UIImage? {
        guard let url, url.scheme == "https" else { return nil }
        if let known = cache.object(forKey: url as NSURL) { return known }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
        request.httpShouldHandleCookies = false
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data),
              min(image.size.width, image.size.height) * image.scale >= Self.minimumSide
        else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
