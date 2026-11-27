import PAVECore
import SwiftUI
import UserNotifications

/// The app after signing in. You can go to Ayla, your vault or your plans yourself with the menu, laid out like
/// ChatGPT: on a wide screen (iPad, the open iPhone Duo held sideways) it is a sidebar next to the screen that you
/// can hide and bring back; elsewhere (iPhone, the open iPhone Duo held upright, its outer display) it slides over
/// the screen from the menu button. When iPhone Duo is partly folded, the menu fills the pane on one side of the fold
/// and the screen the pane on the other, so nothing sits in the fold.
struct MainView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.paveReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AylaSpotlight.settingKey) private var chatsInSpotlight = false
    @State private var model: AylaChatModel
    @State private var memory: AylaMemoryModel
    @State private var vault: VaultModel
    @State private var devices: SignedInDevicesModel
    @State private var profile: ProfileModel
    @Environment(\.dynamicTypeSize) private var deviceTextSize
    @State private var watchConnection = WatchConnectionModel()
    @State private var notificationsModel: NotificationsModel
    /// iCloud Mail, read live on this iPhone; its conversations show up in Meldingen.
    @State private var emailModel = EmailModel()
    @State private var sharing: SharingModel
    /// Ayla was asked to share: the composer opens over the chat, so you are back with her once it is done.
    @State private var aylaShare: ShareTemplateChoice?
    /// A moment Ayla set up on the Watch, for the iPhone's calendar screen.
    @State private var calendarFromWatch: AylaCalendarMoment?
    /// An employer opened from the iPhone's camera, over whatever screen is open.
    @State private var fairEmployer: FairEmployerSlug?
    @State private var draftSync: ApplicationDraftSyncer?
    @State private var accountSync: AccountStateSync?
    /// The employer's inbox of the demo, opened from its key's code.
    @State private var employerInbox: EmployerInboxKey?
    /// Applications whose demo invitation has arrived, for Meldingen and the bell; read again when you move around.
    @State private var invitations: [ApplicationDraft] = []
    @State private var plans: PlanModel
    @State private var destination = MainDestination.ayla
    /// Demo: the Camera Control button steers PAVE while "knopmodus" is on.
    @State private var cameraControl = PaveCameraControl()
    @State private var isMenuOpen = false
    @State private var isSidebarHidden = false
    @State private var showsChats = false
    @State private var width: CGFloat = 0
    @State private var menuButtonFrame = CGRect.zero
    /// iPhone Duo is partly folded, with the fold between a left and a right pane.
    @State private var isFolded = false
    /// When "Zoeken in chats" was asked for, so the search field of the chats takes the keyboard.
    @State private var chatSearchRequestedAt: Date?
    @State private var showsSearch = false
    /// `visibleBanner` as it is on screen, changed with an explicit animation: the models set their banner from a
    /// background refresh, where an implicit animation on the overlay did not catch the card appearing.
    @State private var shownBanner: PaveNotification?
    private let connection = PaveConnection.shared

    /// Wide enough to show the chats next to the conversation.
    private static let wideWidth: CGFloat = 860
    /// Wide enough for the sidebar next to the screen, as ChatGPT does on the open iPhone Duo held sideways.
    private static let sidebarWidth: CGFloat = 800
    private static let sidebarSize: CGFloat = 320

    init(
        service: (any AylaService)?, vaultService: (any VaultService)?, devicesService: (any DevicesService)? = nil,
        profileService: (any ProfileService)? = nil, notificationsService: SupabaseNotificationsService? = nil,
        shareService: (any ShareService)? = nil, planService: (any PlanService)? = nil
    ) {
        _sharing = State(initialValue: SharingModel(service: shareService, webURL: ShareServiceFactory.webURL()))
        _model = State(initialValue: AylaChatModel(service: service, drafts: .standard, pendingFiles: .standard))
        _memory = State(initialValue: AylaMemoryModel(service: service))
        _vault = State(initialValue: VaultModel(service: vaultService))
        _devices = State(initialValue: SignedInDevicesModel(service: devicesService))
        _profile = State(initialValue: ProfileModel(service: profileService))
        _notificationsModel = State(initialValue: NotificationsModel(service: notificationsService))
        _plans = State(initialValue: PlanModel(service: planService, liveActivity: PlanActivityController()))
    }

    /// Meldingen, e-mail conversations and invitations you have not read: the bell and the app icon.
    private var unreadCount: Int {
        notificationsModel.unreadCount + emailModel.unreadCount
            + invitations.filter { $0.progress.invitation?.isRead == false }.count
            // Invitations from the fair wait for an answer in Meldingen too.
            + (sharing.fairApplications?.filter(\.awaitsAnswer).count ?? 0)
    }

    private var currentBanner: PaveNotification? { notificationsModel.banner ?? emailModel.banner }

    /// The banner that may show here: in Meldingen the list shows what is new; inside an e-mail conversation, mail for
    /// another one still gets its banner, as in Messages.
    private var visibleBanner: PaveNotification? {
        guard let banner = currentBanner else { return nil }
        return destination != .notifications || (banner.kind == .email && emailModel.openThreadID != nil) ? banner : nil
    }

    private var topSlot: PaveTopSlot { .shared }

    /// A melding or the step question is on screen: the rest of the top waits.
    private var showsTopMessage: Bool {
        shownBanner != nil || (!topSlot.chatHoldsTop && plans.suggestion.map { plans.suggestion(for: $0.planID) != nil } == true)
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner = shownBanner {
            NotificationBanner(notification: banner) {
                // A message opens its conversation, not just the list.
                emailModel.threadToOpen = banner.emailThreadID
                dismissBanners()
                open(.notifications)
                isMenuOpen = false
            } onDismiss: {
                dismissBanners()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            // The overlay sits outside the screen's environment: without these the photo falls back to initials.
            .environment(profile)
            .environment(emailModel)
            // Its own identity per melding, so a new one replacing the last also comes out of the island.
            .id(banner.id)
            .transition(.fromIsland)
        }
    }

    /// "Klaar met deze stap?" over the app, after the melding when both are there. It waits for an answer: what you
    /// did often happens in a sheet, and the question should still be there when it closes. Not on the page of that
    /// plan, where the plan itself asks.
    @ViewBuilder
    private var suggestionView: some View {
        if shownBanner == nil, !topSlot.chatHoldsTop, let suggestion = plans.suggestion, plans.suggestion(for: suggestion.planID) != nil,
           !(destination == .plan && plans.openPlanID == suggestion.planID) {
            PlanStepSuggestionCard(suggestion: suggestion) {
                plans.acceptSuggestion()
            } onDismiss: {
                plans.dismissSuggestion()
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .gesture(DragGesture(minimumDistance: 12).onEnded { value in
                if value.translation.height < -10 { plans.dismissSuggestion() }
            })
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .id(suggestion.stepID)
            .transition(.fromIsland)
        }
    }

    private func dismissBanners() {
        notificationsModel.dismissBanner()
        emailModel.dismissBanner()
    }

    /// Meldingen every 30 seconds; mail every two minutes, often enough to feel live without asking the provider all the time.
    private func pollMeldingen() async {
        var round = 0
        while !Task.isCancelled {
            await notificationsModel.refresh()
            if round % 4 == 0 { await emailModel.refresh() }
            await sharing.loadFairApplications()
            // With a Watch, who looked at what you shared taps your wrist within half a minute.
            if ShareWatchBridge.isAvailable { await sharing.load() }
            if draftSync == nil { draftSync = ApplicationDraftSyncer.make(auth: appState.authService) }
            if await draftSync?.run() == true { sharing.reloadApplications() }
            if accountSync == nil { accountSync = AccountStateSync.make(auth: appState.authService) }
            await accountSync?.run()
            round += 1
            try? await Task.sleep(for: .seconds(30))
        }
    }

    /// The layout with its environment, banners, polling and knopmodus surface.
    private var framedLayout: some View {
        layout
        .dynamicTypeSize(deviceTextSize.shifted(by: profile.textSize))
        .task { await profile.load() }
        .onChange(of: profile.profile.displayName) { _, name in
            if let name { model.nameChanged(name) }
            emailModel.senderName = name
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .environment(\.reportMenuButtonFrame) { menuButtonFrame = $0 }
        .environment(\.hidesScreenButtons, menuReplacesButtons)
        .environment(\.toolbarIsBeside, MainMenuDrawer.isButtonBeside(menuButtonFrame))
        .environment(\.menuButtonFrame, menuButtonFrame)
        .environment(\.chatSearchRequestedAt, chatSearchRequestedAt)
        .focusedSceneValue(\.paveActions, keyboardActions)
        .tint(.paveAccent)
        .environment(memory)
        .environment(plans)
        .environment(cameraControl)
        .environment(\.unreadNotifications, unreadCount)
        .environment(emailModel)
        .task(id: destination) { invitations = Self.arrivedInvitations() }
        // A container that is always there, so the card's insertion and removal have something to animate in.
        .overlay(alignment: .top) { ZStack(alignment: .top) { bannerView; suggestionView } }
        .animation(.island, value: plans.suggestion)
        .onChange(of: visibleBanner?.id, initial: true) {
            withAnimation(.island) { shownBanner = topSlot.chatHoldsTop ? nil : visibleBanner }
        }
        // While Ayla's answer floats over the chat a melding waits, then comes; one message at the top at a time.
        .onChange(of: topSlot.chatHoldsTop) {
            withAnimation(.island) { shownBanner = topSlot.chatHoldsTop ? nil : visibleBanner }
        }
        .onChange(of: showsTopMessage, initial: true) { topSlot.messageShows = showsTopMessage }
        // New meldingen show up while PAVE is open: a quiet refresh every 30 seconds, and the badge on the icon follows.
        .task(id: PollingState(isActive: scenePhase == .active, isOpen: appState.isOpen)) {
            guard scenePhase == .active, appState.isOpen else { return }
            await pollMeldingen()
        }
        // New mail the moment iCloud has it, not only at the two-minute look.
        .task(id: PollingState(isActive: scenePhase == .active, isOpen: appState.isOpen)) {
            guard scenePhase == .active, appState.isOpen else { return }
            await emailModel.watchForNewMail()
        }
        .onChange(of: unreadCount, initial: true) { _, count in
            NotificationAlerts.setBadge(count)
        }
        // Knopmodus: a full press does Ayla's choice, or starts talking. The presses are caught on an empty layer
        // behind the screen that only exists in knopmodus: around the whole screen, even switched off, iOS's catcher
        // took every tap on the toolbar buttons. iOS's own green dot shows the camera is on.
        // What the button rests on in a menu that is not lit up on the screen itself, such as a chat, a step or an action.
        .overlay(alignment: .top) {
            if cameraControl.topSource == nil, let highlight = cameraControl.highlight, !CameraMenu.litOnScreen.contains(highlight.menu) {
                AylaHeadHint(text: "\(highlight.menuTitle): \(highlight.title)", isAnswer: true)
                    .padding(.top, 52)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: cameraControl.highlight)
        .background {
            if cameraControl.isOn {
                PaveCameraControlSurface(camera: cameraControl.camera) { cameraControl.fullPress() }
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
    }

    // Split from `body`, which became too long for the compiler to type-check in one piece.
    var body: some View {
        framedLayout
        .onAppear {
            cameraControl.onGoTo = { open($0) }
            cameraControl.onAyla = { action in
                switch action {
                case .talk: talk()
                case .newConversation: startNewConversation()
                case .chats: openChats()
                }
            }
        }
        .onChange(of: destination) { _, destination in cameraControl.show(destination) }
        // Knopmodus stays on: it starts whenever PAVE is in front and unlocked, and stops when it is not.
        .onChange(of: CameraControlWanted(isEnabled: cameraControl.isEnabled && !cameraControl.isSuspended, changed: cameraControl.enabledChanged, isActive: scenePhase != .background, isOpen: appState.isOpen), initial: true) { _, wanted in
            if wanted.isEnabled, wanted.isActive, wanted.isOpen {
                Task { await cameraControl.start(at: destination) }
            } else {
                cameraControl.stop()
            }
        }
        .task { await model.start() }
        .task { connectWatch() }
        .onChange(of: plans.plans) { _, all in sendPlanToWatch(all) }
        .followsPlans(plans, chat: model)
        .keepsOpenChat(destination == .ayla && scenePhase == .active && appState.isOpen ? model.conversationID : nil, in: notificationsModel)
        .task { await memory.load() }
        .task { await model.followConversationChanges() }
        .onChange(of: hasSidebar) { isMenuOpen = false }
        // What changes on this iPhone goes to the account a moment later, for the laptop and the other devices.
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in accountSync?.localChanged() }
        .onReceive(NotificationCenter.default.publisher(for: AccountStateSync.didPull)) { _ in
            plans.reloadEditDecisions()
            emailModel.reloadMarks()
        }
        // An application saved here is in the account a moment later, not only at the next round.
        .onReceive(NotificationCenter.default.publisher(for: ApplicationStore.didChange)) { _ in
            Task {
                try? await Task.sleep(for: .seconds(2))
                if await draftSync?.run() == true { sharing.reloadApplications() }
            }
        }
        // A deleted chat that could still be brought back is really deleted when the app goes away.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                // What was written just now is in the account before the app sleeps, for the next device.
                Task { await draftSync?.run() }
                Task { await accountSync?.run() }
                model.commitPendingDeletion()
                memory.commitPendingForget()
                // Locked e-mail conversations need the PIN again, as locked chats do.
                emailModel.showsLocked = false
                // Ask iOS again for a look in the background, for new meldingen and mail.
                NotificationAlerts.scheduleRefresh()
            }
        }
        .onChange(of: model.conversationList, initial: true) { _, list in
            if chatsInSpotlight { AylaSpotlight.update(list) }
        }
        .onChange(of: chatsInSpotlight) { _, isOn in
            if isOn { AylaSpotlight.update(model.conversationList) } else { AylaSpotlight.removeAll() }
        }
        // Siri, a widget or the iPhone's search wait until the app is unlocked, so Ayla never starts listening behind
        // the PIN screen.
        .onChange(of: appState.conversationToOpen, initial: true) { handlePending() }
        .onChange(of: appState.link, initial: true) { handlePending() }
        .onChange(of: appState.fairToOpen, initial: true) { handlePending() }
        .onChange(of: appState.isRelocked) { handlePending() }
        .onChange(of: appState.opensNotifications, initial: true) { handlePending() }
        .onChange(of: connection.isOnline) { _, isOnline in
            if isOnline { Task { await model.refreshConversations() } }
        }
    }

    /// The screens and the menu for every shape of screen, with what opens over them.
    private var layout: some View {
        GeometryReader { proxy in
            // One layout for every shape of screen, with the screen always in the same place in it: folding, turning
            // or resizing only moves it, so what is open on it (a sheet, a half-filled form) stays open.
            let fold = proxy.foldSplit().flatMap { $0.axis == .sideBySide ? $0 : nil }
            let docksSidebar = fold == nil && hasSidebar && !isSidebarHidden
            let usesDrawer = fold == nil && !hasSidebar
            ZStack(alignment: .topLeading) {
                screen(onShowMenu: menuAction(fold: fold))
                    .sheet(isPresented: $showsSearch) { searchScreen }
                    .frame(width: fold?.second.width, height: fold?.second.height)
                    .offset(x: fold?.second.minX ?? 0, y: fold?.second.minY ?? 0)
                    .padding(.leading, docksSidebar ? Self.sidebarSize : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .overlay {
                        // On the outer display of iPhone Duo the open menu draws its own close button in the menu
                        // button's place; the real one hides meanwhile, so no second glass circle shows underneath.
                        if usesDrawer {
                            MainMenuDrawer(
                                isPresented: $isMenuOpen,
                                selection: destination,
                                name: model.firstName,
                                menuButtonFrame: menuButtonFrame,
                                onSelect: open,
                                onNewConversation: startNewConversation,
                                onShowChats: openChats,
                                onSignOut: appState.signOut,
                                onSearch: { showsSearch = true }
                            )
                        }
                    }
                if let fold {
                    sidebar(width: fold.first.width, canHide: false)
                        .frame(width: fold.first.width, height: fold.first.height)
                        .offset(x: fold.first.minX, y: fold.first.minY)
                } else if docksSidebar {
                    sidebar(width: Self.sidebarSize, canHide: true)
                        .transition(.move(edge: .leading))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.canvas.ignoresSafeArea())
            .onChange(of: fold != nil, initial: true) { _, folded in
                isFolded = folded
                if folded { isMenuOpen = false }
            }
        }
        // Your look from Instellingen: the photo in the menu, the text size, and the name Ayla uses.
        .environment(profile)
        // Sharing from the studio and from Ayla, next to the Profiel page.
        .environment(sharing)
        .environment(\.openDestination, openDestinationAction)
        .environment(\.vacancyRequest, vacancyRequestAction)
        .modifier(MainFairSheets(
            sharing: sharing, vault: vault, profile: profile, model: model,
            fairEmployer: $fairEmployer, employerInbox: $employerInbox, aylaShare: $aylaShare
        ))
        .sheet(item: $calendarFromWatch) { moment in
            AylaCalendarEditor(moment: moment) { calendarFromWatch = nil }
                .ignoresSafeArea()
        }
    }

    private var openDestinationAction: (MainDestination) -> Void {
        { destination in open(destination) }
    }

    /// A vacancy task from outside the chat (the fair): close what is over it and let Ayla take it.
    private var vacancyRequestAction: (AylaChatModel.VacancyRequest) -> Void {
        { request in
            fairEmployer = nil
            model.request(request)
            open(.ayla)
        }
    }

    private func handlePending() {
        guard !appState.isRelocked else { return }
        if let id = appState.conversationToOpen {
            appState.conversationToOpen = nil
            openFromSearch(id)
        }
        if let link = appState.link {
            appState.link = nil
            follow(link)
        }
        if let fair = appState.fairToOpen {
            appState.fairToOpen = nil
            isMenuOpen = false
            switch fair {
            case .employer(let slug): fairEmployer = FairEmployerSlug(slug: slug)
            case .vacancy(let slug, let id): fairEmployer = FairEmployerSlug(slug: slug, vacancyID: id)
            case .inbox(let slug, let key): employerInbox = EmployerInboxKey(slug: slug, key: key)
            case .share: break
            }
        }
        if appState.opensNotifications {
            appState.opensNotifications = false
            if let threadID = appState.emailThreadToOpen {
                appState.emailThreadToOpen = nil
                emailModel.threadToOpen = threadID
            }
            isMenuOpen = false
            open(.notifications)
        }
    }

    private var keyboardActions: PaveActions {
        let talk: (() -> Void)? = model.isAvailable ? { self.talk() } : nil
        let toggleMenu: (() -> Void)? = isFolded ? nil : { self.toggleMenu() }
        return PaveActions(
            newConversation: { startNewConversation() },
            talk: talk,
            searchChats: { searchChats() },
            toggleMenu: toggleMenu,
            openSettings: { open(.settings) }
        )
    }

    /// Siri, a widget or Control Center: a talk starts in a new chat, as in ChatGPT.
    private func follow(_ link: PaveLink) {
        switch link {
        case .shares:
            isMenuOpen = false
            open(.profile)
        case .stopSharing:
            isMenuOpen = false
            open(.profile)
            sharing.asksToStopAll = true
        case .applications:
            isMenuOpen = false
            model.opensApplications = true
            open(.vacancies)
        case .fairDay:
            isMenuOpen = false
            open(.profile)
            sharing.showsFairDay = true
        case .plan:
            // The plan on the Lock Screen opens on the Plan screen.
            plans.openPlanID = plans.followedPlanID
            isMenuOpen = false
            open(.plan)
        case .talk, .newConversation:
            startNewConversation()
            if link == .talk { talk() }
        }
    }

    /// Talking starts in the chat that is open.
    private func talk() {
        destination = .ayla
        isMenuOpen = false
        if !isWide { showsChats = false }
        model.wantsToTalk = true
    }

    /// The chats, from the menu on any screen.
    private func openChats() {
        destination = .ayla
        isMenuOpen = false
        showsChats = true
    }

    private func searchChats() {
        destination = .ayla
        isMenuOpen = false
        showsChats = true
        chatSearchRequestedAt = .now
    }

    private func toggleMenu() {
        if hasSidebar {
            setSidebarHidden(!isSidebarHidden)
        } else {
            isMenuOpen.toggle()
        }
    }

    /// The sidebar next to the screen, the same light column as the web sidebar, reaching the edges of the screen.
    /// Next to a fold it cannot be hidden: the screen would then lie across the fold.
    private func sidebar(width: CGFloat, canHide: Bool) -> some View {
        MainSidebar(
            style: canHide ? .docked : .pane,
            selection: destination,
            name: model.firstName,
            onSelect: open,
            onNewConversation: startNewConversation,
            onSignOut: appState.signOut,
            onClose: { setSidebarHidden(true) },
            onSearch: { showsSearch = true }
        )
        // The content starts at the top; the buttons sit at the bottom, as far from the bottom edge as from the side,
        // so they follow the rounded corner of the screen.
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 16)
        .ignoresSafeArea(.container, edges: .bottom)
        .frame(width: width)
        .background {
            Color.canvas
                .overlay(alignment: .trailing) {
                    Color.railBorder.frame(width: 1)
                }
                .ignoresSafeArea()
        }
    }

    /// Next to a fold the menu is always there; next to a hidden sidebar the button brings it back; otherwise it opens
    /// the menu over the screen.
    private func menuAction(fold: FoldSplit?) -> (() -> Void)? {
        if fold != nil { return nil }
        if hasSidebar { return isSidebarHidden ? { setSidebarHidden(false) } : nil }
        return menuReplacesButtons ? nil : { isMenuOpen.toggle() }
    }

    /// The open menu has taken over the buttons in the bar along the side (outer display of iPhone Duo).
    private var menuReplacesButtons: Bool {
        isMenuOpen && MainMenuDrawer.isButtonBeside(menuButtonFrame)
    }

    private var hasSidebar: Bool {
        sizeClass == .regular && width >= Self.sidebarWidth
    }

    /// The chats go next to the conversation when the room left next to the sidebar is wide enough.
    private var isWide: Bool {
        guard sizeClass == .regular, !isFolded else { return false }
        let room = hasSidebar && !isSidebarHidden ? width - Self.sidebarSize : width
        return room >= Self.wideWidth
    }

    @ViewBuilder
    private func screen(onShowMenu: (() -> Void)?) -> some View {
        switch destination {
        case .ayla:
            AylaRootView(model: model, onShowMenu: onShowMenu, isWide: isWide, showsChats: $showsChats)
                .environment(notificationsModel)
                .environment(vault)
                // Settings can open over the chat when you ask Ayla for them.
                .environment(devices)
                .environment(profile)
                .environment(watchConnection)
                .environment(\.openFromAyla, openFromAyla)
                .environment(\.shareFromAyla) { command in
                    if case .share(let organisation, let duration, let withApplication) = command {
                        sharing.reloadApplications()
                        aylaShare = ShareTemplateChoice(template: .employer, organisation: organisation, duration: duration, withApplication: withApplication)
                    } else {
                        sharing.request(command)
                        open(.profile)
                    }
                }
                .environment(\.openPlan) { id in
                    plans.openPlanID = id
                    open(.plan)
                }
        case .vault:
            VaultScreen(onShowMenu: onShowMenu)
                .environment(vault)
                .environment(\.askAylaAbout) { item in
                    model.ask(about: item)
                    open(.ayla)
                }
        case .vacancies:
            VacanciesScreen(model: model, onShowMenu: onShowMenu) { request in
                model.request(request)
                open(.ayla)
            }
            .environment(vault)
        case .plan:
            PlanScreen(
                onShowMenu: onShowMenu,
                chats: model.conversationList,
                chatsAreComplete: model.hasLoadedList && !model.canLoadMore && !model.listFailed,
                actions: PlanChatActions(open: openFromSearch, start: startConversation(in:for:), go: { destination in
                    isMenuOpen = false
                    open(destination)
                }, moveChats: { plan, projectID in
                    let project = model.conversationList.projects.first { $0.id == projectID }
                    for chat in model.conversationList.conversations where plan.conversations.contains(where: { $0.id == chat.id }) && chat.projectID != projectID {
                        model.move(chat, to: project)
                    }
                }, deleteChats: deleteChats, ask: askInPlan)
            )
            // Ayla's proposal for steps reads the evidence she may see and asks her service.
            .environment(vault)
            .environment(model)
        case .profile:
            ProfileScreen(model: sharing, onShowMenu: onShowMenu)
                .environment(vault)
                .environment(profile)
                .environment(model)
        case .settings:
            SettingsScreen(name: model.firstName, onShowMenu: onShowMenu, onSignOut: appState.signOut)
                .environment(model)
                .environment(\.openAylaChat) { chat in
                    destination = .ayla
                    isMenuOpen = false
                    if !isWide { showsChats = false }
                    Task { await model.open(chat) }
                }
                .environment(vault)
                .environment(devices)
                .environment(profile)
                .environment(watchConnection)
        case .notifications:
            NotificationsScreen(
                onShowMenu: onShowMenu,
                audience: notificationsModel.audience,
                notifications: notificationsModel.notifications + emailModel.notifications + emailModel.deletedNotifications,
                loadError: notificationsModel.problem,
                onRefresh: {
                    async let meldingen: Void = notificationsModel.refresh()
                    async let mail: Void = emailModel.refresh()
                    _ = await (meldingen, mail)
                },
                onMarkRead: { id in
                    if let thread = EmailModel.threadID(fromNotification: id) {
                        await emailModel.markRead(thread)
                    } else {
                        await notificationsModel.markRead(id)
                    }
                },
                onMarkAllRead: {
                    await notificationsModel.markAllRead()
                    await emailModel.markAllRead()
                },
                onOpenConversation: openNotificationConversation,
                onOpenVerifiedEvidence: openNotificationEvidence,
                onLoadReview: { await notificationsModel.review($0) },
                onResolveRequest: { await notificationsModel.resolve($0, action: $1, response: $2) },
                onDelete: { await notificationsModel.delete($0) },
                onRestore: { id in
                    if let thread = EmailModel.threadID(fromNotification: id) { return await emailModel.restore(thread) }
                    return await notificationsModel.restore(id)
                },
                invitations: invitations,
                onOpenApplication: { vacancy in
                    model.request(.application(vacancy))
                    open(.ayla)
                }
            )
            .environment(vault)
            // The PIN for locked e-mail, and Ayla's help with a mail.
            .environment(model)
        }
    }

    /// A chat from a notification opens as one from the iPhone's search: a locked one only through the PIN.
    private func openNotificationConversation(_ id: String) {
        openFromSearch(id)
    }

    /// The evidence of a notification opens in the vault, as when Ayla points to it.
    private func openNotificationEvidence(_ id: String) {
        vault.statusNews = id
        vault.itemToOpen = id
        isMenuOpen = false
        open(.vault)
    }

    private func setSidebarHidden(_ isHidden: Bool) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.1)) {
            isSidebarHidden = isHidden
        }
    }

    /// Applications whose demo invitation has arrived, newest first.
    static func arrivedInvitations(now: Date = .now) -> [ApplicationDraft] {
        ApplicationStore().all()
            .filter { $0.progress.invitation?.hasArrived(now: now) == true }
            .sorted { ($0.progress.invitation?.arrivesAt ?? .distantPast) > ($1.progress.invitation?.arrivesAt ?? .distantPast) }
    }

    private func open(_ destination: MainDestination) {
        self.destination = destination
    }

    /// Where Ayla points to: the vault, one item in it (it opens once the vault is there) or the settings.
    private func openFromAyla(_ navigation: AylaReply.Navigation) {
        switch navigation.screen {
        case .vault: open(.vault)
        case .vaultItem:
            vault.itemToOpen = navigation.itemId
            open(.vault)
        case .settings: open(.settings)
        default: break
        }
    }

    /// "Zoeken in PAVE" from the menu.
    private var searchScreen: some View {
        PaveSearchScreen(
            list: model.conversationList,
            searchMessages: model.searchMessages,
            onOpenChat: { openFromSearch($0.id) },
            onOpenProject: { project in
                if let chat = model.conversationList.chats(in: project.id).first {
                    openFromSearch(chat.id)
                } else {
                    model.newConversation(in: project)
                    destination = .ayla
                    if !isWide { showsChats = false }
                }
            },
            onOpenItem: { item in
                vault.itemToOpen = item.id
                open(.vault)
            }
        )
        .environment(vault)
    }

    /// A chat tapped in the iPhone's search.
    private func openFromSearch(_ id: String) {
        destination = .ayla
        isMenuOpen = false
        if !isWide { showsChats = false }
        let known = model.conversationList.conversations.first { $0.id == id }
        // A locked chat opens only through the PIN, and an archived one from the archive.
        if let known, (known.isLocked && !model.showsLockedChats) || known.isArchived {
            if known.isLocked { showsChats = true }
            return
        }
        let conversation = known ?? AylaConversation(id: id, title: "", updatedAt: .now)
        Task { await model.open(conversation) }
    }

    /// "Nieuw gesprek" in a plan: an empty chat that joins the plan with its first message. For a step, the text field
    /// already asks Ayla about it.
    private func startConversation(in plan: PavePlan, for step: PavePlanStep?) {
        // A plan in a project starts its chats there, so Ayla has the project's instructions and sources.
        let project = model.conversationList.projects.first { $0.id == plan.projectID }
        model.newConversation(in: project, plan: plan.id, step: step?.id)
        if let step { model.draft = PlanMessages.stepPrompt(step) }
        destination = .ayla
        isMenuOpen = false
        if !isWide { showsChats = false }
    }

    /// A question to Ayla about a plan, such as "Laat Ayla nakijken": in its latest chat, or a new one in the plan.
    private func askInPlan(_ plan: PavePlan, chatID: String?, text: String) {
        destination = .ayla
        isMenuOpen = false
        if !isWide { showsChats = false }
        if let chatID {
            let conversation = model.conversationList.conversations.first { $0.id == chatID } ?? AylaConversation(id: chatID, title: "", updatedAt: .now)
            Task {
                if model.conversationID != chatID { await model.open(conversation) }
                model.send(text)
            }
        } else {
            let project = model.conversationList.projects.first { $0.id == plan.projectID }
            model.newConversation(in: project, plan: plan.id, step: nil)
            model.send(text)
        }
    }

    /// A plan deleted together with its chats: they go as when deleted from the list of chats.
    private func deleteChats(_ ids: [String]) {
        let chats = model.conversationList.conversations.filter { ids.contains($0.id) }
        guard !chats.isEmpty else { return }
        model.delete(chats)
        // Asked and confirmed already: no undo window in a list that is not on screen.
        model.commitPendingDeletion()
    }

    /// From the menu, wherever you are: back to Ayla with an empty chat.
    private func startNewConversation() {
        model.newConversation()
        destination = .ayla
        isMenuOpen = false
        if !isWide { showsChats = false }
    }
}

