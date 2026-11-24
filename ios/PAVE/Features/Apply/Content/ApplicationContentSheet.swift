import PAVECore
import SwiftUI

/// What is on the CV, from the editor: the same list as before the start, with how long the CV is now.
struct ApplicationContentSheet: View {
    let model: ApplicationStudioModel
    let pages: Int
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(ApplyMessages.whatGoesInEditorHint)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                    ApplicationPageCounter(pages: pages) { model.fitOnOnePage() }
                    ApplicationContentList(model: model)
                    Button(ApplyMessages.backToProposal) { model.propose() }
                        .textStyle(.link)
                        .foregroundStyle(Color.paveAccent)
                        .frame(minHeight: 44)
                        .buttonStyle(.pave)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.canvas)
            .navigationTitle(ApplyMessages.content)
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
