import SwiftUI

struct AuthIntro: View {
    var emblem: ImageResource?
    let eyebrow: String
    let title: String
    var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let emblem {
                Image(emblem)
                    .resizable()
                    .frame(width: 30, height: 30)
                    .frame(width: 64, height: 64)
                    .background(Color.surfaceTint, in: .circle)
                    .accessibilityHidden(true)
            }
            Text(eyebrow)
                .textStyle(.eyebrow)
                .foregroundStyle(Color.brandGreen)
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
        title: "Vul de code uit je authenticator-app in",
        message: "Open je authenticator-app en neem de code van 6 cijfers voor PAVE over. Je krijgt hem niet per mail."
    )
    .padding(32)
}
