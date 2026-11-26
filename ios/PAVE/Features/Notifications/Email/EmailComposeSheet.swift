import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// "Nieuw bericht": the first e-mail to someone. After sending, the conversation opens in Meldingen like any other.
/// With `forwarding` it is "Doorsturen": the message, or the whole conversation, and its files go along under what
/// you write.
struct EmailComposeSheet: View {
    var forwarding: EmailForwarding?
    /// Gets the new conversation's id, so Meldingen can open it.
    var onSent: (String) -> Void = { _ in }

    @Environment(EmailModel.self) private var email
    @Environment(\.dismiss) private var dismiss
    @State private var to = ""
    @State private var subject = ""
    @State private var text = ""
    @State private var files: [EmailOutgoingAttachment] = []
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var isChoosingFile = false
    @State private var isChoosingPhotos = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isChoosingFromVault = false
    @State private var isChoosingContact = false
    @State private var isLoadingFiles = false
    @FocusState private var field: Field?

    private enum Field: Hashable {
        case to, subject, text
    }

    private var recipients: [EmailAddress] {
        to.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == " " })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("@") && $0.contains(".") }
            .map { EmailAddress(name: nil, address: $0.lowercased()) }
    }

    /// The part after the last comma, matched against people you know.
    /// What you are typing now: the part after the last comma.
    private var typed: String {
        guard !to.hasSuffix(", "), let last = to.split(separator: ",").last else { return "" }
        return last.trimmingCharacters(in: .whitespaces)
    }

    private var suggestions: [EmailAddress] {
        guard field == .to else { return [] }
        let chosen = Set(recipients.map(\.address))
        return email.suggestedPeople(matching: typed, limit: 8).filter { !chosen.contains($0.address) }.prefix(5).map(\.self)
    }

    private var canSend: Bool {
        !isSending && !isLoadingFiles && !recipients.isEmpty
            && (forwarding != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("naam@voorbeeld.nl", text: $to)
                        .textStyle(.bodyMedium)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($field, equals: .to)
                        .submitLabel(.next)
                        .onSubmit { field = .subject }
                        .accessibilityLabel("Aan")
                    ForEach(suggestions, id: \.address) { person in
                        Button { choose(person.address) } label: {
                            EmailSuggestionRow(person: person, typed: typed)
                        }
                        .buttonStyle(.plain)
                    }
                    Button { isChoosingContact = true } label: {
                        Label("Kies uit Contacten", tinted: .iconUserGroupSolid)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.paveAccent)
                    }
                    TextField("Onderwerp", text: $subject)
                        .textStyle(.bodyMedium)
                        .focused($field, equals: .subject)
                        .submitLabel(.next)
                        .onSubmit { field = .text }
                } header: {
                    Text("Aan")
                        .textStyle(.caption)
                        .textCase(nil)
                } footer: {
                    if let address = email.account(for: .icloud)?.address {
                        Text("Je verstuurt vanaf \(address).")
                            .textStyle(.caption)
                    }
                }

                if let forwarding {
                    Section {
                        ForEach(forwarding.messages.sorted { $0.date < $1.date }) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(message.isFromMe ? "Jij" : message.from.displayName)
                                        .textStyle(.bodyMedium)
                                        .foregroundStyle(Color.ink)
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(EmailBubbleLayout.timeLabel(message.date))
                                        .textStyle(.meta)
                                        .foregroundStyle(Color.inkMuted)
                                }
                                if let body = message.body, !body.isEmpty {
                                    Text(body)
                                        .textStyle(.caption)
                                        .foregroundStyle(Color.inkMuted)
                                        .lineLimit(3)
                                }
                                if !message.attachments.isEmpty {
                                    Text(message.attachments.count == 1 ? "1 bijlage" : "\(message.attachments.count) bijlagen")
                                        .textStyle(.meta)
                                        .foregroundStyle(Color.inkMuted)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    } header: {
                        Text(forwarding.messages.count == 1 ? "Doorgestuurd bericht" : "Doorgestuurd gesprek · \(forwarding.messages.count) berichten")
                            .textStyle(.caption)
                            .textCase(nil)
                    } footer: {
                        if isLoadingFiles {
                            Text("Bijlagen ophalen…").textStyle(.caption)
                        }
                    }
                }

                Section {
                    TextField(forwarding == nil ? "Je bericht" : "Je bericht (mag leeg)", text: $text, axis: .vertical)
                        .textStyle(.bodyMedium)
                        .lineLimit(6...16)
                        .focused($field, equals: .text)
                    if !files.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(files) { file in
                                    EmailAttachmentChip(attachment: file) { files.removeAll { $0.id == file.id } }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    Menu {
                        Button { isChoosingPhotos = true } label: { Label("Foto's", tinted: .iconPhotoSolid) }
                        Button { isChoosingFile = true } label: { Label("Bestand", tinted: .iconPaperclipSolid) }
                        Button { isChoosingFromVault = true } label: { Label { Text(AylaMessages.sourcesFromVault) } icon: { Image(.iconFolderSolid) } }
                    } label: {
                        Label("Bijlage toevoegen", tinted: .iconPaperclipSolid)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.paveAccent)
                    }
                }

                if let errorMessage {
                    Section { PaveInlineError(message: errorMessage) }
                }
            }
            .tint(.paveAccent)
            .scrollContentBackground(.hidden)
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(forwarding == nil ? "Nieuw bericht" : "Doorsturen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ApplyMessages.cancel) { dismiss() }
                        .disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSending ? "Bezig…" : "Verstuur") { Task { await send() } }
                        .disabled(!canSend)
                }
            }
            .onAppear { field = .to }
            .task { await prepareForward() }
            .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                guard case let .success(urls) = result else { return }
                for url in urls {
                    if let file = EmailOutgoingAttachment.file(at: url) {
                        files.append(file)
                    } else {
                        errorMessage = "\(url.lastPathComponent) kon niet worden geopend."
                    }
                }
            }
            .emailContactPicker(isPresented: $isChoosingContact) { person in choose(person.address) }
            .sheet(isPresented: $isChoosingFromVault) {
                EmailVaultPicker { files.append(contentsOf: $0) }
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
        }
        .presentationDetents([.large])
        .presentationBackground(Color.canvas)
        .interactiveDismissDisabled(isSending || !text.isEmpty)
    }

    private func choose(_ address: String) {
        var parts = to.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // Only what you were typing makes way, not the person you chose before it.
        if !typed.isEmpty, !parts.isEmpty { parts.removeLast() }
        parts.append(address)
        to = parts.joined(separator: ", ") + ", "
    }

    /// The subject and the files of the message you forward.
    private func prepareForward() async {
        guard let forwarding, subject.isEmpty, files.isEmpty else { return }
        subject = EmailForward.subject(forwarding.subject)
        guard forwarding.messages.contains(where: { !$0.attachments.isEmpty || $0.hasAttachments }) else { return }
        isLoadingFiles = true
        do {
            files = try await email.outgoingAttachments(of: forwarding.messages)
        } catch {
            errorMessage = "De bijlagen konden niet worden opgehaald. Je kunt het bericht zonder ze doorsturen."
        }
        isLoadingFiles = false
    }

    private func send() async {
        guard canSend else { return }
        isSending = true
        errorMessage = nil
        let cleanSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let threadID: String?
            if let forwarding {
                threadID = try await email.forward(forwarding.messages, to: recipients, subject: cleanSubject, note: note, attachments: files)
            } else {
                threadID = try await email.startConversation(
                    to: recipients,
                    subject: cleanSubject,
                    text: note,
                    attachments: files
                )
            }
            PaveHaptics.success()
            dismiss()
            if let threadID { onSent(threadID) }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Je bericht kon niet worden verstuurd. Probeer opnieuw."
            PaveHaptics.error()
        }
        isSending = false
    }
}

