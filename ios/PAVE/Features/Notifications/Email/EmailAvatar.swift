import Contacts
import SwiftUI

/// Someone's photo: your own PAVE photo when it is the address of your PAVE account, otherwise the photo from your
/// contacts, otherwise their initials in PAVE's colours.
struct EmailAvatar: View {
    let person: EmailAddress
    var size: CGFloat = 36

    @Environment(ProfileModel.self) private var profile: ProfileModel?
    @Environment(EmailModel.self) private var email: EmailModel?
    @State private var card: EmailContactCard?

    /// The address of your PAVE account, or the iCloud address you connected.
    private var isYou: Bool {
        if let mine = profile?.profile.email, person.matches(mine) { return true }
        if let mine = email?.accounts.first?.address, person.matches(mine) { return true }
        return false
    }

    private var photo: UIImage? {
        if isYou, let avatar = profile?.avatar { return avatar }
        return card?.photo
    }

    var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.paveSurfaceTint
                    .overlay {
                        if initials.isEmpty {
                            Image(.iconUserSolid)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: size * 0.46, height: size * 0.46)
                                .foregroundStyle(Color.paveAccent)
                        } else {
                            Text(initials)
                                .font(.custom("Sora-Regular_SemiBold", size: size * 0.38))
                                .foregroundStyle(Color.paveAccent)
                        }
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
        .task(id: person.address) { card = await EmailContactCard.lookup(person.address) }
        // What Meldingen shows, the melding on the lock screen shows too, also when PAVE is not open.
        .onChange(of: photo, initial: true) { _, photo in
            if let photo { EmailPhotoStore.save(photo, for: person.address) }
        }
    }

    private var initials: String {
        let name = card?.name ?? person.name ?? ""
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first(where: \.isLetter) }
        return String(letters).uppercased()
    }
}

/// One photo for a conversation with one person; for several, two overlapping ones as in a group in Messages.
struct EmailAvatarStack: View {
    let people: [EmailAddress]
    var size: CGFloat = 30

    var body: some View {
        if people.count == 1 {
            EmailAvatar(person: people[0], size: size)
        } else {
            ZStack(alignment: .bottomTrailing) {
                EmailAvatar(person: people[0], size: size * 0.8)
                    .frame(width: size * 1.3, height: size, alignment: .topLeading)
                EmailAvatar(person: people[1], size: size * 0.8)
                    .overlay { Circle().strokeBorder(Color.canvas, lineWidth: 2) }
            }
            .frame(width: size * 1.3, height: size)
        }
    }
}

/// The photos the app has shown for an address (your PAVE photo, a contact's), kept small on this iPhone so a melding
/// can show the same photo, also from the background refresh.
nonisolated enum EmailPhotoStore {
    private static var folder: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "EmailPhotos", directoryHint: .isDirectory)
    }

    private static func url(for address: String) -> URL {
        let name = address.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
        return folder.appending(path: "\(name).jpg")
    }

    /// Written once per address while PAVE is open, so a new photo replaces the old one without writing on every row.
    @MainActor private static var savedThisSession: Set<String> = []

    @MainActor
    static func save(_ photo: UIImage, for address: String) {
        guard savedThisSession.insert(address.lowercased()).inserted else { return }
        let url = url(for: address)
        guard let data = photo.preparingThumbnail(of: CGSize(width: 240, height: 240))?.jpegData(compressionQuality: 0.85)
                ?? photo.jpegData(compressionQuality: 0.85) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func data(for address: String) -> Data? {
        try? Data(contentsOf: url(for: address))
    }

    @MainActor
    static func forgetAll() {
        savedThisSession = []
        try? FileManager.default.removeItem(at: folder)
    }
}

/// What your contacts know about an address: a name and a photo. Looked up once per address while PAVE is open.
struct EmailContactCard {
    let name: String?
    let photo: UIImage?

    @MainActor private static var cache: [String: EmailContactCard] = [:]

    @MainActor
    static func lookup(_ address: String) async -> EmailContactCard? {
        let key = address.lowercased()
        if let cached = cache[key] { return cached }
        guard EmailContacts.isAllowed else { return nil }
        let found = await Task.detached(priority: .utility) { () -> (String?, Data?) in
            let keys = [
                CNContactGivenNameKey, CNContactFamilyNameKey, CNContactThumbnailImageDataKey, CNContactImageDataAvailableKey,
            ] as [CNKeyDescriptor]
            let predicate = CNContact.predicateForContacts(matchingEmailAddress: key)
            guard let contact = try? CNContactStore().unifiedContacts(matching: predicate, keysToFetch: keys).first else { return (nil, nil) }
            let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            return (name.isEmpty ? nil : name, contact.imageDataAvailable ? contact.thumbnailImageData : nil)
        }.value
        let card = EmailContactCard(name: found.0, photo: found.1.flatMap(UIImage.init(data:)))
        cache[key] = card
        return card
    }
}
