import CoreImage.CIFilterBuiltins
import SwiftUI

/// A QR code of a link, sharp at any size, black on white so every scanner reads it, also in dark mode.
struct ShareQRCode: View {
    let url: URL

    var body: some View {
        Group {
            if let image = Self.image(for: url.absoluteString) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .padding(14)
        .background(.white, in: .rect(cornerRadius: 16))
        .accessibilityLabel("QR-code van de link")
    }

    static func image(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage, let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// For the Watch: a bitmap big enough to stay sharp there.
    static func png(for text: String, size: CGFloat = 400) -> Data? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: size / output.extent.width, y: size / output.extent.height))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg).pngData()
    }
}
