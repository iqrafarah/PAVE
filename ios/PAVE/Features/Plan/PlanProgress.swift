import PAVECore

/// Where the app reports what you just did, so a plan can offer to finish the step you are on.
enum PlanProgress {
    static var handler: ((PlanProgressEvent) -> Void)?

    static func report(_ event: PlanProgressEvent) {
        handler?(event)
    }
}
