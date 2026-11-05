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
        emblem: .iconShieldCheck,
        eyebrow: "Two-step verification",
        title: "Verify your identity",
        message: "Open your authenticator app and enter the 6-digit code for your PAVE account."
    )
    .padding(32)
}
