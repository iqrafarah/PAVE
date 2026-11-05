import PAVECore
import SwiftUI

/// The conversation with Ayla (Figma frames "Ayla"). On iPhone vacancies slide up in a panel;
/// on the inner display of iPhone Duo and on iPad they open in a column next to the chat.
struct AylaChatScreen: View {
    @Bindable var model: AylaChatModel
    let onShowConversations: () -> Void

    /// The navigation bar sits 4 pt higher than the header in Figma.
    private static let toolbarOffset: CGFloat = 4

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var dictation = SpeechDictation()
    @State private var openVacanciesID: String?
    @State private var bottomBarHeight: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @FocusState private var isComposerFocused: Bool

    private var isCompact: Bool { sizeClass != .regular }

    private var openVacancies: [Vacancy]? {
        guard let openVacanciesID, let entry = model.entries.first(where: { $0.id == openVacanciesID }) else { return nil }
        return Self.vacancies(in: entry)
    }

    var body: some View {
        GeometryReader { proxy in
            let fullHeight = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            let sheetHeight = (fullHeight * 0.612).rounded()
            let showsSheet = isCompact && openVacancies != nil

            ZStack(alignment: .bottom) {
                content(
                    height: proxy.size.height,
                    bottomMargin: showsSheet ? sheetHeight - proxy.safeAreaInsets.bottom : bottomBarHeight + bottomGap
                )

                if showsSheet, let vacancies = openVacancies {
                    AylaBottomSheet(
                        title: "Vacatures sluiten",
                        height: sheetHeight,
                        expandedHeight: fullHeight - proxy.safeAreaInsets.top - 24,
                        bottomInset: bottomBarHeight + proxy.safeAreaInsets.bottom + 16,
                        onClose: closeVacancies
                    ) {
                        VacancyList(vacancies: vacancies)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }

                bottomBar(placeholder: placeholderColor(sheetOpen: showsSheet), isOverPanel: showsSheet)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bottomBarHeight = $0 }
            }
            .overlay(alignment: .top) {
                if !model.entries.isEmpty {
                    AylaHeaderPanel()
                        .frame(height: proxy.safeAreaInsets.top + 17)
                        .padding(.leading, -proxy.safeAreaInsets.leading)
                        .padding(.trailing, -proxy.safeAreaInsets.trailing)
                        .offset(y: -proxy.safeAreaInsets.top)
                        .allowsHitTesting(false)
                }
            }
        }
        .background { background.ignoresSafeArea() }
        .animation(.easeInOut(duration: 0.35), value: model.phase)
        .animation(.spring(duration: 0.4), value: openVacanciesID)
        .toolbar { toolbar }
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .inspector(isPresented: inspectorBinding) {
            ScrollView {
                VacancyList(vacancies: openVacancies ?? [])
                    .padding(20)
            }
            .background(Color.white)
            .inspectorColumnWidth(min: 320, ideal: 400, max: 480)
        }
        .onChange(of: model.entries.last?.id) {
            guard let last = model.entries.last, last.role == .ayla, !Self.vacancies(in: last).isEmpty else { return }
            openVacanciesID = last.id
        }
        .alert("Inspreken", isPresented: dictationProblemBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dictation.problem == .notAllowed ? AylaMessages.speechNotAllowed : AylaMessages.speechUnavailable)
        }
    }

    // MARK: Header

    /// Standard toolbar buttons with the Figma icons. iOS draws them as glass circles, and on iPhone Duo
    /// it moves them into the bar along the side, under the status bar.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: onShowConversations) {
                Image(.iconMenu)
            }
            .accessibilityLabel("Gesprekken")
        }
        ToolbarItem(placement: .principal) {
            AylaTitle()
                .offset(y: Self.toolbarOffset)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: startNewConversation) {
                Image(.iconChat)
            }
            .accessibilityLabel("Nieuw gesprek")
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(height: CGFloat, bottomMargin: CGFloat) -> some View {
        if model.entries.isEmpty, !model.isLoadingConversation {
            ScrollView {
                AylaWelcome(firstName: model.firstName, isAvailable: model.isAvailable, onStarter: model.send)
                    .padding(.top, (height * 0.174).rounded())
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: bottomMargin) }
        } else {
            transcript(bottomMargin: bottomMargin)
        }
    }

    private func transcript(bottomMargin: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(model.entries.enumerated()), id: \.element.id) { index, entry in
                    let startsTurn = index > 0 && model.entries[index - 1].role != entry.role
                    entryView(entry)
                        .padding(.top, index == 0 ? 0 : (startsTurn ? 25 : 12))
                }
            }
            .padding(.leading, 32)
            .padding(.trailing, 33)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .contentMargins(.top, 32, for: .scrollContent)
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: bottomMargin).allowsHitTesting(false) }
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .alignment)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: model.entries.count) { scrollToBottom() }
        .onChange(of: openVacanciesID) { scrollToBottom() }
        .onChange(of: bottomBarHeight) { scrollToBottom() }
    }

    @ViewBuilder
    private func entryView(_ entry: AylaChatModel.Entry) -> some View {
        switch entry.role {
        case .user:
            ChatBubble(text: entry.text, speaker: .user)
        case .ayla:
            VStack(alignment: .leading, spacing: 12) {
                ChatBubble(text: entry.text, speaker: .ayla(showsMark: entry.id == model.lastAylaEntryID && !isFailed))
                if let question = entry.reply?.question, !question.text.isEmpty {
                    ChatBubble(text: question.text, speaker: .ayla(showsMark: false))
                }
                if let screen = entry.reply?.navigation?.screen, screen != .chat {
                    Text("Dit onderdeel komt later in de app.")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.leading, 4)
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

    // MARK: Bottom

    private func bottomBar(placeholder: Color, isOverPanel: Bool) -> some View {
        VStack(spacing: 0) {
            switch model.phase {
            case .thinking:
                AylaStatusIndicator(state: .thinking, message: "Ayla denkt na")
                    .padding(.bottom, 41)
                    .transition(.opacity)
            case .failed(let message):
                AylaStatusIndicator(state: .failed, message: message)
                    .padding(.horizontal, 32)
                    .padding(.bottom, model.pendingQuestion == nil ? 41 : 35.7)
                    .transition(.opacity)
            case .idle:
                EmptyView()
            }

            if let question = model.pendingQuestion, question.choices.count >= 2 {
                AylaChoiceBar(choices: question.choices.map { AylaChoice(id: $0.id, label: $0.label) }) { choice in
                    model.send(choice.label)
                }
                .padding(.leading, 21)
                .padding(.trailing, 22)
                .padding(.bottom, -11)
            } else {
                AylaComposer(
                    text: $model.draft,
                    isEnabled: model.isAvailable && model.phase != .thinking,
                    isListening: dictation.isListening,
                    placeholderColor: placeholder,
                    isOverPanel: isOverPanel,
                    isFocused: $isComposerFocused,
                    onQuickAction: { model.send($0.question) },
                    onMicrophone: toggleDictation,
                    onSend: send
                )
                .padding(.leading, 33)
                .padding(.trailing, 31)
            }
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    /// Space between the last message and what is below it, as in Figma.
    private var bottomGap: CGFloat {
        switch model.phase {
        case .idle: 12
        case .thinking: 47
        case .failed: 41
        }
    }

    private func placeholderColor(sheetOpen: Bool) -> Color {
        if sheetOpen { return Color.black.opacity(0.41) }
        return model.phase == .idle ? Color.inkMuted.opacity(0.41) : Color.white.opacity(0.41)
    }

    @ViewBuilder
    private var background: some View {
        switch model.phase {
        case .idle:
            Color.canvas
        case .thinking:
            LinearGradient(stops: [.init(color: .canvas, location: 0.658), .init(color: .thinkingGlow, location: 1)], startPoint: .top, endPoint: .bottom)
        case .failed:
            LinearGradient(stops: [.init(color: .canvas, location: 0.658), .init(color: .errorGlow, location: 1)], startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: Actions

    private var isFailed: Bool {
        if case .failed = model.phase { true } else { false }
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { !isCompact && openVacancies != nil },
            set: { if !$0 { openVacanciesID = nil } }
        )
    }

    private var dictationProblemBinding: Binding<Bool> {
        Binding(get: { dictation.problem != nil }, set: { if !$0 { dictation.problem = nil } })
    }

    private func send() {
        dictation.stop()
        model.send(model.draft)
    }

    private func startNewConversation() {
        dictation.stop()
        openVacanciesID = nil
        model.newConversation()
        isComposerFocused = true
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

    private func toggleDictation() {
        if dictation.isListening {
            dictation.stop()
            return
        }
        let prefix = model.draft.isEmpty ? "" : model.draft + " "
        let model = model
        Task {
            await dictation.start { text in model.draft = prefix + text }
        }
    }

    private static func vacancies(in entry: AylaChatModel.Entry) -> [Vacancy] {
        (entry.reply?.blocks ?? []).flatMap { block -> [Vacancy] in
            if case .vacancies(let items) = block { items } else { [] }
        }
    }
}
