import SwiftUI

/// A calm line that says the device is offline, in place of an error after a long wait.
struct PaveOfflineNotice: View {
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(.iconSignalSlash)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
            Text(message)
                .textStyle(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PaveOfflineNotice(message: "Je bent offline. Wat je typt blijft staan tot je weer verbinding hebt.")
        .padding()
        .background(Color.canvas)
}
