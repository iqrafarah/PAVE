import PAVECore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// One e-mail conversation, laid out like Messages: their bubbles grey on the left, yours in PAVE's colour on the
/// right, photos as pictures, and a reply field at the bottom. Tap the name at the top for everything you shared.
/// A locked conversation first asks for your PIN.
struct EmailThreadScreen: View {
    let threadID: String

    @Environment(EmailModel.self) private var email
    @Environment(VaultModel.self) private var vault: VaultModel?
    @Environment(AylaChatModel.self) private var ayla: AylaChatModel?
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var draft = ""
    /// Speaking into the reply field, as in Ayla's chat: the words show in the field and you send them yourself.
    @State private var dictation = SpeechDictation()
    @State private var draftBeforeDictation = ""
    @State private var files: [EmailOutgoingAttachment] = []
    @State private var isSending = false
    @State private var sendError: String?
    @State private var previewURL: URL?
    @State private var openingAttachmentID: String?
    @State private var isChoosingFile = false
    @State private var isChoosingPhotos = false
    @State private var isChoosingFromVault = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showsPerson = false
    @State private var deletingMessage: EmailMessage?
    /// Who the next reply goes to; nil is everyone on the newest message.
    @State private var replyTarget: EmailReplyTarget?
    @State private var forwarding: EmailForwarding?
    @State private var formatted: EmailMessage?
    /// Asked once: after this the ✨ in the reply field goes straight to Ayla.
    @AppStorage("emailAylaAllowed") private var aylaAllowed = false
    /// Waiting for the yes above.
    @State private var askingAyla: EmailAylaTask?
    @State private var aylaWorking: EmailAylaTask?
    @State private var summary: String?
    @State private var vaultFlow: VaultAddEvidenceModel?
    @State private var choosesLockPin = false
    @FocusState private var isReplyFocused: Bool
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    @State private var isAwayFromBottom = false

    private var thread: EmailThread? { email.thread(threadID) }
    private var isHidden: Bool { thread.map(email.isHidden) ?? false }

