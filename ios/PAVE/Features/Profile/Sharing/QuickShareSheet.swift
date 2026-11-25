import PAVECore
import SwiftUI

/// Delen, the one screen for every share: your profile (Snel delen), a selection you kept, or an application with its CV
/// and letter. Choose what, with whom if you like, and how long; one tap and the QR code and link are there, with the
/// files of verified evidence so the recipient can open them. While it is open you see the moment someone looks, and you
/// can stop it right away. "Meer opties" leads to the steps with purpose and downloading.
struct QuickShareSheet: View {
    /// What the screen starts on.
    enum Start: Equatable {
        case profile
        case selection(String)
        /// A kind of recipient without a selection yet: what that recipient usually needs.
        case kind(ShareTemplate)
        case application(vacancyID: String, documents: Set<ApplicationDocumentKind>)
    }

    let model: SharingModel
    var start: Start = .profile
    var recipientOrganisation: String?
    var onShared: (ProfileShare) -> Void = { _ in }
    var onMoreOptions: (() -> Void)?
    let onDone: () -> Void

    @Environment(VaultModel.self) private var vault
    @Environment(ProfileModel.self) private var profile
    /// The last choice of your profile or a selection, for the next Snel delen.
    @AppStorage("quickShare.profileID") private var lastChoice = ""
    @State private var choice = ""
    @State private var didStart = false
    @State private var includesCV = true
    @State private var includesLetter = true
    @State private var recipient = ""
    @State private var duration = ShareDuration.day
    @State private var includesEmail = false
    @State private var includesPhoto = true
    @State private var created: ProfileShare?
    @State private var isStopped = false
    @State private var showsPreview = false
    @State private var showsAllApplications = false
    /// What you changed by hand under "Pas aan"; nil follows the choice above.
    @State private var customItems: Set<String>?
    @State private var customFiles: Set<String>?
    @State private var adjusts = false

    /// The chosen application first, then the newest; three until you ask for all.
    private var shownApplications: [ApplicationDraft] {
        let sorted = model.applications.sorted { a, b in
            if "app:\(a.vacancy.id)" == choice { return true }
            if "app:\(b.vacancy.id)" == choice { return false }
            return a.updatedAt > b.updatedAt
        }
        return showsAllApplications ? sorted : Array(sorted.prefix(3))
    }

    private static let durations: [ShareDuration] = ShareDuration.allCases

    private var name: String { profile.profile.fullName ?? profile.profile.displayName ?? "" }
    private var profiles: [SavedProfile] { model.profiles ?? [] }
    private var shareable: [VaultItem] { vault.items.filter { $0.status != .rejected && $0.archivedAt == nil } }

    /// A kept selection, or for a kind of recipient the one PAVE would start with.
    private var chosenProfile: SavedProfile? {
        if choice.hasPrefix("sel:") { return profiles.first { "sel:\($0.id)" == choice } }
        if choice.hasPrefix("kind:"), let kind = ShareTemplate(rawValue: String(choice.dropFirst(5))) {
            var starter = SavedProfile.starter(for: kind, items: vault.items)
            starter.name = SharingMessages.template(kind)
            return starter
        }
        return nil
    }

    private var application: ApplicationDraft? { model.applications.first { "app:\($0.vacancy.id)" == choice } }

    private var headline: String? {
        if let application, !application.cv.headline.isEmpty { return application.cv.headline }
        return chosenProfile?.headline.nilIfEmpty
            ?? vault.items.filter { $0.category == .diplomas }.max { ($0.period ?? "") < ($1.period ?? "") }.map { "Student \($0.title)" }
    }

    /// The evidence that goes along: of your profile all of it briefly, of a selection what you put in, of an application
    /// what its CV is built from, so a tick on the CV can be opened.
    private var itemIDs: [String] {
        if let customItems { return vault.items.map(\.id).filter(customItems.contains) }
        if let application {
            let behindCV = Set(application.cv.sections.filter(\.isVisible).flatMap(\.entries).filter(\.isVisible).compactMap(\.sourceItemID))
            return shareable.map(\.id).filter(behindCV.contains)
        }
        if let chosenProfile { return vault.items.map(\.id).filter(chosenProfile.itemIDs.contains) }
        return shareable.map(\.id)
    }

