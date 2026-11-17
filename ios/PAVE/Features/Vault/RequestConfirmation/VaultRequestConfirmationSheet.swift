import PAVECore
import SwiftUI

/// "Bevestiging aanvragen": choose who confirms the evidence and how to reach them, and see what they would get to see.
/// Sends the request to the organisation's explicitly assigned reviewers.
struct VaultRequestConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(VaultModel.self) private var vault
    let item: VaultItem
    let documentCount: Int
    var onSend: ((VaultConfirmationRequest) async -> String?)?

    @State private var request: VaultConfirmationRequest
    @State private var showsMissing = false
    @State private var isFinished = false
    @State private var isSending = false
    @State private var sendError: String?
    @State private var confirmsDiscard = false
    @State private var evidenceLogo: VaultLogoLook?
    @FocusState private var focus: VaultConfirmationRequest.Field?

    init(item: VaultItem, documentCount: Int, onSend: ((VaultConfirmationRequest) async -> String?)? = nil) {
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
        .task(id: item.id) {
            evidenceLogo = nil
            if let logo = vault.logo(of: item) {
                evidenceLogo = await vault.look(of: logo)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Verificatie aanvraag")
                .textStyle(.calloutTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Laat je gegevens bevestigen.")
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 20)
    }

    private var form: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if onSend == nil { PaveNotice(message: VaultMessages.requestNotActive) }
                    if let sendError { PaveNotice(message: sendError) }

                    evidenceSummary

                    VStack(alignment: .leading, spacing: 18) {
                        VaultFormField(title: "Naam bedrijf", error: error(.organisation)) {
                            TextField("", text: $request.organisation, prompt: prompt(VaultMessages.requestOrganisationPrompt))
                                .textStyle(.input)
                                .foregroundStyle(Color.ink)
                                .textContentType(.organizationName)
                                .focused($focus, equals: .organisation)
                                .submitLabel(.next)
                                .onSubmit { focus = .email }
                        }

                        if let location = item.organisationLocation, !location.isEmpty {
                            VaultFormField(title: "Locatie van het bedrijf", isRequired: false) {
                                Text(location)
                                    .textStyle(.input)
                                    .foregroundStyle(Color.inkMuted)
                            }
                        }

                        VaultFormField(title: "Betreffende persoon", error: error(.email)) {
                            TextField("", text: $request.email, prompt: prompt("naam@bedrijf.nl"))
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
                    }
                    .padding(18)
                    .background(Color.white, in: .rect(cornerRadius: 16))
                    .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.cardBorder) }

                    Text("De ingestelde beoordelaars ontvangen de aanvraag. Het ingevulde e-mailadres wordt nog niet gemaild.")
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    DisclosureGroup("Dit ziet de beoordelaar") {
                        VaultSharedPreview(item: item, documentCount: documentCount)
                            .padding(.top, 10)
                    }
                    .textStyle(.label)
                    .foregroundStyle(Color.ink)
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

    private var evidenceSummary: some View {
        HStack(spacing: 12) {
            VaultLogoAvatar(look: evidenceLogo, name: item.organisationName ?? item.title, size: 56)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                if let organisation = item.organisationName, !organisation.isEmpty {
                    let location = item.organisationLocation.map { ", \($0)" } ?? ""
                    PaveIconLabel(icon: .iconBuildingOfficeSolid, text: organisation + location)
                }
                if let period = item.period {
                    PaveIconLabel(icon: .iconCalendarDaysSolid, text: period)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.cardBorder) }
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
                Text(onSend == nil ? VaultMessages.requestNotSentMessage(request.organisation) : "De ingestelde beoordelaars van \(request.organisation) ontvangen het verzoek. Je krijgt een melding zodra het bewijs is geverifieerd.")
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
            let sendError = await onSend(request)
            isSending = false
            if let sendError { self.sendError = sendError }
            else { isFinished = true }
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
            .environment(VaultModel(previewContents: VaultContents.preview))
    }
}
