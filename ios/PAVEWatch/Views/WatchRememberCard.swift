import PAVECore
import SwiftUI

/// "Zal ik dit onthouden?" under Ayla's answer, with Ja and Nee. Nothing is saved without Ja.
struct WatchRememberCard: View {
    let remember: WatchAylaModel.Remember
    let onAnswer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(WatchMessages.rememberQuestion)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.brandGreen)
            Text(remember.suggestion.text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            switch remember.state {
            case .asking:
                HStack(spacing: 6) {
                    Button("Nee") { onAnswer(false) }
                    Button("Ja") { onAnswer(true) }
                        .tint(.brandGreen)
                }
                .buttonStyle(.borderedProminent)
            case .saving:
                ProgressView()
            case .saved:
                status(WatchMessages.remembered, icon: .watchIconCheck)
            case .declined:
                status(WatchMessages.notRemembered, icon: .watchIconXMark)
            case .failed:
                Text(WatchMessages.message(for: .unavailable))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandGreen.opacity(0.18), in: .rect(cornerRadius: 12))
    }

    private func status(_ text: String, icon: ImageResource) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(icon).renderingMode(.template)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