    private var draft: ShareDraft {
        let ids = itemIDs
        let brief = application == nil ? (chosenProfile?.brief ?? ids) : []
        // Verified evidence takes its file along, unless the selection says otherwise.
        let fileIDs = customFiles ?? chosenProfile.map { Set($0.files) } ?? ShareFiles.byDefault(vault.items)
        let files = vault.items.filter { ids.contains($0.id) && fileIDs.contains($0.id) && ShareFiles.hasDocument($0) }.map(\.id)
        let content = ShareContent(
            profile: ShareProfile(
                name: name, headline: headline, email: includesEmail ? profile.profile.email : nil,
                summary: application.map(\.cv.profile)?.nilIfEmpty ?? chosenProfile?.summary.nilIfEmpty,
                showsPhoto: includesPhoto && profile.avatar != nil ? true : nil
            ),
            cv: application != nil && includesCV ? application?.cv : nil,
            letter: application != nil && includesLetter ? application?.letter : nil,
            vacancyID: application?.vacancy.id,
            brief: brief.isEmpty ? nil : brief,
            files: files.isEmpty ? nil : files
        )
        let who = recipient.trimmingCharacters(in: .whitespaces)
        let title = application.map { SharingMessages.applicationShareTitle($0.vacancy) }
            ?? SharingMessages.quickShareTitle(chosenProfile?.name ?? SharingMessages.quickShareWhole)
        return ShareDraft(
            title: title,
            recipientName: who.isEmpty ? (application?.vacancy.company ?? SharingMessages.quickShareRecipient) : who,
            recipientOrganisation: application?.vacancy.company ?? "",
            template: application == nil ? (chosenProfile?.template ?? .employer) : .employer,
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
            .navigationTitle(start == .profile ? SharingMessages.quickShare : SharingMessages.shareProfile)
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
                        option(title: kept.name, detail: SharingMessages.profileSummary(kept), icon: ShareTemplateIcon.image(kept.template), id: "sel:\(kept.id)")
                    }
                    if case .kind(let kind) = start {
                        ShareRowDivider(inset: 60)
                        option(title: SharingMessages.template(kind), detail: SharingMessages.templateHint(kind), icon: ShareTemplateIcon.image(kind), id: "kind:\(kind.rawValue)")
                    }
                }
                if !model.applications.isEmpty {
                    SharePanel(title: SharingMessages.orApplication) {
                        ForEach(Array(shownApplications.enumerated()), id: \.element.id) { index, draft in
                            if index > 0 { ShareRowDivider(inset: 60) }
                            option(title: ApplyMessages.title(draft.vacancy), detail: SharingMessages.applicationOption(draft.vacancy.title), icon: .iconBriefcaseSolid, id: "app:\(draft.vacancy.id)")
                        }
                        if model.applications.count > shownApplications.count {
                            ShareRowDivider(inset: 14)
                            Button(SharingMessages.showAllApplications(model.applications.count)) {
                                withAnimation(.snappy(duration: 0.25)) { showsAllApplications = true }
                            }
                            .textStyle(.chip)
                            .foregroundStyle(Color.paveAccent)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.pave)
                        }
                    }
                }
                adjustLine
                if application != nil {
                    SharePanel(title: SharingMessages.application) {
                        Toggle(ApplyMessages.cv, isOn: $includesCV).tint(.paveAccentFill).textStyle(.bodyMedium).padding(14)
                        ShareRowDivider(inset: 14)
                        Toggle(ApplyMessages.letter, isOn: $includesLetter).tint(.paveAccentFill).textStyle(.bodyMedium).padding(14)
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
                    if profile.avatar != nil {
                        ShareRowDivider(inset: 14)
                        Toggle(SharingMessages.photo, isOn: $includesPhoto)
                            .tint(.paveAccentFill)
                            .textStyle(.bodyMedium)
                            .padding(14)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(SharingMessages.quickShareHowLong)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.leading, 8)
                    FlowLayout(spacing: 8) {
                        ForEach(Self.durations, id: \.self) { option in
                            durationChip(option)
                        }
                    }
                }
                HStack(spacing: 20) {
                    Button(SharingMessages.quickShareSeesLink) { showsPreview = true }
                        .disabled(draft.problem != nil)
                    if let onMoreOptions {
                        Button(SharingMessages.moreOptions, action: onMoreOptions)
                    }
                }
                .textStyle(.link)
                .foregroundStyle(Color.paveAccent)
                .frame(minHeight: 44)
                .buttonStyle(.pave)
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
            begin()
        }
    }

    private func option(title: String, detail: String, icon: ImageResource, id: String) -> some View {
        let isOn = choice == id
        return Button {
            PaveHaptics.selection()
            choice = id
            customItems = nil
            customFiles = nil
            if !id.hasPrefix("app:"), !id.hasPrefix("kind:") { lastChoice = id }
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

    /// What goes along now, and a way to change it piece by piece.
    private var adjustLine: some View {
        let draft = draft
        let files = draft.content.files?.count ?? 0
        return Button {
            customItems = customItems ?? Set(draft.itemIDs)
            customFiles = customFiles ?? Set(draft.content.files ?? [])
            adjusts = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(SharingMessages.quickShareGoes(draft.itemIDs.count, files: files))
                    .foregroundStyle(Color.inkMuted)
                Text(SharingMessages.quickShareAdjust)
                    .foregroundStyle(Color.paveAccent)
                Spacer(minLength: 0)
            }
            .textStyle(.caption)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.pave)
        .padding(.top, -12)
        .sheet(isPresented: $adjusts) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(SharingMessages.quickShareAdjustHint)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        ShareComposerItems(
                            items: vault.items, template: draft.template,
                            chosen: Binding(get: { customItems ?? [] }, set: { customItems = $0 }),
                            files: Binding(get: { customFiles ?? [] }, set: { customFiles = $0 })
                        )
                    }
                    .padding(20)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .background(Color.canvas)
                .navigationTitle(SharingMessages.quickShareAdjustTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button(ApplyMessages.done) { adjusts = false } }
                }
            }
        }
    }

    /// Where it starts: what was asked for, or for Snel delen the choice of last time, if it still exists.
    private func begin() {
        guard !didStart else { return }
        didStart = true
        model.reloadApplications()
        switch start {
        case .profile:
            let known = lastChoice.isEmpty || profiles.contains { "sel:\($0.id)" == lastChoice }
            choice = known ? lastChoice : ""
        case .selection(let id):
            choice = "sel:\(id)"
            if let kept = profiles.first(where: { $0.id == id }), let days = kept.duration { duration = days }
        case .kind(let kind):
            choice = "kind:\(kind.rawValue)"
            duration = kind.duration
        case .application(let vacancyID, let documents):
            choice = "app:\(vacancyID)"
            includesCV = documents.contains(.cv)
            includesLetter = documents.contains(.letter)
            duration = .twoWeeks
        }
        if let recipientOrganisation, recipient.isEmpty { recipient = recipientOrganisation }
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
            if let share = await model.create(draft, application: application, photo: profile.avatar) {
                withAnimation(.spring(duration: 0.45, bounce: 0.15)) { created = share }
                onShared(share)
                // Your card goes to the wrist too, to be scanned without taking out the phone.
                if let url = model.link(for: share) {
                    ShareWatchBridge.show(url: url, title: share.recipientName, until: share.expiresAt, name: name, headline: headline)
                }
            }
        }
    }

    // MARK: Shown

    /// After Stop met delen: plainly done, with a way to share again and a way out.
    private var stopped: some View {
        VStack(spacing: 16) {
            Image(.iconCheckBadgeSolid)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .paveIconFrame(30)
                .foregroundStyle(Color.paveAccent)
                .paveIconFrame(72)
                .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 22))
                .accessibilityHidden(true)
            Text(SharingMessages.quickShareStoppedTitle)
                .textStyle(.emptyTitle)
                .foregroundStyle(Color.ink)
            Text(SharingMessages.quickShareStopped)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PavePrimaryButton(title: ApplyMessages.done, action: onDone)
                .padding(.top, 8)
            PaveSecondaryButton(title: SharingMessages.quickShareAgain) {
                withAnimation(.snappy(duration: 0.25)) {
                    created = nil
                    isStopped = false
                }
            }
        }
        .frame(maxWidth: 360)
        .padding(.top, 60)
        .transition(.opacity)
    }

    private func shown(_ share: ProfileShare) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                if isStopped {
                    stopped
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
