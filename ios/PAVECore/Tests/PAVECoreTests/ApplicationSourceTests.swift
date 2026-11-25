import Foundation
import Testing
@testable import PAVECore

@Suite struct ApplicationSourceTests {
    private func fair(_ status: FairApplication.Status, _ answer: FairApplication.Answer? = nil) -> FairApplication {
        FairApplication(id: "f", employerSlug: "jumbo", vacancyID: "v", vacancyTitle: "Bijbaan", card: FairApplicationCard(name: "Ravi"), status: status, answer: answer)
    }

    @Test func fairApplicationsStandInTheSameTerms() {
        #expect(fair(.new).applicationStatus == .sent)
        #expect(fair(.invited).applicationStatus == .interview)
        #expect(fair(.invited, .accepted).applicationStatus == .interview)
        #expect(fair(.invited, .declined).applicationStatus == .rejected)
        #expect(fair(.declined).applicationStatus == .rejected)
    }

    @Test func ownVacanciesAreOwnTheRestAyla() {
        #expect(ApplicationSource(OwnApplication(company: "Jumbo").vacancy()) == .own)
        #expect(ApplicationSource(Vacancy(id: "1", title: "x", company: "y", source: .web)) == .ayla)
    }
}
