import PAVECore
import SwiftUI

/// How a conversation reads like Messages: the time only where a pause starts, messages of one sender close together,
/// and the tail only on the last bubble of a run.
nonisolated struct EmailBubbleLayout: Equatable {
    let messageID: String
    let showsTime: Bool
    let isFirstOfRun: Bool
    let isLastOfRun: Bool

    /// A new time label after a quarter of an hour of silence.
    static let pause: TimeInterval = 15 * 60

    static func make(_ messages: [EmailMessage]) -> [EmailBubbleLayout] {
        messages.indices.map { index in
            let message = messages[index]
            let previous = index > 0 ? messages[index - 1] : nil
            let next = index + 1 < messages.count ? messages[index + 1] : nil
            let showsTime = previous.map { message.date.timeIntervalSince($0.date) > pause } ?? true
            let nextStartsPause = next.map { $0.date.timeIntervalSince(message.date) > pause } ?? true
            return EmailBubbleLayout(
                messageID: message.id,
                showsTime: showsTime,
                isFirstOfRun: showsTime || previous.map { !sameSender($0, message) } ?? true,
                isLastOfRun: nextStartsPause || next.map { !sameSender($0, message) } ?? true
            )
        }
    }

    private static func sameSender(_ a: EmailMessage, _ b: EmailMessage) -> Bool {
        a.isFromMe == b.isFromMe && a.from.matches(b.from.address)
    }

    /// "Vandaag 21:59", "Gisteren 14:02", "di 14:02" this week, otherwise "24 nov. 14:02".
    static func timeLabel(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        let locale = Locale(identifier: "nl_NL")
        let time = date.formatted(.dateTime.hour().minute().locale(locale))
        if calendar.isDate(date, inSameDayAs: now) { return "Vandaag \(time)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Gisteren \(time)"
        }
        if let week = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)), date >= week {
            return "\(date.formatted(.dateTime.weekday(.abbreviated).locale(locale))) \(time)"
        }
        return "\(date.formatted(.dateTime.day().month(.abbreviated).locale(locale))) \(time)"
    }
}

/// One message in the conversation: photos, the text bubble and files, with the time above when a pause starts.
struct EmailMessageRow: View {
    let message: EmailMessage
    let layout: EmailBubbleLayout
    /// Several people: their name above their first bubble and their photo beside their last, as in a group chat.
    var isGroup = false
    /// "Verstuurd" under your last message.
    var showsSent = false
    var isLoading = false
    var openingAttachmentID: String?
    var onOpenAttachment: (EmailAttachment) -> Void = { _ in }
    /// Holding the message offers to delete it; nil leaves that out.
    var onDelete: (() -> Void)?
    /// "Antwoord": only to the person who wrote it.
    var onReply: (() -> Void)?
    /// "Allen antwoorden": to everyone on it; nil when there is only one person.
    var onReplyAll: (() -> Void)?
    var onForward: (() -> Void)?
    /// "Bewaar in kluis" when you hold a photo or file.
    var onSaveToVault: ((EmailAttachment) -> Void)?
    /// "Bekijk opgemaakt", for a mail with a table, a list or pictures.
    var onShowFormatted: (() -> Void)?

    private var mine: Bool { message.isFromMe }
    private var photos: [EmailAttachment] { message.attachments.filter { $0.mimeType.hasPrefix("image/") && $0.data != nil } }
    private var files: [EmailAttachment] { message.attachments.filter { !($0.mimeType.hasPrefix("image/") && $0.data != nil) } }

