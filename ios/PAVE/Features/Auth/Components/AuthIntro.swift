import SwiftUI

struct AuthIntro: View {
    var emblem: ImageResource?
    var eyebrow: String?
    let title: String
    var message: String?
    /// The steps of a flow of several screens. They take the place of the eyebrow, as on the web.
    var steps: [String]?
    var currentStep = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let steps {
                AuthSteps(steps: steps, currentIndex: currentStep)
                    .padding(.bottom, 12)
            }
            if let emblem {
                Image(emblem)
                    .resizable()
                    .frame(width: 30, height: 30)
                    .frame(width: 64, height: 64)
                    .background(Color.surfaceTint, in: .circle)
                    .accessibilityHidden(true)
            }
            if let eyebrow, steps == nil {
                Text(eyebrow)
                    .textStyle(.eyebrow)
                    .foregroundStyle(Color.brandGreen)
            }
            Text(title)
                .textStyle(.title)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            if let message {
                Text(message)
                    .textStyle(.lead)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    AuthIntro(
        emblem: .iconDevicePhoneMobile,
        eyebrow: "Tweestapsverificatie",
        title: "Open je authenticator-app",
        message: "Vul de code uit de app in."
    )
    .padding(32)
}
