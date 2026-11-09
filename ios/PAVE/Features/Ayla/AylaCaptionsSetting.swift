import UIKit

/// Captions in the voice conversation: the sentence Ayla is saying, under the orb.
enum AylaCaptionsSetting {
    static let key = "aylaVoiceCaptions"

    /// Without a choice in PAVE, captions follow "Subtitles & Captioning" in the iPhone's accessibility settings.
    static func isOn(_ choice: Bool?) -> Bool {
        choice ?? UIAccessibility.isClosedCaptioningEnabled
    }
}
