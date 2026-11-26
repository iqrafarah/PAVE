import PAVECore
import SwiftUI

/// On a vacancy's page: make a plan towards applying for it, or open the plan you already have for it, with how far
/// you are. The plan gets steps for what you still miss, your CV and letter, sharing and practising the talk.
struct VacancyPlanLink: View {
    let vacancy: Vacancy

    @Environment(PlanModel.self) private var plans: PlanModel?
    @Environment(\.openDestination) private var openDestination
    @Environment(\.dismiss) private var dismiss
    @State private var isMaking = false

    private var plan: PavePlan? { plans?.plans.first { PlanVacancy.vacancyID(of: $0) == vacancy.id } }

    var body: some View {
        if let plans, plans.isAvailable, let openDestination {
            Button {
                PaveHaptics.tap(.light)
                if let plan {
                    open(plan.id, in: plans, go: openDestination)
                } else {
                    isMaking = true
                    Task {
                        let template = PlanVacancy.template(for: vacancy)
                        let made = await plans.create(name: template.name, goal: template.goal, from: template)
                        isMaking = false
                        if let made {
                            PaveHaptics.success()
                            open(made.id, in: plans, go: openDestination)
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(.iconMapSolid)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .paveIconFrame(18)
                        .foregroundStyle(Color.paveAccent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan == nil ? PlanMessages.vacancyPlanMake : PlanMessages.vacancyPlanOpen)
                            .textStyle(.label)
                            .foregroundStyle(Color.ink)
                        Text(plan.map { "\(PlanMessages.progress($0)) stappen afgerond" } ?? PlanMessages.vacancyPlanHint(vacancy.skillGap.count))
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    if isMaking {
                        ProgressView()
                    } else {
                        Image(.iconChevronRightSolid)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                            .foregroundStyle(Color.inkMuted)
                            .accessibilityHidden(true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.panel, in: .rect(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.cardBorder, lineWidth: 1) }
                .contentShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.pave)
            .disabled(isMaking)
            .accessibilityElement(children: .combine)
        }
    }

    private func open(_ id: String, in plans: PlanModel, go: (MainDestination) -> Void) {
        plans.openPlanID = id
        dismiss()
        go(.plan)
    }
}
