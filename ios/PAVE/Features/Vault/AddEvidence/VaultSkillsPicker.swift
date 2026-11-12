import PAVECore
import SwiftUI

/// Skills for a piece of evidence, as on the web (Figma 1348:2064 and 1173:15642): skills from the rest of your vault and
/// Ayla's proposals side by side where there is room, under each other on a phone, and your own below.
struct VaultSkillsPicker: View {
    @Binding var skills: [String]
    let known: [String]
    @Bindable var ayla: VaultAylaSkills
    let draft: VaultItemDraft
    /// When adding evidence, Ayla starts looking as soon as you reach the skills.
    var asksAylaOnAppear = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var search = ""
    @State private var showsAll = false
    @State private var width: CGFloat = 400
    @FocusState private var isSearching: Bool

    private static let shortList = 6

    private var shown: [String] { showsAll ? known : Array(known.prefix(Self.shortList)) }

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var matches: [String] {
        guard !query.isEmpty else { return [] }
        return known.filter { $0.localizedCaseInsensitiveContains(query) && !shown.contains($0) }.prefix(4).map { $0 }
    }

    private var canAddQuery: Bool {
        !query.isEmpty && !known.contains { $0.caseInsensitiveCompare(query) == .orderedSame } && !isChosen(query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if width >= 520 {
                HStack(alignment: .top, spacing: 16) {
                    vaultSection.frame(maxWidth: .infinity, alignment: .topLeading)
                    aylaSection.frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                vaultSection
                aylaSection
            }
            ownSection
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .background {
            Color.white
                .contentShape(.rect)
                .onTapGesture { isSearching = false }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: skills)
        .animation(.easeOut(duration: 0.2), value: query)
        .task {
            guard asksAylaOnAppear, ayla.state == .idle else { return }
            await askAyla()
        }
    }

    private func askAyla() async {
        await ayla.ask(for: draft, existing: VaultSkills.cleaned(skills + known))
    }

    private var vaultSection: some View {
        section(Text(VaultMessages.skillsFromVault)) {
            if known.isEmpty {
                Text(VaultMessages.skillsEmpty)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 6) {
                    ForEach(shown, id: \.self) { skill in
                        VaultSkillRow(name: skill, isChosen: isChosen(skill)) { toggle(skill) }
                    }
                    if known.count > Self.shortList {
                        Button(showsAll ? "Minder tonen" : "Alle \(known.count) tonen") {
                            withAnimation(.snappy) { showsAll.toggle() }
                        }
                        .textStyle(.link)
                        .foregroundStyle(Color.paveAccent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(8)
                .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Color.railBorder, lineWidth: 1) }
            }
        }
    }

    private var aylaSection: some View {
        section(Text("Voorstel van ") + Text("Ayla").foregroundStyle(Color.paveAccent)) {
            VaultAylaSuggestions(ayla: ayla, isChosen: isChosen, onToggle: toggle) {
                isSearching = false
                Task { await askAyla() }
            }
        }
    }

    private var ownSection: some View {
        section(Text(VaultMessages.skillsOwn)) {
            VStack(alignment: .leading, spacing: 10) {
                searchField
                if !matches.isEmpty || canAddQuery {
                    VStack(spacing: 6) {
                        ForEach(matches, id: \.self) { skill in
                            VaultSkillRow(name: skill, isChosen: isChosen(skill)) { toggle(skill) }
                        }
                        if canAddQuery {
                            VaultSkillRow(name: VaultMessages.skillAdd(query), isChosen: false, action: addQuery)
                        }
                    }
                    .transition(.opacity)
                }
                if !skills.isEmpty {
                    FlowLayout(spacing: 7) {
                        ForEach(skills, id: \.self) { chosenChip($0) }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func section<Content: View>(_ title: Text, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            title
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

    private func isChosen(_ skill: String) -> Bool {
        skills.contains { $0.caseInsensitiveCompare(skill) == .orderedSame }
    }

    private func toggle(_ skill: String) {
        PaveHaptics.selection()
        if isChosen(skill) {
            skills.removeAll { $0.caseInsensitiveCompare(skill) == .orderedSame }
        } else {
            skills = VaultSkills.cleaned(skills + [skill])
        }
    }

    private func addQuery() {
        isSearching = false
        guard !query.isEmpty else { return }
        PaveHaptics.selection()
        let name = known.first { $0.caseInsensitiveCompare(query) == .orderedSame } ?? query
        if !isChosen(name) { skills = VaultSkills.cleaned(skills + [name]) }
        search = ""
    }
}
