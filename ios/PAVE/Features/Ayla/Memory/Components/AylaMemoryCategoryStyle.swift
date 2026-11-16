import PAVECore
import SwiftUI

/// How a memory category looks: a solid Heroicon on one of the pastel tints of the vault tiles in Figma.
extension AylaMemory.Category {
    /// Heroicons Solid, like the rest of PAVE.
    var icon: ImageResource {
        switch self {
        case .education: .iconAcademicCap
        case .work: .iconBriefcaseSolid
        case .goals: .iconFlag
        case .skills: .iconStar
        case .values: .iconHeart
        case .workStyle: .iconUserGroup
        case .interests: .iconPaintBrush
        case .personal: .iconUserCircle
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
