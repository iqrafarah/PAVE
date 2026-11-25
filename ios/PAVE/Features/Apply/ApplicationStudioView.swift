import PAVECore
import SwiftUI

/// Making a CV and a motivation letter for a vacancy, Canva-style: pick a template filled with your own data, let Ayla
/// write along, change any block by tapping it, and export a pdf. On a wide screen (iPad, the open iPhone Duo held
/// sideways) the panel sits next to the page, as in Figma; on a phone the page fills the screen and editing comes up
/// from below, so the page stays in view above it.
struct ApplicationStudioView: View {
    @State private var model: ApplicationStudioModel
    let photo: UIImage?
    let onClose: () -> Void
    /// Opened as a page in the app (Vacatures), not over it: the way out is back, not a cross.
    var isPushed = false
    /// Ayla's help with this vacancy from the overview: what you miss, practising the interview.
    var onTask: (AylaRequest.VacancyTask) -> Void = { _ in }

    @State private var panel = Panel.content
    @State private var showsDesign = false
    @State private var showsContent = false
    @State private var showsQuestions = false
    @State private var exported: ExportedFile?
    @State private var isExporting = false
    @State private var sharing: ShareRequest?
    @State private var sharedNow: ProfileShare?
    @State private var asksSent = false
    /// "Meer opties" was tapped: the steps open once the quick screen is gone.
    @State private var detailedNext: Set<ApplicationDocumentKind>?
    @State private var openedShare: String?
    @State private var confirmsStop = false
    @Environment(\.paveReduceMotion) private var reduceMotion
    /// Where shares are made; absent in previews.
    @Environment(SharingModel.self) private var shares: SharingModel?

    /// Sharing from the studio, with the documents that start on.
    private struct ShareRequest: Identifiable {
        let id = UUID()
        let documents: Set<ApplicationDocumentKind>
        /// The steps with purpose and downloading, asked for with "Meer opties".
        var isDetailed = false
    }

    private enum Panel: String, CaseIterable { case content, design }

    /// Wide enough for the panel next to the page.
    private static let wideWidth: CGFloat = 720

    init(
        model: ApplicationStudioModel, photo: UIImage?, isPushed: Bool = false, onClose: @escaping () -> Void,
        onTask: @escaping (AylaRequest.VacancyTask) -> Void = { _ in }
    ) {
        self.onTask = onTask
        self.isPushed = isPushed
        model.measure = { ApplicationPageMeasure.pages($0, photo: $0.showsPhoto ? photo : nil) }
        _model = State(initialValue: model)
        self.photo = photo
        self.onClose = onClose
    }

