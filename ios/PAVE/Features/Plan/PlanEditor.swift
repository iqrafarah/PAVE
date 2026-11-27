import PAVECore
import SwiftUI

/// Making a plan or changing its name and goal. A new plan can start empty or with the steps of a template. Deleting
/// closes the editor; whoever opened it asks the question.
struct PlanEditor: View {
    @Environment(\.dismiss) private var dismiss
    let plan: PavePlan?
    let onSave: (_ name: String, _ goal: String, _ template: PavePlanTemplate) async -> Bool
    var onDelete: (() -> Void)?

    @State private var name: String
    @State private var goal: String
    @State private var template = PavePlanTemplate.empty
    @State private var isSaving = false
    @State private var problem: String?
    @FocusState private var focus: Field?

    private enum Field { case name, goal }

    init(plan: PavePlan?, onSave: @escaping (String, String, PavePlanTemplate) async -> Bool, onDelete: (() -> Void)? = nil) {
        self.plan = plan
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: plan?.name ?? "")
        _goal = State(initialValue: plan?.goal ?? "")
    }

    private var cleanName: String? { PavePlan.cleanName(name) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PlanField(label: PlanMessages.nameLabel) {
                        TextField("", text: $name, prompt: Text(PlanMessages.namePlaceholder).foregroundStyle(Color.inkMuted))
                            .focused($focus, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focus = .goal }
                            .onChange(of: name) { _, value in
                                if value.count > PavePlan.maxNameLength { name = String(value.prefix(PavePlan.maxNameLength)) }
                            }
                    }

                    PlanField(label: PlanMessages.goalLabel, hint: PlanMessages.goalHint) {
                        TextField("", text: $goal, prompt: Text(PlanMessages.goalPlaceholder).foregroundStyle(Color.inkMuted), axis: .vertical)
                            .lineLimit(2...5)
                            .focused($focus, equals: .goal)
                            .onChange(of: goal) { _, value in
                                if value.count > PavePlan.maxGoalLength { goal = String(value.prefix(PavePlan.maxGoalLength)) }
                            }
                    }

                    if plan == nil {
                        templatePicker
                    }

                    if let problem {
                        PaveInlineError(message: problem)
                    }

                    if plan != nil, onDelete != nil {
                        // The question (and whether to keep the plan's chats) comes once the editor is closed.
                        Button(PlanMessages.delete, role: .destructive) {
                            onDelete?()
                            dismiss()
                        }
                            .textStyle(.action)
                            .frame(minHeight: 44)
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(plan == nil ? PlanMessages.newPlan : PlanMessages.edit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ApplyMessages.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(plan == nil ? PlanMessages.create : "Bewaren") { save() }
                        .disabled(cleanName == nil || isSaving)
                }
            }
            .onAppear { if plan == nil { focus = .name } }
        }
        .tint(.paveAccent)
    }

    /// Start empty or with the steps of a template; the template's goal fills in an empty goal.
    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PlanMessages.startLabel)
                .textStyle(.label)
                .foregroundStyle(Color.ink)
            VStack(spacing: 8) {
                ForEach(PlanTemplates.all) { option in
                    Button {
                        PaveHaptics.tap(.light)
                        if goal.isEmpty || goal == template.goal { goal = option.goal }
                        if name.isEmpty || name == template.name { name = option.name }
                        template = option
                    } label: {
                        HStack(spacing: 12) {
                            PlanBadge(templateID: option.id, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(PlanTemplates.title(of: option))
                                    .textStyle(.listTitle)
                                    .foregroundStyle(Color.ink)
                                Text(PlanTemplates.summary(of: option) + (option.steps.isEmpty ? "" : " · \(PlanMessages.stepCount(option.steps.count))"))
                                    .textStyle(.caption)
                                    .foregroundStyle(Color.inkMuted)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            PlanStepMark(status: option.id == template.id ? .done : .upcoming)
                        }
                        .padding(12)
                        .background(Color.panel, in: .rect(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(option.id == template.id ? Color.paveAccent : Color.cardBorder, lineWidth: option.id == template.id ? 1.5 : 1)
                        }
                        .contentShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.pave)
                    .accessibilityAddTraits(option.id == template.id ? .isSelected : [])
                }
            }
        }
    }

    private func save() {
        guard let cleanName, !isSaving else { return }
        isSaving = true
        Task {
            let saved = await onSave(cleanName, goal, template)
            isSaving = false
            if saved {
                dismiss()
            } else {
                problem = PlanMessages.saveFailed
                AccessibilityNotification.Announcement(PlanMessages.saveFailed).post()
            }
        }
    }
}

