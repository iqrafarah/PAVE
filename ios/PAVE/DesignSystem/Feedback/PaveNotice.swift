import SwiftUI

struct PaveNotice: View {
    enum Tone {
        case info
        case critical
    }

    let title: String?
    let message: Text
    var tone: Tone = .info

    init(title: String? = nil, message: String, tone: Tone = .info) {
        self.title = title
        self.message = Text(message)
        self.tone = tone
    }

    init(title: String? = nil, message: AttributedString, tone: Tone = .info) {
        self.title = title
        self.message = Text(message)
        self.tone = tone
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(tone == .info ? .iconInformationCircle : .iconExclamationCircle)
                .resizable()
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title)
                        .textStyle(.calloutTitle)
                        .foregroundStyle(tone == .info ? Color.paveAccent : .critical)
                }
                message
                    .textStyle(.footnote)
                    .foregroundStyle(tone == .info ? Color.ink : .critical)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(tone == .info ? Color.paveSurfaceTint : .criticalSurface, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 16) {
        PaveNotice(title: "Je account krijg je van je organisatie", message: "Gebruik het account dat je van je organisatie hebt gekregen.")
        PaveNotice(title: "Inloggen is niet gelukt", message: "Je e-mailadres of wachtwoord klopt niet.", tone: .critical)
    }
    .padding(32)
    .background(Color.canvas)
}
