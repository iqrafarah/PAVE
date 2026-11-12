import PAVECore
import SwiftUI

/// When it was: a start and an end (or "Ik doe dit nog") for experience, one date for a diploma or certificate.
struct VaultPeriodSheet: View {
    @Binding var draft: VaultItemDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if draft.category.hasPeriod {
                    DatePicker("Begonnen", selection: day(\.startDate), in: ...Date.now, displayedComponents: .date)
                    Toggle("Ik doe dit nog", isOn: $draft.isCurrent.animation())
                        .tint(.brandGreen)
                    if !draft.isCurrent {
                        DatePicker("Gestopt", selection: day(\.endDate, after: draft.startDate), in: (draft.startDate?.date() ?? .distantPast)..., displayedComponents: .date)
                    }
                } else {
                    DatePicker("Behaald op", selection: day(\.issuedOn), in: ...Date.now, displayedComponents: .date)
                }
            }
            .environment(\.locale, Locale(identifier: "nl_NL"))
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .navigationTitle("Periode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: fillIn)
        }
        .tint(.brandGreen)
        .presentationDetents([.medium, .large])
    }

    /// Opening the sheet already counts as choosing: the dates start at today, so Klaar is never empty.
    private func fillIn() {
        if draft.category.hasPeriod {
            if draft.startDate == nil { draft.startDate = VaultDay(.now) }
        } else if draft.issuedOn == nil {
            draft.issuedOn = VaultDay(.now)
        }
    }

    private func day(_ keyPath: WritableKeyPath<VaultItemDraft, VaultDay?>, after start: VaultDay? = nil) -> Binding<Date> {
        Binding(
            get: { draft[keyPath: keyPath]?.date() ?? start?.date() ?? .now },
            set: { draft[keyPath: keyPath] = VaultDay($0) }
        )
    }
}

#Preview {
    @Previewable @State var draft = VaultItemDraft(category: .internships)
    Color.canvas.sheet(isPresented: .constant(true)) { VaultPeriodSheet(draft: $draft) }
}
