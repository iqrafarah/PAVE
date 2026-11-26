import SwiftUI

/// The QR codes on the wrist: one per page, as big as the screen allows, black on white so a phone reads it, with only a
/// short line above it saying which one it is. Swipe to the next one.
struct WatchSharedCodeView: View {
    let codes: [WatchSharedCode]
    /// The code to start on, such as the one that just arrived.
    var startID: String?

    @State private var selection: String = ""

    var body: some View {
        TabView(selection: $selection) {
            ForEach(codes) { code in
                page(code).tag(code.id)
            }
        }
        .tabViewStyle(.verticalPage)
        .onAppear { selection = startID ?? codes.first?.id ?? "" }
    }

    private func page(_ code: WatchSharedCode) -> some View {
        VStack(spacing: 4) {
            Text(code.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WatchPreferences.shared.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let image = UIImage(data: code.png) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(5)
                    .background(.white, in: .rect(cornerRadius: 8))
                    .accessibilityLabel("QR-code: \(code.title)")
            }
        }
        .padding(.horizontal, 2)
    }
}
