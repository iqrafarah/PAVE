import PAVECore
import SwiftUI

/// Writing a note yourself, or changing one: the text and the folders it belongs in. One note can be in more than one,
/// such as designing as both work and a hobby.
struct AylaMemoryEditor: View {
    let title: String
    @State var text: String
    @State var categories: [AylaMemory.Category]
    let onSave: (String, [AylaMemory.Category]) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    private var canSave: Bool { AylaMemory.clean(text) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bijvoorbeeld: Je wilt werken in de zorg-ICT…", text: $text, axis: .vertical)
                        .textStyle(.bodyMedium)
                        .lineLimit(2...6)
                        .focused($isFocused)
                        .onChange(of: text) { _, new in
                            if new.count > AylaMemory.maxLength { text = String(new.prefix(AylaMemory.maxLength)) }
                        }
                } footer: {
                    Text("Ayla gebruikt dit in je gesprekken op je iPhone, het web en je Apple Watch.")
                        .textStyle(.caption)
                }
                Section {
                    Menu {
                        ForEach(AylaMemory.Category.allCases, id: \.self) { category in
                            Toggle(category.title, isOn: binding(for: category))
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Categorie")
                                .foregroundStyle(Color.ink)
                            Spacer(minLength: 12)
                            Text(categories.map(\.title).joined(separator: ", "))
                                .foregroundStyle(Color.inkMuted)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                            Image(.iconChevronDown)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 10, height: 10)
                                .foregroundStyle(Color.inkMuted)
                                .accessibilityHidden(true)
                        }
                        .textStyle(.bodyMedium)
                        .contentShape(.rect)
                    }
                    // Stays open, so you can tick more than one.
                    .menuActionDismissBehavior(.disabled)
                    .accessibilityLabel("Categorie")
                    .accessibilityValue(categories.map(\.title).joined(separator: ", "))
                } footer: {
                    Text("Kies er één of meer, zoals Werk en stages én Interesses en hobby's.")
                        .textStyle(.caption)
                }
            }
            .tint(.brandGreen)
            .scrollContentBackground(.hidden)
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaren") {
                        PaveHaptics.success()
                        onSave(text, categories)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            // A new note starts typing; changing one leaves the categories in view.
            .onAppear { isFocused = text.isEmpty }
        }
        .presentationDetents([.large])
    }

    /// Ticking adds the category at the end; the last one cannot be unticked, a note always belongs somewhere.
    private func binding(for category: AylaMemory.Category) -> Binding<Bool> {
        Binding(
            get: { categories.contains(category) },
            set: { isOn in
                if isOn {
                    if !categories.contains(category) { categories.append(category) }
                } else if categories.count > 1 {
                    categories.removeAll { $0 == category }
                }
                PaveHaptics.selection()
            }
        )
    }
}

#Preview {
    AylaMemoryEditor(title: "Iets toevoegen", text: "", categories: [.work, .interests]) { _, _ in }
}
