import Foundation
import Testing
@testable import PAVECore

struct VerificationStatusTests {
    @Test func decodesFromSharedJSON() throws {
        let data = Data(#"["verified","validated","selfAdded"]"#.utf8)
        let statuses = try JSONDecoder().decode([VerificationStatus].self, from: data)
        #expect(statuses == [.verified, .validated, .selfAdded])
    }

    @Test func onlySelfAddedIsUnconfirmed() {
        #expect(VerificationStatus.verified.isExternallyConfirmed)
        #expect(VerificationStatus.validated.isExternallyConfirmed)
        #expect(!VerificationStatus.selfAdded.isExternallyConfirmed)
    }
}
