import Foundation
import Testing
@testable import PAVECore

struct VacancyFilterTests {
    private func vacancy(_ id: String, company: String, city: String?, hours: Vacancy.Employment?, fits: Int, misses: Int) -> Vacancy {
        Vacancy(
            id: id, title: "Developer", company: company, city: city, employment: hours, source: .example,
            matches: (0..<fits).map { .init(skill: "s\($0)", requirement: "r") },
            skillGap: (0..<misses).map { .init(skill: "g\($0)", requirement: "r") }
        )
    }

    private var found: [Vacancy] {
        [
            vacancy("a", company: "Kade Consultancy", city: "Eindhoven", hours: .fullTime, fits: 1, misses: 2),
            vacancy("b", company: "Randstad Nederland", city: "Utrecht", hours: .partTime, fits: 3, misses: 0),
            vacancy("c", company: "Studio Noorderlicht", city: "Eindhoven", hours: .partTime, fits: 2, misses: 1),
            vacancy("d", company: "Lumen Data", city: nil, hours: nil, fits: 0, misses: 0),
        ]
    }

    @Test func theMatchIsTheShareOfSkillsThatFit() {
        #expect(found[0].matchPercent == 33)
        #expect(found[1].matchPercent == 100)
        #expect(found[3].matchPercent == nil)
    }

    @Test func bestMatchFirstKeepsTheRestInOrder() {
        let ordered = VacancyFilter(order: .bestMatch).apply(to: found).map(\.id)
        #expect(ordered == ["b", "c", "a", "d"])
        #expect(VacancyFilter().apply(to: found).map(\.id) == ["a", "b", "c", "d"])
    }

    @Test func placeHoursAndEmployerNarrowTheList() {
        #expect(VacancyFilter(city: "eindhoven").apply(to: found).map(\.id) == ["a", "c"])
        #expect(VacancyFilter(employment: .partTime).apply(to: found).map(\.id) == ["b", "c"])
        #expect(VacancyFilter(employer: .agency).apply(to: found).map(\.id) == ["b"])
        #expect(VacancyFilter(employer: .direct).apply(to: found).map(\.id) == ["a", "c", "d"])
        #expect(VacancyFilter(city: "Eindhoven", employment: .partTime).activeCount == 2)
    }

    @Test func placesAreListedMostCommonFirst() {
        #expect(VacancyFilter.cities(in: found) == ["Eindhoven", "Utrecht"])
    }
}
