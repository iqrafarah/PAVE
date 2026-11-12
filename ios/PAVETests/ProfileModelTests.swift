import Foundation
import PAVECore
import SwiftUI
import Testing
import UIKit
@testable import PAVE

@MainActor
struct ProfileModelTests {
    private actor FakeProfiles: ProfileService {
        var stored: PaveProfile
        var savedNames: [String?] = []
        var savedPreferences: [(PaveThemeColor, PaveTextSize, PaveVaultLayout)] = []
        var savedCustomColors: [UInt32?] = []

        init(_ profile: PaveProfile) { stored = profile }

        func profile() async throws -> PaveProfile { stored }
        func setPreferredName(_ name: String?) async throws { savedNames.append(name) }
        func setPreferences(theme: PaveThemeColor, customColor: UInt32?, textSize: PaveTextSize, vaultLayout: PaveVaultLayout) async throws {
            savedPreferences.append((theme, textSize, vaultLayout))
            savedCustomColors.append(customColor)
        }
        func setAvatar(_ jpeg: Data, replacing oldPath: String?) async throws -> String { "u/new.jpg" }
        func removeAvatar(_ path: String) async throws {}
        func avatarData(_ path: String) async throws -> Data { Data() }
    }

    private func clean() {
        for key in [PaveAppearance.themeKey, PaveAppearance.customColorKey, PaveAppearance.textSizeKey, PaveAppearance.vaultLayoutKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    @Test func theLookOfTheAccountAppliesAndChangesAreSaved() async {
        clean()
        defer { clean() }
        let service = FakeProfiles(PaveProfile(fullName: "Ravi Santoso", theme: .blue, textSize: .large, vaultLayout: .list))
        let model = ProfileModel(service: service, onThemeChosen: { _, _ in })
        await model.load()
        #expect(model.theme == .blue)
        #expect(PaveAppearance.vaultLayout == .list)

        await model.setTheme(.lime)
        await model.setVaultLayout(.grid)
        #expect(PaveAppearance.theme == .lime)
        #expect(PaveAppearance.vaultLayout == .grid)
        let saved = await service.savedPreferences
        #expect(saved.last?.0 == .lime && saved.last?.1 == .large && saved.last?.2 == .grid)
    }

    @Test func anOwnColourShowsWhileChoosingAndIsSavedOnce() async {
        clean()
        defer {
            clean()
            PaveAppearance.applyStored()
        }
        let service = FakeProfiles(PaveProfile(fullName: "Ravi Santoso"))
        let model = ProfileModel(service: service, onThemeChosen: { _, _ in })
        await model.load()

        model.previewCustomColor(0xFFD1E8)
        model.previewCustomColor(0xFF66AA)
        #expect(PaveThemeStore.shared.theme == .custom)
        #expect(PaveThemeStore.shared.accent == PaveThemeColor.readableAccent(for: 0xFF66AA))
        #expect(await service.savedPreferences.isEmpty)

        await model.saveCustomColor()
        #expect(await service.savedCustomColors == [0xFF66AA])
        #expect(PaveAppearance.customColor == 0xFF66AA)

        await model.setTheme(.blue)
        #expect(model.customColor == 0xFF66AA)
        #expect(PaveHomeScreen.iconName(theme: .custom, customColor: 0xFF66AA) == "AppIconPink")
        #expect(PaveHomeScreen.iconName(theme: .green, customColor: nil) == nil)
        #expect(PaveHomeScreen.iconName(theme: .lime, customColor: nil) == "AppIconLime")
        #expect(PaveThemeStore.shared.accent == PaveThemeColor.blue.accent)
    }

    @Test func theWidgetsGetTheChosenColourThroughTheKeychain() throws {
        let group = try #require(Bundle.main.object(forInfoDictionaryKey: "PaveKeychainGroup") as? String)
        defer { PaveHomeScreen.updateWidgets(theme: PaveAppearance.theme, customColor: PaveAppearance.customColor) }
        PaveHomeScreen.updateWidgets(theme: .pink, customColor: nil)
        #expect(PaveHomeScreen.storedWidgetAccent(group: group) == PaveThemeColor.hex(PaveThemeColor.pink.accent))
        PaveHomeScreen.updateWidgets(theme: .custom, customColor: 0xFFEB3B)
        #expect(PaveHomeScreen.storedWidgetAccent(group: group) == PaveThemeColor.hex(PaveThemeColor.readableAccent(for: 0xFFEB3B)))
    }

    @Test func withoutTheMigrationTheLookStaysOnThisDevice() async {
        clean()
        defer { clean() }
        let service = FakeProfiles(PaveProfile(fullName: "Ravi Santoso", canChangeSettings: false))
        let model = ProfileModel(service: service, onThemeChosen: { _, _ in })
        await model.load()
        await model.setTextSize(.small)
        #expect(model.textSize == .small)
        #expect(!model.savesInAccount)
        #expect(await service.savedPreferences.isEmpty)
    }

    @Test func theNameIsTidiedAndAnEmptyNameGoesBackToTheSchoolName() async {
        let service = FakeProfiles(PaveProfile(preferredName: "Rav", fullName: "Ravi Santoso"))
        let model = ProfileModel(service: service, onThemeChosen: { _, _ in })
        await model.load()
        #expect(await model.saveName("  Ravi   S. "))
        #expect(model.profile.displayName == "Ravi S.")
        #expect(await model.saveName(" "))
        #expect(model.profile.displayName == "Ravi")
        #expect(await !model.saveName(String(repeating: "a", count: 61)))
        #expect(model.problem != nil)
        #expect(await service.savedNames == ["Ravi S.", nil])
    }

    @Test func textSizeMovesFromTheDeviceSetting() {
        #expect(DynamicTypeSize.large.shifted(by: .small) == .medium)
        #expect(DynamicTypeSize.large.shifted(by: .standard) == .large)
        #expect(DynamicTypeSize.large.shifted(by: .large) == .xxLarge)
        #expect(DynamicTypeSize.xSmall.shifted(by: .small) == .xSmall)
    }
}
