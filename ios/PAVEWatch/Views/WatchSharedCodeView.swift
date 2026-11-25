import SwiftUI

/// Your card on the wrist: PAVE and your name on top, the QR code as big as the screen allows, black on white so a
/// phone reads it.
struct WatchSharedCodeView: View {
    let code: WatchSharedCode

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if let name = code.name {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("PAVE").font(.caption2.weight(.semibold))
                        Text(name).font(.headline).lineLimit(2)
                        if let headline = code.headline {
                            Text(headline).font(.caption2).opacity(0.85).lineLimit(2)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brandGreen.gradient, in: .rect(cornerRadius: 10))
                    .accessibilityElement(children: .combine)
                }
                if let image = UIImage(data: code.png) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                        .background(.white, in: .rect(cornerRadius: 8))
                        .accessibilityLabel("QR-code voor \(code.title)")
                }
                Text("Tot \(code.until.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "nl_NL"))))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 4)
        }
    }
}
