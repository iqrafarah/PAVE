import PAVECore
import Testing
@testable import PAVE

@MainActor
struct RetentionConfirmationTests {
    @Test func aChoiceThatCanDeleteChatsIsAskedFirst() {
        let none = ChatExpiry()
        let month = ChatExpiry(days: 30)
        #expect(SettingsRetentionScreen.deletesMore(month, than: none))
        #expect(SettingsRetentionScreen.deletesMore(ChatExpiry(days: 7), than: month))
        #expect(SettingsRetentionScreen.deletesMore(ChatExpiry(days: 30, start: .created), than: month))
        #expect(SettingsRetentionScreen.deletesMore(ChatExpiry(days: 30, keepsPinned: false), than: month))
        #expect(SettingsRetentionScreen.deletesMore(ChatExpiry(days: 30, keepsLocked: false), than: month))
    }

    @Test func aChoiceThatKeepsMoreIsSavedAtOnce() {
        let week = ChatExpiry(days: 7)
        #expect(!SettingsRetentionScreen.deletesMore(ChatExpiry(), than: week))
        #expect(!SettingsRetentionScreen.deletesMore(ChatExpiry(days: 90), than: week))
        #expect(!SettingsRetentionScreen.deletesMore(week, than: ChatExpiry(days: 7, start: .created)))
    }
}
