import PAVECore
import SwiftUI

/// Making a folder or changing one: a name, a colour and an icon, with the folder shown as it will look.
/// The style follows the "Bewijs toevoegen" sheet in Figma: a white sheet, a large title and one wide button.
struct VaultFolderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(VaultModel.self) private var model
    let folder: VaultFolder?
    let onCreate: (VaultFolder) -> Void

    @State private var name: String
    @State private var color: VaultFolderColor
    @State private var icon: VaultFolderIcon
    @State private var isSaving = false
    @State private var created: VaultFolder?
    @State private var error: String?
    @FocusState private var isNameFocused: Bool

    init(
        folder: VaultFolder?,
        style: (color: VaultFolderColor, icon: VaultFolderIcon)?,
        onCreate: @escaping (VaultFolder) -> Void = { _ in }
    ) {
        self.folder = folder
        self.onCreate = onCreate
        _name = State(initialValue: folder?.name ?? "")
        _color = State(initialValue: style?.color ?? .green)
        _icon = State(initialValue: style?.icon ?? .folder)
    }

    /// The outer display of the iPhone Duo and an iPhone held sideways have little height: less space between parts.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var size = CGSize(width: 400, height: 800)
    private var isShort: Bool { verticalSizeClass == .compact || size.height < 720 }
    /// Wide and low, like the card on the open iPhone Duo or an iPad held sideways: two columns, so nothing hides under the button.
    private var isWide: Bool { size.width >= 500 && size.height < 560 }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isNew: Bool { folder == nil }
    private static let errors = [VaultMessages.folderNameTaken, VaultMessages.folderNameMissing, VaultMessages.message(for: .noConnection)]

    var body: some View {
        Group {
            if let created {
                success(created)
                    .transition(.opacity)
            } else {
                form
            }
        }
        .frame(maxWidth: isWide ? 760 : 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .background(Color.white.ignoresSafeArea())
        .tint(.paveAccent)
    }

    private var form: some View {
        VStack(spacing: 0) {
            ScrollView {
                Group {
                    if isWide {
                        HStack(alignment: .top, spacing: 28) {
                            VStack(alignment: .leading, spacing: 16) {
                                title
                                preview
                                nameField
                            }
                            .frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: 16) {
                                colors
                                icons
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: isShort ? 16 : 24) {
                            title
                            preview
                            nameField
                            colors
                            icons
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, isShort ? 20 : 28)
                .padding(.bottom, 16)
                // Tapping an empty spot closes the keyboard, also when everything fits and nothing scrolls.
                .background {
                    Color.white
                        .contentShape(.rect)
                        .onTapGesture { isNameFocused = false }
                }
            }
            .scrollDismissesKeyboard(.interactively)

            PavePrimaryButton(
                title: isNew ? "Map aanmaken" : "Bewaren",
                loadingTitle: "Bewaren…",
                isLoading: isSaving,
                action: save
            )
            .frame(maxWidth: isWide ? 360 : .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    private var title: some View {
        Text(isNew ? VaultMessages.newFolderTitle : "Map aanpassen")
            .textStyle(.emptyTitle)
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private var preview: some View {
        VaultFolderTile(
            title: trimmedName.isEmpty ? VaultMessages.newFolderTitle : trimmedName,
            icon: icon.image,
            color: color.color,
            surface: color.surface,
            count: folder.map { model.count(in: .folder($0.id)) } ?? 0,
            isSelected: false
        ) {}
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Naam")
                .textStyle(.label)
                .foregroundStyle(Color.ink)
            TextField("Bijvoorbeeld Stage of Bijbaan", text: $name)
                .textStyle(.input)
                .foregroundStyle(Color.ink)
                .focused($isNameFocused)
                // Return only closes the keyboard; the folder is made with the button, after choosing a colour and icon.
                .submitLabel(.done)
                .onSubmit { isNameFocused = false }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(Color.white, in: .rect(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(error == nil ? Color.cardBorder : Color.critical, lineWidth: error == nil ? 1 : 1.5)
                }
                .accessibilityLabel("Naam van de map")
                .onChange(of: name) { error = nil }
            MessageSlot(message: error, reserving: Self.errors) { PaveInlineError(message: $0) }
        }
    }

    private var colors: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kleur")
                .textStyle(.label)
                .foregroundStyle(Color.ink)
            HStack(spacing: 0) {
                ForEach(VaultFolderColor.allCases, id: \.self) { option in
                    colorButton(option)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var icons: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Icoon")
                .textStyle(.label)
                .foregroundStyle(Color.ink)
            // As many columns as fit, each at least 44 points so every icon stays easy to tap.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 64), spacing: 8)], spacing: 8) {
                ForEach(VaultFolderIcon.allCases, id: \.self) { option in
                    iconButton(option)
                }
            }
        }
    }

    private func colorButton(_ option: VaultFolderColor) -> some View {
        let isOn = option == color
        return Button {
            color = option
            PaveHaptics.selection()
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: 30, height: 30)
                .padding(4)
                .overlay { Circle().strokeBorder(isOn ? option.color : .clear, lineWidth: 2) }
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.pave)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func iconButton(_ option: VaultFolderIcon) -> some View {
        let isOn = option == icon
        return Button {
            icon = option
            PaveHaptics.selection()
        } label: {
            Image(option.image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(isOn ? Color.white : Color.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isOn ? color.color : Color.paveSurfaceTint, in: .rect(cornerRadius: 10))
                .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.pave)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func success(_ folder: VaultFolder) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            Text("Map aangemaakt")
                .textStyle(.welcomeTitle)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            Image(.iconCheck)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundStyle(.white)
                .frame(width: 112, height: 112)
                .background(Color.paveAccent, in: .circle)
                .accessibilityHidden(true)
            VaultFolderTile(title: folder.name, icon: icon.image, color: color.color, surface: color.surface, count: 0, isSelected: false) {}
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            PavePrimaryButton(title: "Naar de map") {
                onCreate(folder)
                dismiss()
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
    }

    private func save() {
        guard !isSaving else { return }
        let name = String(trimmedName.prefix(VaultFolder.maximumNameLength))
        guard !name.isEmpty else {
            show(VaultMessages.folderNameMissing)
            return
        }
        guard !model.isFolderNameTaken(name, except: folder?.id) else {
            show(VaultMessages.folderNameTaken)
            return
        }
        isNameFocused = false
        isSaving = true
        Task {
            if let folder {
                let saved = await model.updateFolder(folder, name: name, color: color, icon: icon)
                isSaving = false
                if saved { dismiss() } else { show(takeProblem()) }
            } else if let new = await model.createFolder(named: name, color: color, icon: icon) {
                isSaving = false
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { created = new }
            } else {
                isSaving = false
                show(takeProblem())
            }
        }
    }

    private func takeProblem() -> String {
        defer { model.problem = nil }
        return model.problem ?? VaultMessages.message(for: .unavailable)
    }

    private func show(_ message: String) {
        PaveHaptics.error()
        withAnimation(.easeOut(duration: 0.2)) { error = message }
        AccessibilityNotification.Announcement(message).post()
        isNameFocused = true
    }
}

#Preview {
    Color.canvas
        .sheet(isPresented: .constant(true)) {
            VaultFolderEditor(folder: nil, style: nil)
                .environment(VaultModel(previewContents: .preview))
                .presentationDragIndicator(.visible)
        }
}
