import SwiftUI

// The Watch's texts are Dutch strings in the code, as on the iPhone. These versions of SwiftUI's initialisers take a
// `String` and translate it into the language of the iPhone app. Use `Text(verbatim:)` for a name.

extension Text {
    nonisolated init(_ content: String) {
        self.init(verbatim: WatchTranslator.translate(content))
    }
}

extension Button where Label == Text {
    init(_ title: String, action: @escaping @MainActor () -> Void) {
        self.init(action: action) { Text(title) }
    }

    init(_ title: String, role: ButtonRole?, action: @escaping @MainActor () -> Void) {
        self.init(role: role, action: action) { Text(title) }
    }
}

extension SwiftUI.Label where Title == Text, Icon == Image {
    init(_ title: String, systemImage: String) {
        self.init { Text(title) } icon: { Image(systemName: systemImage) }
    }
}

extension View {
    func navigationTitle(_ title: String) -> some View {
        navigationTitle(Text(title))
    }

    func accessibilityLabel(_ label: String) -> some View {
        accessibilityLabel(Text(label))
    }

    func accessibilityHint(_ hint: String) -> some View {
        accessibilityHint(Text(hint))
    }
}
