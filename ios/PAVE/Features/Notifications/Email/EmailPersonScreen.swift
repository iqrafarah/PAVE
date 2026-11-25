import SwiftUI

/// Tapping the name in a conversation, as in Messages: who it is, the photos and files you sent each other, and your
/// other conversations with them. For a group: everyone in it (each opens their own info) and what was shared there.
struct EmailPersonScreen: View {
    let person: EmailAddress
    /// Set for a conversation with several people.
    var groupThreadID: String?

    @Environment(EmailModel.self) private var email
    @State private var card: EmailContactCard?
    @State private var previewURL: URL?
    @State private var openedThreadID: String?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var openedPerson: EmailAddress?

    private var group: EmailThread? { groupThreadID.flatMap(email.thread) }
    private var threads: [EmailThread] { group.map { [$0] } ?? email.threads(with: person.address) }

    private var shared: [(message: EmailMessage, attachment: EmailAttachment)] {
        threads.flatMap { thread in thread.messages.flatMap { message in message.attachments.map { (message, $0) } } }
            .sorted { $0.message.date > $1.message.date }
    }

    private var photos: [(message: EmailMessage, attachment: EmailAttachment)] {
        shared.filter { $0.attachment.mimeType.hasPrefix("image/") && $0.attachment.data != nil }
    }

    private var files: [(message: EmailMessage, attachment: EmailAttachment)] {
        shared.filter { !($0.attachment.mimeType.hasPrefix("image/") && $0.attachment.data != nil) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let group {
                    VStack(spacing: 8) {
                        EmailAvatarStack(people: group.participants, size: 72)
                        Text(group.participantNames)
                            .textStyle(.calloutTitle)
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.center)
                        Text("\(group.participants.count) mensen")
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(.top, 8)
                    section("Mensen") {
                        VStack(spacing: 0) {
                            ForEach(group.participants, id: \.address) { member in
                                Button { openedPerson = member } label: { memberRow(member) }
                                    .buttonStyle(.plain)
                                if member.address != group.participants.last?.address { Divider().padding(.leading, 60) }
                            }
                        }
                        .background(Color.panel, in: .rect(cornerRadius: 12, style: .continuous))
                    }
                } else {
                    VStack(spacing: 8) {
                        EmailAvatar(person: person, size: 88)
                        Text(card?.name ?? person.displayName)
                            .textStyle(.calloutTitle)
                            .foregroundStyle(Color.ink)
                        Text(person.address)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 8)
                }

                if let errorMessage { PaveInlineError(message: errorMessage) }

                section("Foto's") {
                    if photos.isEmpty {
                        empty(isLoading ? "Foto's laden…" : "Nog geen foto's gedeeld.")
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                            ForEach(photos, id: \.attachment.id) { item in
                                Button { open(item.attachment, of: item.message) } label: {
                                    EmailPhotoTile(attachment: item.attachment)
                                }
                                .buttonStyle(.pave)
                                .accessibilityLabel("Foto \(item.attachment.name)")
                            }
                        }
                        .clipShape(.rect(cornerRadius: 12, style: .continuous))
                    }
                }

                section("Bestanden") {
                    if files.isEmpty {
                        empty(isLoading ? "Bestanden laden…" : "Nog geen bestanden gedeeld.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(files, id: \.attachment.id) { item in
                                Button { open(item.attachment, of: item.message) } label: { fileRow(item.message, item.attachment) }
                                    .buttonStyle(.plain)
                                if item.attachment.id != files.last?.attachment.id { Divider().padding(.leading, 56) }
                            }
                        }
                        .background(Color.panel, in: .rect(cornerRadius: 12, style: .continuous))
                    }
                }

                if group == nil { section("Gesprekken") {
                    VStack(spacing: 0) {
                        ForEach(threads) { thread in
                            Button { openedThreadID = thread.id } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(thread.subject.isEmpty ? EmailModel.preview(of: thread) ?? "E-mail" : thread.subject).textStyle(.bodyMedium).foregroundStyle(Color.ink).lineLimit(1)
                                        Text(EmailBubbleLayout.timeLabel(thread.date)).textStyle(.caption).foregroundStyle(Color.inkMuted)
                                    }
                                    Spacer()
                                    Image(.iconChevronRight)
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 10, height: 10)
                                        .foregroundStyle(Color.inkMuted)
                                }
                                .padding(12)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            if thread.id != threads.last?.id { Divider().padding(.leading, 12) }
                        }
                    }
                    .background(Color.panel, in: .rect(cornerRadius: 12, style: .continuous))
                } }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("Info")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: Binding(get: { openedThreadID != nil }, set: { if !$0 { openedThreadID = nil } })) {
            if let id = openedThreadID { EmailThreadScreen(threadID: id) }
        }
        .navigationDestination(isPresented: Binding(get: { openedPerson != nil }, set: { if !$0 { openedPerson = nil } })) {
            if let openedPerson { EmailPersonScreen(person: openedPerson) }
        }
        .vaultQuickLook($previewURL)
        .task(id: person.address) {
            if group == nil { card = await EmailContactCard.lookup(person.address) }
            // Photos and files are only known once a conversation's messages are loaded.
            for thread in threads.prefix(10) { await email.load(thread.id) }
            isLoading = false
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .textStyle(.caption)
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.panel, in: .rect(cornerRadius: 12, style: .continuous))
    }

    private func memberRow(_ member: EmailAddress) -> some View {
        HStack(spacing: 12) {
            EmailAvatar(person: member, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName).textStyle(.bodyMedium).foregroundStyle(Color.ink).lineLimit(1)
                Text(member.address).textStyle(.caption).foregroundStyle(Color.inkMuted).lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(.iconChevronRight)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10)
                .foregroundStyle(Color.inkMuted)
        }
        .padding(12)
        .contentShape(.rect)
    }

    private func fileRow(_ message: EmailMessage, _ attachment: EmailAttachment) -> some View {
        HStack(spacing: 12) {
            Image(.iconDocumentTextSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.paveAccent)
                .frame(width: 32, height: 32)
                .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name).textStyle(.bodyMedium).foregroundStyle(Color.ink).lineLimit(1)
                Text("\(message.isFromMe ? "Jij" : message.from.displayName) · \(EmailBubbleLayout.timeLabel(message.date))")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if attachment.size > 0 {
                Text(attachment.size.formatted(.byteCount(style: .file))).textStyle(.meta).foregroundStyle(Color.inkMuted)
            }
        }
        .padding(12)
        .contentShape(.rect)
    }

    private func open(_ attachment: EmailAttachment, of message: EmailMessage) {
        Task {
            do {
                let data = try await email.attachmentData(attachment, of: message)
                previewURL = VaultPreviewFile.url(for: data, named: attachment.name)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "\(attachment.name) kon niet worden geopend."
            }
        }
    }
}

/// A square photo in the grid.
private struct EmailPhotoTile: View {
    let attachment: EmailAttachment
    @State private var image: UIImage?

    var body: some View {
        Color.bubbleUser
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .task(id: attachment.id) { image = await EmailPhotoBubble.thumbnail(attachment.data, size: CGSize(width: 130, height: 130)) }
    }
}
