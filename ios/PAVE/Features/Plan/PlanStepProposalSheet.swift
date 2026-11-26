import PAVECore
import SwiftUI

/// "Laat Ayla stappen voorstellen": Ayla reads the plan's goal and the titles of the evidence she may see, and
/// proposes steps. Nothing goes into the plan until you pick which ones and add them.
struct PlanStepProposalSheet: View {
    let plan: PavePlan
    let onAdd: ([PavePlanTemplate.Step]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AylaChatModel.self) private var chat: AylaChatModel?
    @Environment(VaultModel.self) private var vault: VaultModel?
    @State private var steps: [PavePlanTemplate.Step]?
    @State private var chosen: Set<Int> = []
    @State private var failed = false
    @State private var round = 0

    private var request: PlanStepsRequest {
        PlanStepsRequest(name: plan.name, goal: plan.goal, existing: plan.steps.map(\.title), items: vault?.items ?? [], job: PlanVacancy.job(of: plan))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(PlanMessages.proposalReads(evidence: request.evidenceCount, hasVacancy: request.vacancy != nil))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if failed {
                        PaveInlineError(message: PlanMessages.proposalFailed)
                        PaveSecondaryButton(title: PlanMessages.proposalAgain) { round += 1 }
                    } else if let steps {
                        if steps.isEmpty {
                            Text(PlanMessages.proposalEmpty).textStyle(.bodyMedium).foregroundStyle(Color.ink)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                    row(step, index: index)
                                    if index < steps.count - 1 { Rectangle().fill(Color.cardBorder).frame(height: 1).padding(.leading, 48) }
                                }
                            }
                            .background(Color.panel, in: .rect(cornerRadius: 16))
                            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }
                        }
                    } else {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(PlanMessages.proposalThinking).textStyle(.bodyMedium).foregroundStyle(Color.inkMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if let steps, !steps.isEmpty, !failed {
                    VStack(spacing: 8) {
                        PavePrimaryButton(title: PlanMessages.proposalAdd(chosen.count)) {
                            PaveHaptics.success()
                            onAdd(steps.enumerated().filter { chosen.contains($0.offset) }.map(\.element))
                            dismiss()
                        }
                        .disabled(chosen.isEmpty)
                        Button(PlanMessages.proposalOthers) { round += 1 }
                            .textStyle(.link)
                            .foregroundStyle(Color.paveAccent)
                            .frame(minHeight: 44)
                            .buttonStyle(.pave)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .background(Color.canvas)
                }
            }
            .navigationTitle(PlanMessages.proposalTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { dismiss() } }
            }
            .task(id: round) { await load() }
        }
        .tint(.paveAccent)
    }

    private func row(_ step: PavePlanTemplate.Step, index: Int) -> some View {
        let isOn = chosen.contains(index)
        return Button {
            PaveHaptics.selection()
            if isOn { chosen.remove(index) } else { chosen.insert(index) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                PaveCheckbox(isOn: isOn, size: 20).padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title).textStyle(.listTitle).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                    if !step.summary.isEmpty {
                        Text(step.summary).textStyle(.caption).foregroundStyle(Color.inkMuted).multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(step.kind.title).textStyle(.caption).foregroundStyle(Color.paveAccent)
                }
                Spacer(minLength: 8)
                Image(step.kind.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(14)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func load() async {
        failed = false
        steps = nil
        guard let service = chat?.service else {
            failed = true
            return
        }
        do {
            let proposed = try await service.proposePlanSteps(request)
            steps = proposed
            chosen = Set(proposed.indices)
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}
