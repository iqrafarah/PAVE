import PAVECore
import SwiftUI

/// Snel delen: one screen to choose what (your profile or one you kept), with whom if you like, and how long; one tap and
/// the QR code and link are there. While it is open you see the moment someone looks, and you can stop it right away.
struct QuickShareSheet: View {
    let model: SharingModel
    let onDone: () -> Void

    @Environment(VaultModel.self) private var vault
    @Environment(ProfileModel.self) private var profile
    @AppStorage("quickShare.profileID") private var chosenID = ""
    @State private var recipient = ""
    @State private var duration = ShareDuration.day
    @State private var includesEmail = false
    @State private var created: ProfileShare?
    @State private var isStopped = false
    @State private var showsPreview = false

    private static let durations: [ShareDuration] = [.day, .week, .month]

    private var name: String { profile.profile.fullName ?? profile.profile.displayName ?? "" }
    private var profiles: [SavedProfile] { model.profiles ?? [] }
    private var chosenProfile: SavedProfile? { profiles.first { $0.id == chosenID } }
    private var shareable: [VaultItem] { vault.items.filter { $0.status != .rejected && $0.archivedAt == nil } }

    private var headline: String? {
        chosenProfile?.headline.nilIfEmpty
            ?? vault.items.filter { $0.category == .diplomas }.max { ($0.period ?? "") < ($1.period ?? "") }.map { "Student \($0.title)" }
    }

    /// Your whole profile goes briefly; a kept profile as you made it.
    private var draft: ShareDraft {
        let ids = chosenProfile.map { kept in vault.items.map(\.id).filter(kept.itemIDs.contains) } ?? shareable.map(\.id)
        let brief = chosenProfile?.brief ?? ids
        let content = ShareContent(
            profile: ShareProfile(name: name, headline: headline, email: includesEmail ? profile.profile.email : nil),
            brief: brief.isEmpty ? nil : brief
        )
        let who = recipient.trimmingCharacters(in: .whitespaces)
        return ShareDraft(
            title: SharingMessages.quickShareTitle(chosenProfile?.name ?? SharingMessages.quickShareWhole),
            recipientName: who.isEmpty ? SharingMessages.quickShareRecipient : who,
            template: chosenProfile?.template ?? .employer,
            itemIDs: ids, content: content, duration: duration
        )
    }

    /// What the recipient will see, before anything is shared.
    private var preview: ProfileShare {
        let draft = draft
        return ProfileShare(
            id: "preview", code: "", title: draft.title, recipientName: draft.recipientName, template: draft.template,
            itemIDs: draft.itemIDs, content: draft.content, expiresAt: draft.duration.end(from: .now)
        )
    }

    /// The share as it is now, with its looks, while the sheet polls.
    private var live: ProfileShare? { created.flatMap { model.share($0.id) } ?? created }

