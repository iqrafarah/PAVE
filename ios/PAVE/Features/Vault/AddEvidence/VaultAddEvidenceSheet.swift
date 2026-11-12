import PAVECore
import SwiftUI

/// "Bewijs toevoegen" from Figma (FEDDIES 1348:1169 to 1348:2537): four steps in one sheet. The pages slide the way you
/// go, the stepper fills up, and at the end the sheet becomes lower for the moment the evidence is added.
struct VaultAddEvidenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var flow: VaultAddEvidenceModel
    @State private var source: VaultFileSource?
    @State private var confirmsDiscard = false
    /// The status column of the iPhone Duo's outer display: a lower sheet would float under it, so it stays tall there.
    @State private var hasSideColumn = false

    init(vault: VaultModel, category: VaultCategory, folderID: String?) {
        self.init(flow: VaultAddEvidenceModel(vault: vault, category: category, folderID: folderID))
    }

    /// Starts at a given point of the flow, for previews.
    init(flow: VaultAddEvidenceModel) {
        _flow = State(initialValue: flow)
    }

    private var isShort: Bool { verticalSizeClass == .compact }

    private var pageAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .snappy(duration: 0.38)
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let leading = AnyTransition.move(edge: .leading).combined(with: .opacity)
        let trailing = AnyTransition.move(edge: .trailing).combined(with: .opacity)
        return flow.movesForward
            ? .asymmetric(insertion: trailing, removal: leading)
            : .asymmetric(insertion: leading, removal: trailing)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .top) {
                page
                    .id(flow.page)
                    .transition(pageTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            footer
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .tint(.brandGreen)
        .animation(pageAnimation, value: flow.page)
        .onGeometryChange(for: Bool.self) { $0.safeAreaInsets.trailing > 0 || $0.safeAreaInsets.leading > 0 } action: { hasSideColumn = $0 }
        .presentationDetents(flow.page == .done && !hasSideColumn ? [.custom(AddedDetent.self)] : [.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(flow.hasChanges || flow.isSaving)
        .vaultFilePicker(source: $source, role: .document) { result in
            withAnimation(.snappy(duration: 0.3)) { flow.pick(result) }
        }
        .confirmationDialog(VaultMessages.discardTitle, isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Stoppen", role: .destructive) { dismiss() }
            Button("Verder met toevoegen", role: .cancel) {}
        } message: {
            Text(VaultMessages.discardMessage)
        }
        .onChange(of: flow.page) { _, page in
            AccessibilityNotification.Announcement("Stap \(page.step + 1) van 4: \(VaultMessages.steps[page.step])").post()
        }
    }

    private var header: some View {
        VStack(spacing: isShort ? 12 : 18) {
            HStack {
                Text(VaultMessages.addTitle)
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: close) {
                    Image(.iconXMark)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .accessibilityLabel("Sluiten")
            }
            PaveStepper(steps: VaultMessages.steps, current: flow.page.step)
        }
        .padding(.leading, 24)
        .padding(.trailing, 12)
        .padding(.top, isShort ? 10 : 20)
        .padding(.bottom, isShort ? 10 : 16)
    }

    @ViewBuilder
    private var page: some View {
        if flow.page == .done {
            VaultEvidenceAddedView(flow: flow)
                .padding(.horizontal, 24)
                .padding(.top, 8)
        } else {
            ScrollView {
                Group {
                    switch flow.page {
                    case .source: sourcePage
                    case .details: VaultEvidenceForm(flow: flow)
                    case .documents: VaultCoverPicker(flow: flow)
                    case .skills: VaultSkillsPicker(flow: flow)
                    case .done: EmptyView()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var sourcePage: some View {
        VStack(spacing: 20) {
            if let document = flow.document {
                VaultFileRow(upload: document) {
                    withAnimation(.snappy(duration: 0.3)) { flow.removeDocument() }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                VaultUploadZone(title: VaultMessages.uploadTitle, hint: VaultMessages.uploadHint, sources: [.files, .photos], height: isShort ? 150 : 194) {
                    source = $0
                }
                .transition(.opacity)
                VaultOrDivider()
                VaultChoiceCard(title: VaultMessages.withoutFileTitle, message: VaultMessages.withoutFileMessage) {
                    flow.withoutFile()
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if flow.canGoBack {
                PaveSoftButton(title: "Terug") { flow.back() }
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            primaryButton
        }
        .animation(pageAnimation, value: flow.canGoBack)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, isShort ? 8 : 12)
        .background(Color.white)
        // A problem floats just above the buttons, over the bottom of the page, so nothing above it moves.
        .overlay(alignment: .top) {
            if let problem = flow.problem {
                PaveInlineError(message: problem)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .alignmentGuide(.top) { $0[.bottom] }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: flow.problem)
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch flow.page {
        case .source:
            PavePrimaryButton(title: "Volgende") { Task { await flow.next() } }
                .disabled(flow.document == nil)
        case .details, .documents:
            PavePrimaryButton(title: "Volgende") { Task { await flow.next() } }
        case .skills:
            PavePrimaryButton(title: "Toevoegen", loadingTitle: VaultMessages.saving, isLoading: flow.isSaving) {
                Task { await flow.next() }
            }
        case .done:
            PavePrimaryButton(title: "Afronden", loadingTitle: "Bewaren…", isLoading: flow.isSaving) {
                Task { if await flow.finish() { dismiss() } }
            }
        }
    }

    private func close() {
        if flow.hasChanges { confirmsDiscard = true } else { dismiss() }
    }
}

/// The lower sheet for the last step, as in Figma (about 56% of the screen), but never too low for its content.
private struct AddedDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        min(context.maxDetentValue, max(context.maxDetentValue * 0.6, 520))
    }
}

#Preview {
    Color.canvas
        .sheet(isPresented: .constant(true)) {
            VaultAddEvidenceSheet(vault: VaultModel(previewContents: .preview), category: .internships, folderID: nil)
                .paveSheet()
        }
}
