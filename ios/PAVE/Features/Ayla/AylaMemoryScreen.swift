import PAVECore
import SwiftUI

/// "Wat Ayla over je weet": everything Ayla remembers about you, as in the memory settings of ChatGPT, but you also
/// decide what goes in. Change or delete a note, write one yourself, forget everything, or turn the memory off.
struct AylaMemoryScreen: View {
    /// Shown from the chat in a sheet: then there is a "Klaar" button.
    var onDone: (() -> Void)?

    @Environment(AylaMemoryModel.self) private var memory
    @State private var editing: AylaMemory?
    @State private var isAdding = false
    @State private var draft = ""
    @State private var confirmsForgetAll = false

    var body: some View {
        content
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Wat Ayla over je weet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { await memory.load() }
            .alert("Iets toevoegen", isPresented: $isAdding) {
                TextField("Bijvoorbeeld: Ik wil werken in de zorg-ICT", text: $draft)
                Button("Annuleren", role: .cancel) {}
                Button("Bewaren") {
                    PaveHaptics.success()
                    memory.add(draft)
                }
            } message: {
                Text("Ayla gebruikt dit in je gesprekken.")
            }
            .alert("Aanpassen", isPresented: isEditing, presenting: editing) { note in
                TextField("Wat Ayla onthoudt", text: $draft)
                Button("Annuleren", role: .cancel) {}
                Button("Bewaren") {
                    PaveHaptics.success()
                    memory.update(note, to: draft)
                }
            }
            .alert("Wat Ayla over je weet", isPresented: problemBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(memory.problem ?? "")
            }
            .confirmationDialog("Alles vergeten?", isPresented: $confirmsForgetAll, titleVisibility: .visible) {
                Button("Alles vergeten", role: .destructive) {
                    PaveHaptics.tap(.heavy)
                    memory.forgetAll()
                }
            } message: {
                Text("Ayla vergeet alles wat hier staat, ook op het web. Dit kun je niet ongedaan maken.")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch memory.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .notSetUp:
            centered(title: "Nog niet beschikbaar", message: AylaMessages.memoryNotSetUp)
        case .unavailable:
            centered(title: "Geen Ayla", message: AylaMessages.notAvailableInDemo)
        case .failed(let message):
            VStack(spacing: 16) {
                centered(title: "Niet geladen", message: message)
                    .frame(maxHeight: nil)
                Button("Opnieuw proberen") { Task { await memory.load() } }
                    .textStyle(.label)
                    .tint(.brandGreen)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            list
        }
    }

    private var list: some View {
        List {
            Section {
                Toggle(isOn: enabledBinding) {
                    Text("Ayla mag dingen onthouden")
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                }
                .tint(.brandGreen)
                .listRowBackground(Color.white)
            } footer: {
                Text(memory.memories.isEnabled
                    ? "Ayla stelt voor wat ze onthoudt en jij beslist. Ze gebruikt het in je gesprekken op je iPhone, het web en je Apple Watch."
                    : "Ayla gebruikt niets van hieronder en stelt niets voor. Wat er staat, blijft bewaard tot je het wist.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
            }

            Section {
                if memory.notes.isEmpty {
                    Text("Ayla onthoudt nog niets over je. Vertel je in een gesprek iets wat later handig is, zoals je opleiding of een doel, dan vraagt ze of ze het mag onthouden. Je kunt ook zelf iets toevoegen.")
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.vertical, 6)
                        .listRowBackground(Color.white)
                } else {
                    ForEach(memory.notes) { note in
                        row(note)
                    }
                }
            } header: {
                Text(memory.notes.isEmpty ? "Onthouden" : "Onthouden (\(memory.notes.count))")
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
            }

            if !memory.notes.isEmpty {
                Section {
                    Button(role: .destructive) {
                        confirmsForgetAll = true
                    } label: {
                        Text("Alles vergeten")
                            .textStyle(.listTitle)
                            .foregroundStyle(Color.criticalInk)
                    }
                    .listRowBackground(Color.white)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await memory.load() }
        .animation(.snappy, value: memory.notes)
    }

    private func row(_ note: AylaMemory) -> some View {
        Button {
            edit(note)
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
                Label("Vergeten", systemImage: "trash.fill")
            }
            .tint(.red)
            Button {
                edit(note)
            } label: {
                Label("Aanpassen", systemImage: "pencil")
            }
            .tint(.brandGreen)
        }
        .contextMenu {
            Button { edit(note) } label: { Label("Aanpassen", systemImage: "pencil") }
            Button(role: .destructive) { memory.forget(note) } label: { Label("Vergeten", systemImage: "trash.fill") }
        }
        .accessibilityActions {
            Button("Aanpassen") { edit(note) }
            Button("Vergeten") { memory.forget(note) }
        }
    }

    private func centered(title: String, message: String) -> some View {
        PaveEmptyState(icon: .iconDatabase, title: title, message: message)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if memory.state == .ready {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    draft = ""
                    isAdding = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Iets toevoegen")
            }
        }
        if let onDone {
            ToolbarItem(placement: .cancellationAction) {
                Button("Klaar", action: onDone)
            }
        }
    }

    private func edit(_ note: AylaMemory) {
        draft = note.text
        editing = note
    }

    private var isEditing: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { memory.memories.isEnabled }, set: { isOn in
            PaveHaptics.selection()
            memory.setEnabled(isOn)
        })
    }

    private var problemBinding: Binding<Bool> {
        Binding(get: { memory.problem != nil }, set: { if !$0 { memory.problem = nil } })
    }
}

#Preview {
    NavigationStack {
        AylaMemoryScreen()
    }
    .environment(AylaMemoryModel(service: nil))
}
