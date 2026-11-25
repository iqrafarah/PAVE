import PAVECore
import SwiftUI

/// Sharing in four steps, as the sketchbook and the kick-off ask: what, with whom and what for, how long, and a check in
/// plain words before it is confirmed with Face ID. Then the QR code and the link.
struct ShareComposer: View {
    enum Step: Int, CaseIterable { case what, who, howLong, check }

    let model: SharingModel
    let template: ShareTemplate
    var recipientOrganisation: String?
    var vacancyID: String?
    var withApplication = true
    /// Which of the application's documents start on: from the studio only what was made.
    var startsWith: Set<ApplicationDocumentKind> = [.cv, .letter]
    /// The words of the last button, for where it goes back to.
    var doneTitle = ApplyMessages.done
    /// Called once it is shared, before the user closes it.
    var onShared: (ProfileShare) -> Void = { _ in }
    /// Shared from a saved profile: its evidence, headline and e-mail are filled in, and it starts at "Met wie".
    var savedProfile: SavedProfile?
    let onDone: () -> Void

    @Environment(VaultModel.self) private var vault
    @Environment(ProfileModel.self) private var profile
    @State private var step = Step.what
    @State private var chosen: Set<String> = []
    @State private var applicationID: String?
    @State private var includesCV = true
    @State private var includesLetter = true
    @State private var includesEmail = true
    /// Evidence shown briefly, from a saved profile.
    @State private var brief: Set<String> = []
    @State private var headline = ""
    @State private var recipientName = ""
    @State private var organisation = ""
    @State private var title = ""
    @State private var purpose = ""
    @State private var duration: ShareDuration
    @State private var allowsDownload = false
    @State private var created: ProfileShare?
    @State private var confirmsDiscard = false
    @State private var didStart = false
    @State private var makesApplication = false
    @State private var newVacancy: Vacancy?
    @Environment(\.vacancyRequest) private var vacancyRequest

    init(
        model: SharingModel, template: ShareTemplate, recipientOrganisation: String? = nil, vacancyID: String? = nil,
        duration: ShareDuration? = nil, withApplication: Bool = true, startsWith: Set<ApplicationDocumentKind> = [.cv, .letter],
        doneTitle: String = ApplyMessages.done, onShared: @escaping (ProfileShare) -> Void = { _ in }, savedProfile: SavedProfile? = nil, onDone: @escaping () -> Void
    ) {
        self.savedProfile = savedProfile
        self.startsWith = startsWith
        self.doneTitle = doneTitle
        self.onShared = onShared
        self.model = model
        self.template = template
        self.recipientOrganisation = recipientOrganisation
        self.vacancyID = vacancyID
        self.withApplication = withApplication
        self.onDone = onDone
        _duration = State(initialValue: duration ?? template.duration)
    }

    private var application: ApplicationDraft? { model.applications.first { $0.vacancy.id == applicationID } }
    private var name: String { profile.profile.fullName ?? profile.profile.displayName ?? "" }

