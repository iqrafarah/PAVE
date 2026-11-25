import PAVECore
import SwiftUI

/// Applying at the fair without a CV: a short card with who you are, why this job and when you can work, plus a
/// spoken pitch if you like. Ayla can write the "why" from your vault; you check and change it before it is left with
/// the employer, confirmed with Face ID.
struct QuickApplySheet: View {
    let model: SharingModel
    let employer: FairEmployer
    let vacancy: Vacancy
    let onDone: () -> Void

    @Environment(VaultModel.self) private var vault
    @Environment(ProfileModel.self) private var profile
    @Environment(AylaChatModel.self) private var chat
    @AppStorage("fair.availability") private var storedAvailability = ""
    @State private var card = FairApplicationCard(name: "")
    @State private var isWriting = false
    @State private var isSending = false
    @State private var sent: FairApplication?
    @State private var dictation = SpeechDictation()
    @State private var didStart = false

    var body: some View {
        NavigationStack {
            Group {
                if let sent {
                    QuickApplySent(employer: employer, application: sent, onDone: onDone)
                } else {
                    form
                }
            }
            .background(Color.canvas)
            .navigationTitle(sent == nil ? SharingMessages.quickApply : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if sent == nil {
                    ToolbarItem(placement: .cancellationAction) { Button(SharingMessages.cancel, action: onDone) }
                }
            }
        }
        .task { start() }
        .onDisappear { dictation.stop() }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vacancy.title).textStyle(.calloutTitle).foregroundStyle(Color.ink)
                    Text([employer.name, employer.stand].compactMap { $0 }.joined(separator: " · ")).textStyle(.caption).foregroundStyle(Color.inkMuted)
                }
                SharePanel(title: SharingMessages.aboutYou) {
                    labelled(SharingMessages.name) {
                        TextField(SharingMessages.name, text: $card.name).textStyle(.bodyMedium).foregroundStyle(Color.ink)
                    }
                    ShareRowDivider(inset: 14)
                    labelled(SharingMessages.quickApplyHeadline) {
                        TextField(SharingMessages.quickApplyHeadline, text: $card.headline, prompt: Text(SharingMessages.quickApplyHeadlinePrompt).foregroundStyle(Color.inkMuted))
                            .textStyle(.bodyMedium).foregroundStyle(Color.ink)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(SharingMessages.quickApplyWhy).textStyle(.bodyMedium).foregroundStyle(Color.inkMuted)
                        Spacer()
                        if chat.isAvailable {
                            Button { Task { await writeWhy() } } label: {
                                HStack(spacing: 6) {
                                    if isWriting { ProgressView().controlSize(.small) } else { AylaLetter(color: Color.paveAccent).frame(width: 13, height: 13) }
                                    Text(isWriting ? SharingMessages.quickApplyWriting : SharingMessages.quickApplyAylaWrites).textStyle(.chip)
                                }
                                .foregroundStyle(Color.paveAccent)
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.pave)
                            .disabled(isWriting)
                        }
                    }
                    .padding(.leading, 8)
                    TextField(SharingMessages.quickApplyWhy, text: $card.why, prompt: Text(SharingMessages.quickApplyWhyPrompt).foregroundStyle(Color.inkMuted), axis: .vertical)
                        .lineLimit(3...6)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                        .padding(14)
                        .background(Color.panel, in: .rect(cornerRadius: 14))
                }
                QuickApplyAvailability(availability: $card.availability)
                VStack(alignment: .leading, spacing: 8) {
                    Text(SharingMessages.quickApplyPitch).textStyle(.bodyMedium).foregroundStyle(Color.inkMuted).padding(.leading, 8)
                    VStack(alignment: .leading, spacing: 10) {
                        Button { Task { await togglePitch() } } label: {
                            HStack(spacing: 8) {
                                Image(dictation.isListening ? .iconPauseSolid : .iconChatBubbleLeftEllipsisSolid)
                                    .renderingMode(.template).resizable().scaledToFit().paveIconFrame(16)
                                    .accessibilityHidden(true)
                                Text(dictation.isListening ? SharingMessages.quickApplyPitchStop : SharingMessages.quickApplyPitchStart).textStyle(.chip)
                            }
                            .foregroundStyle(dictation.isListening ? Color.white : Color.paveAccent)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(dictation.isListening ? Color.paveAccentFill : Color.paveSurfaceTint, in: .capsule)
                        }
                        .buttonStyle(.pave)
                        if !card.pitch.isEmpty {
                            TextField(SharingMessages.quickApplyPitch, text: $card.pitch, axis: .vertical)
                                .lineLimit(2...6).textStyle(.bodyMedium).foregroundStyle(Color.ink)
                        }
                        Text(SharingMessages.quickApplyPitchHint).textStyle(.caption).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.panel, in: .rect(cornerRadius: 14))
                }
                Text(SharingMessages.quickApplyHonest(employer.name)).textStyle(.caption).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            PavePrimaryButton(title: SharingMessages.quickApplySend(employer.name), loadingTitle: SharingMessages.sharing, isLoading: isSending) { send() }
                .disabled(card.problem != nil || isSending)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.canvas)
        }
    }

    private func labelled(_ title: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).textStyle(.caption).foregroundStyle(Color.inkMuted)
            field()
        }
        .padding(14)
    }

    private func start() {
        guard !didStart else { return }
        didStart = true
        card.name = profile.profile.fullName ?? profile.profile.displayName ?? ""
        card.headline = vault.items.filter { $0.category == .diplomas }.max { ($0.period ?? "") < ($1.period ?? "") }.map { "Student \($0.title)" } ?? ""
        if let data = storedAvailability.data(using: .utf8), let kept = try? JSONDecoder().decode(Availability.self, from: data) { card.availability = kept }
    }

    /// Ayla writes two short sentences on why this job, only from the evidence she may see.
    private func writeWhy() async {
        guard let service = chat.service else { return }
        isWriting = true
        defer { isWriting = false }
        let request = ApplicationWritingRequest(
            kind: .profile, vacancy: vacancy, name: card.name, items: vault.items.filter { $0.aylaAllowedAt != nil },
            focus: SharingMessages.quickApplyFocus
        )
        if let written = try? await service.writeApplication(request).profile, !written.isEmpty { card.why = written }
    }

    private func togglePitch() async {
        if dictation.isListening {
            dictation.stop()
        } else {
            await dictation.start { text in card.pitch = String(text.prefix(1200)) }
        }
    }

    private func send() {
        dictation.stop()
        if let data = try? JSONEncoder().encode(card.availability) { storedAvailability = String(decoding: data, as: UTF8.self) }
        isSending = true
        Task {
            let authenticator = LocalBiometricAuthenticator()
            if authenticator.kind != nil, !(await authenticator.authenticate(reason: SharingMessages.biometricReason(employer.name))) {
                isSending = false
                return
            }
            let kept = await model.apply(card, employer: employer, vacancy: vacancy)
            isSending = false
            if let kept {
                PaveHaptics.success()
                FairDay.record(.applied(employer: employer.name, vacancy: vacancy.title))
                withAnimation(.spring(duration: 0.45, bounce: 0.2)) { sent = kept }
            }
        }
    }
}
