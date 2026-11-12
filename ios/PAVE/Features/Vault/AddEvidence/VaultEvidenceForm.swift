import PAVECore
import SwiftUI

/// Step 1, second half: what the evidence is. Two columns where they fit, as in Figma; one column on a narrow screen.
struct VaultEvidenceForm: View {
    @Bindable var flow: VaultAddEvidenceModel
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
            if let document = flow.document {
                VaultFileRow(upload: document) {
                    withAnimation(.snappy) { flow.removeDocument() }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                VaultFormField(title: "Titel", error: error(.title)) {
                    TextField("", text: $flow.draft.title, prompt: prompt("Bijv. Eindstage"), axis: .vertical)
                        .lineLimit(1...3)
                        .textStyle(.input)
                        .foregroundStyle(Color.ink)
                        .focused($focus, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focus = .organisation }
                }
                VaultFormField(title: "Soort bewijs") {
                    category
                }
                VaultFormField(title: "Organisatie / school", error: error(.organisation)) {
                    TextField("", text: $flow.draft.organisationName, prompt: prompt("Bijv. LiveWall"))
                        .textStyle(.input)
                        .foregroundStyle(Color.ink)
                        .textContentType(.organizationName)
                        .focused($focus, equals: .organisation)
                        .submitLabel(.next)
                        .onSubmit { focus = .description }
                }
                VaultFormField(title: "Periode", error: error(.period)) {
                    period
                }
            }
            VaultFormField(title: "Beschrijving", error: error(.description), minHeight: 114) {
                TextField("", text: $flow.draft.description, prompt: prompt("Wat heb je gedaan of geleerd?"), axis: .vertical)
                    .lineLimit(4...10)
                    .textStyle(.input)
                    .foregroundStyle(Color.ink)
                    .focused($focus, equals: .description)
                    .padding(.vertical, 12)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .sheet(isPresented: $editsPeriod) {
            VaultPeriodSheet(draft: $flow.draft)
        }
        .onChange(of: flow.showsMissing) { _, shows in
            guard shows, let first = flow.missingFields.first else { return }
            switch first {
            case .title: focus = .title
            case .organisation: focus = .organisation
            case .description: focus = .description
            case .period: focus = nil
            }
        }
        .animation(.snappy(duration: 0.3), value: flow.document)
    }

    private var category: some View {
        Menu {
            Picker("Soort bewijs", selection: $flow.draft.category) {
                ForEach(VaultCategory.allCases) { category in
                    Text(category.singularTitle).tag(category)
                }
            }
        } label: {
            HStack {
                Text(flow.draft.category.singularTitle)
                    .textStyle(.input)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(.iconChevronDown)
                    .renderingMode(.template)
                    .foregroundStyle(Color.inkMuted)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .accessibilityValue(flow.draft.category.singularTitle)
    }

    private var period: some View {
        Button {
            focus = nil
            editsPeriod = true
        } label: {
            HStack {
                Text(flow.draft.period ?? "Kies een datum")
                    .textStyle(.input)
                    .foregroundStyle(flow.draft.period == nil ? Color.inkMuted : .ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                Image(.iconCalendarDaysSolid)
                    .renderingMode(.template)
                    .foregroundStyle(Color.inkMuted)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityValue(flow.draft.period ?? "Nog niet gekozen")
    }

    private func prompt(_ text: String) -> Text {
        Text(text).foregroundStyle(Color.inkMuted)
    }

    private func error(_ field: VaultItemDraft.Field) -> String? {
        flow.missingFields.contains(field) ? VaultMessages.missing(field, category: flow.draft.category) : nil
    }
}

#Preview {
    ScrollView {
        VaultEvidenceForm(flow: VaultAddEvidenceModel(vault: VaultModel(previewContents: .preview), category: .internships, folderID: nil))
            .padding(24)
    }
}
