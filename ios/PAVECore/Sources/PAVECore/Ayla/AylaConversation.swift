import Foundation

public struct AylaConversation: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var updatedAt: Date
    public var pinnedAt: Date?
    /// Where the conversation began: on the phone, the web or the Watch.
    public var startedOn: AylaDevice?

    public var isPinned: Bool { pinnedAt != nil }

    public init(id: String, title: String, updatedAt: Date, pinnedAt: Date? = nil, startedOn: AylaDevice? = nil) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
        self.pinnedAt = pinnedAt
        self.startedOn = startedOn
    }

    /// The longest title someone can give a conversation.
    public static let maxTitleLength = 80

    /// A title someone typed, tidied up; nil when nothing is left.
    public static func cleanTitle(_ text: String) -> String? {
        let words = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !words.isEmpty else { return nil }
        return String(words.prefix(maxTitleLength))
    }
}

/// A group of conversations in the list, by when they were last used, as in ChatGPT and Claude.
public struct AylaConversationSection: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case pinned
        case today
        case yesterday
        case lastWeek
        case lastMonth
        case earlier
    }

    public var kind: Kind
    public var conversations: [AylaConversation]

    public var id: Kind { kind }

    public var title: String {
        switch kind {
        case .pinned: "Vastgezet"
        case .today: "Vandaag"
        case .yesterday: "Gisteren"
        case .lastWeek: "Afgelopen 7 dagen"
        case .lastMonth: "Afgelopen 30 dagen"
        case .earlier: "Eerder"
        }
    }
}

/// The user's conversations. `canPin` stays false until the `pinned_at` column exists in Supabase.
public struct AylaConversationList: Equatable, Sendable {
    public var conversations: [AylaConversation]
    public var canPin: Bool

    public init(conversations: [AylaConversation] = [], canPin: Bool = false) {
        self.conversations = conversations
        self.canPin = canPin
    }

    /// Pinned conversations, the most recently pinned first.
    public var pinned: [AylaConversation] {
        conversations.filter(\.isPinned).sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
    }

    /// The other conversations, the most recent first.
    public var others: [AylaConversation] {
        conversations.filter { !$0.isPinned }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Conversations whose title contains the search text, ignoring case and accents.
    public func matching(_ search: String) -> AylaConversationList {
        let search = search.trimmingCharacters(in: .whitespaces)
        guard !search.isEmpty else { return self }
        let found = conversations.filter {
            $0.title.range(of: search, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_NL")) != nil
        }
        return AylaConversationList(conversations: found, canPin: canPin)
    }

    public mutating func setPinned(_ isPinned: Bool, id: String, at date: Date = .now) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].pinnedAt = isPinned ? date : nil
    }

    public mutating func rename(id: String, to title: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].title = title
    }

    public mutating func remove(id: String) {
        conversations.removeAll { $0.id == id }
    }

    /// Whether `other` would show exactly the same list: the same groups, chats, names and order. Small differences
    /// that do not show, such as the fraction of a second a chat was pinned at, do not count.
    public func looksTheSame(as other: AylaConversationList, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard canPin == other.canPin else { return false }
        func shown(_ list: AylaConversationList) -> [[String]] {
            list.sections(now: now, calendar: calendar).map { section in
                ["\(section.kind)"] + section.conversations.map {
                    "\($0.id)|\($0.title)|\($0.startedOn?.rawValue ?? "")|\(Int($0.updatedAt.timeIntervalSince1970 / 60))"
                }
            }
        }
        return shown(self) == shown(other)
    }

    /// Pinned first, then the rest by when it was last used. Empty groups are left out.
    public func sections(now: Date = .now, calendar: Calendar = .current) -> [AylaConversationSection] {
        let today = calendar.startOfDay(for: now)
        func daysAgo(_ date: Date) -> Int {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: today).day ?? 0
        }
        var groups: [AylaConversationSection.Kind: [AylaConversation]] = [:]
        for conversation in others {
            let days = daysAgo(conversation.updatedAt)
            let kind: AylaConversationSection.Kind = switch days {
            case ...0: .today
            case 1: .yesterday
            case 2...7: .lastWeek
            case 8...30: .lastMonth
            default: .earlier
            }
            groups[kind, default: []].append(conversation)
        }
        let order: [AylaConversationSection.Kind] = [.today, .yesterday, .lastWeek, .lastMonth, .earlier]
        let pinnedSection = pinned.isEmpty ? [] : [AylaConversationSection(kind: .pinned, conversations: pinned)]
        return pinnedSection + order.compactMap { kind in
            groups[kind].map { AylaConversationSection(kind: kind, conversations: $0) }
        }
    }
}

/// A message in which the search text was found, with a short piece of text around it.
public struct AylaSearchHit: Equatable, Sendable, Identifiable {
    public var id: String
    public var conversationID: String
    public var snippet: String

    public init(id: String, conversationID: String, snippet: String) {
        self.id = id
        self.conversationID = conversationID
        self.snippet = snippet
    }

    /// About `width` characters of `text` around the first place `search` occurs, with an ellipsis where it is cut.
    public static func snippet(of text: String, around search: String, width: Int = 90) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        guard let range = flat.range(of: search, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return flat.count > width ? String(flat.prefix(width)) + "…" : flat
        }
        let start = flat.index(range.lowerBound, offsetBy: -width / 3, limitedBy: flat.startIndex) ?? flat.startIndex
        let end = flat.index(start, offsetBy: width, limitedBy: flat.endIndex) ?? flat.endIndex
        var piece = String(flat[start..<end]).trimmingCharacters(in: .whitespaces)
        if start > flat.startIndex { piece = "…" + piece }
        if end < flat.endIndex { piece += "…" }
        return piece
    }
}

/// A message as it is stored. Messages from Ayla keep the whole reply, so cards come back too.
public struct AylaStoredMessage: Equatable, Sendable, Identifiable {
    public enum Role: String, Sendable {
        case user
        case ayla
    }

    public var id: String
    public var role: Role
    public var text: String
    public var reply: AylaReply?

    public init(id: String, role: Role, text: String, reply: AylaReply? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.reply = reply
    }
}
