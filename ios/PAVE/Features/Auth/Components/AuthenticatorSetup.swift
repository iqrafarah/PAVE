import CoreImage.CIFilterBuiltins
import PAVECore
import SwiftUI
import UniformTypeIdentifiers

struct SetupStepRow: View {
    let number: Int
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .textStyle(.eyebrow)
                .foregroundStyle(Color.brandGreen)
                .frame(width: 28, height: 28)
                .background(Color.surfaceTint, in: .circle)
                .accessibilityLabel("Stap \(number)")

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
                Text(message)
                    .textStyle(.footnote)
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

struct OtherDeviceSetupCard: View {
    let setupURI: URL
    let secret: String?

    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                QRCodeImage(content: setupURI.absoluteString)
                    .frame(width: 108, height: 108)
                    .accessibilityLabel("QR-code voor je authenticator-app")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Scan met je andere apparaat")
                        .textStyle(.label)
                        .foregroundStyle(Color.brandGreen)
                    Text("Open je authenticator-app, voeg een account toe en scan deze code.")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let secret {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lukt scannen niet? Vul dan deze instelsleutel in:")
                        .textStyle(.label)
                        .foregroundStyle(Color.ink)
                    HStack(spacing: 8) {
                        Text(secret)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Color.ink)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button(didCopy ? "Gekopieerd" : "Kopieer") {
                            copy(secret)
                        }
                        .textStyle(.eyebrow)
                        .foregroundStyle(Color.brandGreen)
                        .frame(minWidth: 44, minHeight: 44)
                        .buttonStyle(.pave)
                        .accessibilityLabel(didCopy ? "Instelsleutel gekopieerd" : "Kopieer instelsleutel")
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 4)
                    .background(Color.white, in: .rect(cornerRadius: 7))
                }
            }
        }
        .padding(16)
        .background(Color.surfaceTint, in: .rect(cornerRadius: 12))
    }

    private func copy(_ secret: String) {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: secret]],
            options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(120)]
        )
        didCopy = true
    }
}

struct SetupPreviewPlaceholder: View {
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.brandGreen)
                } else {
                    Image(.iconQrcode)
                        .resizable()
                        .frame(width: 44, height: 44)
                    Text("VOORBEELD")
                        .textStyle(.tag)
                        .foregroundStyle(Color.brandGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4)
                }
            }
            .frame(width: 108, height: 108)
            .background(Color.white, in: .rect(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Color.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(isLoading ? "QR-code laden..." : "Voorbeeld")
                    .textStyle(.label)
                    .foregroundStyle(Color.brandGreen)
                if !isLoading {
                    Text("Demo-account. Er wordt geen echte verificatiecode gemaakt.")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.ink)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.surfaceTint, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

private struct QRCodeImage: View {
    let content: String

    var body: some View {
        if let image = Self.render(content) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(6)
                .background(Color.white, in: .rect(cornerRadius: 7))
        }
    }

    private static func render(_ content: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"
        guard
            let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
            let cgImage = CIContext().createCGImage(output, from: output.extent)
        else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    VStack(spacing: 16) {
        SetupStepRow(number: 1, title: "Voeg PAVE toe aan je codes", message: "Je iPhone bewaart de code voor je.")
        OtherDeviceSetupCard(
            setupURI: URL(string: "otpauth://totp/PAVE:ravi?secret=JBSWY3DPEHPK3PXP&issuer=PAVE")!,
            secret: "JBSWY3DPEHPK3PXP"
        )
        SetupPreviewPlaceholder(isLoading: false)
    }
    .padding(32)
}
