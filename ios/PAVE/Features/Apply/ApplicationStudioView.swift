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

    @State private var panel = Panel.content
    @State private var showsDesign = false
    @State private var showsContent = false
    @State private var exported: ExportedFile?
    @State private var isExporting = false
    @Environment(\.paveReduceMotion) private var reduceMotion

    private enum Panel: String, CaseIterable { case content, design }

    /// Wide enough for the panel next to the page.
    private static let wideWidth: CGFloat = 720

    init(model: ApplicationStudioModel, photo: UIImage?, onClose: @escaping () -> Void) {
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
                    ApplicationGalleryView(model: model, photo: photo)
                }
            case .start:
                VStack(spacing: 0) {
                    stepBar { model.stage = .gallery }
                    ApplicationContentView(model: model, photo: photo) { model.stage = .gallery }
                }
            case .editor:
                editor
            }
        }
        .background(Color.canvas)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.stage)
        .sheet(item: $exported) { VaultShareSheet(urls: [$0.url]) }
        .onDisappear { model.settle() }
        .alert(ApplyMessages.aylaWrites, isPresented: Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })) {
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
                    }
                } else {
                    ApplicationCanvas(model: model, photo: photo)
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
                ApplicationContentSheet(model: model, pages: model.pages) { showsContent = false }
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
                roundButton(.iconArrowLeft, label: ApplyMessages.otherDesign, action: back)
            } else {
                roundButton(.iconXMark, label: ApplyMessages.close, action: onClose)
            }
            Text(ApplyMessages.title(model.draft.vacancy))
                .textStyle(.label)
                .foregroundStyle(Color.inkMuted)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            if back != nil {
                roundButton(.iconXMark, label: ApplyMessages.close, action: onClose)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            roundButton(.iconXMark, label: ApplyMessages.close, action: onClose)
            Spacer(minLength: 0)
            Picker(ApplyMessages.title(model.draft.vacancy), selection: Binding(get: { model.document }, set: { value in
                model.selection = nil
                model.document = value
            })) {
                Text(ApplyMessages.cv).tag(ApplicationDocumentKind.cv)
                Text(ApplyMessages.letter).tag(ApplicationDocumentKind.letter)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            Spacer(minLength: 0)
            roundButton(.iconArrowUpTrayOutline, label: model.document == .cv ? ApplyMessages.exportCV : ApplyMessages.exportLetter, isBusy: isExporting, action: export)
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
            pill(.iconPaintBrushOutline, ApplyMessages.design, showsTitle: showsTitles) { showsDesign = true }
            if model.document == .letter {
                pill(.iconPlusCircleOutline, ApplyMessages.paragraph, showsTitle: showsTitles) { model.addParagraph() }
            } else {
                pill(.iconListBulletOutline, ApplyMessages.content, showsTitle: showsTitles) { showsContent = true }
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
                        PaveSecondaryButton(title: ApplyMessages.addParagraph, icon: .iconPlusCircleOutline) { model.addParagraph() }
                    } else {
                        PaveSecondaryButton(title: ApplyMessages.whatGoesIn, icon: .iconListBulletOutline) { showsContent = true }
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

    // MARK: Parts

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
