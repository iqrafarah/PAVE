import Foundation
import Testing
@testable import PAVECore

struct ProfileTests {
    @Test func readsTheProfileAndFallsBackToKnownValues() throws {
        let json = Data(#"[{"preferred_name":null,"full_name":"Ravi Santoso","email":"ravi@student.fontys.nl","avatar_url":null,"avatar_path":"u/a.jpg","theme_color":"lime","text_size":"huge","vault_layout":"list"}]"#.utf8)
        let profile = try #require(try JSONDecoder().decode([SettingsProfileRow].self, from: json).first).profile(canChangeSettings: true)
        #expect(profile.displayName == "Ravi")
        #expect(profile.theme == .lime)
        #expect(profile.textSize == .standard)
        #expect(profile.vaultLayout == .list)
        #expect(profile.avatarPath == "u/a.jpg")
    }

    @Test func aNameIsTidiedAndKeptShort() throws {
        #expect(try PaveProfile.cleanedName("  Ravi   S. ") == "Ravi S.")
        #expect(try PaveProfile.cleanedName("   ") == nil)
        #expect(throws: ProfileError.nameTooLong) { try PaveProfile.cleanedName(String(repeating: "a", count: 61)) }
        #expect(PaveProfile(preferredName: " Rav ", fullName: "Ravi Santoso").displayName == "Rav")
    }

    @Test func everyAccentCarriesWhiteText() {
        func luminance(_ hex: UInt32) -> Double {
            func channel(_ value: UInt32) -> Double {
                let c = Double(value) / 255
                return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(hex >> 16 & 0xFF) + 0.7152 * channel(hex >> 8 & 0xFF) + 0.0722 * channel(hex & 0xFF)
        }
        for theme in PaveThemeColor.allCases {
            #expect(1.05 / (luminance(theme.accent) + 0.05) >= 4.5, "\(theme)")
        }
        for own: UInt32 in [0xFFFFFF, 0xFFEB3B, 0x00FF00, 0xFFD1E8, 0x7FDBFF] {
            #expect(1.05 / (luminance(PaveThemeColor.readableAccent(for: own)) + 0.05) >= 4.5, "\(PaveThemeColor.hex(own))")
        }
        #expect(PaveThemeColor.readableAccent(for: 0x1A2B3C) == 0x1A2B3C)
    }

    @Test func anOwnColourGetsTheClosestThemeColour() {
        #expect(PaveThemeColor.nearestPreset(to: 0x7FDBFF) == .blue)
        #expect(PaveThemeColor.nearestPreset(to: 0xFF66AA) == .pink)
        #expect(PaveThemeColor.nearestPreset(to: 0xE53935) == .red)
        #expect(PaveThemeColor.nearestPreset(to: 0x2E7D32) == .green)
        #expect(PaveThemeColor.nearestPreset(to: 0x808080) == .green)
        #expect(PaveThemeColor.nearestPreset(to: 0xFFFFFF) == .green)
        for preset in PaveThemeColor.presets {
            #expect(PaveThemeColor.nearestPreset(to: preset.swatch) == preset, "\(preset)")
        }
    }

    @Test func anOwnColourIsStoredAsHexAndNeedsItsValue() throws {
        #expect(PaveThemeColor.hex(0xff66aa) == "#FF66AA")
        #expect(PaveThemeColor.color(hex: "#FF66AA") == 0xFF66AA)
        #expect(PaveThemeColor.color(hex: "FF66AA") == nil)
        #expect(!PaveThemeColor.presets.contains(.custom))

        func profile(_ fields: String) throws -> PaveProfile {
            let json = Data("[{\"full_name\":\"Ravi Santoso\",\(fields)}]".utf8)
            return try #require(try JSONDecoder().decode([SettingsProfileRow].self, from: json).first).profile(canChangeSettings: true)
        }
        let own = try profile(##""theme_color":"custom","theme_custom_color":"#FF66AA""##)
        #expect(own.theme == .custom && own.customColor == 0xFF66AA)
        #expect(try profile(#""theme_color":"custom","theme_custom_color":null"#).theme == .green)
    }

    @Test func aMissingMigrationIsNotSetUp() {
        #expect(SupabaseProfileService.error(status: 400, body: Data(#"{"code":"42703"}"#.utf8)) == .notSetUp)
        #expect(SupabaseProfileService.error(status: 400, body: Data(#"{"error":"Bucket not found"}"#.utf8)) == .notSetUp)
        #expect(SupabaseProfileService.error(status: 403, body: Data()) == .notAllowed)
        #expect(SupabaseProfileService.error(status: 500, body: Data()) == .unavailable)
    }
}