#Preview {
    MainView(service: nil, vaultService: nil)
        .environment(AppState())
}

// MARK: The Watch

extension MainView {
    /// What you decide on the Watch is carried out here: an invitation answered, a plan step, an application to open.
    func connectWatch() {
        WatchEventBridge.onAnswer = { id, accepted in
            guard let application = sharing.fairApplications?.first(where: { $0.id == id }) else { return false }
            await sharing.answer(application, accepted: accepted)
            return true
        }
        WatchEventBridge.onActions = { actions in await carryOutFromWatch(actions) }
        sendPlanToWatch(plans.plans)
    }

    /// The plan you follow, or else the one changed last, for the wrist.
    func sendPlanToWatch(_ all: [PavePlan]) {
        let going = all.filter { !$0.isFinished }
        guard let plan = going.first(where: { $0.id == plans.followedPlanID }) ?? going.max(by: { $0.updatedAt < $1.updatedAt }) else { return }
        WatchEventBridge.send(.plan(name: plan.name, done: plan.doneCount, total: plan.totalCount, current: plan.currentStep?.title))
    }

    /// Actions Ayla proposed on the Watch, after Ja there. Plans and invitations change here at once; an application or
    /// plan opens on the iPhone, which says so on the wrist and lights up with a notification.
    func carryOutFromWatch(_ actions: [AylaAppAction]) async -> String {
        var said: [String] = []
        let planActions = AylaPlanActions(plans: plans, chatPlan: nil)
        for action in actions.prefix(4) {
            switch action.kind {
            case "addPlanStep":
                said.append(planActions.addStep(action.value, toPlanNamed: action.target) ?? WatchHandoffMessages.stepAdded(action.value ?? ""))
            case "markPlanStep":
                said.append(planActions.markStep(action.target, as: action.value) ?? WatchHandoffMessages.stepMarked(action.target ?? ""))
            case "answerInvitation":
                let accepted = ["yes", "ja", "on"].contains(action.value?.lowercased() ?? "")
                guard let application = AylaPlanActions.invitation(action.target, in: sharing.fairApplications ?? []) else {
                    said.append(AylaMessages.actionNoInvitation(action.target ?? ""))
                    continue
                }
                await sharing.answer(application, accepted: accepted)
                said.append(AylaMessages.actionInvitationAnswered(FairApplicationDetail.employerName(application), accepted: accepted))
            case "openApplication", "makeVacancyPlan":
                guard let vacancy = vacancyFromWatch(action.target) else {
                    said.append(WatchHandoffMessages.noVacancy(action.target ?? ""))
                    continue
                }
                if action.kind == "makeVacancyPlan" {
                    let template = PlanVacancy.template(for: vacancy)
                    if plans.plans.contains(where: { PlanVacancy.vacancyID(of: $0) == vacancy.id }) == false {
                        _ = await plans.create(name: template.name, goal: template.goal, from: template)
                    }
                    handOff(title: WatchHandoffMessages.planReady(vacancy), detail: WatchHandoffMessages.onIPhone)
                    open(.plan)
                } else {
                    handOff(title: WatchHandoffMessages.applicationReady(vacancy), detail: WatchHandoffMessages.onIPhone)
                    model.request(.application(vacancy))
                    open(.ayla)
                }
                said.append(WatchHandoffMessages.onIPhone)
            case "addToCalendar":
                guard let moment = AylaCalendarMoment(title: action.target ?? "", value: action.value ?? "") else {
                    said.append(AylaMessages.actionBadDate)
                    continue
                }
                calendarFromWatch = moment
                handOff(title: moment.title, detail: WatchHandoffMessages.calendarOnIPhone)
                said.append(WatchHandoffMessages.calendarOnIPhone)
            case "openPlan":
                guard let plan = planActions.plan(named: action.target) else {
                    said.append(AylaMessages.actionNoPlan(action.target))
                    continue
                }
                plans.openPlanID = plan.id
                open(.plan)
                handOff(title: plan.name, detail: WatchHandoffMessages.onIPhone)
                said.append(WatchHandoffMessages.onIPhone)
            default:
                said.append(WatchHandoffMessages.onlyOnIPhone)
            }
        }
        return said.joined(separator: " ")
    }

