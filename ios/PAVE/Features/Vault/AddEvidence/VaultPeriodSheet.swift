import PAVECore
import SwiftUI

/// When it was: a period from a start to an end (or "Ik doe dit nog"), or one date. Experience starts as a period and a
/// diploma, certificate or badge as one date, but either can be the other.
struct VaultPeriodSheet: View {
    @Binding var draft: VaultItemDraft
    @Environment(\.dismiss) private var dismiss
    /// Beside the status column of the iPhone Duo a half-high sheet would run under it, so it opens full height there.
    @State private var hasSideColumn = false

    private var isPeriod: Binding<Bool> {
        Binding(
            get: { draft.isPeriod },
            set: { newValue in
                withAnimation(.snappy(duration: 0.3)) {
                    draft.usesPeriod = newValue
                    fillIn()
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Soort", selection: isPeriod) {
                        Text("Periode").tag(true)
                        Text("Eén datum").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if draft.isPeriod {
                    Section {
                        DatePicker("Van", selection: start, in: ...Date.now, displayedComponents: .date)
                        Toggle("Ik doe dit nog", isOn: $draft.isCurrent.animation(.snappy(duration: 0.3)))
                            .tint(.paveAccent)
                        if !draft.isCurrent {
                            DatePicker("Tot", selection: end, in: (draft.startDate?.date() ?? .distantPast)..., displayedComponents: .date)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    } footer: {
                        summary
                    }
                } else {
                    Section {
                        DatePicker(draft.category.hasPeriod ? "Datum" : "Behaald op", selection: issued, in: ...Date.now, displayedComponents: .date)
                    } footer: {
                        summary
                    }
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
        .tint(.paveAccent)
        .onGeometryChange(for: Bool.self) { $0.safeAreaInsets.trailing > 0 || $0.safeAreaInsets.leading > 0 } action: { hasSideColumn = $0 }
        .presentationDetents(hasSideColumn ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// What will be on the card, so you see the result while choosing.
    private var summary: some View {
        Text(draft.period.map { "Op je kaart: \($0)" } ?? "")
            .textStyle(.caption)
            .foregroundStyle(Color.inkMuted)
            .contentTransition(.numericText())
            .animation(.snappy, value: draft.period)
    }

    /// Opening counts as choosing: both ends start at today, so Klaar is never empty and the end is never missing.
    private func fillIn() {
        if draft.isPeriod {
            if draft.startDate == nil { draft.startDate = VaultDay(.now) }
            if draft.endDate == nil, !draft.isCurrent { draft.endDate = draft.startDate }
        } else if draft.issuedOn == nil {
            draft.issuedOn = VaultDay(.now)
        }
    }

    private var start: Binding<Date> {
        Binding(
            get: { draft.startDate?.date() ?? .now },
            set: { date in
                let day = VaultDay(date)
                draft.startDate = day
                // The end moves along so the period never runs backwards.
                if let end = draft.endDate, end < day { draft.endDate = day }
            }
        )
    }

    private var end: Binding<Date> {
        Binding(
            get: { draft.endDate?.date() ?? draft.startDate?.date() ?? .now },
            set: { draft.endDate = VaultDay($0) }
        )
    }

    private var issued: Binding<Date> {
        Binding(
            get: { draft.issuedOn?.date() ?? .now },
            set: { draft.issuedOn = VaultDay($0) }
        )
    }
}

#Preview {
    @Previewable @State var draft = VaultItemDraft(category: .internships)
    Color.canvas.sheet(isPresented: .constant(true)) { VaultPeriodSheet(draft: $draft) }
}