    var body: some View {
        VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
            if layout.showsTime {
                Text(EmailBubbleLayout.timeLabel(message.date))
                    .textStyle(.meta)
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
            }
            if isGroup, !mine, layout.isFirstOfRun {
                Text(message.from.displayName)
                    .textStyle(.meta)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.leading, 50)
            }
            HStack(alignment: .bottom, spacing: 8) {
                if mine { Spacer(minLength: 56) }
                if isGroup, !mine {
                    if layout.isLastOfRun { EmailAvatar(person: message.from, size: 28) } else { Color.clear.frame(width: 28, height: 28) }
                }
                // As in Messages: what you attached first, the text last, with the tail.
                VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                    // Photos sent together as one block, as in Messages; holding one offers "Bewaar in kluis".
                    if !photos.isEmpty {
                        EmailPhotoGrid(photos: photos, onOpen: onOpenAttachment) { photo in attachmentMenu(photo) }
                    }
                    ForEach(files) { file in
                        Button { onOpenAttachment(file) } label: {
                            EmailFileBubble(attachment: file, mine: mine, isLoading: openingAttachmentID == file.id)
                        }
                        .buttonStyle(.pave)
                        .accessibilityHint("Opent de bijlage")
                        .contextMenu { attachmentMenu(file) }
                    }
                    if isLoading {
                        EmailLoadingBubble(mine: mine)
                    } else if let body = message.body, !body.isEmpty {
                        let forward = EmailForward.split(body)
                        if !forward.note.isEmpty || forward.parts.isEmpty {
                            textBubble(forward.parts.isEmpty ? body : forward.note, copy: body, hasTail: layout.isLastOfRun && forward.parts.isEmpty)
                        }
                        ForEach(Array(forward.parts.enumerated()), id: \.offset) { _, part in
                            EmailForwardCard(part: part, mine: mine)
                                .contextMenu { messageMenu(copy: body) }
                        }
                    }
                    if !isLoading, let onShowFormatted {
                        Button(action: onShowFormatted) {
                            Text("Bekijk opgemaakt")
                                .textStyle(.meta)
                                .foregroundStyle(Color.paveAccent)
                                .padding(.horizontal, 6)
                                .frame(minHeight: 32)
                        }
                        .buttonStyle(.pave)
                        .accessibilityHint("Toont de mail met tabellen en opmaak")
                    }
                }
                if !mine { Spacer(minLength: 56) }
            }
            .padding(.top, layout.isFirstOfRun && !layout.showsTime ? 8 : 0)
            if showsSent {
                Text("Verstuurd")
                    .textStyle(.meta)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 2)
                    .padding(.trailing, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityActions {
            if let onReply { Button("Antwoord", action: onReply) }
            if let onReplyAll { Button("Allen antwoorden", action: onReplyAll) }
            if let onForward { Button("Doorsturen", action: onForward) }
            if let onShowFormatted { Button("Bekijk opgemaakt", action: onShowFormatted) }
            ForEach(message.attachments.filter(canSave)) { attachment in
                Button("\(attachment.name) bewaren in je kluis") { onSaveToVault?(attachment) }
            }
            if let onDelete { Button("Verwijderen", action: onDelete) }
        }
    }

    private func textBubble(_ text: String, copy: String, hasTail: Bool) -> some View {
        Text(text)
            .textStyle(.input)
            .foregroundStyle(mine ? Color.white : Color.ink)
            .tint(mine ? .white : .paveAccent)
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                EmailBubbleShape(isMine: mine, hasTail: hasTail)
                    .fill(mine ? Color.paveAccentFill : Color.bubbleUser)
            }
            .contentShape(.contextMenuPreview, .rect(cornerRadius: 18, style: .continuous))
            .contextMenu { messageMenu(copy: copy) }
    }

    @ViewBuilder
    private func messageMenu(copy: String) -> some View {
        if let onReply {
            Button(action: onReply) { Label("Antwoord", tinted: .iconArrowUturnLeftSolid) }
        }
        if let onReplyAll {
            Button(action: onReplyAll) { Label("Allen antwoorden", tinted: .iconArrowUturnLeftSolid) }
        }
        if let onForward {
            Button(action: onForward) { Label("Doorsturen", tinted: .iconArrowUturnRightSolid) }
        }
        Button { UIPasteboard.general.string = copy } label: {
            Label("Kopiëren", tinted: .iconDocumentDuplicate)
        }
        if let onShowFormatted {
            Button(action: onShowFormatted) { Label("Bekijk opgemaakt", tinted: .iconDocumentText) }
        }
        if let onDelete {
            Button(role: .destructive, action: onDelete) { Label("Verwijderen", tinted: .iconTrash) }
        }
    }

    /// Files the vault takes: a PDF, a Word file, a photo or text; also what you sent yourself, such as your own
    /// certificate you mailed to someone.
    private func canSave(_ attachment: EmailAttachment) -> Bool {
        onSaveToVault != nil && EmailVaultFile.canSave(mimeType: attachment.mimeType, name: attachment.name)
    }

    @ViewBuilder
    private func attachmentMenu(_ attachment: EmailAttachment) -> some View {
        Button { onOpenAttachment(attachment) } label: { Label("Openen", tinted: .iconEyeSolid) }
        if canSave(attachment), let onSaveToVault {
            Button { onSaveToVault(attachment) } label: { Label("Bewaar in kluis", tinted: .iconFolderArrowDownSolid) }
        }
        if let onForward {
            Button(action: onForward) { Label("Doorsturen", tinted: .iconArrowUturnRightSolid) }
        }
        if let onDelete {
            Button(role: .destructive, action: onDelete) { Label("Verwijderen", tinted: .iconTrash) }
        }
    }

    private var accessibilityText: String {
        let who = mine ? "Jij" : message.from.displayName
        let files = message.attachments.isEmpty ? "" : ", \(message.attachments.count) bijlage\(message.attachments.count == 1 ? "" : "n")"
        return "\(who), \(EmailBubbleLayout.timeLabel(message.date)): \(message.body ?? "")\(files)"
    }
}

