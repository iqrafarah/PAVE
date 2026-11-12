import PAVECore
import SwiftUI

/// "Wat Ayla over je weet" on the wrist: only to read, per category. Changing or forgetting a note happens on the
/// iPhone, and nothing here is read out loud.
struct WatchMemoryView: View {
    @Bindable var model: WatchAylaModel

    @State private var memories: AylaMemories?
    @State private var problem: String?

    var body: some View {
        List {
            if let problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let memories {
                if !memories.isEnabled {
                    Text("Ayla onthoudt nu niets. Je kunt dit aanzetten op je iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if memories.notes.isEmpty {
                    Text("Ayla onthoudt nog niets over je. Vertel het haar, dan vraagt ze of ze het mag onthouden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(memories.byCategory, id: \.category) { group in
                        Section(group.category.title) {
                            ForEach(group.notes) { note in
                                Text(note.text)
                                    .font(.footnote)
                            }
                        }
                    }
                    Text("Aanpassen of wissen doe je op je iPhone.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Wat Ayla weet")
        .task {
            do {
                memories = try await model.memories()
            } catch AylaError.notSetUp {
                problem = "Wat Ayla over je weet is nog niet beschikbaar."
            } catch {
                problem = WatchMessages.message(for: AylaError(error))
            }
        }
    }
}
