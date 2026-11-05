import SwiftUI

struct PaveNotice: View {
    enum Tone {
        case info
        case critical
    }

    let title: String
    let message: String
    var tone: Tone = .info

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(tone == .info ? .iconInformationCircle : .iconExclamationCircle)
                .resizable()
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .textStyle(.calloutTitle)
                    .foregroundStyle(tone == .info ? Color.brandGreen : .critical)
                Text(message)
                    .textStyle(.footnote)
                    .foregroundStyle(tone == .info ? Color.ink : .critical)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(tone == .info ? Color.surfaceTint : .criticalSurface, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 16) {
        PaveNotice(title: "Your account is provided", message: "Use the account supplied by your organization.")
        PaveNotice(title: "We couldn’t sign you in", message: "Your email or password is incorrect.", tone: .critical)
    }
    .padding(32)
    .background(Color.canvas)
}
