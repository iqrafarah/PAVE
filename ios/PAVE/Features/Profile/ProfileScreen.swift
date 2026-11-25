import PAVECore
import SwiftUI

/// Profiel en delen: what you share now and with whom, sharing something new for a kind of recipient, scanning a QR code
/// at a fair, the report of who looked, and what sharing means. You stay in charge: everything can be paused or taken
/// back (kick-off p. 10, 36).
struct ProfileScreen: View {
    let model: SharingModel
    let onShowMenu: (() -> Void)?

    @State private var composing: ShareTemplateChoice?
    @State private var opened: String?
    @State private var showsScanner = false
    /// Just shared: its page opens once the composer has gone.
    @State private var justShared: String?
    /// Chosen after scanning an employer: the composer opens once the scanner has gone.
    @State private var sharesBack: FairEmployer?
    @State private var showsReport = false
    @State private var showsQuickShare = false
    @State private var quickStart = QuickShareSheet.Start.profile
    @State private var quickRecipient: String?
    /// "Meer opties" was tapped: the steps open once the share screen is gone.
    @State private var detailedNext: ShareTemplateChoice?
    @State private var showsPrivacy = false
    @State private var showsEarlier = false
    @State private var editing: SavedProfile?
    @Environment(VaultModel.self) private var vault

