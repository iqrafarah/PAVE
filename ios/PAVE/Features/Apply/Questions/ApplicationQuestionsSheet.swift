import SwiftUI

/// Ayla's questions about the CV, to answer or to skip, and a way to let her look again.
struct ApplicationQuestionsSheet: View {
    let model: ApplicationStudioModel
    let onDone: () -> Void

    private var shown: [ApplicationQuestion] { model.questions.filter { $0.state != .skipped } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(shown.isEmpty && !model.isAsking ? model.questionsProblem ?? ApplyMessages.noQuestions : ApplyMessages.questionsHint)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(shown) { question in
                        ApplicationQuestionCard(model: model, question: question)
                    }
                    if model.openQuestions == 0 {
                        PaveSecondaryButton(title: model.isAsking ? ApplyMessages.asking : ApplyMessages.askOn) {
                            Task { await model.askQuestions() }
                        }
                        .disabled(model.isAsking || !model.canWrite)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.canvas)
            .navigationTitle(ApplyMessages.questionsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ApplyMessages.done, action: onDone)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}