extension EmailOutgoingAttachment {
    /// A file from the Files app; nil when it cannot be read.
    static func file(at url: URL) -> EmailOutgoingAttachment? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return EmailOutgoingAttachment(name: url.lastPathComponent, mimeType: type, data: data)
    }

    /// A photo from the library, named "Foto 1.jpg", "Foto 2.heic", ….
    static func photo(_ item: PhotosPickerItem, number: Int) async -> EmailOutgoingAttachment? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        let type = item.supportedContentTypes.first
        return EmailOutgoingAttachment(
            name: "Foto \(number).\(type?.preferredFilenameExtension ?? "jpg")",
            mimeType: type?.preferredMIMEType ?? "image/jpeg",
            data: data
        )
    }
}

/// A person to send to, as in Mail: their photo, their name and address, with what you typed in bold.
struct EmailSuggestionRow: View {
    let person: EmailAddress
    let typed: String

    var body: some View {
        HStack(spacing: 12) {
            EmailAvatar(person: person, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.highlighted(person.name ?? person.address, typed))
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                if person.name != nil {
                    Text(Self.highlighted(person.address, typed))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(person.name.map { "\($0), \(person.address)" } ?? person.address)
        .accessibilityHint("Voegt toe aan Aan")
    }

    private static func highlighted(_ text: String, _ typed: String) -> AttributedString {
        var result = AttributedString(text)
        let needle = typed.trimmingCharacters(in: .whitespaces)
        if !needle.isEmpty, let range = result.range(of: needle, options: .caseInsensitive) {
            result[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return result
    }
}