    var body: some View {
        NavigationStack {
            Group {
                if let live { shown(live) } else { choosing }
            }
            .background(Color.canvas)
            .navigationTitle(SharingMessages.quickShare)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(created == nil ? SharingMessages.cancel : ApplyMessages.done, action: onDone)
                }
            }
            .sheet(isPresented: $showsPreview) { ShareRecipientPreview(share: preview, items: vault.items) }
        }
        .onAppear { model.problem = nil }
        .onDisappear { model.problem = nil }
    }

    // MARK: Choosing

    private var choosing: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(SharingMessages.quickShareIntro)
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                SharePanel(title: SharingMessages.quickShareWhat) {
                    option(title: SharingMessages.quickShareWhole, detail: SharingMessages.quickShareWholeDetail(shareable.count), icon: .iconUserSolid, id: "")
                    ForEach(profiles) { kept in
                        ShareRowDivider(inset: 60)
                        option(title: kept.name, detail: SharingMessages.profileSummary(kept), icon: ShareTemplateIcon.image(kept.template), id: kept.id)
                    }
                }
                SharePanel(title: SharingMessages.quickShareWho) {
                    TextField("", text: $recipient, prompt: Text(SharingMessages.quickShareWhoPrompt).foregroundStyle(Color.inkMuted))
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                        .textContentType(.name)
                        .padding(14)
                    ShareRowDivider(inset: 14)
                    Toggle(SharingMessages.email, isOn: $includesEmail)
                        .tint(.paveAccentFill)
                        .textStyle(.bodyMedium)
                        .padding(14)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(SharingMessages.quickShareHowLong)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.leading, 8)
                    HStack(spacing: 8) {
                        ForEach(Self.durations, id: \.self) { option in
                            durationChip(option)
                        }
                    }
                }
                Button(SharingMessages.quickShareSeesLink) { showsPreview = true }
                    .textStyle(.link)
                    .foregroundStyle(Color.paveAccent)
                    .frame(minHeight: 44)
                    .buttonStyle(.pave)
                    .disabled(draft.problem != nil)
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                ShareBottomNote(error: model.problem, reason: draft.problem == nil ? nil : SharingMessages.quickShareEmpty)
                PavePrimaryButton(title: SharingMessages.quickShareMake, loadingTitle: SharingMessages.sharing, isLoading: model.isCreating) { make() }
                    .disabled(draft.problem != nil || model.isCreating)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .background(Color.canvas)
        }
        .task {
            if vault.state != .ready { await vault.load() }
            // A profile that was deleted since falls back to your whole profile.
            if !chosenID.isEmpty, chosenProfile == nil, model.profiles != nil { chosenID = "" }
        }
    }

    private func option(title: String, detail: String, icon: ImageResource, id: String) -> some View {
        let isOn = chosenID == id
        return Button {
            PaveHaptics.selection()
            chosenID = id
        } label: {
            HStack(spacing: 14) {
                ShareRowIcon(icon: icon, isMuted: !isOn)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).textStyle(.bodyMedium).foregroundStyle(Color.ink)
                    Text(detail).textStyle(.caption).foregroundStyle(Color.inkMuted)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                PaveCheckbox(isOn: isOn, size: 20)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func durationChip(_ option: ShareDuration) -> some View {
        let isOn = duration == option
        return Button(SharingMessages.duration(option)) {
            PaveHaptics.selection()
            duration = option
        }
        .textStyle(.chip)
        .foregroundStyle(isOn ? Color.white : Color.ink)
        .padding(.horizontal, 16)
        .frame(minHeight: 40)
        .background(isOn ? Color.paveAccentFill : Color.panel, in: .capsule)
        .overlay { Capsule().strokeBorder(isOn ? Color.clear : Color.cardBorder) }
        .frame(minHeight: 44)
        .contentShape(.capsule)
        .buttonStyle(.pave)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func make() {
        let draft = draft
        model.problem = nil
        Task {
            let authenticator = LocalBiometricAuthenticator()
            if authenticator.kind != nil, !(await authenticator.authenticate(reason: SharingMessages.biometricReason(draft.recipientName))) { return }
            if let share = await model.create(draft, application: nil, photo: nil) {
                withAnimation(.spring(duration: 0.45, bounce: 0.15)) { created = share }
                // Your card goes to the wrist too, to be scanned without taking out the phone.
                if let url = model.link(for: share) {
                    ShareWatchBridge.show(url: url, title: share.recipientName, until: share.expiresAt, name: name, headline: headline)
                }
            }
        }
    }

    // MARK: Shown

    private func shown(_ share: ProfileShare) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                if isStopped {
                    PaveNotice(message: SharingMessages.quickShareStopped)
                } else {
                    ShareCodeCard(model: model, share: share)
                    QuickShareLookStatus(share: share)
                    Text(SharingMessages.quickShareEnds(share.expiresAt))
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .multilineTextAlignment(.center)
                    Button(SharingMessages.quickShareStop, role: .destructive) {
                        Task {
                            await model.revoke(share)
                            ShareWatchBridge.clear()
                            PaveHaptics.success()
                            withAnimation(.easeOut(duration: 0.2)) { isStopped = true }
                        }
                    }
                    .textStyle(.link)
                    .foregroundStyle(Color.critical)
                    .frame(minHeight: 44)
                    .buttonStyle(.pave)
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        // While the code is on screen, a look shows up within seconds.
        .task(id: share.id) {
            while !Task.isCancelled, !isStopped {
                try? await Task.sleep(for: .seconds(4))
                await model.load()
            }
        }
    }
}