/// A rounded bubble with Messages' tail at the bottom on the sender's side.
nonisolated struct EmailBubbleShape: Shape {
    let isMine: Bool
    let hasTail: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 18, style: .continuous)
        guard hasTail else { return path }
        var tail = Path()
        let y = rect.maxY
        if isMine {
            let x = rect.maxX
            tail.move(to: CGPoint(x: x - 12, y: y - 14))
            tail.addQuadCurve(to: CGPoint(x: x + 5, y: y), control: CGPoint(x: x - 3, y: y - 1))
            tail.addQuadCurve(to: CGPoint(x: x - 20, y: y - 2), control: CGPoint(x: x - 8, y: y + 1))
        } else {
            // Drawn the other way round than on the right, so it turns the same way as the bubble and fills.
            let x = rect.minX
            tail.move(to: CGPoint(x: x + 20, y: y - 2))
            tail.addQuadCurve(to: CGPoint(x: x - 5, y: y), control: CGPoint(x: x + 8, y: y + 1))
            tail.addQuadCurve(to: CGPoint(x: x + 12, y: y - 14), control: CGPoint(x: x + 3, y: y - 1))
        }
        tail.closeSubpath()
        path.addPath(tail)
        return path
    }
}

/// A photo in the conversation, shown as a picture instead of a file.
struct EmailPhotoBubble: View {
    let attachment: EmailAttachment
    var maxSize = CGSize(width: 230, height: 280)

    @State private var image: UIImage?

    /// The photo's own shape within `maxSize`, so a portrait photo gets no empty space beside it.
    private var size: CGSize {
        guard let image, image.size.width > 0, image.size.height > 0 else { return CGSize(width: 180, height: 140) }
        let scale = min(maxSize.width / image.size.width, maxSize.height / image.size.height)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.bubbleUser
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .task(id: attachment.id) { image = await EmailPhotoBubble.thumbnail(attachment.data, size: maxSize) }
    }

    /// Decoded smaller than the original, so a 4 MB photo does not slow the conversation down.
    static func thumbnail(_ data: Data?, size: CGSize) async -> UIImage? {
        guard let data, let image = UIImage(data: data) else { return nil }
        let scale = min(1, max(size.width / image.size.width, size.height / image.size.height) * 2)
        return await image.byPreparingThumbnail(ofSize: CGSize(width: image.size.width * scale, height: image.size.height * scale)) ?? image
    }
}

