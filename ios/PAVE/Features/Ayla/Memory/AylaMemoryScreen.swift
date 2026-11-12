import PAVECore
import SwiftUI

/// "Wat Ayla over je weet": everything Ayla remembers about you, in a folder per category (the tiles of the vault in
/// Figma). Unlike the memory of ChatGPT, you also decide what goes in. Open a folder to change or forget a note, write
/// one yourself, forget everything, or turn the memory off.
struct AylaMemoryScreen: View {
    /// Shown from the chat in a sheet: then there is a "Klaar" button.
    var onDone: (() -> Void)?

    @Environment(AylaMemoryModel.self) private var memory
    @State private var isAdding = false
    @State private var confirmsForgetAll = false

    var body: some View {
        content
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Wat Ayla over je weet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            // Only the first time: coming back from a folder must not bring back a note that is still being forgotten.
            .task { if memory.state != .ready { await memory.load() } }
            .sheet(isPresented: $isAdding) {
                AylaMemoryEditor(title: "Iets toevoegen", text: "", categories: [.personal]) { text, categories in
                    memory.add(text, categories: categories)
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
                    .tint(.paveAccent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            list
        }
    }

    /// The switch, the folders (all categories, so you can also add to an empty one) and "Alles vergeten".
    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Toggle(isOn: enabledBinding) {
                    Text("Ayla mag dingen onthouden")
                        .textStyle(.listTitle)
                        .foregroundStyle(Color.ink)
                }
                .tint(.paveAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white, in: .rect(cornerRadius: 16))
                Text(memory.memories.isEnabled
                    ? "Ayla stelt voor wat ze onthoudt en jij beslist. Ze gebruikt het in je gesprekken op je iPhone, het web en je Apple Watch."
                    : "Ayla gebruikt niets uit deze mappen en stelt niets voor. Wat erin staat, blijft bewaard tot je het wist.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if memory.notes.isEmpty {
                    Text("Ayla onthoudt nog niets over je. Vertel je in een gesprek iets wat later handig is, zoals je opleiding of een doel, dan vraagt ze of ze het mag onthouden. Je kunt ook zelf iets toevoegen.")
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(AylaMemory.Category.allCases, id: \.self) { category in
                        NavigationLink {
                            AylaMemoryFolderScreen(category: category)
                        } label: {
                            AylaMemoryFolder(category: category, count: memory.notes.count { $0.isIn(category) })
                        }
                        .buttonStyle(.pave)
                    }
                }
                .padding(.top, 24)

                if !memory.notes.isEmpty {
                    Button {
                        confirmsForgetAll = true
                    } label: {
                        Text("Alles vergeten")
                            .textStyle(.listTitle)
                            .foregroundStyle(Color.criticalInk)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.white, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.pave)
                    .padding(.top, 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await memory.load() }
        .animation(.snappy, value: memory.notes)
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
                    isAdding = true
                } label: {
                    Image(.iconPlus)
                        .renderingMode(.template)
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
