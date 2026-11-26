import PAVECore
import SwiftUI

/// Ayla writes a block again: shorter, stronger for this vacancy, in English, more formal or more personal. What it
/// said before can come back once.
struct ApplicationRewriteBar: View {
    let model: ApplicationStudioModel
    let block: ApplicationBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                AylaLetter(color: .paveAccent)
                    .frame(width: 13, height: 13)
                    .accessibilityHidden(true)
                Text(model.writing == block ? ApplyMessages.aylaWriting : ApplyMessages.aylaWrites)
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
                    .contentTransition(.opacity)
            }
            FlowLayout(spacing: 8) {
                    ForEach(ApplicationWritingRequest.Rewrite.allCases, id: \.self) { how in
                        Button(ApplyMessages.rewrite(how)) {
                            Task { await model.rewrite(block, how) }
                        }
                        .textStyle(.chip)
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Color.panel, in: .capsule)
                        .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: 1) }
                        .frame(minHeight: 44)
                        .contentShape(.capsule)
                        .buttonStyle(.pave)
                    }
            }
            .disabled(model.writing != nil || !model.canWrite)
            .opacity(model.writing != nil ? 0.5 : 1)
            if model.before?.block == block {
                Button(ApplyMessages.undo) { model.undoAyla() }
                    .textStyle(.link)
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44)
                    .buttonStyle(.pave)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.writing)
    }
}