    var body: some View {
        Group {
            switch model.stage {
            case .gallery:
                VStack(spacing: 0) {
                    stepBar(back: nil)
                    steps(current: 0)
                    ApplicationGalleryView(model: model, photo: photo)
                }
            case .start:
                VStack(spacing: 0) {
                    stepBar { model.stage = .gallery }
                    steps(current: 1)
                    ApplicationContentView(model: model, photo: photo) { model.stage = .gallery }
                }
            case .hub:
                VStack(spacing: 0) {
                    stepBar(back: nil)
                    ApplicationHubView(
                        model: model, photo: photo, shares: shares.map { $0.shares(forVacancy: model.draft.vacancy.id) },
                        onShare: shares == nil ? nil : { share(model.hasLetter ? [.cv, .letter] : [.cv]) },
                        onOpenShare: { openedShare = $0 },
                        onTask: onTask
                    )
                }
            case .editor:
                editor
            }
        }
        .background(Color.canvas)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.stage)
        .sheet(item: $exported) { VaultShareSheet(urls: [$0.url]) }
        .sheet(item: $sharing, onDismiss: sharingClosed) { request in
            if let shares {
                if request.isDetailed {
                    ShareComposer(
                        model: shares, template: .employer, recipientOrganisation: model.draft.vacancy.company, vacancyID: model.draft.vacancy.id,
                        startsWith: request.documents, doneTitle: ApplyMessages.backToApplication,
                        onShared: { sharedNow = $0 }
                    ) { sharing = nil }
                } else {
                    QuickShareSheet(
                        model: shares, start: .application(vacancyID: model.draft.vacancy.id, documents: request.documents),
                        onShared: { sharedNow = $0 },
                        onMoreOptions: {
                            detailedNext = request.documents
                            sharing = nil
                        }
                    ) { sharing = nil }
                }
            }
        }
        .sheet(item: Binding(get: { openedShare.map(OpenedShare.init) }, set: { openedShare = $0?.id })) { opened in
            if let shares {
                NavigationStack {
                    ShareDetailView(model: shares, shareID: opened.id)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(ApplyMessages.done) { openedShare = nil }
                            }
                        }
                }
            }
        }
        .confirmationDialog(ApplyMessages.markSentQuestion, isPresented: $asksSent, titleVisibility: .visible) {
            Button(ApplyMessages.markSent) { model.setStatus(.sent) }
            Button(ApplyMessages.notNow, role: .cancel) {}
        } message: {
            Text(ApplyMessages.markSentHint(model.draft.vacancy.company))
        }
        .confirmationDialog(ApplyMessages.stopQuestion, isPresented: $confirmsStop, titleVisibility: .visible) {
            Button(ApplyMessages.stop, role: .destructive, action: onClose)
            Button(ApplyMessages.goOn, role: .cancel) {}
        } message: {
            Text(ApplyMessages.stopHint)
        }
        .task { shares?.reloadApplications() }
        .onDisappear { model.settle() }
        .alert(ApplyMessages.somethingWrong, isPresented: Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.problem ?? "")
        }
    }

    private var editor: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= Self.wideWidth
            VStack(spacing: 0) {
                topBar
                if isWide {
                    HStack(spacing: 0) {
                        ScrollView {
                            sidePanel
                                .padding(20)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .frame(width: 360)
                        .background(Color.canvas)
                        Rectangle().fill(Color.cardBorder).frame(width: 1)
                        ApplicationCanvas(model: model, photo: photo)
                            .overlay(alignment: .top) { ApplicationSavedNote(savedAt: model.savedAt) }
                    }
                } else {
                    ApplicationCanvas(model: model, photo: photo)
                        .overlay(alignment: .top) { ApplicationSavedNote(savedAt: model.savedAt) }
                        // Over the page, so nothing moves when her questions arrive.
                        .overlay(alignment: .bottom) {
                            if model.openQuestions > 0, model.selection == nil {
                                ApplicationQuestionsPill(count: model.openQuestions) { showsQuestions = true }
                                    .padding(.bottom, 10)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.15), value: model.openQuestions)
                    bottomBar
                }
            }
            .background(Color.canvas)
            .sheet(isPresented: Binding(get: { !isWide && model.selection != nil }, set: { if !$0 { model.selection = nil } })) {
                editorSheet
            }
            .sheet(isPresented: $showsDesign) {
                designSheet
            }
            .sheet(isPresented: $showsContent) {
                ApplicationContentSheet(model: model, pages: model.pages, onAskOn: {
                    showsContent = false
                    showsQuestions = true
                    Task { await model.askQuestions() }
                }) { showsContent = false }
            }
            .sheet(isPresented: $showsQuestions) {
                ApplicationQuestionsSheet(model: model) { showsQuestions = false }
            }
            .onChange(of: model.selection) { _, block in
                // What was typed in the block that closes shows and is kept at once.
                model.settle()
                if block != nil, isWide { withAnimation(.snappy(duration: 0.25)) { panel = .content } }
            }
        }
    }

    // MARK: Bars

    /// Above the gallery and the start: close, or back to the gallery, and for which vacancy.
    private func stepBar(back: (() -> Void)?) -> some View {
        HStack(spacing: 12) {
            if let back {
                roundBackButton(label: ApplyMessages.otherDesign, action: back)
            } else if isPushed {
                roundBackButton(label: ApplyMessages.backToApplications, action: close)
            } else {
                roundButton(.iconXMark, label: ApplyMessages.close, action: close)
            }
            Text(ApplyMessages.title(model.draft.vacancy))
                .textStyle(.label)
                .foregroundStyle(Color.inkMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if back != nil, !isPushed {
                roundButton(.iconXMark, label: ApplyMessages.close, action: close)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            roundBackButton(label: ApplyMessages.backToApplication) { model.showOverview() }
            Spacer(minLength: 0)
            Picker(ApplyMessages.title(model.draft.vacancy), selection: Binding(get: { model.document }, set: { value in
                model.selection = nil
                model.document = value
            })) {
                Text(ApplyMessages.cv).tag(ApplicationDocumentKind.cv)
                Text(ApplyMessages.letterShort).tag(ApplicationDocumentKind.letter)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            Spacer(minLength: 0)
            if shares != nil {
                Button { share([model.document]) } label: {
                    Text(ApplyMessages.share)
                        .textStyle(.chip)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Color.panel, in: .capsule)
                        .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: 1) }
                        .contentShape(.capsule)
                }
                .buttonStyle(.pave)
                .accessibilityLabel(ApplyMessages.shareWith(model.draft.vacancy.company))
            }
            roundButton(.iconArrowUpTraySolid, label: model.document == .cv ? ApplyMessages.exportCV : ApplyMessages.exportLetter, isBusy: isExporting, action: export)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var bottomBar: some View {
        // On a narrow phone the two quiet buttons keep their icon only, so the three fit on one line.
        ViewThatFits(in: .horizontal) {
            bottomButtons(showsTitles: true)
            bottomButtons(showsTitles: false)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(Color.canvas)
    }

    private func bottomButtons(showsTitles: Bool) -> some View {
        HStack(spacing: 10) {
            pill(.iconPaintBrushSolid, ApplyMessages.design, showsTitle: showsTitles) { showsDesign = true }
            if model.document == .letter {
                pill(.iconPlus, ApplyMessages.paragraph, showsTitle: showsTitles) { model.addParagraph() }
            } else {
                pill(.iconListBulletSolid, ApplyMessages.content, showsTitle: showsTitles) { showsContent = true }
            }
            Button {
                Task { model.document == .cv ? await model.writeProfile() : await model.writeLetter() }
            } label: {
                HStack(spacing: 8) {
                    if isAylaWriting {
                        ProgressView().tint(.white)
                    } else {
                        AylaLetter(color: .white)
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                    }
                    Text(isAylaWriting ? ApplyMessages.aylaWriting : ApplyMessages.aylaWritesShort)
                        .textStyle(.chip)
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Color.paveAccentFill, in: .capsule)
            }
            .buttonStyle(.pave)
            .disabled(!model.canWrite || isAylaWriting)
            .accessibilityLabel(model.document == .cv ? ApplyMessages.aylaProfile : ApplyMessages.aylaLetter)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var isAylaWriting: Bool { model.document == .cv ? model.writing == .profile : model.isWritingLetter }

    // MARK: Panels

    @ViewBuilder
    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker(ApplyMessages.design, selection: $panel) {
                Text(ApplyMessages.content).tag(Panel.content)
                Text(ApplyMessages.design).tag(Panel.design)
            }
            .pickerStyle(.segmented)
            switch panel {
            case .content:
                if let block = model.selection {
                    ApplicationBlockEditor(model: model, block: block)
                        .id(block)
                        .transition(.opacity)
                } else {
                    ApplicationAylaCard(model: model)
                    if model.document == .letter {
                        PaveSecondaryButton(title: ApplyMessages.addParagraph, icon: .iconPlus) { model.addParagraph() }
                    } else {
                        PaveSecondaryButton(title: ApplyMessages.whatGoesIn, icon: .iconListBulletSolid) { showsContent = true }
                        PaveSecondaryButton(title: model.openQuestions > 0 ? ApplyMessages.aylaAsks(model.openQuestions) : ApplyMessages.askOn) {
                            showsQuestions = true
                            if model.openQuestions == 0 { Task { await model.askQuestions() } }
                        }
                        .disabled(!model.canWrite && model.questions.isEmpty)
                    }
                    Text(ApplyMessages.tapToEdit)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
            case .design:
                ApplicationDesignPanel(model: model, photo: photo)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.selection)
    }

    private var editorSheet: some View {
        NavigationStack {
            ScrollView {
                if let block = model.selection {
                    ApplicationBlockEditor(model: model, block: block)
                        .id(block)
                        .padding(20)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.canvas)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ApplyMessages.done) { model.selection = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    private var designSheet: some View {
        NavigationStack {
            ScrollView {
                ApplicationDesignPanel(model: model, photo: photo)
                    .padding(20)
            }
            .background(Color.canvas)
            .navigationTitle(ApplyMessages.design)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ApplyMessages.done) { showsDesign = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    /// Where a new application is: the same steps as adding evidence to the vault.
    private func steps(current: Int) -> some View {
        PaveStepper(steps: ApplyMessages.steps, current: current)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }

    // MARK: Leaving and sharing

    /// A new application asks first: what was chosen in the gallery and the content step is not kept.
    private func close() {
        if model.isKept { onClose() } else { confirmsStop = true }
    }

    /// The composer with this vacancy and company filled in; what was typed is kept first, so the share has it.
    private func share(_ documents: Set<ApplicationDocumentKind>) {
        model.settle()
        shares?.reloadApplications()
        sharedNow = nil
        sharing = ShareRequest(documents: documents)
    }

    /// Back from sharing: on the overview, where the share now shows, and asked whether it went out.
    private func sharingClosed() {
        if let documents = detailedNext {
            detailedNext = nil
            sharing = ShareRequest(documents: documents, isDetailed: true)
            return
        }
        guard sharedNow != nil else { return }
        sharedNow = nil
        model.showOverview()
        if model.tracking.status == .concept { asksSent = true }
    }

    private struct OpenedShare: Identifiable { let id: String }

    // MARK: Parts

    /// Back, with the same chevron as the system's back button.
    private func roundBackButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PaveBackChevron()
                .frame(width: 44, height: 44)
                .background(Color.panel, in: .circle)
                .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
                .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(label)
    }

    private func roundButton(_ icon: ImageResource, label: String, isBusy: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isBusy {
                    ProgressView()
                } else {
                    Image(icon)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(18)
                        .foregroundStyle(Color.ink)
                }
            }
            .frame(width: 44, height: 44)
            .background(Color.panel, in: .circle)
            .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
            .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .disabled(isBusy)
        .accessibilityLabel(label)
    }

    private func pill(_ icon: ImageResource, _ title: String, showsTitle: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(16)
                    .foregroundStyle(Color.paveAccent)
                    .accessibilityHidden(true)
                if showsTitle {
                    Text(title)
                        .textStyle(.chip)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .frame(minWidth: 44, minHeight: 44)
            .background(Color.panel, in: .capsule)
            .overlay { Capsule().strokeBorder(Color.cardBorder, lineWidth: 1) }
            .contentShape(.capsule)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(title)
    }

    private func export() {
        model.settle()
        isExporting = true
        defer { isExporting = false }
        do {
            exported = ExportedFile(url: try ApplicationPDF.file(for: model.draft, document: model.document, photo: photo))
            PaveHaptics.success()
        } catch {
            model.problem = ApplyMessages.exportFailed
        }
    }
}

private struct ExportedFile: Identifiable {
    let url: URL
    var id: URL { url }
}
