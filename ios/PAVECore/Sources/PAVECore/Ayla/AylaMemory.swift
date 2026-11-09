import Foundation

/// Something Ayla remembers about the user, shared by web, iPhone and Watch (`ayla_memories`). Nothing is saved by
/// itself: Ayla suggests a note in her reply (`AylaReply.memory`) and the user keeps it, or writes one themselves.
public struct AylaMemory: Identifiable, Equatable, Sendable {
    public enum Source: String, Sendable {
        /// Suggested by Ayla and kept by the user.
        case ayla
        /// Written by the user.
        case user
    }

    public static let maxLength = 300

    public var id: String
    public var text: String
    public var source: Source
    public var createdAt: Date

    public init(id: String, text: String, source: Source, createdAt: Date) {
        self.id = id
        self.text = text
        self.source = source
        self.createdAt = createdAt
    }

    /// The text as it is saved: one line, trimmed, at most `maxLength` characters. Nil when nothing is left.
    public static func clean(_ text: String) -> String? {
        let line = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !line.isEmpty else { return nil }
        return String(line.prefix(maxLength))
    }

    /// The same note, whatever the capitals or the full stop at the end.
    public static func isSame(_ a: String, _ b: String) -> Bool {
        func plain(_ text: String) -> String {
            text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        }
        return plain(a) == plain(b)
    }
}

/// What Ayla remembers and whether the user lets her.
public struct AylaMemories: Equatable, Sendable {
    /// Off: Ayla uses none of the notes and suggests nothing. The notes stay until the user deletes them.
    public var isEnabled: Bool
    /// The newest first.
    public var notes: [AylaMemory]

    public init(isEnabled: Bool = true, notes: [AylaMemory] = []) {
        self.isEnabled = isEnabled
        self.notes = notes
    }

    public func contains(_ text: String) -> Bool {
        notes.contains { AylaMemory.isSame($0.text, text) }
    }
}
