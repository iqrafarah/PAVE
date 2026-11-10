import PAVECore
import SwiftUI

/// One folder of "Wat Ayla over je weet": what Ayla remembers in that category. Tap or swipe a note to change or
/// forget it; + adds one straight into this folder.
struct AylaMemoryFolderScreen: View {
    let category: AylaMemory.Category

    @Environment(AylaMemoryModel.self) private var memory
    @State private var editing: AylaMemory?
    @State private var isAdding = false

    private var notes: [AylaMemory] {
        memory.notes.filter { $0.category == category }
    }

    var body: some View {
        Group {
            if notes.isEmpty {
                PaveEmptyState(
                    icon: .iconFolder,
                    title: "Nog leeg",
                    message: "Vertel je Ayla iets over \(category.title.lowercased()), dan vraagt ze of ze het hier mag bewaren. Je kunt ook zelf iets toevoegen."
                )
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 12) {
            if memory.pendingForget != nil {
                AylaUndoBar(message: "Vergeten") {
                    PaveHaptics.tap(.light)
                    memory.undoForget()
                }
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: memory.pendingForget)
        .onDisappear { memory.commitPendingForget() }
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAdding = true
                } label: {
                    Image(.iconPlus)
                        .renderingMode(.template)
                }
                .accessibilityLabel("Iets toevoegen aan \(category.title)")
            }
        }
        .sheet(isPresented: $isAdding) {
            AylaMemoryEditor(title: "Iets toevoegen", text: "", category: category) { text, category in
                memory.add(text, category: category)
            }
        }
        .sheet(item: $editing) { note in
            AylaMemoryEditor(title: "Aanpassen", text: note.text, category: note.category) { text, category in
                memory.update(note, to: text, category: category)
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(notes) { note in
                    row(note)
                }
            } footer: {
                if !memory.memories.isEnabled {
                    Text("Het geheugen staat uit: Ayla gebruikt dit nu niet.")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .animation(.snappy, value: notes)
    }

    private func row(_ note: AylaMemory) -> some View {
        Button {
            editing = note
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.text)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(memory.memories.isEnabled ? Color.ink : .inkMuted)
                    .multilineTextAlignment(.leading)
                Text("\(note.source == .ayla ? "Voorgesteld door Ayla" : "Zelf toegevoegd") · \(note.createdAt.formatted(.dateTime.day().month(.abbreviated)))")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.white)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                PaveHaptics.tap(.medium)
                memory.forget(note)
            } label: {
                Label("Vergeten", image: .iconTrash)
            }
            .tint(.red)
            Button {
                editing = note
            } label: {
                Label("Aanpassen", image: .iconPencil)
            }
            .tint(.brandGreen)
        }
        .contextMenu {
            Button { editing = note } label: { Label("Aanpassen", image: .iconPencil) }
            Button(role: .destructive) { memory.forget(note) } label: { Label("Vergeten", image: .iconTrash) }
        }
        .accessibilityActions {
            Button("Aanpassen") { editing = note }
            Button("Vergeten") { memory.forget(note) }
        }
    }
}

#Preview {
    NavigationStack {
        AylaMemoryFolderScreen(category: .education)
    }
    .environment(AylaMemoryModel(service: nil))
}
