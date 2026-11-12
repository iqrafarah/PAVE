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

        init(_ profile: PaveProfile) { stored = profile }

        func profile() async throws -> PaveProfile { stored }
        func setPreferredName(_ name: String?) async throws { savedNames.append(name) }
        func setPreferences(theme: PaveThemeColor, textSize: PaveTextSize, vaultLayout: PaveVaultLayout) async throws {
            savedPreferences.append((theme, textSize, vaultLayout))
        }
        func setAvatar(_ jpeg: Data, replacing oldPath: String?) async throws -> String { "u/new.jpg" }
        func removeAvatar(_ path: String) async throws {}
        func avatarData(_ path: String) async throws -> Data { Data() }
    }

    private func clean() {
        for key in [PaveAppearance.themeKey, PaveAppearance.textSizeKey, PaveAppearance.vaultLayoutKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    @Test func theLookOfTheAccountAppliesAndChangesAreSaved() async {
        clean()
        defer { clean() }
        let service = FakeProfiles(PaveProfile(fullName: "Ravi Santoso", theme: .blue, textSize: .large, vaultLayout: .list))
        let model = ProfileModel(service: service)
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

    @Test func withoutTheMigrationTheLookStaysOnThisDevice() async {
        clean()
        defer { clean() }
        let service = FakeProfiles(PaveProfile(fullName: "Ravi Santoso", canChangeSettings: false))
        let model = ProfileModel(service: service)
        await model.load()
        await model.setTextSize(.small)
        #expect(model.textSize == .small)
        #expect(!model.savesInAccount)
        #expect(await service.savedPreferences.isEmpty)
    }

    @Test func theNameIsTidiedAndAnEmptyNameGoesBackToTheSchoolName() async {
        let service = FakeProfiles(PaveProfile(preferredName: "Rav", fullName: "Ravi Santoso"))
        let model = ProfileModel(service: service)
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