/// Photos sent together, as Messages shows them: one on its own in its own shape; two side by side; three as one wide
/// above two; more two per row. Tap one to open it, hold it for "Bewaar in kluis" and the rest.
struct EmailPhotoGrid<Menu: View>: View {
    let photos: [EmailAttachment]
    let onOpen: (EmailAttachment) -> Void
    @ViewBuilder let menu: (EmailAttachment) -> Menu

    private static var width: CGFloat { 236 }
    private static var gap: CGFloat { 2 }
    private var half: CGFloat { (Self.width - Self.gap) / 2 }

    var body: some View {
        Group {
            switch photos.count {
            case 1:
                Button { onOpen(photos[0]) } label: { EmailPhotoBubble(attachment: photos[0]) }
                    .buttonStyle(.pave)
                    .accessibilityLabel("Foto \(photos[0].name)")
                    .contextMenu { menu(photos[0]) }
            case 2:
                HStack(spacing: Self.gap) {
                    tile(photos[0], width: half, height: 170)
                    tile(photos[1], width: half, height: 170)
                }
            case 3:
                VStack(spacing: Self.gap) {
                    tile(photos[0], width: Self.width, height: 150)
                    HStack(spacing: Self.gap) {
                        tile(photos[1], width: half, height: half)
                        tile(photos[2], width: half, height: half)
                    }
                }
            default:
                // Two per row; an odd last one takes the whole width, so every photo shows.
                VStack(spacing: Self.gap) {
                    ForEach(Array(stride(from: 0, to: photos.count, by: 2)), id: \.self) { start in
                        if start + 1 < photos.count {
                            HStack(spacing: Self.gap) {
                                tile(photos[start], width: half, height: half)
                                tile(photos[start + 1], width: half, height: half)
                            }
                        } else {
                            tile(photos[start], width: Self.width, height: 150)
                        }
                    }
                }
            }
        }
        // One rounded block; the photos inside it only have a thin gap between them.
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: photos.count == 1 ? .combine : .contain)
        .accessibilityLabel(photos.count == 1 ? "" : "\(photos.count) foto's")
    }

    private func tile(_ photo: EmailAttachment, width: CGFloat, height: CGFloat) -> some View {
        Button { onOpen(photo) } label: {
            EmailPhotoTile(attachment: photo, size: CGSize(width: width, height: height))
        }
        .buttonStyle(.pave)
        .accessibilityLabel("Foto \(photo.name)")
        .contextMenu { menu(photo) }
    }
}

/// One photo filling its place in the grid, cropped to it.
private struct EmailPhotoTile: View {
    let attachment: EmailAttachment
    let size: CGSize

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.bubbleUser
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(.rect)
        .task(id: attachment.id) { image = await EmailPhotoBubble.thumbnail(attachment.data, size: size) }
    }
}

/// A file as a bubble: an icon, its name and size.
struct EmailFileBubble: View {
    let attachment: EmailAttachment
    let mine: Bool
    var isLoading = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(mine ? Color.white.opacity(0.22) : Color.panel)
                if isLoading {
                    ProgressView().controlSize(.small).tint(mine ? .white : .paveAccent)
                } else {
                    Image(.iconDocumentTextSolid)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(mine ? Color.white : Color.paveAccent)
                }
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.name)
                    .textStyle(.caption)
                    .foregroundStyle(mine ? Color.white : Color.ink)
                    .lineLimit(1)
                if attachment.size > 0 {
                    Text(attachment.size.formatted(.byteCount(style: .file)))
                        .textStyle(.meta)
                        .foregroundStyle(mine ? Color.white.opacity(0.8) : Color.inkMuted)
                }
            }
        }
        .padding(8)
        .padding(.trailing, 6)
        .frame(maxWidth: 250, alignment: .leading)
        .background(mine ? Color.paveAccentFill : Color.bubbleUser, in: .rect(cornerRadius: 18, style: .continuous))
    }
}

