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
    @State private var showsPrivacy = false
    @State private var showsEarlier = false
    @State private var editing: SavedProfile?
    @Environment(VaultModel.self) private var vault

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ShareProfileCard {
                        // A fair profile, when there is one, is what you show at a stand.
                        if let fair = model.profiles?.first(where: { $0.template == .fair }) {
                            composing = ShareTemplateChoice(template: .fair, withApplication: false, profile: fair)
                        } else {
                            composing = ShareTemplateChoice(template: .fair)
                        }
                    }
                    Text(SharingMessages.intro)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .padding(.horizontal, 8)
                        .fixedSize(horizontal: false, vertical: true)
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Color.canvas.ignoresSafeArea())
            .refreshable { await model.load() }
            .mainScreenToolbar(SharingMessages.title, onShowMenu: onShowMenu)
            .navigationDestination(item: $opened) { id in ShareDetailView(model: model, shareID: id) }
        }
        .task { await model.load() }
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
            composing = ShareTemplateChoice(template: .fair, organisation: employer.name)
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
        case .loading where model.shares.isEmpty:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
        default:
            suggestions
            live
        }
        if let profiles = model.profiles { saved(profiles) }
        templates
        SharePanel(title: "Meer") {
            ShareLinkRow(icon: .iconCamera, title: SharingMessages.scan, detail: SharingMessages.scanHint) { showsScanner = true }
            ShareRowDivider()
            ShareLinkRow(icon: .iconClockSolid, title: SharingMessages.report, detail: SharingMessages.reportHint) { showsReport = true }
            ShareRowDivider()
            ShareLinkRow(icon: .iconShieldCheckSolid, title: SharingMessages.howItWorks) { showsPrivacy = true }
        }
        if !model.ended.isEmpty { earlier }
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
    private func saved(_ profiles: [SavedProfile]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SharePanel(title: SharingMessages.profiles) {
                ForEach(profiles) { profile in
                    SavedProfileRow(profile: profile) { editing = profile } onShare: {
                        composing = ShareTemplateChoice(template: profile.template, withApplication: false, profile: profile)
                    }
                    ShareRowDivider()
                }
                Button {
                    editing = SavedProfile.starter(for: .employer, items: vault.items)
                } label: {
                    HStack(spacing: 14) {
                        ShareRowIcon(icon: .iconPlusCircleSolid)
                        Text(SharingMessages.newProfile).textStyle(.bodyMedium).foregroundStyle(Color.paveAccent)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .contentShape(.rect)
                }
                .buttonStyle(.pave)
            }
            if profiles.isEmpty {
                Text(SharingMessages.profilesHint)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var templates: some View {
        SharePanel(title: SharingMessages.newShare) {
            ForEach(Array(ShareTemplate.allCases.enumerated()), id: \.element) { index, template in
                Button { composing = ShareTemplateChoice(template: template) } label: {
                    HStack(spacing: 14) {
                        ShareTemplateIcon(template: template)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(SharingMessages.template(template)).textStyle(.bodyMedium).foregroundStyle(Color.ink)
                            Text(SharingMessages.templateHint(template)).textStyle(.caption).foregroundStyle(Color.inkMuted).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .contentShape(.rect)
                }
                .buttonStyle(.pave)
                .disabled(model.service == nil || model.state == .notSetUp)
                if index < ShareTemplate.allCases.count - 1 { ShareRowDivider() }
            }
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
