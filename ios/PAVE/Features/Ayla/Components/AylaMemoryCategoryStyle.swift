import PAVECore
import SwiftUI

/// How a memory category looks: a filled icon on one of the pastel tints of the vault tiles in Figma.
extension AylaMemory.Category {
    var symbol: String {
        switch self {
        case .education: "graduationcap.fill"
        case .work: "briefcase.fill"
        case .goals: "flag.fill"
        case .skills: "star.fill"
        case .values: "heart.fill"
        case .workStyle: "person.2.fill"
        case .interests: "paintpalette.fill"
        case .personal: "person.crop.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .education, .workStyle: .cardTintLavender
        case .work, .interests: .cardTintApricot
        case .goals, .personal: .cardTintGreen
        case .skills: .cardTintLime
        case .values: .cardTintRose
        }
    }
}
