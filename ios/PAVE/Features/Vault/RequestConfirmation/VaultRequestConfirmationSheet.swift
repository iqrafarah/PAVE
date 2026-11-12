import PAVECore
import SwiftUI

/// "Bevestiging aanvragen": choose who confirms the evidence and how to reach them, and see what they would get to see.
/// Sends the request to the organisation's explicitly assigned reviewers.
struct VaultRequestConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: VaultItem
    let documentCount: Int
    var onSend: ((VaultConfirmationRequest) async -> Bool)?

    @State private var request: VaultConfirmationRequest
    @State private var showsMissing = false
    @State private var isFinished = false
    @State private var isSending = false
    @State private var sendError: String?
    @State private var confirmsDiscard = false
    @FocusState private var focus: VaultConfirmationRequest.Field?

    init(item: VaultItem, documentCount: Int, onSend: ((VaultConfirmationRequest) async -> Bool)? = nil) {
        self.item = item
        self.documentCount = documentCount
        self.onSend = onSend
        _request = State(initialValue: VaultConfirmationRequest(item: item))
    }

    private var hasChanges: Bool { !isFinished && request != VaultConfirmationRequest(item: item) }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isFinished {
                notSent
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
            } else {
                form
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.snappy(duration: 0.35), value: isFinished)
        .background(Color.white.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheetDismissGuard(isBlocked: hasChanges) { confirmsDiscard = true }
        .confirmationDialog(VaultMessages.discardRequestTitle, isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Weggooien", role: .destructive) { dismiss() }
            Button("Verder met invullen", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Bevestiging aanvragen")
                .textStyle(.listTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text(VaultMessages.requestPreviewLabel)
                .textStyle(.meta)
                .foregroundStyle(Color.statusPending)
                .padding(.horizontal, 8)
                .frame(minHeight: 24)
                .background(Color.statusPending.opacity(0.12), in: .capsule)
                .accessibilityLabel(VaultMessages.requestPreviewAccessibility)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    private var form: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if onSend == nil { PaveNotice(message: VaultMessages.requestNotActive) }
                    if let sendError { PaveNotice(message: sendError) }

                    block(VaultMessages.requestWhoTitle) {
                        VStack(spacing: 10) {
                            ForEach(VaultConfirmationRequest.Recipient.allCases) { recipient in
                                VaultRecipientCard(recipient: recipient, isSelected: request.recipient == recipient) {
                                    request.recipient = recipient
                                }
                            }
                        }
                    }

                    VaultFormField(title: request.recipient.organisationLabel, error: error(.organisation)) {
                        TextField("", text: $request.organisation, prompt: prompt(VaultMessages.requestOrganisationPrompt))
                            .textStyle(.input)
                            .foregroundStyle(Color.ink)
                            .textContentType(.organizationName)
                            .focused($focus, equals: .organisation)
                            .submitLabel(.next)
                            .onSubmit { focus = .email }
                    }

                    VaultFormField(title: VaultMessages.requestEmailTitle, error: error(.email)) {
                        TextField("", text: $request.email, prompt: prompt("naam@organisatie.nl"))
                            .textStyle(.input)
                            .foregroundStyle(Color.ink)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focus, equals: .email)
                            .submitLabel(.done)
                            .onSubmit { focus = nil }
                    }

                    VaultFormField(title: VaultMessages.requestMessageTitle, isRequired: false, minHeight: 96) {
                        TextField("", text: $request.message, prompt: prompt(VaultMessages.requestMessagePrompt), axis: .vertical)
                            .lineLimit(3...6)
                            .textStyle(.input)
                            .foregroundStyle(Color.ink)
                            .padding(.vertical, 12)
                            .frame(maxHeight: .infinity, alignment: .top)
                    }

                    block(VaultMessages.requestSharedTitle) {
                        VaultSharedPreview(item: item, documentCount: documentCount)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)

            PavePrimaryButton(title: isSending ? "Versturen…" : VaultMessages.requestSend) { send() }
                .disabled(isSending)
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .frame(maxWidth: 560)
        }
    }

    private var notSent: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Image(.iconClockSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .foregroundStyle(Color.statusPending)
                .frame(width: 72, height: 72)
                .background(Color.statusPending.opacity(0.12), in: .circle)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(onSend == nil ? VaultMessages.requestNotSentTitle : "Verzoek verstuurd")
                    .textStyle(.emptyTitle)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(onSend == nil ? VaultMessages.requestNotSentMessage(request.organisation) : "\(request.organisation) ontvangt het verzoek. Je krijgt een melding zodra het bewijs is geverifieerd.")
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 380)
            Spacer(minLength: 0)
            PavePrimaryButton(title: "Sluiten") { dismiss() }
                .frame(maxWidth: 560)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func send() {
        focus = nil
        showsMissing = true
        guard request.missingFields.isEmpty else {
            focus = request.missingFields.first
            PaveHaptics.error()
            return
        }
        guard let onSend else {
            PaveHaptics.selection()
            isFinished = true
            return
        }
        isSending = true
        sendError = nil
        Task {
            let sent = await onSend(request)
            isSending = false
            if sent { isFinished = true }
            else { sendError = "Er ging iets mis. Controleer de organisatienaam en probeer het opnieuw." }
        }
    }

    private func block(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .textStyle(.label)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func prompt(_ text: String) -> Text {
        Text(text).foregroundStyle(Color.inkMuted)
    }

    private func error(_ field: VaultConfirmationRequest.Field) -> String? {
        guard showsMissing, request.missingFields.contains(field) else { return nil }
        return VaultMessages.requestMissing(field)
    }
}

#Preview {
    Color.canvas.sheet(isPresented: .constant(true)) {
        VaultRequestConfirmationSheet(item: VaultContents.preview.items[0], documentCount: 2)
    }
}
