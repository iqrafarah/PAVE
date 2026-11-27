import Foundation
import PAVECore
import Testing
@testable import PAVE

/// What one account keeps on this iPhone is never shown to the next account that signs in on it.
struct AccountSeparationTests {
    private func draft(_ id: String) -> ApplicationDraft {
        ApplicationDraft(vacancy: Vacancy(id: id, title: "Junior IT-consultant", company: "Kade", source: .example), cv: CVContent(name: "Ravi"), letter: LetterContent(), updatedAt: .now)
    }

    @Test func applicationsOfOneAccountAreNotSeenByTheNext() {
        let name = "accounts-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let ravi = "ravi-\(UUID().uuidString)", daaf = "daaf-\(UUID().uuidString)"

        PaveAccount.set(ravi, in: defaults)
        ApplicationStore(defaults: defaults).save(draft("kade"))
        #expect(ApplicationStore(defaults: defaults).all().map(\.id) == ["kade"])

        // Ravi signs out: nothing shows, also not before the next one signs in.
        PaveAccount.set(nil, in: defaults)
        #expect(ApplicationStore(defaults: defaults).all().isEmpty)
        #expect(ApplicationStore(defaults: defaults).load("kade") == nil)

        PaveAccount.set(daaf, in: defaults)
        #expect(ApplicationStore(defaults: defaults).all().isEmpty)
        #expect(ApplicationStore(defaults: defaults).load("kade") == nil)
        #expect(ApplicationStore(defaults: defaults).claim(for: daaf))

        // Ravi back: his application is still there for him.
        PaveAccount.set(ravi, in: defaults)
        #expect(ApplicationStore(defaults: defaults).all().map(\.id) == ["kade"])
    }

    @Test func keysOnTheDeviceBelongToOneAccount() {
        let defaults = UserDefaults(suiteName: "keys-\(UUID().uuidString)")!
        PaveAccount.set("ravi", in: defaults)
        let ravi = PaveAccount.key("fair.day", in: defaults)
        PaveAccount.set("daaf", in: defaults)
        #expect(PaveAccount.key("fair.day", in: defaults) != ravi)
        PaveAccount.set(nil, in: defaults)
        #expect(PaveAccount.key("fair.day", in: defaults) == "fair.day.signedOut")
    }
}
