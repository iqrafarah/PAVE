import SwiftUI

/// There is no sign-in on the Watch: it follows the iPhone. Signed in there without connecting this Watch, it asks
/// you to connect it in Instellingen.
struct WatchSignedOutView: View {
    var needsConnecting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(.watchIconPhone)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(Color.brandGreen)
                Text(needsConnecting ? WatchMessages.notConnectedTitle : WatchMessages.signedOutTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(needsConnecting ? WatchMessages.notConnectedMessage : WatchMessages.signedOutMessage)
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
