import PAVECore
import SwiftUI

/// Making or changing a saved profile: its name, for whom, the line under your name, your e-mail, and which evidence
/// goes in, each briefly or in full.
struct SavedProfileEditor: View {
    let model: SharingModel
    let onDone: () -> Void

    @Environment(VaultModel.self) private var vault
    @State private var profile: SavedProfile
    @State private var chosen: Set<String>
    @State private var brief: Set<String>
    @State private var isSaving = false
    @State private var confirmsDelete = false
    private let isNew: Bool

    init(model: SharingModel, profile: SavedProfile, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
        isNew = profile.id.isEmpty
        _profile = State(initialValue: profile)
        _chosen = State(initialValue: Set(profile.itemIDs))
        _brief = State(initialValue: profile.briefIDs)
    }

    /// In the order of the vault, so the recipient sees it as you keep it.
    private var kept: SavedProfile {
        var kept = profile
        kept.itemIDs = vault.items.map(\.id).filter(chosen.contains)
        kept.briefIDs = brief.intersection(chosen)
        return kept
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SharePanel(title: SharingMessages.profileName) {
                        TextField(SharingMessages.profileName, text: $profile.name)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                            .padding(14)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(SharingMessages.profileFor)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.inkMuted)
                            .padding(.leading, 8)
                        FlowLayout(spacing: 8) {
                            ForEach(ShareTemplate.allCases, id: \.self) { template in
                                templateChip(template)
                            }
                        }
                    }
                    SharePanel(title: SharingMessages.aboutYou) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(SharingMessages.headline).textStyle(.caption).foregroundStyle(Color.inkMuted)
                            TextField(SharingMessages.headline, text: $profile.headline, prompt: Text(SharingMessages.headlinePrompt).foregroundStyle(Color.inkMuted))
                                .textStyle(.bodyMedium)
                                .foregroundStyle(Color.ink)
                        }
                        .padding(14)
                        ShareRowDivider(inset: 14)
                        Toggle(SharingMessages.email, isOn: $profile.includesEmail)
                            .tint(.paveAccentFill)
                            .textStyle(.bodyMedium)
                            .padding(14)
                    }
                    Text(SharingMessages.profileItems)
                        .textStyle(.calloutTitle)
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(SharingMessages.detailExplained)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, -12)
                    ShareComposerItems(items: vault.items, template: profile.template, chosen: $chosen, brief: $brief)
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.canvas)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if let problem = kept.problem {
                        Text(SharingMessages.profileProblem(problem))
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                            .transition(.opacity)
                    }
                    PavePrimaryButton(title: SharingMessages.saveProfile, loadingTitle: SharingMessages.saving, isLoading: isSaving) { save() }
                        .disabled(kept.problem != nil || isSaving)
                }
                .animation(.easeOut(duration: 0.2), value: kept.problem)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.canvas)
            }
            .navigationTitle(isNew ? SharingMessages.newProfile : SharingMessages.editProfile)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SharingMessages.cancel, action: onDone)
                }
                if !isNew {
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) { confirmsDelete = true } label: {
                            Image(.iconTrashSolid)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .paveIconFrame(17)
                                .foregroundStyle(Color.critical)
                        }
                        .accessibilityLabel(SharingMessages.deleteProfile)
                    }
                }
            }
            .confirmationDialog(SharingMessages.deleteProfileQuestion(profile.name), isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button(SharingMessages.deleteProfile, role: .destructive) {
                    Task {
                        await model.delete(profile)
                        onDone()
                    }
                }
            } message: {
                Text(SharingMessages.deleteProfileHint)
            }
        }
    }

    private func templateChip(_ template: ShareTemplate) -> some View {
        let isOn = profile.template == template
        return Button {
            PaveHaptics.selection()
            profile.template = template
        } label: {
            HStack(spacing: 6) {
                Image(ShareTemplateIcon.image(template))
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .paveIconFrame(14)
                    .accessibilityHidden(true)
                Text(SharingMessages.template(template)).textStyle(.chip)
            }
            .foregroundStyle(isOn ? Color.white : Color.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(isOn ? Color.paveAccentFill : Color.panel, in: .capsule)
            .overlay { Capsule().strokeBorder(isOn ? Color.clear : Color.cardBorder, lineWidth: 1) }
            .frame(minHeight: 44)
            .contentShape(.capsule)
        }
        .buttonStyle(.pave)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func save() {
        isSaving = true
        Task {
            let ok = await model.save(kept)
            isSaving = false
            if ok { onDone() }
        }
    }
}
