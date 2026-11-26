import PAVECore
import SwiftUI

/// Ayla writing the profile or the whole letter, and which evidence she uses for it.
struct ApplicationAylaCard: View {
    let model: ApplicationStudioModel

    private var isWriting: Bool { model.document == .cv ? model.writing == .profile : model.isWritingLetter }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AylaLetter(color: .paveAccent)
                    .frame(width: 15, height: 15)
                    .accessibilityHidden(true)
                Text(ApplyMessages.aylaWrites)
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
            }
            Text(ApplyMessages.aylaUses(model.itemsForAyla.count))
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            PavePrimaryButton(
                title: model.document == .cv ? ApplyMessages.aylaProfile : ApplyMessages.aylaLetter,
                loadingTitle: ApplyMessages.aylaWriting,
                isLoading: isWriting
            ) {
                Task { model.document == .cv ? await model.writeProfile() : await model.writeLetter() }
            }
            .disabled(!model.canWrite)
        }
        .padding(16)
        .background(Color.panel, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1) }
    }
}
