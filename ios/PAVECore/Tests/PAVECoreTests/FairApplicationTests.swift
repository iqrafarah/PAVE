import Foundation
import Testing
@testable import PAVECore

struct FairApplicationTests {
    @Test func postersAndInboxKeysAreRead() {
        #expect(ShareLinks.scanned("pave://vacature/jumbo/fair-jumbo-planning") == .vacancy(slug: "jumbo", id: "fair-jumbo-planning"))
        let inbox = ShareLinks.inboxInApp("jumbo", key: "abcdefghijklmnopqrst")
        #expect(ShareLinks.scanned(inbox.absoluteString) == .inbox(slug: "jumbo", key: "abcdefghijklmnopqrst"))
        #expect(ShareLinks.scanned("pave://werkgever-inbox/jumbo?sleutel=kort") == nil)
        #expect(ShareLinks.scanned(ShareLinks.vacancyInApp("ogd", id: "fair-ogd-traineeship").absoluteString) == .vacancy(slug: "ogd", id: "fair-ogd-traineeship"))
    }

    @Test func aCardNeedsANameAndAReason() {
        #expect(FairApplicationCard(name: "").problem == .noName)
        #expect(FairApplicationCard(name: "Sam").problem == .noWhy)
        #expect(FairApplicationCard(name: "Sam", pitch: "Ik ben Sam.").problem == nil)
    }

    @Test func theInboxReadsWhatTheFunctionSends() throws {
        let json = """
        {"employer":{"slug":"jumbo","name":"Jumbo","stand":"Stand D"},"applications":[{"id":"a","vacancyID":"v","vacancyTitle":"Bijbaan",
        "name":"Sam","why":"Ik werk graag met mensen.","availability":{"days":["zaterdag"],"maxHours":12},"status":"invited",
        "invitedFor":"2026-11-28T10:00:00.000Z","appliedAt":"2026-11-25T12:00:00.123+00:00"}]}
        """
        let inbox = try FairInboxService.inbox(from: Data(json.utf8))
        #expect(inbox.name == "Jumbo")
        #expect(inbox.applications.first?.availability.days == ["zaterdag"])
        #expect(inbox.applications.first?.invitedFor != nil)
    }
}
