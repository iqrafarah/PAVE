import ContactsUI
import SwiftUI

extension View {
    /// iOS's own contact picker, limited to e-mail addresses. It needs no access to your contacts: you only hand over
    /// the address you tap.
    func emailContactPicker(isPresented: Binding<Bool>, onPick: @escaping (EmailAddress) -> Void) -> some View {
        background(EmailContactPicker(isPresented: isPresented, onPick: onPick).frame(width: 0, height: 0))
    }
}

/// CNContactPickerViewController has to be presented by UIKit itself; inside a SwiftUI sheet it stays empty.
private struct EmailContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (EmailAddress) -> Void

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactEmailAddressesKey]
        picker.predicateForEnablingContact = NSPredicate(format: "emailAddresses.@count > 0")
        picker.predicateForSelectionOfContact = NSPredicate(format: "emailAddresses.@count == 1")
        DispatchQueue.main.async { host.present(picker, animated: true) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: EmailContactPicker

        init(parent: EmailContactPicker) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            if let email = contact.emailAddresses.first { pick(email.value as String, contact) }
            parent.isPresented = false
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect property: CNContactProperty) {
            if let email = property.value as? String { pick(email, property.contact) }
            parent.isPresented = false
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }

        private func pick(_ address: String, _ contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName)
            parent.onPick(EmailAddress(name: name, address: address.lowercased()))
        }
    }
}
