import SwiftUI

/// The QR code of a share, as big as the screen allows, black on white so a phone reads it from the wrist.
struct WatchSharedCodeView: View {
    let code: WatchSharedCode

    var body: some View {
        VStack(spacing: 6) {
            if let image = UIImage(data: code.png) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .background(.white, in: .rect(cornerRadius: 8))
                    .accessibilityLabel("QR-code voor \(code.title)")
            }
            Text("Voor \(code.title), tot \(code.until.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "nl_NL"))))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 4)
    }
}
