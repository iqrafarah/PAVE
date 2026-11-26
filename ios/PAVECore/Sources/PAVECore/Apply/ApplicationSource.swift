import Foundation

/// Where an application comes from, as a label in the one list of applications: found with Ayla, made yourself, or left
/// at the fair.
public enum ApplicationSource: String, CaseIterable, Sendable {
    case ayla, own, fair

    public init(_ vacancy: Vacancy) {
        self = vacancy.source == .own ? .own : .ayla
    }
}

extension FairApplication {
    /// Where it stands in the same terms as any application: left behind is sent, an invitation (you come) is a talk,
    /// not chosen or said no is rejected.
    public var applicationStatus: ApplicationStatus {
        switch (status, answer) {
        case (.declined, _), (.invited, .declined?): .rejected
        case (.invited, _): .interview
        case (.new, _): .sent
        }
    }
}
