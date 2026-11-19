import PAVECore
import SwiftUI

/// The app after signing in. You can go to Ayla, your vault or your plans yourself with the menu, laid out like
/// ChatGPT: on a wide screen (iPad, the open iPhone Duo held sideways) it is a sidebar next to the screen that you
/// can hide and bring back; elsewhere (iPhone, the open iPhone Duo held upright, its outer display) it slides over
/// the screen from the menu button. When iPhone Duo is partly folded, the menu fills the pane on one side of the fold
/// and the screen the pane on the other, so nothing sits in the fold.
struct MainView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AylaSpotlight.settingKey) private var chatsInSpotlight = false
    @State private var model: AylaChatModel
    @State private var memory: AylaMemoryModel
    @State private var vault: VaultModel
    @State private var devices: SignedInDevicesModel
    @State private var profile: ProfileModel
    @Environment(\.dynamicTypeSize) private var deviceTextSize
    @State private var watchConnection = WatchConnectionModel()
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
    private let connection = PaveConnection.shared

    /// Wide enough to show the chats next to the conversation.
    private static let wideWidth: CGFloat = 860
    /// Wide enough for the sidebar next to the screen, as ChatGPT does on the open iPhone Duo held sideways.
    private static let sidebarWidth: CGFloat = 800
    private static let sidebarSize: CGFloat = 320

    init(service: (any AylaService)?, vaultService: (any VaultService)?, devicesService: (any DevicesService)? = nil, profileService: (any ProfileService)? = nil) {
        _model = State(initialValue: AylaChatModel(service: service, drafts: .standard, pendingFiles: .standard))
        _memory = State(initialValue: AylaMemoryModel(service: service))
        _vault = State(initialValue: VaultModel(service: vaultService))
        _devices = State(initialValue: SignedInDevicesModel(service: devicesService))
        _profile = State(initialValue: ProfileModel(service: profileService))
    }

    var body: some View {
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
        .dynamicTypeSize(deviceTextSize.shifted(by: profile.textSize))
        .task { await profile.load() }
        .onChange(of: profile.profile.displayName) { _, name in
            if let name { model.nameChanged(name) }
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
        .environment(cameraControl)
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
        .task { await memory.load() }
        .task { await model.followConversationChanges() }
        .onChange(of: hasSidebar) { isMenuOpen = false }
        // A deleted chat that could still be brought back is really deleted when the app goes away.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                model.commitPendingDeletion()
                memory.commitPendingForget()
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
        .onChange(of: appState.isRelocked) { handlePending() }
        .onChange(of: connection.isOnline) { _, isOnline in
            if isOnline { Task { await model.refreshConversations() } }
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
        startNewConversation()
        if link == .talk { talk() }
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
                .environment(vault)
                // Settings can open over the chat when you ask Ayla for them.
                .environment(devices)
                .environment(profile)
                .environment(watchConnection)
                .environment(\.openFromAyla, openFromAyla)
        case .vault:
            VaultScreen(onShowMenu: onShowMenu)
                .environment(vault)
                .environment(\.askAylaAbout) { item in
                    model.ask(about: item)
                    open(.ayla)
                }
        case .plan:
            PlanScreen(onShowMenu: onShowMenu)
        case .profile:
            ProfileScreen(onShowMenu: onShowMenu)
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
            NotificationsScreen(onShowMenu: onShowMenu)
        }
    }

    private func setSidebarHidden(_ isHidden: Bool) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4, bounce: 0.1)) {
            isSidebarHidden = isHidden
        }
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

/// When knopmodus should run: chosen, PAVE in front, and unlocked.
private struct CameraControlWanted: Equatable {
    let isEnabled: Bool
    let changed: Int
    let isActive: Bool
    let isOpen: Bool
}