    var body: some View {
        Group {
            if let thread {
                if isHidden {
                    EmailLockGate {}
                } else {
                    conversation(thread)
                }
            } else {
                PaveEmptyState(icon: .iconEnvelopeSolid, title: "Gesprek niet gevonden", message: "Het staat niet meer in je mailbox.")
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { header }
            if let thread, !isHidden {
                ToolbarItem(placement: .topBarTrailing) { moreMenu(thread) }
            }
        }
        .navigationDestination(isPresented: $showsPerson) {
            if let thread, let person = thread.participants.first {
                EmailPersonScreen(person: person, groupThreadID: thread.participants.count > 1 ? thread.id : nil)
            }
        }
        .task(id: "\(threadID):\(isHidden)") {
            guard !isHidden else { return }
            isLoading = true
            await email.open(threadID)
            isLoading = false
            // The texts just came in and made the conversation taller: the newest message again, at the bottom.
            scrollToBottom(animated: false)
        }
        .confirmationDialog(
            "Dit bericht verwijderen?",
            isPresented: Binding(get: { deletingMessage != nil }, set: { if !$0 { deletingMessage = nil } }),
            titleVisibility: .visible,
            presenting: deletingMessage
        ) { message in
            Button("Verwijderen", role: .destructive) {
                PaveHaptics.tap(.medium)
                Task { await email.delete(message, in: threadID) }
            }
            Button("Annuleren", role: .cancel) {}
        } message: { _ in
            Text("Het gaat naar de prullenmand van je iCloud-mailbox. Daar kun je het in Mail nog terugzetten.")
        }
        .vaultQuickLook($previewURL)
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            guard case let .success(urls) = result else { return }
            for url in urls {
                if let file = EmailOutgoingAttachment.file(at: url) { files.append(file) } else {
                    sendError = "\(url.lastPathComponent) kon niet worden geopend."
                }
            }
        }
        .photosPicker(isPresented: $isChoosingPhotos, selection: $photoItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    if let photo = await EmailOutgoingAttachment.photo(item, number: files.count + 1) { files.append(photo) }
                }
                photoItems = []
            }
        }
        .sheet(isPresented: $isChoosingFromVault) {
            EmailVaultPicker { files.append(contentsOf: $0) }
        }
        .sheet(item: $forwarding) { forwarding in
            EmailComposeSheet(forwarding: forwarding)
        }
        .sheet(item: $formatted) { message in
            if let html = message.html { EmailFormattedSheet(message: message, html: html) }
        }
        .confirmationDialog(
            "De mail aan Ayla laten zien?",
            isPresented: Binding(get: { askingAyla != nil }, set: { if !$0 { askingAyla = nil } }),
            titleVisibility: .visible,
            presenting: askingAyla
        ) { task in
            Button("Vraag Ayla") {
                aylaAllowed = true
                Task { await runAyla(task) }
            }
            Button("Annuleren", role: .cancel) {}
        } message: { _ in
            Text("Hiervoor gaat de tekst van dit gesprek naar Ayla, met de namen en adressen erin. Ze gebruikt hem alleen hiervoor; er komt geen chat van bij je chats. Ayla kan fouten maken, dus lees na wat ze schrijft.")
        }
        .sheet(item: $vaultFlow) { flow in
            VaultAddEvidenceSheet(flow: flow)
                .paveSheet()
        }
        .sheet(isPresented: $choosesLockPin) {
            NavigationStack {
                EmailLockGate(purpose: .lock) {
                    choosesLockPin = false
                    lock()
                }
                .navigationTitle("Gesprek vergrendelen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { choosesLockPin = false } }
                }
            }
            .tint(.paveAccent)
        }
    }

    /// The person's photo with their name under it, as in Messages; tapping opens what you shared.
    private var header: some View {
        Button { showsPerson = true } label: {
            VStack(spacing: 2) {
                if !isHidden, let people = thread?.participants, !people.isEmpty {
                    EmailAvatarStack(people: people)
                }
                HStack(spacing: 3) {
                    Text(isHidden ? "Vergrendeld gesprek" : thread?.participantNames ?? "E-mail")
                        .textStyle(.meta)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    if !isHidden {
                        Image(.iconChevronRight)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 6, height: 6)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
            }
        }
        .buttonStyle(.pave)
        .disabled(isHidden || thread?.participants.isEmpty != false)
        .accessibilityLabel(isHidden ? "Vergrendeld gesprek" : "\(thread?.participantNames ?? "E-mail"), bekijk gedeelde foto's en bestanden")
    }

    /// Dempen, vergrendelen, Ayla and doorsturen, behind the round … at the top right.
    private func moreMenu(_ thread: EmailThread) -> some View {
        Menu {
            Section {
                Button { askAyla(.summarize) } label: { Label("Laat Ayla samenvatten", systemImage: "sparkles") }
                    .disabled(ayla?.service == nil || aylaWorking != nil)
                Button { askAyla(.suggestReply) } label: { Label("Laat Ayla een antwoord voorstellen", systemImage: "text.bubble.fill") }
                    .disabled(ayla?.service == nil || aylaWorking != nil)
            }
            Section {
                Button { forwarding = EmailForwarding(messages: thread.messages) } label: {
                    Label(thread.messages.count == 1 ? "Doorsturen" : "Gesprek doorsturen", systemImage: "arrowshape.turn.up.right.fill")
                }
                Button {
                    PaveHaptics.selection()
                    email.toggleMute(threadID)
                } label: {
                    if email.isMuted(thread) {
                        Label("Dempen opheffen", systemImage: "bell.fill")
                    } else {
                        Label("Dempen", systemImage: "bell.slash.fill")
                    }
                }
                if email.isLocked(thread) {
                    Button {
                        PaveHaptics.selection()
                        email.setLocked(false, threadID)
                    } label: { Label("Ontgrendelen", tinted: .iconLockOpenSolid) }
                } else {
                    Button { startLocking() } label: { Label("Vergrendelen", tinted: .iconLockClosedSolid) }
                        .disabled(ayla?.service == nil)
                }
            } footer: {
                if email.isMuted(thread) { Text("Je krijgt geen banner voor dit gesprek.") }
            }
        } label: {
            Image(.iconEllipsis)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.ink)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Meer")
    }

    private func conversation(_ thread: EmailThread) -> some View {
        let layouts = EmailBubbleLayout.make(thread.messages)
        let lastSentID = thread.messages.last(where: \.isFromMe)?.id
        let me = email.account(for: thread.provider)?.address ?? ""
        return ScrollView {
            LazyVStack(spacing: 2) {
                if !thread.subject.isEmpty {
                    Text(thread.subject)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.top, 8)
                }
                if email.isMuted(thread) {
                    Label("Gedempt", systemImage: "bell.slash.fill")
                        .textStyle(.meta)
                        .foregroundStyle(Color.inkMuted)
                }
                if let problem = email.problem {
                    PaveInlineError(message: problem)
                }
                ForEach(Array(zip(thread.messages, layouts)), id: \.0.id) { message, layout in
                    let hasOthers = EmailReplyRecipients(replyingTo: message, as: me).everyone.count > 1
                    EmailMessageRow(
                        message: message,
                        layout: layout,
                        isGroup: thread.participants.count > 1,
                        showsSent: message.id == lastSentID && thread.messages.last?.id == lastSentID,
                        isLoading: isLoading && !message.isLoaded,
                        openingAttachmentID: openingAttachmentID,
                        onOpenAttachment: { attachment in Task { await open(attachment, of: message) } },
                        onDelete: { deletingMessage = message },
                        onReply: { reply(to: message, onlySender: true) },
                        onReplyAll: hasOthers ? { reply(to: message, onlySender: false) } : nil,
                        onForward: { forwarding = EmailForwarding(messages: [message]) },
                        onSaveToVault: vault == nil ? nil : { attachment in Task { await saveToVault(attachment, of: message) } },
                        onShowFormatted: message.html == nil ? nil : { formatted = message }
                    )
                    .id(message.id)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .scrollDismissesKeyboard(.interactively)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentSize.height - geometry.visibleRect.maxY > 160
        } action: { _, isAway in
            isAwayFromBottom = isAway
        }
        .onChange(of: thread.messages.count) {
            scrollToBottom(animated: true)
            // An answer came in while you are here: its text, and it is read.
            Task { await email.open(threadID) }
        }
        .onAppear { email.openThreadID = threadID }
        .onDisappear {
            dictation.stop()
            if email.openThreadID == threadID { email.openThreadID = nil }
        }
        .alert("Inspreken", isPresented: Binding(get: { dictation.problem != nil }, set: { if !$0 { dictation.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dictation.problem == .notAllowed ? AylaMessages.speechNotAllowed : AylaMessages.speechUnavailable)
        }
        .sensoryFeedback(trigger: dictation.isListening) { _, isListening in isListening ? .start : .stop }
        // On the conversation, not on the bar: laid out inside the safe area the bar below leaves, its bottom edge is the
        // top of the reply bar, so the button sits just above the field.
        .overlay(alignment: .bottom) {
            if isAwayFromBottom {
                ChatScrollDownButton { scrollToBottom(animated: true) }
                    .padding(.bottom, 10)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: isAwayFromBottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer(thread)
        }
    }

    /// Twice: a lazy list only knows its real height once the last rows have been laid out.
    private func scrollToBottom(animated: Bool) {
        Task {
            await Task.yield()
            withAnimation(animated ? .easeOut(duration: 0.3) : nil) { scrollPosition.scrollTo(edge: .bottom) }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(animated ? .easeOut(duration: 0.3) : nil) { scrollPosition.scrollTo(edge: .bottom) }
        }
    }

    // MARK: Reply

    private var canSend: Bool {
        !isSending && aylaWorking == nil && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !files.isEmpty)
    }

    private func reply(to message: EmailMessage, onlySender: Bool) {
        replyTarget = EmailReplyTarget(message: message, onlySender: onlySender)
        isReplyFocused = true
    }

    /// Who the reply goes to, in words: "iedereen" or one name.
    private func recipientsLabel(_ thread: EmailThread) -> String {
        guard let replyTarget else { return thread.participantNames }
        let me = email.account(for: thread.provider)?.address ?? ""
        let people = replyTarget.recipients(as: me).everyone
        return people.isEmpty ? thread.participantNames : people.map(\.displayName).joined(separator: ", ")
    }

    /// Only after "Antwoord" or "Allen antwoorden" on one message (hold it): who the reply goes to, and a way back. Without
    /// that choice a reply simply goes to everyone, as in a group chat.
    @ViewBuilder
    private func recipientsBar(_ thread: EmailThread) -> some View {
        let senders = EmailReplyTarget.senders(in: thread)
        if replyTarget != nil {
            HStack(spacing: 6) {
                Menu {
                    Button { replyTarget = nil } label: { Label("Aan iedereen", tinted: .iconUserGroupSolid) }
                    ForEach(senders, id: \.id) { message in
                        Button { replyTarget = EmailReplyTarget(message: message, onlySender: true) } label: {
                            Label("Alleen aan \(message.from.displayName)", tinted: .iconUserSolid)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(replyTarget?.onlySender == true ? "Aan: \(recipientsLabel(thread))" : "Aan: iedereen")
                            .textStyle(.meta)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                        Image(.iconChevronDown)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 8, height: 8)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(Color.panel, in: .capsule)
                    .overlay { Capsule().strokeBorder(Color.cardBorder) }
                }
                .accessibilityLabel("Antwoord aan \(recipientsLabel(thread)), wijzigen")
                if replyTarget != nil {
                    Button { replyTarget = nil } label: {
                        Image(.iconXMark)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 9, height: 9)
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.pave)
                    .accessibilityLabel("Terug naar antwoorden aan iedereen")
                }
                Spacer(minLength: 0)
            }
            // In line with the rounded edge of the field below.
            .padding(.leading, 12)
        }
    }

    private func composer(_ thread: EmailThread) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let sendError {
                PaveInlineError(message: sendError)
            }
            if let summary { summaryCard(summary) }
            recipientsBar(thread)
            if dictation.isListening, let startedAt = dictation.startedAt {
                // While you speak the recording bar takes the field's place, as in Ayla's chat. ✓ keeps the text in the
                // field to read and send yourself; ✕ throws it away.
                AylaDictationBar(text: draft, meter: dictation.meter, startedAt: startedAt, onCancel: cancelDictation, onDone: { dictation.stop() })
                    .transition(.opacity)
            } else {
                EmailReplyField(
                    text: $draft, files: $files, isSending: isSending, canSend: canSend,
                    label: "Antwoord aan \(recipientsLabel(thread))", focus: $isReplyFocused,
                    aylaWorking: aylaWorking,
                    onAyla: ayla?.service == nil ? nil : { askAyla($0) },
                    attach: EmailAttachMenu(
                        onPhotos: { isChoosingPhotos = true },
                        onFile: { isChoosingFile = true },
                        onVault: { isChoosingFromVault = true }
                    ),
                    isListening: dictation.isListening,
                    onMicrophone: toggleDictation
                ) {
                    Task { await send() }
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: dictation.isListening)
        // Where Ayla's composer is in her chat: the glass field floats over the conversation, without a bar behind it.
        .padding(.leading, 33)
        .padding(.trailing, 31)
        .padding(.vertical, 8)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    private func toggleDictation() {
        if dictation.isListening {
            dictation.stop()
            return
        }
        draftBeforeDictation = draft
        let prefix = draft.isEmpty ? "" : draft + " "
        Task { await dictation.start { text in draft = prefix + text } }
    }

    private func cancelDictation() {
        dictation.stop()
        draft = draftBeforeDictation
    }

    private func send() async {
        guard canSend else { return }
        dictation.stop()
        isSending = true
        sendError = nil
        do {
            try await email.reply(
                in: threadID, text: draft.trimmingCharacters(in: .whitespacesAndNewlines), attachments: files,
                to: replyTarget?.message, onlySender: replyTarget?.onlySender ?? false
            )
            draft = ""
            files = []
            replyTarget = nil
            PaveHaptics.success()
        } catch {
            sendError = (error as? LocalizedError)?.errorDescription ?? "Je antwoord kon niet worden verstuurd. Probeer opnieuw."
            PaveHaptics.error()
        }
        isSending = false
    }

    private func open(_ attachment: EmailAttachment, of message: EmailMessage) async {
        openingAttachmentID = attachment.id
        defer { openingAttachmentID = nil }
        do {
            let data = try await email.attachmentData(attachment, of: message)
            previewURL = VaultPreviewFile.url(for: data, named: attachment.name)
        } catch {
            sendError = (error as? LocalizedError)?.errorDescription ?? "\(attachment.name) kon niet worden geopend."
        }
    }

    // MARK: Ayla

    private func askAyla(_ task: EmailAylaTask) {
        if aylaAllowed {
            Task { await runAyla(task) }
        } else {
            askingAyla = task
        }
    }

    /// A reply lands in the reply field, to change and send yourself; a summary as a card above it.
    private func runAyla(_ task: EmailAylaTask) async {
        guard let service = ayla?.service, let thread, aylaWorking == nil else { return }
        aylaWorking = task
        sendError = nil
        defer { aylaWorking = nil }
        do {
            let text = try await EmailAylaHelper(service: service).run(task, on: thread, wish: draft)
            switch task {
            case .suggestReply, .improve:
                draft = text
                isReplyFocused = true
            case .summarize:
                withAnimation(.snappy) { summary = text }
            }
            PaveHaptics.success()
        } catch {
            sendError = (error as? LocalizedError)?.errorDescription ?? "Ayla kon nu niet helpen. Probeer het opnieuw."
            PaveHaptics.error()
        }
    }

    private func summaryCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                PaveMark(size: 3)
                Text("Samenvatting van Ayla")
                    .textStyle(.meta)
                    .foregroundStyle(Color.inkMuted)
                Spacer(minLength: 8)
                Button { withAnimation(.snappy) { summary = nil } } label: {
                    Image(.iconXMark)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 9, height: 9)
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.pave)
                .accessibilityLabel("Samenvatting sluiten")
            }
            ScrollView {
                Text(text)
                    .textStyle(.caption)
                    .foregroundStyle(Color.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 180)
            .fixedSize(horizontal: false, vertical: true)
            Text("Ayla kan fouten maken.")
                .textStyle(.meta)
                .foregroundStyle(Color.inkMuted)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .padding(.top, 2)
        .background(Color.panel, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.cardBorder) }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Vault

    /// "Bewaar in kluis": adding evidence opens with this file in it and a title from its name; you check it and save.
    private func saveToVault(_ attachment: EmailAttachment, of message: EmailMessage) async {
        guard let vault else { return }
        openingAttachmentID = attachment.id
        defer { openingAttachmentID = nil }
        do {
            let data = try await email.attachmentData(attachment, of: message)
            let file = EmailVaultFile.prepare(data: data, name: attachment.name, mimeType: attachment.mimeType)
            let upload = VaultUpload(data: file.data, fileName: file.name, mimeType: file.mimeType)
            if let problem = upload.problem {
                sendError = VaultMessages.upload(problem)
                PaveHaptics.error()
                return
            }
            if vault.state != .ready { await vault.load() }
            let category = EmailVaultCategory.guess(fileName: attachment.name, subject: message.subject)
            let flow = VaultAddEvidenceModel(vault: vault, category: category, folderID: nil)
            flow.pick(.success(upload))
            vaultFlow = flow
        } catch {
            sendError = (error as? LocalizedError)?.errorDescription ?? "\(attachment.name) kon niet worden opgehaald."
            PaveHaptics.error()
        }
    }

    // MARK: Lock

    /// With a PIN already, it locks at once and the conversation closes; otherwise you choose a PIN first.
    private func startLocking() {
        guard let ayla else { return }
        Task {
            switch await ayla.chatPinExists() {
            case true?: lock()
            case false?: choosesLockPin = true
            case nil: sendError = AylaMessages.pinCheckFailed
            }
        }
    }

    private func lock() {
        email.setLocked(true, threadID)
        email.showsLocked = false
        PaveHaptics.success()
        dismiss()
    }
}

/// "Antwoord" or "Allen antwoorden" on one message, until the reply is sent.
nonisolated struct EmailReplyTarget: Equatable, Sendable {
    let message: EmailMessage
    let onlySender: Bool

    func recipients(as me: String) -> EmailReplyRecipients {
        onlySender ? EmailReplyRecipients(onlySenderOf: message, as: me) : EmailReplyRecipients(replyingTo: message, as: me)
    }

    /// The newest message of each person who wrote in the conversation, for "Alleen aan …".
    static func senders(in thread: EmailThread) -> [EmailMessage] {
        var seen = Set<String>()
        return thread.messages.reversed().filter { message in
            !message.isFromMe && seen.insert(message.from.address.lowercased()).inserted
        }
    }
}

/// A file from a mail as the vault takes it. Mail programs label photos loosely ("image/jpg", "application/octet-stream"
/// with a .jpg name), and some send GIF, WebP or TIFF: those become a JPEG, so every photo can be evidence.
nonisolated enum EmailVaultFile {
    /// The type the vault knows this file as, from its label or else its name; nil when the vault cannot take it.
    static func vaultType(mimeType: String, name: String) -> String? {
        let type = mimeType.lowercased().split(separator: ";").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        switch type {
        case "image/jpg", "image/pjpeg": return "image/jpeg"
        case "image/heif", "image/heic-sequence", "image/heif-sequence": return "image/heic"
        default: break
        }
        if VaultUpload.allowedTypes.contains(type) { return type }
        if type.hasPrefix("image/") { return "image/jpeg" }
        // A vague label: the extension says what it is.
        guard let byName = UTType(filenameExtension: (name as NSString).pathExtension)?.preferredMIMEType?.lowercased() else { return nil }
        if byName == mimeType.lowercased() { return nil }
        return vaultType(mimeType: byName, name: "")
    }

    static func canSave(mimeType: String, name: String) -> Bool {
        vaultType(mimeType: mimeType, name: name) != nil
    }

    /// The bytes, name and type to put in the vault; a photo the vault does not take as it is becomes a JPEG.
    static func prepare(data: Data, name: String, mimeType: String) -> (data: Data, name: String, mimeType: String) {
        guard let type = vaultType(mimeType: mimeType, name: name) else { return (data, name, mimeType.lowercased()) }
        let original = mimeType.lowercased().split(separator: ";").first.map(String.init) ?? ""
        let byName = UTType(filenameExtension: (name as NSString).pathExtension)?.preferredMIMEType?.lowercased()
        let isAlready = type == original || (type == "image/jpeg" && original == "image/jpg") || type == byName
            || (type == "image/heic" && original.hasPrefix("image/hei"))
        guard type == "image/jpeg", !isAlready else { return (data, name, type) }
        // GIF, WebP, TIFF, BMP: redrawn as a JPEG with the same name and a .jpg extension.
        guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) else { return (data, name, type) }
        let base = (name as NSString).deletingPathExtension
        return (jpeg, "\(base.isEmpty ? "Foto" : base).jpg", "image/jpeg")
    }
}

/// The kind of evidence a file from a mail probably is, to start "Bewijs toevoegen" with; you can still change it.
nonisolated enum EmailVaultCategory {
    static func guess(fileName: String, subject: String) -> VaultCategory {
        let text = "\(fileName) \(subject)".lowercased()
        let kinds: [(VaultCategory, [String])] = [
            (.diplomas, ["diploma", "getuigschrift", "propedeuse"]),
            (.certificates, ["certificaat", "certificate", "certified", "cijferlijst"]),
            (.internships, ["stage", "internship", "praktijkovereenkomst", "bpv"]),
            (.workExperience, ["arbeidsovereenkomst", "contract", "werkgever", "referentie"]),
            (.feedback, ["feedback", "beoordeling", "evaluatie"]),
        ]
        return kinds.first { _, words in words.contains { text.contains($0) } }?.0 ?? .other
    }
}

/// The reply field, built exactly like Ayla's composer (AylaComposer): the plus, Ayla's mark, the text and send, in one
/// glass field. Files you add show above the text. Ayla's mark is her button here: with an empty field she suggests a
/// reply or summarises, with text she words it better.
struct EmailReplyField: View {
    @Binding var text: String
    @Binding var files: [EmailOutgoingAttachment]
    let isSending: Bool
    let canSend: Bool
    let label: String
    /// So "Antwoord" on a message and Ayla's reply can put the cursor in the field.
    var focus: FocusState<Bool>.Binding?
    /// What Ayla is doing now, if anything.
    var aylaWorking: EmailAylaTask?
    /// Ayla's mark in the field. Nil leaves it out.
    var onAyla: ((EmailAylaTask) -> Void)?
    let attach: EmailAttachMenu
    var isListening = false
    /// The microphone, as in Ayla's composer: you speak, the words show in the field, and you send them yourself.
    var onMicrophone: (() -> Void)?
    let onSend: () -> Void

    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !files.isEmpty {
                // As in Ayla's composer: the row stops short of the rounded corners, and a chip that runs on fades out.
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(files) { file in
                            AylaAttachmentChip(name: file.name) { files.removeAll { $0.id == file.id } }
                        }
                    }
                    .padding(.horizontal, Self.chipFade)
                }
                .scrollIndicators(.hidden)
                .mask {
                    HStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: Self.chipFade)
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: Self.chipFade)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)
            }
            field
        }
        .glassEffect(.clear, in: .rect(cornerRadius: 25))
    }

    private static let chipFade: CGFloat = 12

    private var field: some View {
        HStack(spacing: 0) {
            attach
                .disabled(isSending)

            mark

            TextField(aylaWorking == .suggestReply ? "Ayla schrijft een antwoord…" : "Bericht", text: $text,
                      prompt: Text(aylaWorking == .suggestReply ? "Ayla schrijft een antwoord…" : "Bericht").foregroundStyle(Color.inkMuted.opacity(0.41)),
                      axis: .vertical)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
                .tint(.paveAccent)
                .lineLimit(1...6)
                .padding(.vertical, 16)
                // Ayla's text replaces what is here, so nothing typed meanwhile gets lost.
                .disabled(isSending || aylaWorking != nil)
                .accessibilityLabel(label)
                .modifier(EmailOptionalFocus(focus: focus))

            if let onMicrophone {
                Button(action: onMicrophone) {
                    Image(.iconMicrophone)
                        .renderingMode(.template)
                        .foregroundStyle(isListening ? Color.paveAccent : .ink)
                        .frame(width: 31, height: 53)
                        .padding(.leading, 13)
                        .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .disabled(isSending || aylaWorking != nil)
                .accessibilityLabel(isListening ? "Stop met inspreken" : "Inspreken")
            }

            Button(action: send) {
                Group {
                    if isSending {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(.iconSend)
                    }
                }
                .paveIconFrame(30)
                .background(Color.paveAccentFill, in: .circle)
                .shadow(color: .black.opacity(0.25), radius: 2)
                .frame(width: AylaComposer.roundButtonWidth, height: 53)
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            .disabled(isSending)
            .padding(.leading, onMicrophone == nil ? 6 : 0)
            .accessibilityLabel(isSending ? "Bezig met versturen" : "Versturen")
        }
        .padding(.leading, 4.5)
        .padding(.trailing, 7)
        .frame(minHeight: 53)
        // Tapping anywhere in the field, also next to the text, puts the cursor in it.
        .contentShape(.rect)
        .onTapGesture { if !isSending, aylaWorking == nil { focus?.wrappedValue = true } }
    }

    /// Ayla's mark between the plus and the text, where it is in her composer.
    @ViewBuilder
    private var mark: some View {
        if aylaWorking != nil {
            ProgressView()
                .controlSize(.mini)
                .tint(.paveAccent)
                .frame(width: markSize.width, height: 53)
                .padding(.leading, 1.5)
                .padding(.trailing, 9.4)
                .accessibilityLabel("Ayla is bezig")
        } else if let onAyla, hasText {
            Button { onAyla(.improve) } label: { markLabel }
                .buttonStyle(.pave)
                .accessibilityLabel("Beter formuleren met Ayla")
                .accessibilityHint("Ayla maakt van je tekst een net antwoord op deze mail")
        } else if let onAyla {
            Menu {
                Button { onAyla(.suggestReply) } label: { Label("Stel een antwoord voor", systemImage: "text.bubble.fill") }
                Button { onAyla(.summarize) } label: { Label("Vat samen", tinted: .iconListBulletSolid) }
            } label: { markLabel }
                .menuOrder(.fixed)
                .accessibilityLabel("Vraag Ayla")
                .accessibilityHint("Laat Ayla een antwoord voorstellen of het gesprek samenvatten")
        }
    }

    /// The default PaveMark: four squares of 4.25 pt, each half a square further right.
    private let markSize = CGSize(width: 4.25 + 3 * 4.25 / 2, height: 4 * 4.25)

    private var markLabel: some View {
        PaveMark()
            .padding(.leading, 1.5)
            .padding(.trailing, 9.4)
            .frame(height: 53)
            .contentShape(.rect)
    }

    private func send() {
        guard canSend else { return }
        onSend()
    }
}

/// The plus at the start of the reply field, as in Ayla's composer: a photo, a file, or something from your vault.
struct EmailAttachMenu: View {
    let onPhotos: () -> Void
    let onFile: () -> Void
    let onVault: () -> Void

    var body: some View {
        Menu {
            Button(action: onPhotos) { Label("Foto's", tinted: .iconPhotoSolid) }
            Button(action: onFile) { Label("Bestand", tinted: .iconPaperclipSolid) }
            Button(action: onVault) { Label { Text(AylaMessages.sourcesFromVault) } icon: { Image(.iconFolderSolid) } }
        } label: {
            Image(.iconPlus)
                .frame(width: 44, height: 53)
                .contentShape(.rect)
        }
        // Top to bottom as written, also though the menu opens upward from the bottom of the screen.
        .menuOrder(.fixed)
        .accessibilityLabel("Bijlage toevoegen")
    }
}

private struct EmailOptionalFocus: ViewModifier {
    let focus: FocusState<Bool>.Binding?

    func body(content: Content) -> some View {
        if let focus { content.focused(focus) } else { content }
    }
}
