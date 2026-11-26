import SwiftUI

/// Instellingen › Taal: Nederlands, English or Papiamentu. Each language is shown in its own name and PAVE changes at
/// once, so you never get stuck in a language you cannot read.
struct SettingsLanguageScreen: View {
    @State private var store = PaveLanguageStore.shared

    var body: some View {
        SettingsPage(title: SettingsMessages.language, cameraMenus: cameraMenus) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(PaveLanguage.allCases) { language in
                    SettingsOptionCard(title: language.nativeName, isSelected: store.language == language) {
                        Text(verbatim: language.flag)
                            .font(.system(size: 22))
                    } action: {
                        store.select(language)
                    }
                    .environment(\.locale, language.locale)
                }
                Text(SettingsMessages.languageHint)
                    .textStyle(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var cameraMenus: [CameraMenu] {
        let languages = PaveLanguage.allCases
        return [
            CameraMenu(
                id: "language", title: SettingsMessages.language, symbol: "globe", items: languages.map(\.nativeName),
                selected: languages.firstIndex(of: store.language) ?? 0,
                onSwipe: { index in store.select(languages[index]) }
            ),
        ]
    }
}
