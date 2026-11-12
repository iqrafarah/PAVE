import PAVECore
import SwiftUI

/// Step 3: skills from the rest of your vault, and your own. Ayla's proposals from the design come later: she may only
/// read the evidence after step 4.
struct VaultSkillsPicker: View {
    @Bindable var flow: VaultAddEvidenceModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var search = ""
    @State private var showsAll = false
    @FocusState private var isSearching: Bool

    private static let shortList = 6

    private var known: [String] { flow.knownSkills }

    private var shown: [String] {
        showsAll ? known : Array(known.prefix(Self.shortList))
    }

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var matches: [String] {
        guard !query.isEmpty else { return [] }
        return known.filter { $0.localizedCaseInsensitiveContains(query) && !shown.contains($0) }.prefix(4).map { $0 }
    }

    private var canAddQuery: Bool {
        !query.isEmpty && !known.contains { $0.caseInsensitiveCompare(query) == .orderedSame } && !flow.isChosen(query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            section(VaultMessages.skillsFromVault) {
                if known.isEmpty {
                    Text(VaultMessages.skillsEmpty)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 6) {
                        ForEach(shown, id: \.self) { skill in
                            VaultSkillRow(name: skill, isChosen: flow.isChosen(skill)) { toggle(skill) }
                        }
                        if known.count > Self.shortList {
                            Button(showsAll ? "Minder tonen" : "Alle \(known.count) tonen") {
                                withAnimation(.snappy) { showsAll.toggle() }
                            }
                            .textStyle(.link)
                            .foregroundStyle(Color.brandGreen)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .padding(8)
                    .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Color.railBorder, lineWidth: 1) }
                }
            }

            section(VaultMessages.skillsOwn) {
                VStack(alignment: .leading, spacing: 10) {
                    searchField
                    if !matches.isEmpty || canAddQuery {
                        VStack(spacing: 6) {
                            ForEach(matches, id: \.self) { skill in
                                VaultSkillRow(name: skill, isChosen: flow.isChosen(skill)) { toggle(skill) }
                            }
                            if canAddQuery {
                                VaultSkillRow(name: VaultMessages.skillAdd(query), isChosen: false, action: addQuery)
                            }
                        }
                        .transition(.opacity)
                    }
                    if !flow.skills.isEmpty {
                        FlowLayout(spacing: 7) {
                            ForEach(flow.skills, id: \.self) { skill in
                                chosenChip(skill)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: flow.skills)
        .animation(.easeOut(duration: 0.2), value: query)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .textStyle(.listTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(.iconSearch)
                .renderingMode(.template)
                .foregroundStyle(Color.ink)
                .accessibilityHidden(true)
            TextField("", text: $search, prompt: Text(VaultMessages.skillsPrompt).foregroundStyle(Color.inkMuted))
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
                .autocorrectionDisabled()
                .focused($isSearching)
                .submitLabel(.done)
                .onSubmit(addQuery)
                .accessibilityLabel(VaultMessages.skillsOwn)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Color.railBorder, lineWidth: 1) }
    }

    private func chosenChip(_ skill: String) -> some View {
        Button { toggle(skill) } label: {
            HStack(spacing: 6) {
                Text(skill)
                    .textStyle(.meta)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Image(.iconXMark)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(Color.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 11)
            .frame(minHeight: 32)
            .background(Color.tileFill, in: .rect(cornerRadius: 7))
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .accessibilityLabel(skill)
        .accessibilityHint("Tik om weg te halen")
    }

    private func toggle(_ skill: String) {
        PaveHaptics.selection()
        flow.toggle(skill)
    }

    private func addQuery() {
        guard !query.isEmpty else { return }
        PaveHaptics.selection()
        if let existing = known.first(where: { $0.caseInsensitiveCompare(query) == .orderedSame }) {
            if !flow.isChosen(existing) { flow.toggle(existing) }
        } else {
            flow.addOwnSkill(query)
        }
        search = ""
    }
}

#Preview {
    ScrollView {
        VaultSkillsPicker(flow: VaultAddEvidenceModel(vault: VaultModel(previewContents: .preview), category: .projects, folderID: nil))
            .padding(24)
    }
}
