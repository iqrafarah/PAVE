import CoreText
import SwiftUI

/// The typeface of the whole app, chosen in Instellingen › Weergave. PAVE's own (Inter with Sora for titles) is the
/// default; the others are Apple's, and one made to be easy to read.
enum PaveFontStyle: String, CaseIterable, Identifiable {
    case pave
    case system
    case rounded
    case serif
    case readable

    var id: String { rawValue }

    /// Atkinson Hyperlegible (Braille Institute, SIL Open Font License): letters that are hard to mix up.
    static let readableRegular = "AtkinsonHyperlegible-Regular"
    static let readableBold = "AtkinsonHyperlegible-Bold"
}

/// The chosen typeface. Text styles read it while they draw, so Observation redraws every text when it changes.
/// Kept on this device only, like "Animaties uitzetten".
@Observable
final class PaveFontStore {
    static let shared = PaveFontStore()
    static let key = "paveFontStyle"

    var style: PaveFontStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: Self.key) }
    }

    private init() {
        style = UserDefaults.standard.string(forKey: Self.key).flatMap(PaveFontStyle.init(rawValue:)) ?? .pave
        // The readable typeface ships in the app's resources; registering it here needs no entry in Info.plist.
        for name in [PaveFontStyle.readableRegular, PaveFontStyle.readableBold] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
