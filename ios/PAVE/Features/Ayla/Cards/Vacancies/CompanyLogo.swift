import SwiftUI

/// The company's logo in the round badge of a vacancy, or the first letter of its name while the logo loads and when
/// there is none. Logos are drawn for a white ground, so the badge stays white in dark mode too.
struct CompanyLogo: View {
    let name: String
    let url: URL?
    var size: CGFloat = 64

    @State private var logo: UIImage?

    var body: some View {
        ZStack {
            if let logo {
                Image(uiImage: logo)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size * 0.56, height: size * 0.56)
                    .frame(width: size, height: size)
                    .background(Color.white, in: .circle)
                    .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
                    .transition(.opacity)
                    .accessibilityHidden(true)
            } else {
                CompanyMonogram(name: name, size: size)
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
    /// Smaller than this (in pixels) is the service's placeholder or too blurry to show: the letter is better.
    private static let minimumSide: CGFloat = 48

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
