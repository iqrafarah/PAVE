import PAVECore
import SwiftUI

/// On a project's page: the plans that belong to it, with how far each is. A tap opens the plan.
struct ProjectPlansList: View {
    let project: AylaProject

    @Environment(PlanModel.self) private var plans: PlanModel?
    @Environment(\.openPlan) private var openPlan

    private var linked: [PavePlan] { plans?.plans.filter { $0.projectID == project.id } ?? [] }

    var body: some View {
        if !linked.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(linked.count == 1 ? PlanMessages.projectPlan : PlanMessages.projectPlans)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .accessibilityAddTraits(.isHeader)
                ForEach(linked) { plan in
                    Button { openPlan?(plan.id) } label: {
                        HStack(spacing: 12) {
                            Image(.iconMapSolid)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .paveIconFrame(16)
                                .foregroundStyle(Color.paveAccent)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(plan.name).textStyle(.listTitle).foregroundStyle(Color.ink).lineLimit(1)
                                PlanProgressBar(progress: plan.progress)
                                Text("\(PlanMessages.progress(plan)) stappen afgerond")
                                    .textStyle(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(Color.inkMuted)
                            }
                            Image(.iconChevronRightSolid)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(Color.inkMuted)
                                .accessibilityHidden(true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.panel, in: .rect(cornerRadius: 14))
                        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.cardBorder) }
                        .contentShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.pave)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
