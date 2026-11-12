import SwiftUI

/// There is no sign-in on the Watch: it follows the iPhone.
struct WatchSignedOutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(.watchIconPhone)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(Color.brandGreen)
                Text(WatchMessages.signedOutTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(WatchMessages.signedOutMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    WatchSignedOutView()
}
