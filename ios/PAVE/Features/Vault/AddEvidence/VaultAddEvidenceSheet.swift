import PAVECore
import SwiftUI

/// "Bewijs toevoegen" from Figma (FEDDIES 1348:1169 to 1348:2537): four steps in one sheet. The pages slide the way you
/// go while the stepper runs along, and at the end the sheet becomes lower for the moment the evidence is added.
struct VaultAddEvidenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var flow: VaultAddEvidenceModel
    @State private var source: VaultFileSource?
    @State private var confirmsDiscard = false
    /// The status column of the iPhone Duo's outer display: a lower sheet would float under it, so it stays tall there.
    @State private var hasSideColumn = false
    @State private var height: CGFloat = 800
    /// While you type, the buttons step aside: return closes the keyboard and brings them back.
    @State private var isTyping = false

    init(vault: VaultModel, category: VaultCategory, folderID: String?) {
        self.init(flow: VaultAddEvidenceModel(vault: vault, category: category, folderID: folderID))
    }

    /// Starts at a given point of the flow, for previews.
    init(flow: VaultAddEvidenceModel) {
        _flow = State(initialValue: flow)
    }

    /// The outer display of the iPhone Duo and a phone held sideways: less room above and below.
    private var isShort: Bool { verticalSizeClass == .compact || height < 720 }

    private var pageAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.42)
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .push(from: flow.movesForward ? .trailing : .leading)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .top) {
                page
                    .id(flow.page)
                    .transition(pageTransition)
            }
            .environment(\.isShortSheet, isShort)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            if showsFooter {
                footer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .tint(.brandGreen)
        .animation(pageAnimation, value: flow.page)
        .animation(.easeOut(duration: 0.2), value: isTyping)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .onGeometryChange(for: Bool.self) { $0.safeAreaInsets.trailing > 0 || $0.safeAreaInsets.leading > 0 } action: { hasSideColumn = $0 }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in isTyping = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in isTyping = false }
        .presentationDetents(flow.page == .done && !hasSideColumn ? [.custom(AddedDetent.self)] : [.large])
        .presentationDragIndicator(.visible)
        // Swipe down to close, like every sheet; with something filled in it first asks whether to stop.
        .sheetDismissGuard(isBlocked: flow.hasChanges || flow.isSaving) {
            if !flow.isSaving { confirmsDiscard = true }
        }
        .vaultFilePicker(source: $source, role: .document) { result in
            withAnimation(pageAnimation) { flow.pick(result) }
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

    /// Step 1 without a file has two clear choices and no button; after that the buttons stay, except while typing.
    private var showsFooter: Bool {
        !isTyping && !(flow.page == .source && !flow.hasFile)
    }

    private var header: some View {
        VStack(spacing: isShort ? 10 : 18) {
            HStack {
                Text(VaultMessages.addTitle)
                    .textStyle(isShort ? .label : .listTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .frame(height: isShort ? 36 : 44)
            PaveStepper(steps: VaultMessages.steps, current: flow.page.step)
        }
        .padding(.horizontal, 24)
        .padding(.top, isShort ? 8 : 22)
        .padding(.bottom, isShort ? 8 : 16)
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
                    case .details: detailsPage
                    case .documents: VaultDocumentsStep(flow: flow)
                    case .skills: VaultSkillsPicker(skills: $flow.skills, known: flow.knownSkills, ayla: flow.ayla, draft: flow.draft, asksAylaOnAppear: true)
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

    private var detailsPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(flow.documents, id: \.checksum) { document in
                VaultFileRow(upload: document) {
                    withAnimation(.snappy(duration: 0.3)) { flow.remove(document) }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
            VaultEvidenceForm(
                draft: $flow.draft,
                missing: flow.missingFields,
                folders: flow.folders,
                onFolderChosen: flow.folderChosen,
                newFolder: flow.newKindFolder.map { name in
                    VaultEvidenceForm.NewFolder(name: name, isOn: true) { flow.setMakesKindFolder($0) }
                } ?? (flow.kindFolderMissing
                    ? VaultEvidenceForm.NewFolder(name: flow.draft.category.title, isOn: false) { flow.setMakesKindFolder($0) }
                    : nil)
            )
        }
        .onChange(of: flow.draft.category) { flow.categoryChanged() }
    }

    private var sourcePage: some View {
        VStack(spacing: isShort ? 14 : 20) {
            if flow.hasFile {
                ForEach(flow.documents, id: \.checksum) { document in
                    VaultFileRow(upload: document) {
                        withAnimation(.snappy(duration: 0.3)) { flow.remove(document) }
                    }
                }
                if flow.canAddDocument {
                    VaultUploadZone(title: VaultMessages.addAnotherDocument, hint: VaultMessages.uploadHint, sources: [.files, .photos], isCompact: true) {
                        source = $0
                    }
                }
            } else {
                VaultUploadZone(title: VaultMessages.uploadTitle, hint: VaultMessages.uploadHint, sources: [.files, .photos], height: isShort ? 140 : 194) {
                    source = $0
                }
                VaultOrDivider()
                VaultChoiceCard(title: VaultMessages.withoutFileTitle, message: VaultMessages.withoutFileMessage) {
                    flow.withoutFile()
                }
            }
        }
        .animation(.snappy(duration: 0.3), value: flow.documents)
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
        .padding(.bottom, isShort ? 6 : 12)
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
        case .source, .details, .documents:
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

}

extension EnvironmentValues {
    /// The sheet has little height (the iPhone Duo's outer display, a phone held sideways): parts become lower.
    @Entry var isShortSheet = false
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
