import SwiftUI

// PAVE's texts are Dutch strings in the code. These versions of SwiftUI's text initialisers take a `String` and
// translate it into the language of Instellingen › Taal; Swift picks them over SwiftUI's own because `String` is more
// specific than `StringProtocol`. Use `Text(verbatim:)` for a text that must never change, such as a name.

extension Text {
    nonisolated init(_ content: String) {
        self.init(verbatim: PaveTranslator.translate(content))
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

    init(_ title: String, image: ImageResource) {
        self.init { Text(title) } icon: { Image(image) }
    }

    init(_ title: String, image: String) {
        self.init { Text(title) } icon: { Image(image) }
    }
}

extension Toggle where Label == Text {
    init(_ title: String, isOn: Binding<Bool>) {
        self.init(isOn: isOn) { Text(title) }
    }
}

extension TextField where Label == Text {
    init(_ title: String, text: Binding<String>) {
        self.init(text: text, prompt: Text(title)) { Text(title) }
    }

    init(_ title: String, text: Binding<String>, axis: Axis) {
        self.init(text: text, prompt: Text(title), axis: axis) { Text(title) }
    }

    init(_ title: String, text: Binding<String>, prompt: Text?) {
        self.init(text: text, prompt: prompt) { Text(title) }
    }

    init(_ title: String, text: Binding<String>, prompt: Text?, axis: Axis) {
        self.init(text: text, prompt: prompt, axis: axis) { Text(title) }
    }
}

extension SecureField where Label == Text {
    init(_ title: String, text: Binding<String>) {
        self.init(text: text, prompt: Text(title)) { Text(title) }
    }
}

extension Picker where Label == Text {
    init(_ title: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.init(selection: selection, content: content) { Text(title) }
    }
}

extension Menu where Label == Text {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content) { Text(title) }
    }
}

extension Link where Label == Text {
    init(_ title: String, destination: URL) {
        self.init(destination: destination) { Text(title) }
    }
}

extension Section where Parent == Text, Footer == EmptyView {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content) { Text(title) }
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

    func accessibilityValue(_ value: String) -> some View {
        accessibilityValue(Text(value))
    }

    func accessibilityAction(named name: String, _ handler: @escaping @MainActor () -> Void) -> some View {
        accessibilityAction(named: Text(name), handler)
    }

    func alert<A: View>(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View {
        alert(Text(title), isPresented: isPresented, actions: actions)
    }

    func alert<A: View, M: View>(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View {
        alert(Text(title), isPresented: isPresented, actions: actions, message: message)
    }

    func alert<A: View, M: View, T>(_ title: String, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View {
        alert(Text(title), isPresented: isPresented, presenting: data, actions: actions, message: message)
    }

    func alert<A: View, T>(_ title: String, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View {
        alert(Text(title), isPresented: isPresented, presenting: data, actions: actions)
    }

    func confirmationDialog<A: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A) -> some View {
        confirmationDialog(Text(title), isPresented: isPresented, titleVisibility: titleVisibility, actions: actions)
    }

    func confirmationDialog<A: View, M: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View {
        confirmationDialog(Text(title), isPresented: isPresented, titleVisibility: titleVisibility, actions: actions, message: message)
    }

    func confirmationDialog<A: View, T>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View {
        confirmationDialog(Text(title), isPresented: isPresented, titleVisibility: titleVisibility, presenting: data, actions: actions)
    }

    func confirmationDialog<A: View, M: View, T>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View {
        confirmationDialog(Text(title), isPresented: isPresented, titleVisibility: titleVisibility, presenting: data, actions: actions, message: message)
    }
}
