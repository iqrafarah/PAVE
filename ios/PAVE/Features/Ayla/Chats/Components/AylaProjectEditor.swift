import PAVECore
import SwiftUI

/// Making a project or changing one (web AylaProjectEditor): a name, its own icon and colour, and the instructions Ayla
/// follows in every chat of the project. Deleting keeps the chats; they only no longer belong to a project.
struct AylaProjectEditor: View {
    @Environment(\.dismiss) private var dismiss
    let project: AylaProject?
    /// False until projects can have an icon and colour of their own.
    var canStyle = false
    let onSave: (_ name: String, _ instructions: String, _ icon: VaultFolderIcon?, _ color: VaultFolderColor?) async -> Bool
    var onDelete: (() -> Void)?

    @State private var name: String
    @State private var instructions: String
    @State private var icon: VaultFolderIcon?
    @State private var color: VaultFolderColor?
    @State private var isSaving = false
    @State private var problem: String?
    @State private var confirmsDelete = false
    @FocusState private var focus: Field?

    private enum Field { case name, instructions }

    init(
        project: AylaProject?, canStyle: Bool = false,
        onSave: @escaping (String, String, VaultFolderIcon?, VaultFolderColor?) async -> Bool, onDelete: (() -> Void)? = nil
    ) {
        self.project = project
        self.canStyle = canStyle
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: project?.name ?? "")
        _instructions = State(initialValue: project?.instructions ?? "")
        _icon = State(initialValue: project?.icon)
        _color = State(initialValue: project?.color)
    }

    /// How the project will look, with the name typed so far.
    private var preview: AylaProject {
        AylaProject(id: project?.id ?? "new", name: name, icon: icon, color: color)
    }

    private var cleanName: String? { AylaProject.cleanName(name) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if canStyle {
                        AylaProjectBadge(project: preview, size: 64)
                            .frame(maxWidth: .infinity)
                            .animation(.snappy(duration: 0.2), value: icon)
                            .animation(.snappy(duration: 0.2), value: color)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AylaMessages.projectNameLabel)
                            .textStyle(.label)
                            .foregroundStyle(Color.ink)
                        TextField("", text: $name, prompt: Text(AylaMessages.projectNamePlaceholder).foregroundStyle(Color.inkMuted))
                            .textStyle(.input)
                            .foregroundStyle(Color.ink)
                            .focused($focus, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focus = .instructions }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 48)
                            .background(Color.panel, in: .rect(cornerRadius: 10))
                            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.cardBorder) }
                            .onChange(of: name) { _, value in
                                if value.count > AylaProject.maxNameLength { name = String(value.prefix(AylaProject.maxNameLength)) }
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(AylaMessages.projectInstructions)
                            .textStyle(.label)
                            .foregroundStyle(Color.ink)
                        Text(AylaMessages.projectInstructionsHint)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField(
                            "", text: $instructions,
                            prompt: Text(AylaMessages.projectInstructionsPlaceholder).foregroundStyle(Color.inkMuted),
                            axis: .vertical
                        )
                        .lineLimit(5...12)
                        .textStyle(.input)
                        .foregroundStyle(Color.ink)
                        .focused($focus, equals: .instructions)
                        .padding(14)
                        .background(Color.panel, in: .rect(cornerRadius: 10))
                        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(Color.cardBorder) }
                        .onChange(of: instructions) { _, value in
                            if value.count > AylaProject.maxInstructionsLength {
                                instructions = String(value.prefix(AylaProject.maxInstructionsLength))
                            }
                        }
                        Text("\(instructions.count)/\(AylaProject.maxInstructionsLength)")
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .accessibilityLabel("\(instructions.count) van \(AylaProject.maxInstructionsLength) tekens")
                    }

                    if canStyle {
                        AylaLookPicker(icon: $icon, color: $color)
                    }

                    if let problem {
                        PaveInlineError(message: problem)
                    }

                    if project != nil, onDelete != nil {
                        Button(AylaMessages.projectDelete, role: .destructive) { confirmsDelete = true }
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
            .navigationTitle(project == nil ? AylaMessages.newProject : AylaMessages.projectEdit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ApplyMessages.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(project == nil ? AylaMessages.projectCreate : "Bewaren") { save() }
                        .disabled(cleanName == nil || isSaving)
                }
            }
            .confirmationDialog(AylaMessages.projectDeleteQuestion, isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button(AylaMessages.projectDelete, role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text(AylaMessages.projectDeleteBody)
            }
            .onAppear { if project == nil { focus = .name } }
        }
        .tint(.paveAccent)
    }

    private func save() {
        guard let cleanName, !isSaving else { return }
        isSaving = true
        Task {
            let saved = await onSave(cleanName, instructions.trimmingCharacters(in: .whitespacesAndNewlines), icon, color)
            isSaving = false
            if saved {
                dismiss()
            } else {
                problem = AylaMessages.projectFailed
                AccessibilityNotification.Announcement(AylaMessages.projectFailed).post()
            }
        }
    }
}

#Preview {
    AylaProjectEditor(project: nil, canStyle: true) { _, _, _, _ in true }
}
