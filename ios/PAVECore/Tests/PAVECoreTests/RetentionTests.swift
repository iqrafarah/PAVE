import Foundation
import Testing
@testable import PAVECore

struct RetentionTests {
    private let day: TimeInterval = 86_400
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func chat(
        pinned: Bool = false, project: String? = nil, locked: Bool = false, archived: Bool = false,
        expiry: AylaConversation.Expiry = .followsAccount
    ) -> AylaConversation {
        AylaConversation(
            id: "c", title: "Chat", updatedAt: now, pinnedAt: pinned ? now : nil, projectID: project, isLocked: locked,
            createdAt: now.addingTimeInterval(-10 * day), archivedAt: archived ? now : nil, expiry: expiry
        )
    }

    @Test func nothingExpiresUnlessTheAccountChoseIt() {
        #expect(ChatExpiry().expiresAt(chat()) == nil)
        #expect(ChatExpiry().expiresAt(chat(expiry: .days(7))) == now.addingTimeInterval(7 * day))
    }

    @Test func theTimeRunsFromTheLastMessageOrFromWhenTheChatWasMade() {
        #expect(ChatExpiry(days: 30).expiresAt(chat()) == now.addingTimeInterval(30 * day))
        #expect(ChatExpiry(days: 30, start: .created).expiresAt(chat()) == now.addingTimeInterval(20 * day))
    }

    @Test func theArchiveAndProjectsNeverExpire() {
        let expiry = ChatExpiry(days: 1, keepsPinned: false, keepsLocked: false)
        #expect(expiry.expiresAt(chat(archived: true)) == nil)
        #expect(expiry.expiresAt(chat(project: "p")) == nil)
        #expect(expiry.expiresAt(chat(archived: true, expiry: .days(1))) == nil)
    }

    @Test func pinnedAndLockedChatsStayUnlessTurnedOff() {
        #expect(ChatExpiry(days: 7).expiresAt(chat(pinned: true)) == nil)
        #expect(ChatExpiry(days: 7).expiresAt(chat(locked: true)) == nil)
        #expect(ChatExpiry(days: 7, keepsPinned: false).expiresAt(chat(pinned: true)) != nil)
        #expect(ChatExpiry(days: 7, keepsLocked: false).expiresAt(chat(locked: true)) != nil)
    }

    @Test func theChatsOwnChoiceWins() {
        #expect(ChatExpiry(days: 7).expiresAt(chat(expiry: .never)) == nil)
        #expect(ChatExpiry(days: 7).expiresAt(chat(expiry: .days(1))) == now.addingTimeInterval(day))
        #expect(AylaConversation.Expiry(days: nil) == .followsAccount)
        #expect(AylaConversation.Expiry(days: 0) == .never)
        #expect(AylaConversation.Expiry.days(30).storedDays == 30)
        #expect(AylaConversation.Expiry.never.storedDays == 0)
    }

    @Test func anArchivedChatLeavesTheListAndComesBackUnpinned() {
        var list = AylaConversationList(conversations: [chat(pinned: true)])
        list.setArchived(true, id: "c", at: now)
        #expect(list.visible.isEmpty)
        #expect(list.pinned.isEmpty)
        #expect(list.archived.map(\.id) == ["c"])
        #expect(list.matching("chat").conversations.isEmpty)
        list.setArchived(false, id: "c")
        #expect(list.others.map(\.id) == ["c"])
        #expect(list.archived.isEmpty)
    }

    @Test func aRowWithoutTheNewColumnsKeepsEverything() {
        let retention = try? JSONDecoder().decode(RetentionRow.self, from: Data("{}".utf8)).retention
        #expect(retention == PaveRetention())
        let chosen = try? JSONDecoder().decode(RetentionRow.self, from: Data(#"{"chat_expiry_days":7,"chat_expiry_from":"created","chat_expiry_keeps_pinned":false,"chat_expiry_keeps_locked":true,"ayla_uses_archive":true}"#.utf8)).retention
        #expect(chosen == PaveRetention(chatExpiry: ChatExpiry(days: 7, start: .created, keepsPinned: false), aylaUsesArchive: true))
    }
}

struct ArchiveListTests {
    @Test func aLockedChatInTheArchiveStaysBehindThePin() {
        let now = Date.now
        let list = AylaConversationList(conversations: [
            AylaConversation(id: "a", title: "Archief", updatedAt: now, archivedAt: now),
            AylaConversation(id: "b", title: "Geheim", updatedAt: now, isLocked: true, archivedAt: now),
        ])
        #expect(list.archived.map(\.id) == ["a"])
        #expect(list.visible.isEmpty)
    }
}
