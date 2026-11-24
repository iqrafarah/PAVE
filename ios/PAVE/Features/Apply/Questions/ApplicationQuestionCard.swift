import PAVECore
import SwiftUI

/// One question from Ayla: what it is about, a line to answer in, and after that what the CV says now, with a way
/// back and a way to keep the answer with the evidence in the vault.
struct ApplicationQuestionCard: View {
    let model: ApplicationStudioModel
    let question: ApplicationQuestion

    private var item: VaultItem? { model.item(question.sourceItemID) }
    private var hasAnswer: Bool { !question.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ApplyMessages.questionAbout(question.title))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                Text(question.text)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            switch question.state {
            case .open, .working:
                TextField("", text: Binding(get: { question.answer }, set: { model.setAnswer(question.id, $0) }), prompt: Text(ApplyMessages.answerPrompt).foregroundStyle(Color.inkMuted), axis: .vertical)
                    .lineLimit(1...4)
                    .textStyle(.input)
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 48)
                    .background(Color.canvas, in: .rect(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cardBorder, lineWidth: 1) }
                    .disabled(question.state == .working)
                    .accessibilityLabel(question.text)
                HStack(spacing: 14) {
                    PavePrimaryButton(title: ApplyMessages.workIn, loadingTitle: ApplyMessages.aylaWriting, isLoading: question.state == .working) {
                        Task { await model.answer(question.id) }
                    }
                    .disabled(!hasAnswer || question.state == .working)
                    Button(ApplyMessages.skip) { model.skip(question.id) }
                        .textStyle(.link)
                        .foregroundStyle(Color.paveAccent)
                        .frame(minHeight: 44)
                        .buttonStyle(.pave)
                        .disabled(question.state == .working)
                }
            case .done:
                VStack(alignment: .leading, spacing: 4) {
                    Text(ApplyMessages.workedIn)
                        .textStyle(.caption)
                        .foregroundStyle(Color.paveAccent)
                    Text(model.entry(question.entryID)?.description ?? "")
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
                Button(ApplyMessages.undo) { model.undoAnswer(question.id) }
                    .textStyle(.link)
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44)
                    .buttonStyle(.pave)
                if model.keepInVault != nil {
                    keep
                }
            case .skipped:
                EmptyView()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1) }
    }

    /// Nothing goes to the vault by itself: the user says so, knowing what it does to verified evidence.
    @ViewBuilder
    private var keep: some View {
        if question.isKept {
            Text(ApplyMessages.keptInVault)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(item?.status == .verified ? ApplyMessages.keepVerifiedHint : ApplyMessages.keepHint)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                PaveSecondaryButton(title: ApplyMessages.keepInVault) {
                    Task { await model.keep(question.id) }
                }
                .disabled(question.isKeeping)
            }
        }
    }
}
