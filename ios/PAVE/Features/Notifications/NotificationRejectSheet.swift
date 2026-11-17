import SwiftUI

/// Rejecting a verification request: the reviewer always writes why, so the learner knows what to fix.
struct NotificationRejectSheet: View {
    static let maxLength = 2000

    let documentName: String
    let onReject: (String) async -> String?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var reason = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var cleanedReason: String { reason.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canReject: Bool { !cleanedReason.isEmpty && !isWorking }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bijvoorbeeld: De datum op het certificaat klopt niet met je stageperiode.", text: $reason, axis: .vertical)
                        .textStyle(.bodyMedium)
                        .lineLimit(4...10)
                        .focused($isFocused)
                        .onChange(of: reason) { _, new in
                            if new.count > Self.maxLength { reason = String(new.prefix(Self.maxLength)) }
                        }
                } header: {
                    Text("Waarom wijs je \(documentName) af?")
                        .textStyle(.caption)
                } footer: {
                    Text("De lerende ziet deze reden bij het bewijs in de kluis en kan daarna opnieuw een aanvraag doen.")
                        .textStyle(.caption)
                }
                if let errorMessage {
                    Section {
                        PaveInlineError(message: errorMessage)
                    }
                }
            }
            .tint(.brandGreen)
            .scrollContentBackground(.hidden)
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Aanvraag afwijzen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                        .disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isWorking ? "Bezig…" : "Afwijzen", role: .destructive) {
                        Task { await reject() }
                    }
                    .disabled(!canReject)
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isWorking || !cleanedReason.isEmpty)
    }

    private func reject() async {
        guard canReject else { return }
        isWorking = true
        errorMessage = nil
        let error = await onReject(cleanedReason)
        isWorking = false
        if let error {
            errorMessage = error
            PaveHaptics.error()
        } else {
            PaveHaptics.success()
            dismiss()
        }
    }
}

#Preview {
    Color.canvas.sheet(isPresented: .constant(true)) {
        NotificationRejectSheet(documentName: "Toets Nederlands") { _ in nil }
    }
}
