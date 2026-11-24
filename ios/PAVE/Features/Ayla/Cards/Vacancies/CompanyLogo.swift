import SwiftUI

/// The company's logo in the round badge of a vacancy, or the first letter of its name while the logo loads and when
/// there is none. Logos are drawn for a white ground, so the badge stays white in dark mode too.
struct CompanyLogo: View {
    let name: String
    let url: URL?
    var size: CGFloat = 64
    /// Where the company is, so the search for its site finds the right one.
    var city: String?
    /// Off for "Via werkzoeken.nl": that site's own icon is what the card names, and nothing is looked up.
    var looksUp = true
    /// The logo fills the whole circle, like the logo of evidence in the vault, instead of sitting small in the middle.
    var fills = false

    @State private var logo: UIImage?

    private var isSmall: Bool {
        guard let logo else { return false }
        return min(logo.size.width, logo.size.height) * logo.scale < 64
    }

    var body: some View {
        ZStack {
            if let logo, fills {
                Image(uiImage: logo)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .background(Color.white)
                    .clipShape(.circle)
                    .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
                    .transition(.opacity)
                    .accessibilityHidden(true)
            } else if let logo {
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
        .task(id: url) {
            logo = await CompanyLogos.shared.logo(at: url)
            // No logo, or only a favicon too small to show: PAVE looks for the logo on the company's own site.
            if logo == nil, looksUp { logo = await CompanyLogos.shared.logo(of: name, in: city) }
            // A site's icon often has a white or transparent margin: without it the logo itself fills the circle.
            if fills, let found = logo {
                logo = await Task.detached(priority: .userInitiated) { Self.withoutMargin(found) }.value
            }
        }
    }

    /// The image without its white or transparent edges; the image itself when there are none, or nothing else.
    nonisolated static func withoutMargin(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let width = cgImage.width, height = cgImage.height
        guard width > 2, height > 2, width * height <= 2_048 * 2_048 else { return image }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                let alpha = Int(pixels[i + 3])
                guard alpha > 24 else { continue }
                // Premultiplied: near white means each channel close to the alpha.
                let isWhite = [0, 1, 2].allSatisfy { alpha - Int(pixels[i + $0]) < 16 } && alpha > 230
                guard !isWhite else { continue }
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return image }
        let box = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        // Hardly a margin, or almost nothing left: keep the image as it is.
        guard box.width * box.height < CGFloat(width * height) * 0.95, box.width >= 16, box.height >= 16,
              let cropped = cgImage.cropping(to: box) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}

/// Loads company logos once and keeps them while the app runs.
final class CompanyLogos {
    static let shared = CompanyLogos()

    private let cache = NSCache<NSURL, UIImage>()
    /// Asks the server for a company's logo; set once Ayla is there.
    var finder: (@Sendable (String, String?) async -> URL?)?
    /// One lookup per company and place while the app runs, also when it found nothing.
    private var lookups: [String: Task<URL?, Never>] = [:]

    func logo(of company: String, in city: String?) async -> UIImage? {
        guard let finder, !company.isEmpty else { return nil }
        let key = "\(company)|\(city ?? "")".lowercased()
        let lookup = lookups[key] ?? Task { await finder(company, city) }
        lookups[key] = lookup
        return await logo(at: await lookup.value)
    }
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
