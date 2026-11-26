import Foundation
import Testing
@testable import PAVECore

struct WatchEventTests {
    @Test func eventsGoOverAndComeBackTheSame() throws {
        let events: [WatchEvent] = [
            .look(who: "Sanne de Vries", what: "Sollicitatie Kade"),
            .invitation(id: "a", employer: "Jumbo", vacancy: "Planning", at: Date(timeIntervalSince1970: 1_800_000_000)),
            .standTip(employer: "OGD", line: "Zoekt: Traineeship IT"),
            .handoff(title: "Je cv voor Kade", detail: "Staat klaar op je iPhone"),
            .plan(name: "Scrum halen", done: 1, total: 4, current: "Cursus kiezen"),
        ]
        for event in events {
            let data = try #require(event.data)
            #expect(WatchEvent.from([WatchEvent.key: data]) == event)
        }
        #expect(WatchEvent.plan(name: "x", done: 0, total: 1, current: nil).taps == false)
        #expect(WatchEvent.look(who: "x", what: "y").taps)
    }

    @Test func requestsFromTheWatchReadBack() {
        let request = WatchRequest.actions([AylaAppAction("markPlanStep", value: "done", target: "Cursus kiezen")])
        #expect(WatchRequest.from(request.message) == request)
        #expect(WatchRequest.from(["other": 1]) == nil)
    }
}
