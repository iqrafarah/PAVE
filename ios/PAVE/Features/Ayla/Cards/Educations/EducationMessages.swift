import PAVECore

/// The words around the studies and courses Ayla finds. Kept with the cards; see docs/ui-teksten.md.
enum EducationMessages {
    static func found(_ count: Int) -> String { count == 1 ? "1 opleiding gevonden" : "\(count) opleidingen gevonden" }
    static let openSite = "Bekijk de site"
    static let addToPlan = "Zet in plan"
    static let inPlan = "In je plan"
    static let makePlan = "Maak er een plan van"
    static func addedTo(_ plan: String) -> String { "Staat als stap in \(plan)." }
    static func planMade(_ plan: String) -> String { "Plan \(plan) gemaakt." }
    static let checkOnSite = "Toelating, kosten en open dagen staan op de site van de school."
    static func searching(_ what: String, in place: String) -> String {
        place.isEmpty ? "Ayla zoekt opleidingen: \(what)…" : "Ayla zoekt opleidingen: \(what) in \(place)…"
    }
    static let searchingShort = "Zoekt opleidingen"
    static let openSiteHint = "Opent de site van de school in Safari"
    static let addToPlanHint = "Zet deze opleiding als stap in je plan"
    static let makePlanHint = "Maakt een plan met de stappen om je aan te melden"

    /// The step a study becomes, in the language the app is in now: a plan keeps the words it was made with.
    static func step(for education: AylaEducation) -> PavePlanStep {
        var step = education.planStep
        step.title = step.title.translated
        return step
    }

    /// The plan for one study when there is none yet: look, visit, check, apply.
    static func template(for education: AylaEducation) -> PavePlanTemplate {
        let first = step(for: education)
        return PavePlanTemplate(
            id: "education-\(education.id)",
            name: education.name,
            summary: "",
            goal: "Beginnen aan \(education.name) bij \(education.school)".translated,
            steps: [
                .init(first.title, summary: first.summary, kind: .research, metadata: first.metadata),
                .init("Toelatingseisen nakijken".translated, summary: "Wat de school vraagt aan vooropleiding, keuring of toets".translated, kind: .research),
                .init("Naar een open dag of meeloopdag".translated, kind: .action),
                .init("Bewijs klaarzetten in je kluis".translated, summary: "Diploma's en cijferlijsten die de school vraagt".translated, kind: .evidence),
                .init("Aanmelden".translated, kind: .milestone),
            ]
        )
    }
}
