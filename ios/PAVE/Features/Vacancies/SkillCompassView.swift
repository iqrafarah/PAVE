import PAVECore
import SwiftUI

/// "Skill-kompas": over the vacancies you found, kept and applied for, what you still miss (the most asked first, with
/// the one that pays off most on top) and what you can already show with evidence. A missing skill goes into a plan
/// as a step, or to Ayla to ask how to get it.
struct SkillCompassView: View {
    let compass: SkillCompass.Result
    /// A vacancy that asks for a skill, to ask Ayla about it with that vacancy in mind.
    let vacancyAsking: (String) -> Vacancy?
    let onAskAyla: ((String, Vacancy) -> Void)?

    @Environment(PlanModel.self) private var plans: PlanModel?
    @State private var added: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(PlanMessages.compassIntro(compass.vacancyCount))
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if let next = compass.nextBest {
                    nextBest(next)
                }
                if compass.missing.count > 1 {
                    section(PlanMessages.compassMissing) {
                        ForEach(Array(compass.missing.dropFirst().enumerated()), id: \.element.id) { index, skill in
                            missingRow(skill)
                            if index < compass.missing.count - 2 { ShareRowDivider(inset: 14) }
                        }
                    }
                }
                if !compass.have.isEmpty {
                    section(PlanMessages.compassHave) {
                        ForEach(Array(compass.have.enumerated()), id: \.element.id) { index, skill in
                            haveRow(skill)
                            if index < compass.have.count - 1 { ShareRowDivider(inset: 14) }
                        }
                    }
                }
                if compass.missing.isEmpty && compass.have.isEmpty {
                    PaveEmptyState(icon: .iconMagnifyingGlassSolid, title: PlanMessages.compassEmptyTitle, message: PlanMessages.compassEmpty)
                        .padding(.top, 30)
                }
            }
            .padding(20)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas)
        .navigationTitle(PlanMessages.compassTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func nextBest(_ skill: SkillCompass.Skill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(PlanMessages.compassNext).textStyle(.caption).foregroundStyle(Color.paveAccent)
            Text(skill.name).textStyle(.emptyTitle).foregroundStyle(Color.ink)
            meter(skill.count)
            Text(PlanMessages.compassAskedIn(skill.count, of: compass.vacancyCount))
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
            Text(skill.vacancies.prefix(3).joined(separator: " · "))
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .lineLimit(2)
            actions(skill, prominent: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.panel, in: .rect(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Color.paveAccent.opacity(0.5), lineWidth: 1.5) }
    }

    private func missingRow(_ skill: SkillCompass.Skill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(skill.name).textStyle(.listTitle).foregroundStyle(Color.ink)
                Spacer()
                Text(PlanMessages.compassCount(skill.count, of: compass.vacancyCount)).textStyle(.caption).monospacedDigit().foregroundStyle(Color.inkMuted)
            }
            meter(skill.count)
            actions(skill, prominent: false)
        }
        .padding(14)
    }

    private func haveRow(_ skill: SkillCompass.Skill) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(skill.isVerified ? .iconCheckBadgeSolid : .iconCheckCircleSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(18)
                .foregroundStyle(skill.isVerified ? Color.paveAccent : Color.inkMuted)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(skill.name).textStyle(.listTitle).foregroundStyle(Color.ink)
                Text(skill.evidence.isEmpty ? PlanMessages.compassMatchedOnly : PlanMessages.compassProof(skill.evidence, verified: skill.isVerified))
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(PlanMessages.compassCount(skill.count, of: compass.vacancyCount)).textStyle(.caption).monospacedDigit().foregroundStyle(Color.inkMuted)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func actions(_ skill: SkillCompass.Skill, prominent: Bool) -> some View {
        HStack(spacing: 8) {
            if let plans, plans.isAvailable {
                Menu {
                    ForEach(plans.plans.filter { !$0.isFinished }) { plan in
                        Button { add(skill, to: plan.id, in: plans) } label: { Label(plan.name, tinted: .iconMapSolid) }
                    }
                    Button { Task { await newPlan(for: skill, in: plans) } } label: { Label(PlanMessages.compassNewPlan, tinted: .iconPlusCircleSolid) }
                } label: {
                    chip(added.contains(skill.id) ? PlanMessages.compassAdded : PlanMessages.compassToPlan, icon: added.contains(skill.id) ? .iconCheckCircleSolid : .iconMapSolid, isOn: prominent)
                }
                .disabled(added.contains(skill.id))
            }
            if let onAskAyla, let vacancy = vacancyAsking(skill.name) {
                Button { onAskAyla(skill.name, vacancy) } label: { chip(PlanMessages.compassAsk, icon: .iconAyla, isOn: false) }
                    .buttonStyle(.pave)
            }
        }
    }

    private func chip(_ title: String, icon: ImageResource, isOn: Bool) -> some View {
        HStack(spacing: 6) {
            Image(icon).renderingMode(.template).resizable().scaledToFit().paveIconFrame(13)
            Text(title).textStyle(.chip).lineLimit(1)
        }
        .foregroundStyle(isOn ? Color.white : Color.paveAccent)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(isOn ? Color.paveAccentFill : Color.paveSurfaceTint, in: .capsule)
        .contentShape(.capsule)
    }

    private func meter(_ count: Int) -> some View {
        PlanProgressBar(progress: compass.vacancyCount == 0 ? 0 : Double(count) / Double(compass.vacancyCount))
            .accessibilityHidden(true)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        SharePanel(title: title) { content() }
    }

    private func add(_ skill: SkillCompass.Skill, to planID: String, in plans: PlanModel) {
        PaveHaptics.success()
        plans.addStep(PavePlanStep(title: PlanMessages.compassStep(skill.name), summary: PlanMessages.compassStepSummary(skill.count), kind: .action), to: planID)
        added.insert(skill.id)
    }

    private func newPlan(for skill: SkillCompass.Skill, in plans: PlanModel) async {
        let template = PavePlanTemplate(
            id: "skill", name: String("\(skill.name) leren".prefix(PavePlan.maxNameLength)), summary: "", goal: PlanMessages.compassStepSummary(skill.count),
            steps: [
                .init(PlanMessages.compassStep(skill.name), summary: PlanMessages.compassStepSummary(skill.count), kind: .action),
                .init("Zet je bewijs in je kluis", summary: "Een certificaat, project of feedback waaruit blijkt dat je het kunt.", kind: .evidence),
                .init("Laat het verifiëren", summary: "Geverifieerd bewijs weegt zwaarder bij een werkgever.", kind: .verification),
            ]
        )
        if await plans.create(name: template.name, goal: template.goal, from: template) != nil {
            PaveHaptics.success()
            added.insert(skill.id)
        }
    }
}

/// On the Vacatures page: the compass in one line, opening it.
struct SkillCompassCard: View {
    let compass: SkillCompass.Result

    var body: some View {
        HStack(spacing: 12) {
            Image(.iconMagnifyingGlassSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(18)
                .foregroundStyle(Color.paveAccent)
                .frame(width: 40, height: 40)
                .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(PlanMessages.compassTitle).textStyle(.listTitle).foregroundStyle(Color.ink)
                Text(compass.nextBest.map { PlanMessages.compassCardHint($0.name, count: $0.count, of: compass.vacancyCount) } ?? PlanMessages.compassCardAllSet)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(.iconChevronRightSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10)
                .foregroundStyle(Color.inkMuted)
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(Color.panel, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
        .contentShape(.rect(cornerRadius: 16))
    }
}
