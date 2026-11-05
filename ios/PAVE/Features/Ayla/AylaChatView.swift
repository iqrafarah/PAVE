import PAVECore
import SwiftUI

struct AylaChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model: AylaChatModel
    @State private var showsConversations = false
    @State private var stableSize: CGSize = .zero
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @FocusState private var isComposerFocused: Bool

    init(service: (any AylaService)?) {
        _model = State(initialValue: AylaChatModel(service: service))
    }

    var body: some View {
        GeometryReader { proxy in
            let mode = AdaptiveMode.resolve(
                size: proxy.size,
                stableSize: stableSize == .zero ? proxy.size : stableSize,
                sizeClass: sizeClass,
                fold: proxy.foldSplit()
            )
            switch mode {
            case .compact:
                chat(showsMenu: true)
            case .card:
                chat(showsMenu: true, maxWidth: 680)
            case .split(let split):
                SplitPanes(split: split) {
                    conversationList(closesSheet: false)
                } second: {
                    chat(showsMenu: false)
                }
                .background(Color.canvas)
            }
        }
        .trackingStableSize($stableSize)
        .sheet(isPresented: $showsConversations) {
            conversationList(closesSheet: true)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task { await model.start() }
    }

    // MARK: Chat column

    private func chat(showsMenu: Bool, maxWidth: CGFloat = .infinity) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                AylaHeader(showsMenu: showsMenu, onMenu: { showsConversations = true }, onNewConversation: startNewConversation)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
                    .frame(maxWidth: min(maxWidth, 560))
                    .frame(maxWidth: .infinity)
            }
            .background { background.ignoresSafeArea() }
            .animation(.easeInOut(duration: 0.35), value: model.phase)
    }

    @ViewBuilder
    private var content: some View {
        if model.entries.isEmpty, !model.isLoadingConversation {
            ScrollView {
                AylaWelcome(firstName: model.firstName, isAvailable: model.isAvailable, onStarter: model.send)
                    .containerRelativeFrame(.vertical) { height, _ in height * 0.8 }
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            transcript
        }
    }

    private var transcript: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(model.entries.enumerated()), id: \.element.id) { index, entry in
                    let startsTurn = index > 0 && model.entries[index - 1].role != entry.role
                    entryView(entry)
                        .padding(.top, index == 0 ? 0 : (startsTurn ? 25 : 12))
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: model.entries.count) {
            withAnimation(.easeOut(duration: 0.3)) { scrollPosition.scrollTo(edge: .bottom) }
        }
    }

    @ViewBuilder
    private func entryView(_ entry: AylaChatModel.Entry) -> some View {
        switch entry.role {
        case .user:
            ChatBubble(text: entry.text, speaker: .user)
        case .ayla:
            VStack(alignment: .leading, spacing: 12) {
                ChatBubble(text: entry.text, speaker: .ayla(showsMark: entry.id == model.lastAylaEntryID))
                if let question = entry.reply?.question, !question.text.isEmpty {
                    ChatBubble(text: question.text, speaker: .ayla(showsMark: false))
                }
                if let screen = entry.reply?.navigation?.screen, screen != .chat {
                    Text("Dit onderdeel komt later in de app.")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.leading, 4)
                }
                ForEach(Array((entry.reply?.blocks ?? []).enumerated()), id: \.offset) { _, block in
                    if case .vacancies(let vacancies) = block, !vacancies.isEmpty {
                        VacancyPanel(vacancies: vacancies)
                            .padding(.horizontal, -32)
                            .padding(.top, 12)
                    }
                }
            }
        }
    }

    // MARK: Bottom

    private var bottomBar: some View {
        VStack(spacing: 22) {
            switch model.phase {
            case .thinking:
                AylaStatusIndicator(state: .thinking, message: "Ayla denkt na")
                    .transition(.opacity)
            case .failed(let message):
                VStack(spacing: 6) {
                    AylaStatusIndicator(state: .failed, message: message)
                    Button("Opnieuw proberen", action: model.retry)
                        .textStyle(.link)
                        .foregroundStyle(Color.criticalInk)
                        .frame(minHeight: 44)
                        .buttonStyle(.plain)
                }
                .transition(.opacity)
            case .idle:
                EmptyView()
            }

            if let question = model.pendingQuestion, question.choices.count >= 2 {
                AylaChoiceBar(choices: question.choices.map { AylaChoice(id: $0.id, label: $0.label) }) { choice in
                    model.send(choice.label)
                }
            } else {
                AylaComposer(
                    text: $model.draft,
                    isEnabled: model.isAvailable && model.phase != .thinking,
                    isFocused: $isComposerFocused
                ) {
                    model.send(model.draft)
                }
            }
        }
        .padding(.horizontal, 21)
        .padding(.top, 12)
        .padding(.bottom, 8)
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

    // MARK: Conversations

    private func conversationList(closesSheet: Bool) -> some View {
        ConversationList(
            conversations: model.conversations,
            currentID: model.conversationID,
            onNew: {
                startNewConversation()
                if closesSheet { showsConversations = false }
            },
            onOpen: { conversation in
                if closesSheet { showsConversations = false }
                Task { await model.open(conversation) }
            },
            onSignOut: {
                showsConversations = false
                appState.signOut()
            }
        )
        .task { await model.refreshConversations() }
    }

    private func startNewConversation() {
        model.newConversation()
        isComposerFocused = true
    }
}

#Preview {
    AylaChatView(service: nil)
        .environment(AppState())
}
