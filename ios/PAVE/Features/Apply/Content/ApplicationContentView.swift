import PAVECore
import SwiftUI

/// The second step: what goes on the CV. Ayla's proposal for this vacancy is already ticked, with the reason per piece
/// of evidence and how long the CV gets; then how to begin, with Ayla or yourself.
struct ApplicationContentView: View {
    let model: ApplicationStudioModel
    let photo: UIImage?
    let onBack: () -> Void

    @State private var pages = 1
    @State private var isBeginning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                ApplicationCoverageCard(model: model)
                ApplicationContentList(model: model)
                ApplicationFocusField(model: model)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { begin }
    }

    /// The page as it will be, small, next to what this step is and how long the CV gets.
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            ApplicationPages(draft: model.shown, document: .cv, photo: photo, cornerRadius: 6, onPageCount: { pages = $0 })
                .scaleEffect(Self.previewWidth / ApplicationPage.size.width, anchor: .topLeading)
                .frame(width: Self.previewWidth, height: ApplicationPage.size.height * Self.previewWidth / ApplicationPage.size.width, alignment: .topLeading)
                .background { RoundedRectangle(cornerRadius: 4).fill(.white).shadow(color: .black.opacity(0.12), radius: 8, y: 3) }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(ApplyMessages.whatGoesIn)
                    .textStyle(.emptyTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(ApplyMessages.whatGoesInHint(model.draft.vacancy))
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                ApplicationPageCounter(pages: pages) { model.fitOnOnePage() }
                if !model.isProposal {
                    Button(ApplyMessages.backToProposal) { model.propose() }
                        .textStyle(.link)
                        .foregroundStyle(Color.paveAccent)
                        .frame(minHeight: 44)
                        .buttonStyle(.pave)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static let previewWidth: CGFloat = 104

    private var begin: some View {
        VStack(spacing: 8) {
            // Side by side where both fit, so the list keeps the screen.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { choices }
                VStack(spacing: 10) { choices }
            }
            Text(model.canWrite ? ApplyMessages.aylaUses(model.itemsForAyla.count) : ApplyMessages.aylaUnavailable)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color.canvas)
        .overlay(alignment: .top) { Rectangle().fill(Color.cardBorder).frame(height: 1) }
    }

    @ViewBuilder
    private var choices: some View {
        PaveSecondaryButton(title: ApplyMessages.fillYourself) { start(withAyla: false) }
            .disabled(isBeginning)
        PavePrimaryButton(title: ApplyMessages.aylaFills, loadingTitle: ApplyMessages.aylaWriting, isLoading: isBeginning) { start(withAyla: true) }
            .disabled(!model.canWrite || isBeginning)
    }

    private func start(withAyla: Bool) {
        isBeginning = withAyla
        Task { await model.begin(withAyla: withAyla) }
    }
}
