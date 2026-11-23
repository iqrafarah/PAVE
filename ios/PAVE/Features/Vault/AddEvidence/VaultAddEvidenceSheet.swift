import PAVECore
import SwiftUI

/// "Bewijs toevoegen" from Figma (FEDDIES 1348:1169 to 1348:2537): four steps in one sheet. The pages slide the way you
/// go while the stepper runs along, and at the end the sheet becomes lower for the moment the evidence is added.
struct VaultAddEvidenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.paveReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var flow: VaultAddEvidenceModel
    @State private var source: VaultFileSource?
    @State private var confirmsDiscard = false
    /// The status column of the iPhone Duo's outer display: a lower sheet would float under it, so it stays tall there.
    @State private var hasSideColumn = false
    @State private var height: CGFloat = 800
    /// While you type, the buttons step aside: return closes the keyboard and brings them back.
    @State private var isTyping = false
    @State private var isScanning = false
    /// "Haal bewijs uit je wallet" (demo): its own way through this sheet, with its own steps.
    @State private var wallet: VaultWalletModel?
    @Environment(PaveCameraControl.self) private var cameraControl: PaveCameraControl?

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
        ZStack {
            if let wallet {
                VaultWalletFlow(wallet: wallet, onBack: closeWallet, onDone: { dismiss() })
                    .environment(\.isShortSheet, isShort)
                    .transition(reduceMotion ? .opacity : .push(from: .trailing))
            } else {
                steps
                    .transition(reduceMotion ? .opacity : .push(from: .leading))
            }
        }
        .animation(pageAnimation, value: wallet == nil)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.panel.ignoresSafeArea())
        .tint(.paveAccent)
        .animation(pageAnimation, value: flow.page)
        .animation(.easeOut(duration: 0.2), value: isTyping)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .onGeometryChange(for: Bool.self) { $0.safeAreaInsets.trailing > 0 || $0.safeAreaInsets.leading > 0 } action: { hasSideColumn = $0 }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in isTyping = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in isTyping = false }
        .presentationDetents(flow.page == .done && wallet == nil && !hasSideColumn ? [.custom(AddedDetent.self)] : [.large])
        .presentationDragIndicator(.visible)
        // Swipe down to close, like every sheet; with something filled in it first asks whether to stop.
        .sheetDismissGuard(isBlocked: flow.hasChanges || flow.isSaving || wallet?.isChecking == true) {
            if !flow.isSaving, wallet == nil { confirmsDiscard = true }
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
            flow.isResumed = false
            AccessibilityNotification.Announcement("Stap \(page.step + 1) van 4: \(VaultMessages.steps[page.step])").post()
        }
        .onAppear {
            if flow.isResumed { AccessibilityNotification.Announcement(VaultMessages.draftBack).post() }
        }
        // Closed before saving, also by accident: it comes back as it was when you add evidence within half a minute.
        .onDisappear { flow.vault.keepDraft(flow) }
        .cameraControlMenus("add-evidence", menus: cameraMenus, press: { primaryAction() })
        // A scan from the Camera Control button: the scanner needs the camera knopmodus holds, so knopmodus waits.
        .fullScreenCover(isPresented: $isScanning, onDismiss: { cameraControl?.isSuspended = false }) {
            DocumentScanner(
                onScan: { pages in
                    isScanning = false
                    Task { await addScan(pages) }
                },
                onCancel: { isScanning = false }
            )
            .ignoresSafeArea()
        }
    }

    /// The four steps of adding evidence yourself.
    private var steps: some View {
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
    }

    private func openWallet() {
        PaveHaptics.selection()
        wallet = VaultWalletModel(vault: flow.vault, folderID: flow.startFolderID)
    }

    private func closeWallet() {
        wallet = nil
    }

    // MARK: Camera Control

    /// Knopmodus while adding evidence: a full press is the main button of the page; the menus hold the other
    /// buttons, the ways to add a file on the first page and the kind of evidence on the details.
    private var cameraMenus: [CameraMenu] {
        var menus: [CameraMenu] = []
        if flow.page == .source, !flow.hasFile {
            var ways: [(String, () -> Void)] = []
            if DocumentScanner.isAvailable { ways.append(("Scannen", startScan)) }
            ways.append(("Foto", { source = .photos }))
            ways.append(("Bestand", { source = .files }))
            ways.append(("Zonder bestand", { withAnimation(pageAnimation) { flow.withoutFile() } }))
            ways.append(("Uit je wallet", openWallet))
            menus.append(CameraMenu(id: "add-ways", title: "Toevoegen", symbol: "plus.circle", items: ways.map(\.0), onPress: { index in
                if ways.indices.contains(index) { ways[index].1() }
            }))
        }
        if flow.page == .details {
            let kinds = VaultCategory.allCases
            menus.append(CameraMenu(
                id: "kind", title: "Soort", symbol: "square.stack", items: kinds.map(\.singularTitle),
                selected: kinds.firstIndex(of: flow.draft.category) ?? 0,
                onSwipe: { index in if kinds.indices.contains(index) { flow.draft.category = kinds[index] } }
            ))
        }
        var steps: [(String, () -> Void)] = []
        if flow.canGoBack {
            steps.append(("Terug", { flow.back() }))
        } else if offersAyla {
            steps.append((VaultMessages.aylaFillStop, {
                flow.stopFilling()
                Task { await flow.next() }
            }))
        } else if flow.page == .done, !flow.nextEvidence.isEmpty {
            steps.append((VaultMessages.nextEvidenceSkip, { Task { if await flow.finish() { dismiss() } } }))
        }
        if flow.page != .done {
            steps.append(("Stoppen", { if flow.hasChanges { confirmsDiscard = true } else { dismiss() } }))
        }
        menus.append(CameraMenu(id: "steps", title: "Stap", symbol: "arrow.left.arrow.right", items: steps.map(\.0), onPress: { index in
            if steps.indices.contains(index) { steps[index].1() }
        }))
        return menus
    }

    private func startScan() {
        cameraControl?.isSuspended = true
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            isScanning = true
        }
    }

    private func addScan(_ pages: [CGImage]) async {
        guard !pages.isEmpty else { return }
        let day = Date.now.formatted(.iso8601.year().month().day())
        guard let file = try? await AttachmentReader.file(pages: pages, name: "Scan \(day).pdf"), let upload = file.upload else {
            flow.problem = VaultMessages.scanFailed
            return
        }
        withAnimation(pageAnimation) { flow.pick(.success(upload)) }
    }

    /// What the main button of the page does, also for a full press of the Camera Control button.
    private func primaryAction() {
        guard !flow.isSaving else { return }
        switch flow.page {
        case .source where offersAyla:
            if flow.aylaFill != .reading { flow.fillWithAyla() }
        case .source, .details, .documents, .skills:
            Task { await flow.next() }
        case .done:
            Task {
                guard await flow.finish() else { return }
                if let next = flow.nextFlow() {
                    flow = next
                } else {
                    dismiss()
                }
            }
        }
    }

    private var resumedNotice: some View {
        HStack(spacing: 12) {
            Text(VaultMessages.draftBack)
                .textStyle(.caption)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(VaultMessages.draftStartOver) {
                PaveHaptics.selection()
                withAnimation(pageAnimation) {
                    flow = VaultAddEvidenceModel(vault: flow.vault, category: flow.startCategory, folderID: flow.startFolderID)
                }
            }
            .textStyle(.label)
            .foregroundStyle(Color.paveAccent)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 14)
        .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
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
            if flow.isResumed {
                resumedNotice
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: flow.isResumed)
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
            if flow.aylaProposal != nil {
                VaultAylaFilledBanner(splitTitles: flow.aylaSplitTitles, addsApart: flow.addsApart, onAddsApart: flow.setAddsApart)
            }
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
                    : nil),
                aylaNotes: flow.aylaNotes,
                revealsAylaFill: flow.revealsAylaFill
            )
            // Only the first time after she filled it: going back and forth shows the fields at once.
            .onDisappear { flow.revealsAylaFill = false }
        }
        .animation(.snappy(duration: 0.3), value: flow.documents)
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
                if flow.aylaFill == .reading {
                    VaultAylaFillSkeleton()
                        .padding(.top, 6)
                        .transition(.opacity)
                } else if flow.canAddDocument {
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
                VaultChoiceCard(title: VaultMessages.walletChoiceTitle, message: VaultMessages.walletChoiceMessage, action: openWallet)
            }
        }
        .animation(.snappy(duration: 0.3), value: flow.documents)
        .animation(.easeOut(duration: 0.25), value: flow.aylaFill)
    }

    /// With a file on the first page, Ayla offers to fill it in, until she did.
    private var offersAyla: Bool {
        flow.page == .source && flow.hasFile && flow.aylaFill != .filled
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if flow.canGoBack {
                PaveSoftButton(title: "Terug") { flow.back() }
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else if flow.page == .done, !flow.nextEvidence.isEmpty {
                PaveSoftButton(title: VaultMessages.nextEvidenceSkip) {
                    Task { if await flow.finish() { dismiss() } }
                }
                .disabled(flow.isSaving)
            } else if offersAyla {
                PaveSoftButton(title: VaultMessages.aylaFillStop) {
                    flow.stopFilling()
                    Task { await flow.next() }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            primaryButton
        }
        .animation(pageAnimation, value: offersAyla)
        .animation(pageAnimation, value: flow.canGoBack)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, isShort ? 6 : 12)
        .background(Color.panel)
        // A problem floats just above the buttons, over the bottom of the page, so nothing above it moves.
        .overlay(alignment: .top) {
            if let problem = flow.problem {
                PaveInlineError(message: problem)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.panel)
                    .alignmentGuide(.top) { $0[.bottom] }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: flow.problem)
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch flow.page {
        case .source where offersAyla:
            PavePrimaryButton(title: flow.aylaFill == .idle ? VaultMessages.aylaFillTitle : VaultMessages.aylaFillAgain, loadingTitle: VaultMessages.aylaFillButtonReading, isLoading: flow.aylaFill == .reading) {
                primaryAction()
            }
        case .source, .details, .documents:
            PavePrimaryButton(title: "Volgende") { primaryAction() }
        case .skills:
            PavePrimaryButton(title: "Toevoegen", loadingTitle: VaultMessages.saving, isLoading: flow.isSaving) {
                primaryAction()
            }
        case .done:
            PavePrimaryButton(title: flow.nextEvidence.isEmpty ? "Afronden" : VaultMessages.nextEvidence, loadingTitle: "Bewaren…", isLoading: flow.isSaving) {
                primaryAction()
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