    /// A vacancy by the words said on the Watch: an application you have, one you kept, or one Ayla found last.
    func vacancyFromWatch(_ words: String?) -> Vacancy? {
        let known = ApplicationStore().all().map(\.vacancy) + model.savedVacancies.map(\.vacancy) + model.latestVacancySearch.vacancies
        let named = known.map { AylaAppCommand.Named(id: $0.id, name: "\($0.title) \($0.company)") }
        if let found = AylaAppAction.best(words, in: named) { return known.first { $0.id == found.id } }
        return words?.isEmpty != false ? known.first : nil
    }

    /// The iPhone lights up, and the wrist says it is ready there.
    func handOff(title: String, detail: String) {
        WatchEventBridge.send(.handoff(title: title, detail: detail))
        Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = WatchHandoffMessages.fromWatch
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: "watch.handoff.\(UUID().uuidString)", content: content, trigger: nil))
        }
    }
}

/// The words of what was set up from the Watch.
enum WatchHandoffMessages {
    static let onIPhone = "Het staat klaar op je iPhone."
    static let fromWatch = "Klaargezet door Ayla, vanaf je Watch."
    static let onlyOnIPhone = "Dat kan alleen op je iPhone."
    static let calendarOnIPhone = "Open je iPhone om het in je agenda te bewaren."
    static func stepAdded(_ title: String) -> String { "Ik heb de stap \(title) toegevoegd." }
    static func stepMarked(_ title: String) -> String { "Ik heb de stap \(title) bijgewerkt." }
    static func noVacancy(_ words: String) -> String { "Ik vond geen vacature bij \(words). Open hem op je iPhone." }
    static func applicationReady(_ vacancy: Vacancy) -> String { "Je cv en brief voor \(vacancy.company)" }
    static func planReady(_ vacancy: Vacancy) -> String { "Je plan voor \(vacancy.company)" }
}

/// When knopmodus should run: chosen, PAVE in front, and unlocked.
private struct PollingState: Equatable {
    let isActive: Bool
    let isOpen: Bool
}

private struct CameraControlWanted: Equatable {
    let isEnabled: Bool
    let changed: Int
    let isActive: Bool
    let isOpen: Bool
}
