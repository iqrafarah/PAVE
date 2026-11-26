import Foundation

/// A plan made for one vacancy keeps what it needs of it in its free metadata: which vacancy, where, and what the user
/// still misses for it. Ayla uses that for her steps, and the step for the CV and letter opens that application.
public enum PlanVacancy {
    public static let idKey = "vacancyID"
    static let titleKey = "vacancyTitle"
    static let companyKey = "vacancyCompany"
    static let summaryKey = "vacancySummary"
    static let missingKey = "vacancyMissing"
    private static let separator = "\u{1F}"

    public static func metadata(for vacancy: Vacancy) -> [String: String] {
        var metadata = [idKey: vacancy.id, titleKey: vacancy.title, companyKey: vacancy.company]
        if let summary = vacancy.summary, !summary.isEmpty { metadata[summaryKey] = String(summary.prefix(600)) }
        let missing = vacancy.skillGap.map(\.skill).filter { !$0.isEmpty }.prefix(8)
        if !missing.isEmpty { metadata[missingKey] = missing.joined(separator: separator) }
        return metadata
    }

    public static func vacancyID(of plan: PavePlan) -> String? { plan.metadata[idKey] }

    /// The vacancy as far as the plan knows it, to open its application or practise for it.
    public static func vacancy(of plan: PavePlan) -> Vacancy? {
        guard let id = plan.metadata[idKey], let title = plan.metadata[titleKey] else { return nil }
        var vacancy = Vacancy(id: id, title: title, company: plan.metadata[companyKey] ?? "", source: .web)
        vacancy.summary = plan.metadata[summaryKey]
        return vacancy
    }

    public static func job(of plan: PavePlan) -> PlanStepsRequest.Job? {
        guard let title = plan.metadata[titleKey] else { return nil }
        return PlanStepsRequest.Job(
            title: title, company: plan.metadata[companyKey] ?? "", summary: plan.metadata[summaryKey],
            missing: plan.metadata[missingKey]?.components(separatedBy: separator) ?? []
        )
    }

    /// The steps towards applying for this vacancy: read it, work on what is missing, evidence, CV and letter, share,
    /// and practise the talk. All of them can be changed afterwards.
    public static func template(for vacancy: Vacancy) -> PavePlanTemplate {
        var steps: [PavePlanTemplate.Step] = [
            .init("Lees de vacature goed", summary: "Kijk wat ze vragen en wat je daarvan al kunt laten zien.", kind: .research, metadata: [idKey: vacancy.id]),
        ]
        for gap in vacancy.skillGap.prefix(3) where !gap.skill.isEmpty {
            steps.append(.init(
                String("Werk aan \(gap.skill)".prefix(PavePlan.maxNameLength)),
                summary: PavePlan.cleanGoal(gap.requirement.isEmpty ? "De vacature vraagt hierom en het staat nog niet in je kluis." : "De vacature vraagt: \(gap.requirement)"),
                kind: .action
            ))
        }
        steps += [
            .init("Zet passend bewijs in je kluis", summary: "Voeg toe wat bij deze vacature hoort en laat het verifiëren waar dat kan.", kind: .evidence),
            .init("Schrijf je cv en brief", summary: "Maak ze voor deze vacature; Ayla schrijft mee met wat ze van je mag zien.", kind: .document, metadata: [idKey: vacancy.id]),
            .init("Deel je sollicitatie", summary: "Kies wat \(vacancy.company) mag zien en hoe lang.", kind: .profile, metadata: [idKey: vacancy.id]),
            .init("Oefen het gesprek met Ayla", summary: "Bereid je voor op de vragen die je kunt verwachten.", kind: .conversation, metadata: [idKey: vacancy.id]),
        ]
        return PavePlanTemplate(
            id: "vacancy", name: String("\(vacancy.title) bij \(vacancy.company)".prefix(PavePlan.maxNameLength)),
            summary: "Stappen naar een sollicitatie.", goal: PavePlan.cleanGoal("Solliciteren op \(vacancy.title) bij \(vacancy.company)."),
            steps: steps, metadata: metadata(for: vacancy)
        )
    }
}

extension PavePlan {
    private static let projectKey = "projectID"

    /// The project in Ayla this plan belongs to, if any: new chats of the plan start in it, so Ayla uses the project's
    /// instructions and sources.
    public var projectID: String? {
        get { metadata[Self.projectKey] }
        set { metadata[Self.projectKey] = newValue }
    }
}
