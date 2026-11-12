import PAVECore
import SwiftUI

/// What the evidence is: title, kind, organisation, period, folder and description. Two columns where they fit, as in
/// Figma; one column on a narrow screen. The return key confirms the text and closes the keyboard in every field, like
/// tapping next to it. Used for adding and for changing evidence.
struct VaultEvidenceForm: View {
    @Binding var draft: VaultItemDraft
    /// The fields to mark as missing; empty until the user tried to go on.
    let missing: [VaultItemDraft.Field]
    let folders: [VaultFolder]
    /// The user chose a folder (or none) on purpose, so it no longer follows the kind of evidence.
    var onFolderChosen: () -> Void = {}
    /// A folder for the kind that does not exist yet and is made when saving, such as Stages; ticked on at first.
    var newFolder: NewFolder?

    struct NewFolder {
        let name: String
        let isOn: Bool
        let onToggle: (Bool) -> Void
    }

    @State private var width: CGFloat = 400
    @State private var editsPeriod = false
    @FocusState private var focus: Field?

    private enum Field { case title, organisation, description }

    private var columns: [GridItem] {
        let count = width >= 330 ? 2 : 1
        return Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                VaultFormField(title: "Titel", error: error(.title)) {
                    TextField("", text: $draft.title, prompt: prompt("Bijv. Eindstage"))
                        .textStyle(.input)
                        .foregroundStyle(Color.ink)
                        .focused($focus, equals: .title)
                        .submitLabel(.done)
                        .onSubmit { focus = nil }
                }
                VaultFormField(title: "Soort bewijs") {
                    category
                }
                VaultFormField(title: "Organisatie / school", error: error(.organisation)) {
                    TextField("", text: $draft.organisationName, prompt: prompt("Bijv. LiveWall"))
                        .textStyle(.input)
                        .foregroundStyle(Color.ink)
                        .textContentType(.organizationName)
                        .focused($focus, equals: .organisation)
                        .submitLabel(.done)
                        .onSubmit { focus = nil }
                }
                VaultFormField(title: "Periode", error: error(.period)) {
                    period
                }
            }
            if !folders.isEmpty || newFolder != nil {
                VaultFormField(title: "Mappen", isRequired: false) {
                    folder
                }
            }
            VaultFormField(title: "Beschrijving", error: error(.description), minHeight: 114) {
                TextField("", text: $draft.description, prompt: prompt("Wat heb je gedaan of geleerd?"), axis: .vertical)
                    .lineLimit(4...10)
                    .textStyle(.input)
                    .foregroundStyle(Color.ink)
                    .focused($focus, equals: .description)
                    .submitLabel(.done)
                    // A text field over several lines turns return into a new line; here it closes the keyboard instead.
                    .onChange(of: draft.description) { old, new in
                        guard new.count == old.count + 1, new.hasSuffix("\n") else { return }
                        draft.description = old
                        focus = nil
                    }
                    .padding(.vertical, 12)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background {
            Color.white
                .contentShape(.rect)
                .onTapGesture { focus = nil }
        }
        .sheet(isPresented: $editsPeriod) {
            VaultPeriodSheet(draft: $draft)
        }
        .onChange(of: missing) { _, missing in
            switch missing.first {
            case .title: focus = .title
            case .organisation: focus = .organisation
            case .description: focus = .description
            case .period, nil: break
            }
        }
    }

    private var category: some View {
        Menu {
            Picker("Soort bewijs", selection: $draft.category) {
                ForEach(VaultCategory.allCases) { category in
                    Text(category.singularTitle).tag(category)
                }
            }
        } label: {
            menuLabel(draft.category.singularTitle, icon: .iconChevronDown)
        }
        .accessibilityValue(draft.category.singularTitle)
    }

    private var chosenFolders: String {
        var names = folders.filter { draft.folderIDs.contains($0.id) }.map(\.name)
        if let newFolder, newFolder.isOn { names.append(newFolder.name) }
        return names.isEmpty ? "Geen map" : names.joined(separator: ", ")
    }

    /// Several folders can be ticked; the menu stays open while you tick them.
    private var folder: some View {
        Menu {
            if let newFolder {
                Toggle(isOn: Binding(get: { newFolder.isOn }, set: newFolder.onToggle)) {
                    Text(VaultMessages.newKindFolder(newFolder.name))
                }
            }
            ForEach(folders) { folder in
                Toggle(isOn: Binding(
                    get: { draft.folderIDs.contains(folder.id) },
                    set: { isOn in
                        if isOn { draft.folderIDs.append(folder.id) } else { draft.folderIDs.removeAll { $0 == folder.id } }
                        onFolderChosen()
                    }
                )) {
                    Text(folder.name)
                }
            }
        } label: {
            menuLabel(chosenFolders, icon: .iconChevronDown, isPlaceholder: chosenFolders == "Geen map")
        }
        .menuActionDismissBehavior(.disabled)
        .accessibilityValue(chosenFolders)
    }

    private var period: some View {
        Button {
            focus = nil
            editsPeriod = true
        } label: {
            menuLabel(draft.period ?? (draft.isPeriod ? "Kies van en tot" : "Kies een datum"), icon: .iconCalendarDaysSolid, isPlaceholder: draft.period == nil)
        }
        .buttonStyle(.pave)
        .accessibilityValue(draft.period ?? "Nog niet gekozen")
    }

    private func menuLabel(_ text: String, icon: ImageResource, isPlaceholder: Bool = false) -> some View {
        HStack {
            Text(text)
                .textStyle(.input)
                .foregroundStyle(isPlaceholder ? Color.inkMuted : .ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            Image(icon)
                .renderingMode(.template)
                .foregroundStyle(Color.inkMuted)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(.rect)
    }

    private func prompt(_ text: String) -> Text {
        Text(text).foregroundStyle(Color.inkMuted)
    }

    private func error(_ field: VaultItemDraft.Field) -> String? {
        missing.contains(field) ? VaultMessages.missing(field, isPeriod: draft.isPeriod) : nil
    }
}

#Preview {
    @Previewable @State var draft = VaultItemDraft(category: .internships)
    ScrollView {
        VaultEvidenceForm(draft: $draft, missing: [], folders: [])
            .padding(24)
    }
}
