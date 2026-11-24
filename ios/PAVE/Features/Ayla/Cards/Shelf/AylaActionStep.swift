/// One thing Ayla does in the app, as a line you can follow.
struct AylaActionStep: Identifiable, Equatable {
    enum State {
        case waiting, running, done, failed
    }

    let id: Int
    let title: String
    var state = State.waiting
}
