import OSLog

/// What the mail servers answer, for Xcode's console. Never passwords or message text.
nonisolated enum EmailLog {
    static let logger = Logger(subsystem: "nl.fontys.pave", category: "email")
}
