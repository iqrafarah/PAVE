import PAVECore

/// A part of the CV or the letter that can be tapped and changed.
enum ApplicationBlock: Hashable {
    case personal
    case profile
    case entry(String)
    case skills
    case salutation
    case paragraph(String)
    case closing

    /// A block of running text, which Ayla can write again.
    var isText: Bool {
        switch self {
        case .profile, .paragraph: true
        default: false
        }
    }
}

/// The CV or the letter, whichever is in front.
enum ApplicationDocumentKind: String, CaseIterable, Identifiable {
    case cv, letter
    var id: Self { self }
}
