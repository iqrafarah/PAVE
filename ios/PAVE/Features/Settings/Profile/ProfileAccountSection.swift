import PhotosUI
import SwiftUI

/// Account in Instellingen: the photo (change it, frame it in the circle, or remove it), the name Ayla uses, and the
/// full name and e-mail from the school, which cannot be changed here.
struct ProfileAccountSection: View {
    @Environment(ProfileModel.self) private var profile
    let fallbackName: String?

    @State private var pickedPhoto: PhotosPickerItem?
    @State private var choosesPhoto = false
    @State private var framing: FramedImage?
    @State private var confirmsRemove = false
    @State private var name = ""
    @FocusState private var isEditingName: Bool

    private var displayName: String? { profile.profile.displayName ?? fallbackName }
    private var nameChanged: Bool { name.trimmingCharacters(in: .whitespaces) != (profile.profile.preferredName ?? "") }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            photo
            if profile.state == .ready {
                nameField
                organisationDetails
            }
            if let problem = profile.problem {
                PaveInlineError(message: problem)
                    .padding(.horizontal, 4)
            }
        }
        .onAppear { name = profile.profile.preferredName ?? "" }
        .onChange(of: profile.profile.preferredName) { _, new in name = new ?? "" }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    framing = FramedImage(image: image)
                }
                pickedPhoto = nil
            }
        }
        .sheet(item: $framing) { framed in
            VaultImageFramer(image: framed.image, shape: .circle, title: SettingsMessages.photoTitle) { result in
                Task { await profile.setAvatar(result) }
            }
        }
        .photosPicker(isPresented: $choosesPhoto, selection: $pickedPhoto, matching: .images)
        .confirmationDialog(SettingsMessages.removePhotoQuestion, isPresented: $confirmsRemove, titleVisibility: .visible) {
            Button(SettingsMessages.removePhoto, role: .destructive) { Task { await profile.removeAvatar() } }
        }
    }

    private var photo: some View {
        HStack(alignment: .center, spacing: 16) {
            AccountBadge(name: displayName, image: profile.avatar, size: 72)
                .overlay {
                    if profile.isSaving { ProgressView().tint(.white) }
                }
            VStack(alignment: .leading, spacing: 8) {
                Text(displayName ?? "Je account")
                    .textStyle(.listTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                if profile.state == .ready, profile.savesInAccount {
                    HStack(spacing: 8) {
                        Button { choosesPhoto = true } label: {
                            Text(SettingsMessages.changePhoto)
                                .textStyle(.gapChip)
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 36)
                                .overlay { Capsule().strokeBorder(Color.ink, lineWidth: 1) }
                                .contentShape(.capsule)
                        }
                        .buttonStyle(.pave)
                        if profile.profile.avatarPath != nil {
                            Button { confirmsRemove = true } label: {
                                HStack(spacing: 4) {
                                    Image(.iconTrashSolid)
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                        .accessibilityHidden(true)
                                    Text(SettingsMessages.removePhoto)
                                        .textStyle(.gapChip)
                                }
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 8)
                                .frame(minHeight: 36)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.pave)
                        }
                    }
                    .disabled(profile.isSaving)
                    Text(SettingsMessages.photoHint)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else if profile.state == .ready {
                    Text(SettingsMessages.notSetUp)
                        .textStyle(.caption)
                        .foregroundStyle(Color.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.white, in: .rect(cornerRadius: 14))
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(SettingsMessages.name)
                .textStyle(.label)
                .foregroundStyle(Color.ink)
            HStack(spacing: 8) {
                TextField("", text: $name, prompt: Text(profile.profile.fullName?.split(separator: " ").first.map(String.init) ?? SettingsMessages.namePrompt).foregroundStyle(Color.inkMuted))
                    .textStyle(.input)
                    .foregroundStyle(Color.ink)
                    .textContentType(.nickname)
                    .submitLabel(.done)
                    .focused($isEditingName)
                    .onSubmit(save)
                    .disabled(!profile.savesInAccount)
                if nameChanged {
                    Button(SettingsMessages.saveName, action: save)
                        .textStyle(.gapChip)
                        .foregroundStyle(Color.paveAccent)
                        .frame(minHeight: 36)
                        .disabled(profile.isSaving)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(Color.canvas, in: .rect(cornerRadius: 10))
            Text(SettingsMessages.nameHint)
                .textStyle(.caption)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.white, in: .rect(cornerRadius: 14))
        .animation(.snappy(duration: 0.2), value: nameChanged)
    }

    @ViewBuilder
    private var organisationDetails: some View {
        let details = [(SettingsMessages.fullName, profile.profile.fullName), (SettingsMessages.email, profile.profile.email)]
            .compactMap { label, value in value.map { (label, $0) } }
        if !details.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(details, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .textStyle(.caption)
                            .foregroundStyle(Color.inkMuted)
                        Text(value)
                            .textStyle(.bodyMedium)
                            .foregroundStyle(Color.ink)
                            .textSelection(.enabled)
                    }
                }
                Text(SettingsMessages.fromOrganisation)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: .rect(cornerRadius: 14))
        }
    }

    private func save() {
        isEditingName = false
        guard nameChanged else { return }
        Task { _ = await profile.saveName(name) }
    }
}

private struct FramedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