/// While the text of a message is being fetched.
struct EmailLoadingBubble: View {
    let mine: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule().frame(width: 170, height: 9)
            Capsule().frame(width: 110, height: 9)
        }
        .foregroundStyle((mine ? Color.white : Color.inkMuted).opacity(0.3))
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(mine ? Color.paveAccentFill : Color.bubbleUser, in: .rect(cornerRadius: 18, style: .continuous))
        .accessibilityLabel("Bericht wordt geladen")
    }
}

/// A file you are about to send: a photo preview or an icon, the name, and a cross to take it out again.
struct EmailAttachmentChip: View {
    let attachment: EmailOutgoingAttachment
    var onRemove: () -> Void

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(.rect(cornerRadius: 12, style: .continuous))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(.iconDocumentTextSolid)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Color.paveAccent)
                        Text(attachment.name)
                            .textStyle(.meta)
                            .foregroundStyle(Color.ink)
                            .lineLimit(2)
                        Text(attachment.data.count.formatted(.byteCount(style: .file)))
                            .textStyle(.meta)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(8)
                    .frame(width: 120, height: 64, alignment: .topLeading)
                    .background(Color.bubbleUser, in: .rect(cornerRadius: 12, style: .continuous))
                }
            }
            Button(action: onRemove) {
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(Color.white)
                    .frame(width: 20, height: 20)
                    .background(Color.black.opacity(0.55), in: .circle)
            }
            .buttonStyle(.pave)
            .padding(4)
            .accessibilityLabel("\(attachment.name) weghalen")
        }
        .task(id: attachment.id) {
            guard attachment.mimeType.hasPrefix("image/") else { return }
            image = await EmailPhotoBubble.thumbnail(attachment.data, size: CGSize(width: 64, height: 64))
        }
    }
}

/// A forwarded message inside the conversation. It is someone else's message, so it is a PAVE card with their photo
/// and name instead of one of your bubbles; its text folds after a few lines.
struct EmailForwardCard: View {
    let part: EmailForward.Part
    let mine: Bool

    @State private var isOpen = false

    private var isLong: Bool { part.text.count > 280 || part.text.components(separatedBy: "\n").count > 7 }

    var body: some View {
        VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
            Label("Doorgestuurd", tinted: .iconArrowUturnRightSolid)
                .labelStyle(EmailSmallLabelStyle())
                .textStyle(.meta)
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 6)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    EmailAvatar(person: EmailAddress(name: part.from, address: part.address), size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(part.from.isEmpty ? "Onbekend" : part.from)
                            .textStyle(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                        if !part.date.isEmpty {
                            Text(part.date)
                                .textStyle(.meta)
                                .foregroundStyle(Color.inkMuted)
                                .lineLimit(1)
                        }
                    }
                }
                if !part.subject.isEmpty {
                    Text(part.subject)
                        .textStyle(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.ink)
                }
                if !part.text.isEmpty {
                    Text(part.text)
                        .textStyle(.input)
                        .foregroundStyle(Color.ink)
                        .tint(.paveAccent)
                        .textSelection(.enabled)
                        .lineLimit(isOpen ? nil : 7)
                }
                if isLong {
                    Button(isOpen ? "Minder tonen" : "Hele bericht tonen") { withAnimation(.snappy) { isOpen.toggle() } }
                        .textStyle(.meta)
                        .foregroundStyle(Color.paveAccent)
                        .buttonStyle(.pave)
                }
            }
            .padding(12)
            .frame(maxWidth: 290, alignment: .leading)
            .background(Color.panel, in: .rect(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.cardBorder) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Doorgestuurd bericht van \(part.from), \(part.date). \(part.subject). \(part.text)")
    }
}

/// A small icon right beside its text, for "Doorgestuurd".
private struct EmailSmallLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.font(.system(size: 9, weight: .semibold))
            configuration.title
        }
    }
}
