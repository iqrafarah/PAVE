import SwiftUI

extension EnvironmentValues {
    /// Goes to another part of the app from a sheet that just finished, such as Meldingen after a request was sent.
    @Entry var openDestination: ((MainDestination) -> Void)?
}
