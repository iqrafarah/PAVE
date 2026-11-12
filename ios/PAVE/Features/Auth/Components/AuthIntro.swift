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
                    .background(Color.paveSurfaceTint, in: .circle)
                    .accessibilityHidden(true)
            }
            if let eyebrow, steps == nil {
                Text(eyebrow)
                    .textStyle(.eyebrow)
                    .foregroundStyle(Color.paveAccent)
            }
            Text(Self.keepingHyphenatedWordsWhole(title))
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

    /// "Open je authenticator-app" breaks before "authenticator-app", not after the hyphen.
    static func keepingHyphenatedWordsWhole(_ title: String) -> String {
        title.replacingOccurrences(of: "-", with: "\u{2060}-\u{2060}")
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
