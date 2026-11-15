import PAVECore
import PhotosUI
import SwiftUI

/// The conversation with Ayla (Figma frames "Ayla"). Vacancies slide up in a panel on every screen size.
struct AylaChatScreen: View {
    @Bindable var model: AylaChatModel
    /// Nil when the menu is already on screen, on the inner display of iPhone Duo and on iPad.
    let onShowMenu: (() -> Void)?
    let onShowChats: () -> Void

    /// The navigation bar sits 4 pt higher than the header in Figma.
    private static let toolbarOffset: CGFloat = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.hidesScreenButtons) private var hidesScreenButtons
    @Environment(VaultModel.self) private var vault: VaultModel?
    @Environment(\.openFromAyla) private var openFromAyla
    /// Adding evidence after Ja to Ayla's "Wil je iets toevoegen?", filled with what she proposed.
    @State private var addEvidence: VaultAddEvidenceModel?
    @State private var dictation = SpeechDictation()
    @State private var voice: AylaVoiceSession?
    @State private var voiceProblem: SpeechDictation.Problem?
    @State private var draftBeforeDictation = ""
    @Namespace private var barSpace
    // The spoken conversation's pixel intro and outro, and the field around the orb (all positions are on screen).
    @State private var introPhase: AylaVoiceIntro.Phase?
    /// The orb's two places on screen: large in the middle, and small above the voice bar.
    @State private var stageSlot = CGRect.zero
    @State private var barSlot = CGRect.zero
    @State private var outroOrbFrame = CGRect.zero
    @State private var voiceButtonFrame = CGRect.zero
    /// Where the layer with the orb and the intro is on screen.
    @State private var layerOrigin = CGPoint.zero
    @State private var fieldRevealedAt: Date?
    @State private var isOrbHidden = false
    /// Where the orb sits while talking, once the user dragged it: large in the middle (true) or small above the
    /// voice bar with the conversation in view (false). Nil follows the screen: full screen on iPhone, in the chat on
    /// iPad and the open Duo.
    @State private var prefersVoiceStage: Bool?
    /// Whether the screen shows the spoken conversation. It changes at the tap, inside an animation, so the text
    /// field melts into the voice bar; the session itself takes a moment to start.
    @State private var isTalking = false
    /// Where the orb is between its places: 0 large in the middle, 1 small above the voice bar with the conversation
    /// in view.
    @State private var orbMotion = AylaOrbMotion()
    /// Haptics for dragging the orb: a tap once letting go would switch, a click when it switches, a landing when
    /// it arrives.
    @State private var isOrbReadyToSwitch = false
    /// Also false when iOS cancels the drag without ending it, so the orb is never left stretched.
    @GestureState private var isHoldingOrb = false
    @State private var orbSnaps = 0
    @State private var orbLandings = 0
    @State private var orbSpringBacks = 0
    @State private var voiceBarHeight: CGFloat = 0
    /// Where the line under the large orb is, so the field leaves it clear.
    @State private var captionFrame = CGRect.null
    @State private var openVacanciesID: String?
    @State private var bottomBarHeight: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @State private var isAttachMenuOpen = false
    @State private var isChoosingFile = false
    @State private var isChoosingPhotos = false
    @State private var vaultDetent = PresentationDetent.large
    /// Files the user took out of a card, by the reply's id and the file's checksum.
    @State private var excludedFiles: [String: Set<String>] = [:]
    /// The reply whose item is being added, so the card can say it went into the vault.
    @State private var addingFromReplyID: String?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var picksVaultItem = false
    @State private var fileProblem: String?
    @FocusState private var isComposerFocused: Bool
    @State private var readAloud = AylaReadAloud()
    @Environment(AylaMemoryModel.self) private var memory
    @State private var showsMemory = false
    @State private var isScanning = false
    @State private var isDropTargeted = false
    @State private var selectingText: SelectableText?
    /// Scrolled up far enough that the newest message is out of view.
    @State private var isAwayFromBottom = false
    /// The offline line above the text field; the conversation makes room for it, so it never covers a message.
    @State private var offlineNoticeHeight: CGFloat = 0
    @AppStorage(AylaVoiceTextSetting.key) private var showsVoiceText = true
    private let connection = PaveConnection.shared

    private struct SelectableText: Identifiable {
        let id: String
        let text: String
    }

    /// Kluis, Plan or Profiel from the start chips, open over the chat.
    @State private var shelf: AylaShelf?
    /// What a button of the chat does once that sheet has slid away: the menu and the chats open over the chat,
    /// never under a sheet.
    @State private var afterShelf: (() -> Void)?
    /// The wave of blocks after something went into the vault, and the save that is busy after a yes in words.
    @State private var waveStartedAt: Date?
    @State private var isSavingForUser = false
    @State private var confirmationItem: VaultItem?
    /// Ja and Nee by nodding or shaking the head with AirPods on, and what the last nod or shake answered.
    @State private var headGestures = AylaHeadGestures()
    @State private var headAnswer: Bool?
    /// Whether that answer came from the head or from a tap on Ja or Nee.
    @State private var answeredByHead = true
    @State private var waveFromOrb = false
    /// The vacancy shown under the orb while talking, gone through by turning the head.
    @State private var vacancyIndex = 0
    /// Photos for an item that just went into the vault, after a Ja to Ayla's question for them.
    @State private var photosForItemID: String?
    @State private var photoTargetID: String?
    @State private var itemPhotoItems: [PhotosPickerItem] = []
    @State private var mutedForPhotos = false
    @State private var isAddingItemPhotos = false
    @Environment(PaveCameraControl.self) private var cameraControl: PaveCameraControl?
    @Environment(\.toolbarIsBeside) private var toolbarIsBeside

    private var openVacancies: [Vacancy]? {
        guard let openVacanciesID, let entry = model.entries.first(where: { $0.id == openVacanciesID }) else { return nil }
        return Self.vacancies(in: entry)
    }

    var body: some View {
        GeometryReader { proxy in
            let fullHeight = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            let sheetHeight = (fullHeight * 0.612).rounded()
            let expandedHeight = fullHeight - proxy.safeAreaInsets.top - 24
            let showsSheet = openVacancies != nil

            ZStack(alignment: .bottom) {
                if let voice, isTalking {
                    AylaOrbTrack(motion: orbMotion, stage: stageSlot, bar: barSlot) { frame, _ in
                        AylaAmbientField(
                            mode: orbMode(voice.state),
                            meter: voice.meter,
                            orbFrame: frame,
                            quietFrame: orbMotion.isLow || !showsVoiceText ? .null : captionFrame,
                            revealedAt: fieldRevealedAt
                        )
                    }
                    .ignoresSafeArea()
                }

                content(
                    height: proxy.size.height,
                    bottomMargin: showsSheet ? sheetHeight - proxy.safeAreaInsets.bottom : bottomBarHeight + bottomGap + offlineNoticeHeight
                )

                if isAttachMenuOpen {
                    Color.clear
                        .contentShape(.rect)
                        .ignoresSafeArea()
                        .onTapGesture { isAttachMenuOpen = false }
                        .accessibilityHidden(true)
                }

                if showsSheet, let vacancies = openVacancies {
                    AylaBottomSheet(
                        title: "Vacatures sluiten",
                        height: sheetHeight,
                        expandedHeight: expandedHeight,
                        bottomInset: bottomBarHeight + proxy.safeAreaInsets.bottom + 16,
                        onClose: closeVacancies
                    ) {
                        VacancyList(vacancies: vacancies)
                            .frame(maxWidth: 600)
                            .frame(maxWidth: .infinity)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }

                if let waveStartedAt {
                    let place = proxy.frame(in: .global).origin
                    let origin = waveFromOrb && !orbFrame.isEmpty
                        ? CGPoint(x: orbFrame.midX - place.x, y: orbFrame.midY - place.y)
                        : CGPoint(x: proxy.size.width / 2, y: proxy.size.height - bottomBarHeight / 2)
                    AylaSuccessWave(startedAt: waveStartedAt, origin: origin)
                        .transition(.opacity)
                }

                bottomBar(placeholder: placeholderColor(sheetOpen: showsSheet), isOverPanel: showsSheet)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bottomBarHeight = $0 }
                    // Above the bar, so the bar itself never changes height and nothing jumps.
                    .overlay(alignment: .top) { aboveBottomBar(isOverPanel: showsSheet) }
            }
            .overlay { orbLayer }
        }
        .background { background.ignoresSafeArea() }
        .animation(.easeInOut(duration: 0.35), value: model.phase)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.15), value: isVoiceActive)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.12), value: model.entries.isEmpty)
        .animation(.easeOut(duration: 0.2), value: dictation.isListening)
        .animation(.easeOut(duration: 0.4), value: isOutroRunning)
        .sensoryFeedback(trigger: dictation.isListening) { _, isListening in isListening ? .start : .stop }
        .animation(.spring(duration: 0.4), value: openVacanciesID)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4), value: shelf)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.18), value: isAttachMenuOpen)
        .toolbar { toolbar }
        .cameraControlMenus("chat", menus: cameraMenus, press: isTalking ? { stopVoice() } : nil)
        .photosPicker(isPresented: $isChoosingPhotos, selection: $photoItems, maxSelectionCount: max(1, AylaAttachment.maxCount - model.attachments.count), matching: .images, preferredItemEncoding: .compatible)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            photoItems = []
            Task { await addPhotos(items) }
        }
        // The places from the start chips, as they are in the app: up from the bottom, pulled up to the full screen,
        // swiped away, with the chat still there behind them. The vault is the vault itself.
        .sheet(item: Binding(get: { shelf }, set: { if $0 == nil { closeShelf() } }), onDismiss: {
            afterShelf?()
            afterShelf = nil
        }) { shelf in
            Group {
                if shelf == .vault {
                    if let vault {
                        VaultScreen(onShowMenu: nil)
                            .environment(vault)
                            .environment(\.vaultButtonsInPage, toolbarIsBeside)
                            .environment(\.askAylaAbout) { item in
                                closeShelf()
                                model.ask(about: item)
                            }
                    }
                } else {
                    ScrollView {
                        AylaShelfContent(shelf: shelf) { _ in }
                            .padding(.horizontal, 24)
                            .padding(.top, 28)
                            .padding(.bottom, 24)
                    }
                    .background(Color.white.ignoresSafeArea(edges: .bottom))
                }
            }
            .presentationDetents([.fraction(0.62), .large], selection: $vaultDetent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
            .paveSheet(background: shelf == .vault ? .canvas : .white, clipsToColumn: shelf != .vault)
        }
        .photosPicker(
            isPresented: Binding(get: { photosForItemID != nil }, set: { if !$0 { itemPhotosClosed() } }),
            selection: $itemPhotoItems,
            maxSelectionCount: itemPhotosRoom,
            matching: .images,
            preferredItemEncoding: .compatible
        )
        .onChange(of: itemPhotoItems) { _, items in
            guard !items.isEmpty, let itemID = photoTargetID else { return }
            itemPhotoItems = []
            Task { await addItemPhotos(items, to: itemID) }
        }
        .sheet(item: $confirmationItem) { item in
            VaultRequestConfirmationSheet(item: item, documentCount: vault?.documents(of: item).count ?? 0)
                .paveSheet()
        }
        .sheet(isPresented: $picksVaultItem) {
            if let vault {
                AylaVaultSelectionSheet { items in model.attach(items) }
                    .environment(vault)
                    .paveSheet(background: .white)
            }
        }
        .task {
            guard let vault else { return }
            model.analyzeEvidence = { uploads in
                let reading = await VaultEvidenceReader.read(uploads)
                return (try await vault.proposeEvidence(from: reading.documents), reading.pictures)
            }
        }
        .sheet(isPresented: Binding(get: { addEvidence != nil }, set: { if !$0 { addEvidenceClosed() } })) {
            if let addEvidence {
                VaultAddEvidenceSheet(flow: addEvidence)
                    .paveSheet()
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onChange(of: model.entries.last?.id) {
            guard !isVoiceActive, let last = model.entries.last, last.role == .ayla, !Self.vacancies(in: last).isEmpty else { return }
            closeShelf()
            openVacanciesID = last.id
        }
        .onChange(of: model.conversationID) { old, _ in
            shelf = nil
            dictation.stop()
            readAloud.stop()
            isAttachMenuOpen = false
            // The first spoken question gives the conversation its id; only another conversation ends the voice.
            if old != nil { voice?.stop() }
        }
        // Only when the app really leaves: the permission prompts at the first start make it briefly inactive.
        .onChange(of: headMode, initial: true) { _, mode in
            if mode.yesNo || mode.browse {
                headGestures.start(followsTurns: mode.browse, onGesture: answerByHead)
            } else {
                headGestures.stop()
            }
        }
        .onDisappear { headGestures.stop() }
        .onChange(of: model.lastAylaEntryID) { vacancyIndex = 0 }
        // A spoken conversation goes on in the background, with the Lock Screen and the Dynamic Island showing it,
        // so you can keep talking with the phone in your pocket.
        .transform(voiceReactions)
        .transform(prompts)
        .onDisappear {
            voice?.stop()
            readAloud.stop()
        }
        .sheet(item: $selectingText) { ChatTextSelection(text: $0.text) }
        // Handoff to your other devices, with only a general title: the chat's own title stays private.
        .userActivity(AylaHandoff.activityType, isActive: model.conversationID != nil && !isVoiceActive) { activity in
            guard let id = model.conversationID else { return }
            activity.title = "Gesprek met Ayla"
            activity.isEligibleForHandoff = true
            activity.isEligibleForSearch = false
            activity.isEligibleForPrediction = false
            activity.addUserInfoEntries(from: [AylaHandoff.idKey: id])
        }
        .fullScreenCover(isPresented: $isScanning) {
            DocumentScanner { pages in
                isScanning = false
                addScan(pages)
            } onCancel: {
                isScanning = false
            }
            .ignoresSafeArea()
        }
        // Drag a pdf, photo or text file in from Files, Photos or Safari (iPad, the open iPhone Duo).
        .onDrop(of: AttachmentReader.contentTypes, isTargeted: $isDropTargeted) { providers in
            guard model.isAvailable, !isTalking else { return false }
            addProviders(providers)
            return true
        }
        .overlay {
            if isDropTargeted {
                AylaDropTarget()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
        .sheet(isPresented: $showsMemory) {
            NavigationStack {
                AylaMemoryScreen { showsMemory = false }
            }
        }
        .onChange(of: model.wantsToTalk, initial: true) { _, wants in
            guard wants else { return }
            model.wantsToTalk = false
            guard voiceAction != nil, !isTalking, connection.isOnline else { return }
            // A moment after the chat appears, so you see the orb come out of the button.
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                if !isTalking { startVoice() }
            }
        }
    }

    /// The button back to the newest message, and the line that says you are offline.
    private func aboveBottomBar(isOverPanel: Bool) -> some View {
        VStack(spacing: 10) {
            if !isTalking, !isOverPanel, headAnswer != nil || (asksYesNoByHead && headGestures.isReceiving) {
                AylaHeadHint(text: headAnswer.map { AylaMessages.yesNoAnswer($0, byHead: answeredByHead) } ?? AylaMessages.headHint, isAnswer: headAnswer != nil)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            if isAwayFromBottom, !isTalking, !isOverPanel, !model.entries.isEmpty {
                ChatScrollDownButton { scrollToBottom() }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            if !connection.isOnline, !isTalking, model.phase == .idle {
                PaveOfflineNotice(message: AylaMessages.offline)
                    .padding(.horizontal, 24)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height + 10 } action: { offlineNoticeHeight = $0 }
                    .onDisappear { offlineNoticeHeight = 0 }
                    .transition(.opacity)
            }
        }
        .alignmentGuide(.top) { $0[.bottom] + 10 }
        .animation(.easeOut(duration: 0.2), value: isAwayFromBottom)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: headAnswer)
        .animation(.easeOut(duration: 0.2), value: headGestures.isReceiving)
        .animation(.easeOut(duration: 0.25), value: connection.isOnline)
    }

    /// The alerts and the file picker. Apart from `body`, so the compiler can keep up.
    private func prompts(_ content: some View) -> some View {
        content
            .alert("Praten met Ayla", isPresented: voiceProblemBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(voiceProblem == .notAllowed ? AylaMessages.voiceNotAllowed : AylaMessages.speechUnavailable)
            }
            .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: AttachmentReader.contentTypes, allowsMultipleSelection: true) { result in
                addFiles(result)
            }
            .alert("Inspreken", isPresented: dictationProblemBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(dictation.problem == .notAllowed ? AylaMessages.speechNotAllowed : AylaMessages.speechUnavailable)
            }
            .alert("Bestand toevoegen", isPresented: fileProblemBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(fileProblem ?? "")
            }
    }

    // MARK: Header

    /// Standard toolbar buttons with the Figma icons. iOS draws them as glass circles, and on iPhone Duo
    /// it moves them into the bar along the side, under the status bar.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if let onShowMenu {
            ToolbarItem(placement: .topBarLeading) {
                MainMenuToolbarButton { closingShelf(then: onShowMenu) }
            }
        }
        ToolbarItem(placement: .principal) {
            PaveTitle("Ayla")
                .offset(y: Self.toolbarOffset)
        }
        // With the menu on screen (iPad, open iPhone Duo) the chat button sits at the top left, next to the menu,
        // instead of on the right where the open iPhone Duo puts it right against the status bar.
        if !hidesScreenButtons {
            ToolbarItem(placement: onShowMenu == nil ? .topBarLeading : .topBarTrailing) {
                Button {
                    PaveHaptics.tap(.light)
                    closingShelf(then: onShowChats)
                } label: {
                    Image(.iconChat)
                        .paveToolbarHitArea()
                }
                .accessibilityLabel("Chats")
            }
        }
    }

    // MARK: Content

    /// While talking, the conversation stays where it is and shows once the orb has come down (`orbMotion`), with the
    /// full-screen caption on top of it, which fades as the orb leaves the middle.
    private func content(height: CGFloat, bottomMargin: CGFloat) -> some View {
        ZStack {
            conversation(height: height, bottomMargin: bottomMargin)
                // Tapping next to the text field closes the keyboard, as in Messages and ChatGPT. Alongside the
                // buttons in the conversation, so a starter or a card still works with the same tap.
                .contentShape(.rect)
                .simultaneousGesture(TapGesture().onEnded { isComposerFocused = false }, isEnabled: isComposerFocused)
                // Mostly in the second half, so it does not crowd the orb on its way down.
                // As in ChatGPT: gone at once when the orb jumps up, and only back once it has landed below.
                .opacity(showsConversation ? 1 : 0)
                .animation(showsConversation ? .easeOut(duration: 0.3) : .easeOut(duration: 0.08), value: showsConversation)
                .allowsHitTesting(!isTalking || orbMotion.isLow)

            if let voice, isTalking {
                // The line follows Ayla sentence by sentence.
                TimelineView(.periodic(from: .now, by: showsVoiceText ? 0.25 : 3600)) { context in
                    AylaVoiceStage(
                        caption: stageCaption(voice, at: context.date),
                        motion: orbMotion,
                        showsText: showsVoiceText,
                        onOrbFrame: { place(.center, at: $0) },
                        onCaptionFrame: { captionFrame = $0 },
                        card: vacancyCard
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // The whole middle can be dragged, not only the orb itself.
                .contentShape(.rect)
                .gesture(orbDragGesture, isEnabled: canDragOrb)
                .allowsHitTesting(!orbMotion.isLow)
                // Down to the voice bar: the room for the small orb is only for when it is small.
                .padding(.bottom, voiceBarHeight + bottomGap)
                .transition(.opacity)
                .accessibilityHidden(orbMotion.isLow)
            }
        }
    }

    @ViewBuilder
    private func conversation(height: CGFloat, bottomMargin: CGFloat) -> some View {
        if model.entries.isEmpty, !model.isLoadingConversation {
            ScrollView {
                AylaWelcome(firstName: model.firstName, isAvailable: model.isAvailable, isTyping: model.isGreetingReady, onStarter: openShelf)
                    .padding(.top, (height * 0.174).rounded())
                    .frame(maxWidth: .infinity)
                    // The orb falls apart right here during the outro; the welcome returns once its blocks are back in the button.
                    // It also waits for the name, so the title does not jump when the name comes in, and it stays out of
                    // the way while you talk: a spoken conversation starts clean.
                    .opacity(isOutroRunning || !model.isGreetingReady || isTalking ? 0 : 1)
                    .animation(.easeOut(duration: 0.3), value: model.isGreetingReady)
                    .animation(.easeOut(duration: 0.25), value: isTalking)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: bottomMargin) }
        } else {
            transcript(bottomMargin: bottomMargin)
        }
    }

    private func transcript(bottomMargin: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Each row gets its spacing up front: a row that is on its way out (a new conversation) must not look
                // up its neighbour in the list, which may already be empty.
                ForEach(Self.rows(model.entries), id: \.entry.id) { row in
                    VStack(spacing: 0) {
                        if let time = row.time {
                            Text(time)
                                .textStyle(.caption)
                                .foregroundStyle(Color.inkMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 12)
                        }
                        entryView(row.entry)
                    }
                    .padding(.top, row.spacing)
                }
            }
            .padding(.leading, 32)
            .padding(.trailing, 33)
            .padding(.top, 32)
            .padding(.bottom, bottomGap)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        // The top margin is part of the content: iOS 26.0 counts scroll content margins twice
        // when it aligns a short conversation to the bottom.
        // The text field is a bar, so iOS fades the conversation softly under it and under the header.
        .safeAreaBar(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: max(0, bottomMargin - bottomGap))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .alignment)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .scrollDismissesKeyboard(.interactively)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentSize.height - geometry.visibleRect.maxY > 160
        } action: { _, isAway in
            isAwayFromBottom = isAway
        }
        .onChange(of: model.entries.count) { scrollToBottom() }
        .onChange(of: openVacanciesID) { scrollToBottom() }
        .onChange(of: bottomBarHeight) { scrollToBottom() }
        // The keyboard is still on its way down when the question is sent, so the first scroll can land too high and
        // leave the last message under the "Ayla denkt na" blocks: once more when that has settled.
        .onChange(of: model.phase) { _, phase in
            guard phase == .thinking else { return }
            scrollToBottom()
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                if model.phase == .thinking { scrollToBottom() }
            }
        }
        .onChange(of: offlineNoticeHeight) { if !isAwayFromBottom { scrollToBottom() } }
    }

    @ViewBuilder
    private func entryView(_ entry: AylaChatModel.Entry) -> some View {
        switch entry.role {
        case .user:
            VStack(alignment: .trailing, spacing: 6) {
                if !entry.attachments.isEmpty {
                    FlowLayout(spacing: 5, alignment: .trailing) {
                        ForEach(entry.attachments, id: \.self) { name in
                            AylaAttachmentChip(name: name, isCompact: true)
                        }
                    }
                }
                ChatBubble(text: entry.text, speaker: .user, actions: actions(for: entry))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        case .ayla:
            VStack(alignment: .leading, spacing: 12) {
                ChatBubble(
                    text: entry.text,
                    speaker: .ayla(showsMark: entry.id == model.lastAylaEntryID && !isFailed),
                    actions: actions(for: entry)
                )
                if let question = model.question(for: entry), !question.text.isEmpty, !AylaVaultOffer.isAlreadyAsked(question.text, in: entry.text), !model.questionIsOnCard(for: entry) {
                    ChatBubble(text: question.text, speaker: .ayla(showsMark: false))
                }
                // Evidence built up together in the chat: what Ayla has so far, and the way into the vault with it.
                if let reply = entry.reply, let item = reply.proposedAction?.vaultItem, reply.accessRequest == nil {
                    AylaEvidenceConceptCard(
                        item: item,
                        analysis: model.analysis(for: reply),
                        files: model.analysis(for: reply)?.uploads ?? model.uploads(for: item),
                        excluded: excludedFiles[reply.id] ?? [],
                        isLast: entry.id == model.lastAylaEntryID,
                        isAdded: model.addedReplies.contains(reply.id),
                        onToggleFile: { file in
                            PaveHaptics.selection()
                            if excludedFiles[reply.id, default: []].remove(file.checksum) == nil { excludedFiles[reply.id, default: []].insert(file.checksum) }
                        },
                        onRequestConfirmation: model.addedItemIDs[reply.id].flatMap { id in vault?.items.first { $0.id == id } }.map { saved in { confirmationItem = saved } }
                    ) {
                        openProposedEvidence(from: reply)
                    }
                    .padding(.top, 3)
                }
                // Adding evidence opens from Ja under the question; the vault, an item in it and the settings open from a
                // button, like on the web; other parts of PAVE are not in the app yet.
                if let navigation = entry.reply?.navigation, navigation.screen != .chat, navigation.screen != .addEvidence {
                    if let openFromAyla, AylaNavigationButton.canOpen(navigation.screen) {
                        AylaNavigationButton(navigation: navigation, itemTitle: itemTitle(navigation.itemId)) {
                            openFromAyla(navigation)
                        }
                    } else {
                        Text("Dit onderdeel komt later in de app.")
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .padding(.leading, 4)
                    }
                }
                if let reply = entry.reply, !reply.usedData.isEmpty {
                    AylaUsedVault(categories: reply.usedData)
                        .padding(.top, -4)
                }
                if let used = entry.reply?.usedMemories, !used.isEmpty {
                    AylaUsedMemories(notes: used) { showsMemory = true }
                        .padding(.top, -4)
                }
                if let reply = entry.reply, !reply.suggestedMemories.isEmpty {
                    memoryCard(for: reply, isLast: entry.id == model.lastAylaEntryID)
                }
                let vacancies = Self.vacancies(in: entry)
                if !vacancies.isEmpty {
                    ChatAttachmentCard(
                        icon: .iconBriefcase,
                        title: vacancies.count == 1 ? "1 vacature gevonden" : "\(vacancies.count) vacatures gevonden"
                    ) {
                        openVacanciesID = entry.id
                    }
                    .padding(.top, 3)
                }
            }
        }
    }

    /// Ayla suggests remembering something: you decide, on the newest answer. On older answers only a kept note
    /// shows, so a question you passed by does not keep coming back.
    @ViewBuilder
    private func memoryCard(for reply: AylaReply, isLast: Bool) -> some View {
        let decision = memory.decision(for: reply)
        if decision == .saved || isLast {
            AylaMemoryCard(
                changes: memory.changes(in: reply),
                didUpdate: reply.suggestedMemories.contains { $0.replaces != nil },
                decision: decision,
                onConfirm: { memory.accept($0, replyID: reply.id, conversationID: model.conversationID) },
                onDecline: { memory.decline(replyID: reply.id) },
                onShowMemory: { showsMemory = true }
            )
            .padding(.top, 3)
            .transition(.opacity)
        }
    }

    /// What you can do with a message when you press and hold it, as in ChatGPT and Messages.
    private func actions(for entry: AylaChatModel.Entry) -> [ChatBubble.Action] {
        var actions: [ChatBubble.Action] = [
            .init(title: "Kopiëren", icon: .iconDocumentDuplicate) { UIPasteboard.general.string = entry.text },
            .init(title: "Tekst selecteren", icon: .iconDocumentText) {
                selectingText = SelectableText(id: entry.id, text: entry.text)
            },
        ]
        switch entry.role {
        case .ayla:
            let isReading = readAloud.playingID == entry.id
            actions.append(.init(title: isReading ? "Stop met voorlezen" : "Voorlezen", icon: isReading ? .iconStop : .iconSpeakerWave) {
                readAloud.toggle(id: entry.id, text: entry.text, service: model.service)
            })
            if entry.id == model.entries.last?.id, model.canRedoLastTurn, connection.isOnline, !isVoiceActive {
                actions.append(.init(title: "Nieuw antwoord", icon: .iconArrowPath) {
                    readAloud.stop()
                    model.askAgain()
                })
            }
        case .user:
            if entry.id == model.lastQuestionID, connection.isOnline, !isVoiceActive {
                actions.append(.init(title: "Aanpassen", icon: .iconPencil) {
                    readAloud.stop()
                    model.editLastQuestion()
                    isComposerFocused = true
                })
            }
        }
        return actions
    }

    /// What the spoken conversation reacts to: the orb's haptics, the orb changing place, and the conversation
    /// ending by itself. Apart from `body`, so the compiler can keep up.
    private func voiceReactions(_ content: some View) -> some View {
        content
            // Your message is sent: a firm tap. Ayla's answer comes in: a soft one. Opening an old chat is neither.
            .onChange(of: model.entries.count) { old, new in
                guard new == old + 1, let last = model.entries.last, !isVoiceActive else { return }
                PaveHaptics.tap(last.role == .user ? .medium : .soft)
            }
            // While talking every turn is felt, so you know without looking: your question goes (firm), Ayla starts
            // talking (soft), and it is your turn again (light).
            .onChange(of: voice?.state) { old, new in
                switch (old, new) {
                case (.listening, .thinking): PaveHaptics.tap(.medium)
                case (.thinking, .speaking): PaveHaptics.tap(.soft)
                case (.speaking, .listening): PaveHaptics.tap(.light)
                default: break
                }
            }
            .onChange(of: model.phase) { _, phase in
                if case .failed = phase { PaveHaptics.error() }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: isOrbReadyToSwitch) { _, isPast in isPast }
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.9), trigger: orbSnaps)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: orbLandings)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.4), trigger: orbSpringBacks)
            // Large to small with the first message on iPad, or the accessibility action: the orb glides there.
            .onChange(of: wantsVoiceStage) { _, wantsStage in
                guard !orbMotion.isDragging else { return }
                let target: CGFloat = wantsStage ? 0 : 1
                guard isTalking else {
                    orbMotion.jump(to: target)
                    return
                }
                // Already on its way there after a drag.
                guard orbMotion.place != target else { return }
                orbMotion.glide(to: target, reduceMotion: reduceMotion) { orbLandings += 1 }
            }
            .onChange(of: isHoldingOrb) { _, isHolding in
                guard !isHolding, orbMotion.isDragging else { return }
                isOrbReadyToSwitch = false
                orbMotion.letGo(velocity: 0, reduceMotion: reduceMotion)
            }
            .onChange(of: isVoiceActive) { _, isActive in
                guard !isActive else { return }
                // Stopped by itself (another conversation, the app went away, Ayla could not answer).
                if isTalking { withAnimation(voiceAnimation) { isTalking = false } }
                prefersVoiceStage = nil
                fieldRevealedAt = nil
                isOrbHidden = false
                if case .intro = introPhase { introPhase = nil }
            }
    }

    // MARK: Bottom

    /// Starting or stopping a spoken conversation does not swap the bars: the text field shrinks into the voice
    /// bar's field (and grows back), and the round buttons slide out of it.
    private func bottomBar(placeholder: Color, isOverPanel: Bool) -> some View {
        VStack(spacing: 0) {
            if let voice, isTalking {
                voiceControls(voice)
            } else {
                textControls(placeholder: placeholder, isOverPanel: isOverPanel)
                    // Gone quickly, so it does not linger as a ghost over the field that takes its place.
                    .transition(.opacity.animation(.easeOut(duration: 0.12)))
            }
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    /// The layer above everything with Ayla's orb, which moves freely between its places, and the intro and outro.
    private var orbLayer: some View {
        ZStack {
            Color.clear
            if let voice, isTalking {
                AylaOrbTrack(motion: orbMotion, stage: stageSlot, bar: barSlot) { frame, scale in
                    if !frame.isEmpty {
                        let center = CGPoint(x: frame.midX - layerOrigin.x, y: frame.midY - layerOrigin.y)
                        orb(voice, at: CGPoint(x: frame.midX, y: frame.midY))
                            .frame(width: frame.width, height: frame.height)
                            .scaleEffect(scale)
                            .position(center)
                    }
                }
                .transition(.opacity)
            }
            if let introPhase {
                AylaVoiceIntro(
                    phase: introPhase,
                    buttonCenter: CGPoint(x: voiceButtonFrame.midX - layerOrigin.x, y: voiceButtonFrame.midY - layerOrigin.y),
                    orbFrame: introOrbFrame(for: introPhase).offsetBy(dx: -layerOrigin.x, dy: -layerOrigin.y)
                )
            }
        }
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { layerOrigin = $0 }
    }

    /// Ayla's orb: tap it to send now or to interrupt her, drag it between full screen and the conversation.
    private func orb(_ voice: AylaVoiceSession, at position: CGPoint) -> some View {
        AylaPixelOrb(
            mode: orbMode(voice.state),
            meter: voice.meter,
            icon: { voice.icon(at: $0) },
            position: position
        )
            .opacity(isOrbHidden ? 0 : 1)
            // Fades in while the intro's blocks fade out.
            .animation(isOrbHidden ? nil : .easeOut(duration: 0.3), value: isOrbHidden)
            .contentShape(.circle)
            .onTapGesture { voice.tapOrb() }
            .simultaneousGesture(orbDragGesture, isEnabled: canDragOrb)
            .accessibilityElement()
            .accessibilityLabel("Ayla")
            .accessibilityHint(voice.state == .speaking ? "Tik om Ayla te onderbreken" : "Tik om je vraag nu te versturen")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { voice.tapOrb() }
            .accessibilityActions {
                if canDragOrb {
                    let isLarge = !orbMotion.isLow
                    Button(isLarge ? "Gesprek tonen" : "Volledig scherm") { prefersVoiceStage = !isLarge }
                }
            }
    }

    /// The place of the small orb, and the voice bar in the place of the text field. The place is always there, also
    /// while the orb is large, so nothing moves when the orb comes down.
    private func voiceControls(_ voice: AylaVoiceSession) -> some View {
        VStack(spacing: 12) {
            // Room above it so the conversation does not crowd it, as in ChatGPT.
            Color.clear
                .frame(width: 116, height: 116)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { place(.bar, at: $0) }
                // A wider strip than the orb, so it is easy to take hold of.
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
                .gesture(orbDragGesture, isEnabled: canDragOrb)
                .padding(.top, 36)
                .padding(.bottom, 8)
                .accessibilityHidden(true)

            AylaVoiceBar(
                text: $model.draft,
                isMuted: voice.isMuted,
                isFocused: $isComposerFocused,
                onAdd: toggleAttachMenu,
                onSend: {
                    isComposerFocused = false
                    voice.send(typed: model.draft)
                },
                onMute: voice.toggleMute,
                onStop: stopVoice,
                morph: barSpace
            )
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { voiceBarHeight = $0 }
            // A question for Ja or Nee: the buttons take the place of the bar, for when you cannot talk right now. The
            // bar stays underneath and keeps its height, so nothing moves.
            .opacity(voiceChoices.isEmpty ? 1 : 0)
            .allowsHitTesting(voiceChoices.isEmpty)
            .accessibilityHidden(!voiceChoices.isEmpty)
            .overlay(alignment: .bottom) {
                if !voiceChoices.isEmpty {
                    AylaChoiceBar(
                        choices: voiceChoices,
                        isAboutVault: model.pendingOffersEvidence,
                        picked: headAnswer.flatMap { isYes in
                            voiceChoices.first { isYes ? AylaVaultOffer.isYes($0.label) : AylaVaultOffer.isNo($0.label) }?.id
                        } ?? buttonAnswerID
                    ) { choice in
                        chooseWhileTalking(choice)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.15), value: voiceChoices.isEmpty)
            .overlay(alignment: .bottomLeading) {
                if isAttachMenuOpen {
                    attachMenu
                            .accessibilityAction(.escape) { isAttachMenuOpen = false }
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.3, anchor: .bottomLeading).combined(with: .opacity))
                }
            }
            .padding(.leading, 24)
            .padding(.trailing, 24)
        }
        // Only the field and the round buttons move in; the rest fades out when the conversation stops.
        .transition(.asymmetric(insertion: .identity, removal: .opacity))
    }

    /// The one line under the full-screen orb: what you say, Ayla's answer, or a hint while nothing is happening.
    private func stageCaption(_ voice: AylaVoiceSession, at date: Date) -> AylaVoiceCaption {
        if let headAnswer { return .init(text: AylaMessages.yesNoAnswer(headAnswer, byHead: answeredByHead), kind: .heard) }
        if !voice.heard.isEmpty { return .init(text: voice.heard, kind: .heard) }
        if let sentence = voice.spokenSentence(at: date) {
            return .init(text: sentence, kind: .answer)
        }
        if voice.state == .speaking, let answer = model.entries.last(where: { $0.role == .ayla })?.text, !answer.isEmpty {
            return .init(text: answer, kind: .answer)
        }
        if voice.state == .listening, asksYesNoByHead, headGestures.isReceiving {
            return .init(text: AylaMessages.headHintVoice, kind: .status)
        }
        if voice.state == .listening, !model.entries.isEmpty, !voice.isMuted {
            return .init(text: "Ayla luistert…", kind: .status)
        }
        return .init(text: voice.state == .thinking ? "Ayla denkt na…" : voiceHint(voice), kind: .status)
    }

    private func voiceHint(_ voice: AylaVoiceSession) -> String {
        if voice.isMuted { return "Je microfoon staat uit. Tik op de microfoon om verder te praten." }
        if voice.state == .starting { return "Microfoon aanzetten…" }
        return "Ik luister. Vraag me bijvoorbeeld welke banen bij je passen of hoe je je cv sterker maakt."
    }

    /// The orb the intro flows into, or (for the outro) where it was when the conversation stopped.
    private func introOrbFrame(for phase: AylaVoiceIntro.Phase) -> CGRect {
        if case .outro = phase { return outroOrbFrame }
        return orbFrame
    }

    private func orbMode(_ state: AylaVoiceSession.State) -> AylaPixelOrb.Mode {
        switch state {
        case .off, .starting: .idle
        case .listening: .listening
        case .thinking: .thinking
        case .speaking: .speaking
        }
    }

    @ViewBuilder
    private func textControls(placeholder: Color, isOverPanel: Bool) -> some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .thinking:
                AylaStatusIndicator(state: .thinking, message: "Ayla denkt na…")
                    .padding(.bottom, 41)
                    .transition(.opacity)
            case .failed(let message):
                AylaStatusIndicator(state: .failed, message: message)
                    .padding(.horizontal, 32)
                    .padding(.bottom, model.pendingQuestion == nil ? 41 : 35.7)
                    .transition(.opacity)
            case .idle, .writing:
                EmptyView()
            }

            if dictation.isListening, let startedAt = dictation.startedAt {
                AylaDictationBar(text: model.draft, meter: dictation.meter, startedAt: startedAt, onCancel: cancelDictation, onDone: finishDictation)
                    .padding(.leading, 33)
                    .padding(.trailing, 31)
                    .transition(.opacity)
            } else if let question = model.pendingQuestion, question.choices.count >= 2, !model.pendingQuestionIsOnCard {
                AylaChoiceBar(
                    choices: question.choices.map { AylaChoice(id: $0.id, label: $0.label) },
                    isAboutVault: model.pendingOffersEvidence,
                    picked: headAnswer.flatMap { isYes in
                        question.choices.first { isYes ? AylaVaultOffer.isYes($0.label) : AylaVaultOffer.isNo($0.label) }?.id
                    } ?? buttonAnswerID
                ) { choice in
                    choose(choice.label)
                }
                .padding(.leading, 21)
                .padding(.trailing, 22)
                .padding(.bottom, -11)
            } else {
                if let title = model.contextTitle, !isVoiceActive {
                    AylaContextChip(title: title) { model.clearContext() }
                        .padding(.leading, 33)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }
                AylaComposer(
                    text: $model.draft,
                    attachments: model.attachments,
                    isEnabled: model.isAvailable,
                    isOnline: connection.isOnline,
                    isAnswering: model.isAnswering,
                    onStop: {
                        PaveHaptics.tap(.medium)
                        model.stopAnswer()
                    },
                    isListening: dictation.isListening,
                    placeholderColor: placeholder,
                    isOverPanel: isOverPanel,
                    isFocused: $isComposerFocused,
                    onAdd: toggleAttachMenu,
                    onRemoveAttachment: model.removeAttachment,
                    onMicrophone: toggleDictation,
                    onSend: { send() },
                    onVoice: voiceAction,
                    onVoiceButtonFrame: { voiceButtonFrame = $0 },
                    morph: barSpace
                )
                .overlay(alignment: .bottomLeading) {
                    if isAttachMenuOpen {
                        attachMenu
                            .accessibilityAction(.escape) { isAttachMenuOpen = false }
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.3, anchor: .bottomLeading).combined(with: .opacity))
                    }
                }
                .padding(.leading, 33)
                .padding(.trailing, 31)
            }
        }
    }

    /// Space between the last message and what is below it, as in Figma.
    /// Room under the conversation; while typing it grows for the "Ayla denkt na" line under the last message.
    /// While talking there is no such line and the orb shows it, so the room stays the same and nothing moves.
    private var bottomGap: CGFloat {
        if isVoiceActive { return 12 }
        return switch model.phase {
        case .idle, .writing: 12
        case .thinking: 47
        case .failed: 41
        }
    }

    private func placeholderColor(sheetOpen: Bool) -> Color {
        if sheetOpen { return Color.black.opacity(0.41) }
        return model.phase == .idle || model.phase == .writing ? Color.inkMuted.opacity(0.41) : Color.white.opacity(0.41)
    }

    @ViewBuilder
    /// While talking, the orb and its field already show that Ayla is thinking, so the glow at the bottom stays away.
    private var background: some View {
        switch isVoiceActive ? .idle : model.phase {
        case .idle, .writing:
            Color.canvas
        case .thinking:
            LinearGradient(stops: [.init(color: .canvas, location: 0.658), .init(color: .paveThinkingGlow, location: 1)], startPoint: .top, endPoint: .bottom)
        case .failed:
            LinearGradient(stops: [.init(color: .canvas, location: 0.658), .init(color: .errorGlow, location: 1)], startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: Actions

    private var isFailed: Bool {
        if case .failed = model.phase { true } else { false }
    }

    private var dictationProblemBinding: Binding<Bool> {
        Binding(get: { dictation.problem != nil }, set: { if !$0 { dictation.problem = nil } })
    }

    /// Sending closes the keyboard, so Ayla's answer has the room, as in Messages.
    private func itemTitle(_ id: String?) -> String? {
        guard let id else { return nil }
        return vault?.items.first { $0.id == id }?.title
    }

    /// Ja to "Wil je iets toevoegen?" opens adding evidence, filled with Ayla's proposal and skills; the answer still goes
    /// to Ayla, as on the web.
    private func choose(_ label: String) {
        if AylaVaultOffer.isYes(label), handleYes(saying: label) { return }
        if model.pendingOffersEvidence, AylaVaultOffer.isYes(label) {
            openProposedEvidence(from: model.lastReply)
        }
        send(label)
    }

    /// Adding evidence as Ayla proposed it, with the files she said belong to it. A spoken conversation stops: the form
    /// is something to look at.
    private func openProposedEvidence(from reply: AylaReply?) {
        guard let vault else { return }
        let analysis = model.analysis(for: reply)
        let excluded = reply.flatMap { excludedFiles[$0.id] } ?? []
        let documents = (analysis?.uploads ?? model.uploads(for: reply?.proposedAction?.vaultItem)).filter { !excluded.contains($0.checksum) }
        if isTalking { stopVoice() }
        addingFromReplyID = reply?.id
        Task {
            if vault.state != .ready { await vault.load() }
            addEvidence = .proposed(by: reply, vault: vault, documents: documents, analysis: excluded.isEmpty ? analysis : nil)
        }
    }

    /// The form closed: an item that was saved is marked on its card, and Ayla hears it.
    private func addEvidenceClosed() {
        defer { addEvidence = nil; addingFromReplyID = nil }
        guard let flow = addEvidence, flow.savedItemID != nil, let replyID = addingFromReplyID else { return }
        model.markAdded(replyID: replyID, itemID: flow.savedItemID, title: flow.draft.title, uploads: flow.documents)
        startWave()
    }

    private func startWave(fromOrb: Bool = false) {
        let started = Date()
        waveFromOrb = fromOrb
        waveStartedAt = started
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if waveStartedAt == started { waveStartedAt = nil }
        }
    }

    /// A question for Ja or Nee is open, so a nod or a head shake answers it: in the chat, or while talking once Ayla
    /// has asked it and you have not started to answer in words.
    private var asksYesNoByHead: Bool {
        guard model.pendingYesNo, addEvidence == nil, shelf == nil, !isSavingForUser else { return false }
        // As soon as Ja and Nee show, also while Ayla is still saying the question.
        if let voice, isTalking { return (voice.state == .listening || voice.state == .speaking) && voice.heard.isEmpty }
        return !dictation.isListening
    }

    /// A nod is Ja, a head shake Nee: you feel it, the answer lights up and the line above says what was understood,
    /// a moment before it is sent, as if it was tapped or said.
    private func answerByHead(_ gesture: AylaHeadGesture) {
        if browsesByHead, !asksYesNoByHead {
            switch gesture {
            case .turnRight: moveVacancy(by: 1)
            case .turnLeft: moveVacancy(by: -1)
            case .nod: chooseVacancy()
            case .shake: break
            }
            return
        }
        guard gesture == .nod || gesture == .shake, asksYesNoByHead else { return }
        answerYesNo(gesture == .nod, byHead: true)
    }

    /// Ja or Nee, by a nod or a head shake, or by a tap on the buttons that take the place of the voice bar: you feel
    /// it, the answer lights up and the line says what was understood, then it is sent as if it was said.
    private func answerYesNo(_ isYes: Bool, byHead: Bool) {
        guard headAnswer == nil else { return }
        if isYes { PaveHaptics.success() } else { PaveHaptics.tap(.rigid) }
        answeredByHead = byHead
        headAnswer = isYes
        AccessibilityNotification.Announcement(AylaMessages.yesNoAnswer(isYes, byHead: byHead)).post()
        if let voice, isTalking {
            voice.play(isYes ? .tick : .no)
            voice.send(typed: isYes ? "Ja" : "Nee")
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                headAnswer = nil
            }
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            answer(isYes)
            try? await Task.sleep(for: .milliseconds(900))
            headAnswer = nil
        }
    }

    private func answer(_ isYes: Bool) {
        if let question = model.pendingQuestion, question.choices.count >= 2, !model.pendingQuestionIsOnCard,
           let choice = question.choices.first(where: { isYes ? AylaVaultOffer.isYes($0.label) : AylaVaultOffer.isNo($0.label) }) {
            choose(choice.label)
            return
        }
        let word = isYes ? "Ja" : "Nee"
        if isYes, handleYes(saying: word) { return }
        guard connection.isOnline else { return }
        model.send(word)
    }

    /// A Ja that PAVE carries out itself: putting Ayla's evidence in the vault, adding photos to what just went in,
    /// or asking someone to confirm it. True when it did; Ayla then hears what happened instead of the Ja.
    private func handleYes(saying words: String) -> Bool {
        if let reply = model.lastReply, model.pendingQuestionIsOnCard, !model.addedReplies.contains(reply.id), AylaVaultOffer.asksToPutInVault(reply) {
            addEvidenceForUser(from: reply, saying: words)
            return true
        }
        switch model.followUp {
        case .photos(let itemID):
            choosePhotos(for: itemID)
            return true
        case .confirmation(let itemID):
            guard let item = vault?.items.first(where: { $0.id == itemID }) else { return false }
            if isTalking { stopVoice() }
            confirmationItem = item
            return true
        case nil:
            break
        }
        // While talking, a Ja to adding evidence that is not complete yet opens the form; Ayla still hears the Ja.
        if isTalking, model.pendingOffersEvidence, let reply = model.lastReply, !model.addedReplies.contains(reply.id) {
            openProposedEvidence(from: reply)
        }
        return false
    }

    // MARK: Photos for an item that just went in

    private var itemPhotosRoom: Int {
        guard let photoTargetID, let item = vault?.items.first(where: { $0.id == photoTargetID }) else { return VaultAddEvidenceModel.maximumDocuments }
        return max(1, VaultAddEvidenceModel.maximumDocuments - (vault?.documents(of: item).count ?? 0))
    }

    /// While choosing, a spoken conversation stops listening, so the room around you is not sent as a question.
    private func choosePhotos(for itemID: String) {
        if let voice, isTalking, !voice.isMuted {
            voice.toggleMute()
            mutedForPhotos = true
        }
        photoTargetID = itemID
        photosForItemID = itemID
    }

    private func itemPhotosClosed() {
        photosForItemID = nil
        Task {
            // The chosen photos arrive just after the picker closes; without any, listening goes on.
            try? await Task.sleep(for: .milliseconds(300))
            if itemPhotoItems.isEmpty, photoTargetID != nil, !isAddingItemPhotos { listenAgainAfterPhotos() }
        }
    }

    private func listenAgainAfterPhotos() {
        photoTargetID = nil
        if mutedForPhotos, let voice, voice.isMuted { voice.toggleMute() }
        mutedForPhotos = false
    }

    private func addItemPhotos(_ items: [PhotosPickerItem], to itemID: String) async {
        guard let vault else { return }
        isAddingItemPhotos = true
        defer { isAddingItemPhotos = false }
        let day = Date.now.formatted(.iso8601.year().month().day())
        var added = 0
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self), let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.85) else { continue }
            let upload = VaultUpload(data: jpeg, fileName: "Foto \(day) \(added + 1).jpeg", mimeType: "image/jpeg")
            do {
                try await vault.attach(upload, to: itemID)
                added += 1
            } catch {
                break
            }
        }
        listenAgainAfterPhotos()
        guard added > 0 else {
            fileProblem = AylaMessages.fileUnreadable
            return
        }
        await vault.load()
        PaveHaptics.success()
        let title = vault.items.first { $0.id == itemID }?.title ?? "je bewijs"
        let notice = AylaMessages.photosAdded(added, to: title)
        if let voice, isTalking {
            voice.play(.saved)
            voice.send(typed: notice, checksYes: false)
        } else {
            model.send(notice)
        }
        startWave(fromOrb: isTalking)
    }

    // MARK: Vacancies while talking

    /// Vacancies in Ayla's newest answer, gone through one by one under the orb while talking.
    private var voiceVacancies: [Vacancy] {
        guard isTalking, let last = model.entries.last(where: { $0.role == .ayla }) else { return [] }
        return Self.vacancies(in: last)
    }

    /// Knopmodus in the chat: Ayla's answer choices, the vacancies under the orb, and your recent chats. A full press
    /// answers, asks about the vacancy or opens the chat; without a choice it ends a spoken conversation.
    private var cameraMenus: [CameraMenu] {
        var menus: [CameraMenu] = []
        let choices: [AylaChoice] = isTalking ? voiceChoices : (model.pendingQuestion?.choices.map { AylaChoice(id: $0.id, label: $0.label) } ?? [])
        if choices.count >= 2 {
            menus.append(CameraMenu(id: "answer", title: "Antwoord", symbol: "checkmark.bubble", items: choices.map(\.label), keys: choices.map(\.id), onPress: { index in
                guard choices.indices.contains(index) else { return }
                answerByButton(choices[index])
            }))
        }
        let vacancies = voiceVacancies
        if browsesByHead, !vacancies.isEmpty {
            menus.append(CameraMenu(
                id: "vacancies", title: "Vacature", symbol: "briefcase", items: vacancies.map(\.title), selected: vacancyIndex,
                onSwipe: { index in withAnimation(.snappy(duration: 0.25)) { vacancyIndex = index } },
                onPress: { index in
                    vacancyIndex = index
                    chooseVacancy()
                }
            ))
        }
        if let reply = model.lastReply, reply.proposedAction?.vaultItem != nil, reply.accessRequest == nil, !model.addedReplies.contains(reply.id) {
            menus.append(CameraMenu(id: "concept", title: "Bewijs", symbol: "doc.badge.plus", items: [AylaMessages.conceptAdd], onPress: { _ in
                openProposedEvidence(from: reply)
            }))
        }
        let chats = Array(model.conversationList.conversations.prefix(8))
        if !chats.isEmpty, !isTalking {
            menus.append(CameraMenu(id: "chats", title: "Chats", symbol: "bubble.left.and.bubble.right", items: chats.map { $0.title.isEmpty ? "Gesprek" : $0.title }, keys: chats.map(\.id), onPress: { index in
                guard chats.indices.contains(index) else { return }
                Task { await model.open(chats[index]) }
            }))
        }
        return menus
    }

    /// The answer the Camera Control button rests on, lit up in the choices until a full press sends it.
    private var buttonAnswerID: String? {
        cameraControl?.highlight.flatMap { $0.menu == "answer" ? $0.key : nil }
    }

    /// An answer chosen with the Camera Control button: the same as tapping it.
    private func answerByButton(_ choice: AylaChoice) {
        if isTalking {
            chooseWhileTalking(choice)
        } else if AylaVaultOffer.isYes(choice.label) || AylaVaultOffer.isNo(choice.label) {
            answerYesNo(AylaVaultOffer.isYes(choice.label), byHead: false)
        } else {
            choose(choice.label)
        }
    }

    /// Ayla's choices in place of the voice bar while she asks for one, even while she is still saying it: the same
    /// as under the chat (also when the chat shows the question on the evidence card, which the orb covers), or Ja and
    /// Nee for a question in her words that asks for one of them.
    private var voiceChoices: [AylaChoice] {
        guard let voice, isTalking, voice.isActive, voice.state != .thinking else { return [] }
        if let choices = model.pendingQuestion?.choices, choices.count >= 2 {
            return choices.map { AylaChoice(id: $0.id, label: $0.label) }
        }
        guard model.pendingYesNo else { return [] }
        return [AylaChoice(id: "yes", label: "Ja"), AylaChoice(id: "no", label: "Nee")]
    }

    /// A tap on one of those choices while talking: Ja and Nee get the same feedback as a nod; another choice is sent
    /// as if it was said.
    private func chooseWhileTalking(_ choice: AylaChoice) {
        if AylaVaultOffer.isYes(choice.label) || AylaVaultOffer.isNo(choice.label) {
            answerYesNo(AylaVaultOffer.isYes(choice.label), byHead: false)
            return
        }
        PaveHaptics.selection()
        voice?.play(.tick)
        voice?.send(typed: choice.label)
    }

    private var browsesByHead: Bool {
        isTalking && !orbMotion.isLow && !voiceVacancies.isEmpty && voice?.isActive == true
    }

    private struct HeadMode: Equatable {
        let yesNo: Bool
        let browse: Bool
    }

    private var headMode: HeadMode {
        HeadMode(yesNo: asksYesNoByHead, browse: browsesByHead)
    }

    private var vacancyCard: AylaVoiceVacancyCard? {
        let vacancies = voiceVacancies
        guard browsesByHead, !vacancies.isEmpty else { return nil }
        let index = min(vacancyIndex, vacancies.count - 1)
        return AylaVoiceVacancyCard(
            vacancy: vacancies[index],
            index: index,
            count: vacancies.count,
            followsHead: headGestures.isReceiving,
            onPrevious: { moveVacancy(by: -1) },
            onNext: { moveVacancy(by: 1) },
            onChoose: chooseVacancy
        )
    }

    private func moveVacancy(by step: Int) {
        let next = vacancyIndex + step
        guard voiceVacancies.indices.contains(next) else {
            PaveHaptics.tap(.soft)
            return
        }
        withAnimation(.snappy(duration: 0.25)) { vacancyIndex = next }
        PaveHaptics.selection()
        voice?.play(.tick)
    }

    /// Ayla tells more about this one: why it fits and what is still missing.
    private func chooseVacancy() {
        let vacancies = voiceVacancies
        guard let voice, !vacancies.isEmpty else { return }
        PaveHaptics.tap(.medium)
        voice.play(.tick)
        voice.send(typed: AylaMessages.vacancyAsk(vacancies[min(vacancyIndex, vacancies.count - 1)]), checksYes: false)
    }

    /// A yes in words to "Zal ik het in je kluis zetten?": Ayla puts it in the vault, without the form. When something
    /// required is missing, or the save fails, the form opens instead, so nothing is saved halfway out of sight.
    private func addEvidenceForUser(from reply: AylaReply, saying words: String) {
        guard let vault, !isSavingForUser else { return }
        isSavingForUser = true
        let analysis = model.analysis(for: reply)
        let excluded = excludedFiles[reply.id] ?? []
        let documents = (analysis?.uploads ?? model.uploads(for: reply.proposedAction?.vaultItem)).filter { !excluded.contains($0.checksum) }
        PaveHaptics.tap(.light)
        Task {
            defer { isSavingForUser = false }
            if vault.state != .ready { await vault.load() }
            let flow = VaultAddEvidenceModel.proposed(by: reply, vault: vault, documents: documents, analysis: excluded.isEmpty ? analysis : nil)
            if flow.aylaFill != .reading, flow.aylaProposals.count <= 1, await flow.saveFromChat() {
                let talking = isTalking ? voice : nil
                model.markAdded(
                    replyID: reply.id, itemID: flow.savedItemID, title: flow.draft.title, uploads: flow.documents, saying: words,
                    deliver: talking.map { voice in { voice.send(typed: $0, checksYes: false) } }
                )
                talking?.play(.saved)
                startWave(fromOrb: talking != nil)
            } else {
                if isTalking { stopVoice() }
                addingFromReplyID = reply.id
                addEvidence = flow
            }
        }
    }

    private func send(_ text: String? = nil) {
        guard connection.isOnline, !isSavingForUser else { return }
        dictation.stop()
        isComposerFocused = false
        let message = text ?? model.draft
        let words = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if text == nil, !model.isAnswering, AylaVaultOffer.isConfirmation(words), handleYes(saying: words) {
            model.draft = ""
            return
        }
        model.send(message)
    }


    private var isVoiceActive: Bool { voice?.isActive == true }

    private enum OrbPlace {
        /// Large in the middle.
        case center
        /// Small above the voice bar.
        case bar
    }

    /// A place of the orb moved (the keyboard, turning the device): the orb glides along. The first time it is
    /// simply there.
    private func place(_ place: OrbPlace, at frame: CGRect) {
        let old = place == .center ? stageSlot : barSlot
        guard old != frame else { return }
        let update = {
            switch place {
            case .center: stageSlot = frame
            case .bar: barSlot = frame
            }
        }
        if old.isEmpty || reduceMotion {
            update()
        } else {
            withAnimation(.smooth(duration: 0.35), update)
        }
    }

    /// Where the orb is on screen, once it has arrived.
    private var orbFrame: CGRect {
        AylaOrbTrack<EmptyView>.frame(of: orbMotion, stage: stageSlot, bar: barSlot)
    }

    /// Talking full screen: at the start of an empty chat and on iPhone, until the orb is dragged down. On iPad and
    /// the open Duo there is room for both, so with a conversation the orb sits above the voice bar.
    private var wantsVoiceStage: Bool {
        guard !model.isLoadingConversation else { return false }
        return prefersVoiceStage ?? (model.entries.isEmpty || sizeClass == .compact)
    }

    private var canDragOrb: Bool {
        isTalking && !model.isLoadingConversation
    }

    /// How far the orb travels between its places.
    private var orbTravel: CGFloat {
        guard !stageSlot.isEmpty, !barSlot.isEmpty else { return 300 }
        return max(120, barSlot.midY - stageSlot.midY)
    }

    /// The conversation shows when not talking, and while talking only once the small orb has landed above the
    /// voice bar.
    private var showsConversation: Bool {
        !isTalking || (orbMotion.isLow && orbMotion.hasArrived)
    }

    /// Like ChatGPT: drag the large orb down to see the conversation, or the small one up to talk full screen. The
    /// orb does not follow the finger: it gives a little, like elastic, and stretches towards it. Let go far enough,
    /// or flick, and it jumps to its other place, popping to its new size on the way; otherwise it springs back.
    private var orbDragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .updating($isHoldingOrb) { _, isHolding, _ in isHolding = true }
            .onChanged { value in
                if !orbMotion.isDragging { orbMotion.grab() }
                let finger = orbMotion.drag(by: value.translation.height)
                isOrbReadyToSwitch = finger * orbDirection > AylaOrbMotion.switchDistance
            }
            .onEnded { value in
                isOrbReadyToSwitch = false
                let pulled = value.translation.height * orbDirection
                let heading = value.predictedEndTranslation.height * orbDirection
                let isFlickedBack = value.velocity.height * orbDirection < -300
                let switches = (pulled > AylaOrbMotion.switchDistance && !isFlickedBack) || heading > AylaOrbMotion.flickDistance
                guard switches else {
                    orbSpringBacks += 1
                    orbMotion.letGo(velocity: value.velocity.height, reduceMotion: reduceMotion)
                    return
                }
                orbSnaps += 1
                orbMotion.switchPlace(velocity: value.velocity.height, travel: orbTravel, reduceMotion: reduceMotion) {
                    orbLandings += 1
                }
                prefersVoiceStage = !orbMotion.isLow
            }
    }

    /// Down from the middle, up from the voice bar.
    private var orbDirection: CGFloat {
        orbMotion.isLow ? -1 : 1
    }

    private var isOutroRunning: Bool {
        if case .outro = introPhase { true } else { false }
    }

    /// Talking with Ayla needs her server; with the demo sign-in there is no voice button.
    private var voiceAction: (() -> Void)? {
        guard model.isAvailable else { return nil }
        return { startVoice() }
    }

    private var voiceProblemBinding: Binding<Bool> {
        Binding(get: { voiceProblem != nil }, set: { if !$0 { voiceProblem = nil } })
    }

    /// Starts the spoken conversation. The orb comes out of the voice button: its blocks burst out of it and swirl
    /// into place, after which the field around the orb rolls out.
    private func startVoice() {
        dictation.stop()
        readAloud.stop()
        isComposerFocused = false
        isAttachMenuOpen = false
        let session = voice ?? AylaVoiceSession(model: model)
        session.onYes = { handleYes(saying: $0) }
        voice = session
        stageSlot = .zero
        barSlot = .zero
        orbMotion.jump(to: wantsVoiceStage ? 0 : 1)
        withAnimation(voiceAnimation) { isTalking = true }
        fieldRevealedAt = nil
        if reduceMotion {
            introPhase = nil
            isOrbHidden = false
            fieldRevealedAt = .now
        } else {
            let phase = AylaVoiceIntro.Phase.intro(.now)
            introPhase = phase
            isOrbHidden = true
            Task {
                try? await Task.sleep(for: AylaVoiceIntro.introArrival)
                guard introPhase == phase else { return }
                isOrbHidden = false
                fieldRevealedAt = .now
                try? await Task.sleep(for: AylaVoiceIntro.introDuration - AylaVoiceIntro.introArrival)
                if introPhase == phase { introPhase = nil }
            }
        }
        Task {
            await session.start()
            if let problem = session.problem {
                withAnimation(voiceAnimation) { isTalking = false }
                voiceProblem = problem
                introPhase = nil
                isOrbHidden = false
            }
        }
    }

    /// Stops the spoken conversation: the orb falls apart into its blocks, which swirl back into the voice button.
    private func stopVoice() {
        guard let voice else { return }
        isAttachMenuOpen = false
        fieldRevealedAt = nil
        if !reduceMotion {
            outroOrbFrame = orbFrame
            let phase = AylaVoiceIntro.Phase.outro(.now)
            introPhase = phase
            Task {
                try? await Task.sleep(for: AylaVoiceIntro.outroDuration)
                if introPhase == phase { introPhase = nil }
            }
        }
        withAnimation(voiceAnimation) { isTalking = false }
        voice.stop()
    }

    /// Text field and voice bar melt into each other with this.
    private var voiceAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.2)
    }

    private var fileProblemBinding: Binding<Bool> {
        Binding(get: { fileProblem != nil }, set: { if !$0 { fileProblem = nil } })
    }

    private func toggleAttachMenu() {
        isComposerFocused = false
        isAttachMenuOpen.toggle()
    }

    private func chooseFile() {
        isAttachMenuOpen = false
        isChoosingFile = true
    }

    private var attachMenu: some View {
        AylaAttachMenu(
            onAddFile: { chooseFile() },
            onPhoto: { isAttachMenuOpen = false; isChoosingPhotos = true },
            onPickItem: vault == nil || vault?.state == .ready && vault?.items.isEmpty == true ? nil : { isAttachMenuOpen = false; picksVaultItem = true },
            onScan: scanAction,
            onPaste: { addPasted() }
        )
    }

    /// Photos from the library, several at once: each becomes a JPEG without its location, written to a file of our
    /// own and read like a chosen file, one after the other so their names stay apart.
    private func addPhotos(_ items: [PhotosPickerItem]) async {
        let model = model
        let day = Date.now.formatted(.iso8601.year().month().day())
        for item in items {
            guard model.attachments.count < AylaAttachment.maxCount else {
                fileProblem = AylaMessages.tooManyFiles
                return
            }
            guard let data = try? await item.loadTransferable(type: Data.self), let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.85) else {
                fileProblem = AylaMessages.fileUnreadable
                continue
            }
            let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            defer { try? FileManager.default.removeItem(at: folder) }
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let url = folder.appending(path: model.uniqueAttachmentName("Foto \(day).jpeg"))
                try jpeg.write(to: url)
                let file = try await AttachmentReader.file(url)
                model.attach(file.attachment, upload: file.upload ?? VaultUpload(data: jpeg, fileName: url.lastPathComponent, mimeType: "image/jpeg"))
                PaveHaptics.tap(.light)
            } catch {
                fileProblem = AylaMessages.fileUnreadable
            }
        }
    }

    private func addFiles(_ result: Result<[URL], any Error>) {
        guard case .success(let urls) = result else { return }
        let model = model
        Task {
            for url in urls {
                guard model.attachments.count < AylaAttachment.maxCount else {
                    fileProblem = AylaMessages.tooManyFiles
                    return
                }
                if let file = try? await AttachmentReader.file(url) {
                    model.attach(file.attachment, upload: file.upload)
                } else {
                    fileProblem = AylaMessages.fileUnreadable
                }
            }
        }
    }

    /// Only where the device has a camera that can scan documents.
    private var scanAction: (() -> Void)? {
        guard DocumentScanner.isAvailable else { return nil }
        return { scanDocument() }
    }

    private func scanDocument() {
        isAttachMenuOpen = false
        isScanning = true
    }

    private func addScan(_ pages: [CGImage]) {
        guard !pages.isEmpty else { return }
        let name = "Scan \(Date.now.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "nl_NL")))).pdf"
        let model = model
        Task {
            guard model.attachments.count < AylaAttachment.maxCount else {
                fileProblem = AylaMessages.tooManyFiles
                return
            }
            if let file = try? await AttachmentReader.file(pages: pages, name: name) {
                model.attach(file.attachment, upload: file.upload)
                PaveHaptics.success()
            } else {
                fileProblem = AylaMessages.fileUnreadable
            }
        }
    }

    private func addPasted() {
        isAttachMenuOpen = false
        guard model.attachments.count < AylaAttachment.maxCount else {
            fileProblem = AylaMessages.tooManyFiles
            return
        }
        let url: URL
        do {
            url = try AttachmentReader.clipboardFile()
        } catch AttachmentReader.Failure.refused {
            fileProblem = AylaMessages.pasteRefused
            return
        } catch {
            fileProblem = AylaMessages.fileUnreadable
            return
        }
        let model = model
        Task {
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            if let file = try? await AttachmentReader.file(url) {
                model.attach(file.attachment, upload: file.upload)
                PaveHaptics.tap(.light)
            } else {
                fileProblem = AylaMessages.fileUnreadable
            }
        }
    }

    /// Files dragged in or pasted: read on the device, like a chosen file.
    private func addProviders(_ providers: [NSItemProvider]) {
        let model = model
        Task {
            for provider in providers {
                guard model.attachments.count < AylaAttachment.maxCount else {
                    fileProblem = AylaMessages.tooManyFiles
                    return
                }
                if let file = try? await AttachmentReader.file(provider) {
                    model.attach(file.attachment, upload: file.upload)
                    PaveHaptics.tap(.light)
                } else {
                    fileProblem = AylaMessages.fileUnreadable
                }
            }
        }
    }

    private func scrollToBottom() {
        Task {
            await Task.yield()
            withAnimation(.easeOut(duration: 0.3)) { scrollPosition.scrollTo(edge: .bottom) }
        }
    }

    private func closeVacancies() {
        openVacanciesID = nil
    }

    private func openShelf(_ next: AylaShelf) {
        PaveHaptics.selection()
        if let shelf { model.hideScreen(shelf.screen) }
        openVacanciesID = nil
        vaultDetent = .fraction(0.62)
        shelf = next
        model.showScreen(next.screen)
    }

    private func closeShelf() {
        guard let shelf else { return }
        model.hideScreen(shelf.screen)
        self.shelf = nil
    }

    /// Something that opens over the chat waits until the sheet from the start chips is gone.
    private func closingShelf(then action: @escaping () -> Void) {
        guard shelf != nil else { return action() }
        afterShelf = action
        closeShelf()
    }

    private func cancelDictation() {
        dictation.stop()
        model.draft = draftBeforeDictation
    }

    private func finishDictation() {
        dictation.stop()
    }

    private func toggleDictation() {
        if dictation.isListening {
            dictation.stop()
            return
        }
        draftBeforeDictation = model.draft
        isAttachMenuOpen = false
        let prefix = model.draft.isEmpty ? "" : model.draft + " "
        let model = model
        Task {
            await dictation.start { text in model.draft = prefix + text }
        }
    }

    /// The messages with the space above each one (more when the other side starts a turn), and the time above the
    /// first one and after a pause, as in Messages.
    private static func rows(_ entries: [AylaChatModel.Entry]) -> [(entry: AylaChatModel.Entry, spacing: CGFloat, time: String?)] {
        entries.indices.map { index in
            let entry = entries[index]
            let previous = index > 0 ? entries[index - 1] : nil
            let time = AylaTimeline.showsTime(before: entry.sentAt, after: previous?.sentAt)
                ? AylaTimeline.label(for: entry.sentAt) : nil
            guard let previous else { return (entry, 0, time) }
            return (entry, time != nil ? 28 : previous.role != entry.role ? 25 : 12, time)
        }
    }

    private static func vacancies(in entry: AylaChatModel.Entry) -> [Vacancy] {
        (entry.reply?.blocks ?? []).flatMap { block -> [Vacancy] in
            if case .vacancies(let items) = block { items } else { [] }
        }
    }
}

private extension View {
    func transform(_ change: (Self) -> some View) -> some View {
        change(self)
    }
}
