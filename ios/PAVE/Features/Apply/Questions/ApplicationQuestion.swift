import Foundation

/// A question from Ayla about one entry on the CV, with what the user answered and what became of it.
struct ApplicationQuestion: Identifiable, Equatable {
    enum State: Equatable {
        case open
        /// Ayla is writing the entry again with the answer.
        case working
        /// In the CV; `before` is what the entry said, to go back to.
        case done(before: String)
        case skipped
    }

    let id = UUID().uuidString
    let entryID: String
    let sourceItemID: String
    /// The title of the entry it is about.
    let title: String
    let text: String
    var answer = ""
    var state = State.open
    var isKeeping = false
    var isKept = false
}
