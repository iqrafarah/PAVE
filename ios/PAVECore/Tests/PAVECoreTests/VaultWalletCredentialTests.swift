import Foundation
import Testing
@testable import PAVECore

struct VaultWalletCredentialTests {
    @Test func readsTheCredentialsOfTheWalletFunction() throws {
        let json = """
        {"credentials":[
          {"id":"badge-teamwork","category":"badges","format":"Open Badge","title":"Samenwerken in een projectteam","issuer":"Hogeschool Kempenland","place":"Eindhoven","issuedOn":"2025-01-24","description":"Je werkte een semester in een projectteam.","skills":["Samenwerken","Plannen"],"imported":true},
          {"id":"work-customer-service","category":"workExperience","format":"Werkgeversverklaring","title":"Bijbaan klantenservice","issuer":"Winkelhuis Zuid","startDate":"2023-09-01","isCurrent":true,"skills":[]},
          {"id":"internship-frontend","category":"internships","format":"Werkgeversverklaring","title":"Stage front-end development","issuer":"Studio Noord","startDate":"2025-02-03","endDate":"2025-07-04","skills":["React"]},
          {"id":"odd","category":"spaceships","title":"Iets","issuer":"Iemand"}
        ]}
        """
        struct Reply: Decodable { let credentials: [VaultWalletCredential] }
        let credentials = try JSONDecoder().decode(Reply.self, from: Data(json.utf8)).credentials
        #expect(credentials.count == 4)
        #expect(credentials[0].category == .badges)
        #expect(credentials[0].imported)
        #expect(credentials[0].issuedOn == VaultDay(year: 2025, month: 1, day: 24))
        #expect(credentials[0].when == "jan 2025")
        #expect(credentials[1].when == "sep 2023 – nu")
        #expect(credentials[2].when == "feb 2025 – jul 2025")
        #expect(!credentials[2].imported)
        // A kind of evidence the app does not know is "Overige", not a failure.
        #expect(credentials[3].category == .other)
    }
}
