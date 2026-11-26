import Foundation

/// Turns loose messages into conversations, and a full e-mail into the part worth showing as a chat bubble.
nonisolated enum EmailThreading {
    private static let subjectPrefixes = ["re", "aw", "antw", "antwoord", "fw", "fwd", "wg", "doorst", "tr", "sv", "vs"]

    /// "Re: RE: Fwd: Stage" becomes "Stage".
    static func normalizedSubject(_ subject: String) -> String {
        var value = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        var changed = true
        while changed {
            changed = false
            if value.hasPrefix("["), let close = value.firstIndex(of: "]"), value.distance(from: value.startIndex, to: close) < 20 {
                value = String(value[value.index(after: close)...]).trimmingCharacters(in: .whitespaces)
                changed = true
            }
            guard let colon = value.firstIndex(of: ":") else { break }
            let prefix = value[..<colon].lowercased().trimmingCharacters(in: .whitespaces)
            let bare = prefix.replacingOccurrences(of: #"\[\d+\]$"#, with: "", options: .regularExpression)
            if subjectPrefixes.contains(bare) {
                value = String(value[value.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                changed = true
            }
        }
        return value
    }

    /// The Message-ID, In-Reply-To and References headers link messages; messages without those headers join a
    /// conversation with the same subject and person.
    static func threads(from messages: [EmailMessage]) -> [EmailThread] {
        var parent = Array(messages.indices)
        func root(_ index: Int) -> Int {
            var index = index
            while parent[index] != index {
                parent[index] = parent[parent[index]]
                index = parent[index]
            }
            return index
        }
        func join(_ a: Int, _ b: Int) {
            let ra = root(a), rb = root(b)
            if ra != rb { parent[rb] = ra }
        }

        var byMessageID: [String: Int] = [:]
        for (index, message) in messages.enumerated() {
            let ids = ([message.messageID, message.inReplyTo].compactMap { $0 } + message.references).map(normalizedID)
            for id in ids where !id.isEmpty {
                if let other = byMessageID[id] { join(other, index) } else { byMessageID[id] = index }
            }
        }

        var bySubject: [String: Int] = [:]
        for (index, message) in messages.enumerated() {
            let subject = normalizedSubject(message.subject).lowercased()
            // A forward starts a conversation of its own, even with the same subject and person: only its headers
            // (an answer to it) join it to anything.
            guard !subject.isEmpty, !isForward(message.subject) else { continue }
            for person in counterparts(of: message) {
                let key = "\(subject)\u{0}\(person)"
                if let other = bySubject[key] { join(other, index) } else { bySubject[key] = index }
            }
        }

        let groups = Dictionary(grouping: messages.indices, by: root)
        return groups.values.map { indices in
            let items = indices.map { messages[$0] }.sorted { $0.date < $1.date }
            let first = items[0]
            let id = "\(first.provider.rawValue):\(first.messageID.map(normalizedID) ?? first.id)"
            return EmailThread(id: id, provider: first.provider, messages: items)
        }
        .sorted { $0.date > $1.date }
    }

    /// The people you have written to: everyone on the mail you sent.
    static func knownAddresses(in messages: [EmailMessage]) -> Set<String> {
        Set(messages.filter(\.isFromMe).flatMap { $0.to + $0.cc }.map { $0.address.lowercased() })
    }

    /// A real conversation: you wrote in it, or someone you know (from your sent mail or your contacts) did, and it is
    /// not only newsletters and automatic notices.
    static func isConversation(_ thread: EmailThread, known: Set<String>) -> Bool {
        if thread.messages.contains(where: \.isFromMe) { return true }
        return thread.messages.contains { !$0.isAutomated && known.contains($0.from.address.lowercased()) }
    }

    private static let forwardPrefixes: Set<String> = ["fw", "fwd", "wg", "doorst", "tr"]

    /// "Fwd: Stage", also as "Re: Fwd: Stage".
    static func isForward(_ subject: String) -> Bool {
        var value = subject.trimmingCharacters(in: .whitespaces)
        while let colon = value.firstIndex(of: ":"), value.distance(from: value.startIndex, to: colon) <= 8 {
            let prefix = value[..<colon].lowercased().trimmingCharacters(in: .whitespaces)
            if forwardPrefixes.contains(prefix) { return true }
            guard subjectPrefixes.contains(prefix) else { return false }
            value = String(value[value.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        return false
    }

    private static func counterparts(of message: EmailMessage) -> [String] {
        (message.isFromMe ? message.to + message.cc : [message.from]).map { $0.address.lowercased() }
    }

    static func normalizedID(_ id: String) -> String {
        id.trimmingCharacters(in: CharacterSet(charactersIn: "<> \t\r\n")).lowercased()
    }

    // MARK: The new part of a message

    private static let attributionPatterns = [
        #"^(op|on|le|am|el)\s.+(schreef|wrote|a écrit|schrieb|escribió).*:\s*$"#,
        #"^.+\sheeft\s.+geschreven\s*:\s*$"#,
        #"^-{2,}\s*(original message|oorspronkelijk bericht|oorspronkelijk e-?mailbericht|forwarded message|doorgestuurd bericht)\s*-{2,}\s*$"#,
        #"^_{10,}\s*$"#,
    ]

    /// Everything you wrote yourself, without the history the mail program quotes below it.
    static func stripQuotedText(_ text: String) -> String {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var cut = lines.count
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowered = trimmed.lowercased()
            if trimmed.hasPrefix(">") {
                // A quote only ends the message when nothing of your own follows it.
                let rest = lines[index...].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if rest.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).hasPrefix(">") }) { cut = index; break }
                continue
            }
            let joined = index + 1 < lines.count ? lowered + " " + lines[index + 1].lowercased().trimmingCharacters(in: .whitespaces) : lowered
            if attributionPatterns.contains(where: { lowered.range(of: $0, options: .regularExpression) != nil }) {
                cut = index
                break
            }
            if (lowered.hasPrefix("op ") || lowered.hasPrefix("on ")),
               attributionPatterns.prefix(1).contains(where: { joined.range(of: $0, options: .regularExpression) != nil }) {
                cut = index
                break
            }
            // Outlook's header block: "Van: …" followed by "Verzonden:" or "Sent:".
            if lowered.hasPrefix("van:") || lowered.hasPrefix("from:") {
                let next = lines[(index + 1)..<min(lines.count, index + 4)].map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
                if next.contains(where: { $0.hasPrefix("verzonden:") || $0.hasPrefix("sent:") || $0.hasPrefix("datum:") || $0.hasPrefix("date:") }) {
                    cut = index
                    break
                }
            }
        }
        let kept = lines[..<cut].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return kept.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : kept
    }
}
