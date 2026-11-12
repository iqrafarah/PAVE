import SwiftUI
import UIKit

/// How a cover looks on a card, as on the web (Figma 1209:56023): the image in the round avatar, and the band above
/// it in a light tint of the strongest colour in the image, so an orange logo gets a peach band.
struct VaultLogoLook: Equatable {
    let image: UIImage
    let tint: Color

    /// Works on a small copy away from the main thread; nil when the bytes are no image.
    static func make(from data: Data) async -> VaultLogoLook? {
        let found = await Task.detached(priority: .userInitiated) { () -> (UIImage, UIColor?)? in
            guard let image = UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 240, height: 240)) else { return nil }
            return (image, strongestColor(in: image))
        }.value
        guard let (image, strongest) = found else { return nil }
        return VaultLogoLook(image: image, tint: strongest.map { Color(uiColor: $0).mix(with: .white, by: 0.78) } ?? .surfaceTint)
    }

    /// The colour that stands out most: white, black and grey count for nothing, and the more saturated and bright a
    /// pixel is, the more it weighs. The pixels are grouped by hue and the heaviest group gives its average colour.
    nonisolated static func strongestColor(in image: UIImage) -> UIColor? {
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard
            let cgImage = image.cgImage,
            let context = CGContext(
                data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        let bins = 24
        var weights = [Double](repeating: 0, count: bins)
        var sums = [(r: Double, g: Double, b: Double, w: Double)](repeating: (0, 0, 0, 0), count: bins)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.5 else { continue }
            let r = Double(pixels[index]) / 255 / alpha
            let g = Double(pixels[index + 1]) / 255 / alpha
            let b = Double(pixels[index + 2]) / 255 / alpha
            let maximum = max(r, g, b)
            let minimum = min(r, g, b)
            let saturation = maximum == 0 ? 0 : (maximum - minimum) / maximum
            guard saturation > 0.25, maximum > 0.2 else { continue }
            var hue: Double
            if maximum == r { hue = (g - b) / (maximum - minimum) }
            else if maximum == g { hue = 2 + (b - r) / (maximum - minimum) }
            else { hue = 4 + (r - g) / (maximum - minimum) }
            hue = (hue / 6).truncatingRemainder(dividingBy: 1)
            if hue < 0 { hue += 1 }
            let bin = min(Int(hue * Double(bins)), bins - 1)
            let weight = saturation * maximum
            weights[bin] += weight
            sums[bin] = (sums[bin].r + r * weight, sums[bin].g + g * weight, sums[bin].b + b * weight, sums[bin].w + weight)
        }
        guard let best = weights.indices.max(by: { weights[$0] < weights[$1] }), sums[best].w > 0 else { return nil }
        let total = sums[best]
        return UIColor(red: total.r / total.w, green: total.g / total.w, blue: total.b / total.w, alpha: 1)
    }
}

/// The round avatar of an item: its cover image, or the first letter of the organisation when there is none.
struct VaultLogoAvatar: View {
    let look: VaultLogoLook?
    let name: String
    var size: CGFloat = 44

    var body: some View {
        if let look {
            Image(uiImage: look.image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .background(Color.white)
                .clipShape(.circle)
                .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
                .transition(.opacity)
                .accessibilityHidden(true)
        } else {
            CompanyMonogram(name: name, size: size)
        }
    }
}