    var body: some View {
        NavigationStack {
            ScrollView {
                // What you share now on the left; making and keeping profiles on the right where there is room.
                PaveColumns(minColumnWidth: 330, spacing: 22) {
                    VStack(alignment: .leading, spacing: 22) {
                        if let invited = model.fairApplications?.first(where: \.awaitsAnswer) {
                            NavigationLink { FairDayView(model: model) } label: {
                                ShareLinkRow.label(icon: .iconCalendarDaysSolid, title: SharingMessages.fairInvitedTitle, detail: SharingMessages.fairInvitedBody(invited, employer: FairDay.employerName(slug: invited.employerSlug)))
                                    .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 14))
                            }
                            .buttonStyle(.pave)
                        }
                        ShareProfileCard { share(.profile) }
                        Text(SharingMessages.intro)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .padding(.horizontal, 8)
                            .fixedSize(horizontal: false, vertical: true)
                        content
                    }
                    VStack(alignment: .leading, spacing: 22) {
                        making
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 1080)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Color.canvas.ignoresSafeArea())
            .refreshable {
                await vault.load()
                await model.load()
            }
            .mainScreenToolbar(SharingMessages.title, onShowMenu: onShowMenu)
            .navigationDestination(item: $opened) { id in ShareDetailView(model: model, shareID: id) }
            .navigationDestination(isPresented: Bindable(model).showsFairDay) { FairDayView(model: model) }
            .onChange(of: model.shareToOpen, initial: true) { _, id in
                guard let id else { return }
                model.shareToOpen = nil
                opened = id
            }
        }
        .task {
            // Sharing chooses from the vault, which may not have been opened yet.
            if vault.state != .ready { await vault.load() }
            await model.load()
        }
        .onChange(of: model.request, initial: true) { _, command in
            guard let command else { return }
            model.request = nil
            switch command {
            case .share(let organisation, let duration, let withApplication):
                composing = ShareTemplateChoice(template: .employer, organisation: organisation, duration: duration, withApplication: withApplication)
            case .stop(let organisation):
                Task {
                    if model.shares.isEmpty { await model.load() }
                    if let share = model.live(named: organisation) {
                        model.asksToRevoke = share.id
                        opened = share.id
                    }
                }
            case .showShares:
                break
            }
        }
        .sheet(item: $composing, onDismiss: {
            guard let id = justShared else { return }
            justShared = nil
            opened = id
        }) { choice in
            ShareComposer(
                model: model, template: choice.template, recipientOrganisation: choice.organisation, duration: choice.duration,
                withApplication: choice.withApplication, doneTitle: SharingMessages.showShare, onShared: { justShared = $0.id },
                savedProfile: choice.profile
            ) { composing = nil }
        }
        .sheet(isPresented: $showsScanner, onDismiss: {
            guard let employer = sharesBack else { return }
            sharesBack = nil
            fairShare(to: employer.name)
        }) {
            ShareScanSheet(model: model) { sharesBack = $0 }
        }
        .sheet(isPresented: $showsReport) { ShareReportSheet(model: model) }
        .sheet(item: $editing) { profile in
            SavedProfileEditor(model: model, profile: profile) { editing = nil }
        }
        .confirmationDialog(
            model.live.isEmpty ? SharingMessages.nothingToStop : SharingMessages.stopAllQuestion,
            isPresented: Binding(get: { model.asksToStopAll && model.state != .loading }, set: { if !$0 { model.asksToStopAll = false } }),
            titleVisibility: .visible
        ) {
            if !model.live.isEmpty {
                Button(SharingMessages.pauseAll) { Task { await model.stopAll(revoking: false) } }
                Button(SharingMessages.revokeAll, role: .destructive) { Task { await model.stopAll(revoking: true) } }
            }
        } message: {
            if !model.live.isEmpty { Text(SharingMessages.stopAllHint(model.live.count)) }
        }
        .sheet(isPresented: $showsPrivacy) { SharePrivacySheet() }
        .sheet(isPresented: $showsQuickShare, onDismiss: {
            guard let next = detailedNext else { return }
            detailedNext = nil
            composing = next
        }) {
            QuickShareSheet(model: model, start: quickStart, recipientOrganisation: quickRecipient, onMoreOptions: {
                detailedNext = detailedChoice(for: quickStart)
                showsQuickShare = false
            }) { showsQuickShare = false }
        }
        .alert(SharingMessages.title, isPresented: Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.problem ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .unavailable:
            PaveNotice(message: SharingMessages.demoOnly)
        case .notSetUp:
            PaveNotice(message: SharingMessages.notSetUp)
        case .failed:
            PaveNotice(message: SharingMessages.loadFailed, tone: .critical)
            PaveSecondaryButton(title: SharingMessages.tryAgain) { Task { await model.load() } }
                .frame(maxWidth: 260)
        case .loading where model.shares.isEmpty:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
        default:
            suggestions
            live
        }
        if !model.ended.isEmpty { earlier }
    }

    /// Your profiles, sharing something new, and the rest.
    @ViewBuilder
    private var making: some View {
        sharingList(model.profiles ?? [])
        SharePanel(title: SharingMessages.more) {
            NavigationLink { FairDayView(model: model) } label: {
                ShareLinkRow.label(icon: .iconQrcode, title: SharingMessages.fairDay, detail: SharingMessages.fairDayHint)
            }
            .buttonStyle(.pave)
            ShareRowDivider()
            ShareLinkRow(icon: .iconCamera, title: SharingMessages.scan, detail: SharingMessages.scanHint) { showsScanner = true }
            ShareRowDivider()
            ShareLinkRow(icon: .iconClockSolid, title: SharingMessages.report, detail: SharingMessages.reportHint) { showsReport = true }
            ShareRowDivider()
            ShareLinkRow(icon: .iconShieldCheckSolid, title: SharingMessages.howItWorks) { showsPrivacy = true }
        }
    }

    @ViewBuilder
    private var suggestions: some View {
        ForEach(model.suggestions) { suggestion in
            if let share = model.share(suggestion.shareID) {
                Button { opened = share.id } label: {
                    HStack(alignment: .top, spacing: 12) {
                        ShareTemplateIcon(template: share.template)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(share.recipient).textStyle(.bodyMedium).foregroundStyle(Color.ink)
                            Text(SharingMessages.advice(suggestion.reason)).textStyle(.caption).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(Color.paveSurfaceTint, in: .rect(cornerRadius: 16))
                    .contentShape(.rect(cornerRadius: 16))
                }
                .buttonStyle(.pave)
            }
        }
    }

    @ViewBuilder
    private var live: some View {
        if model.live.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(SharingMessages.nothingShared).textStyle(.listTitle).foregroundStyle(Color.ink)
                Text(SharingMessages.nothingSharedHint).textStyle(.caption).foregroundStyle(Color.inkMuted)
            }
        } else {
            SharePanel(title: SharingMessages.live) {
                ForEach(Array(model.live.enumerated()), id: \.element.id) { index, share in
                    Button { opened = share.id } label: { ShareRow(share: share) }
                        .buttonStyle(.pave)
                    if index < model.live.count - 1 { ShareRowDivider() }
                }
            }
        }
    }

    /// Your saved profiles, to share in two taps, and a new one.
    /// Every share starts on the one share screen.
    private func share(_ start: QuickShareSheet.Start, to recipient: String? = nil) {
        quickStart = start
        quickRecipient = recipient
        showsQuickShare = true
    }

    /// Back to an employer you scanned: your fair selection if you made one, else what a fair usually needs.
    private func fairShare(to employer: String) {
        if let fair = model.profiles?.first(where: { $0.template == .fair }) {
            share(.selection(fair.id), to: employer)
        } else {
            share(.kind(.fair), to: employer)
        }
    }

    /// The steps with purpose and downloading, for what the share screen started on.
    private func detailedChoice(for start: QuickShareSheet.Start) -> ShareTemplateChoice {
        switch start {
        case .selection(let id):
            if let kept = model.profiles?.first(where: { $0.id == id }) {
                return ShareTemplateChoice(template: kept.template, withApplication: false, profile: kept)
            }
            return ShareTemplateChoice(template: .employer)
        case .kind(let kind): return ShareTemplateChoice(template: kind)
        case .profile, .application: return ShareTemplateChoice(template: .employer)
        }
    }

    /// One list for everyone you share with: your own profiles first, then the kinds of recipient you have none for
    /// yet. Every row works the same: tap it to change or make the profile, Delen to share it.
    private func sharingList(_ profiles: [SavedProfile]) -> some View {
        let open = ShareTemplate.allCases.filter { kind in !profiles.contains { $0.template == kind } }
        let canShare = model.service != nil && model.state != .notSetUp
        return VStack(alignment: .leading, spacing: 6) {
            SharePanel(title: SharingMessages.profiles) {
                ForEach(profiles) { profile in
                    SavedProfileRow(profile: profile) { editing = profile } onShare: {
                        share(.selection(profile.id))
                    }
                    ShareRowDivider()
                }
                ForEach(open, id: \.self) { kind in
                    SavedProfileRow(template: kind) {
                        editing = SavedProfile.starter(for: kind, items: vault.items)
                    } onShare: {
                        share(.kind(kind))
                    }
                    ShareRowDivider()
                }
                Menu {
                    ForEach(ShareTemplate.allCases, id: \.self) { kind in
                        Button {
                            editing = SavedProfile.starter(for: kind, items: vault.items)
                        } label: {
                            Label(SharingMessages.template(kind), image: ShareTemplateIcon.image(kind))
                        }
                    }
                } label: {
                    HStack(spacing: 14) {
                        ShareRowIcon(icon: .iconPlus)
                        Text(SharingMessages.newProfile).textStyle(.bodyMedium).foregroundStyle(Color.paveAccent)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .contentShape(.rect)
                }
            }
            .disabled(!canShare)
            Text(SharingMessages.profilesHint)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 8)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var earlier: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { showsEarlier.toggle() }
            } label: {
                HStack {
                    Text("\(SharingMessages.earlier) · \(model.ended.count)").textStyle(.bodyMedium).foregroundStyle(Color.inkMuted)
                    Spacer()
                    Image(.iconChevronDown).renderingMode(.template).resizable().scaledToFit().frame(height: 6)
                        .rotationEffect(.degrees(showsEarlier ? 180 : 0)).foregroundStyle(Color.inkMuted)
                }
                .padding(.horizontal, 4)
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.pave)
            if showsEarlier {
                VStack(spacing: 0) {
                    ForEach(Array(model.ended.enumerated()), id: \.element.id) { index, share in
                        Button { opened = share.id } label: { ShareRow(share: share) }.buttonStyle(.pave)
                        if index < model.ended.count - 1 { ShareRowDivider() }
                    }
                }
                .background(Color.panel, in: .rect(cornerRadius: 14))
            }
        }
    }
}

/// Which kind of share to start, and for whom when it came from a fair.
struct ShareTemplateChoice: Identifiable {
    let template: ShareTemplate
    var organisation: String?
    var duration: ShareDuration?
    var withApplication = true
    var profile: SavedProfile?
    var id: String { "\(template.rawValue)-\(organisation ?? "")-\(profile?.id ?? "")" }
}