    private var draft: ShareDraft {
        let app = application
        let content = ShareContent(
            profile: ShareProfile(
                name: name,
                headline: headline.isEmpty ? nil : headline,
                email: includesEmail ? profile.profile.email : nil,
                summary: app.map(\.cv.profile).flatMap { $0.isEmpty ? nil : $0 }
            ),
            cv: app != nil && includesCV ? app?.cv : nil,
            letter: app != nil && includesLetter ? app?.letter : nil,
            vacancyID: app?.vacancy.id,
            brief: brief.intersection(chosen).isEmpty ? nil : Array(brief.intersection(chosen))
        )
        let ids = vault.items.filter { chosen.contains($0.id) }.map(\.id)
        return ShareDraft(
            title: title, recipientName: recipientName, recipientOrganisation: organisation, purpose: purpose, template: template,
            itemIDs: ids, content: content, allowsDownload: allowsDownload, duration: duration
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let created {
                    ShareCreatedView(model: model, share: created, doneTitle: doneTitle, onDone: onDone)
                } else {
                    steps
                }
            }
            .background(Color.canvas)
            .navigationTitle(created == nil ? SharingMessages.template(template) : SharingMessages.shared)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if created == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        if step == .what {
                            Button(SharingMessages.cancel) { confirmsDiscard = true }
                        } else {
                            PaveBackButton { step = Step(rawValue: step.rawValue - 1) ?? .what }
                        }
                    }
                }
            }
            .confirmationDialog(SharingMessages.discardQuestion, isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button(SharingMessages.discard, role: .destructive, action: onDone)
            }
        }
        .presentationDetents([.large])
        .sheetDismissGuard(isBlocked: created == nil) { confirmsDiscard = true }
        .task {
            if vault.state != .ready { await vault.load() }
            start()
        }
    }

    private var steps: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ShareStepBar(step: step.rawValue, count: Step.allCases.count)
                Text(stepTitle)
                    .textStyle(.calloutTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                switch step {
                case .what: what
                case .who: who
                case .howLong: howLong
                case .check: check
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    private var stepTitle: String {
        switch step {
        case .what: SharingMessages.stepWhat
        case .who: SharingMessages.stepWho
        case .howLong: SharingMessages.stepHowLong
        case .check: SharingMessages.stepCheck
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var what: some View {
        SharePanel(title: SharingMessages.aboutYou) {
            HStack {
                Text(SharingMessages.name).textStyle(.bodyMedium).foregroundStyle(Color.ink)
                Spacer()
                Text(name.isEmpty ? SharingMessages.nameMissing : name)
                    .textStyle(name.isEmpty ? .caption : .bodyMedium)
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.trailing)
            }
            .padding(14)
            ShareRowDivider(inset: 14)
            Toggle(isOn: $includesEmail) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(SharingMessages.email).textStyle(.bodyMedium).foregroundStyle(Color.ink)
                    Text(profile.profile.email ?? "").textStyle(.caption).foregroundStyle(Color.inkMuted)
                }
            }
            .tint(.paveAccentFill)
            .padding(14)
            ShareRowDivider(inset: 14)
            VStack(alignment: .leading, spacing: 4) {
                Text(SharingMessages.headline).textStyle(.caption).foregroundStyle(Color.inkMuted)
                TextField(SharingMessages.headline, text: $headline, prompt: Text(SharingMessages.headlinePrompt).foregroundStyle(Color.inkMuted))
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color.ink)
            }
            .padding(14)
        }
        if template.offersApplication, !model.applications.isEmpty {
            SharePanel(title: SharingMessages.application) {
                applicationMenu
                if application != nil {
                    ShareRowDivider(inset: 14)
                    Toggle(ApplyMessages.cv, isOn: $includesCV).tint(.paveAccentFill).textStyle(.bodyMedium).padding(14)
                    ShareRowDivider(inset: 14)
                    Toggle(ApplyMessages.letter, isOn: $includesLetter).tint(.paveAccentFill).textStyle(.bodyMedium).padding(14)
                }
            }
            Text(SharingMessages.applicationHint).textStyle(.caption).foregroundStyle(Color.inkMuted).padding(.top, -12)
        }
        if template.offersApplication, model.applications.isEmpty, vacancyRequest != nil {
            SharePanel(title: SharingMessages.application) {
                Button { makesApplication = true } label: {
                    HStack(spacing: 12) {
                        Text(ApplyMessages.newApplication)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.paveAccent)
                        Spacer(minLength: 0)
                        Image(.iconPlus)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .paveIconFrame(15)
                            .foregroundStyle(Color.paveAccent)
                            .accessibilityHidden(true)
                    }
                    .padding(14)
                    .contentShape(.rect)
                }
                .buttonStyle(.pave)
            }
            Text(SharingMessages.applicationNoneHint).textStyle(.caption).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true).padding(.top, -12)
        }
        ShareComposerItems(items: vault.items, template: template, chosen: $chosen)
            .sheet(isPresented: $makesApplication, onDismiss: {
                guard let vacancy = newVacancy else { return }
                newVacancy = nil
                onDone()
                vacancyRequest?(.application(vacancy))
            }) {
                ApplicationNewSheet { newVacancy = $0 }
            }
    }

    /// Which application goes along: the job and the company each on their own line, so a long name never gets cut.
    private var applicationMenu: some View {
        Menu {
            Picker(SharingMessages.application, selection: $applicationID) {
                Text(SharingMessages.noApplication).tag(String?.none)
                ForEach(model.applications) { draft in
                    Button {} label: {
                        Text(draft.vacancy.title)
                        Text(draft.vacancy.company)
                    }
                    .tag(Optional(draft.vacancy.id))
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(application?.vacancy.title ?? SharingMessages.noApplication)
                        .textStyle(.bodyMedium)
                        .foregroundStyle(Color.ink)
                    if let company = application?.vacancy.company {
                        Text(company)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.paveAccent)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .contentShape(.rect)
        }
        .accessibilityLabel(SharingMessages.application)
        .accessibilityValue(application.map { "\($0.vacancy.title), \($0.vacancy.company)" } ?? SharingMessages.noApplication)
    }

    @ViewBuilder
    private var who: some View {
        field(SharingMessages.recipientName, text: $recipientName, prompt: SharingMessages.recipientNamePrompt)
        field(SharingMessages.recipientOrganisation, text: $organisation, prompt: SharingMessages.recipientOrganisationPrompt)
        field(SharingMessages.shareTitle, text: $title, prompt: SharingMessages.purposePrompt)
        field(SharingMessages.purpose, text: $purpose, prompt: SharingMessages.purposePrompt)
    }

    @ViewBuilder
    private var howLong: some View {
        FlowLayout(spacing: 8) {
            ForEach(ShareDuration.allCases, id: \.self) { option in
                let isOn = duration == option
                Button(SharingMessages.duration(option)) {
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
        }
        SharePanel(title: SharingMessages.recipientMay) {
            Toggle(SharingMessages.allowsDownload, isOn: $allowsDownload).tint(.paveAccentFill).textStyle(.bodyMedium).padding(14)
        }
        Text(SharingMessages.downloadHint).textStyle(.caption).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var check: some View {
        let draft = draft
        // What will happen, line by line, as a receipt to check before Face ID.
        SharePanel(title: SharingMessages.template(template)) {
            checkRow(SharingMessages.checkWhat, SharingMessages.checkWhatValue(draft, items: draft.itemIDs.count))
            ShareRowDivider(inset: 14)
            checkRow(SharingMessages.checkWho, SharingMessages.checkWhoValue(draft))
            if !draft.purpose.isEmpty {
                ShareRowDivider(inset: 14)
                checkRow(SharingMessages.checkPurpose, draft.purpose)
            }
            ShareRowDivider(inset: 14)
            checkRow(SharingMessages.checkUntil, SharingMessages.checkUntilValue(draft.duration.end(from: .now)))
            ShareRowDivider(inset: 14)
            checkRow(SharingMessages.checkRights, SharingMessages.checkRightsValue(draft.allowsDownload))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(SharingMessages.summary(draft, items: draft.itemIDs.count, until: draft.duration.end(from: .now)))
        Text(SharingMessages.checkFooter).textStyle(.caption).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
        if model.webURL == nil {
            PaveNotice(message: SharingMessages.noWebsite)
        } else if model.webURL?.host() == "localhost" {
            PaveNotice(message: SharingMessages.localOnly)
        }
        Text(SharingMessages.privacyText[4].1).textStyle(.caption).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
    }

    private func checkRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.inkMuted)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .textStyle(.bodyMedium)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VaultFormField(title: title, isRequired: false) {
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Color.inkMuted))
                .textStyle(.input)
                .foregroundStyle(Color.ink)
        }
    }

    // MARK: Moving on

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step == .check {
                PavePrimaryButton(title: confirmTitle, loadingTitle: SharingMessages.sharing, isLoading: model.isCreating) { confirm() }
                    .disabled(draft.problem != nil || model.isCreating)
            } else {
                PavePrimaryButton(title: SharingMessages.next) { step = Step(rawValue: step.rawValue + 1) ?? .check }
                    .disabled(!canGoOn)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(Color.canvas)
        .overlay(alignment: .top) { Rectangle().fill(Color.cardBorder).frame(height: 1) }
    }

    private var canGoOn: Bool {
        switch step {
        case .what: !chosen.isEmpty || (application != nil && (includesCV || includesLetter))
        case .who: !recipientName.trimmingCharacters(in: .whitespaces).isEmpty && !title.trimmingCharacters(in: .whitespaces).isEmpty
        default: true
        }
    }

    private var confirmTitle: String {
        LocalBiometricAuthenticator().kind.map { SharingMessages.confirmWith($0.name) } ?? SharingMessages.confirm
    }

    /// Face ID where there is one; without it, the tap on the button itself is the confirmation.
    private func confirm() {
        let draft = draft
        Task {
            let authenticator = LocalBiometricAuthenticator()
            if authenticator.kind != nil, !(await authenticator.authenticate(reason: SharingMessages.biometricReason(draft.recipientName))) { return }
            created = await model.create(draft, application: application, photo: profile.avatar)
            if let created { onShared(created) }
        }
    }

    private func start() {
        guard !didStart else { return }
        didStart = true
        chosen = Set(vault.items.filter { template.categories.contains($0.category) && $0.status != .rejected }.map(\.id))
        if let savedProfile {
            chosen = Set(savedProfile.itemIDs).intersection(vault.items.map(\.id))
            brief = savedProfile.briefIDs
            includesEmail = savedProfile.includesEmail
            if !savedProfile.headline.isEmpty { headline = savedProfile.headline }
            step = .who
        }
        if let vacancyID, model.applications.contains(where: { $0.vacancy.id == vacancyID }) { applicationID = vacancyID }
        // Asked for a company by name: its own application, if there is one.
        if applicationID == nil, let recipientOrganisation {
            applicationID = model.applications.first { $0.vacancy.company.localizedCaseInsensitiveContains(recipientOrganisation) || recipientOrganisation.localizedCaseInsensitiveContains($0.vacancy.company) }?.vacancy.id
        }
        if let app = application ?? (template == .employer && withApplication ? model.applications.first : nil) {
            applicationID = app.vacancy.id
            includesCV = startsWith.contains(.cv)
            includesLetter = startsWith.contains(.letter)
            headline = app.cv.headline
            organisation = recipientOrganisation ?? app.vacancy.company
            title = "Sollicitatie \(app.vacancy.title)"
            purpose = "Sollicitatie \(app.vacancy.title) bij \(app.vacancy.company)"
        }
        if template == .fair {
            recipientName = SharingMessages.fairRecipient
            title = recipientOrganisation.map { "Beurs, \($0)" } ?? "Banenbeurs"
        }
        if let recipientOrganisation, organisation.isEmpty { organisation = recipientOrganisation }
    }
}
