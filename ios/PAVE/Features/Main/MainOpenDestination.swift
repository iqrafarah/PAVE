import PAVECore
import SwiftUI

extension EnvironmentValues {
    /// Goes to another part of the app from a sheet that just finished, such as Meldingen after a request was sent.
    @Entry var openDestination: ((MainDestination) -> Void)?
    /// Does something with a vacancy in the chat (apply, what you miss, practise, ask), from a screen outside it such as
    /// an employer at the fair.
    @Entry var vacancyRequest: ((AylaChatModel.VacancyRequest) -> Void)?
}

/// An employer to open from a link, by the slug in its code.
struct FairEmployerSlug: Identifiable, Equatable {
    let slug: String
    var id: String { slug }
}