/// Adding a step or changing one.
struct PlanStepEditor: View {
    @Environment(\.dismiss) private var dismiss
    let step: PavePlanStep?
    let onSave: (PavePlanStep) -> Void
    var onDelete: (() -> Void)?

    @State private var title: String
    @State private var summary: String
    @State private var kind: PavePlanStep.Kind
    @FocusState private var focusesTitle: Bool

    init(step: PavePlanStep?, onSave: @escaping (PavePlanStep) -> Void, onDelete: (() -> Void)? = nil) {
        self.step = step
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: step?.title ?? "")
        _summary = State(initialValue: step?.summary ?? "")
        _kind = State(initialValue: step?.kind ?? .general)
    }

    /// The known kinds, and the step's own kind when a flow brought one the app does not know.
    private var kinds: [PavePlanStep.Kind] {
        PavePlanStep.Kind.choosable.contains(kind) ? PavePlanStep.Kind.choosable : PavePlanStep.Kind.choosable + [kind]
    }

    private var cleanTitle: String? { PavePlan.cleanName(title) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PlanField(label: PlanMessages.stepTitleLabel) {
                        TextField("", text: $title, prompt: Text(PlanMessages.stepTitlePlaceholder).foregroundStyle(Color.inkMuted))
                            .focused($focusesTitle)
                    }
                    PlanField(label: PlanMessages.stepSummaryLabel) {
                        TextField("", text: $summary, prompt: Text(PlanMessages.stepSummaryPlaceholder).foregroundStyle(Color.inkMuted), axis: .vertical)
                            .lineLimit(2...4)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(PlanMessages.kindLabel)
                            .textStyle(.label)
                            .foregroundStyle(Color.ink)
                        Menu {
                            Picker(PlanMessages.kindLabel, selection: $kind) {
                                ForEach(kinds, id: \.self) { option in
                                    Label { Text(option.title) } icon: { Image(option.icon).renderingMode(.template) }
                                        .tag(option)
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(kind.icon)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .paveIconFrame(16)
                                    .foregroundStyle(Color.paveAccent)
                                Text(kind.title)
                                    .textStyle(.input)
                                    .foregroundStyle(Color.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(.iconChevronDown)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .paveIconHeight(6)
                                    .foregroundStyle(Color.inkMuted)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 48)
                            .background(Color.panel, in: .rect(cornerRadius: 10))
                            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.cardBorder) }
                        }
                        .accessibilityLabel("\(PlanMessages.kindLabel): \(kind.title)")
                    }
                    if step != nil, let onDelete {
                        Button(PlanMessages.deleteStep, role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        .textStyle(.action)
                        .frame(minHeight: 44)
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(step == nil ? PlanMessages.addStep : PlanMessages.editStep)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ApplyMessages.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(step == nil ? "Toevoegen" : "Bewaren") {
                        guard let cleanTitle else { return }
                        var saved = step ?? PavePlanStep(title: cleanTitle)
                        saved.title = cleanTitle
                        saved.summary = PavePlan.cleanGoal(summary)
                        saved.kind = kind
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(cleanTitle == nil)
                }
            }
            .onAppear { if step == nil { focusesTitle = true } }
        }
        .tint(.paveAccent)
    }
}

/// A label with a text field in PAVE's style, as in the project editor.
private struct PlanField<Field: View>: View {
    let label: String
    var hint: String?
    @ViewBuilder let field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .textStyle(.label)
                .foregroundStyle(Color.ink)
            if let hint {
                Text(hint)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            field
                .textStyle(.input)
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .frame(minHeight: 48)
                .background(Color.panel, in: .rect(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.cardBorder) }
        }
    }
}

#Preview {
    PlanEditor(plan: nil) { _, _, _ in true }
}
