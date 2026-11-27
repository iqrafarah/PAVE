import Foundation
import PAVECore
import Testing
@testable import PAVE

@MainActor
struct ProfileLanguageTests {
    private actor FakeProfiles: ProfileService {
        var account: PaveAccountLanguage?
        var savedCodes: [String?] = []

        init(_ account: PaveAccountLanguage?) { self.account = account }

        func profile() async throws -> PaveProfile { PaveProfile(fullName: "Ravi Santoso") }
        func setPreferredName(_ name: String?) async throws {}
        func setPreferences(theme: PaveThemeColor, customColor: UInt32?, textSize: PaveTextSize, vaultLayout: PaveVaultLayout) async throws {}
        func setAvatar(_ jpeg: Data, replacing oldPath: String?) async throws -> String { "" }
        func removeAvatar(_ path: String) async throws {}
        func avatarData(_ path: String) async throws -> Data { Data() }
        func language() async throws -> PaveAccountLanguage? { account }
        func setLanguage(_ code: String?) async throws { savedCodes.append(code) }
    }

    /// The store is shared by the whole app: put back what was there.
    private func withStoredLanguage(_ body: () async -> Void) async {
        let key = PaveLanguageStore.key
        let before = UserDefaults.standard.string(forKey: key)
        let language = PaveLanguageStore.shared.language
        await body()
        PaveLanguageStore.shared.select(language)
        UserDefaults.standard.set(before, forKey: key)
    }

    @Test func theLanguageOfTheAccountAppliesAndChangesAreSaved() async {
        await withStoredLanguage {
            let service = FakeProfiles(PaveAccountLanguage(code: "pap"))
            let model = ProfileModel(service: service, onThemeChosen: { _, _ in })
            await model.load()
            #expect(model.savesLanguage)
            #expect(PaveLanguageStore.shared.language == .papiamentu)

            await model.setLanguage(.english)
            #expect(PaveLanguageStore.shared.language == .english)
            #expect(await service.savedCodes == ["en"])
        }
    }

    @Test func withoutTheMigrationTheLanguageStaysOnThisDevice() async {
        await withStoredLanguage {
            let service = FakeProfiles(nil)
            let model = ProfileModel(service: service, onThemeChosen: { _, _ in })
            await model.load()
            #expect(!model.savesLanguage)

            await model.setLanguage(.english)
            #expect(PaveLanguageStore.shared.language == .english)
            #expect(await service.savedCodes.isEmpty)
        }
    }
}
