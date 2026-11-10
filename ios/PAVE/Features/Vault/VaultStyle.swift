import PAVECore
import SwiftUI

extension VaultCategory {
    var icon: ImageResource {
        switch self {
        case .diplomas: .iconAcademicCapSolid
        case .certificates: .iconCheckBadgeSolid
        case .badges: .iconStar
        case .projects: .iconWrenchScrewdriverSolid
        case .workExperience: .iconBriefcaseSolid
        case .internships: .iconBuildingOfficeSolid
        case .skills: .iconPaintBrush
        case .feedback: .iconChatBubbleLeftEllipsisSolid
        case .reflections: .iconDocumentText
        }
    }

    /// The outline icon on the folder tiles, as in the design. Everywhere else the vault uses filled icons.
    var folderIcon: ImageResource {
        switch self {
        case .diplomas: .iconAcademicCapOutline
        case .certificates: .iconCheckBadgeOutline
        case .badges: .iconStarOutline
        case .projects: .iconWrenchScrewdriverOutline
        case .workExperience: .iconBriefcaseOutline
        case .internships: .iconBuildingOfficeOutline
        case .skills: .iconPaintBrushOutline
        case .feedback: .iconChatBubbleLeftEllipsisOutline
        case .reflections: .iconDocumentTextOutline
        }
    }

    var tint: Color {
        switch self {
        case .diplomas, .certificates, .badges: .cardTintApricot
        case .workExperience, .internships: .cardTintGreen
        case .projects, .skills: .cardTintLime
        case .feedback, .reflections: .cardTintLavender
        }
    }
}

extension VaultItem.Status {
    var icon: ImageResource {
        switch self {
        case .verified: .iconCheckBadgeSolid
        case .toVerify: .iconClockSolid
        case .rejected: .iconExclamationCircleSolid
        }
    }

    var foreground: Color {
        switch self {
        case .verified: .brandGreen
        case .toVerify: .statusPending
        case .rejected: .statusRejected
        }
    }

    var background: Color {
        switch self {
        case .verified: .statusVerifiedSurface
        case .toVerify: .statusPendingSurface
        case .rejected: .statusRejectedSurface
        }
    }
}

extension VaultFolderColor {
    var color: Color {
        switch self {
        case .green: .brandGreen
        case .blue: .folderBlue
        case .purple: .folderPurple
        case .rust: .folderRust
        case .rose: .folderRose
        case .slate: .folderSlate
        }
    }

    /// The light band behind the folder: 11% of the colour on white, which for green is exactly the surface tint.
    var surface: Color {
        self == .green ? .surfaceTint : color.mix(with: .white, by: 0.89)
    }
}

extension VaultFolderIcon {
    /// Outline, like the icons on the category folders.
    var image: ImageResource {
        switch self {
        case .folder: .iconFolderOutline
        case .briefcase: .iconBriefcaseOutline
        case .academicCap: .iconAcademicCapOutline
        case .checkBadge: .iconCheckBadgeOutline
        case .wrenchScrewdriver: .iconWrenchScrewdriverOutline
        case .chatBubble: .iconChatBubbleLeftEllipsisOutline
        case .star: .iconStarOutline
        case .heart: .iconHeartOutline
        case .codeBracket: .iconCodeBracketOutline
        case .lightBulb: .iconLightBulbOutline
        case .rocket: .iconRocketLaunchOutline
        case .globe: .iconGlobeEuropeAfricaOutline
        case .paintBrush: .iconPaintBrushOutline
        case .documentText: .iconDocumentTextOutline
        case .userGroup: .iconUserGroupOutline
        case .trophy: .iconTrophyOutline
        }
    }
}
