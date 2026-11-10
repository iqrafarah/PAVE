import PAVECore
import SwiftUI

/// Writing a note yourself, or changing one: the text and where it belongs.
struct AylaMemoryEditor: View {
    let title: String
    @State var text: String
    @State var category: AylaMemory.Category
    let onSave: (String, AylaMemory.Category) -> Void

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
                Section("Categorie") {
                    Picker("Categorie", selection: $category) {
                        ForEach(AylaMemory.Category.allCases, id: \.self) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
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
                        onSave(text, category)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            // A new note starts typing; changing one leaves the category in view.
            .onAppear { isFocused = text.isEmpty }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    AylaMemoryEditor(title: "Iets toevoegen", text: "", category: .personal) { _, _ in }
}
