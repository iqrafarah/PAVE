import SwiftUI

/// What the app switcher and Control Center show of PAVE: only the logo, never your chats or what Ayla knows.
struct PavePrivacyCover: View {
    var body: some View {
        ZStack {
            Color.canvas
            Image(.paveLogo)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 150)
                .foregroundStyle(Color.paveAccent)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    PavePrivacyCover()
}
