import Observation
import PAVECore
import UIKit

/// The account in Instellingen: the name Ayla uses, the photo and the look of the app. The look applies at once on this
/// device and is saved in the account, so web and iPhone show the same; before the migration it stays on this device.
@Observable
final class ProfileModel {
    enum State: Equatable {
        case loading
        case ready
        /// The demo login has no profile.
        case unavailable
        case failed
    }

    private(set) var state = State.loading
    private(set) var profile = PaveProfile()
    private(set) var avatar: UIImage?
    private(set) var isSaving = false
    var problem: String?

    private(set) var theme = PaveAppearance.theme
    /// The last own colour, kept when you go back to one of the others so the picker still shows it.
    private(set) var customColor = PaveAppearance.customColor
    private(set) var textSize = PaveTextSize(rawValue: UserDefaults.standard.string(forKey: PaveAppearance.textSizeKey) ?? "") ?? .standard
    private(set) var vaultLayout = PaveAppearance.vaultLayout

    private let service: (any ProfileService)?
    private let defaults: UserDefaults
    /// Gives the widgets and the app icon the chosen colour.
    private let onThemeChosen: @MainActor (PaveThemeColor, UInt32?) -> Void

    init(
        service: (any ProfileService)?,
        defaults: UserDefaults = .standard,
        onThemeChosen: @escaping @MainActor (PaveThemeColor, UInt32?) -> Void = PaveHomeScreen.update
    ) {
        self.service = service
        self.defaults = defaults
        self.onThemeChosen = onThemeChosen
        if service == nil { state = .unavailable }
    }

    /// Whether the look is kept in the account (after the migration) or only here.
    var savesInAccount: Bool { profile.canChangeSettings }

    func load() async {
        guard let service else { return }
        do {
            let loaded = try await service.profile()
            profile = loaded
            state = .ready
            if loaded.canChangeSettings {
                customColor = loaded.customColor ?? customColor
                apply(theme: loaded.theme, textSize: loaded.textSize, vaultLayout: loaded.vaultLayout)
                onThemeChosen(theme, customColor)
            }
            await loadAvatar()
        } catch {
            if state != .ready { state = .failed }
        }
    }

    func setTheme(_ theme: PaveThemeColor) async {
        apply(theme: theme, textSize: textSize, vaultLayout: vaultLayout)
        onThemeChosen(theme, customColor)
        await savePreferences()
    }

    /// Shows an own colour at once, while you are still choosing it; `saveCustomColor` keeps it in the account.
    func previewCustomColor(_ color: UInt32) {
        customColor = color
        apply(theme: .custom, textSize: textSize, vaultLayout: vaultLayout)
    }

    func saveCustomColor() async {
        guard theme == .custom, customColor != nil else { return }
        onThemeChosen(theme, customColor)
        await savePreferences()
    }

    func setTextSize(_ textSize: PaveTextSize) async {
        apply(theme: theme, textSize: textSize, vaultLayout: vaultLayout)
        await savePreferences()
    }

    func setVaultLayout(_ vaultLayout: PaveVaultLayout) async {
        apply(theme: theme, textSize: textSize, vaultLayout: vaultLayout)
        await savePreferences()
    }

    /// Saves the name Ayla uses; an empty name goes back to the first name from the school. False when it failed.
    func saveName(_ text: String) async -> Bool {
        guard let service else { return false }
        problem = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let name = try PaveProfile.cleanedName(text)
            try await service.setPreferredName(name)
            profile.preferredName = name
            return true
        } catch {
            problem = SettingsMessages.message(for: ProfileError(error))
            return false
        }
    }

    func setAvatar(_ image: UIImage) async {
        guard let service, let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        problem = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let path = try await service.setAvatar(jpeg, replacing: profile.avatarPath)
            profile.avatarPath = path
            avatar = image
        } catch {
            problem = SettingsMessages.message(for: ProfileError(error))
        }
    }

    func removeAvatar() async {
        guard let service, let path = profile.avatarPath else { return }
        problem = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await service.removeAvatar(path)
            profile.avatarPath = nil
            avatar = nil
            await loadAvatar()
        } catch {
            problem = SettingsMessages.message(for: ProfileError(error))
        }
    }

    private func apply(theme: PaveThemeColor, textSize: PaveTextSize, vaultLayout: PaveVaultLayout) {
        self.theme = theme
        self.textSize = textSize
        self.vaultLayout = vaultLayout
        PaveAppearance.apply(theme, customColor: customColor)
        defaults.set(textSize.rawValue, forKey: PaveAppearance.textSizeKey)
        defaults.set(vaultLayout.rawValue, forKey: PaveAppearance.vaultLayoutKey)
    }

    private func savePreferences() async {
        guard let service, profile.canChangeSettings else { return }
        do {
            try await service.setPreferences(theme: theme, customColor: customColor, textSize: textSize, vaultLayout: vaultLayout)
            profile.theme = theme
            profile.customColor = customColor
            profile.textSize = textSize
            profile.vaultLayout = vaultLayout
        } catch {
            problem = SettingsMessages.message(for: ProfileError(error))
        }
    }

    /// The own photo, else the one the organisation set.
    private func loadAvatar() async {
        if let path = profile.avatarPath, let service, let data = try? await service.avatarData(path), let image = UIImage(data: data) {
            avatar = image
        } else if let url = profile.avatarURL, let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) {
            avatar = image
        }
    }
}
